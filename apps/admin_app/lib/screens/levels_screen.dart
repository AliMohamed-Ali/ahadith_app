import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../ui.dart';
import 'hadith_list_screen.dart';

/// مستويات تبويب: عدد غير محدود، ترتيب بالسحب، تعديل وحذف.
class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key, required this.tab});
  final AppTab tab;
  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  late final repo = context.read<ContentRepository>();
  late final Stream<List<Level>> _levels = repo.levels(widget.tab.id);
  late final Stream<List<Hadith>> _hadiths = repo.hadiths(widget.tab.id, onlyPublished: false);
  List<Level> _local = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('مستويات: ${widget.tab.nameAr}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('مستوى جديد'),
      ),
      body: StreamBuilder<List<Hadith>>(
        stream: _hadiths,
        builder: (context, hs) => StreamBuilder<List<Level>>(
          stream: _levels,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            _local = [...snap.data!];
            final counts = <String, int>{};
            for (final h in hs.data ?? const <Hadith>[]) {
              if (h.levelId != null) counts[h.levelId!] = (counts[h.levelId!] ?? 0) + 1;
            }
            if (_local.isEmpty) return const Center(child: Text('مفيش مستويات. ضيفي أول مستوى.'));
            return ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
              itemCount: _local.length,
              onReorder: (a, b) {
                if (b > a) b--;
                _local.insert(b, _local.removeAt(a));
                setState(() {});
                run(context, () => repo.reorder('levels', _local.map((e) => e.id).toList()), done: 'اتغير الترتيب');
              },
              itemBuilder: (context, i) {
                final l = _local[i];
                final n = counts[l.id] ?? 0;
                return Card(
                  key: ValueKey(l.id),
                  color: Colors.white,
                  elevation: 0,
                  shape: cardShape,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: hexColor(l.color), child: Text('${i + 1}', style: TextStyle(color: onColor(hexColor(l.color)), fontWeight: FontWeight.w800))),
                    title: Text(l.nameAr, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${l.ageAr.isEmpty ? '' : '${l.ageAr} · '}$n حديث'),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HadithListScreen(tab: widget.tab, level: l))),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(onPressed: () => _edit(l, hadithCount: n), icon: const Icon(Icons.edit_rounded)),
                      ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle_rounded)),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _edit(Level? l, {int hadithCount = 0}) async {
    final nameAr = TextEditingController(text: l?.nameAr ?? 'المستوى ${_local.length + 1}');
    final nameEn = TextEditingController(text: l?.nameEn ?? '');
    final ageAr = TextEditingController(text: l?.ageAr ?? '');
    final ageEn = TextEditingController(text: l?.ageEn ?? '');
    var color = l?.color ?? presetColors[_local.length % presetColors.length];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(ctx).bottom + 16),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l == null ? 'مستوى جديد' : 'تعديل المستوى', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TF(nameAr, 'الاسم بالعربي'),
              const SizedBox(height: 10),
              TF(nameEn, 'الاسم بالإنجليزي', ltr: true),
              const SizedBox(height: 10),
              TF(ageAr, 'السن بالعربي (مثلًا: من ٤ إلى ٦ سنوات)'),
              const SizedBox(height: 10),
              TF(ageEn, 'السن بالإنجليزي', ltr: true),
              const SizedBox(height: 12),
              ColorField(value: color, onChanged: (v) => setS(() => color = v)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () async {
                  if (nameAr.text.trim().isEmpty) {
                    toast(ctx, 'اكتبي الاسم', error: true);
                    return;
                  }
                  final lv = Level(
                    id: l?.id ?? repo.newId('levels'),
                    tabId: widget.tab.id,
                    nameAr: nameAr.text.trim(),
                    nameEn: nameEn.text.trim(),
                    ageAr: ageAr.text.trim(),
                    ageEn: ageEn.text.trim(),
                    color: color,
                    order: l?.order ?? _local.length + 1,
                  );
                  if (await run(ctx, () => repo.saveLevel(lv)) && ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('حفظ'),
              ),
              if (l != null)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () async {
                    if (hadithCount > 0) {
                      {
                    toast(ctx, 'المستوى فيه $hadithCount حديث. انقليهم أو امسحيهم الأول.', error: true);
                    return;
                  }
                    }
                    final ok = await confirm(ctx, 'حذف المستوى؟', 'هيتمسح «${l.nameAr}».', ok: 'احذف', danger: true);
                    if (ok && ctx.mounted && await run(ctx, () => repo.deleteLevel(l.id), done: 'اتمسح') && ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('حذف المستوى'),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

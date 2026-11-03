import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../ui.dart';
import 'hadith_list_screen.dart';

/// مستويات تبويب: عدد غير محدود، ترتيب بالسحب، تعديل وحذف.
/// لو parent موجود: أقسام مستوى خريطة (زي جبال الآداب).
class LevelsScreen extends StatefulWidget {
  const LevelsScreen({super.key, required this.tab, this.parent});
  final AppTab tab;
  final Level? parent;
  @override
  State<LevelsScreen> createState() => _LevelsScreenState();
}

class _LevelsScreenState extends State<LevelsScreen> {
  late final repo = context.read<ContentRepository>();
  late final Stream<List<Level>> _levels = repo.levels(widget.tab.id);
  late final Stream<List<Hadith>> _hadiths = repo.hadiths(widget.tab.id, onlyPublished: false);
  List<Level> _local = [];
  /// كل مستويات التبويب (عشان نختار المستوى اللي الجبل تبعه).
  List<Level> _all = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.parent == null ? 'مستويات: ${widget.tab.nameAr}' : 'جبال: ${widget.parent!.nameAr}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add_rounded),
        label: Text(widget.parent == null ? 'مستوى جديد' : 'جبل جديد'),
      ),
      body: StreamBuilder<List<Hadith>>(
        stream: _hadiths,
        builder: (context, hs) => StreamBuilder<List<Level>>(
          stream: _levels,
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final all = _all = snap.data!;
            _local = all.where((l) => l.parentId == widget.parent?.id).toList();
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
                    subtitle: Text(
                      '${l.ageAr.isEmpty ? '' : '${l.ageAr} · '}'
                      '${l.isMap ? 'خريطة جبال · ${all.where((c) => c.parentId == l.id).length} جبل' : '${l.icon.isEmpty ? '' : '${l.icon} '}$n حديث'}',
                    ),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => l.isMap ? LevelsScreen(tab: widget.tab, parent: l) : HadithListScreen(tab: widget.tab, level: l))),
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
    final icon = TextEditingController(text: l?.icon ?? '');
    final desc = TextEditingController(text: l?.descAr ?? '');
    var color = l?.color ?? presetColors[_local.length % presetColors.length];
    // جبل (قسم جوه مستوى خريطة) ولا مستوى عادي
    final isSection = (l?.parentId ?? widget.parent?.id) != null;
    var parentId = l?.parentId ?? widget.parent?.id;
    var style = l?.style ?? '';
    final maps = _all.where((x) => x.isMap).toList();
    final children = l == null ? 0 : _all.where((x) => x.parentId == l.id).length;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(ctx).bottom + 16),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(isSection ? (l == null ? 'جبل جديد' : 'تعديل الجبل') : (l == null ? 'مستوى جديد' : 'تعديل المستوى'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TF(nameAr, 'الاسم بالعربي'),
              const SizedBox(height: 10),
              TF(nameEn, 'الاسم بالإنجليزي', ltr: true),
              const SizedBox(height: 10),
              if (!isSection) ...[
                TF(ageAr, 'سطر صغير تحت الاسم (اختياري، مثلًا: المستوى الأول)'),
                const SizedBox(height: 10),
                TF(ageEn, 'السطر الصغير بالإنجليزي', ltr: true),
                const SizedBox(height: 12),
                Choice<String>(
                  label: 'شكل المستوى عند الأطفال',
                  value: style,
                  options: const {'': 'نهر أحاديث على طول', 'mountains': 'خريطة جبال (كل جبل نهر)'},
                  onChanged: (v) => setS(() => style = v),
                ),
                if (style == 'mountains') ...[
                  const SizedBox(height: 10),
                  TF(desc, 'كلمة تحت الخريطة (اختياري)', lines: 2),
                ],
                const SizedBox(height: 12),
              ] else ...[
                TF(icon, 'إيموجي الجبل (مثلًا 🍽️)'),
                const SizedBox(height: 10),
                Choice<String?>(
                  label: 'الجبل ده في أنهي مستوى',
                  value: parentId,
                  options: {for (final m in maps) m.id: m.nameAr},
                  onChanged: (v) => setS(() => parentId = v),
                ),
                const SizedBox(height: 10),
                TF(desc, 'ملحوظة بتظهر فوق النهر (اختياري)', lines: 2),
                const SizedBox(height: 12),
              ],
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
                    // الحاجات اللي مش في الفورم بتفضل زي ما هي
                    ageYear: l?.ageYear ?? 0,
                    hadithIds: l?.hadithIds ?? const [],
                    parentId: parentId,
                    style: isSection ? '' : style,
                    icon: icon.text.trim(),
                    descAr: desc.text.trim(),
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
                      toast(ctx, 'المستوى فيه $hadithCount حديث. انقليهم أو امسحيهم الأول.', error: true);
                      return;
                    }
                    if (children > 0) {
                      toast(ctx, 'المستوى فيه $children جبل. انقليهم لمستوى تاني أو امسحيهم الأول.', error: true);
                      return;
                    }
                    final ok = await confirm(ctx, 'حذف المستوى؟', 'هيتمسح «${l.nameAr}».', ok: 'احذف', danger: true);
                    if (ok && ctx.mounted && await run(ctx, () => repo.deleteLevel(l.id), done: 'اتمسح') && ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(isSection ? 'حذف الجبل' : 'حذف المستوى'),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

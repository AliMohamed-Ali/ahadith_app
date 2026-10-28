import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../ui.dart';
import 'bukhari_screen.dart';
import 'hadith_list_screen.dart';
import 'levels_screen.dart';
import 'qa_editor_screen.dart';

/// كل التبويبات: إضافة تبويب من أي نوع، ترتيب، إخفاء، حذف، والدخول على محتواه.
class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key});
  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
  late final repo = context.read<ContentRepository>();
  late final Stream<List<AppTab>> _stream = repo.tabs();
  List<AppTab> _local = [];

  void _open(AppTab t) {
    final Widget w = t.isQa ? QaEditorScreen(tab: t) : (t.isAges ? const BukhariAdminScreen() : (t.hasLevels ? LevelsScreen(tab: t) : HadithListScreen(tab: t)));
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التبويبات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTabEditor(context, null, nextOrder: _local.length + 1),
        icon: const Icon(Icons.add_rounded),
        label: const Text('تبويب جديد'),
      ),
      body: StreamBuilder<List<AppTab>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          _local = [...snap.data!];
          if (_local.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('مفيش تبويبات. اعملي تبويب جديد أو استوردي المحتوى الأولي من لوحة التحكم.', textAlign: TextAlign.center)));
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: _local.length,
            onReorder: (a, b) {
              if (b > a) b--;
              final t = _local.removeAt(a);
              _local.insert(b, t);
              setState(() {});
              run(context, () => repo.reorder('tabs', _local.map((e) => e.id).toList()), done: 'اتغير الترتيب');
            },
            itemBuilder: (context, i) {
              final t = _local[i];
              final c = hexColor(t.color);
              final kind = t.isQa ? 'أسئلة وأجوبة' : (t.isAges ? 'بالسن والدروس (البخاري)' : (t.hasLevels ? 'أحاديث بمستويات' : 'أحاديث مفتوحة'));
              final place = t.place == 'tab' ? 'تبويب تحت' : 'كارت في الرئيسية';
              return Card(
                key: ValueKey(t.id),
                color: Colors.white,
                elevation: 0,
                shape: cardShape,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: c, child: Icon(t.isQa ? Icons.lightbulb_rounded : Icons.menu_book_rounded, color: onColor(c))),
                  title: Text(t.nameAr, style: TextStyle(fontWeight: FontWeight.w800, color: t.visible ? null : Colors.black38)),
                  subtitle: Text('$kind · $place${t.visible ? '' : ' · مخفي عن الأطفال'}'),
                  onTap: () => _open(t),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    // يظهر/يختفي في أبلكيشن الأطفال على طول
                    Tooltip(
                      message: t.visible ? 'ظاهر للأطفال' : 'مخفي عن الأطفال',
                      child: Switch(value: t.visible, onChanged: (v) => run(context, () => repo.saveTab(t.copyWith(visible: v)), done: v ? 'بقى ظاهر للأطفال ✓' : 'اتخفى عن الأطفال')),
                    ),
                    IconButton(tooltip: 'تعديل', onPressed: () => showTabEditor(context, t), icon: const Icon(Icons.edit_rounded)),
                    ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle_rounded)),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// نافذة إضافة/تعديل تبويب.
Future<void> showTabEditor(BuildContext context, AppTab? tab, {int nextOrder = 1}) async {
  final repo = context.read<ContentRepository>();
  final isNew = tab == null;
  final nameAr = TextEditingController(text: tab?.nameAr ?? '');
  final nameEn = TextEditingController(text: tab?.nameEn ?? '');
  var type = tab?.type ?? 'hadith';
  var mode = tab?.mode ?? 'open';
  var place = tab?.place ?? 'home';
  var color = tab?.color ?? '#0E7C74';
  var visible = tab?.visible ?? true;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(ctx).bottom + 16),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(isNew ? 'تبويب جديد' : 'تعديل التبويب', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TF(nameAr, 'الاسم بالعربي'),
            const SizedBox(height: 10),
            TF(nameEn, 'الاسم بالإنجليزي', ltr: true),
            const SizedBox(height: 12),
            Choice<String>(
              label: 'نوع المحتوى${isNew ? '' : ' (مايتغيرش بعد الإنشاء)'}',
              value: type,
              enabled: isNew,
              options: const {'hadith': 'أحاديث', 'qa': 'أسئلة وأجوبة'},
              onChanged: (v) => setS(() => type = v),
            ),
            // البخاري طريقة عرضه ثابتة (سنين ← دروس)
            if (type == 'hadith' && mode != 'ages') ...[
              const SizedBox(height: 12),
              Choice<String>(
                label: 'طريقة العرض',
                value: mode,
                options: const {'open': 'مفتوح (أي حديث في أي وقت)', 'levels': 'بمستويات (بالترتيب)'},
                onChanged: (v) => setS(() => mode = v),
              ),
            ],
            const SizedBox(height: 12),
            Choice<String>(
              label: 'مكانه في أبلكيشن الأطفال',
              value: place,
              options: const {'home': 'كارت في الرئيسية', 'tab': 'تبويب في الشريط اللي تحت'},
              onChanged: (v) => setS(() => place = v),
            ),
            const SizedBox(height: 12),
            ColorField(value: color, onChanged: (v) => setS(() => color = v)),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('ظاهر للأطفال'), value: visible, onChanged: (v) => setS(() => visible = v)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                if (nameAr.text.trim().isEmpty) {
                    toast(ctx, 'اكتبي الاسم', error: true);
                    return;
                  }
                final t = AppTab(
                  id: tab?.id ?? repo.newId('tabs'),
                  nameAr: nameAr.text.trim(),
                  nameEn: nameEn.text.trim(),
                  type: type,
                  mode: type == 'qa' ? 'open' : mode,
                  place: place,
                  color: color,
                  visible: visible,
                  order: tab?.order ?? nextOrder,
                  system: tab?.system ?? false,
                );
                if (await run(ctx, () => repo.saveTab(t)) && ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
            if (!isNew)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () async {
                  final ok = await confirm(ctx, 'حذف التبويب؟', 'هيتمسح التبويب «${tab!.nameAr}» وكل اللي جواه (مستويات وأحاديث وأسئلة). مفيش رجوع.', ok: 'احذف', danger: true);
                  if (ok && ctx.mounted && await run(ctx, () => repo.deleteTab(tab!.id), done: 'اتمسح') && ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('حذف التبويب'),
              ),
          ]),
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../services/media_service.dart';
import '../ui.dart';

/// أقسام تبويب أسئلة وأجوبة.
class QaEditorScreen extends StatefulWidget {
  const QaEditorScreen({super.key, required this.tab});
  final AppTab tab;
  @override
  State<QaEditorScreen> createState() => _QaEditorScreenState();
}

class _QaEditorScreenState extends State<QaEditorScreen> {
  late final repo = context.read<ContentRepository>();
  late final Stream<List<QaSection>> _stream = repo.qaSections(widget.tab.id);
  List<QaSection> _local = [];

  void _open(QaSection? s) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QaSectionEditScreen(
          section: s ?? QaSection(id: repo.newId('qaSections'), tabId: widget.tab.id, titleAr: '', order: _local.length + 1, videoScene: 's${_local.length % 7}'),
          isNew: s == null,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.tab.nameAr)),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _open(null), icon: const Icon(Icons.add_rounded), label: const Text('قسم جديد')),
      body: StreamBuilder<List<QaSection>>(
        stream: _stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          _local = [...snap.data!];
          if (_local.isEmpty) return const Center(child: Text('مفيش أقسام. ضيفي أول قسم.'));
          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: _local.length,
            onReorder: (a, b) {
              if (b > a) b--;
              _local.insert(b, _local.removeAt(a));
              setState(() {});
              run(context, () => repo.reorder('qaSections', _local.map((e) => e.id).toList()), done: 'اتغير الترتيب');
            },
            itemBuilder: (context, i) {
              final s = _local[i];
              return Card(
                key: ValueKey(s.id),
                color: Colors.white,
                elevation: 0,
                shape: cardShape,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: hexColor(s.color), child: Text('${i + 1}', style: TextStyle(color: onColor(hexColor(s.color)), fontWeight: FontWeight.w800))),
                  title: Text(s.titleAr, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${s.items.length} سؤال${s.audioUrl.isNotEmpty ? ' · فيه صوت' : ''}'),
                  onTap: () => _open(s),
                  trailing: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle_rounded)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class QaSectionEditScreen extends StatefulWidget {
  const QaSectionEditScreen({super.key, required this.section, required this.isNew});
  final QaSection section;
  final bool isNew;
  @override
  State<QaSectionEditScreen> createState() => _QaSectionEditScreenState();
}

class _QaSectionEditScreenState extends State<QaSectionEditScreen> {
  late final repo = context.read<ContentRepository>();
  late final _titleAr = TextEditingController(text: widget.section.titleAr);
  late final _titleEn = TextEditingController(text: widget.section.titleEn);
  late String _color = widget.section.color;
  late String _scene = widget.section.videoScene;
  late String _audio = widget.section.audioUrl;
  late final List<(TextEditingController, TextEditingController)> _items = [
    for (final it in widget.section.items) (TextEditingController(text: it.q), TextEditingController(text: it.a)),
  ];

  @override
  void dispose() {
    _titleAr.dispose();
    _titleEn.dispose();
    for (final it in _items) {
      it.$1.dispose();
      it.$2.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleAr.text.trim().isEmpty) {
      toast(context, 'اكتبي عنوان القسم', error: true);
      return;
    }
    final items = [
      for (final it in _items)
        if (it.$1.text.trim().isNotEmpty) QaItem(q: it.$1.text.trim(), a: it.$2.text.trim()),
    ];
    final s = QaSection(
      id: widget.section.id,
      tabId: widget.section.tabId,
      titleAr: _titleAr.text.trim(),
      titleEn: _titleEn.text.trim(),
      color: _color,
      order: widget.section.order,
      videoScene: _scene,
      audioUrl: _audio,
      items: items,
    );
    if (await run(context, () => repo.saveQaSection(s)) && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'قسم جديد' : widget.section.titleAr),
        actions: [
          if (!widget.isNew)
            IconButton(
              onPressed: () async {
                final ok = await confirm(context, 'حذف القسم؟', 'هيتمسح القسم وكل أسئلته.', ok: 'احذف', danger: true);
                if (ok && mounted && await run(context, () => repo.deleteQaSection(widget.section.id), done: 'اتمسح') && mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: _save, child: const Text('حفظ')))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        FormSection(title: 'القسم', icon: Icons.folder_rounded, children: [
          TF(_titleAr, 'العنوان بالعربي'),
          TF(_titleEn, 'العنوان بالإنجليزي', ltr: true),
          ColorField(value: _color, onChanged: (v) => setState(() => _color = v)),
        ]),
        FormSection(title: 'الفيديو', icon: Icons.movie_rounded, color: AppColors.royal, children: [
          Choice<String>(
            label: 'رسمة الفيديو',
            value: _scene,
            options: {'': 'فانوس بس', for (var i = 0; i <= 6; i++) 's$i': 'مشهد ${i + 1}'},
            onChanged: (v) => setState(() => _scene = v),
          ),
          MediaField(label: 'صوت الفيديو (اختياري)', url: _audio, kind: MediaKind.audio, onChanged: (v) => setState(() => _audio = v)),
        ]),
        FormSection(title: 'الأسئلة (${_items.length})', icon: Icons.quiz_rounded, color: AppColors.coral, children: [
          for (var i = 0; i < _items.length; i++)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Row(children: [
                  Text('سؤال ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: i == 0 ? null : () => setState(() => _items.insert(i - 1, _items.removeAt(i))),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: i == _items.length - 1 ? null : () => setState(() => _items.insert(i + 1, _items.removeAt(i))),
                    icon: const Icon(Icons.arrow_downward_rounded),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    color: AppColors.danger,
                    onPressed: () => setState(() => _items.removeAt(i)),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ]),
                TF(_items[i].$1, 'السؤال'),
                const SizedBox(height: 8),
                TF(_items[i].$2, 'الإجابة', lines: 2),
              ]),
            ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _items.add((TextEditingController(), TextEditingController()))),
            icon: const Icon(Icons.add_rounded),
            label: const Text('ضيفي سؤال'),
          ),
        ]),
      ]),
    );
  }
}

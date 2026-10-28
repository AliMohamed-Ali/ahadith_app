import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../ui.dart';
import 'hadith_edit_screen.dart';

/// أحاديث تبويب (أو مستوى): المنشور والمسودات، ترتيب بالسحب، نشر/إخفاء سريع.
class HadithListScreen extends StatefulWidget {
  const HadithListScreen({super.key, required this.tab, this.level});
  final AppTab tab;
  final Level? level;
  @override
  State<HadithListScreen> createState() => _HadithListScreenState();
}

class _HadithListScreenState extends State<HadithListScreen> {
  late final repo = context.read<ContentRepository>();
  late final Stream<List<Hadith>> _stream = repo.hadiths(widget.tab.id, levelId: widget.level?.id, onlyPublished: false);
  List<Hadith> _local = [];
  String _q = '';

  void _open(Hadith? h) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HadithEditScreen(tab: widget.tab, level: widget.level, hadith: h, nextOrder: _local.length + 1),
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.level?.nameAr ?? widget.tab.nameAr)),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _open(null), icon: const Icon(Icons.add_rounded), label: const Text('حديث جديد')),
      body: StreamBuilder<List<Hadith>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          _local = [...snap.data!];
          final filtered = _q.isEmpty ? _local : _local.where((h) => h.titleAr.contains(_q) || h.text.contains(_q)).toList();
          final canReorder = _q.isEmpty;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'دوري بالعنوان أو النص'),
                onChanged: (v) => setState(() => _q = v.trim()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text('${_local.length} حديث · ${_local.where((h) => h.published).length} منشور', style: const TextStyle(color: Colors.black54)),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('مفيش أحاديث هنا لسه.'))
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                      itemCount: filtered.length,
                      onReorder: (a, b) {
                        if (!canReorder) return;
                        if (b > a) b--;
                        _local.insert(b, _local.removeAt(a));
                        setState(() {});
                        run(context, () => repo.reorder('hadiths', _local.map((e) => e.id).toList()), done: 'اتغير الترتيب');
                      },
                      itemBuilder: (context, i) {
                        final h = filtered[i];
                        return Card(
                          key: ValueKey(h.id),
                          color: Colors.white,
                          elevation: 0,
                          shape: cardShape,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: h.published ? AppColors.teal : Colors.black12,
                              child: Text('${i + 1}', style: TextStyle(color: h.published ? Colors.white : AppColors.navy, fontWeight: FontWeight.w800)),
                            ),
                            title: Text(h.titleAr.isEmpty ? '(بدون عنوان)' : h.titleAr, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text(h.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => _open(h),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              Tooltip(
                                message: h.published ? 'ظاهر للأطفال' : 'مخفي عن الأطفال',
                                child: Switch(value: h.published, onChanged: (v) => run(context, () => repo.setPublished(h.id, v), done: v ? 'بقى ظاهر للأطفال ✓' : 'اتخفى عن الأطفال')),
                              ),
                              if (canReorder) ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle_rounded)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

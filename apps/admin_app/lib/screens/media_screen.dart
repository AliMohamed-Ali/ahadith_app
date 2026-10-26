import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/media_service.dart';
import '../ui.dart';

/// مكتبة الوسائط: رفع ملفات ونسخ روابطها.
class MediaScreen extends StatefulWidget {
  const MediaScreen({super.key});
  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  late Future<List<MediaItem>> _files = MediaService.list();

  void _reload() => setState(() => _files = MediaService.list());

  IconData _icon(String name) {
    final n = name.toLowerCase();
    if (RegExp(r'\.(mp3|m4a|aac|wav|ogg)$').hasMatch(n)) return Icons.audiotrack_rounded;
    if (RegExp(r'\.(mp4|mov|webm)$').hasMatch(n)) return Icons.movie_rounded;
    return Icons.image_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الوسائط'), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh_rounded))]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final url = await MediaService.pickAndUpload(context);
          if (url != null && mounted) {
            toast(context, 'اترفع ✓');
            _reload();
          }
        },
        icon: const Icon(Icons.upload_rounded),
        label: const Text('رفع ملف'),
      ),
      body: FutureBuilder<List<MediaItem>>(
        future: _files,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('خطأ: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('مفيش ملفات لسه.'));
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              return Card(
                color: Colors.white,
                elevation: 0,
                shape: cardShape,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: Icon(_icon(r.name)),
                  title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'نسخ الرابط',
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: r.url));
                        if (context.mounted) toast(context, 'اتنسخ الرابط');
                      },
                      icon: const Icon(Icons.link_rounded),
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      color: Colors.red,
                      onPressed: () async {
                        final ok = await confirm(context, 'شيل الملف من القائمة؟', 'الرابط هيفضل شغال في أي حديث أو قسم مستخدمه.', ok: 'احذف', danger: true);
                        if (ok && context.mounted && await run(context, () => MediaService.delete(r), done: 'اتمسح')) _reload();
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
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

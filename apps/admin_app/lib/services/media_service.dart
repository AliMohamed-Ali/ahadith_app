import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ui.dart';

enum MediaKind { audio, image, video, any }

/// ملف مرفوع على Cloudinary ومسجّل في مجموعة media في Firestore.
class MediaItem {
  MediaItem({required this.id, required this.name, required this.url});
  final String id;
  final String name;
  final String url;
}

/// رفع ملف (صوت/صورة/فيديو) إلى Cloudinary بـ upload preset من غير توقيع، وإرجاع الرابط.
class MediaService {
  static const _cloudName = 'dubxerhck';
  static const _uploadPreset = 'o4rrcmxe';
  static final _col = FirebaseFirestore.instance.collection('media');

  static String _contentType(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'mp3' => 'audio/mpeg',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'ogg' => 'audio/ogg',
      'opus' => 'audio/opus',
      'amr' => 'audio/amr',
      '3gp' => 'audio/3gpp',
      'flac' => 'audio/flac',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'svg' => 'image/svg+xml',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'webm' => 'video/webm',
      _ => 'application/octet-stream',
    };
  }

  static const _audioExt = ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'opus', 'amr', '3gp', 'flac'];
  static const _anyExt = [..._audioExt, 'png', 'jpg', 'jpeg', 'webp', 'gif', 'mp4', 'mov', 'webm'];
  static bool _picking = false;

  /// يفتح اختيار ملف، يرفعه، ويعرض التقدم. يرجع الرابط أو null.
  static Future<String?> pickAndUpload(BuildContext context, {MediaKind kind = MediaKind.any, String folder = 'media'}) async {
    // ضغطة تانية والاختيار لسه مفتوح بتلغي الأولى بخطأ multiple_request.
    if (_picking) return null;
    _picking = true;
    FilePickerResult? res;
    try {
      // على iOS الصوت والملفات العامة بـ custom علشان يفتح تطبيق الملفات بدل مكتبة الموسيقى.
      // على أندرويد custom بيحوّل الامتدادات لـ MIME وبيقفل ملفات صوت كتير (زي تسجيلات الموبايل)، فبنستخدم فلتر النظام.
      final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
      res = await FilePicker.platform.pickFiles(
        withData: true,
        type: switch (kind) {
          MediaKind.image => FileType.image,
          MediaKind.video => FileType.video,
          MediaKind.audio => ios ? FileType.custom : FileType.audio,
          MediaKind.any => ios ? FileType.custom : FileType.any,
        },
        allowedExtensions: ios ? switch (kind) { MediaKind.audio => _audioExt, MediaKind.any => _anyExt, _ => null } : null,
      );
    } catch (e) {
      debugPrint('file picker failed: $e');
      if (context.mounted) toast(context, 'مقدرناش نفتح اختيار الملفات، جرّب تاني', error: true);
      return null;
    } finally {
      _picking = false;
    }
    final f = res?.files.single;
    if (f == null || f.bytes == null) return null;
    final type = _contentType(f.name);
    if (!type.startsWith('audio/') && !type.startsWith('image/') && !type.startsWith('video/')) {
      if (context.mounted) toast(context, 'نوع الملف مش مدعوم', error: true);
      return null;
    }
    if (f.size > 50 * 1024 * 1024) {
      if (context.mounted) toast(context, 'الملف أكبر من 50 ميجا', error: true);
      return null;
    }
    final progress = ValueNotifier<double?>(null);
    final cancel = CancelToken();
    // الصوت بيترفع على Cloudinary كـ video، فـ auto بيختار النوع الصح.
    final upload = Dio().post<Map<String, dynamic>>(
      'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload',
      data: FormData.fromMap({
        'upload_preset': _uploadPreset,
        'folder': 'ahadith/$folder',
        'file': MultipartFile.fromBytes(f.bytes!, filename: f.name),
      }),
      cancelToken: cancel,
      onSendProgress: (sent, total) => progress.value = total <= 0 ? null : sent / total,
    );
    if (!context.mounted) return null;
    String? url;
    Object? error;
    upload.then((r) => url = r.data?['secure_url'] as String?, onError: (Object e) => error = e).whenComplete(() {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    });
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('جاري الرفع…'),
        content: ValueListenableBuilder<double?>(valueListenable: progress, builder: (_, v, __) => LinearProgressIndicator(value: v)),
        actions: [TextButton(onPressed: () => cancel.cancel(), child: const Text('إلغاء'))],
      ),
    );
    if (url == null) {
      if (error != null) debugPrint('cloudinary upload failed: $error');
      if (context.mounted) toast(context, 'الرفع ما كملش', error: true);
      return null;
    }
    await _col.add({'name': f.name, 'url': url, 'type': type, 'size': f.size, 'createdAt': FieldValue.serverTimestamp()});
    return url;
  }

  static Future<List<MediaItem>> list() async {
    final snap = await _col.orderBy('createdAt', descending: true).get();
    return [for (final d in snap.docs) MediaItem(id: d.id, name: (d.data()['name'] ?? '') as String, url: (d.data()['url'] ?? '') as String)];
  }

  /// بيشيل الملف من القائمة بس. مسح الملف نفسه من Cloudinary محتاج الـ API secret،
  /// فده يتعمل من console.cloudinary.com لو احتجنا.
  static Future<void> delete(MediaItem item) => _col.doc(item.id).delete();
}

/// حقل رابط ملف + زرار رفع + زرار مسح.
class MediaField extends StatelessWidget {
  const MediaField({super.key, required this.label, required this.url, required this.onChanged, this.kind = MediaKind.any});
  final String label;
  final String url;
  final ValueChanged<String> onChanged;
  final MediaKind kind;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(kind == MediaKind.audio ? Icons.audiotrack_rounded : (kind == MediaKind.image ? Icons.image_rounded : Icons.perm_media_rounded)),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(url.isEmpty ? 'مفيش ملف' : url, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      ),
      IconButton(
        tooltip: 'رفع',
        onPressed: () async {
          final u = await MediaService.pickAndUpload(context, kind: kind);
          if (u != null) onChanged(u);
        },
        icon: const Icon(Icons.upload_rounded),
      ),
      if (url.isNotEmpty) IconButton(tooltip: 'امسح', onPressed: () => onChanged(''), icon: const Icon(Icons.close_rounded)),
    ]);
  }
}

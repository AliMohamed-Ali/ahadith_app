import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';

import '../ui.dart';

/// إرسال إشعار لكل أجهزة الأطفال (عن طريق الدالة السحابية sendKidsNotification).
class NotifyScreen extends StatefulWidget {
  const NotifyScreen({super.key});
  @override
  State<NotifyScreen> createState() => _NotifyScreenState();
}

class _NotifyScreenState extends State<NotifyScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _busy = false;
  final _log = FirebaseFirestore.instance.collection('notificationsLog').orderBy('at', descending: true).limit(20).snapshots();

  Future<void> _send() async {
    if (_title.text.trim().isEmpty) {
      toast(context, 'اكتبي العنوان', error: true);
      return;
    }
    final ok = await confirm(context, 'إرسال لكل الأطفال؟', '«${_title.text.trim()}»\n${_body.text.trim()}', ok: 'ابعتي');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final sent = await run(context, () async {
      await FirebaseFunctions.instanceFor(region: 'europe-west1').httpsCallable('sendKidsNotification').call({'title': _title.text.trim(), 'body': _body.text.trim()});
    }, done: 'اتبعت ✓');
    if (!mounted) return;
    setState(() => _busy = false);
    if (sent) {
      _title.clear();
      _body.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        FormSection(title: 'إشعار جديد', icon: Icons.notifications_active_rounded, color: AppColors.goldDark, children: [
          TF(_title, 'العنوان (مثلًا: حديث جديد مستنيك! 🌙)'),
          TF(_body, 'الرسالة', lines: 2),
          FilledButton.icon(onPressed: _busy ? null : _send, icon: const Icon(Icons.send_rounded), label: const Text('إرسال')),
          const Text('محتاج خطة Blaze في Firebase عشان الدالة السحابية تشتغل.', style: TextStyle(color: Colors.black54, fontSize: 12)),
        ]),
        const Padding(padding: EdgeInsets.all(8), child: Text('آخر الإشعارات', style: TextStyle(fontWeight: FontWeight.w800))),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _log,
          builder: (context, snap) {
            final docs = snap.data?.docs ?? const [];
            if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('مفيش إشعارات اتبعتت لسه.'));
            return Column(children: [
              for (final d in docs)
                Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: cardShape,
                  child: ListTile(
                    title: Text('${d.data()['title'] ?? ''}'),
                    subtitle: Text('${d.data()['body'] ?? ''}'),
                    trailing: Text(_date(d.data()['at']), style: const TextStyle(fontSize: 12)),
                  ),
                ),
            ]);
          },
        ),
      ]),
    );
  }

  String _date(Object? v) {
    if (v is! Timestamp) return '';
    final d = v.toDate();
    return '${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
  }
}

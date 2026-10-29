import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../ui.dart';

/// التحديث الإجباري والمقترح لأبلكيشن الأطفال (config/update).
class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});
  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  late final repo = context.read<ContentRepository>();
  final c = <String, TextEditingController>{};
  bool _loaded = false;

  TextEditingController t(String k) => c.putIfAbsent(k, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    repo.updateConfig().first.then((u) {
      if (!mounted) return;
      String n(int v) => v == 0 ? '' : '$v';
      t('minBuildAndroid').text = n(u.minBuildAndroid);
      t('minBuildIos').text = n(u.minBuildIos);
      t('latestBuildAndroid').text = n(u.latestBuildAndroid);
      t('latestBuildIos').text = n(u.latestBuildIos);
      t('androidUrl').text = u.androidUrl;
      t('iosUrl').text = u.iosUrl;
      t('messageAr').text = u.messageAr;
      t('messageEn').text = u.messageEn;
      setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  int _n(String k) => int.tryParse(t(k).text.trim()) ?? 0;

  Future<void> _save() async {
    final u = UpdateConfig(
      minBuildAndroid: _n('minBuildAndroid'),
      minBuildIos: _n('minBuildIos'),
      latestBuildAndroid: _n('latestBuildAndroid'),
      latestBuildIos: _n('latestBuildIos'),
      androidUrl: t('androidUrl').text.trim(),
      iosUrl: t('iosUrl').text.trim(),
      messageAr: t('messageAr').text.trim(),
      messageEn: t('messageEn').text.trim(),
    );
    if (u.minBuildAndroid > 0 || u.minBuildIos > 0) {
      final ok = await confirm(
        context,
        'تحديث إجباري',
        'أي طفل عنده نسخة أقدم من '
            '${u.minBuildAndroid > 0 ? 'أندرويد ${u.minBuildAndroid}' : ''}'
            '${u.minBuildAndroid > 0 && u.minBuildIos > 0 ? ' / ' : ''}'
            '${u.minBuildIos > 0 ? 'آيفون ${u.minBuildIos}' : ''}'
            ' الأبلكيشن هيتقفل عنده لحد ما يحدّث.\n\nاتأكدي إن النسخة الجديدة نزلت على المتجر الأول.',
        ok: 'احفظي',
        danger: true,
      );
      if (!ok || !mounted) return;
    }
    await run(context, () => repo.saveUpdateConfig(u));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('تحديث الأبلكيشن')),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: _loaded ? _save : null, child: const Text('حفظ')),
          ),
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                const Card(
                  color: Color(0xFFFFF6E0),
                  elevation: 0,
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'رقم النسخة = الرقم اللي بعد + في version في pubspec.yaml بتاع أبلكيشن الأطفال.\n'
                      'مثلاً version: 1.0.0+3 يبقى رقمها 3.\n\n'
                      '• أقل نسخة مسموح بيها: أي نسخة أقدم بتتقفل خالص لحد ما الطفل يحدّث (إجباري).\n'
                      '• آخر نسخة: أي نسخة أقدم بيظهرلها شريط «فيه تحديث جديد» ويقدر يقفله بـ «بعدين».\n'
                      '• سيبي الخانة فاضية أو 0 عشان تقفلي الخاصية دي.',
                      style: TextStyle(height: 1.6),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FormSection(title: 'أندرويد', icon: Icons.android_rounded, children: [
                  TF(t('minBuildAndroid'), 'أقل نسخة مسموح بيها (إجباري)', number: true, ltr: true),
                  TF(t('latestBuildAndroid'), 'آخر نسخة (اقتراح تحديث)', number: true, ltr: true),
                  TF(t('androidUrl'), 'رابط جوجل بلاي (اختياري)', ltr: true, hint: 'لو فاضي بيتعمل تلقائي من اسم الباكدج'),
                ]),
                FormSection(title: 'آيفون', icon: Icons.phone_iphone_rounded, color: AppColors.navy, children: [
                  TF(t('minBuildIos'), 'أقل نسخة مسموح بيها (إجباري)', number: true, ltr: true),
                  TF(t('latestBuildIos'), 'آخر نسخة (اقتراح تحديث)', number: true, ltr: true),
                  TF(t('iosUrl'), 'رابط آب ستور', ltr: true, hint: 'https://apps.apple.com/app/id...'),
                ]),
                FormSection(title: 'رسالة التحديث الإجباري (اختياري)', icon: Icons.chat_rounded, color: AppColors.goldDark, children: [
                  TF(t('messageAr'), 'بالعربي', lines: 2, hint: 'لو فاضية بتظهر الرسالة العادية'),
                  TF(t('messageEn'), 'بالإنجليزي', lines: 2, ltr: true),
                ]),
              ]),
      );
}

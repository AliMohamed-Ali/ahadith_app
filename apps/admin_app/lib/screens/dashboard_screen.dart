import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../services/seed_service.dart';
import '../ui.dart';
import 'bukhari_screen.dart';
import 'media_screen.dart';
import 'notify_screen.dart';
import 'rewards_screen.dart';
import 'tabs_screen.dart';
import 'update_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final repo = context.read<ContentRepository>();
  late final Stream<List<AppTab>> _tabs = repo.tabs();
  // عدّ بس من غير ما نحمّل الأحاديث (البخاري لوحده آلاف)
  late final Future<List<int>> _counts = Future.wait([repo.countHadiths(), repo.countHadiths(published: true)]);

  void _go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Future<void> _seed() async {
    final overwrite = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('استيراد المحتوى الأولي'),
        content: const Text('هيضيف: المستويات (١٠ أحاديث)، الأربعين النووية كاملة (٤٢)، أقسام «ما لا يسع أطفال المسلمين جهله» (٧ أقسام)، وإعدادات النجوم والمتجر.\n\nلو فيه حاجات عدلتيها قبل كده، اختاري «المحتوى الناقص بس» عشان ما يتكتبش فوقها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          OutlinedButton(onPressed: () => Navigator.pop(c, true), child: const Text('استبدال الكل')),
          FilledButton(onPressed: () => Navigator.pop(c, false), child: const Text('المحتوى الناقص بس')),
        ],
      ),
    );
    if (overwrite == null || !mounted) return;
    try {
      final r = await SeedService(FirebaseFirestore.instance).import(overwrite: overwrite);
      if (mounted) toast(context, 'تم ✓ اتكتب ${r['written']} مستند');
    } catch (e) {
      if (mounted) toast(context, 'حصل خطأ: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التحكم'),
        actions: [IconButton(tooltip: 'خروج', onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout_rounded))],
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        FutureBuilder<List<int>>(
          future: _counts,
          builder: (context, hs) => StreamBuilder<List<AppTab>>(
            stream: _tabs,
            builder: (context, ts) {
              final c = hs.data;
              return Row(children: [
                _Stat(label: 'تبويبات', value: '${ts.data?.length ?? '…'}', color: AppColors.navy),
                _Stat(label: 'أحاديث منشورة', value: c == null ? '…' : '${c[1]}', color: AppColors.teal),
                _Stat(label: 'مسودات', value: c == null ? '…' : '${c[0] - c[1]}', color: AppColors.goldDark),
              ]);
            },
          ),
        ),
        const SizedBox(height: 16),
        _Tile(icon: Icons.tab_rounded, color: AppColors.teal, title: 'المحتوى والتبويبات', sub: 'التبويبات، المستويات، الأحاديث، الأسئلة', onTap: () => _go(const TabsScreen())),
        _Tile(icon: Icons.menu_book_rounded, color: const Color(0xFF7558D6), title: 'صحيح البخاري', sub: 'استيراد، ومراجعة الأحاديث لكل سن، والنشر', onTap: () => _go(const BukhariAdminScreen())),
        _Tile(icon: Icons.workspace_premium_rounded, color: AppColors.royal, title: 'النجوم والجوائز', sub: 'النجوم العادية والملكية ومتجر فانوس', onTap: () => _go(const RewardsScreen())),
        _Tile(icon: Icons.perm_media_rounded, color: AppColors.coral, title: 'الوسائط', sub: 'رفع صوت وصور وفيديو', onTap: () => _go(const MediaScreen())),
        _Tile(icon: Icons.system_update_rounded, color: AppColors.teal, title: 'تحديث الأبلكيشن', sub: 'تحديث إجباري أو اقتراح تحديث لأبلكيشن الأطفال', onTap: () => _go(const UpdateScreen())),
        _Tile(icon: Icons.notifications_active_rounded, color: AppColors.goldDark, title: 'الإشعارات', sub: 'ابعتي إشعار لكل الأطفال', onTap: () => _go(const NotifyScreen())),
        _Tile(icon: Icons.cloud_download_rounded, color: AppColors.navy, title: 'استيراد المحتوى الأولي', sub: 'مرة واحدة في البداية', onTap: _seed),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          color: Colors.white,
          elevation: 0,
          shape: cardShape,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
            ]),
          ),
        ),
      );
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.color, required this.title, required this.sub, required this.onTap});
  final IconData icon;
  final Color color;
  final String title, sub;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        elevation: 0,
        shape: cardShape,
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(backgroundColor: color.withOpacity(.12), child: Icon(icon, color: color)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(sub),
          trailing: const Icon(Icons.chevron_left_rounded),
          onTap: onTap,
        ),
      );
}

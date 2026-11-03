import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../services/sounds.dart';
import '../state/progress_store.dart';
import '../widgets/fanoos.dart';
import 'fanoos_screen.dart';
import 'garden_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'tab_router.dart';

/// الهيكل الأساسي: شريط سفلي = الرئيسية + التبويبات التي اختار المدير مكانها "تبويب" + الحديقة + فانوس + ملفي.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  late final Stream<List<AppTab>> _tabs = context.read<ContentRepository>().tabs(onlyVisible: true);

  @override
  void initState() {
    super.initState();
    // الطفل راجع تاني: فانوس بيرحّب بيه
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<ProgressStore>();
      if (mounted && (p.profile != null || p.doneCount.isNotEmpty)) _welcomeBack(p);
      // مهمات الأحاديث اللي الطفل خلّصها قبل ما المهمة تتضاف
      if (p.doneCount.isNotEmpty) {
        context.read<ContentRepository>().hadithsByIds(p.doneCount.keys).then(p.syncMissions).catchError((Object e) => debugPrint('missions sync failed: $e'));
      }
    });
  }

  Future<void> _welcomeBack(ProgressStore p) async {
    final ar = S.ar(context);
    final name = p.profile?.name.trim() ?? '';
    final line = S.of(context, 'welcomeBack${math.Random().nextInt(5) + 1}', {'name': name.isEmpty ? S.of(context, 'champ') : name});
    Sounds.play(Sfx.star);
    await showDialog<void>(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Fanoos(size: 100, mood: FanoosMood.happy),
            const SizedBox(height: 10),
            Text(S.of(c, 'welcomeBackTitle'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.teal)),
            const SizedBox(height: 6),
            Text(line, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 1.5)),
            if (p.doneCount.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(S.of(c, 'welcomeBackCount', {'n': arNum(p.doneCount.length, arabic: ar)}), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, color: AppColors.muted)),
            ],
            const SizedBox(height: 14),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: () => Navigator.pop(c), child: Text(S.of(c, 'letsContinue'))),
          ]),
        ),
      ),
    );
  }

  void goTo(int i) {
    if (i != _index) Sounds.play(Sfx.tap);
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    return StreamBuilder<List<AppTab>>(
      stream: _tabs,
      builder: (context, snap) {
        final all = snap.data ?? const <AppTab>[];
        final navTabs = all.where((t) => t.place == 'tab').toList();
        final pages = <Widget>[
          HomeScreen(tabs: all, onOpenFanoos: () => goTo(navTabs.length + 2)),
          for (final t in navTabs) TabBody(tab: t),
          const GardenScreen(),
          const FanoosScreen(),
          const ProfileScreen(),
        ];
        final items = <NavigationDestination>[
          NavigationDestination(icon: const Icon(Icons.home_rounded), label: S.of(context, 'navHome')),
          for (final t in navTabs) NavigationDestination(icon: Icon(t.isQa ? Icons.lightbulb_rounded : Icons.menu_book_rounded, color: hexColor(t.color)), label: _short(t.name(ar))),
          NavigationDestination(icon: const Icon(Icons.local_florist_rounded), label: S.of(context, 'navGarden')),
          NavigationDestination(icon: const Icon(Icons.emoji_objects_rounded), label: S.of(context, 'navFanoos')),
          NavigationDestination(icon: const Icon(Icons.face_rounded), label: S.of(context, 'navProfile')),
        ];
        final i = _index.clamp(0, pages.length - 1);
        return Scaffold(
          body: IndexedStack(index: i, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: i,
            height: 70,
            backgroundColor: Colors.white,
            indicatorColor: AppColors.cream,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: goTo,
            destinations: items,
          ),
        );
      },
    );
  }

  /// أسماء التبويبات الطويلة (مثل "ما لا يسع أطفال المسلمين جهله") تُختصر في الشريط.
  String _short(String s) {
    final words = s.split(' ');
    return words.length <= 2 ? s : '${words.take(2).join(' ')}…';
  }
}

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../services/sounds.dart';
import '../l10n.dart';
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

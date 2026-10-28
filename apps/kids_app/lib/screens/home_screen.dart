import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/progress_store.dart';
import '../widgets/animated_dropdown.dart';
import '../widgets/common.dart';
import '../widgets/fanoos.dart';
import '../widgets/my_fanoos.dart';
import '../theme.dart';
import 'intro_screen.dart';
import 'missions_screen.dart';
import 'tab_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.tabs, required this.onOpenFanoos});
  final List<AppTab> tabs;
  final VoidCallback onOpenFanoos;

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final p = context.watch<ProgressStore>();
    final cfg = context.watch<AppConfig>();
    final stars = p.normalStars(cfg.rewards);
    final royal = p.royalStars(cfg.rewards);
    // ترتيب الصفحة: تعرّف على الحديث، ثم تبويبات الأسئلة (ما لا يسع...)، ثم باقي التبويبات المحطوطة في الرئيسية.
    final qaTabs = tabs.where((t) => t.isQa).toList();
    final homeHadith = tabs.where((t) => t.isHadith && t.place == 'home').toList();
    var d = 0;
    int next() => (d++) * 70;

    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: _Hero(name: p.profile?.name ?? '', stars: stars, royal: royal)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        sliver: SliverList.list(children: [
          RiseIn(
            delay: next(),
            child: _WideCard(
              color: AppColors.teal,
              shadow: AppColors.tealDark,
              icon: Icons.auto_stories_rounded,
              title: S.of(context, 'introTitle'),
              sub: S.of(context, 'introSub'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IntroScreen())),
            ),
          ),
          for (final t in qaTabs)
            RiseIn(
              delay: next(),
              child: _WideCard(
                color: hexColor(t.color, AppColors.royal),
                shadow: Colors.black26,
                icon: Icons.lightbulb_rounded,
                title: t.name(ar),
                sub: S.of(context, 'qaSub'),
                onTap: () => openTab(context, t),
              ),
            ),
          for (final t in homeHadith)
            RiseIn(delay: next(), child: t.hasLevels ? _LevelsCard(tab: t) : _OpenTabCard(tab: t)),
          if (p.pendingMissions.isNotEmpty)
            RiseIn(
              delay: next(),
              child: _WideCard(
                color: AppColors.coral,
                shadow: const Color(0xFFB4401F),
                icon: Icons.flag_rounded,
                title: S.of(context, 'pendingMission'),
                sub: S.of(context, 'pendingMissionSub', {'n': arNum(p.pendingMissions.length, arabic: ar)}),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MissionsScreen())),
              ),
            ),
          RiseIn(delay: next(), child: _GiftsCard(stars: stars, royal: royal, onTap: onOpenFanoos)),
        ]),
      ),
    ]);
  }
}

/// الجزء العلوي (صغير): فانوس + ترحيب + النجوم + زر اللغة.
class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.stars, required this.royal});
  final String name;
  final int stars;
  final int royal;

  @override
  Widget build(BuildContext context) {
    final p = context.read<ProgressStore>();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.navy, AppColors.navy2], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, 16),
      child: Row(children: [
        const MyFanoos(size: 58, mood: FanoosMood.happy),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              name.isEmpty ? S.of(context, 'helloHero') : S.of(context, 'helloName', {'name': name}),
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [StarPill(count: stars, dense: true), StarPill(count: royal, royal: true, dense: true)]),
          ]),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.white24, shape: const StadiumBorder()),
          onPressed: () => p.setLang(p.ar ? 'en' : 'ar'),
          child: Text(p.ar ? 'EN' : 'ع', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _WideCard extends StatelessWidget {
  const _WideCard({required this.color, required this.shadow, required this.icon, required this.title, required this.sub, required this.onTap});
  final Color color;
  final Color shadow;
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = onColor(color);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: BigTile(
        color: color,
        shadow: shadow,
        onTap: onTap,
        child: Row(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: Colors.white.withOpacity(.22), borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: fg, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w800)),
              Text(sub, style: TextStyle(color: fg.withOpacity(.9), fontSize: 14)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// كارت التبويب الذي فيه مستويات: قائمة منسدلة متحركة بالمستويات.
class _LevelsCard extends StatefulWidget {
  const _LevelsCard({required this.tab});
  final AppTab tab;
  @override
  State<_LevelsCard> createState() => _LevelsCardState();
}

class _LevelsCardState extends State<_LevelsCard> {
  late final Stream<List<Level>> _levels = context.read<ContentRepository>().levels(widget.tab.id);

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final tab = widget.tab;
    final p = context.watch<ProgressStore>();
    final c = hexColor(tab.color, AppColors.gold);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: cardBox(shadow: c.withOpacity(.6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.stairs_rounded, color: c, size: 30),
          const SizedBox(width: 8),
          Expanded(child: Text(tab.name(ar), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 4),
        Text(S.of(context, 'chooseLevel'), style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 10),
        StreamBuilder<List<Level>>(
          stream: _levels,
          builder: (context, snap) {
            final levels = snap.data ?? const <Level>[];
            return AnimatedDropdown<Level>(
              items: levels,
              icon: Icons.stairs_rounded,
              placeholder: S.of(context, 'chooseLevelPh'),
              labelOf: (l) {
                final done = p.completedLevels.contains(l.id) ? ' 👑' : '';
                final age = l.age(ar).isEmpty ? '' : ' · ${l.age(ar)}';
                return '${l.name(ar)}$age$done';
              },
              onChanged: (l) => openLevel(context, tab, l),
            );
          },
        ),
      ]),
    );
  }
}

class _OpenTabCard extends StatelessWidget {
  const _OpenTabCard({required this.tab});
  final AppTab tab;
  @override
  Widget build(BuildContext context) {
    final c = hexColor(tab.color, AppColors.navy);
    return _WideCard(
      color: c,
      shadow: Color.lerp(c, Colors.black, .35)!,
      icon: Icons.menu_book_rounded,
      title: tab.name(S.ar(context)),
      sub: S.of(context, tab.isAges ? 'bkSub' : 'openTabSub'),
      onTap: () => openTab(context, tab),
    );
  }
}

class _GiftsCard extends StatelessWidget {
  const _GiftsCard({required this.stars, required this.royal, required this.onTap});
  final int stars;
  final int royal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final cfg = context.watch<AppConfig>().rewards;
    final lv = RewardsCalculator(cfg).fanoosLevel(stars);
    final nextAt = lv + 1 < cfg.fanoosLevels.length ? cfg.fanoosLevels[lv + 1] : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: BigTile(
        color: AppColors.royalSoft,
        shadow: const Color(0xFFD9C2F5),
        onTap: onTap,
        child: Row(children: [
          const RoyalStarIcon(size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(S.of(context, 'giftsTitle'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.royalDark)),
              Text(
                nextAt == null ? S.of(context, 'fanoosMax') : S.of(context, 'fanoosNext', {'n': arNum(nextAt - stars, arabic: ar)}),
                style: const TextStyle(color: AppColors.royalDark),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

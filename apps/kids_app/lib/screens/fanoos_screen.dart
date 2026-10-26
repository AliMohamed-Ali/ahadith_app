import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/progress_store.dart';
import '../widgets/common.dart';
import '../widgets/fanoos.dart';
import '../widgets/my_fanoos.dart';
import '../theme.dart';

/// فانوس: صاحب الطفل. الألوان والزينة تتفتح بالنجوم العادية أو الملكية (السعر = عدد النجوم المطلوب).
class FanoosScreen extends StatelessWidget {
  const FanoosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final p = context.watch<ProgressStore>();
    final cfg = context.watch<AppConfig>();
    final stars = p.normalStars(cfg.rewards);
    final royal = p.royalStars(cfg.rewards);
    final lv = RewardsCalculator(cfg.rewards).fanoosLevel(stars);
    final colors = cfg.shop.where((s) => s.kind == 'color').toList();
    final acc = cfg.shop.where((s) => s.kind == 'accessory').toList();
    bool unlocked(ShopItem s) => (s.isRoyal ? royal : stars) >= s.price;

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        Text(S.of(context, 'fanoosTitle'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: cardBox(color: AppColors.navy, shadow: const Color(0xFF0F1A40), radius: 30),
          child: Row(children: [
            const MyFanoos(size: 110, mood: FanoosMood.happy),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(S.of(context, 'fanoosLevel', {'n': arNum(lv + 1, arabic: ar)}), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [StarPill(count: stars), StarPill(count: royal, royal: true)]),
                const SizedBox(height: 8),
                Text(S.of(context, 'royalHow'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Text(S.of(context, 'colors'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final s in colors)
            _ShopTile(
              item: s,
              unlocked: unlocked(s),
              selected: p.fanColor == s.id,
              onTap: () => unlocked(s) ? p.setFanColor(s.id) : _lockedMsg(context, s),
              child: Fanoos(size: 40, color: hexColor(s.hex), swing: false),
            ),
        ]),
        if (acc.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(S.of(context, 'accessories'), style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final s in acc)
              _ShopTile(
                item: s,
                unlocked: unlocked(s),
                selected: p.wearing.contains(s.id),
                onTap: () => unlocked(s) ? p.toggleWear(s.id) : _lockedMsg(context, s),
                child: Fanoos(size: 40, swing: false, crown: s.id == 'crown', bow: s.id == 'bow', halo: s.id == 'halo'),
              ),
          ]),
        ],
      ]),
    );
  }

  void _lockedMsg(BuildContext context, ShopItem s) {
    final ar = S.ar(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: s.isRoyal ? AppColors.royalDark : AppColors.goldDark,
      content: Text(S.of(context, s.isRoyal ? 'needRoyal' : 'needStars', {'n': arNum(s.price, arabic: ar)})),
    ));
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.item, required this.unlocked, required this.selected, required this.onTap, required this.child});
  final ShopItem item;
  final bool unlocked;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: item.isRoyal ? AppColors.royalSoft : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.teal : Colors.transparent, width: 3),
          boxShadow: const [BoxShadow(color: AppColors.mintLine, offset: Offset(0, 4))],
        ),
        child: Column(children: [
          Stack(alignment: Alignment.center, children: [
            Opacity(opacity: unlocked ? 1 : .35, child: child),
            if (!unlocked) const Icon(Icons.lock_rounded, color: AppColors.navy),
          ]),
          const SizedBox(height: 4),
          Text(item.name(ar), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (!unlocked) StarPill(count: item.price, royal: item.isRoyal, dense: true),
          if (unlocked && selected) const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 20),
        ]),
      ),
    );
  }
}

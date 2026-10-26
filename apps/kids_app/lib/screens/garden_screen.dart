import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/progress_store.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/fanoos.dart';
import '../theme.dart';
import 'missions_screen.dart';

/// حديقة الحسنات: نبتة لكل حديث، تكبر مع كل مراجعة، وفراشة لكل مهمة اتعملت.
class GardenScreen extends StatefulWidget {
  const GardenScreen({super.key});
  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen> with SingleTickerProviderStateMixin {
  late final Stream<List<Hadith>> _all = context.read<ContentRepository>().allHadiths();
  late final AnimationController _fly = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
  static const _petals = [Color(0xFFF27BA6), Color(0xFFFF8A3D), Color(0xFF9B7BEA), Color(0xFF4FA8F0), Color(0xFFE8573A)];

  @override
  void dispose() {
    _fly.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final p = context.watch<ProgressStore>();
    final cfg = context.watch<AppConfig>().rewards;
    final calc = RewardsCalculator(cfg);
    final ids = p.doneCount.keys.toList();
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFCDEBFF), Color(0xFFDFF3E4)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
      child: SafeArea(
        bottom: false,
        child: StreamBuilder<List<Hadith>>(
          stream: _all,
          builder: (context, snap) {
            final titles = {for (final h in snap.data ?? const <Hadith>[]) h.id: h.title(ar)};
            return CustomScrollView(slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(children: [
                    Expanded(child: Text(S.of(context, 'gardenTitle'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.coral, minimumSize: const Size(48, 44)),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MissionsScreen())),
                      icon: const Icon(Icons.flag_rounded),
                      label: Text(S.of(context, 'missions')),
                    ),
                  ]),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 90,
                  child: AnimatedBuilder(
                    animation: _fly,
                    builder: (context, _) => Stack(children: [
                      for (var i = 0; i < math.min(p.butterflies, 12); i++)
                        Positioned(
                          left: (MediaQuery.sizeOf(context).width - 40) * ((_fly.value + i * 0.17) % 1),
                          top: 30 + math.sin((_fly.value * 2 * math.pi) * 3 + i) * 22,
                          child: CustomPaint(size: const Size(32, 26), painter: _ButterflyPainter(_petals[i % _petals.length], math.sin(_fly.value * 120 + i).abs())),
                        ),
                      Positioned(
                        right: 16,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                          child: Text(S.of(context, 'butterflies', {'n': arNum(p.butterflies, arabic: ar)}), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
              if (ids.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Fanoos(size: 90, mood: FanoosMood.talk),
                      const SizedBox(height: 12),
                      Text(S.of(context, 'gardenEmpty'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 19)),
                    ]),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 130, mainAxisExtent: 150, crossAxisSpacing: 8, mainAxisSpacing: 8),
                    itemCount: ids.length,
                    itemBuilder: (context, i) {
                      final id = ids[i];
                      final w = p.wins(id);
                      return RiseIn(
                        delay: math.min(i, 12) * 40,
                        child: Container(
                          decoration: cardBox(color: Colors.white.withOpacity(.85), radius: 20),
                          padding: const EdgeInsets.all(6),
                          child: Column(children: [
                            Expanded(child: PlantView(stage: calc.plantStage(w), petal: _petals[i % _petals.length], size: 64)),
                            Text(titles[id] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            Text(S.of(context, 'reviews', {'n': arNum(w, arabic: ar)}), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
            ]);
          },
        ),
      ),
    );
  }
}

/// فراشة صغيرة بجناحين يرفرفوا.
class _ButterflyPainter extends CustomPainter {
  _ButterflyPainter(this.color, this.flap);
  final Color color;
  final double flap;
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final w = s.width / 2 * (0.45 + 0.55 * flap);
    final p = Paint()..color = color;
    canvas.drawOval(Rect.fromLTWH(c.dx - w, 0, w, s.height * .6), p);
    canvas.drawOval(Rect.fromLTWH(c.dx, 0, w, s.height * .6), p);
    canvas.drawOval(Rect.fromLTWH(c.dx - w * .8, s.height * .45, w * .8, s.height * .5), p);
    canvas.drawOval(Rect.fromLTWH(c.dx, s.height * .45, w * .8, s.height * .5), p);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 4, height: s.height * .9), const Radius.circular(2)), Paint()..color = AppColors.navy);
  }

  @override
  bool shouldRepaint(covariant _ButterflyPainter old) => old.flap != flap || old.color != color;
}

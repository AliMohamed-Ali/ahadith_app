import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/progress_store.dart';
import '../theme.dart';
import 'common.dart';
import 'fanoos.dart';

/// كنوز الواحة: كل حديث جديد الطفل يخلّصه بيكسبه كنز (بالترتيب، ولما يخلصوا بيرجعوا من الأول).
class Treasure {
  const Treasure(this.emoji, this.ar, this.en);
  final String emoji, ar, en;
  String name(bool isAr) => isAr ? ar : en;
}

const treasures = <Treasure>[
  Treasure('🌴', 'نخلة', 'Palm tree'),
  Treasure('🌙', 'هلال', 'Crescent'),
  Treasure('🏮', 'فانوس', 'Lantern'),
  Treasure('⭐', 'نجمة', 'Star'),
  Treasure('🐪', 'جمل', 'Camel'),
  Treasure('🕌', 'مسجد', 'Mosque'),
  Treasure('🕊️', 'حمامة', 'Dove'),
  Treasure('🌹', 'وردة', 'Rose'),
  Treasure('⛺', 'خيمة', 'Tent'),
  Treasure('💧', 'عين ميه', 'Spring'),
  Treasure('🐑', 'خروف', 'Sheep'),
  Treasure('🌳', 'شجرة', 'Tree'),
];

/// الكنز رقم i (من 0) اللي الطفل كسبه.
Treasure treasureAt(int i) => treasures[i % treasures.length];

/// الكنز بيطلع بنطة من وسط نور بيلف (في شاشة الفوز).
class TreasureReveal extends StatefulWidget {
  const TreasureReveal({super.key, required this.treasure});
  final Treasure treasure;
  @override
  State<TreasureReveal> createState() => _TreasureRevealState();
}

class _TreasureRevealState extends State<TreasureReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  late final DateTime _start = DateTime.now();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final since = DateTime.now().difference(_start).inMilliseconds / 1000;
          final pop = Curves.elasticOut.transform((since / 1.1).clamp(0.0, 1.0));
          return SizedBox(
            width: 130,
            height: 110,
            child: Stack(alignment: Alignment.center, children: [
              Transform.rotate(angle: _c.value * math.pi * 2, child: CustomPaint(size: const Size(130, 130), painter: _RaysPainter())),
              Transform.scale(scale: .2 + .8 * pop, child: Text(widget.treasure.emoji, style: const TextStyle(fontSize: 62))),
            ]),
          );
        },
      );
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero);
    c.drawCircle(center, 38, Paint()..color = AppColors.gold.withOpacity(.35));
    final ray = Paint()..color = AppColors.gold.withOpacity(.28);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final p = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + math.cos(a - .12) * 64, center.dy + math.sin(a - .12) * 64)
        ..lineTo(center.dx + math.cos(a + .12) * 64, center.dy + math.sin(a + .12) * 64)
        ..close();
      c.drawPath(p, ray);
    }
  }

  @override
  bool shouldRepaint(covariant _RaysPainter old) => false;
}

/// «واحتي»: صحرا فيها بحيرة، وكل كنز الطفل جمعه متحط فيها.
class OasisScreen extends StatefulWidget {
  const OasisScreen({super.key});
  @override
  State<OasisScreen> createState() => _OasisScreenState();
}

class _OasisScreenState extends State<OasisScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  static double _hash(int k) => (math.sin(k * 91.7) * 43758.5453).remainder(1).abs();

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final p = context.watch<ProgressStore>();
    final earned = p.doneCount.length;
    final counts = List.filled(treasures.length, 0);
    for (var i = 0; i < earned; i++) {
      counts[i % treasures.length]++;
    }
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context, 'oasisTitle')), backgroundColor: const Color(0xFFC27A10)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // الواحة نفسها
        LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          const h = 330.0;
          final shown = math.min(earned, 60);
          return AnimatedBuilder(
            animation: _clock,
            builder: (context, _) {
              final t = _clock.value * 60;
              return ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Stack(children: [
                    Positioned.fill(child: CustomPaint(painter: _OasisPainter(t))),
                    if (earned == 0)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Fanoos(size: 70, mood: FanoosMood.talk),
                            const SizedBox(height: 8),
                            Text(S.of(context, 'oasisEmpty'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy)),
                          ]),
                        ),
                      ),
                    for (var i = 0; i < shown; i++)
                      Positioned(
                        left: 14 + _hash(i) * (w - 60),
                        // الكنوز على الرملة حوالين البحيرة (مش في السما)
                        top: 130 + _hash(i + 300) * (h - 180) + math.sin(t * 2 + i) * 2,
                        child: RiseIn(delay: math.min(i, 20) * 40, child: Text(treasureAt(i).emoji, style: const TextStyle(fontSize: 30))),
                      ),
                  ]),
                ),
              );
            },
          );
        }),
        const SizedBox(height: 14),
        Text(S.of(context, 'oasisCount', {'n': arNum(earned, arabic: ar)}), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        // كل الكنوز: اللي اتجمع بعدده، والباقي علامة استفهام
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          for (var i = 0; i < treasures.length; i++)
            Container(
              width: 92,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: cardBox(color: counts[i] > 0 ? Colors.white : const Color(0xFFEDEDF3), radius: 20),
              child: Column(children: [
                counts[i] > 0
                    ? Text(treasures[i].emoji, style: const TextStyle(fontSize: 34))
                    : const Text('❔', style: TextStyle(fontSize: 34, color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(counts[i] > 0 ? treasures[i].name(ar) : '؟', style: const TextStyle(fontWeight: FontWeight.w800)),
                if (counts[i] > 1) Text('×${arNum(counts[i], arabic: ar)}', style: const TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w800)),
              ]),
            ),
        ]),
      ]),
    );
  }
}

class _OasisPainter extends CustomPainter {
  _OasisPainter(this.t);
  final double t;
  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFD9A0), Color(0xFFFFF1D6)]).createShader(r));
    c.drawCircle(Offset(s.width * .8, 50), 30, Paint()..color = AppColors.gold);
    c.drawCircle(Offset(s.width * .8, 50), 44, Paint()..color = AppColors.gold.withOpacity(.25));
    // كثبان
    for (final (base, color, phase) in [(.42, const Color(0xFFF2C77E), 0.0), (.55, const Color(0xFFF7D79A), 1.2)]) {
      final p = Path()..moveTo(0, s.height);
      for (var x = 0.0; x <= s.width + 8; x += 8) {
        p.lineTo(x, s.height * base + math.sin(x / s.width * math.pi * 1.6 + phase) * 18);
      }
      p
        ..lineTo(s.width, s.height)
        ..close();
      c.drawPath(p, Paint()..color = color);
    }
    // البحيرة بموج صغير
    final lake = Rect.fromCenter(center: Offset(s.width / 2, s.height * .72), width: s.width * .42, height: 50);
    c.drawOval(lake.inflate(6), Paint()..color = const Color(0xFF8FD16A));
    c.drawOval(lake, Paint()..color = const Color(0xFF4FB3E8));
    final wave = Paint()
      ..color = Colors.white.withOpacity(.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 3; i++) {
      final x = lake.left + 20 + ((t * 10 + i * 40) % (lake.width - 40));
      c.drawArc(Rect.fromCenter(center: Offset(x, lake.center.dy + (i - 1) * 10), width: 18, height: 6), math.pi, math.pi, false, wave);
    }
  }

  @override
  bool shouldRepaint(covariant _OasisPainter old) => old.t != t;
}

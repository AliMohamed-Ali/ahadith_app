import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hadith_core/hadith_core.dart';

import '../l10n.dart';
import '../widgets/fanoos.dart';
import 'shell.dart';

/// شاشة البداية: فانوس بينزل ويتنطط ويسلّم، واسم الأبلكيشن بيطلع كلمة كلمة.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))
    ..forward()
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _go();
    });
  bool _left = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go() {
    if (_left || !mounted) return;
    _left = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (_, __, ___) => const Shell(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  /// جزء من الأنيميشن بين وقتين (بالثواني).
  double _seg(double from, double to, [Curve curve = Curves.linear]) => curve.transform(((_c.value * 3 - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _go,
        child: Scaffold(
          body: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final drop = _seg(0, .9, Curves.bounceOut);
              final landed = _c.value * 3 > .9;
              final words = 'أحاديث الصغار'.split(' ');
              return Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _NightPainter(_c.value * 3))),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Transform.translate(
                        offset: Offset(0, (1 - drop) * -500),
                        child: Fanoos(size: 150, mood: landed ? FanoosMood.happy : FanoosMood.smile),
                      ),
                      const SizedBox(height: 18),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            for (var i = 0; i < words.length; i++)
                              Transform.scale(
                                scale: _seg(1.0 + i * .25, 1.6 + i * .25, Curves.elasticOut),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    words[i],
                                    style: GoogleFonts.balooBhaijaan2(fontSize: 46, fontWeight: FontWeight.w800, color: i == 0 ? Colors.white : AppColors.gold, height: 1.1),
                                  ),
                                ),
                              ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: _seg(1.6, 2.1),
                        child: Transform.translate(
                          offset: Offset(0, (1 - _seg(1.6, 2.1, Curves.easeOut)) * 16),
                          child: Text(S.of(context, 'splashTag'), textAlign: TextAlign.center, style: GoogleFonts.balooBhaijaan2(fontSize: 19, fontWeight: FontWeight.w700, color: const Color(0xFFCFE6FF))),
                        ),
                      ),
                    ]),
                  ),
                ),
              ]);
            },
          ),
        ),
      );
}

/// سما الليل: نجوم بتلمع، هلال، وتلال تحت (نفس روح أيقونة الأبلكيشن).
class _NightPainter extends CustomPainter {
  _NightPainter(this.t);
  final double t;

  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1D2B5E), Color(0xFF2E3F82)]).createShader(r));
    // نور ورا فانوس
    c.drawCircle(
        s.center(const Offset(0, -60)),
        170,
        Paint()
          ..shader = RadialGradient(colors: [AppColors.gold.withOpacity(.28 * ((t - .8) / .6).clamp(0.0, 1.0)), Colors.transparent])
              .createShader(Rect.fromCircle(center: s.center(const Offset(0, -60)), radius: 170)));
    final rnd = math.Random(4);
    for (var i = 0; i < 40; i++) {
      final o = Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height * .8);
      final tw = .3 + .7 * math.sin(t * (2 + rnd.nextDouble() * 3) + i).abs();
      final pop = ((t - rnd.nextDouble() * 1.2) / .3).clamp(0.0, 1.0);
      c.drawCircle(o, (1 + rnd.nextDouble() * 1.8) * pop, Paint()..color = Colors.white.withOpacity(tw));
    }
    // الهلال بيطلع من الجنب
    final m = Offset(s.width * .8, s.height * .14) + Offset((1 - Curves.easeOutBack.transform((t / .8).clamp(0.0, 1.0))) * 120, 0);
    c.drawCircle(m, 36, Paint()..color = AppColors.gold);
    c.drawCircle(m + const Offset(15, -10), 32, Paint()..color = const Color(0xFF1F2E63));
    // التلال
    for (final (base, color, phase) in [(.86, const Color(0xFF0E7C74), 0.0), (.9, const Color(0xFF3CC7A8), 1.4)]) {
      final p = Path()..moveTo(0, s.height);
      for (var x = 0.0; x <= s.width + 8; x += 8) {
        p.lineTo(x, s.height * base + math.sin(x / s.width * math.pi * 2 + phase) * 14);
      }
      p
        ..lineTo(s.width, s.height)
        ..close();
      c.drawPath(p, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _NightPainter old) => old.t != t;
}

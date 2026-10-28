import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';

enum FanoosMood { smile, happy, talk }

/// شخصية "فانوس" مرسومة بالكود: بيتنطط، بيرمش، بيبص حواليه، وبيشاور بإيده.
/// swing = false يخليه ثابت (من غير نط).
class Fanoos extends StatefulWidget {
  const Fanoos({super.key, this.size = 72, this.color = AppColors.gold, this.mood = FanoosMood.smile, this.swing = true, this.crown = false, this.bow = false, this.halo = false});
  final double size;
  final Color color;
  final FanoosMood mood;
  final bool swing;
  final bool crown;
  final bool bow;
  final bool halo;

  @override
  State<Fanoos> createState() => _FanoosState();
}

class _FanoosState extends State<Fanoos> with SingleTickerProviderStateMixin {
  // دورة واحدة 4 ثواني فيها كل الحركات، وكل فانوس بيبدأ من نقطة مختلفة عشان ما يتحركوش مع بعض.
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4), value: math.Random().nextDouble())..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.size * 1.3;
    return SizedBox(
      width: widget.size,
      height: h,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size(widget.size, h),
          painter: FanoosPainter(v: _c.value, color: widget.color, mood: widget.mood, alive: widget.swing, crown: widget.crown, bow: widget.bow, halo: widget.halo),
        ),
      ),
    );
  }
}

/// v من 0 لـ 1 = مكان الشخصية في دورة الحركة.
class FanoosPainter extends CustomPainter {
  FanoosPainter({required this.v, required this.color, required this.mood, this.alive = true, this.crown = false, this.bow = false, this.halo = false});
  final double v;
  final Color color;
  final FanoosMood mood;
  final bool alive, crown, bow, halo;

  static const _ink = Color(0xFF2B2140);
  static const _mouth = Color(0xFF5A1E2E);
  static const _tongue = Color(0xFFF27BA6);
  static const _blush = Color(0x99FF8C7A);

  @override
  void paint(Canvas canvas, Size size) {
    // الرسم على شبكة 100×130 ثم التكبير.
    canvas.save();
    canvas.scale(size.width / 100, size.height / 130);
    const tau = math.pi * 2;
    final happy = mood == FanoosMood.happy;

    // نط وضغط ومط (squash & stretch)
    var lift = 0.0, sx = 1.0, sy = 1.0;
    if (alive) {
      if (happy) {
        final hop = math.sin(v * tau * 4);
        lift = math.max(0.0, hop) * 10;
        final land = math.max(0.0, -hop);
        sy = 1 - land * .08 + math.max(0.0, hop) * .05;
      } else {
        final b = math.sin(v * tau * 2);
        lift = (b + 1) * 1.2;
        sy = 1 + b * .025;
      }
      sx = 1 / sy;
    }
    canvas.translate(50, 121 - lift);
    canvas.scale(sx, sy);
    canvas.translate(-50, -121);

    // الضل بنفس درجة اللون (مش رمادي)
    final hsl = HSLColor.fromColor(color);
    Color shade(double k) => hsl.withLightness((hsl.lightness * k).clamp(0.0, 1.0)).withSaturation(math.min(1.0, hsl.saturation * 1.1)).toColor();
    final dark = shade(.78);
    final darker = shade(.62);
    final light = Color.lerp(color, Colors.white, .35)!;

    if (halo) {
      final h = Paint()..color = const Color(0xFFFFE9A8);
      for (var i = 0; i < 7; i++) {
        final a = math.pi + i * math.pi / 6 + math.sin(v * tau) * .05;
        canvas.drawCircle(Offset(50 + 46 * math.cos(a), 66 + 46 * math.sin(a)), 3.5 + (i.isEven ? 1.5 : 0), h);
      }
    }

    // الرجلين
    final leg = Paint()
      ..color = darker
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(39, 92), const Offset(39, 113), leg);
    canvas.drawLine(const Offset(61, 92), const Offset(61, 113), leg);
    // في الهوا الرجلين بتتلم، وعلى الأرض بتتفرش
    final fw = lift > 3 ? 13.0 : 18.0;
    canvas.drawOval(Rect.fromCenter(center: const Offset(37, 116), width: fw, height: 9), Paint()..color = darker);
    canvas.drawOval(Rect.fromCenter(center: const Offset(63, 116), width: fw, height: 9), Paint()..color = darker);

    // الإيدين (ورا الجسم)
    final waveOn = !happy && alive && v > .55 && v < .8;
    final wave = math.sin((v - .55) / .25 * tau * 2.5);
    double armL, armR;
    if (happy && alive) {
      armL = 2.5 + math.sin(v * tau * 8) * .3;
      armR = 2.5 - math.sin(v * tau * 8) * .3;
    } else if (mood == FanoosMood.talk && alive) {
      armL = .5 + math.sin(v * tau * 3) * .25;
      armR = 1.1 + math.sin(v * tau * 3 + 1) * .4;
    } else {
      armL = .45 + math.sin(v * tau * 2) * .06;
      armR = waveOn ? 2.6 + wave * .35 : .45 - math.sin(v * tau * 2) * .06;
    }
    _arm(canvas, const Offset(22, 68), armL, -1, dark);
    _arm(canvas, const Offset(78, 68), armR, 1, dark);

    // الحلقة والغطا
    canvas.drawCircle(const Offset(50, 7), 4.5, Paint()
      ..color = darker
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    canvas.drawPath(Path()..moveTo(29, 29)..cubicTo(31, 13, 69, 13, 71, 29)..close(), Paint()..color = dark);
    canvas.drawPath(Path()..moveTo(36, 24)..quadraticBezierTo(42, 17, 50, 16.5), Paint()
      ..color = Colors.white.withOpacity(.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);
    canvas.drawRRect(RRect.fromLTRBR(25, 27, 75, 35, const Radius.circular(4)), Paint()..color = darker);

    // الجسم: لون غامق تحت + فاتح فوق = ضل بسيط
    canvas.drawRRect(RRect.fromLTRBR(17, 33, 83, 101, const Radius.circular(25)), Paint()..color = dark);
    canvas.drawRRect(RRect.fromLTRBR(17, 33, 79, 97, const Radius.circular(24)), Paint()..color = color);
    canvas.drawPath(Path()..moveTo(22, 52)..quadraticBezierTo(22, 40, 32, 38), Paint()
      ..color = light
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);

    // الشباك اللي جوه منوّر (النور بيرتعش شوية)
    final flicker = alive ? .5 + .5 * math.sin(v * tau * 7) * math.sin(v * tau * 3) : .5;
    final panel = RRect.fromLTRBR(26, 42, 72, 90, const Radius.circular(17));
    canvas.drawRRect(
      panel,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, .1),
          radius: .9,
          colors: [const Color(0xFFFFFDF0), Color.lerp(const Color(0xFFFFE7A0), const Color(0xFFFFF1C4), flicker)!],
        ).createShader(panel.outerRect),
    );

    // العيون
    final blink = alive && (v % .5) > .47 ? .1 : 1.0;
    final look = alive ? Offset(math.sin(v * tau) * 1.8, math.sin(v * tau * 2 + 1) * .8) : Offset.zero;
    final brow = happy || mood == FanoosMood.talk ? 2.5 : 0.0;
    if (happy) {
      final s = Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(Path()..moveTo(33, 62)..quadraticBezierTo(39.5, 53, 46, 62), s);
      canvas.drawPath(Path()..moveTo(52, 62)..quadraticBezierTo(58.5, 53, 65, 62), s);
    } else {
      for (final ex in [39.5, 58.5]) {
        final eye = Rect.fromCenter(center: Offset(ex, 60), width: 14.5, height: 17 * blink);
        canvas.drawOval(eye, Paint()..color = Colors.white);
        canvas.drawOval(eye, Paint()
          ..color = _ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8);
        if (blink > .5) {
          final pc = Offset(ex + .8, 61) + look;
          canvas.drawCircle(pc, 5, Paint()..color = _ink);
          canvas.drawCircle(pc + const Offset(1.7, -2), 1.8, Paint()..color = Colors.white);
          canvas.drawCircle(pc + const Offset(-1.6, 2), .9, Paint()..color = Colors.white);
        }
      }
    }
    final b = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(Path()..moveTo(33, 49.5 - brow)..quadraticBezierTo(39, 46.5 - brow, 45, 48.5 - brow), b);
    canvas.drawPath(Path()..moveTo(53, 48.5 - brow)..quadraticBezierTo(59, 46.5 - brow, 65, 49.5 - brow), b);

    // الخدود
    canvas.drawOval(Rect.fromCenter(center: const Offset(31, 73), width: 9, height: 5.5), Paint()..color = _blush);
    canvas.drawOval(Rect.fromCenter(center: const Offset(67, 73), width: 9, height: 5.5), Paint()..color = _blush);

    // البق
    final Path m;
    if (mood == FanoosMood.talk) {
      final open = alive ? math.sin(v * tau * 10).abs() : .4;
      m = Path()..addOval(Rect.fromCenter(center: const Offset(49, 76), width: 11, height: 3 + 8 * open));
    } else if (happy) {
      m = Path()..moveTo(40, 71)..quadraticBezierTo(49, 87, 58, 71)..close();
    } else {
      m = Path()..moveTo(43, 72)..quadraticBezierTo(49, 81, 55, 72)..close();
    }
    canvas.drawPath(m, Paint()..color = _mouth);
    canvas.save();
    canvas.clipPath(m);
    canvas.drawCircle(const Offset(49, 82), 5, Paint()..color = _tongue);
    canvas.restore();

    if (bow) {
      final p = Paint()..color = const Color(0xFFE8573A);
      canvas.drawPath(Path()..moveTo(50, 101)..lineTo(36, 94)..lineTo(36, 108)..close(), p);
      canvas.drawPath(Path()..moveTo(50, 101)..lineTo(64, 94)..lineTo(64, 108)..close(), p);
      canvas.drawCircle(const Offset(50, 101), 3.5, Paint()..color = const Color(0xFFB4401F));
    }
    if (crown) {
      final c = Path()
        ..moveTo(36, 16)
        ..lineTo(38, 2)
        ..lineTo(44, 10)
        ..lineTo(50, 0)
        ..lineTo(56, 10)
        ..lineTo(62, 2)
        ..lineTo(64, 16)
        ..close();
      canvas.drawPath(c, Paint()..color = const Color(0xFFFFD95A));
      canvas.drawCircle(const Offset(50, 10), 2.2, Paint()..color = const Color(0xFFE8573A));
    }
    canvas.restore();
  }

  /// دراع صغير: الزاوية من تحت (0) لفوق (π)، و side يحدد اليمين أو الشمال.
  void _arm(Canvas c, Offset s, double a, double side, Color col) {
    final e = s + Offset(side * math.sin(a) * 15, math.cos(a) * 15);
    c.drawLine(s, e, Paint()
      ..color = col
      ..strokeWidth = 7.5
      ..strokeCap = StrokeCap.round);
    c.drawCircle(e, 4.8, Paint()..color = col);
  }

  @override
  bool shouldRepaint(covariant FanoosPainter old) => true;
}

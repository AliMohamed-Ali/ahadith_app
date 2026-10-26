import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';

enum FanoosMood { smile, happy, talk }

/// شخصية "فانوس" مرسومة بالكود، تتمرجح طول الوقت.
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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);

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
        builder: (context, _) {
          final angle = widget.swing ? (Curves.easeInOut.transform(_c.value) - 0.5) * 0.24 : 0.0;
          return Transform.rotate(
            angle: angle,
            alignment: Alignment.topCenter,
            child: CustomPaint(
              size: Size(widget.size, h),
              painter: _FanoosPainter(color: widget.color, mood: widget.mood, talk: _c.value, crown: widget.crown, bow: widget.bow, halo: widget.halo),
            ),
          );
        },
      ),
    );
  }
}

class _FanoosPainter extends CustomPainter {
  _FanoosPainter({required this.color, required this.mood, required this.talk, required this.crown, required this.bow, this.halo = false});
  final Color color;
  final FanoosMood mood;
  final double talk;
  final bool crown;
  final bool bow;
  final bool halo;

  @override
  void paint(Canvas canvas, Size size) {
    // الرسم على شبكة 100×130 ثم التكبير.
    canvas.save();
    canvas.scale(size.width / 100, size.height / 130);
    final p = Paint()..isAntiAlias = true;
    const dark = Color(0xFFC27A10);
    const cap = Color(0xFFE0961A);
    const ink = AppColors.navy;

    if (halo) {
      final h = Paint()..color = const Color(0xFFFFE9A8);
      for (var i = 0; i < 7; i++) {
        final a = math.pi + i * math.pi / 6;
        final c = Offset(50 + 44 * math.cos(a), 66 + 44 * math.sin(a));
        canvas.drawCircle(c, 3.5 + (i.isEven ? 1.5 : 0), h);
      }
    }
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = dark;
    canvas.drawCircle(const Offset(50, 8), 6, p);
    p.style = PaintingStyle.fill;

    p.color = cap;
    canvas.drawPath(Path()..moveTo(30, 30)..lineTo(50, 14)..lineTo(70, 30)..close(), p);
    p.color = dark;
    canvas.drawRRect(RRect.fromLTRBR(26, 30, 74, 38, const Radius.circular(4)), p);
    p.color = color;
    canvas.drawRRect(RRect.fromLTRBR(22, 38, 78, 100, const Radius.circular(18)), p);
    p.color = const Color(0xFFFFF3C9);
    canvas.drawRRect(RRect.fromLTRBR(30, 46, 70, 90, const Radius.circular(14)), p);

    // العيون
    p.color = ink;
    if (mood == FanoosMood.happy) {
      final s = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(Path()..moveTo(37, 64)..quadraticBezierTo(42, 58, 47, 64), s);
      canvas.drawPath(Path()..moveTo(53, 64)..quadraticBezierTo(58, 58, 63, 64), s);
    } else {
      canvas.drawCircle(const Offset(42, 63), 4.5, p);
      canvas.drawCircle(const Offset(58, 63), 4.5, p);
      p.color = Colors.white;
      canvas.drawCircle(const Offset(43.5, 61.5), 1.5, p);
      canvas.drawCircle(const Offset(59.5, 61.5), 1.5, p);
    }
    // الخدود
    p.color = const Color(0xCCFF9C8A);
    canvas.drawCircle(const Offset(36, 73), 4, p);
    canvas.drawCircle(const Offset(64, 73), 4, p);
    // الفم
    if (mood == FanoosMood.talk) {
      p.color = ink;
      final open = 2 + 4 * math.sin(talk * math.pi * 6).abs();
      canvas.drawOval(Rect.fromCenter(center: const Offset(50, 76), width: 12, height: open), p);
    } else if (mood == FanoosMood.happy) {
      p.color = ink;
      canvas.drawPath(Path()..moveTo(42, 72)..arcToPoint(const Offset(58, 72), radius: const Radius.circular(8), clockwise: false)..close(), p);
    } else {
      final s = Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(Path()..moveTo(43, 73)..quadraticBezierTo(50, 81, 57, 73), s);
    }
    p.color = dark;
    canvas.drawRRect(RRect.fromLTRBR(26, 100, 74, 108, const Radius.circular(4)), p);
    p.color = cap;
    canvas.drawPath(Path()..moveTo(38, 108)..lineTo(62, 108)..lineTo(50, 122)..close(), p);

    if (bow) {
      p.color = const Color(0xFFE8573A);
      canvas.drawPath(Path()..moveTo(50, 104)..lineTo(36, 97)..lineTo(36, 111)..close(), p);
      canvas.drawPath(Path()..moveTo(50, 104)..lineTo(64, 97)..lineTo(64, 111)..close(), p);
      p.color = const Color(0xFFB4401F);
      canvas.drawCircle(const Offset(50, 104), 3.5, p);
    }
    if (crown) {
      p.color = const Color(0xFFFFD95A);
      final c = Path()
        ..moveTo(36, 16)
        ..lineTo(38, 2)
        ..lineTo(44, 10)
        ..lineTo(50, 0)
        ..lineTo(56, 10)
        ..lineTo(62, 2)
        ..lineTo(64, 16)
        ..close();
      canvas.drawPath(c, p);
      p.color = const Color(0xFFE8573A);
      canvas.drawCircle(const Offset(50, 10), 2.2, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FanoosPainter old) => old.talk != talk || old.color != color || old.mood != mood || old.crown != crown || old.bow != bow || old.halo != halo;
}

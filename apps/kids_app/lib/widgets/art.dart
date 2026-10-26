import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';

import '../state/progress_store.dart';

/// الشخصيات الكرتونية للملف الشخصي (بدل صور الأطفال في لوحة الشرف).
class AvatarDef {
  const AvatarDef(this.key, this.nameAr, this.nameEn, this.bg, this.fg);
  final String key;
  final String nameAr;
  final String nameEn;
  final Color bg;
  final Color fg;
}

const avatars = <AvatarDef>[
  AvatarDef('cat', 'قطة', 'Cat', Color(0xFFFFE3B8), Color(0xFFF0A35B)),
  AvatarDef('bunny', 'أرنب', 'Bunny', Color(0xFFE3D4FF), Colors.white),
  AvatarDef('bear', 'دب', 'Bear', Color(0xFFD9F2C4), Color(0xFFC68B59)),
  AvatarDef('owl', 'بومة', 'Owl', Color(0xFFCFE0FF), Color(0xFF9B7BEA)),
  AvatarDef('chick', 'كتكوت', 'Chick', Color(0xFFFFF3C9), Color(0xFFFFD43B)),
  AvatarDef('lamb', 'خروف', 'Lamb', Color(0xFFEAF6F0), Colors.white),
];

AvatarDef avatarOf(String key) => avatars.firstWhere((a) => a.key == key, orElse: () => avatars.first);

class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.avatarKey, this.size = 56});
  final String avatarKey;
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _AvatarPainter(avatarOf(avatarKey)));
}

/// صورة الطفل إن وُجدت (على جهازه فقط)، وإلا شخصيته الكرتونية.
class ProfileFace extends StatelessWidget {
  const ProfileFace({super.key, required this.profile, this.size = 92});
  final KidProfile? profile;
  final double size;
  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p != null && p.hasPhoto) {
      return ClipOval(child: Image.file(File(p.photoPath), width: size, height: size, fit: BoxFit.cover));
    }
    return AvatarView(avatarKey: p?.avatar ?? 'cat', size: size);
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.a);
  final AvatarDef a;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64);
    final p = Paint()..isAntiAlias = true;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x261D2B5E);
    p.color = a.bg;
    canvas.drawCircle(const Offset(32, 32), 32, p);
    p.color = a.fg;
    final ears = Path();
    switch (a.key) {
      case 'cat':
        ears
          ..addPolygon(const [Offset(15, 28), Offset(17, 8), Offset(31, 21)], true)
          ..addPolygon(const [Offset(49, 28), Offset(47, 8), Offset(33, 21)], true);
        break;
      case 'bunny':
        ears
          ..addOval(Rect.fromCenter(center: const Offset(24, 14), width: 9, height: 24))
          ..addOval(Rect.fromCenter(center: const Offset(40, 14), width: 9, height: 24));
        break;
      case 'bear':
        ears
          ..addOval(Rect.fromCircle(center: const Offset(20, 24), radius: 8))
          ..addOval(Rect.fromCircle(center: const Offset(44, 24), radius: 8));
        break;
      case 'owl':
        ears
          ..addPolygon(const [Offset(15, 24), Offset(19, 10), Offset(28, 20)], true)
          ..addPolygon(const [Offset(49, 24), Offset(45, 10), Offset(36, 20)], true);
        break;
      case 'lamb':
        ears
          ..addOval(Rect.fromCenter(center: const Offset(12, 32), width: 10, height: 7))
          ..addOval(Rect.fromCenter(center: const Offset(52, 32), width: 10, height: 7));
        break;
      default:
        ears.addOval(Rect.fromCenter(center: const Offset(32, 17), width: 4, height: 9));
    }
    canvas.drawPath(ears, p);
    canvas.drawPath(ears, line);
    canvas.drawCircle(const Offset(32, 38), 19, p);
    canvas.drawCircle(const Offset(32, 38), 19, line);
    if (a.key == 'lamb') {
      p.color = const Color(0xFFE6EDF3);
      for (final x in [22.0, 32.0, 42.0]) {
        canvas.drawCircle(Offset(x, 22), 6, p);
      }
    }
    if (a.key == 'bear') {
      p.color = const Color(0xFFEBC9A2);
      canvas.drawOval(Rect.fromCenter(center: const Offset(32, 45), width: 16, height: 12), p);
    }
    p.color = AppColors.navy;
    canvas.drawCircle(const Offset(25, 35), 3, p);
    canvas.drawCircle(const Offset(39, 35), 3, p);
    p.color = const Color(0xB3FF9C8A);
    canvas.drawCircle(const Offset(20, 42), 3, p);
    canvas.drawCircle(const Offset(44, 42), 3, p);
    // الأنف/المنقار
    p.color = switch (a.key) { 'owl' => AppColors.gold, 'chick' => const Color(0xFFFF8A3D), 'bunny' => const Color(0xFFF27BA6), _ => const Color(0xFFE8573A) };
    canvas.drawPath(Path()..moveTo(29, 41)..lineTo(35, 41)..lineTo(32, 45)..close(), p);
    if (a.key != 'owl' && a.key != 'chick') {
      final m = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = AppColors.navy;
      canvas.drawPath(Path()..moveTo(27, 47)..quadraticBezierTo(32, 51, 37, 47), m);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) => old.a.key != a.key;
}

/// نبتة الحديقة حسب مرحلتها: 1 بذرة، 2 وردة، 3 شجرة مثمرة.
class PlantView extends StatelessWidget {
  const PlantView({super.key, required this.stage, required this.petal, this.size = 64});
  final int stage;
  final Color petal;
  final double size;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.scale(scale: v, alignment: Alignment.bottomCenter, child: child),
        child: CustomPaint(size: Size(size, size * 70 / 60), painter: _PlantPainter(stage, petal)),
      );
}

class _PlantPainter extends CustomPainter {
  _PlantPainter(this.stage, this.petal);
  final int stage;
  final Color petal;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 60);
    final p = Paint()..isAntiAlias = true;
    p.color = const Color(0xFFA0703F);
    canvas.drawOval(Rect.fromCenter(center: const Offset(30, 65), width: 48, height: 10), p);
    final stem = Paint()
      ..color = const Color(0xFF3E9B4F)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const leaf = Color(0xFF5DBB63);
    if (stage >= 3) {
      p.color = const Color(0xFF8A5A2B);
      canvas.drawRRect(RRect.fromLTRBR(26, 36, 34, 65, const Radius.circular(3)), p);
      p.color = const Color(0xFF3E9B4F);
      canvas.drawCircle(const Offset(30, 24), 20, p);
      p.color = leaf;
      canvas.drawCircle(const Offset(16, 32), 12, p);
      canvas.drawCircle(const Offset(44, 32), 12, p);
      p.color = petal;
      for (final o in const [Offset(22, 18), Offset(38, 24), Offset(28, 34), Offset(44, 36)]) {
        canvas.drawCircle(o, 4, p);
      }
    } else {
      final top = stage == 2 ? 28.0 : 42.0;
      canvas.drawLine(const Offset(30, 65), Offset(30, top), stem);
      p.color = leaf;
      canvas.drawPath(Path()..moveTo(30, 50)..quadraticBezierTo(14, 48, 12, 33)..quadraticBezierTo(27, 33, 30, 50)..close(), p);
      canvas.drawPath(Path()..moveTo(30, 46)..quadraticBezierTo(46, 44, 48, 29)..quadraticBezierTo(33, 29, 30, 46)..close(), p);
      if (stage == 2) {
        p.color = petal;
        for (var i = 0; i < 5; i++) {
          final a = -math.pi / 2 + i * 2 * math.pi / 5;
          canvas.drawCircle(Offset(30 + 9 * math.cos(a), 20 + 9 * math.sin(a)), 7, p);
        }
        p.color = AppColors.gold;
        canvas.drawCircle(const Offset(30, 20), 6, p);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlantPainter old) => old.stage != stage || old.petal != petal;
}

/// قصاصات احتفال.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.size = 260});
  final double size;
  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(size: Size.square(widget.size), painter: _ConfettiPainter(Curves.easeOutCubic.transform(_c.value))),
        ),
      );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t);
  final double t;
  static const colors = [AppColors.gold, Color(0xFFE8573A), AppColors.teal, Color(0xFFF27BA6), Color(0xFF33478A)];
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint();
    for (var i = 0; i < 18; i++) {
      final a = i * 2 * math.pi / 18;
      final d = t * size.width * (0.35 + (i % 3) * 0.08);
      p.color = colors[i % colors.length].withOpacity(1 - t);
      canvas.save();
      canvas.translate(c.dx + d * math.cos(a), c.dy + d * math.sin(a) + t * 30);
      canvas.rotate(t * 6 + i);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -7, 10, 14), const Radius.circular(3)), p);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}

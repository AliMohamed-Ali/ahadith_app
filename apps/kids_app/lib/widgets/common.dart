import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n.dart';

/// نجمة عادية (ذهبية).
class StarIcon extends StatelessWidget {
  const StarIcon({super.key, this.size = 20, this.color = AppColors.gold});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _StarPainter(color));
}

/// نجمة ملكية (بنفسجي وفوقها تاج).
class RoyalStarIcon extends StatelessWidget {
  const RoyalStarIcon({super.key, this.size = 22});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size * 1.1,
        child: Stack(alignment: Alignment.bottomCenter, children: [
          Positioned(bottom: 0, child: CustomPaint(size: Size.square(size * 0.9), painter: _StarPainter(AppColors.royal))),
          Positioned(top: 0, child: CustomPaint(size: Size(size * 0.5, size * 0.25), painter: _CrownPainter())),
        ]),
      );
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final c = Offset(size.width / 2, size.height / 2);
    final r1 = size.width / 2, r2 = r1 * 0.45;
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? r1 : r2;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = c + Offset(r * math.cos(a), r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.color != color;
}

class _CrownPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(0, s.height)
      ..lineTo(s.width * .1, 0)
      ..lineTo(s.width * .3, s.height * .55)
      ..lineTo(s.width * .5, 0)
      ..lineTo(s.width * .7, s.height * .55)
      ..lineTo(s.width * .9, 0)
      ..lineTo(s.width, s.height)
      ..close();
    canvas.drawPath(p, Paint()..color = const Color(0xFFFFD95A));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// عدّاد نجوم صغير.
class StarPill extends StatelessWidget {
  const StarPill({super.key, required this.count, this.royal = false, this.dense = false});
  final int count;
  final bool royal;
  final bool dense;
  @override
  Widget build(BuildContext context) {
    final ar = Directionality.of(context) == TextDirection.rtl;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12, vertical: dense ? 2 : 6),
      decoration: BoxDecoration(color: royal ? AppColors.royalSoft : AppColors.cream, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        royal ? RoyalStarIcon(size: dense ? 15 : 20) : StarIcon(size: dense ? 15 : 18),
        const SizedBox(width: 4),
        Text(arNum(count, arabic: ar), style: TextStyle(fontWeight: FontWeight.w800, fontSize: dense ? 14 : 17, color: royal ? AppColors.royalDark : const Color(0xFF7A4A06))),
      ]),
    );
  }
}

/// زر كبير مرح (مع ظل سفلي) يُستخدم في الصفحة الرئيسية.
class BigTile extends StatefulWidget {
  const BigTile({super.key, required this.color, required this.shadow, required this.child, required this.onTap, this.radius = 30});
  final Color color;
  final Color shadow;
  final Widget child;
  final VoidCallback? onTap;
  final double radius;
  @override
  State<BigTile> createState() => _BigTileState();
}

class _BigTileState extends State<BigTile> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, _down ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: [BoxShadow(color: widget.shadow, offset: Offset(0, _down ? 2 : 6))],
        ),
        padding: const EdgeInsets.all(16),
        child: widget.child,
      ),
    );
  }
}

/// ظهور متدرّج (يُستخدم لتتابع العناصر عند فتح الشاشات).
class RiseIn extends StatelessWidget {
  const RiseIn({super.key, required this.child, this.delay = 0});
  final Widget child;
  final int delay;
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + delay),
      curve: Curves.easeOutBack,
      builder: (context, v, child) {
        final t = ((v * (450 + delay) - delay) / 450).clamp(0.0, 1.0);
        return Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, (1 - t) * 20), child: child));
      },
      child: child,
    );
  }
}

/// نسخ ومشاركة.
Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(S.of(context, 'copiedToast'))));
  }
}

Future<void> shareText(BuildContext context, String text) async {
  final full = '$text\n\n${S.of(context, 'shareFooter')}';
  await Share.share(full);
}

class CopyShareRow extends StatelessWidget {
  const CopyShareRow({super.key, required this.text, this.share = true});
  final String text;
  final bool share;
  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
      OutlinedButton.icon(onPressed: () => copyText(context, text), icon: const Icon(Icons.copy_rounded, size: 18), label: Text(S.of(context, 'copy'))),
      if (share)
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => shareText(context, text),
          icon: const Icon(Icons.share_rounded, size: 18),
          label: Text(S.of(context, 'share')),
        ),
    ]);
  }
}

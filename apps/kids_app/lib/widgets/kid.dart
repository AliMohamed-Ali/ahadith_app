import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ألوان الطفل (كرتون بخط خارجي).
class _K {
  static const ink = Color(0xFF3A2A4A);
  static const skin = Color(0xFFF6C9A0);
  static const skinDark = Color(0xFFE0A47A);
  static const hair = Color(0xFF4A2C1A);
  static const hoodie = Color(0xFF1FB5A5);
  static const hoodieDark = Color(0xFF128A7E);
  static const hoodieLight = Color(0xFF6FE3D6);
  static const pants = Color(0xFF2C3E7A);
  static const pantsDark = Color(0xFF1F2C5A);
  static const shoe = Colors.white;
  static const shoeStripe = Color(0xFFEF5B4C);
  static const bag = Color(0xFFF5B82E);
  static const bagDark = Color(0xFFC99419);
  static const blush = Color(0x73F27BA6);
  static const mouth = Color(0xFF6B2A3A);
}

/// غمضة العين كل كام ثانية.
double kidBlink(double t) => (t % 3.3) < .13 ? .12 : 1;

/// وضعية الطفل من الجنب. الزوايا بالراديان: 0 = لتحت، موجب = لقدّام.
class KidPose {
  const KidPose({
    this.legF = 0,
    this.legB = 0,
    this.kneeF = 0,
    this.kneeB = 0,
    this.armF = 0,
    this.armB = 0,
    this.elbowF = .3,
    this.elbowB = .3,
    this.lean = 0,
    this.squash = 1,
    this.happy = false,
    this.blink = 1,
    this.grounded = true,
  });
  final double legF, legB, kneeF, kneeB, armF, armB, elbowF, elbowB, lean, squash, blink;
  final bool happy, grounded;

  /// جري: phase بيزيد مع الوقت. الركبة بتتني والرجل راجعة لقدّام.
  factory KidPose.run(double phase, {double blink = 1}) {
    final s = math.sin(phase), c = math.cos(phase);
    return KidPose(
      legF: s * .75,
      legB: -s * .75,
      kneeF: math.max(0, c) * 1.4 + .1,
      kneeB: math.max(0, -c) * 1.4 + .1,
      armF: -s * .9,
      armB: s * .9,
      elbowF: 1.4,
      elbowB: 1.4,
      lean: .14,
      blink: blink,
    );
  }

  /// واقف بيتنفس.
  factory KidPose.idle(double t, {double blink = 1}) => KidPose(
        legF: .08,
        legB: -.08,
        kneeF: .05,
        kneeB: .05,
        armF: .15 + math.sin(t * 2) * .05,
        armB: -.1,
        squash: 1 + math.sin(t * 2.2) * .012,
        blink: blink,
      );

  /// بيوطّي قبل النطة أو بعد النزول (k من 0 لـ 1).
  factory KidPose.crouch(double k) => KidPose(
        legF: .6 * k,
        legB: .35 * k,
        kneeF: 1.2 * k,
        kneeB: .95 * k,
        armF: -.5 * k,
        armB: -.7 * k,
        elbowF: .6,
        elbowB: .6,
        lean: .3 * k,
        squash: 1 - .06 * k,
      );

  /// في الهوا.
  const KidPose.jump()
      : this(legF: .8, kneeF: 1.4, legB: -.25, kneeB: 1.1, armF: 2.6, armB: 2.2, elbowF: .3, elbowB: .3, lean: .05, squash: 1.04, happy: true, grounded: false);

  /// فرحان وإيديه لفوق.
  factory KidPose.cheer(double t) => KidPose(
        legF: .15,
        legB: -.15,
        armF: 2.8 + math.sin(t * 10) * .2,
        armB: 2.6 - math.sin(t * 10) * .2,
        elbowF: .2,
        elbowB: .2,
        squash: 1 + math.sin(t * 10).abs() * .03,
        happy: true,
      );
}

/// الطفل من الجنب (باصص يمين، أو شمال لو facingLeft).
class Kid extends StatelessWidget {
  const Kid({super.key, required this.pose, this.facingLeft = false, this.height = 110});
  final KidPose pose;
  final bool facingLeft;
  final double height;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(height * 100 / 140, height), painter: KidPainter(pose, facingLeft: facingLeft));
}

/// الطفل من ضهره (للعبة القطر).
class KidBack extends StatelessWidget {
  const KidBack({super.key, required this.phase, this.air = false, this.tilt = 0, this.cheer = false, this.t = 0, this.height = 120});
  final double phase, tilt, t, height;
  final bool air, cheer;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(height * 100 / 140, height), painter: KidBackPainter(phase: phase, air: air, tilt: tilt, cheer: cheer, t: t));
}

Paint _ink(double w) => Paint()
  ..color = _K.ink
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

/// خط بلون جوه خط غامق (شكل الكرتون).
void _limb(Canvas c, List<Offset> pts, Color col, double w) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (final q in pts.skip(1)) {
    path.lineTo(q.dx, q.dy);
  }
  c.drawPath(path, _ink(w + 4.5));
  c.drawPath(
    path,
    Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

void _fillInk(Canvas c, Path p, Color col, {double w = 2.5}) {
  c.drawPath(p, Paint()..color = col);
  c.drawPath(p, _ink(w));
}

void _hand(Canvas c, Offset o) => _fillInk(c, Path()..addOval(Rect.fromCircle(center: o, radius: 4.6)), _K.skin, w: 2.2);

class KidPainter extends CustomPainter {
  KidPainter(this.pose, {this.facingLeft = false});
  final KidPose pose;
  final bool facingLeft;

  static const _thigh = 17.0, _shin = 17.0, _sole = 131.0;

  @override
  void paint(Canvas canvas, Size size) {
    final p = pose;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 140);
    if (facingLeft) {
      canvas.translate(100, 0);
      canvas.scale(-1, 1);
    }
    (Offset, Offset) leg(double a, double k) {
      final knee = Offset(math.sin(a) * _thigh, math.cos(a) * _thigh);
      final b = a - k;
      return (knee, knee + Offset(math.sin(b) * _shin, math.cos(b) * _shin));
    }

    final lf = leg(p.legF, p.kneeF), lb = leg(p.legB, p.kneeB);
    // على الأرض: أوطى رجل تلمس الأرض، فالجسم بيطلع وينزل لوحده مع الجري.
    final hipY = p.grounded ? _sole - math.max(lf.$2.dy, lb.$2.dy) : _sole - _thigh - _shin;
    final hip = Offset(46, hipY);
    Offset rot(Offset v, double a) => Offset(v.dx * math.cos(a) - v.dy * math.sin(a), v.dx * math.sin(a) + v.dy * math.cos(a));
    final shoulder = hip + rot(Offset(1, -27 * p.squash), p.lean);

    _arm(canvas, shoulder, p.armB, p.elbowB, _K.hoodieDark);
    _leg(canvas, hip, lb, _K.pantsDark, p.legB - p.kneeB);
    _leg(canvas, hip, lf, _K.pants, p.legF - p.kneeF);

    canvas.save();
    canvas.translate(hip.dx, hip.dy);
    canvas.rotate(p.lean);
    canvas.scale(1, p.squash);
    // الشنطة
    _fillInk(canvas, Path()..addRRect(RRect.fromLTRBR(-22, -32, -7, -6, const Radius.circular(5))), _K.bag);
    canvas.drawLine(const Offset(-21, -20), const Offset(-8, -20), Paint()..color = _K.bagDark..strokeWidth = 3);
    // الهودي
    final body = Path()..addRRect(RRect.fromLTRBR(-13, -36, 14, 5, const Radius.circular(12)));
    canvas.drawPath(body, Paint()..color = _K.hoodie);
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(const Rect.fromLTRB(-14, -14, 15, -9), Paint()..color = _K.hoodieLight);
    canvas.drawRect(const Rect.fromLTRB(-14, 0, 15, 6), Paint()..color = _K.hoodieDark);
    canvas.restore();
    canvas.drawPath(body, _ink(2.5));
    // حزام الشنطة
    canvas.drawPath(Path()..moveTo(-8, -34)..quadraticBezierTo(-1, -26, -3, -14), Paint()
      ..color = _K.bagDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round);
    canvas.restore();

    // الدراع اللي لفوق تترسم ورا الراس عشان ما تغطيش الوش
    final armUp = p.armF > 1.6;
    if (armUp) _arm(canvas, shoulder, p.armF, p.elbowF, _K.hoodie);
    canvas.save();
    canvas.translate(hip.dx, hip.dy);
    canvas.rotate(p.lean);
    canvas.scale(1, p.squash);
    // الراس أعدل شوية من الجسم
    canvas.translate(3, -57);
    canvas.rotate(-p.lean * .5);
    _head(canvas, p);
    canvas.restore();
    if (!armUp) _arm(canvas, shoulder, p.armF, p.elbowF, _K.hoodie);
    canvas.restore();
  }

  void _arm(Canvas c, Offset s, double a, double elbow, Color col) {
    final e = s + Offset(math.sin(a) * 13, math.cos(a) * 13);
    final b = a + elbow;
    final h = e + Offset(math.sin(b) * 12, math.cos(b) * 12);
    _limb(c, [s, e, h], col, 7.5);
    _hand(c, h);
  }

  void _leg(Canvas c, Offset hip, (Offset, Offset) l, Color col, double shinAngle) {
    final foot = hip + l.$2;
    _limb(c, [hip, hip + l.$1, foot], col, 9);
    c.save();
    c.translate(foot.dx, foot.dy);
    c.rotate(-shinAngle * .8);
    final shoe = Path()..addRRect(RRect.fromLTRBR(-6, -4, 11, 5.5, const Radius.circular(4.5)));
    c.drawPath(shoe, Paint()..color = _K.shoe);
    c.drawLine(const Offset(-2, -.5), const Offset(6, -.5), Paint()
      ..color = _K.shoeStripe
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);
    c.drawPath(shoe, _ink(2.3));
    c.restore();
  }

  void _head(Canvas c, KidPose p) {
    final face = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 24));
    c.drawPath(face, Paint()..color = _K.skin);
    c.save();
    c.clipPath(face);
    final hair = Paint()..color = _K.hair;
    c.drawCircle(const Offset(-11, -13), 23, hair);
    c.drawCircle(const Offset(4, -22), 8, hair);
    c.drawCircle(const Offset(12, -20), 6, hair);
    c.drawCircle(const Offset(18, -16), 3.5, hair);
    c.drawArc(Rect.fromCircle(center: const Offset(-11, -13), radius: 16), 3.7, .9, false, Paint()
      ..color = Colors.white.withOpacity(.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
    c.restore();
    c.drawPath(face, _ink(2.6));
    // خصلة فوق
    _fillInk(c, Path()..moveTo(-6, -23)..quadraticBezierTo(-3, -35, 9, -33)..quadraticBezierTo(2, -29, 3, -23)..close(), _K.hair, w: 2);
    // الودن
    _fillInk(c, Path()..addOval(Rect.fromCircle(center: const Offset(-5, 3), radius: 6.5)), _K.skin, w: 2.2);
    c.drawArc(Rect.fromCircle(center: const Offset(-5, 3), radius: 3), 1, 3.5, false, Paint()
      ..color = _K.skinDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6);
    // العين
    c.drawOval(Rect.fromCenter(center: const Offset(11, 1), width: 6.5, height: 9.5 * p.blink), Paint()..color = _K.ink);
    if (p.blink > .5) c.drawCircle(const Offset(12.4, -1.4), 1.7, Paint()..color = Colors.white);
    c.drawLine(const Offset(7, -8), const Offset(15, -9.5), _ink(2));
    c.drawOval(Rect.fromCenter(center: const Offset(12, 9), width: 8, height: 4.5), Paint()..color = _K.blush);
    c.drawArc(Rect.fromCenter(center: const Offset(23, 3), width: 4, height: 5), -1.2, 2.4, false, _ink(1.8));
    if (p.happy) {
      final m = Path()..moveTo(13, 11)..quadraticBezierTo(18, 21, 22.5, 10.5)..close();
      _fillInk(c, m, _K.mouth, w: 1.8);
      c.drawCircle(const Offset(18, 15.5), 2, Paint()..color = const Color(0xFFF27BA6));
    } else {
      c.drawArc(Rect.fromCenter(center: const Offset(17, 9.5), width: 8, height: 6), .2, 2.3, false, _ink(2));
    }
  }

  @override
  bool shouldRepaint(covariant KidPainter old) => true;
}

class KidBackPainter extends CustomPainter {
  KidBackPainter({required this.phase, this.air = false, this.tilt = 0, this.cheer = false, this.t = 0});
  final double phase, tilt, t;
  final bool air, cheer;

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 100, size.height / 140);
    c.translate(50, 134);
    c.rotate(tilt);
    c.translate(-50, -134);
    final s = math.sin(phase);
    final bob = air || cheer ? 0.0 : (1 - math.cos(phase * 2)) * 1.6;

    // الرجلين: الرجل اللي فوق نعلها باين
    for (final (hx, lift) in [(41.0, air ? .8 : math.max(0.0, s)), (59.0, air ? .8 : math.max(0.0, -s))]) {
      final top = Offset(hx, 98 - bob);
      final foot = top + Offset(0, 31 - lift * 12);
      _limb(c, [top, foot], _K.pants, 10);
      if (lift > .25) {
        final sole = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: foot + const Offset(0, 3), width: 15, height: 7 + lift * 5), const Radius.circular(5)));
        _fillInk(c, sole, const Color(0xFFE6E6EE), w: 2.2);
        c.drawLine(foot + const Offset(-4, 3), foot + const Offset(4, 3), Paint()
          ..color = const Color(0xFFB8B8C8)
          ..strokeWidth = 2);
      } else {
        final heel = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: foot + const Offset(0, 3), width: 16, height: 8), const Radius.circular(4)));
        _fillInk(c, heel, _K.shoe, w: 2.2);
        c.drawLine(foot + const Offset(-5, 2), foot + const Offset(5, 2), Paint()
          ..color = _K.shoeStripe
          ..strokeWidth = 2.5);
      }
    }

    // الدراعين ورا الجسم (الدراع اللي قدّام بتستخبى)
    for (final (side, sw) in [(-1.0, air ? 0.0 : s), (1.0, air ? 0.0 : -s)]) {
      final sh = Offset(50 + side * 15, 66 - bob);
      final Offset hand;
      if (cheer) {
        hand = sh + Offset(side * 12, -32 + math.sin(t * 10 + side) * 3);
      } else if (air) {
        hand = sh + Offset(side * 18, -12);
      } else {
        hand = sh + Offset(side * (7 + 3 * sw), 22 - 8 * sw);
      }
      final elbow = Offset.lerp(sh, hand, .5)! + Offset(side * 5, 0);
      _limb(c, [sh, elbow, hand], _K.hoodie, 7.5);
      _hand(c, hand);
    }

    c.save();
    c.translate(0, -bob);
    _fillInk(c, Path()..addRRect(RRect.fromLTRBR(35, 51, 65, 68, const Radius.circular(10))), _K.hoodieDark);
    final body = Path()..addRRect(RRect.fromLTRBR(33, 58, 67, 103, const Radius.circular(13)));
    c.drawPath(body, Paint()..color = _K.hoodie);
    c.save();
    c.clipPath(body);
    c.drawRect(const Rect.fromLTRB(32, 97, 68, 104), Paint()..color = _K.hoodieDark);
    c.restore();
    c.drawPath(body, _ink(2.5));
    // الشنطة
    _fillInk(c, Path()..addRRect(RRect.fromLTRBR(37, 64, 63, 96, const Radius.circular(7))), _K.bag);
    _fillInk(c, Path()..addRRect(RRect.fromLTRBR(37, 64, 63, 76, const Radius.circular(7))), _K.bagDark, w: 2.2);
    _fillInk(c, Path()..addRRect(RRect.fromLTRBR(46, 72, 54, 79, const Radius.circular(2))), _K.ink, w: 1);
    _fillInk(c, Path()..addRRect(RRect.fromLTRBR(42, 84, 58, 92, const Radius.circular(3))), _K.bagDark, w: 1.8);
    // الودان والراس
    for (final x in [26.0, 74.0]) {
      _fillInk(c, Path()..addOval(Rect.fromCircle(center: Offset(x, 37), radius: 6.5)), _K.skin, w: 2.2);
    }
    final head = Path()..addOval(Rect.fromCircle(center: const Offset(50, 34), radius: 24));
    c.drawPath(head, Paint()..color = _K.skin);
    c.save();
    c.clipPath(head);
    c.drawCircle(const Offset(50, 28), 25, Paint()..color = _K.hair);
    c.drawArc(Rect.fromCircle(center: const Offset(46, 26), radius: 15), 3.6, 1.1, false, Paint()
      ..color = Colors.white.withOpacity(.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
    c.restore();
    c.drawPath(head, _ink(2.6));
    _fillInk(c, Path()..moveTo(45, 11)..quadraticBezierTo(48, 0, 59, 2)..quadraticBezierTo(52, 5, 54, 11)..close(), _K.hair, w: 2);
    c.restore();
    c.restore();
  }

  @override
  bool shouldRepaint(covariant KidBackPainter old) => true;
}

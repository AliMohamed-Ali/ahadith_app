import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hadith_core/hadith_core.dart';

import '../l10n.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/kid.dart';
import 'adventure_game.dart';

class _Rock {
  _Rock(this.word, this.x, this.seed);
  final String word;
  /// مكانها كنسبة من عرض الشاشة.
  final double x;
  final int seed;
  /// وقت ما بدأت تتكسر (لو اختارها غلط).
  double? fall;
}

/// تسلّق الجبل: الطفل بينط من صخرة لصخرة على الكلمة الصح لحد القمة ويركّز العلم.
class ClimbGame extends StatefulWidget {
  const ClimbGame({super.key, required this.game, required this.onDone});
  final GameData game;
  final VoidCallback onDone;
  @override
  State<ClimbGame> createState() => _ClimbGameState();
}

class _ClimbGameState extends State<ClimbGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _rnd = math.Random();
  late final _collect = collectSeq(widget.game);
  late final List<String> _seq = _collect.seq;
  late final List<List<_Rock>> _rows = _buildRows();
  int _at = 0;
  double _kidX = .5, _fromX = .5;
  bool _faceLeft = false;
  double _t = 0, _cam = 0, _wonAt = -1;
  /// -1 = واقف، غير كده تقدم النطة من 0 لـ 1.
  double _jumpP = -1;
  _Rock? _target;
  Size _size = Size.zero;
  Duration _last = Duration.zero;

  bool get _won => _at == _seq.length;
  double get _gap => (_size.height * .27).clamp(130.0, 190.0);
  double get _rockW => math.min(124, _size.width * .29);
  double _rowY(int k) => k * _gap;
  double _sy(double wy) => _size.height - 90 - (wy - _cam);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  List<List<_Rock>> _buildRows() {
    final decoys = decoysFor(widget.game);
    return [
      for (final word in _seq)
        () {
          final others = decoys.where((w) => w != word).toList()..shuffle(_rnd);
          final words = [word, ...others.take(_rnd.nextBool() ? 2 : 1)]..shuffle(_rnd);
          final cols = switch (words.length) { 1 => [.5], 2 => (_rnd.nextBool() ? [.27, .7] : [.3, .73]), _ => [.19, .5, .81] };
          return [for (var i = 0; i < words.length; i++) _Rock(words[i], cols[i] + (_rnd.nextDouble() - .5) * .05, _rnd.nextInt(1000))];
        }(),
    ];
  }

  void _tick(Duration e) {
    final dt = math.min((e - _last).inMicroseconds / 1e6, .05);
    _last = e;
    if (_size == Size.zero) return;
    setState(() {
      _t += dt;
      if (_jumpP >= 0) {
        _jumpP += dt / .75;
        if (_jumpP >= 1) {
          _jumpP = -1;
          _kidX = _target!.x;
          _at++;
          if (_won) {
            _wonAt = _t;
            Future.delayed(const Duration(milliseconds: 2400), () => mounted ? widget.onDone() : null);
          }
        }
      }
      final camTarget = _rowY(_at) + (_jumpP >= 0 ? _gap * Curves.easeInOut.transform(_jumpP) : 0);
      _cam += (camTarget - _cam) * math.min(1, dt * 5);
    });
  }

  void _tapRock(_Rock r) {
    if (_jumpP >= 0 || _won || r.fall != null) return;
    if (r.word == _seq[_at]) {
      _target = r;
      _fromX = _kidX;
      _faceLeft = r.x < _kidX - .01 || (r.x - _kidX).abs() <= .01 && _faceLeft;
      _jumpP = 0;
    } else {
      setState(() => r.fall = _t);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.coral, duration: const Duration(milliseconds: 1200), content: Text(S.of(context, 'tryAgain'))));
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        HadithBar(game: widget.game, seq: _seq, full: _collect.full, got: _at, t: _t, accent: AppColors.coral),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            _size = box.biggest;
            return ClipRect(
              child: Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _ClimbPainter(cam: _cam, t: _t, gap: _gap, rows: _seq.length, progress: _at / _seq.length))),
                for (var k = 0; k < _rows.length; k++)
                  if (_sy(_rowY(k + 1)) > -120 && _sy(_rowY(k + 1)) < _size.height + 80)
                    for (final r in _rows[k]) ..._rockView(k + 1, r),
                ..._kidViews(),
                if (_t < 4.5 && _at == 0) _hint(S.of(context, 'climbHint')),
                if (_won) const Positioned(left: 0, right: 0, top: 10, child: IgnorePointer(child: Center(child: ConfettiBurst(size: 300)))),
              ]),
            );
          }),
        ),
      ]);

  Widget _hint(String text) => Positioned(
        left: 16,
        right: 16,
        top: 12,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(color: AppColors.navy.withOpacity(.85), borderRadius: BorderRadius.circular(20)),
            child: Text('👆 $text', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      );

  List<Widget> _rockView(int row, _Rock r) {
    final w = _rockW;
    var dx = 0.0, dy = 0.0, rot = 0.0, op = 1.0;
    if (r.fall != null) {
      final q = _t - r.fall!;
      if (q > 1.2) return const [];
      if (q < .3) {
        dx = math.sin(q * 80) * 4;
      } else {
        final f = q - .3;
        dy = 700 * f * f;
        rot = f * 2 * (r.seed.isEven ? 1 : -1);
        op = (1 - f / .9).clamp(0.0, 1.0);
      }
    }
    final isNext = row == _at + 1 && !_won;
    final passed = row <= _at;
    final correct = r.word == _seq[row - 1];
    // الصفوف اللي لسه بعيدة من غير كلام عشان الشاشة تفضل بسيطة
    final showWord = isNext || (passed && correct);
    final glow = isNext && r.fall == null ? .5 + .5 * math.sin(_t * 5) : 0.0;
    return [
      Positioned(
        left: r.x * _size.width - w / 2 + dx,
        top: _sy(_rowY(row)) - 10 + dy,
        width: w,
        height: 74,
        child: Opacity(
          opacity: op,
          child: Transform.rotate(
            angle: rot,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isNext ? () => _tapRock(r) : null,
              child: Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _LedgePainter(r.seed, snowy: row / _seq.length > .6, glow: glow))),
                if (showWord)
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 24,
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: passed ? AppColors.gold : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.ink, width: 2),
                          ),
                          child: Text(r.word, style: hadithStyle(size: 18)),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _kidViews() {
    const h = 104.0;
    const w = h * 100 / 140;
    double x = _kidX, wy = _rowY(_at);
    KidPose pose;
    final p = _jumpP;
    if (p >= 0) {
      // توطية ← نطة في قوس ← نزول
      final air = ((p - .18) / .7).clamp(0.0, 1.0);
      x = _fromX + (_target!.x - _fromX) * Curves.easeInOut.transform(air);
      wy = _rowY(_at) + _gap * air + 80 * 4 * air * (1 - air);
      pose = p < .18 ? KidPose.crouch(p / .18) : (p < .88 ? const KidPose.jump() : KidPose.crouch((1 - p) / .12 * .6));
    } else if (_won) {
      pose = KidPose.cheer(_t);
    } else {
      pose = KidPose.idle(_t, blink: kidBlink(_t));
    }
    final feet = _sy(wy);
    final standing = p < 0;
    return [
      if (standing) Positioned(left: x * _size.width - 26, top: _sy(_rowY(_at)) - 5, child: Container(width: 52, height: 10, decoration: BoxDecoration(color: Colors.black.withOpacity(.18), borderRadius: BorderRadius.circular(10)))),
      if (_won)
        Positioned(
          left: x * _size.width + (x > .5 ? -78 : 26),
          top: feet - 96,
          child: CustomPaint(size: const Size(56, 96), painter: _FlagPainter(_t, ((_t - _wonAt) / .6).clamp(0.0, 1.0))),
        ),
      Positioned(left: x * _size.width - w / 2, top: feet - h * 131 / 140, child: Kid(pose: pose, facingLeft: _faceLeft, height: h)),
    ];
  }
}

/// صخرة بارزة من الجبل.
class _LedgePainter extends CustomPainter {
  _LedgePainter(this.seed, {this.snowy = false, this.glow = 0});
  final int seed;
  final bool snowy;
  final double glow;

  @override
  void paint(Canvas canvas, Size s) {
    final r = math.Random(seed);
    double j(double a) => (r.nextDouble() - .5) * a;
    const top = 10.0;
    final body = Path()
      ..moveTo(3, top + 4)
      ..quadraticBezierTo(s.width * .3, top - 4 + j(4), s.width * .5, top - 2)
      ..quadraticBezierTo(s.width * .75, top - 3 + j(4), s.width - 3, top + 4)
      ..lineTo(s.width - 8 + j(6), top + 26)
      ..lineTo(s.width * .72 + j(10), s.height - 12 + j(8))
      ..lineTo(s.width * .5 + j(12), s.height - 2)
      ..lineTo(s.width * .28 + j(10), s.height - 14 + j(8))
      ..lineTo(8 + j(6), top + 28)
      ..close();
    if (glow > 0) {
      canvas.drawPath(body, Paint()
        ..color = AppColors.gold.withOpacity(.35 + glow * .4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + glow * 6));
    }
    canvas.drawPath(body, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFC9B6A3), Color(0xFF7E6A5A)]).createShader(Offset.zero & s));
    // شقوق
    final crack = Paint()
      ..color = const Color(0xFF5E4E42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final cx = s.width * (.3 + r.nextDouble() * .4);
    canvas.drawPath(Path()..moveTo(cx, top + 18)..lineTo(cx + 6, top + 30)..lineTo(cx + 1, top + 42), crack);
    canvas.drawPath(body, Paint()
      ..color = const Color(0xFF4E3E33)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round);
    // الوش اللي فوق: عشب أو تلج
    final cap = Path()
      ..moveTo(3, top + 4)
      ..quadraticBezierTo(s.width * .5, top - 8, s.width - 3, top + 4)
      ..quadraticBezierTo(s.width * .8, top + 12, s.width * .62, top + 8)
      ..quadraticBezierTo(s.width * .5, top + 14, s.width * .38, top + 8)
      ..quadraticBezierTo(s.width * .2, top + 12, 3, top + 4)
      ..close();
    canvas.drawPath(cap, Paint()..color = snowy ? Colors.white : const Color(0xFF7CC46B));
    canvas.drawPath(cap, Paint()
      ..color = snowy ? const Color(0xFFB8C6E0) : const Color(0xFF4E8E3E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _LedgePainter old) => old.glow != glow || old.snowy != snowy;
}

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.t, this.raise);
  final double t, raise;
  @override
  void paint(Canvas canvas, Size s) {
    final topY = s.height - (s.height - 4) * Curves.easeOutBack.transform(raise);
    canvas.drawLine(Offset(4, s.height), Offset(4, topY), Paint()
      ..color = const Color(0xFF5E4E42)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);
    final flag = Path()..moveTo(6, topY);
    for (var x = 0.0; x <= 46; x += 4) {
      flag.lineTo(6 + x, topY + math.sin(x / 9 - t * 8) * 3 * x / 46);
    }
    for (var x = 46.0; x >= 0; x -= 4) {
      flag.lineTo(6 + x, topY + 30 + math.sin(x / 9 - t * 8) * 3 * x / 46);
    }
    flag.close();
    canvas.drawPath(flag, Paint()..color = AppColors.teal);
    canvas.drawPath(flag, Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    canvas.drawCircle(Offset(26, topY + 15 + math.sin(20 / 9 - t * 8) * 1.5), 6, Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(covariant _FlagPainter old) => true;
}

/// السما والجبل اللي ورا الصخور، بتتحرك مع الكاميرا وإحنا طالعين.
class _ClimbPainter extends CustomPainter {
  _ClimbPainter({required this.cam, required this.t, required this.gap, required this.rows, required this.progress});
  final double cam, t, gap, progress;
  final int rows;

  static double _hash(int k) => (math.sin(k * 127.1) * 43758.5453).remainder(1).abs();
  double _sy(Size s, double wy) => s.height - 90 - (wy - cam);

  @override
  void paint(Canvas c, Size s) {
    // السما بتغمق كل ما نطلع والأفق بيبقى دهبي
    final sky = Offset.zero & s;
    c.drawRect(
      sky,
      Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [
          Color.lerp(const Color(0xFF6EC6FF), const Color(0xFF3F6FC8), progress)!,
          Color.lerp(const Color(0xFFDDF3FF), const Color(0xFFFFD9A8), progress)!,
        ]).createShader(sky),
    );
    c.drawCircle(Offset(s.width * .82, 70), 46, Paint()..color = AppColors.gold.withOpacity(.25));
    c.drawCircle(Offset(s.width * .82, 70), 28, Paint()..color = AppColors.gold);

    // جبال بعيدة
    final farBase = s.height * .78 + cam * .12;
    final far = Path()..moveTo(0, s.height);
    for (var x = 0.0; x <= s.width + 8; x += 8) {
      far.lineTo(x, farBase - 110 - 60 * math.sin(x / 90 + 1).abs() - 25 * math.sin(x / 37));
    }
    far
      ..lineTo(s.width, s.height)
      ..close();
    c.drawPath(far, Paint()..color = const Color(0xFF9DB0D8));

    // سحاب بيعدي وإحنا طالعين
    final cloud = Paint()..color = Colors.white.withOpacity(.85);
    for (var i = 0; i < 24; i++) {
      final cy = s.height - 90 - (i * 150 + _hash(i) * 80 - cam * .6);
      if (cy < -60 || cy > s.height + 60) continue;
      final cx = (_hash(i + 50) * s.width + t * (8 + _hash(i) * 10)) % (s.width + 160) - 80;
      final r = 16 + _hash(i + 9) * 10;
      c.drawCircle(Offset(cx, cy), r, cloud);
      c.drawCircle(Offset(cx + r, cy - r * .5), r * 1.15, cloud);
      c.drawCircle(Offset(cx + r * 2.1, cy), r, cloud);
    }

    // الجبل نفسه: بيضيق عند القمة
    final topRow = rows * gap;
    final summit = topRow + gap * 1.2;
    double half(double wy) {
      final base = s.width * .46 + math.sin(wy / 41) * 10 + math.sin(wy / 13) * 4;
      if (wy <= topRow + 30) return base;
      return base * (1 - ((wy - topRow - 30) / (summit - topRow - 30)).clamp(0.0, 1.0));
    }

    final topY = math.max(-10.0, _sy(s, summit));
    final left = <Offset>[], right = <Offset>[];
    for (var y = s.height; y >= topY; y -= 6) {
      final wy = cam + (s.height - 90 - y);
      final h = half(wy);
      final wob = math.sin(wy / 23) * 5;
      left.add(Offset(s.width / 2 - h + wob, y));
      right.add(Offset(s.width / 2 + h - wob, y));
    }
    final cliff = Path()..addPolygon([...left, ...right.reversed], true);
    c.drawPath(cliff, Paint()..shader = const LinearGradient(colors: [Color(0xFF7C6A5C), Color(0xFFA08C79), Color(0xFF8A7767)]).createShader(sky));
    c.save();
    c.clipPath(cliff);
    final crack = Paint()
      ..color = const Color(0xFF6A5A4D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final moss = Paint()..color = const Color(0xFF6FA35A).withOpacity(.55);
    final j0 = ((cam - 200) / 55).floor();
    for (var j = j0; j < j0 + (s.height / 55).ceil() + 8; j++) {
      final x = s.width / 2 + (_hash(j) - .5) * s.width * .85;
      final y = _sy(s, j * 55 + _hash(j + 7) * 30);
      c.drawPath(Path()..moveTo(x, y)..lineTo(x + 7, y + 10)..lineTo(x + 2, y + 20)..lineTo(x + 8, y + 28), crack);
      if (_hash(j + 3) > .6 && j * 55 < topRow * .6) c.drawOval(Rect.fromCenter(center: Offset(x - 20, y + 10), width: 26, height: 9), moss);
    }
    // تلج القمة
    final snowLine = _sy(s, topRow + gap * .45);
    final snow = Path()..moveTo(0, -20);
    snow.lineTo(s.width, -20);
    for (var x = s.width; x >= 0; x -= 12) {
      snow.lineTo(x, snowLine + math.sin(x / 14) * 7);
    }
    snow.close();
    c.drawPath(snow, Paint()..color = Colors.white);
    c.restore();
    c.drawPath(cliff, Paint()
      ..color = const Color(0xFF5A4A3E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);

    // الأرض تحت ومعسكر البداية
    final gy = _sy(s, 0);
    if (gy < s.height) {
      c.drawRect(Rect.fromLTWH(0, gy, s.width, s.height - gy + 4), Paint()..color = const Color(0xFF7CC46B));
      c.drawRect(Rect.fromLTWH(0, gy, s.width, 8), Paint()..color = const Color(0xFF8FD16A));
      final tx = s.width * .13;
      final tent = Path()..moveTo(tx - 34, gy)..lineTo(tx, gy - 46)..lineTo(tx + 34, gy)..close();
      c.drawPath(tent, Paint()..color = AppColors.coral);
      c.drawPath(Path()..moveTo(tx - 10, gy)..lineTo(tx, gy - 30)..lineTo(tx + 10, gy)..close(), Paint()..color = const Color(0xFF9E3A28));
      c.drawPath(tent, Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round);
      for (var i = 0; i < 6; i++) {
        final fx = s.width * (.3 + i * .12);
        c.drawCircle(Offset(fx, gy + 18 + (i % 2) * 10), 4, Paint()..color = i.isEven ? const Color(0xFFF27BA6) : AppColors.gold);
      }
    }

    // عصافير
    final bird = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final x = (t * (30 + i * 8) + i * 170) % (s.width + 100) - 50;
      final y = 110.0 + i * 50 + math.sin(t * 2 + i) * 8;
      final flap = math.sin(t * 9 + i) * 4;
      c.drawPath(Path()..moveTo(x - 8, y - flap)..quadraticBezierTo(x - 4, y - 4, x, y)..quadraticBezierTo(x + 4, y - 4, x + 8, y - flap), bird);
    }
  }

  @override
  bool shouldRepaint(covariant _ClimbPainter old) => true;
}

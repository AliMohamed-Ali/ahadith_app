import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hadith_core/hadith_core.dart';

import '../l10n.dart';
import '../services/sounds.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/kid.dart';
import 'adventure_game.dart';

class _Token {
  _Token(this.word, this.lane, this.d);
  final String word;
  final int lane;
  /// المسافة قدّام الكاميرا بالمتر.
  double d;
  bool? good;
  double fx = 0;
}

/// مغامرة القطر: الطفل بيجري فوق 3 قطورات ماشية، يغيّر القطر يمين وشمال وينط، ويجمع كلمات الحديث.
class TrainRunGame extends StatefulWidget {
  const TrainRunGame({super.key, required this.game, required this.onDone});
  final GameData game;
  final VoidCallback onDone;
  @override
  State<TrainRunGame> createState() => _TrainRunGameState();
}

class _TrainRunGameState extends State<TrainRunGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _rnd = math.Random();
  late final _collect = collectSeq(widget.game);
  late final List<String> _seq = _collect.seq;
  late final List<String> _decoys = decoysFor(widget.game);
  final List<_Token> _tokens = [];
  int _got = 0, _lane = 0;
  double _laneX = 0, _t = 0, _dist = 0, _stumble = 0, _nextWave = .8;
  /// -1 = على السطح، غير كده تقدم النطة من 0 لـ 1.
  double _air = -1;
  Size _size = Size.zero;
  Duration _last = Duration.zero;

  // سرعة هادية، والكلمات بتظهر من مسافة قريبة كفاية إنها تتقري.
  static const _speed = 8.0, _d0 = 2.6, _laneW = 1.7, _dFar = 75.0, _dSpawn = 30.0;

  bool get _won => _got == _seq.length;
  String get _next => _seq[_got];

  // كاميرا بمنظور: نقطة التلاشي في نص الأفق.
  double get _horizon => _size.height * .3;
  double get _f => _size.width * .62;
  double get _camH => (_size.height * .88 - _horizon) * _d0 / _f;
  double get _camX => _laneX * _laneW * .55;
  Offset _proj(double x, double up, double d) => Offset(_size.width / 2 + _f * (x - _camX) / d, _horizon + _f * (_camH - up) / d);
  double get _jumpUp => _air < 0 ? 0 : 1.5 * 4 * _air * (1 - _air);

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

  void _move(int dir) {
    final next = (_lane + dir).clamp(-1, 1);
    if (next != _lane) Sounds.play(Sfx.swish);
    _lane = next;
  }

  void _jump() {
    if (_air < 0) {
      _air = 0;
      Sounds.play(Sfx.jump);
    }
  }

  void _tick(Duration e) {
    final dt = math.min((e - _last).inMicroseconds / 1e6, .05);
    _last = e;
    if (_size == Size.zero) return;
    setState(() {
      _t += dt;
      _dist += _speed * dt;
      _stumble = math.max(0, _stumble - dt);
      _laneX += (_lane - _laneX) * math.min(1, dt * 14);
      if (_air >= 0) {
        _air += dt / .75;
        if (_air >= 1) _air = _won ? 0 : -1;
      }
      if (!_won) {
        _nextWave -= dt;
        if (_nextWave <= 0) _wave();
      }
      for (final k in _tokens) {
        if (k.good != null) {
          k.fx += dt / .5;
          continue;
        }
        final prev = k.d;
        k.d -= _speed * dt;
        if (!_won && prev > _d0 && k.d <= _d0 && k.lane == _lane) _hit(k);
      }
      _tokens.removeWhere((k) => k.fx >= 1 || k.d < .7);
    });
  }

  void _wave() {
    _nextWave = 2.3 + _rnd.nextDouble() * .5;
    final first = _got == 0 && _tokens.isEmpty;
    final nextAlive = _tokens.any((k) => k.good == null && k.word == _next);
    final others = _decoys.where((w) => w != _next).toList();
    final lanes = [-1, 0, 1]..shuffle(_rnd);
    // أول كلمة في نفس سكة الطفل عشان يفهم اللعبة
    if (first) {
      lanes
        ..remove(_lane)
        ..insert(0, _lane);
    }
    var i = 0;
    if (!nextAlive) _tokens.add(_Token(_next, lanes[i++], _dSpawn));
    // دايمًا فيه سكة فاضية يهرب فيها
    final nDecoys = first || others.isEmpty ? 0 : (nextAlive || _rnd.nextDouble() < .6 ? 1 : 0);
    for (var k = 0; k < nDecoys && i < 3; k++) {
      _tokens.add(_Token(others[_rnd.nextInt(others.length)], lanes[i++], _dSpawn));
    }
  }

  void _hit(_Token k) {
    // المقارنة بالكلمة نفسها: لو كلمة غلط بقت هي اللي عليها الدور تتحسب صح.
    if (k.word == _next) {
      k.good = true;
      _got++;
      Sounds.play(_won ? Sfx.levelUp : Sfx.coin);
      if (_won) {
        _air = 0;
        Future.delayed(const Duration(milliseconds: 1800), () => mounted ? widget.onDone() : null);
      }
    } else if (_air < 0) {
      k.good = false;
      _stumble = .6;
      Sounds.play(Sfx.bump);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.coral, duration: const Duration(milliseconds: 1200), content: Text(S.of(context, 'tryAgain'))));
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        HadithBar(game: widget.game, seq: _seq, full: _collect.full, got: _got, t: _t, accent: const Color(0xFF3C8DDB)),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            _size = box.biggest;
            final sorted = [..._tokens]..sort((a, b) => b.d.compareTo(a.d));
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: (e) {
                final v = e.velocity.pixelsPerSecond.dx;
                if (v.abs() > 80) _move(v > 0 ? 1 : -1);
              },
              onVerticalDragEnd: (e) {
                if (e.velocity.pixelsPerSecond.dy < -80) _jump();
              },
              onTapUp: (e) {
                final x = e.localPosition.dx / _size.width;
                x < .33 ? _move(-1) : (x > .67 ? _move(1) : _jump());
              },
              child: ClipRect(
                child: Stack(children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RailPainter(dist: _dist, t: _t, camX: _camX, horizon: _horizon, f: _f, camH: _camH, laneW: _laneW, dFar: _dFar),
                    ),
                  ),
                  for (final k in sorted.where((k) => k.d > _d0 || k.good != null)) _tokenView(k),
                  ..._kidViews(),
                  for (final k in sorted.where((k) => k.d <= _d0 && k.good == null)) _tokenView(k),
                  if (_t < 5 && !_won)
                    Positioned(
                      left: 16,
                      right: 16,
                      top: 12,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.navy.withOpacity(.85), borderRadius: BorderRadius.circular(20)),
                          child: Text('👈 👆 👉  ${S.of(context, 'runHint')}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                      ),
                    ),
                  if (_won) const Positioned(left: 0, right: 0, top: 10, child: IgnorePointer(child: Center(child: ConfettiBurst(size: 300)))),
                ]),
              ),
            );
          }),
        ),
      ]);

  Widget _tokenView(_Token k) {
    // الكلمة بتمشي في عمود السكة بتاعتها (مش بتلزق في نص الشاشة من بعيد)، وحجمها مقروء من أول ما تظهر.
    final near = (1 - (k.d - _d0) / (_dSpawn - _d0)).clamp(0.0, 1.0);
    final real = _proj(k.lane * _laneW, 1.3 + math.sin(_t * 3 + k.lane) * .06, k.d);
    final column = _proj(k.lane * _laneW, 0, _d0).dx;
    final p = Offset(real.dx + (column - real.dx) * .8, real.dy);
    final scale = .62 + .43 * Curves.easeIn.transform(near);
    final q = Curves.easeOut.transform(k.fx.clamp(0.0, 1.0));
    var dx = 0.0, dy = 0.0, rot = 0.0, op = ((_dSpawn - k.d) / 4).clamp(0.0, 1.0);
    var s = scale;
    if (k.good == true) {
      dy = -q * (p.dy + 40);
      s = scale * (1 + q * .3);
      op = 1 - q * .8;
    } else if (k.good == false) {
      dx = (k.lane <= 0 ? -1 : 1) * q * 160;
      dy = -q * 120;
      rot = q * 2.5;
      op = 1 - q;
    }
    final w = _size.width / 3 - 8;
    return Positioned(
      left: p.dx - w / 2 + dx,
      top: p.dy - 70 + dy,
      width: w,
      height: 70,
      child: IgnorePointer(
        child: Opacity(
          opacity: op,
          child: Transform.rotate(
            angle: rot,
            child: Transform.scale(
              scale: s,
              alignment: Alignment.bottomCenter,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white, AppColors.cream]),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.gold, width: 4),
                      boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(.7), blurRadius: 14, spreadRadius: 1)],
                    ),
                    child: Text(k.word, style: hadithStyle(size: 26)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _kidViews() {
    const h = 124.0;
    const w = h * 100 / 140;
    final x = _laneX * _laneW;
    final roof = _proj(x, 0, _d0);
    final feet = _proj(x, _jumpUp, _d0);
    final shadowW = 56 * (1 - _jumpUp / 3);
    return [
      Positioned(
        left: roof.dx - shadowW / 2,
        top: roof.dy - 6,
        child: Container(width: shadowW, height: 12, decoration: BoxDecoration(color: Colors.black.withOpacity(.25), borderRadius: BorderRadius.circular(12))),
      ),
      Positioned(
        left: feet.dx - w / 2,
        top: feet.dy - h * 134 / 140,
        child: Opacity(
          opacity: _stumble > 0 && (_t * 20).floor().isEven ? .4 : 1,
          child: KidBack(
            phase: _t * 12,
            air: _air >= 0,
            tilt: (_lane - _laneX) * -.35 + (_stumble > 0 ? math.sin(_t * 40) * .08 : 0),
            cheer: _won,
            t: _t,
            height: h,
          ),
        ),
      ),
    ];
  }
}

/// الدنيا: سما، أرض، أشجار وأعمدة، و3 قطورات ماشية بمنظور.
class _RailPainter extends CustomPainter {
  _RailPainter({required this.dist, required this.t, required this.camX, required this.horizon, required this.f, required this.camH, required this.laneW, required this.dFar});
  final double dist, t, camX, horizon, f, camH, laneW, dFar;

  static const _roofH = 3.2;
  static const _fog = Color(0xFFDDEBF2);
  static const _trains = [Color(0xFFE8573A), Color(0xFF3C8DDB), Color(0xFF1FA59A)];

  static double _hash(int k) => (math.sin(k * 127.1) * 43758.5453).remainder(1).abs();

  Offset _p(Size s, double x, double up, double d) => Offset(s.width / 2 + f * (x - camX) / d, horizon + f * (camH - up) / d);
  Color _fogged(Color c, double d) => Color.lerp(c, _fog, math.pow((d / dFar).clamp(0.0, 1.0), 1.3).toDouble())!;

  void _quad(Canvas c, Size s, double x0, double x1, double up, double dn, double df, Paint p) {
    c.drawPath(Path()..addPolygon([_p(s, x0, up, dn), _p(s, x1, up, dn), _p(s, x1, up, df), _p(s, x0, up, df)], true), p);
  }

  @override
  void paint(Canvas c, Size s) {
    // السما والشمس
    final skyRect = Rect.fromLTWH(0, 0, s.width, horizon + 2);
    c.drawRect(skyRect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6EC3F7), Color(0xFFFFE4C4)]).createShader(skyRect));
    final sun = Offset(s.width * .72 - camX * 4, horizon - 42);
    c.drawCircle(sun, 44, Paint()..color = AppColors.gold.withOpacity(.25));
    c.drawCircle(sun, 26, Paint()..color = AppColors.gold);
    final cloud = Paint()..color = Colors.white.withOpacity(.9);
    for (var i = 0; i < 3; i++) {
      final cx = (i * 160 + t * 6 - camX * 8) % (s.width + 120) - 60;
      final cy = 26.0 + i * 22;
      c.drawCircle(Offset(cx, cy), 13, cloud);
      c.drawCircle(Offset(cx + 14, cy - 7), 16, cloud);
      c.drawCircle(Offset(cx + 30, cy), 13, cloud);
    }
    // تلال بعيدة
    final hills = Path()..moveTo(0, horizon + 2);
    for (var x = 0.0; x <= s.width + 8; x += 8) {
      final u = x + camX * 10;
      hills.lineTo(x, horizon - 14 - 16 * math.sin(u / 70).abs() - 6 * math.sin(u / 23));
    }
    hills
      ..lineTo(s.width, horizon + 2)
      ..close();
    c.drawPath(hills, Paint()..color = const Color(0xFFA9C7A0));

    // الأرض
    final groundRect = Rect.fromLTWH(0, horizon, s.width, s.height - horizon);
    c.drawRect(groundRect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFC9DFA8), Color(0xFF6FAE4E)]).createShader(groundRect));
    // خطوط الغيط
    final row = Paint()
      ..color = const Color(0xFF5E9C42).withOpacity(.35)
      ..strokeWidth = 2;
    for (final x in const <double>[-24, -18, -13, -9, 9, 13, 18, 24]) {
      c.drawLine(_p(s, x, -_roofH, 1.2), _p(s, x, -_roofH, dFar), row);
    }
    // سكة القطر تحت
    _quad(c, s, -3, 3, -_roofH, 1, dFar, Paint()..color = const Color(0xFFA39A8F));

    // أشجار وأعمدة على الجناب (من البعيد للقريب)
    final props = <(double, void Function())>[];
    const treeGap = 9.0;
    final ti = (dist / treeGap).floor();
    for (var k = ti; k < ti + (dFar / treeGap).ceil() + 1; k++) {
      final d = k * treeGap - dist;
      if (d < 1.2 || d > dFar) continue;
      for (final side in [-1.0, 1.0]) {
        final h = _hash(k * 2 + (side > 0 ? 1 : 0));
        final x = side * (5.5 + h * 6);
        props.add((d, () => _tree(c, s, x, d, h)));
      }
    }
    const poleGap = 22.0;
    final pi0 = (dist / poleGap).floor();
    for (var k = pi0; k < pi0 + (dFar / poleGap).ceil() + 1; k++) {
      final d = k * poleGap - dist + 5;
      if (d < 1.2 || d > dFar) continue;
      for (final side in [-1.0, 1.0]) {
        props.add((d, () => _pole(c, s, side * 3.3, d)));
      }
    }
    props.sort((a, b) => b.$1.compareTo(a.$1));
    for (final pr in props) {
      pr.$2();
    }

    // الفراغ بين القطورات
    for (final gx in [-laneW / 2, laneW / 2]) {
      _quad(c, s, gx - .13, gx + .13, 0, 1, dFar, Paint()..color = const Color(0xFF3A3A4A));
    }

    // القطورات: كل عربية لوحدها من البعيد للقريب
    const carLen = 15.0, period = 16.4;
    final first = (dist / period).floor();
    for (var k = first + (dFar / period).ceil() + 1; k >= first; k--) {
      final dn = k * period - dist;
      final df = dn + carLen;
      if (df < 1 || dn > dFar) continue;
      for (var lane = -1; lane <= 1; lane++) {
        _car(c, s, lane, math.max(dn, 1), math.min(df, dFar), dn >= 1);
      }
    }

    // خطوط سرعة
    final streak = Paint()
      ..color = Colors.white.withOpacity(.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final ph = (t * 1.6 + _hash(i)) % 1;
      final x = (i.isEven ? -1 : 1) * (2.4 + _hash(i + 3) * 1.5);
      final d = 8 - ph * 7;
      c.drawLine(_p(s, x, 1 + _hash(i + 5) * 2, d), _p(s, x, 1 + _hash(i + 5) * 2, d + 1.5), streak);
    }
  }

  void _car(Canvas c, Size s, int lane, double dn, double df, bool showBack) {
    final base = _trains[lane + 1];
    final cx = lane * laneW;
    const hw = .72;
    final mid = (dn + df) / 2;
    // ضهر العربية اللي باصص للكاميرا
    if (showBack) {
      final back = Path()..addPolygon([_p(s, cx - hw, 0, dn), _p(s, cx + hw, 0, dn), _p(s, cx + hw, -_roofH, dn), _p(s, cx - hw, -_roofH, dn)], true);
      c.drawPath(back, Paint()..color = _fogged(Color.lerp(base, Colors.black, .3)!, dn));
      final win = Path()..addPolygon([_p(s, cx - .35, -.4, dn), _p(s, cx + .35, -.4, dn), _p(s, cx + .35, -1.8, dn), _p(s, cx - .35, -1.8, dn)], true);
      c.drawPath(win, Paint()..color = _fogged(const Color(0xFF2B3550), dn));
    }
    // السطح
    _quad(c, s, cx - hw, cx + hw, 0, dn, df, Paint()..color = _fogged(base, mid));
    _quad(c, s, cx - .18, cx + .18, .01, dn, df, Paint()..color = _fogged(Color.lerp(base, Colors.white, .3)!, mid));
    _quad(c, s, cx - hw, cx - hw + .08, .01, dn, df, Paint()..color = _fogged(Color.lerp(base, Colors.black, .25)!, mid));
    _quad(c, s, cx + hw - .08, cx + hw, .01, dn, df, Paint()..color = _fogged(Color.lerp(base, Colors.black, .25)!, mid));
    // فتحات تهوية
    for (final v in [3.0, 10.0]) {
      final a = dn + v, b = a + 1;
      if (a < dn || b > df || a < 1) continue;
      _quad(c, s, cx - .3, cx + .3, .02, a, b, Paint()..color = _fogged(const Color(0xFF55607A), a));
    }
  }

  void _tree(Canvas c, Size s, double x, double d, double h) {
    final base = _p(s, x, -_roofH, d);
    final top = _p(s, x, -_roofH + 3 + h * 2.5, d);
    c.drawLine(base, top, Paint()
      ..color = _fogged(const Color(0xFF7A5A32), d)
      ..strokeWidth = math.max(1, f * .35 / d));
    final r = f * (1.3 + h * .8) / d;
    final leaf = Paint()..color = _fogged(h > .5 ? const Color(0xFF3E9B4F) : const Color(0xFF4FAE5C), d);
    c.drawCircle(top, r, leaf);
    c.drawCircle(top + Offset(-r * .55, r * .35), r * .75, leaf);
    c.drawCircle(top + Offset(r * .55, r * .35), r * .75, leaf);
  }

  void _pole(Canvas c, Size s, double x, double d) {
    final paint = Paint()
      ..color = _fogged(const Color(0xFF6B7280), d)
      ..strokeWidth = math.max(1, f * .14 / d)
      ..strokeCap = StrokeCap.round;
    final top = _p(s, x, 2.4, d);
    c.drawLine(_p(s, x, -_roofH, d), top, paint);
    c.drawLine(top, _p(s, x - x.sign * .7, 2.4, d), paint);
    c.drawCircle(_p(s, x - x.sign * .7, 2.25, d), math.max(1.5, f * .14 / d), Paint()..color = _fogged(AppColors.gold, d));
  }

  @override
  bool shouldRepaint(covariant _RailPainter old) => true;
}

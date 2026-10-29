import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hadith_core/hadith_core.dart';

import '../l10n.dart';
import '../services/sounds.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/kid.dart';

/// كلمات جملة اللعبة (قبل + الإجابة + بعد).
List<String> hadithWords(GameData g) => '${g.before} ${g.answer} ${g.after}'.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

/// الكلمات اللي الطفل هيجمعها: الجملة كلها لو مناسبة، غير كده الكلمة الناقصة بس.
({List<String> seq, bool full}) collectSeq(GameData g) {
  final w = hadithWords(g);
  final full = w.length >= 3 && w.length <= 9;
  return (seq: full ? w : [g.answer], full: full);
}

/// كلمات غلط للتمويه.
List<String> decoysFor(GameData g) => {...g.wrongOptions, ...hadithWords(g)}.toList();

/// الحديث فوق اللعبة: اللي اتجمع دهبي، واللي عليه الدور بينوّر.
class HadithBar extends StatelessWidget {
  const HadithBar({super.key, required this.game, required this.seq, required this.full, required this.got, required this.t, required this.accent});
  final GameData game;
  final List<String> seq;
  final bool full;
  final int got;
  final double t;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final pulse = .5 + .5 * math.sin(t * 6);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(12),
      decoration: cardBox(),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 6, children: [
          if (!full && game.before.isNotEmpty) Text(game.before, style: hadithStyle(size: 20)),
          for (var k = 0; k < seq.length; k++)
            if (k < got)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(12)),
                child: Text(seq[k], style: hadithStyle(size: 20)),
              )
            else if (k == got)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color.lerp(AppColors.teal, accent, pulse)!, width: 3),
                ),
                child: Text(full ? seq[k] : '  ؟  ', style: hadithStyle(size: 20, color: AppColors.teal)),
              )
            else
              Text(seq[k], style: hadithStyle(size: 20, color: AppColors.muted.withOpacity(.35))),
          if (!full && game.after.isNotEmpty) Text(game.after, style: hadithStyle(size: 20)),
        ]),
      ),
    );
  }
}

enum AdvLayer { peaks, snowPeaks, hills, dunes, pines, roundTrees, fruitTrees, palms, fence, waves }

enum AdvSky { clouds, stars, snow }

/// حركة الصاحب: بينط، بيمشي، أو بيطير.
enum AdvPal { hop, walk, fly }

/// عوالم المغامرة: الطفل بيجري ومعاه صاحبه وبيجمع كلمات الحديث.
enum AdventureWorld {
  mountains('advMountains', '🦅', AdvPal.fly, '🌸', Color(0xFF8FD3FF), Color(0xFFDFF3FF), AdvLayer.snowPeaks, Color(0xFF8C9CC4), AdvLayer.hills, Color(0xFF7CC46B), Color(0xFF5DAA4E), Color(0xFF8FD16A), AdvSky.clouds, Color(0xFF4FA8F0)),
  farm('advFarm', '🐇', AdvPal.hop, '🥕', Color(0xFF9EDBFF), Color(0xFFFFF6D8), AdvLayer.hills, Color(0xFFA8D88A), AdvLayer.fence, Color(0xFFC68B59), Color(0xFF9BCB5A), Color(0xFFB8E07A), AdvSky.clouds, Color(0xFFF0644A)),
  desert('advDesert', '🐪', AdvPal.walk, '💧', Color(0xFFFFC27A), Color(0xFFFFEBC2), AdvLayer.dunes, Color(0xFFE9B872), AdvLayer.palms, Color(0xFF3E9B4F), Color(0xFFF2CF8A), Color(0xFFF7DDA4), AdvSky.clouds, Color(0xFFC27A10)),
  sea('advSea', '🐬', AdvPal.hop, '🐚', Color(0xFF7FD0F5), Color(0xFFD8F1FB), AdvLayer.waves, Color(0xFF3BA7D9), AdvLayer.palms, Color(0xFF2E9B5F), Color(0xFFF5DEA3), Color(0xFFFFF0C2), AdvSky.clouds, Color(0xFF0E7C74)),
  forest('advForest', '🦉', AdvPal.fly, '🍄', Color(0xFF9ED8B0), Color(0xFFE6F7D9), AdvLayer.pines, Color(0xFF3E7D5A), AdvLayer.roundTrees, Color(0xFF4F9E4F), Color(0xFF6B8E3D), Color(0xFF8FBF5A), AdvSky.clouds, Color(0xFF3E9B4F)),
  snow('advSnow', '🐧', AdvPal.walk, '❄️', Color(0xFFA7C8F2), Color(0xFFEEF5FF), AdvLayer.snowPeaks, Color(0xFFB8C6E0), AdvLayer.pines, Color(0xFF2F6B55), Color(0xFFF4F8FF), Color(0xFFFFFFFF), AdvSky.snow, Color(0xFF4FA8F0)),
  night('advNight', '🐈', AdvPal.walk, '⭐', Color(0xFF1E2A5A), Color(0xFF3B4C8A), AdvLayer.hills, Color(0xFF2C3E7A), AdvLayer.roundTrees, Color(0xFF22335F), Color(0xFF3A5A3A), Color(0xFF4F7A4F), AdvSky.stars, Color(0xFFF5B82E)),
  river('advRiver', '🦆', AdvPal.walk, '🐟', Color(0xFF9EDBFF), Color(0xFFE0F6FF), AdvLayer.hills, Color(0xFF9ACD7A), AdvLayer.waves, Color(0xFF4FB3E8), Color(0xFF7CC46B), Color(0xFF9BDB7A), AdvSky.clouds, Color(0xFF4FA8F0)),
  orchard('advOrchard', '🐑', AdvPal.hop, '🍎', Color(0xFFAEE2FF), Color(0xFFFFF3E0), AdvLayer.hills, Color(0xFF9BCB5A), AdvLayer.fruitTrees, Color(0xFF5DAA4E), Color(0xFF8FD16A), Color(0xFFACE08A), AdvSky.clouds, Color(0xFFF0644A)),
  jungle('advJungle', '🐒', AdvPal.hop, '🍌', Color(0xFF7FD6A8), Color(0xFFD8F5E0), AdvLayer.roundTrees, Color(0xFF2E8B57), AdvLayer.palms, Color(0xFF1F7A4A), Color(0xFF7A5A32), Color(0xFF4E9B3A), AdvSky.clouds, Color(0xFFF5B82E));

  const AdventureWorld(this.titleKey, this.pal, this.palMove, this.item, this.skyTop, this.skyBottom, this.far, this.farColor, this.mid, this.midColor, this.ground, this.groundTop, this.sky, this.accent);
  final String titleKey;
  final String pal;
  final AdvPal palMove;
  final String item;
  final Color skyTop, skyBottom;
  final AdvLayer far, mid;
  final Color farColor, midColor;
  final Color ground, groundTop;
  final AdvSky sky;
  final Color accent;
}

class _Item {
  _Item(this.word, this.air, this.x);
  final String word;
  final bool air;
  double x;
  /// null = لسه ماشية، true = اتجمعت، false = خبطت فيها غلط.
  bool? good;
  /// تقدم أنيميشن الجمع/الخبطة من 0 لـ 1.
  double fx = 0;
}

/// لعبة المغامرة: الطفل بيجري في العالم، يدوس على الشاشة عشان ينط، ويجمع كلمات الحديث بالترتيب.
class AdventureGame extends StatefulWidget {
  const AdventureGame({super.key, required this.game, required this.world, required this.onDone});
  final GameData game;
  final AdventureWorld world;
  final VoidCallback onDone;
  @override
  State<AdventureGame> createState() => _AdventureGameState();
}

class _AdventureGameState extends State<AdventureGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _rnd = math.Random();
  late final _collect = collectSeq(widget.game);
  late final List<String> _seq = _collect.seq;
  late final List<String> _decoys = decoysFor(widget.game);
  final List<_Item> _items = [];
  int _got = 0;
  int _sinceGood = 0;
  Size _size = Size.zero;
  Duration _last = Duration.zero;
  double _t = 0, _dist = 0, _nextSpawn = .6, _hurt = 0;
  /// -1 = على الأرض، غير كده تقدم النطة من 0 لـ 1.
  double _jump = -1;

  bool get _won => _got == _seq.length;
  String get _next => _seq[_got];

  // المقاسات
  double get _groundY => _size.height - (_size.height * .16).clamp(56.0, 100.0);
  double get _jumpH => math.min(_size.height * .42, 180);
  double get _kidX => _size.width * .74;
  double get _kidLift => _jump < 0 ? 0 : _jumpH * 4 * _jump * (1 - _jump);
  double get _speed => (_size.width * .3).clamp(110.0, 190.0);
  double _itemY(bool air) => air ? _groundY - _jumpH * .85 - 30 : _groundY - 34;

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

  void _tap() {
    if (_jump < 0) {
      _jump = 0;
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
      _hurt = math.max(0, _hurt - dt);
      if (_jump >= 0) {
        _jump += dt / .85;
        // بعد الفوز الطفل يفضل ينط من الفرحة
        if (_jump >= 1) _jump = _won ? 0 : -1;
      }
      if (!_won) {
        _nextSpawn -= dt;
        if (_nextSpawn <= 0) _spawn();
      }
      final kidY = _groundY - 46 - _kidLift;
      for (final it in _items) {
        if (it.good != null) {
          it.fx += dt / .6;
          continue;
        }
        it.x += _speed * dt;
        if (!_won && (it.x - _kidX).abs() < 46 && (_itemY(it.air) - kidY).abs() < 58) _hit(it);
      }
      _items.removeWhere((it) => it.fx >= 1 || it.x > _size.width + 100);
    });
  }

  void _spawn() {
    _nextSpawn = 1.25 + _rnd.nextDouble() * .5;
    final first = _got == 0 && _items.isEmpty;
    final nextAlive = _items.any((it) => it.good == null && it.word == _next);
    final others = _decoys.where((w) => w != _next).toList();
    final good = !nextAlive && (others.isEmpty || first || _sinceGood >= 2 || _rnd.nextDouble() < .5);
    if (!good && others.isEmpty) return;
    _sinceGood = good ? 0 : _sinceGood + 1;
    // أول كلمة دايمًا على الأرض عشان الطفل يفهم اللعبة
    _items.add(_Item(good ? _next : others[_rnd.nextInt(others.length)], !first && _rnd.nextBool(), -90));
  }

  void _hit(_Item it) {
    // المقارنة بالكلمة نفسها: لو كلمة غلط بقت هي اللي عليها الدور تتحسب صح.
    if (it.word == _next) {
      it.good = true;
      _got++;
      Sounds.play(_won ? Sfx.levelUp : Sfx.coin);
      if (_won) {
        _jump = 0;
        Future.delayed(const Duration(milliseconds: 1600), () => mounted ? widget.onDone() : null);
      }
    } else {
      it.good = false;
      _hurt = .5;
      Sounds.play(Sfx.bump);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.coral, duration: const Duration(milliseconds: 1200), content: Text(S.of(context, 'tryAgain'))));
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        HadithBar(game: widget.game, seq: _seq, full: _collect.full, got: _got, t: _t, accent: widget.world.accent),
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            _size = box.biggest;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _tap(),
              child: ClipRect(
                child: Stack(children: [
                  Positioned.fill(child: CustomPaint(painter: _WorldPainter(widget.world, _dist, _t, _groundY))),
                  for (final it in _items) _itemView(it),
                  ..._palViews(),
                  _kidView(),
                  if (_t < 4 && !_won)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 12,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.navy.withOpacity(.85), borderRadius: BorderRadius.circular(20)),
                          child: Text('👆 ${S.of(context, 'advHint')}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        ),
                      ),
                    ),
                  if (_won) const Positioned(left: 0, right: 0, top: 10, child: IgnorePointer(child: Center(child: ConfettiBurst(size: 280)))),
                ]),
              ),
            );
          }),
        ),
      ]);

  Widget _itemView(_Item it) {
    final y = _itemY(it.air);
    final p = Curves.easeOut.transform(it.fx.clamp(0.0, 1.0));
    var dx = 0.0, dy = 0.0, rot = 0.0, scale = 1.0;
    if (it.good == true) {
      dy = -p * (y + 60);
      scale = 1 + p * .4;
    } else if (it.good == false) {
      dx = -p * 120;
      dy = -p * 140;
      rot = -p * 3;
    } else {
      dy = math.sin(_t * 3 + it.x / 50) * 4;
    }
    return Positioned(
      left: it.x - 70 + dx,
      top: y - 45 + dy,
      width: 140,
      height: 90,
      child: IgnorePointer(
        child: Opacity(
          opacity: it.good == null ? 1 : 1 - p * .9,
          child: Transform.rotate(
            angle: rot,
            child: Transform.scale(
              scale: scale,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(widget.world.item, style: const TextStyle(fontSize: 26)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: it.good == true ? AppColors.gold : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: widget.world.accent, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 3), blurRadius: 4)],
                    ),
                    child: Text(it.word, style: hadithStyle(size: 18)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------- الصاحب ----------
  List<Widget> _palViews() {
    final w = widget.world;
    final ph = _dist / 18;
    final x = _kidX + 66;
    final lift = switch (w.palMove) {
          AdvPal.hop => math.sin(ph * .5).abs() * 26,
          AdvPal.walk => math.sin(ph).abs() * 4,
          AdvPal.fly => 90 + math.sin(_t * 3) * 12,
        } +
        (_won ? math.sin(_t * 8).abs() * 20 : 0);
    final top = _groundY - 58 - lift;
    return [
      Positioned(left: x - 28, top: top, child: Text(w.pal, style: const TextStyle(fontSize: 46))),
      if (_t < 3.5)
        Positioned(
          right: _size.width - x - 30,
          top: top - 44,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: w.accent, width: 2)),
            child: Text(S.of(context, 'advLetsGo'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.navy)),
          ),
        ),
    ];
  }

  Widget _kidView() => Positioned(
        left: _kidX - 39,
        top: _groundY - 105 - _kidLift,
        child: Opacity(
          opacity: _hurt > 0 && (_t * 20).floor().isEven ? .4 : 1,
          child: Kid(
            facingLeft: true,
            pose: _won ? (_jump >= 0 ? const KidPose.jump() : KidPose.cheer(_t)) : (_jump >= 0 ? const KidPose.jump() : KidPose.run(_t * 11, blink: kidBlink(_t))),
          ),
        ),
      );
}

/// خلفية العالم: سما + طبقتين بتتحركوا بسرعات مختلفة + أرض.
class _WorldPainter extends CustomPainter {
  _WorldPainter(this.w, this.dist, this.t, this.groundY);
  final AdventureWorld w;
  final double dist, t, groundY;

  static const _brown = Color(0xFF8A5A2B);

  static double _hash(int k) => (math.sin(k * 127.1) * 43758.5453).remainder(1).abs();

  @override
  void paint(Canvas canvas, Size s) {
    final skyRect = Offset.zero & s;
    canvas.drawRect(skyRect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [w.skyTop, w.skyBottom]).createShader(skyRect));
    final night = w.sky == AdvSky.stars;
    if (night) {
      final rnd = math.Random(5);
      for (var i = 0; i < 40; i++) {
        final o = Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * groundY * .7);
        final tw = .25 + .75 * math.sin(t * (1.5 + rnd.nextDouble() * 2) + i).abs();
        canvas.drawCircle(o, 1 + rnd.nextDouble() * 1.6, Paint()..color = Colors.white.withOpacity(tw));
      }
      canvas.drawCircle(const Offset(60, 55), 28, Paint()..color = AppColors.cream);
      canvas.drawCircle(const Offset(72, 47), 25, Paint()..color = w.skyTop);
    } else {
      canvas.drawCircle(const Offset(56, 52), 44, Paint()..color = AppColors.gold.withOpacity(.25));
      canvas.drawCircle(const Offset(56, 52), 28, Paint()..color = AppColors.gold);
    }
    if (w.sky == AdvSky.clouds) _clouds(canvas, s);
    _layer(canvas, s, w.far, w.farColor, dist * .15, s.height * .45);
    _layer(canvas, s, w.mid, w.midColor, dist * .45, s.height * .25);
    _ground(canvas, s);
    if (w.sky == AdvSky.snow) {
      final rnd = math.Random(9);
      final flake = Paint()..color = Colors.white;
      for (var i = 0; i < 40; i++) {
        final x = (rnd.nextDouble() * s.width + math.sin(t + i) * 12 + dist * .2) % s.width;
        final y = (rnd.nextDouble() * s.height + t * (30 + rnd.nextDouble() * 30)) % s.height;
        canvas.drawCircle(Offset(x, y), 2 + rnd.nextDouble() * 2, flake);
      }
    }
  }

  void _clouds(Canvas canvas, Size s) {
    final cloud = Paint()..color = Colors.white.withOpacity(.9);
    for (var i = 0; i < 4; i++) {
      final x = (dist * .05 + t * (6 + i * 3) + i * 190) % (s.width + 160) - 80;
      final y = 30 + i * groundY / 6;
      final r = 16.0 + (i % 2) * 6;
      canvas.drawCircle(Offset(x, y), r, cloud);
      canvas.drawCircle(Offset(x + r, y - r * .5), r * 1.15, cloud);
      canvas.drawCircle(Offset(x + r * 2.1, y), r, cloud);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y - 2, r * 2.1, r), Radius.circular(r / 2)), cloud);
    }
  }

  /// يرسم أشكال متكررة بتتحرك ناحية اليمين (لأن الطفل بيجري شمال).
  void _repeat(Size s, double period, double o, void Function(double x, double hash) draw) {
    final first = (o / period).floor();
    final shift = o - first * period;
    for (var k = -2; k <= s.width / period + 1; k++) {
      draw(k * period + shift, _hash(k - first));
    }
  }

  void _layer(Canvas canvas, Size s, AdvLayer type, Color color, double o, double h) {
    final paint = Paint()..color = color;
    final base = groundY;
    switch (type) {
      case AdvLayer.peaks:
      case AdvLayer.snowPeaks:
        const p = 240.0;
        _repeat(s, p, o, (x, r) {
          final top = Offset(x + p * .5, base - h * (.65 + .35 * r));
          final left = Offset(x - p * .2, base);
          final right = Offset(x + p * 1.2, base);
          canvas.drawPath(Path()..moveTo(left.dx, left.dy)..lineTo(top.dx, top.dy)..lineTo(right.dx, right.dy)..close(), paint);
          if (type == AdvLayer.snowPeaks) {
            final l = Offset.lerp(top, left, .28)!;
            final rr = Offset.lerp(top, right, .28)!;
            final mid = Offset((l.dx + rr.dx) / 2, l.dy - 6);
            canvas.drawPath(
              Path()
                ..moveTo(top.dx, top.dy)
                ..lineTo(rr.dx, rr.dy)
                ..lineTo((rr.dx + mid.dx) / 2, rr.dy + 6)
                ..lineTo(mid.dx, mid.dy)
                ..lineTo((l.dx + mid.dx) / 2, l.dy + 6)
                ..lineTo(l.dx, l.dy)
                ..close(),
              Paint()..color = Colors.white,
            );
          }
        });
      case AdvLayer.hills:
      case AdvLayer.dunes:
      case AdvLayer.waves:
        final path = Path()..moveTo(0, base);
        for (var x = 0.0; x <= s.width + 8; x += 8) {
          final u = x - o;
          final y = switch (type) {
            AdvLayer.hills => base - h * (.55 + .25 * math.sin(u / 170) + .2 * math.sin(u / 67)),
            AdvLayer.dunes => base - h * (.5 + .4 * math.sin(u / 260)),
            _ => base - h * .5 + math.sin(u / 30 + t * 2) * 4,
          };
          path.lineTo(x, y);
        }
        path
          ..lineTo(s.width, base)
          ..close();
        canvas.drawPath(path, paint);
        if (type == AdvLayer.waves) {
          final foam = Paint()
            ..color = Colors.white.withOpacity(.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round;
          _repeat(s, 70, o, (x, r) {
            final y = base - h * (.15 + .25 * r);
            canvas.drawArc(Rect.fromCenter(center: Offset(x, y), width: 26, height: 10), math.pi, math.pi, false, foam);
          });
        }
      case AdvLayer.pines:
        _repeat(s, 60, o, (x, r) {
          final th = h * (.6 + .4 * r);
          canvas.drawRect(Rect.fromLTWH(x - 3, base - 14, 6, 14), Paint()..color = _brown);
          for (var k = 0; k < 3; k++) {
            final y0 = base - 10 - k * th * .28;
            final half = 22.0 - k * 5;
            canvas.drawPath(Path()..moveTo(x - half, y0)..lineTo(x, y0 - th * .42)..lineTo(x + half, y0)..close(), paint);
          }
          if (w.sky == AdvSky.snow) {
            canvas.drawPath(Path()..moveTo(x - 6, base - 10 - th * .56 - th * .42 + 14)..lineTo(x, base - 10 - th * .56 - th * .42)..lineTo(x + 6, base - 10 - th * .56 - th * .42 + 14)..close(), Paint()..color = Colors.white);
          }
        });
      case AdvLayer.roundTrees:
      case AdvLayer.fruitTrees:
        _repeat(s, 110, o, (x, r) {
          final th = h * (.55 + .45 * r);
          final cr = 22 + 12 * r;
          canvas.drawRect(Rect.fromLTWH(x - 5, base - th, 10, th), Paint()..color = _brown);
          final c = Offset(x, base - th - cr * .6);
          canvas.drawCircle(c, cr, paint);
          canvas.drawCircle(c + Offset(-cr * .6, cr * .3), cr * .7, paint);
          canvas.drawCircle(c + Offset(cr * .6, cr * .3), cr * .7, paint);
          if (type == AdvLayer.fruitTrees) {
            final apple = Paint()..color = const Color(0xFFE8473A);
            for (var k = 0; k < 5; k++) {
              final a = k * 1.3 + r * 6;
              canvas.drawCircle(c + Offset(math.cos(a) * cr * .7, math.sin(a) * cr * .6), 4.5, apple);
            }
          }
        });
      case AdvLayer.palms:
        _repeat(s, 150, o, (x, r) {
          final th = h * (.75 + .25 * r);
          final top = Offset(x + 14, base - th);
          canvas.drawPath(
            Path()
              ..moveTo(x, base)
              ..quadraticBezierTo(x - 8, base - th * .5, top.dx, top.dy),
            Paint()
              ..color = _brown
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8
              ..strokeCap = StrokeCap.round,
          );
          final leaf = Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round;
          for (var k = 0; k < 5; k++) {
            final a = -math.pi / 2 + (k - 2) * .65;
            final end = top + Offset(math.cos(a) * 34, math.sin(a) * 34 + 22);
            canvas.drawPath(Path()..moveTo(top.dx, top.dy)..quadraticBezierTo(top.dx + math.cos(a) * 26, top.dy + math.sin(a) * 26 - 8, end.dx, end.dy), leaf);
          }
        });
      case AdvLayer.fence:
        // الحظيرة الحمرا
        _repeat(s, 640, o, (x, r) {
          final bh = h * .95;
          final body = Rect.fromLTWH(x, base - bh, 110, bh);
          canvas.drawRect(body, Paint()..color = const Color(0xFFD9483B));
          canvas.drawPath(Path()..moveTo(x - 10, base - bh)..lineTo(x + 55, base - bh - 40)..lineTo(x + 120, base - bh)..close(), Paint()..color = const Color(0xFF8E2F25));
          final door = Rect.fromLTWH(x + 35, base - bh * .55, 40, bh * .55);
          canvas.drawRect(door, Paint()..color = Colors.white);
          final cross = Paint()
            ..color = const Color(0xFFD9483B)
            ..strokeWidth = 4;
          canvas.drawLine(door.topLeft, door.bottomRight, cross);
          canvas.drawLine(door.topRight, door.bottomLeft, cross);
        });
        final rail = Paint()
          ..color = color
          ..strokeWidth = 5;
        canvas.drawLine(Offset(0, base - h * .38), Offset(s.width, base - h * .38), rail);
        canvas.drawLine(Offset(0, base - h * .18), Offset(s.width, base - h * .18), rail);
        _repeat(s, 36, o, (x, r) => canvas.drawRect(Rect.fromLTWH(x - 3, base - h * .5, 6, h * .5), paint));
    }
  }

  void _ground(Canvas canvas, Size s) {
    canvas.drawRect(Rect.fromLTWH(0, groundY, s.width, s.height - groundY), Paint()..color = w.ground);
    canvas.drawRect(Rect.fromLTWH(0, groundY, s.width, 10), Paint()..color = w.groundTop);
    final deco = Paint()..color = w.groundTop;
    _repeat(s, 46, dist, (x, r) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x, groundY + 22 + r * (s.height - groundY - 34)), width: 14 + r * 10, height: 5), deco);
    });
  }

  @override
  bool shouldRepaint(covariant _WorldPainter old) => old.dist != dist || old.t != t || old.groundY != groundY || old.w != w;
}

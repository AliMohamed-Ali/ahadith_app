import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../services/sounds.dart';
import '../state/progress_store.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/fanoos.dart';
import 'adventure_game.dart';
import 'climb_game.dart';
import 'puzzle_game.dart';
import 'river_screen.dart';
import 'train_run_game.dart';

// ألعاب المغامرة (نفس أسامي AdventureWorld) متوزعة بين الألعاب التانية عشان تتنوع.
enum GameKind { fish, climb, puzzle, mountains, bubbles, trainRun, farm, train, desert, balloons, sea, order, forest, stars, snow, butterflies, night, river, orchard, jungle }

extension on GameKind {
  AdventureWorld? get world => AdventureWorld.values.asNameMap()[name];
}

/// ألعاب الحديث: صيد السمك، الفقاعات، القطار، البالونات، رتّب الحديث، النجوم، الفراشات،
/// و10 مغامرات الطفل بيجري فيها ويجمع كلمات الحديث.
/// تتبدل حسب ترتيب الحديث.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.flow});
  final FlowCtx flow;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameKind kind = _chooseKind();
  late final List<String> options = [...widget.flow.hadith.game.options]..shuffle(math.Random());
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  late final AnimationController _leave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  final Set<String> _wrong = {};
  bool _solved = false;

  Hadith get h => widget.flow.hadith;
  double get _sec => _clock.value * 60;

  GameKind _chooseKind() {
    final k = GameKind.values[widget.flow.index % GameKind.values.length];
    // لعبة الترتيب محتاجة جملة مش طويلة قوي ولا قصيرة قوي.
    if (k == GameKind.order && !_OrderGame.fits(h.game)) return GameKind.balloons;
    if (k == GameKind.puzzle && !PuzzleGame.fits(h.game)) return GameKind.bubbles;
    return k;
  }

  /// للتجربة بس (Debug): ينقل للعبة اللي بعدها على نفس الحديث.
  void _debugNextKind() {
    var next = GameKind.values[(kind.index + 1) % GameKind.values.length];
    if (next == GameKind.order && !_OrderGame.fits(h.game) || next == GameKind.puzzle && !PuzzleGame.fits(h.game)) next = GameKind.values[(next.index + 1) % GameKind.values.length];
    setState(() {
      kind = next;
      _wrong.clear();
      _solved = false;
      _leave.reset();
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    _leave.dispose();
    super.dispose();
  }

  void _pick(String o) {
    if (_solved || _wrong.contains(o)) return;
    if (o == h.game.answer) {
      Sounds.play(kind == GameKind.bubbles || kind == GameKind.balloons ? Sfx.pop : Sfx.correct);
      setState(() => _solved = true);
      _leave.forward();
      Future.delayed(const Duration(milliseconds: 250), () => Sounds.play(Sfx.whoosh));
      Future.delayed(const Duration(milliseconds: 1200), _win);
    } else {
      Sounds.play(Sfx.wrong);
      setState(() => _wrong.add(o));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.coral, duration: const Duration(milliseconds: 1200), content: Text(S.of(context, 'tryAgain'))));
    }
  }

  void _win() {
    if (!mounted) return;
    final p = context.read<ProgressStore>();
    final f = widget.flow;
    p.winGame(h, openTab: f.openTab, levelId: f.level?.id, levelHadithIds: f.tab.usesLevels ? f.levelHadithIds : null);
    showWinSheet(context, f);
  }

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final g = h.game;
    final titleKey = switch (kind) {
      GameKind.fish => 'gameFish',
      GameKind.bubbles => 'gameBubbles',
      GameKind.train => 'gameTrain',
      GameKind.balloons => 'gameBalloons',
      GameKind.order => 'gameOrder',
      GameKind.stars => 'gameStars',
      GameKind.butterflies => 'gameButterflies',
      GameKind.climb => 'gameClimb',
      GameKind.trainRun => 'gameTrainRun',
      GameKind.puzzle => 'gamePuzzle',
      _ => kind.world!.titleKey,
    };
    final bg = switch (kind) {
      GameKind.train => const Color(0xFFFFF6E0),
      GameKind.balloons => const Color(0xFFCDEBFF),
      GameKind.order => const Color(0xFFFFEEF4),
      GameKind.stars => const Color(0xFF1E2A5A),
      GameKind.butterflies => const Color(0xFFE6F7D9),
      GameKind.puzzle => const Color(0xFFFDF1DC),
      _ => const Color(0xFFD8F1FB),
    };
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(title: Text(S.of(context, titleKey)), actions: [
        if (kDebugMode) IconButton(tooltip: 'Next game (debug)', icon: const Icon(Icons.skip_next_rounded), onPressed: _debugNextKind),
      ]),
      body: !g.isValid
          ? _MemorizeMode(hadith: h, onDone: _win)
          : kind == GameKind.climb
          ? ClimbGame(key: ValueKey(kind), game: g, onDone: _win)
          : kind == GameKind.puzzle
          ? PuzzleGame(key: ValueKey(kind), game: g, onDone: _win)
          : kind == GameKind.trainRun
          ? TrainRunGame(key: ValueKey(kind), game: g, onDone: _win)
          : kind.world != null
          ? AdventureGame(key: ValueKey(kind), game: g, world: kind.world!, onDone: _win)
          : kind == GameKind.order
          ? _OrderGame(key: ValueKey(kind), game: g, onDone: _win)
          : Column(children: [
              // الجملة مع الفراغ
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: cardBox(),
                child: Column(children: [
                  Text(S.of(context, 'completeHadith'), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.teal)),
                  const SizedBox(height: 8),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 6, children: [
                      if (g.before.isNotEmpty) Text(g.before, style: hadithStyle(size: 24)),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                        decoration: BoxDecoration(
                          color: _solved ? AppColors.gold : AppColors.mint,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _solved ? AppColors.goldDark : AppColors.teal, width: 2),
                        ),
                        child: Text(_solved ? g.answer : '  ؟  ', style: hadithStyle(size: 24)),
                      ),
                      if (g.after.isNotEmpty) Text(g.after, style: hadithStyle(size: 24)),
                    ]),
                  ),
                ]),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) => AnimatedBuilder(
                    animation: Listenable.merge([_clock, _leave]),
                    builder: (context, _) => switch (kind) {
                      GameKind.fish => _fish(box.biggest),
                      GameKind.bubbles => _bubbles(box.biggest),
                      GameKind.train => _train(box.biggest, ar),
                      GameKind.balloons => _balloons(box.biggest),
                      GameKind.stars => _stars(box.biggest),
                      GameKind.butterflies => _butterflies(box.biggest),
                      _ => const SizedBox.shrink(),
                    },
                  ),
                ),
              ),
            ]),
    );
  }

  static const _palette = [Color(0xFFFF8A3D), Color(0xFF9B7BEA), Color(0xFFF27BA6), Color(0xFF3CC7A8), Color(0xFF4FA8F0)];

  // ---------- صيد السمك ----------
  Widget _fish(Size s) {
    final n = options.length;
    final lane = (s.height - 40) / n;
    return Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _SeaPainter(_sec))),
      for (var i = 0; i < n; i++)
        Builder(builder: (_) {
          final o = options[i];
          final speed = 38 + i * 9.0;
          final dirRight = i.isEven;
          final span = s.width + 180;
          var x = (_sec * speed + i * 140) % span - 150;
          if (!dirRight) x = s.width - x - 150;
          final y = 20 + i * lane + math.sin(_sec * 2 + i) * 8;
          final caught = _solved && o == h.game.answer;
          return Positioned(
            left: caught ? s.width / 2 - 75 : x,
            top: caught ? y - _leave.value * (y + 60) : y,
            child: _Tappable(
              disabled: _wrong.contains(o),
              onTap: () => _pick(o),
              child: _FishView(word: o, color: _palette[i % _palette.length], facingRight: dirRight),
            ),
          );
        }),
    ]);
  }

  // ---------- الفقاعات ----------
  Widget _bubbles(Size s) {
    final n = options.length;
    final col = s.width / n;
    return Stack(children: [
      for (var i = 0; i < n; i++)
        Builder(builder: (_) {
          final o = options[i];
          const size = 120.0;
          final span = s.height + size;
          final y = s.height - ((_sec * (34 + i * 7) + i * 110) % span);
          final x = col * i + col / 2 - size / 2 + math.sin(_sec * 1.6 + i * 2) * 14;
          final popped = _solved && o == h.game.answer;
          return Positioned(
            left: x,
            top: y,
            child: _Tappable(
              disabled: _wrong.contains(o),
              onTap: () => _pick(o),
              child: Transform.scale(
                scale: popped ? 1 + _leave.value * 0.6 : 1,
                child: Opacity(opacity: popped ? (1 - _leave.value).clamp(0.0, 1.0) : 1, child: _BubbleView(word: o, size: size, color: _palette[i % _palette.length])),
              ),
            ),
          );
        }),
    ]);
  }

  // ---------- القطار ----------
  Widget _train(Size s, bool ar) {
    final g = h.game;
    final shift = -Curves.easeIn.transform(_leave.value) * (s.width + 400);
    final wagons = <Widget>[
      const _Loco(),
      if (g.before.isNotEmpty) _Wagon(word: g.before, color: const Color(0xFF4FA8F0)),
      _Wagon(word: _solved ? g.answer : '؟', color: _solved ? AppColors.gold : Colors.white, dashed: !_solved),
      if (g.after.isNotEmpty) _Wagon(word: g.after, color: const Color(0xFF3CC7A8)),
    ];
    return Column(children: [
      const SizedBox(height: 10),
      SizedBox(
        height: 120,
        child: ClipRect(
          child: Stack(children: [
            Positioned(left: 0, right: 0, bottom: 14, child: Container(height: 6, color: const Color(0xFF8A5A2B))),
            Positioned(
              right: 12 - shift,
              bottom: 18,
              // القطار دايمًا من اليمين للشمال (زي النص العربي)، والقاطرة في الأول.
              child: Directionality(textDirection: TextDirection.rtl, child: Row(mainAxisSize: MainAxisSize.min, children: wagons)),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 18),
      Text(S.of(context, 'trainHint'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
        for (var i = 0; i < options.length; i++)
          _Tappable(
            disabled: _wrong.contains(options[i]) || (_solved && options[i] == g.answer),
            onTap: () => _pick(options[i]),
            child: Transform.translate(
              offset: Offset(0, math.sin(_sec * 3 + i) * 3),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFC68B59), borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Color(0xFF8A5A2B), offset: Offset(0, 5))]),
                child: Text(options[i], style: hadithStyle(size: 22, color: Colors.white)),
              ),
            ),
          ),
      ]),
    ]);
  }

  // ---------- البالونات ----------
  Widget _balloons(Size s) {
    final n = options.length;
    final col = s.width / n;
    return Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _SkyPainter(_sec))),
      for (var i = 0; i < n; i++)
        Builder(builder: (_) {
          final o = options[i];
          final span = s.height + _BalloonView.height;
          final y = s.height - ((_sec * (30 + i * 6) + i * 130) % span);
          final x = col * i + col / 2 - _BalloonView.width / 2 + math.sin(_sec * 1.2 + i * 2) * 16;
          final popped = _solved && o == h.game.answer;
          return Positioned(
            left: x,
            top: y,
            child: _Tappable(
              disabled: _wrong.contains(o),
              onTap: () => _pick(o),
              child: Transform.scale(
                scale: popped ? 1 + _leave.value * 0.8 : 1,
                child: Opacity(opacity: popped ? (1 - _leave.value).clamp(0.0, 1.0) : 1, child: _BalloonView(word: o, color: _palette[i % _palette.length])),
              ),
            ),
          );
        }),
    ]);
  }

  // ---------- النجوم ----------
  Widget _stars(Size s) {
    final n = options.length;
    final col = s.width / n;
    const size = 124.0;
    return Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _NightPainter(_sec))),
      for (var i = 0; i < n; i++)
        Builder(builder: (_) {
          final o = options[i];
          // النجوم بتنزل من فوق لتحت
          final y = (_sec * (26 + i * 6) + i * 140) % (s.height + size) - size;
          final x = col * i + col / 2 - size / 2 + math.sin(_sec * .9 + i * 2) * 10;
          final caught = _solved && o == h.game.answer;
          return Positioned(
            left: x,
            top: caught ? y - _leave.value * (y + size + 40) : y,
            child: _Tappable(
              disabled: _wrong.contains(o),
              onTap: () => _pick(o),
              child: Transform.scale(
                scale: caught ? 1 + _leave.value * 0.5 : 1,
                child: _StarView(word: o, size: size, angle: math.sin(_sec * 1.4 + i) * .25, glow: caught),
              ),
            ),
          );
        }),
    ]);
  }

  // ---------- الفراشات ----------
  Widget _butterflies(Size s) {
    final n = options.length;
    final lane = (s.height - 50) / n;
    const w = _ButterflyView.width;
    return Stack(children: [
      Positioned.fill(child: CustomPaint(painter: _GardenPainter(_sec))),
      for (var i = 0; i < n; i++)
        Builder(builder: (_) {
          final o = options[i];
          final phase = _sec * (.45 + i * .1) + i * 1.7;
          final x = (s.width - w) / 2 * (1 + math.sin(phase));
          final y = 10 + i * lane + math.sin(_sec * 2.2 + i) * 12;
          final flown = _solved && o == h.game.answer;
          return Positioned(
            left: x,
            top: flown ? y - _leave.value * (y + 120) : y,
            child: _Tappable(
              disabled: _wrong.contains(o),
              onTap: () => _pick(o),
              child: _ButterflyView(word: o, color: _palette[i % _palette.length], flap: math.sin(_sec * (flown ? 22 : 9) + i).abs()),
            ),
          );
        }),
    ]);
  }
}

class _Tappable extends StatelessWidget {
  const _Tappable({required this.child, required this.onTap, this.disabled = false});
  final Widget child;
  final VoidCallback onTap;
  final bool disabled;
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: disabled ? 0.25 : 1,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: disabled ? null : onTap, child: child),
      );
}

class _FishView extends StatelessWidget {
  const _FishView({required this.word, required this.color, required this.facingRight});
  final String word;
  final Color color;
  final bool facingRight;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        height: 70,
        child: Stack(alignment: Alignment.center, children: [
          Transform.flip(flipX: !facingRight, child: CustomPaint(size: const Size(150, 70), painter: _FishPainter(color))),
          Padding(
            padding: EdgeInsets.only(left: facingRight ? 0 : 24, right: facingRight ? 24 : 0),
            child: Text(word, maxLines: 1, overflow: TextOverflow.ellipsis, style: hadithStyle(size: 18, color: Colors.white)),
          ),
        ]),
      );
}

class _FishPainter extends CustomPainter {
  _FishPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = color;
    // الذيل على الشمال والرأس يمين
    canvas.drawPath(Path()..moveTo(30, s.height / 2)..lineTo(2, 10)..lineTo(2, s.height - 10)..close(), p);
    canvas.drawOval(Rect.fromLTWH(22, 6, s.width - 26, s.height - 12), p);
    canvas.drawCircle(Offset(s.width - 24, s.height / 2 - 8), 6, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(s.width - 22, s.height / 2 - 8), 3, Paint()..color = AppColors.navy);
  }

  @override
  bool shouldRepaint(covariant _FishPainter old) => old.color != color;
}

class _SeaPainter extends CustomPainter {
  _SeaPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = Colors.white.withOpacity(.6);
    final rnd = math.Random(3);
    for (var i = 0; i < 14; i++) {
      final x = rnd.nextDouble() * s.width;
      final y = s.height - ((t * (20 + rnd.nextDouble() * 20) + rnd.nextDouble() * s.height) % s.height);
      canvas.drawCircle(Offset(x, y), 3 + rnd.nextDouble() * 5, p);
    }
    final weed = Paint()
      ..color = const Color(0xFF3E9B4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final x = s.width * (i + .5) / 6;
      final sway = math.sin(t * 1.5 + i) * 10;
      canvas.drawPath(Path()..moveTo(x, s.height)..quadraticBezierTo(x + sway, s.height - 30, x - sway / 2, s.height - 60), weed);
    }
  }

  @override
  bool shouldRepaint(covariant _SeaPainter old) => old.t != t;
}

class _BubbleView extends StatelessWidget {
  const _BubbleView({required this.word, required this.size, required this.color});
  final String word;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(center: const Alignment(-.4, -.4), colors: [Colors.white, color.withOpacity(.75)]),
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: FittedBox(child: Text(word, style: hadithStyle(size: 20))),
      );
}

class _Loco extends StatelessWidget {
  const _Loco();
  @override
  Widget build(BuildContext context) => Container(
        width: 86,
        height: 74,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(color: AppColors.coral, borderRadius: BorderRadius.circular(14)),
        child: const Center(child: Fanoos(size: 40, swing: false, mood: FanoosMood.happy)),
      );
}

class _Wagon extends StatelessWidget {
  const _Wagon({required this.word, required this.color, this.dashed = false});
  final String word;
  final Color color;
  final bool dashed;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 80),
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: dashed ? AppColors.teal : Colors.black12, width: dashed ? 3 : 1),
        ),
        child: Text(word, style: hadithStyle(size: 20, color: onColor(color))),
      );
}

class _BalloonView extends StatelessWidget {
  const _BalloonView({required this.word, required this.color});
  final String word;
  final Color color;
  static const width = 110.0;
  static const height = 170.0;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _BalloonPainter(color))),
          Positioned(
            left: 14,
            right: 14,
            top: 18,
            height: 88,
            child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text(word, style: hadithStyle(size: 20, color: Colors.white)))),
          ),
        ]),
      );
}

class _BalloonPainter extends CustomPainter {
  _BalloonPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final body = Rect.fromLTWH(4, 0, s.width - 8, 124);
    canvas.drawOval(body, Paint()..shader = RadialGradient(center: const Alignment(-.35, -.4), colors: [Color.lerp(color, Colors.white, .35)!, color]).createShader(body));
    // اللمعة
    canvas.drawOval(const Rect.fromLTWH(22, 16, 16, 28), Paint()..color = Colors.white.withOpacity(.55));
    // العقدة والخيط
    final cx = s.width / 2;
    canvas.drawPath(Path()..moveTo(cx, 120)..lineTo(cx - 7, 132)..lineTo(cx + 7, 132)..close(), Paint()..color = color);
    canvas.drawPath(
      Path()
        ..moveTo(cx, 132)
        ..quadraticBezierTo(cx - 10, 148, cx, 156)
        ..quadraticBezierTo(cx + 10, 164, cx, s.height),
      Paint()
        ..color = AppColors.muted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _BalloonPainter old) => old.color != color;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size s) {
    // الشمس
    canvas.drawCircle(Offset(s.width - 40, 40), 46, Paint()..color = AppColors.gold.withOpacity(.25));
    canvas.drawCircle(Offset(s.width - 40, 40), 30, Paint()..color = AppColors.gold);
    // سحاب ماشي
    final cloud = Paint()..color = Colors.white.withOpacity(.9);
    for (var i = 0; i < 4; i++) {
      final x = (t * (10 + i * 4) + i * 170) % (s.width + 160) - 80;
      final y = 30 + i * s.height / 4.5;
      final r = 18.0 + (i % 2) * 6;
      canvas.drawCircle(Offset(x, y), r, cloud);
      canvas.drawCircle(Offset(x + r, y - r * .5), r * 1.15, cloud);
      canvas.drawCircle(Offset(x + r * 2.1, y), r, cloud);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y - 2, r * 2.1, r), Radius.circular(r / 2)), cloud);
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.t != t;
}

class _StarView extends StatelessWidget {
  const _StarView({required this.word, required this.size, required this.angle, this.glow = false});
  final String word;
  final double size;
  final double angle;
  final bool glow;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          Transform.rotate(angle: angle, child: CustomPaint(size: Size.square(size), painter: _StarPainter(glow))),
          SizedBox(
            width: size * .5,
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(word, style: hadithStyle(size: 18))),
          ),
        ]),
      );
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.glow);
  final bool glow;
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final outer = s.width / 2 - 4;
    final inner = outer * .55;
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final r = k.isEven ? outer : inner;
      final a = -math.pi / 2 + k * math.pi / 5;
      final p = c + Offset(math.cos(a) * r, math.sin(a) * r);
      k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()
      ..color = AppColors.gold.withOpacity(glow ? .9 : .45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow ? 16 : 8));
    canvas.drawPath(path, Paint()..shader = const RadialGradient(colors: [AppColors.cream, AppColors.gold]).createShader(Rect.fromCircle(center: c, radius: outer)));
    canvas.drawPath(path, Paint()
      ..color = AppColors.goldDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.glow != glow;
}

class _NightPainter extends CustomPainter {
  _NightPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size s) {
    final rnd = math.Random(7);
    for (var i = 0; i < 45; i++) {
      final o = Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height);
      final twinkle = .25 + .75 * math.sin(t * (1.5 + rnd.nextDouble() * 2) + i).abs();
      canvas.drawCircle(o, 1 + rnd.nextDouble() * 1.8, Paint()..color = Colors.white.withOpacity(twinkle));
    }
    // الهلال
    final m = Offset(46, s.height - 60);
    canvas.drawCircle(m, 30, Paint()..color = AppColors.cream);
    canvas.drawCircle(m + const Offset(12, -8), 27, Paint()..color = const Color(0xFF1E2A5A));
  }

  @override
  bool shouldRepaint(covariant _NightPainter old) => old.t != t;
}

class _ButterflyView extends StatelessWidget {
  const _ButterflyView({required this.word, required this.color, required this.flap});
  final String word;
  final Color color;
  /// من 0 (الجناحات مقفولة) لـ 1 (مفتوحة).
  final double flap;
  static const width = 140.0;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: 84,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(size: const Size(width, 84), painter: _ButterflyPainter(color, .35 + flap * .65)),
          Container(
            constraints: const BoxConstraints(maxWidth: width - 20),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.92), borderRadius: BorderRadius.circular(14)),
            child: FittedBox(fit: BoxFit.scaleDown, child: Text(word, style: hadithStyle(size: 18))),
          ),
        ]),
      );
}

class _ButterflyPainter extends CustomPainter {
  _ButterflyPainter(this.color, this.open);
  final Color color;
  final double open;
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final wing = Paint()..color = color;
    final spot = Paint()..color = Colors.white.withOpacity(.5);
    for (final side in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(cx, 0);
      canvas.scale(side * open, 1);
      canvas.drawOval(const Rect.fromLTWH(2, 2, 62, 44), wing);
      canvas.drawOval(const Rect.fromLTWH(4, 40, 44, 38), wing);
      canvas.drawCircle(const Offset(42, 20), 8, spot);
      canvas.restore();
    }
    final body = Paint()..color = AppColors.navy;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, s.height / 2), width: 8, height: 64), const Radius.circular(4)), body);
    final antenna = Paint()
      ..color = AppColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(Offset(cx, 12), Offset(cx - 10, 0), antenna);
    canvas.drawLine(Offset(cx, 12), Offset(cx + 10, 0), antenna);
  }

  @override
  bool shouldRepaint(covariant _ButterflyPainter old) => old.open != open || old.color != color;
}

class _GardenPainter extends CustomPainter {
  _GardenPainter(this.t);
  final double t;
  static const _petals = [Color(0xFFF27BA6), AppColors.gold, Color(0xFF9B7BEA), AppColors.coral];
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Rect.fromLTWH(0, s.height - 34, s.width, 34), Paint()..color = const Color(0xFF8FD16A));
    final stem = Paint()
      ..color = const Color(0xFF3E9B4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    for (var i = 0; i < 7; i++) {
      final x = s.width * (i + .5) / 7;
      final sway = math.sin(t * 1.3 + i) * 6;
      final top = Offset(x + sway, s.height - 70 - (i % 3) * 14);
      canvas.drawLine(Offset(x, s.height - 20), top, stem);
      final petal = Paint()..color = _petals[i % _petals.length];
      for (var k = 0; k < 5; k++) {
        final a = k * 2 * math.pi / 5 + t * .3;
        canvas.drawCircle(top + Offset(math.cos(a) * 9, math.sin(a) * 9), 7, petal);
      }
      canvas.drawCircle(top, 6, Paint()..color = AppColors.goldDark);
    }
  }

  @override
  bool shouldRepaint(covariant _GardenPainter old) => old.t != t;
}

/// "رتّب الحديث": الطفل يدوس على كلمات الجملة بالترتيب.
class _OrderGame extends StatefulWidget {
  const _OrderGame({super.key, required this.game, required this.onDone});
  final GameData game;
  final VoidCallback onDone;

  static List<String> wordsOf(GameData g) => hadithWords(g);

  static bool fits(GameData g) {
    final n = wordsOf(g).length;
    return n >= 3 && n <= 9;
  }

  @override
  State<_OrderGame> createState() => _OrderGameState();
}

class _OrderGameState extends State<_OrderGame> with SingleTickerProviderStateMixin {
  late final List<String> words = _OrderGame.wordsOf(widget.game);
  late final List<int> pool = _shuffled();
  final List<int> placed = [];
  int? _shaking;
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));

  bool get _done => placed.length == words.length;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  List<int> _shuffled() {
    final l = List.generate(words.length, (i) => i);
    final r = math.Random();
    for (var tries = 0; tries < 10; tries++) {
      l.shuffle(r);
      if (!List.generate(l.length, (i) => words[l[i]] == words[i]).every((x) => x)) break;
    }
    return l;
  }

  void _tap(int i) {
    if (_done || placed.contains(i)) return;
    // المقارنة بالكلمة نفسها عشان لو فيه كلمة متكررة أي نسخة منها تنفع.
    if (words[i] == words[placed.length]) {
      Sounds.play(placed.length == words.length - 1 ? Sfx.levelUp : Sfx.snap);
      setState(() => placed.add(i));
      if (_done) Future.delayed(const Duration(milliseconds: 1100), () => mounted ? widget.onDone() : null);
    } else {
      Sounds.play(Sfx.wrong);
      setState(() => _shaking = i);
      _shake.forward(from: 0);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.coral, duration: const Duration(milliseconds: 1200), content: Text(S.of(context, 'tryAgain'))));
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: Fanoos(size: 70, mood: _done ? FanoosMood.happy : FanoosMood.talk)),
        const SizedBox(height: 8),
        Text(S.of(context, 'orderHint'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.teal)),
        const SizedBox(height: 12),
        // الجملة اللي بتتبني
        Stack(alignment: Alignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: cardBox(color: _done ? AppColors.cream : Colors.white),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 8, children: [
                for (var k = 0; k < words.length; k++)
                  k < placed.length
                      ? TweenAnimationBuilder<double>(
                          tween: Tween(begin: .4, end: 1),
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.elasticOut,
                          builder: (_, v, child) => Transform.scale(scale: v, child: child),
                          child: _chip(words[k], AppColors.gold),
                        )
                      : Container(
                          width: 56,
                          height: 44,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.mintLine, width: 3)),
                        ),
              ]),
            ),
          ),
          if (_done) const IgnorePointer(child: ConfettiBurst(size: 260)),
        ]),
        const SizedBox(height: 28),
        // الكلمات المتلخبطة
        Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 14, children: [
            for (final i in pool)
              AnimatedBuilder(
                animation: _shake,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_shaking == i ? math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value) : 0, 0),
                  child: child,
                ),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: placed.contains(i) ? 0 : 1,
                  child: GestureDetector(
                    onTap: () => _tap(i),
                    child: _chip(words[i], _GameScreenState._palette[i % _GameScreenState._palette.length], raised: true),
                  ),
                ),
              ),
          ]),
        ),
      ]);

  Widget _chip(String w, Color c, {bool raised = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(14),
          boxShadow: raised ? [BoxShadow(color: Color.lerp(c, Colors.black, .3)!, offset: const Offset(0, 5))] : null,
        ),
        child: Text(w, style: hadithStyle(size: 22, color: onColor(c))),
      );
}

/// لو المدير لم يضع بيانات لعبة: الطفل يقرأ الحديث ويضغط "حفظته".
class _MemorizeMode extends StatelessWidget {
  const _MemorizeMode({required this.hadith, required this.onDone});
  final Hadith hadith;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
        const Center(child: Fanoos(size: 90, mood: FanoosMood.talk)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: cardBox(),
          child: Text(hadith.text, textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: hadithStyle(size: 22)),
        ),
        const SizedBox(height: 18),
        Text(S.of(context, 'memorizeHint'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 14),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)), onPressed: onDone, child: Text(S.of(context, 'memorized'))),
      ]);
}

/// شاشة الفوز: نبتة الحديقة + النجمة + مهمة الحياة الحقيقية.
Future<void> showWinSheet(BuildContext context, FlowCtx f) async {
  Sounds.play(Sfx.win);
  Future.delayed(const Duration(milliseconds: 900), () => Sounds.play(Sfx.star));
  final ar = S.ar(context);
  final p = context.read<ProgressStore>();
  final cfg = context.read<AppConfig>().rewards;
  final wins = p.wins(f.hadith.id);
  final stage = RewardsCalculator(cfg).plantStage(wins);
  final mission = f.hadith.mission(ar);
  final next = f.next;
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(alignment: Alignment.center, children: [
            const ConfettiBurst(size: 240),
            Column(children: [
              Text(S.of(ctx, 'winTitle'), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.teal)),
              const SizedBox(height: 6),
              PlantView(stage: stage, petal: const Color(0xFFF27BA6), size: 80),
              const SizedBox(height: 6),
              Text(S.of(ctx, stage >= 3 ? 'winTree' : 'winPlant'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('+${arNum(cfg.perGame, arabic: ar)} ', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const StarIcon(size: 26),
              ]),
            ]),
          ]),
          if (mission.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.peach.withOpacity(.5), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Icon(Icons.flag_rounded, color: AppColors.coral, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(S.of(ctx, 'missionTitle'), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.coral)),
                    Text(mission, style: const TextStyle(fontSize: 17)),
                  ]),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 16),
          if (next != null)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
              onPressed: () => Navigator.pop(ctx, 'next'),
              child: Text(S.of(ctx, 'nextHadith')),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () => Navigator.pop(ctx, 'back'),
            child: Text(S.of(ctx, 'backToRiver')),
          ),
        ]),
      ),
    ),
  );
  if (!context.mounted) return;
  if (action == 'next' && next != null) {
    openHadithFlow(context, next, replace: true);
  } else {
    Navigator.of(context).pop();
  }
}

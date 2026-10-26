import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/progress_store.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/common.dart';
import '../widgets/fanoos.dart';
import 'river_screen.dart';

enum GameKind { fish, bubbles, train }

/// ألعاب "الكلمة الناقصة": صيد السمك، الفقاعات، القطار. تتبدل حسب ترتيب الحديث.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.flow});
  final FlowCtx flow;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final GameKind kind = GameKind.values[widget.flow.index % GameKind.values.length];
  late final List<String> options = [...widget.flow.hadith.game.options]..shuffle(math.Random());
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  late final AnimationController _leave = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  final Set<String> _wrong = {};
  bool _solved = false;

  Hadith get h => widget.flow.hadith;
  double get _sec => _clock.value * 60;

  @override
  void dispose() {
    _clock.dispose();
    _leave.dispose();
    super.dispose();
  }

  void _pick(String o) {
    if (_solved || _wrong.contains(o)) return;
    if (o == h.game.answer) {
      setState(() => _solved = true);
      _leave.forward();
      Future.delayed(const Duration(milliseconds: 1200), _win);
    } else {
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
    p.winGame(h, openTab: f.openTab, levelId: f.level?.id, levelHadithIds: f.tab.hasLevels ? f.levelHadithIds : null);
    showWinSheet(context, f);
  }

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final g = h.game;
    final titleKey = switch (kind) { GameKind.fish => 'gameFish', GameKind.bubbles => 'gameBubbles', GameKind.train => 'gameTrain' };
    return Scaffold(
      backgroundColor: kind == GameKind.train ? const Color(0xFFFFF6E0) : const Color(0xFFD8F1FB),
      appBar: AppBar(title: Text(S.of(context, titleKey))),
      body: !g.isValid
          ? _MemorizeMode(hadith: h, onDone: _win)
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

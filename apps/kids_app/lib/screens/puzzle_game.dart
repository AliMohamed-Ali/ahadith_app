import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:hadith_core/hadith_core.dart';

import '../l10n.dart';
import '../theme.dart';
import '../widgets/art.dart';
import '../widgets/fanoos.dart';
import 'adventure_game.dart';

/// بازل الحديث: قطع بازل عليها كلمات الحديث، الطفل يسحب كل قطعة لمكانها بالترتيب
/// ولما تكمل تظهر صورة.
class PuzzleGame extends StatefulWidget {
  const PuzzleGame({super.key, required this.game, required this.onDone});
  final GameData game;
  final VoidCallback onDone;

  /// تقسيم الجملة لقطع (من 2 لـ 6 قطع).
  static List<String> piecesOf(GameData g) {
    final words = hadithWords(g);
    final n = words.length.clamp(2, 6);
    if (words.length < 2) return [g.before, g.answer, g.after].where((w) => w.trim().isNotEmpty).toList();
    final per = words.length / n;
    return [for (var i = 0; i < n; i++) words.sublist((i * per).round(), ((i + 1) * per).round()).join(' ')];
  }

  static bool fits(GameData g) => piecesOf(g).length >= 2;

  @override
  State<PuzzleGame> createState() => _PuzzleGameState();
}

class _PuzzleGameState extends State<PuzzleGame> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final List<String> _pieces = PuzzleGame.piecesOf(widget.game);
  late final List<int> _tray = _shuffled();
  final Map<int, double> _placedAt = {};
  int? _shakeSlot, _shakePiece;
  double _shakeAt = -10, _t = 0, _wonAt = -1;
  int? _hover;
  Duration _last = Duration.zero;

  int get _n => _pieces.length;
  int get _cols => _n <= 3 ? _n : (_n == 4 ? 2 : 3);
  int get _rows => (_n / _cols).ceil();
  bool get _won => _placedAt.length == _n;
  /// أول مكان فاضي بالترتيب.
  int get _nextSlot => List.generate(_n, (i) => i).firstWhere((i) => !_placedAt.containsKey(i), orElse: () => -1);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) {
      final dt = math.min((e - _last).inMicroseconds / 1e6, .05);
      _last = e;
      setState(() => _t += dt);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  List<int> _shuffled() {
    final l = List.generate(_pieces.length, (i) => i);
    for (var tries = 0; tries < 10; tries++) {
      l.shuffle();
      if (!List.generate(l.length, (i) => l[i] == i).every((x) => x)) break;
    }
    return l;
  }

  /// مكان القطعة في اللوحة: الأولى فوق على اليمين (زي القراءة).
  (int row, int col) _cell(int i) => (i ~/ _cols, _cols - 1 - i % _cols);
  bool _exists(int r, int c) => r >= 0 && c >= 0 && c < _cols && r * _cols + (_cols - 1 - c) < _n;

  void _place(int piece) {
    setState(() {
      _placedAt[piece] = _t;
      _tray.remove(piece);
    });
    if (_won) {
      _wonAt = _t;
      Future.delayed(const Duration(milliseconds: 2400), () => mounted ? widget.onDone() : null);
    }
  }

  void _wrong({int? slot, int? piece}) {
    setState(() {
      _shakeSlot = slot;
      _shakePiece = piece;
      _shakeAt = _t;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.coral, duration: const Duration(milliseconds: 1200), content: Text(S.of(context, 'tryAgain'))));
  }

  double _shake(bool on) {
    final q = _t - _shakeAt;
    return on && q < .45 ? math.sin(q * 60) * 8 * (1 - q / .45) : 0;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final boardW = math.min(box.maxWidth - 40, 440.0);
        final w = boardW / _cols;
        final h = (w * .72).clamp(70.0, 112.0);
        final k = math.min(w, h) * .2;
        final geo = _Geo(w: w, h: h, k: k, board: Size(boardW, h * _rows));
        return Stack(children: [
          Column(children: [
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Fanoos(size: 54, mood: _won ? FanoosMood.happy : FanoosMood.talk),
              const SizedBox(width: 8),
              Flexible(child: Text(S.of(context, 'puzzleHint'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppColors.teal))),
            ]),
            const SizedBox(height: 14),
            // اللوحة
            Center(
              child: Container(
                padding: EdgeInsets.all(k + 8),
                decoration: cardBox(color: const Color(0xFFFFF8EC), shadow: const Color(0xFFE8D3B0)),
                child: SizedBox(
                  width: geo.board.width,
                  height: geo.board.height,
                  child: Stack(clipBehavior: Clip.none, children: [
                    for (var i = 0; i < _n; i++) _slot(i, geo),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 18),
            // القطع المتلخبطة
            Expanded(
              child: Center(
                child: Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 6, children: [
                  for (final i in _tray) _trayPiece(i, geo),
                ]),
              ),
            ),
          ]),
          if (_won) const Positioned(left: 0, right: 0, top: 60, child: IgnorePointer(child: Center(child: ConfettiBurst(size: 320)))),
        ]);
      });

  Widget _slot(int i, _Geo g) {
    final (r, c) = _cell(i);
    final placed = _placedAt[i];
    final pulse = !_won && i == _nextSlot ? .5 + .5 * math.sin(_t * 5) : 0.0;
    final shape = _shape(r, c);
    Widget child;
    if (placed != null) {
      final q = ((_t - placed) / .35).clamp(0.0, 1.0);
      final pop = 1 + math.sin(q * math.pi) * .12;
      // بعد الفوز الحدود بتختفي والصورة بتبان كاملة
      final outline = _won ? (1 - ((_t - _wonAt) / .8)).clamp(0.0, 1.0) : 1.0;
      child = Transform.scale(scale: pop, child: _PieceView(word: _pieces[i], row: r, col: c, shape: shape, geo: g, outline: outline, showWord: !_won || _t - _wonAt < .8));
    } else {
      child = DragTarget<int>(
        onWillAcceptWithDetails: (_) {
          setState(() => _hover = i);
          return true;
        },
        onLeave: (_) => setState(() => _hover = null),
        onAcceptWithDetails: (d) {
          _hover = null;
          d.data == i ? _place(i) : _wrong(slot: i);
        },
        builder: (context, _, __) => CustomPaint(
          size: Size(g.w + 2 * g.k, g.h + 2 * g.k),
          painter: _SlotPainter(_piecePath(shape, g), hover: _hover == i, pulse: pulse),
        ),
      );
    }
    return Positioned(
      left: c * g.w - g.k + _shake(_shakeSlot == i),
      top: r * g.h - g.k,
      width: g.w + 2 * g.k,
      height: g.h + 2 * g.k,
      child: child,
    );
  }

  Widget _trayPiece(int i, _Geo g) {
    final (r, c) = _cell(i);
    final view = _PieceView(word: _pieces[i], row: r, col: c, shape: _shape(r, c), geo: g);
    final size = Size(g.w + 2 * g.k, g.h + 2 * g.k);
    const trayScale = .82;
    return Transform.translate(
      offset: Offset(_shake(_shakePiece == i), math.sin(_t * 2 + i) * 2),
      child: Draggable<int>(
        data: i,
        dragAnchorStrategy: (d, ctx, pos) => Offset(size.width / 2, size.height / 2),
        feedback: Transform.rotate(
          angle: -.05,
          child: Container(
            decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8))]),
            child: view,
          ),
        ),
        childWhenDragging: SizedBox(width: size.width * trayScale, height: size.height * trayScale),
        // ضغطة: لو دي القطعة اللي عليها الدور تروح مكانها لوحدها
        child: GestureDetector(
          onTap: () => i == _nextSlot ? _place(i) : _wrong(piece: i),
          child: SizedBox(width: size.width * trayScale, height: size.height * trayScale, child: FittedBox(child: view)),
        ),
      ),
    );
  }

  /// شكل الحواف: 1 = بروز لبره، -1 = تجويف، 0 = حافة مستقيمة.
  _Shape _shape(int r, int c) {
    int right(int r, int c) => (r + c).isEven ? 1 : -1;
    int bottom(int r, int c) => (r + c).isEven ? -1 : 1;
    return _Shape(
      top: _exists(r - 1, c) ? -bottom(r - 1, c) : 0,
      right: _exists(r, c + 1) ? right(r, c) : 0,
      bottom: _exists(r + 1, c) ? bottom(r, c) : 0,
      left: _exists(r, c - 1) ? -right(r, c - 1) : 0,
    );
  }
}

class _Geo {
  const _Geo({required this.w, required this.h, required this.k, required this.board});
  final double w, h, k;
  final Size board;
}

class _Shape {
  const _Shape({required this.top, required this.right, required this.bottom, required this.left});
  final int top, right, bottom, left;
}

/// مسار قطعة البازل (جوه مربع فيه مسافة k من كل ناحية للبروز).
Path _piecePath(_Shape s, _Geo g) {
  final k = g.k;
  final path = Path()..moveTo(k, k);
  void edge(Offset a, Offset b, int sign) {
    if (sign == 0) {
      path.lineTo(b.dx, b.dy);
      return;
    }
    final d = b - a;
    final n = Offset(d.dy, -d.dx) / d.distance * (k * .95 * sign);
    Offset at(double u, double v) => a + d * u + n * v;
    path
      ..lineTo(at(.36, 0).dx, at(.36, 0).dy)
      ..cubicTo(at(.42, .35).dx, at(.42, .35).dy, at(.26, 1).dx, at(.26, 1).dy, at(.5, 1).dx, at(.5, 1).dy)
      ..cubicTo(at(.74, 1).dx, at(.74, 1).dy, at(.58, .35).dx, at(.58, .35).dy, at(.64, 0).dx, at(.64, 0).dy)
      ..lineTo(b.dx, b.dy);
  }

  final tl = Offset(k, k), tr = Offset(k + g.w, k), br = Offset(k + g.w, k + g.h), bl = Offset(k, k + g.h);
  edge(tl, tr, s.top);
  edge(tr, br, s.right);
  edge(br, bl, s.bottom);
  edge(bl, tl, s.left);
  return path..close();
}

class _PieceView extends StatelessWidget {
  const _PieceView({required this.word, required this.row, required this.col, required this.shape, required this.geo, this.outline = 1, this.showWord = true});
  final String word;
  final int row, col;
  final _Shape shape;
  final _Geo geo;
  final double outline;
  final bool showWord;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: geo.w + 2 * geo.k,
        height: geo.h + 2 * geo.k,
        child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _PiecePainter(_piecePath(shape, geo), Offset(col * geo.w, row * geo.h), geo, outline))),
          Positioned(
            left: geo.k + 6,
            right: geo.k + 6,
            top: geo.k,
            bottom: geo.k,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: showWord ? 1 : 0,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.92), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.ink, width: 1.5)),
                    child: Text(word, textDirection: TextDirection.rtl, style: hadithStyle(size: 20)),
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
}

class _PiecePainter extends CustomPainter {
  _PiecePainter(this.path, this.offset, this.geo, this.outline);
  final Path path;
  final Offset offset;
  final _Geo geo;
  final double outline;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipPath(path);
    // جزء القطعة من الصورة الكبيرة
    canvas.translate(geo.k - offset.dx, geo.k - offset.dy);
    _paintArt(canvas, geo.board);
    canvas.restore();
    if (outline > 0) {
      canvas.drawPath(path, Paint()
        ..color = Colors.white.withOpacity(.7 * outline)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4);
      canvas.drawPath(path, Paint()
        ..color = AppColors.ink.withOpacity(outline)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant _PiecePainter old) => old.outline != outline || old.offset != offset;
}

class _SlotPainter extends CustomPainter {
  _SlotPainter(this.path, {this.hover = false, this.pulse = 0});
  final Path path;
  final bool hover;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (pulse > 0) {
      canvas.drawPath(path, Paint()
        ..color = AppColors.gold.withOpacity(.25 + pulse * .35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + pulse * 6));
    }
    canvas.drawPath(path, Paint()..color = hover ? AppColors.mint : Colors.white.withOpacity(.75));
    final dash = Paint()
      ..color = hover ? AppColors.teal : AppColors.muted.withOpacity(.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = hover ? 3 : 2;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, d + 7), dash);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SlotPainter old) => old.hover != hover || old.pulse != pulse;
}

/// الصورة اللي بتظهر لما البازل يكمل: جامع ونخل وشمس.
void _paintArt(Canvas c, Size s) {
  final w = s.width, h = s.height;
  final rect = Offset.zero & s;
  c.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7FC8F8), Color(0xFFFFE3B0)]).createShader(rect));
  c.drawCircle(Offset(w * .82, h * .2), h * .2, Paint()..color = AppColors.gold.withOpacity(.3));
  c.drawCircle(Offset(w * .82, h * .2), h * .12, Paint()..color = AppColors.gold);
  final cloud = Paint()..color = Colors.white.withOpacity(.9);
  for (final (x, y) in [(.15, .14), (.5, .1)]) {
    final r = h * .06;
    c.drawCircle(Offset(w * x, h * y), r, cloud);
    c.drawCircle(Offset(w * x + r, h * y - r * .5), r * 1.2, cloud);
    c.drawCircle(Offset(w * x + r * 2.1, h * y), r, cloud);
  }
  // تلال
  final hills = Path()..moveTo(0, h);
  for (var x = 0.0; x <= w + 6; x += 6) {
    hills.lineTo(x, h * .72 - math.sin(x / w * math.pi * 2.2) * h * .06);
  }
  hills
    ..lineTo(w, h)
    ..close();
  c.drawPath(hills, Paint()..color = const Color(0xFF8FD16A));
  c.drawRect(Rect.fromLTWH(0, h * .86, w, h * .14), Paint()..color = const Color(0xFF6FB552));

  // الجامع
  final mx = w * .5, base = h * .86;
  final bw = math.min(w * .42, h * .9);
  final wall = Paint()..color = const Color(0xFFFFF6E6);
  final trim = Paint()..color = AppColors.teal;
  c.drawRect(Rect.fromLTRB(mx - bw / 2, base - h * .28, mx + bw / 2, base), wall);
  c.drawCircle(Offset(mx, base - h * .28), bw * .26, trim);
  c.drawRect(Rect.fromLTRB(mx - bw * .27, base - h * .28, mx + bw * .27, base - h * .26), wall);
  c.drawLine(Offset(mx, base - h * .28 - bw * .26), Offset(mx, base - h * .28 - bw * .26 - h * .06), Paint()
    ..color = AppColors.gold
    ..strokeWidth = 2);
  // الباب
  c.drawRRect(RRect.fromRectAndCorners(Rect.fromLTRB(mx - bw * .09, base - h * .16, mx + bw * .09, base), topLeft: Radius.circular(bw * .09), topRight: Radius.circular(bw * .09)), trim);
  // المئذنة
  for (final side in [-1.0, 1.0]) {
    final x = mx + side * (bw / 2 + bw * .08);
    c.drawRect(Rect.fromLTRB(x - bw * .05, base - h * .5, x + bw * .05, base), wall);
    c.drawRect(Rect.fromLTRB(x - bw * .07, base - h * .4, x + bw * .07, base - h * .37), trim);
    c.drawCircle(Offset(x, base - h * .5), bw * .05, trim);
  }
  final outline = Paint()
    ..color = const Color(0xFFD7C3A3)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  c.drawRect(Rect.fromLTRB(mx - bw / 2, base - h * .28, mx + bw / 2, base), outline);

  // نخل
  for (final x in [w * .1, w * .9]) {
    final top = Offset(x + 6, base - h * .42);
    c.drawPath(Path()..moveTo(x, base)..quadraticBezierTo(x - 6, base - h * .2, top.dx, top.dy), Paint()
      ..color = const Color(0xFF8A5A2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round);
    final leaf = Paint()
      ..color = const Color(0xFF3E9B4F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + (i - 2) * .7;
      final end = top + Offset(math.cos(a) * h * .16, math.sin(a) * h * .16 + h * .1);
      c.drawPath(Path()..moveTo(top.dx, top.dy)..quadraticBezierTo(top.dx + math.cos(a) * h * .12, top.dy + math.sin(a) * h * .12 - 6, end.dx, end.dy), leaf);
    }
  }
  // ورد
  for (var i = 0; i < 9; i++) {
    c.drawCircle(Offset(w * (.05 + i * .11), base + h * .06 + (i % 2) * h * .03), 3.5, Paint()..color = i.isEven ? const Color(0xFFF27BA6) : AppColors.gold);
  }
}

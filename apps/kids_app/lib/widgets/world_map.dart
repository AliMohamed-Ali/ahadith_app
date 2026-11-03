import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../services/sounds.dart';
import '../state/progress_store.dart';
import 'common.dart';
import 'fanoos.dart';

/// نوع المَعلم على الجزيرة.
enum Landmark { house, mountains, castle, oasis, tent }

class WorldPlace {
  const WorldPlace({required this.kind, required this.title, required this.onOpen, this.color = AppColors.teal});
  final Landmark kind;
  final String title;
  final VoidCallback onOpen;
  final Color color;

  /// المَعلم المناسب لكل نوع تبويب.
  static Landmark forTab(AppTab t) {
    if (t.isQa) return Landmark.tent;
    if (t.isAges) return Landmark.castle;
    if (t.usesLevels) return Landmark.mountains;
    return Landmark.oasis;
  }
}

/// الرئيسية كخريطة عالم: جزيرة في بحر، كل قسم مَعلم عليها، وفانوس بيمشي للمكان اللي الطفل يختاره ويكلّمه.
class WorldMap extends StatefulWidget {
  const WorldMap({super.key, required this.places});
  final List<WorldPlace> places;
  @override
  State<WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<WorldMap> with TickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  late final AnimationController _walk = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
  int _at = 0, _from = 0, _to = 0;

  /// أماكن المعالم على الجزيرة (نسبة من العرض والارتفاع).
  static const _slots = [Offset(.27, .24), Offset(.74, .27), Offset(.3, .52), Offset(.75, .57), Offset(.27, .82), Offset(.72, .85)];
  static const _height = 520.0;

  double get _t => _clock.value * 60;

  @override
  void dispose() {
    _clock.dispose();
    _walk.dispose();
    super.dispose();
  }

  Offset _slot(int i, double w) => Offset(_slots[i % _slots.length].dx * w, _slots[i % _slots.length].dy * _height);

  Future<void> _go(int i) async {
    if (_walk.isAnimating) return;
    if (i != _at) {
      setState(() {
        _from = _at;
        _to = i;
      });
      Sounds.play(Sfx.jump);
      await _walk.forward(from: 0);
      Sounds.play(Sfx.land);
      if (!mounted) return;
      setState(() => _at = i);
    }
    widget.places[i].onOpen();
  }

  @override
  Widget build(BuildContext context) {
    final places = widget.places.take(_slots.length).toList();
    final name = context.select<ProgressStore, String>((p) => p.profile?.name.trim() ?? '');
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return SizedBox(
        height: _height,
        child: AnimatedBuilder(
          animation: Listenable.merge([_clock, _walk]),
          builder: (context, _) {
            // فانوس واقف تحت المَعلم اللي اختاره، وبيمشي في قوس للمَعلم الجديد
            // فانوس واقف جنب المَعلم (ناحية نص الجزيرة) عشان ما يغطيش على اللي تحته
            Offset beside(int i) {
              final s = _slot(i, w);
              return s + Offset(s.dx < w / 2 ? 78 : -78, -6);
            }

            final a = beside(_walk.isAnimating ? _from : _at);
            final b = beside(_to);
            final q = _walk.isAnimating ? Curves.easeInOut.transform(_walk.value) : 0.0;
            final fan = _walk.isAnimating ? Offset.lerp(a, b, q)! - Offset(0, math.sin(q * math.pi) * 60) : a;
            // كل 14 ثانية فانوس بيقول جملة
            final talkPhase = _t % 14;
            final talking = !_walk.isAnimating && talkPhase < 5;
            final tip = S.of(context, 'worldTip${(_t ~/ 14) % 4 + 1}', {'name': name.isEmpty ? S.of(context, 'champ') : name});
            return Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: CustomPaint(painter: _IslandPainter(t: _t, spots: [for (var i = 0; i < places.length; i++) _slot(i, w)]))),
              for (var i = 0; i < places.length; i++) _landmark(i, places[i], _slot(i, w)),
              Positioned(left: fan.dx - 24, top: fan.dy - 40, child: IgnorePointer(child: Fanoos(size: 46, mood: talking ? FanoosMood.talk : FanoosMood.smile))),
              if (talking)
                Positioned(
                  left: (fan.dx - 110).clamp(8.0, w - 228),
                  top: fan.dy - 100,
                  width: 220,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: talkPhase < .3 ? talkPhase / .3 : (talkPhase > 4.6 ? (5 - talkPhase) / .4 : 1),
                      child: SpeechBubble(text: tip),
                    ),
                  ),
                ),
            ]);
          },
        ),
      );
    });
  }

  Widget _landmark(int i, WorldPlace p, Offset at) {
    final bob = math.sin(_t * 2 + i) * 3;
    return Positioned(
      left: at.dx - 75,
      top: at.dy - 92 + bob,
      width: 150,
      child: Bouncy(
        sound: true,
        onTap: () => _go(i),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CustomPaint(size: const Size(130, 92), painter: _LandmarkPainter(p.kind, p.color, _t)),
          // اليافطة الخشب باسم القسم
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFB9783F),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF7A4A22), width: 2.5),
              boxShadow: const [BoxShadow(color: Colors.black26, offset: Offset(0, 3))],
            ),
            child: Text(p.title, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, height: 1.25)),
          ),
        ]),
      ),
    );
  }
}

/// فقاعة كلام (فانوس بيكلّم الطفل).
class SpeechBubble extends StatelessWidget {
  const SpeechBubble({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gold, width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3))],
        ),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.navy, height: 1.35)),
      );
}

/// البحر والجزيرة والطريق والسحاب والطيور.
class _IslandPainter extends CustomPainter {
  _IslandPainter({required this.t, required this.spots});
  final double t;
  final List<Offset> spots;

  static double _hash(int k) => (math.sin(k * 127.1) * 43758.5453).remainder(1).abs();

  @override
  void paint(Canvas c, Size s) {
    final r = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(32));
    c.save();
    c.clipRRect(r);
    // البحر
    c.drawRect(Offset.zero & s, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF7FD3F7), Color(0xFF3BA7D9)]).createShader(Offset.zero & s));
    final wave = Paint()
      ..color = Colors.white.withOpacity(.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 14; i++) {
      final x = (_hash(i) * s.width + t * 8) % (s.width + 40) - 20;
      final y = _hash(i + 30) * s.height;
      c.drawArc(Rect.fromCenter(center: Offset(x, y + math.sin(t * 2 + i) * 2), width: 26, height: 10), math.pi, math.pi, false, wave);
    }
    // الجزيرة: رملة وبعدين عشب
    final island = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(14, 28, s.width - 14, s.height - 16), const Radius.circular(90)));
    c.drawPath(island.shift(const Offset(0, 6)), Paint()..color = const Color(0xFF2E8BB8).withOpacity(.5));
    c.drawPath(island, Paint()..color = const Color(0xFFF4DCA0));
    final grass = Path()..addRRect(RRect.fromRectAndRadius(Rect.fromLTRB(30, 42, s.width - 30, s.height - 32), const Radius.circular(80)));
    c.drawPath(grass, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9BDB7A), Color(0xFF6FBE55)]).createShader(Offset.zero & s));
    // بقع عشب وورد
    for (var i = 0; i < 26; i++) {
      final p = Offset(40 + _hash(i + 50) * (s.width - 80), 60 + _hash(i + 80) * (s.height - 110));
      if (i.isEven) {
        c.drawCircle(p, 3.5, Paint()..color = [const Color(0xFFF27BA6), AppColors.gold, Colors.white][i % 3]);
      } else {
        c.drawOval(Rect.fromCenter(center: p, width: 18, height: 7), Paint()..color = const Color(0xFF5AA845).withOpacity(.6));
      }
    }
    // الطريق بين المعالم
    final road = Paint()
      ..color = const Color(0xFFF7E3B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final dots = Paint()
      ..color = const Color(0xFFD9B979)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < spots.length - 1; i++) {
      final a = spots[i] + const Offset(0, 62), b = spots[i + 1] + const Offset(0, 62);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 + 30, b.dx, b.dy);
      c.drawPath(path, road);
      for (final m in path.computeMetrics()) {
        for (var d = 0.0; d < m.length; d += 18) {
          c.drawPath(m.extractPath(d, d + 6), dots);
        }
      }
    }
    // سحاب وطيور
    final cloud = Paint()..color = Colors.white.withOpacity(.9);
    for (var i = 0; i < 3; i++) {
      final x = (_hash(i + 7) * s.width + t * (7 + i * 3)) % (s.width + 140) - 70;
      final y = 18.0 + i * 160 + _hash(i) * 40;
      final rr = 16 + i * 3.0;
      c.drawCircle(Offset(x, y), rr, cloud);
      c.drawCircle(Offset(x + rr, y - rr * .5), rr * 1.2, cloud);
      c.drawCircle(Offset(x + rr * 2.1, y), rr, cloud);
    }
    final bird = Paint()
      ..color = AppColors.navy
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final x = (t * (26 + i * 6) + i * 150) % (s.width + 80) - 40;
      final y = 40.0 + i * 36 + math.sin(t * 2 + i) * 6;
      final flap = math.sin(t * 9 + i) * 4;
      c.drawPath(Path()..moveTo(x - 7, y - flap)..quadraticBezierTo(x - 3, y - 3, x, y)..quadraticBezierTo(x + 3, y - 3, x + 7, y - flap), bird);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _IslandPainter old) => true;
}

/// رسمة كل مَعلم (130×92، الأرضية تحت في النص).
class _LandmarkPainter extends CustomPainter {
  _LandmarkPainter(this.kind, this.color, this.t);
  final Landmark kind;
  final Color color;
  final double t;

  static const _ink = Color(0xFF3A2A4A);

  Paint get _line => Paint()
    ..color = _ink
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.5
    ..strokeJoin = StrokeJoin.round;

  void _fill(Canvas c, Path p, Color col) {
    c.drawPath(p, Paint()..color = col);
    c.drawPath(p, _line);
  }

  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2, base = s.height - 4;
    // ضل تحت المَعلم
    c.drawOval(Rect.fromCenter(center: Offset(cx, base), width: 110, height: 14), Paint()..color = Colors.black.withOpacity(.12));
    switch (kind) {
      case Landmark.mountains:
        _fill(c, Path()..moveTo(cx - 60, base)..lineTo(cx - 22, base - 70)..lineTo(cx + 12, base)..close(), const Color(0xFF7FA6C9));
        _fill(c, Path()..moveTo(cx - 20, base)..lineTo(cx + 22, base - 84)..lineTo(cx + 62, base)..close(), const Color(0xFF6C8FB8));
        _fill(c, Path()..moveTo(cx + 22, base - 84)..lineTo(cx + 9, base - 58)..lineTo(cx + 18, base - 62)..lineTo(cx + 26, base - 54)..lineTo(cx + 34, base - 60)..close(), Colors.white);
        _flag(c, Offset(cx + 22, base - 84), color);
      case Landmark.castle:
        // سور بشُرفات ومئذنة بقبة وهلال
        final wall = Path()..addRect(Rect.fromLTRB(cx - 52, base - 44, cx + 30, base));
        _fill(c, wall, const Color(0xFFF2E3C6));
        for (var k = 0; k < 5; k++) {
          _fill(c, Path()..addRect(Rect.fromLTWH(cx - 52 + k * 17, base - 52, 10, 9)), const Color(0xFFF2E3C6));
        }
        _fill(c, Path()..addRRect(RRect.fromRectAndCorners(Rect.fromLTRB(cx - 24, base - 26, cx - 4, base), topLeft: const Radius.circular(10), topRight: const Radius.circular(10))), const Color(0xFF7558D6));
        _fill(c, Path()..addRect(Rect.fromLTRB(cx + 30, base - 78, cx + 48, base)), const Color(0xFFF2E3C6));
        _fill(c, Path()..addArc(Rect.fromCircle(center: Offset(cx + 39, base - 78), radius: 12), math.pi, math.pi)..close(), color);
        _crescent(c, Offset(cx + 39, base - 96));
      case Landmark.oasis:
        _fill(c, Path()..addOval(Rect.fromCenter(center: Offset(cx, base - 8), width: 70, height: 18)), const Color(0xFF4FB3E8));
        _palm(c, Offset(cx - 34, base - 6), 66);
        _palm(c, Offset(cx + 32, base - 4), 56);
      case Landmark.tent:
        final tent = Path()..moveTo(cx - 52, base)..lineTo(cx, base - 70)..lineTo(cx + 52, base)..close();
        c.save();
        c.clipPath(tent);
        c.drawRect(Rect.fromLTRB(cx - 60, base - 80, cx + 60, base), Paint()..color = color);
        for (var k = -3; k <= 3; k++) {
          c.drawRect(Rect.fromLTWH(cx + k * 16 - 4, base - 80, 8, 80), Paint()..color = Colors.white.withOpacity(.35));
        }
        c.restore();
        c.drawPath(tent, _line);
        _fill(c, Path()..moveTo(cx - 12, base)..lineTo(cx, base - 30)..lineTo(cx + 12, base)..close(), const Color(0xFF3A2A4A));
        _flag(c, Offset(cx, base - 70), AppColors.gold);
      case Landmark.house:
        _fill(c, Path()..addRect(Rect.fromLTRB(cx - 40, base - 46, cx + 40, base)), const Color(0xFFFFF3D6));
        _fill(c, Path()..moveTo(cx - 50, base - 44)..lineTo(cx, base - 80)..lineTo(cx + 50, base - 44)..close(), AppColors.coral);
        _fill(c, Path()..addRRect(RRect.fromRectAndCorners(Rect.fromLTRB(cx - 10, base - 28, cx + 10, base), topLeft: const Radius.circular(10), topRight: const Radius.circular(10))), const Color(0xFF8A5A2B));
        // فانوس صغير منوّر جنب الباب
        final glow = .5 + .5 * math.sin(t * 4);
        c.drawCircle(Offset(cx + 26, base - 22), 12, Paint()..color = AppColors.gold.withOpacity(.25 + glow * .25));
        _fill(c, Path()..addRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + 26, base - 22), width: 10, height: 14), const Radius.circular(3))), AppColors.gold);
    }
  }

  void _flag(Canvas c, Offset top, Color col) {
    c.drawLine(top, top - const Offset(0, 22), Paint()
      ..color = _ink
      ..strokeWidth = 2.5);
    final w = math.sin(t * 5) * 3;
    _fill(c, Path()..moveTo(top.dx, top.dy - 22)..quadraticBezierTo(top.dx + 10, top.dy - 22 + w, top.dx + 20, top.dy - 17)..lineTo(top.dx, top.dy - 12)..close(), col);
  }

  void _crescent(Canvas c, Offset at) {
    final p = Path.combine(PathOperation.difference, Path()..addOval(Rect.fromCircle(center: at, radius: 7)), Path()..addOval(Rect.fromCircle(center: at + const Offset(3, -2), radius: 6)));
    c.drawPath(p, Paint()..color = AppColors.gold);
  }

  void _palm(Canvas c, Offset base, double h) {
    final top = base + Offset(6, -h);
    c.drawPath(Path()..moveTo(base.dx, base.dy)..quadraticBezierTo(base.dx - 6, base.dy - h * .5, top.dx, top.dy), Paint()
      ..color = const Color(0xFF8A5A2B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round);
    final sway = math.sin(t * 1.5 + base.dx) * .08;
    for (var k = 0; k < 5; k++) {
      final a = -math.pi / 2 + (k - 2) * .7 + sway;
      final end = top + Offset(math.cos(a) * 28, math.sin(a) * 28 + 16);
      c.drawPath(Path()..moveTo(top.dx, top.dy)..quadraticBezierTo(top.dx + math.cos(a) * 20, top.dy + math.sin(a) * 20 - 6, end.dx, end.dy), Paint()
        ..color = const Color(0xFF3E9B4F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round);
    }
    c.drawCircle(top + const Offset(-3, 4), 4, Paint()..color = const Color(0xFF8A4B1F));
    c.drawCircle(top + const Offset(4, 5), 4, Paint()..color = const Color(0xFF8A4B1F));
  }

  @override
  bool shouldRepaint(covariant _LandmarkPainter old) => true;
}

/// فقاعة كلام بتظهر لوحدها كل شوية بجملة مختلفة (الشخصية بتكلّم الطفل).
class TalkBubble extends StatefulWidget {
  const TalkBubble({super.key, required this.lines, this.every = 12, this.showFor = 4.5});
  final List<String> lines;
  final double every, showFor;
  @override
  State<TalkBubble> createState() => _TalkBubbleState();
}

class _TalkBubbleState extends State<TalkBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  final _start = DateTime.now();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (widget.lines.isEmpty) return const SizedBox.shrink();
          final secs = DateTime.now().difference(_start).inMilliseconds / 1000;
          final phase = secs % widget.every;
          if (phase > widget.showFor) return const SizedBox.shrink();
          final pop = Curves.easeOutBack.transform((phase / .35).clamp(0.0, 1.0));
          final fade = phase > widget.showFor - .4 ? (widget.showFor - phase) / .4 : 1.0;
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.scale(scale: .6 + .4 * pop, alignment: Alignment.bottomCenter, child: SpeechBubble(text: widget.lines[(secs ~/ widget.every) % widget.lines.length])),
          );
        },
      );
}

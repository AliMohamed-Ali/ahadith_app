import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../widgets/world_map.dart';
import '../widgets/common.dart';
import '../l10n.dart';
import '../services/sounds.dart';
import '../state/progress_store.dart';
import '../theme.dart';
import '../widgets/kid.dart';
import 'river_screen.dart';

/// خريطة جبال لمستوى فيه أقسام (زي الآداب): الطفل بيمشي على الطريق من جبل لجبل،
/// وكل جبل بيفتح نهر أحاديث القسم ده.
class MountainMapScreen extends StatefulWidget {
  const MountainMapScreen({super.key, required this.tab, required this.level});
  final AppTab tab;
  final Level level;
  @override
  State<MountainMapScreen> createState() => _MountainMapScreenState();
}

class _MountainMapScreenState extends State<MountainMapScreen> with TickerProviderStateMixin {
  late final repo = context.read<ContentRepository>();
  late final Stream<List<Level>> _cats = repo.childLevels(widget.level.id);
  late final Stream<List<Hadith>> _hadiths = repo.hadiths(widget.tab.id);
  // وقت مستمر للسحاب ولحركة الطفل وهو واقف
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  late final AnimationController _walk = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  int? _kidAt;
  int _from = 0, _to = 0;

  static const _gap = 200.0, _bottom = 230.0, _top = 200.0;

  @override
  void dispose() {
    _clock.dispose();
    _walk.dispose();
    super.dispose();
  }

  double get _t => _clock.value * 60;

  Offset _peak(int i, int n, double w, double h) => Offset(w * (i.isEven ? .3 : .7) + math.sin(i * 1.7) * w * .05, h - _bottom - i * _gap);

  /// مكان رجلين الطفل جنب الجبل (على الطريق).
  Offset _stand(int i, int n, double w, double h) => _peak(i, n, w, h) + Offset(i.isEven ? 70 : -70, 62);

  Future<void> _go(int i, List<Level> cats) async {
    if (_walk.isAnimating) return;
    Sounds.play(Sfx.tap);
    final at = _kidAt ?? i;
    if (at != i) {
      setState(() {
        _from = at;
        _to = i;
      });
      Sounds.play(Sfx.jump);
      await _walk.forward(from: 0);
      Sounds.play(Sfx.land);
      if (!mounted) return;
      setState(() => _kidAt = i);
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RiverScreen(tab: widget.tab, level: cats[i])));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final p = context.watch<ProgressStore>();
    final color = hexColor(widget.level.color, const Color(0xFF7558D6));
    return Scaffold(
      appBar: AppBar(title: Text(widget.level.name(ar)), backgroundColor: color, foregroundColor: onColor(color)),
      body: StreamBuilder<List<Level>>(
        stream: _cats,
        builder: (context, cs) => StreamBuilder<List<Hadith>>(
          stream: _hadiths,
          builder: (context, hs) {
            if (!cs.hasData || !hs.hasData) return const Center(child: CircularProgressIndicator());
            final cats = cs.data!;
            if (cats.isEmpty) return Center(child: Text(S.of(context, 'emptyContent')));
            final byCat = <String, List<Hadith>>{};
            for (final h in hs.data!) {
              if (h.levelId != null) byCat.putIfAbsent(h.levelId!, () => []).add(h);
            }
            final done = [for (final c in cats) (byCat[c.id] ?? const []).isNotEmpty && byCat[c.id]!.every((h) => p.isDone(h.id))];
            final current = done.indexWhere((d) => !d);
            _kidAt ??= current == -1 ? cats.length - 1 : current;
            // لما الطفل يخلّص كل الأقسام المستوى نفسه بيكمل
            if (current == -1 && !p.completedLevels.contains(widget.level.id)) {
              WidgetsBinding.instance.addPostFrameCallback((_) => p.completeLevel(widget.level.id));
            }
            return LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              final h = math.max(box.maxHeight, _top + _bottom + (cats.length - 1) * _gap + 60);
              final n = cats.length;
              final peaks = [for (var i = 0; i < n; i++) _peak(i, n, w, h)];
              return SingleChildScrollView(
                // بيبدأ من تحت (أول جبل) والطفل بيطلع لفوق
                reverse: true,
                child: SizedBox(
                  width: w,
                  height: h,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_clock, _walk]),
                    builder: (context, _) => Stack(clipBehavior: Clip.none, children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _MapPainter(
                            peaks: peaks,
                            colors: [for (final c in cats) hexColor(c.color, color)],
                            done: done,
                            t: _t,
                          ),
                        ),
                      ),
                      // البداية والطريقة المقترحة
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: cardBox(color: Colors.white.withOpacity(.94)),
                          child: Row(children: [
                            const Text('🚩', style: TextStyle(fontSize: 28)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.level.descAr.isNotEmpty ? widget.level.descAr : S.of(context, 'mapHint'),
                                style: const TextStyle(fontSize: 14, height: 1.5),
                              ),
                            ),
                          ]),
                        ),
                      ),
                      for (var i = 0; i < n; i++) ..._peakViews(i, cats[i], peaks[i], byCat[cats[i].id] ?? const [], done[i], i == current, p, ar, cats),
                      _kidView(w, h, n),
                      _eagleView(w, h, n),
                      // الطفل بيكلّم صاحبه الصغير
                      if (!_walk.isAnimating)
                        Positioned(
                          left: (_stand(_kidAt ?? 0, n, w, h).dx - 95).clamp(8.0, w - 198),
                          top: _stand(_kidAt ?? 0, n, w, h).dy - 150,
                          width: 190,
                          child: IgnorePointer(child: TalkBubble(lines: [for (final k in ['mapTalk1', 'mapTalk2', 'mapTalk3']) S.of(context, k)])),
                        ),
                    ]),
                  ),
                ),
              );
            });
          },
        ),
      ),
    );
  }

  /// ارتفاع كارت اسم الآداب اللي فوق قمة الجبل.
  static const _cardH = 92.0;

  /// أعلى نقطة في كارت الجبل (النسر بيقف عليها).
  double _cardTop(Offset at) => at.dy - 50 - _cardH + 14;

  List<Widget> _peakViews(int i, Level c, Offset at, List<Hadith> hs, bool done, bool isCurrent, ProgressStore p, bool ar, List<Level> cats) {
    final col = hexColor(c.color, AppColors.teal);
    final got = hs.where((h) => p.isDone(h.id)).length;
    final bounce = isCurrent ? math.sin(_t * 4).abs() * 5 : 0.0;
    return [
      // الجبل نفسه بيندس كمان
      Positioned(
        left: at.dx - 95,
        top: at.dy - 50,
        width: 190,
        height: 110,
        child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => _go(i, cats)),
      ),
      // اسم الآداب فوق قمة الجبل
      Positioned(
        left: at.dx - 90,
        top: _cardTop(at) - bounce,
        width: 180,
        height: _cardH,
        child: Bouncy(
          sound: false,
          onTap: () => _go(i, cats),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: done ? AppColors.gold : col, width: 3),
              boxShadow: [BoxShadow(color: (isCurrent ? col : Colors.black).withOpacity(isCurrent ? .5 : .15), blurRadius: isCurrent ? 14 : 6, offset: const Offset(0, 4))],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: [
                Text(c.icon.isEmpty ? '⛰️' : c.icon, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 6),
                Expanded(child: Text(c.name(ar), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.25))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(value: hs.isEmpty ? 0 : got / hs.length, minHeight: 7, backgroundColor: col.withOpacity(.15), color: done ? AppColors.gold : col),
                  ),
                ),
                const SizedBox(width: 6),
                Text('${arNum(got, arabic: ar)}/${arNum(hs.length, arabic: ar)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
        ),
      ),
    ];
  }

  /// النسر واقف فوق كارت الجبل اللي الطفل عنده، وكل كام ثانية بيلف حوالين القمة.
  /// لما الطفل يمشي لجبل تاني النسر بيطير قدّامه ويقف على الجبل الجديد.
  Widget _eagleView(double w, double h, int n) {
    const ew = 64.0, eh = 51.0;
    // النسر واقف فوق كارت اسم الآداب
    Offset perch(int i) {
      final at = _peak(i, n, w, h);
      return Offset(at.dx + 40, _cardTop(at) - eh + 8);
    }
    Offset pos;
    double flap = 0;
    var perched = true, faceLeft = false;
    if (_walk.isAnimating) {
      final a = perch(_from), b = perch(_to);
      // بيسبق الطفل شوية
      final q = Curves.easeInOut.transform((_walk.value * 1.25).clamp(0.0, 1.0));
      pos = Offset.lerp(a, b, q)! - Offset(0, math.sin(q * math.pi) * 110);
      perched = q >= 1;
      flap = math.sin(_walk.value * 40);
      faceLeft = b.dx < a.dx;
    } else {
      final home = perch(_kidAt ?? 0);
      // كل 9 ثواني لفّة طيران 3 ثواني حوالين القمة
      final cycle = _t % 9;
      if (cycle > 6) {
        final a = (cycle - 6) / 3 * math.pi * 2;
        pos = home + Offset(math.sin(a) * 80, -math.sin(a / 2) * 70 - (1 - math.cos(a)) * 10);
        perched = false;
        flap = math.sin(_t * 14);
        faceLeft = math.cos(a) < 0;
      } else {
        pos = home + Offset(0, -math.sin(_t * 3).abs() * 2);
      }
    }
    return Positioned(
      left: pos.dx - ew / 2,
      top: pos.dy,
      child: IgnorePointer(
        child: Transform.flip(flipX: faceLeft, child: CustomPaint(size: const Size(ew, eh), painter: _EaglePainter(flap: flap, perched: perched))),
      ),
    );
  }

  Widget _kidView(double w, double h, int n) {
    const kh = 86.0;
    Offset pos;
    KidPose pose;
    var faceLeft = false;
    if (_walk.isAnimating) {
      final a = _stand(_from, n, w, h), b = _stand(_to, n, w, h);
      final q = Curves.easeInOut.transform(_walk.value);
      // بيمشي على قوس صغير عشان يبان إنه طالع الجبل
      pos = Offset.lerp(a, b, q)! - Offset(0, math.sin(q * math.pi) * 40);
      pose = KidPose.run(_walk.value * 30);
      faceLeft = b.dx < a.dx;
    } else {
      pos = _stand(_kidAt ?? 0, n, w, h);
      pose = KidPose.idle(_t, blink: kidBlink(_t));
      faceLeft = (_kidAt ?? 0).isOdd;
    }
    return Positioned(
      left: pos.dx - kh * 100 / 140 / 2,
      top: pos.dy - kh * 131 / 140,
      child: IgnorePointer(child: Kid(pose: pose, facingLeft: faceLeft, height: kh)),
    );
  }
}

/// نسر كرتون: جناحاته بتترفرف وهو طاير، ومضمومة وهو واقف.
class _EaglePainter extends CustomPainter {
  _EaglePainter({required this.flap, required this.perched});
  /// من -1 (الجناح تحت) لـ 1 (فوق).
  final double flap;
  final bool perched;

  static const _ink = Color(0xFF2B2140);
  static const _brown = Color(0xFF7A4A2A);
  static const _dark = Color(0xFF5C3519);
  static const _beak = Color(0xFFF5B82E);

  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 70, s.height / 56);
    final ink = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round;
    void fill(Path p, Color col) {
      c.drawPath(p, Paint()..color = col);
      c.drawPath(p, ink);
    }

    Path wing(double len, double up) => Path()
      ..moveTo(30, 28)
      ..quadraticBezierTo(26 - len * .3, 26 - up * .6, 30 - len, 28 - up)
      ..lineTo(30 - len + 6, 28 - up * .55 + 4)
      ..lineTo(30 - len + 4, 28 - up * .3 + 6)
      ..quadraticBezierTo(30 - len * .4, 36, 38, 32)
      ..close();

    if (!perched) fill(wing(20, 24 * flap), _dark);
    // الديل
    fill(Path()..moveTo(18, 30)..lineTo(4, 26)..lineTo(6, 34)..lineTo(4, 40)..lineTo(20, 36)..close(), _dark);
    // الجسم
    fill(Path()..addOval(Rect.fromCenter(center: const Offset(32, 33), width: 34, height: 22)), _brown);
    if (perched) {
      fill(Path()..addOval(Rect.fromCenter(center: const Offset(28, 32), width: 24, height: 13)), _dark);
      final leg = Paint()
        ..color = _beak
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      c.drawLine(const Offset(29, 42), const Offset(28, 52), leg);
      c.drawLine(const Offset(36, 42), const Offset(37, 52), leg);
    } else {
      fill(wing(24, 30 * flap), _brown);
    }
    // الراس الأبيض والمنقار
    fill(Path()..addOval(Rect.fromCircle(center: const Offset(50, 21), radius: 10)), Colors.white);
    fill(Path()..moveTo(58, 18)..quadraticBezierTo(68, 18, 66, 26)..lineTo(58, 25)..close(), _beak);
    c.drawCircle(const Offset(52, 19), 2, Paint()..color = _ink);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _EaglePainter old) => true;
}

/// السما والجبال والطريق.
class _MapPainter extends CustomPainter {
  _MapPainter({required this.peaks, required this.colors, required this.done, required this.t});
  final List<Offset> peaks;
  final List<Color> colors;
  final List<bool> done;
  final double t;

  static double _hash(int k) => (math.sin(k * 127.1) * 43758.5453).remainder(1).abs();

  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    // كل ما نطلع السما بتغمق والتلج بيكتر
    c.drawRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF6FB6F2), Color(0xFFBFE4FB), Color(0xFFE6F7D9)], stops: [0, .6, 1]).createShader(r));

    // سحاب
    final cloud = Paint()..color = Colors.white.withOpacity(.85);
    for (var i = 0; i < (s.height / 160).ceil(); i++) {
      final y = 60.0 + i * 160 + _hash(i) * 60;
      final x = (_hash(i + 9) * s.width + t * (6 + _hash(i + 3) * 8)) % (s.width + 160) - 80;
      final rr = 14 + _hash(i + 5) * 10;
      c.drawCircle(Offset(x, y), rr, cloud);
      c.drawCircle(Offset(x + rr, y - rr * .5), rr * 1.2, cloud);
      c.drawCircle(Offset(x + rr * 2.1, y), rr, cloud);
    }

    // جبال بعيدة على الجناب
    final far = Paint()..color = const Color(0xFFA9C2E6).withOpacity(.7);
    for (var i = 0; i < (s.height / 220).ceil() + 1; i++) {
      final y = s.height - i * 220.0;
      final left = i.isEven;
      final x = left ? -40.0 : s.width + 40;
      c.drawPath(Path()..moveTo(x - 110, y)..lineTo(x, y - 180 - _hash(i) * 60)..lineTo(x + 110, y)..close(), far);
    }

    // الأرض تحت
    c.drawPath(
      Path()
        ..moveTo(0, s.height - 120)
        ..quadraticBezierTo(s.width / 2, s.height - 170, s.width, s.height - 120)
        ..lineTo(s.width, s.height)
        ..lineTo(0, s.height)
        ..close(),
      Paint()..color = const Color(0xFF8FD16A),
    );

    // الطريق: دهبي في اللي خلص، متقطع في الباقي
    for (var i = 0; i < peaks.length - 1; i++) {
      final a = peaks[i] + Offset(i.isEven ? 70 : -70, 62), b = peaks[i + 1] + Offset((i + 1).isEven ? 70 : -70, 62);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo((a.dx + b.dx) / 2 + (i.isEven ? 40 : -40), (a.dy + b.dy) / 2, b.dx, b.dy);
      final finished = done[i];
      final paint = Paint()
        ..color = finished ? AppColors.gold : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = finished ? 9 : 7
        ..strokeCap = StrokeCap.round;
      if (finished) {
        c.drawPath(path, paint);
      } else {
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 22) {
            c.drawPath(m.extractPath(d, d + 12), paint);
          }
        }
      }
    }

    // الجبال نفسها
    for (var i = 0; i < peaks.length; i++) {
      final p = peaks[i];
      final base = p.dy + 60, top = p.dy - 50;
      final col = Color.lerp(colors[i], const Color(0xFF8A7767), .45)!;
      final hill = Path()..moveTo(p.dx - 95, base)..quadraticBezierTo(p.dx - 40, top + 30, p.dx, top)..quadraticBezierTo(p.dx + 40, top + 30, p.dx + 95, base)..close();
      c.drawPath(hill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(col, Colors.white, .15)!, col]).createShader(Rect.fromLTRB(p.dx - 95, top, p.dx + 95, base)));
      // ضل على النص اليمين
      c.drawPath(Path()..moveTo(p.dx, top)..quadraticBezierTo(p.dx + 40, top + 30, p.dx + 95, base)..lineTo(p.dx + 20, base)..close(), Paint()..color = Colors.black.withOpacity(.08));
      // تلج القمة
      c.drawPath(
        Path()
          ..moveTo(p.dx - 26, top + 26)
          ..quadraticBezierTo(p.dx - 12, top + 4, p.dx, top)
          ..quadraticBezierTo(p.dx + 12, top + 4, p.dx + 26, top + 26)
          ..lineTo(p.dx + 14, top + 20)
          ..lineTo(p.dx + 4, top + 30)
          ..lineTo(p.dx - 8, top + 20)
          ..lineTo(p.dx - 18, top + 30)
          ..close(),
        Paint()..color = Colors.white,
      );
      // علم لما القسم يخلص
      if (done[i]) {
        // العلم على جنب الجبل عشان كارت الاسم فوق القمة
        final fx = p.dx - 52, fy = p.dy + 30;
        c.drawLine(Offset(fx, fy), Offset(fx, fy - 46), Paint()
          ..color = const Color(0xFF5E4E42)
          ..strokeWidth = 3);
        final wave = math.sin(t * 5 + i) * 3;
        c.drawPath(Path()..moveTo(fx, fy - 46)..quadraticBezierTo(fx + 14, fy - 46 + wave, fx + 26, fy - 40)..lineTo(fx, fy - 30)..close(), Paint()..color = AppColors.gold);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter old) => true;
}

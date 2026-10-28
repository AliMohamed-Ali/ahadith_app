import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/progress_store.dart';
import '../widgets/common.dart';
import '../widgets/my_fanoos.dart';
import '../theme.dart';
import 'hadith_screen.dart';
import 'story_screen.dart';

/// سياق رحلة الحديث: الحكاية ← الحديث ← اللعبة.
class FlowCtx {
  FlowCtx({required this.tab, required this.level, required this.all, required this.index});
  final AppTab tab;
  final Level? level;
  final List<Hadith> all;
  final int index;

  Hadith get hadith => all[index];
  bool get openTab => !tab.usesLevels;
  List<String> get levelHadithIds => all.map((h) => h.id).toList();
  FlowCtx? get next => index + 1 < all.length ? FlowCtx(tab: tab, level: level, all: all, index: index + 1) : null;
}

/// يبدأ رحلة حديث: لو له حكاية مصورة تظهر أولًا.
void openHadithFlow(BuildContext context, FlowCtx f, {bool replace = false}) {
  final route = MaterialPageRoute(builder: (_) => f.hadith.hasStory ? StoryScreen(flow: f) : HadithScreen(flow: f));
  replace ? Navigator.of(context).pushReplacement(route) : Navigator.of(context).push(route);
}

/// خريطة النهر: كل محطة حديث.
class RiverScreen extends StatefulWidget {
  const RiverScreen({super.key, required this.tab, this.level, this.embedded = false, this.showHeader = true});
  final AppTab tab;
  final Level? level;
  /// true لو الشاشة داخل الشريط السفلي أو صفحة لها AppBar بالفعل.
  final bool embedded;
  final bool showHeader;

  @override
  State<RiverScreen> createState() => _RiverScreenState();
}

class _RiverScreenState extends State<RiverScreen> with SingleTickerProviderStateMixin {
  late final Stream<List<Hadith>> _stream = context.read<ContentRepository>().hadiths(widget.tab.id, levelId: widget.level?.id);
  late final AnimationController _wave = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  static const _gap = 132.0;
  static const _top = 90.0;

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  double _xFor(int i, double w) => w / 2 + math.sin(i * 0.95) * (w * 0.26);

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final p = context.watch<ProgressStore>();
    final title = widget.level?.name(ar) ?? widget.tab.name(ar);
    final color = hexColor(widget.level?.color ?? widget.tab.color, AppColors.teal);

    final body = StreamBuilder<List<Hadith>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(S.of(context, 'loadError')));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!;
        if (list.isEmpty) return Center(child: Text(S.of(context, 'emptyContent'), style: const TextStyle(fontSize: 18)));
        final doneN = list.where((h) => p.isDone(h.id)).length;
        final firstUndone = list.indexWhere((h) => !p.isDone(h.id));
        final current = firstUndone == -1 ? list.length - 1 : firstUndone;
        bool locked(int i) => widget.tab.usesLevels && firstUndone != -1 && i > firstUndone;

        return Column(children: [
          if (widget.showHeader && widget.embedded) SafeArea(bottom: false, child: const SizedBox(height: 4)),
          // شريط التقدم
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: cardBox(radius: 20),
            child: Row(children: [
              if (widget.embedded && widget.showHeader) ...[
                Flexible(child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: doneN / list.length),
                    duration: const Duration(milliseconds: 700),
                    builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 12, backgroundColor: AppColors.mint, color: color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${arNum(doneN, arabic: ar)} / ${arNum(list.length, arabic: ar)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final w = box.maxWidth;
              final h = _top * 2 + (list.length - 1) * _gap;
              final points = [for (var i = 0; i < list.length; i++) Offset(_xFor(i, w), _top + i * _gap)];
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 90),
                child: SizedBox(
                  width: w,
                  height: h,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _wave,
                        builder: (_, __) => CustomPaint(painter: _RiverPainter(points, _wave.value)),
                      ),
                    ),
                    for (var i = 0; i < list.length; i++)
                      Positioned(
                        left: points[i].dx - 38,
                        top: points[i].dy - 38,
                        child: RiseIn(
                          delay: math.min(i, 8) * 60,
                          child: _Stop(
                            number: i + 1,
                            title: list[i].title(ar),
                            done: p.isDone(list[i].id),
                            current: i == current,
                            locked: locked(i),
                            color: color,
                            onTap: locked(i)
                                ? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, content: Text(S.of(context, 'lockedToast'))))
                                : () => openHadithFlow(context, FlowCtx(tab: widget.tab, level: widget.level, all: list, index: i)),
                          ),
                        ),
                      ),
                    // فانوس واقف عند المحطة الحالية
                    Positioned(
                      left: points[current].dx + (points[current].dx > w / 2 ? -110 : 44),
                      top: points[current].dy - 60,
                      child: const IgnorePointer(child: MyFanoos(size: 52)),
                    ),
                  ]),
                ),
              );
            }),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: AppColors.coral),
                onPressed: () => openHadithFlow(context, FlowCtx(tab: widget.tab, level: widget.level, all: list, index: current)),
                icon: const Icon(Icons.play_arrow_rounded, size: 30),
                label: Text(firstUndone == -1 ? S.of(context, 'reviewAgain') : (doneN == 0 ? S.of(context, 'letsStart') : S.of(context, 'letsContinue'))),
              ),
            ),
          ),
        ]);
      },
    );

    if (widget.embedded) return Container(color: const Color(0xFFDFF3E4), child: body);
    return Scaffold(
      backgroundColor: const Color(0xFFDFF3E4),
      appBar: AppBar(title: Text(title), backgroundColor: color, foregroundColor: onColor(color)),
      body: body,
    );
  }
}

class _Stop extends StatefulWidget {
  const _Stop({required this.number, required this.title, required this.done, required this.current, required this.locked, required this.color, required this.onTap});
  final int number;
  final String title;
  final bool done;
  final bool current;
  final bool locked;
  final Color color;
  final VoidCallback onTap;
  @override
  State<_Stop> createState() => _StopState();
}

class _StopState extends State<_Stop> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.current) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Stop old) {
    super.didUpdateWidget(old);
    if (widget.current && !_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!widget.current && _pulse.isAnimating) _pulse.stop();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final bg = widget.locked ? const Color(0xFFB8C2CC) : (widget.done ? AppColors.gold : widget.color);
    final shadow = widget.locked ? const Color(0xFF8C97A3) : (widget.done ? AppColors.goldDark : Color.lerp(widget.color, Colors.black, .3)!);
    return SizedBox(
      width: 76,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Transform.scale(scale: 1 + _pulse.value * 0.08, child: child),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 5),
                boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 6))],
              ),
              alignment: Alignment.center,
              child: widget.locked
                  ? const Icon(Icons.lock_rounded, color: Colors.white, size: 30)
                  : widget.done
                      ? const StarIcon(size: 36, color: Colors.white)
                      : Text(arNum(widget.number, arabic: ar), style: TextStyle(color: onColor(bg), fontSize: 28, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
          child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

/// النهر: خط عريض أزرق بين المحطات + موجات متحركة + عشب على الجوانب.
class _RiverPainter extends CustomPainter {
  _RiverPainter(this.points, this.t);
  final List<Offset> points;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, 0);
    path.lineTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      final midY = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, midY, b.dx, midY, b.dx, b.dy);
    }
    path.lineTo(points.last.dx, size.height);

    // ضفة
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 70
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFBFE6C6));
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 54
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF6EC6F0));
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF9EDCF7));

    // موجات بيضاء تجري مع النهر
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(.85);
    for (final m in path.computeMetrics()) {
      const dash = 18.0, gap = 46.0;
      var d = (t * (dash + gap)) % (dash + gap);
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), wave);
        d += dash + gap;
      }
    }

    // عشب وزهور بسيطة على الجانبين
    final rnd = math.Random(7);
    final grass = Paint()..color = const Color(0xFF5DBB63);
    final flower = Paint()..color = const Color(0xFFF27BA6);
    for (var y = 40.0; y < size.height; y += 70) {
      final left = rnd.nextBool();
      final x = left ? 14 + rnd.nextDouble() * 30 : size.width - 14 - rnd.nextDouble() * 30;
      canvas.drawCircle(Offset(x, y), 10, grass);
      canvas.drawCircle(Offset(x + 9, y + 4), 8, grass);
      if (rnd.nextInt(3) == 0) canvas.drawCircle(Offset(x + 4, y - 6), 4, flower);
    }
  }

  @override
  bool shouldRepaint(covariant _RiverPainter old) => old.t != t || old.points.length != points.length;
}

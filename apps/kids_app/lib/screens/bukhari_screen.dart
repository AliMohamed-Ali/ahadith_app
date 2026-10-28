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
import '../widgets/my_fanoos.dart';
import 'tab_router.dart';

const _firstAge = 4, _lastAge = 12;

/// صحيح البخاري: سنين من 4 لـ 12، وكل سن دروس. الطفل الأكبر من 4 بيعمل اختبار صغير الأول.
class BukhariScreen extends StatefulWidget {
  const BukhariScreen({super.key, required this.tab, this.showHeader = true});
  final AppTab tab;
  final bool showHeader;
  @override
  State<BukhariScreen> createState() => _BukhariScreenState();
}

class _BukhariScreenState extends State<BukhariScreen> {
  int? _year;

  int _kidAge(ProgressStore p) => (p.profile?.age ?? 6).clamp(_firstAge, _lastAge);

  Future<void> _placement(int age) async {
    final start = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => PlacementScreen(tab: widget.tab, age: age)));
    if (start != null && mounted) setState(() => _year = start);
  }

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final p = context.watch<ProgressStore>();
    final age = _kidAge(p);
    final start = p.bukhariStart;
    final needsTest = start == null && age > _firstAge;
    final year = _year ?? start ?? _firstAge;
    final color = hexColor(widget.tab.color, const Color(0xFF7558D6));

    return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
      if (widget.showHeader) ...[
        SafeArea(bottom: false, child: Text(widget.tab.name(ar), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
        const SizedBox(height: 12),
      ],
      if (needsTest)
        RiseIn(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: cardBox(shadow: color.withOpacity(.5)),
            child: Column(children: [
              const MyFanoos(size: 80, mood: FanoosMood.talk),
              const SizedBox(height: 8),
              Text(S.of(context, 'bkPlaceTitle'), textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 6),
              Text(S.of(context, 'bkPlaceBody', {'n': arNum(age, arabic: ar)}), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, height: 1.6)),
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: color, minimumSize: const Size.fromHeight(54)),
                onPressed: () => _placement(age),
                icon: const Icon(Icons.quiz_rounded),
                label: Text(S.of(context, 'bkPlaceStart')),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () => p.setBukhariStart(_firstAge),
                child: Text(S.of(context, 'bkPlaceSkip')),
              ),
            ]),
          ),
        )
      else ...[
        // السنين
        SizedBox(
          height: 84,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (var y = _firstAge; y <= _lastAge; y++) _yearChip(y, year, age, start ?? _firstAge, color, ar),
          ]),
        ),
        if (age > _firstAge)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(onPressed: () => _placement(age), icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(S.of(context, 'bkRetake'))),
          ),
        const SizedBox(height: 6),
        if (year > age)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const MyFanoos(size: 80),
              const SizedBox(height: 10),
              Text(S.of(context, 'bkLocked'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
            ]),
          )
        else
          _Lessons(key: ValueKey(year), tab: widget.tab, year: year, color: color),
      ],
    ]);
  }

  Widget _yearChip(int y, int selected, int age, int start, Color color, bool ar) {
    final sel = y == selected;
    final locked = y > age;
    final passed = y < start;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GestureDetector(
        onTap: () => setState(() => _year = y),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 70,
          decoration: BoxDecoration(
            color: sel ? color : (locked ? const Color(0xFFEDEDF3) : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: y == age ? AppColors.gold : Colors.transparent, width: 3),
            boxShadow: [BoxShadow(color: sel ? color.withOpacity(.5) : Colors.black12, offset: const Offset(0, 4))],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(arNum(y, arabic: ar), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: sel ? Colors.white : (locked ? AppColors.muted : AppColors.navy), height: 1)),
            if (locked)
              Icon(Icons.lock_rounded, size: 16, color: sel ? Colors.white : AppColors.muted)
            else if (passed)
              Icon(Icons.check_circle_rounded, size: 16, color: sel ? Colors.white : AppColors.teal)
            else
              Text(y == age ? S.of(context, 'bkYourAge') : S.of(context, 'bkYear', {'n': ''}).trim(), style: TextStyle(fontSize: 12, color: sel ? Colors.white : AppColors.muted)),
          ]),
        ),
      ),
    );
  }
}

/// دروس سن واحدة.
class _Lessons extends StatefulWidget {
  const _Lessons({super.key, required this.tab, required this.year, required this.color});
  final AppTab tab;
  final int year;
  final Color color;
  @override
  State<_Lessons> createState() => _LessonsState();
}

class _LessonsState extends State<_Lessons> {
  late final Stream<List<Level>> _levels = context.read<ContentRepository>().levelsForAge(widget.tab.id, widget.year);

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final p = context.watch<ProgressStore>();
    return StreamBuilder<List<Level>>(
      stream: _levels,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text(S.of(context, 'loadError')));
        if (!snap.hasData) return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
        final levels = snap.data!;
        if (levels.isEmpty) return Padding(padding: const EdgeInsets.all(24), child: Text(S.of(context, 'bkEmpty'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)));
        final next = levels.indexWhere((l) => !p.completedLevels.contains(l.id));
        return LayoutBuilder(builder: (context, box) {
          final cols = box.maxWidth > 560 ? 3 : 2;
          final w = (box.maxWidth - (cols - 1) * 12) / cols;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < levels.length; i++)
              RiseIn(
                delay: math.min(i, 8) * 50,
                child: SizedBox(width: w, child: _lessonCard(levels[i], i, i == next, p, ar)),
              ),
          ]);
        });
      },
    );
  }

  Widget _lessonCard(Level l, int i, bool isNext, ProgressStore p, bool ar) {
    final done = p.completedLevels.contains(l.id);
    final total = l.hadithIds.length;
    final got = l.hadithIds.where(p.isDone).length;
    final c = widget.color;
    return GestureDetector(
      onTap: () => openLevel(context, widget.tab, l),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: cardBox(color: done ? const Color(0xFFFFF6D8) : Colors.white, shadow: isNext ? c.withOpacity(.6) : AppColors.mintLine),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: done ? AppColors.gold : (isNext ? c : c.withOpacity(.15)),
              child: done
                  ? const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20)
                  : Text(arNum(i + 1, arabic: ar), style: TextStyle(fontWeight: FontWeight.w800, color: isNext ? Colors.white : c)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(S.of(context, 'bkLesson', {'n': arNum(i + 1, arabic: ar)}), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
            if (isNext) Icon(ar ? Icons.play_arrow_rounded : Icons.play_arrow_rounded, color: c),
          ]),
          const SizedBox(height: 6),
          Text(l.age(ar), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          if (total > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: got / total, minHeight: 8, backgroundColor: c.withOpacity(.12), color: done ? AppColors.gold : c),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Question {
  _Question(this.hadith) : options = [...hadith.game.options]..shuffle();
  final Hadith hadith;
  final List<String> options;
}

/// اختبار تحديد المستوى: 3 أسئلة "كمّل الحديث" من كل سن أصغر من سن الطفل.
/// لو جاوب 2 من 3 صح يعدّي السن دي، وأول سن يقف فيها هي اللي يبدأ منها.
class PlacementScreen extends StatefulWidget {
  const PlacementScreen({super.key, required this.tab, required this.age});
  final AppTab tab;
  final int age;
  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  final _rnd = math.Random();
  int _year = _firstAge;
  List<_Question>? _qs;
  int _i = 0, _right = 0;
  String? _picked;
  bool _yearPassed = false;
  int? _result;

  @override
  void initState() {
    super.initState();
    _loadYear();
  }

  Future<void> _loadYear() async {
    setState(() => _qs = null);
    while (_year < widget.age) {
      final list = await context.read<ContentRepository>().hadithsForAge(widget.tab.id, _year, limit: 40);
      final good = list.where((h) => h.game.isValid).toList()..shuffle(_rnd);
      if (good.length >= 3) {
        if (!mounted) return;
        setState(() {
          _qs = good.take(3).map(_Question.new).toList();
          _i = 0;
          _right = 0;
          _picked = null;
          _yearPassed = false;
        });
        return;
      }
      // السن دي لسه ملهاش أحاديث منشورة كفاية: نعدّيها
      _year++;
    }
    _finish(widget.age);
  }

  void _finish(int start) {
    context.read<ProgressStore>().setBukhariStart(start);
    setState(() => _result = start);
  }

  void _pick(String o) {
    if (_picked != null) return;
    final q = _qs![_i];
    setState(() {
      _picked = o;
      if (o == q.hadith.game.answer) _right++;
    });
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      if (_i < _qs!.length - 1) {
        setState(() {
          _i++;
          _picked = null;
        });
      } else if (_right >= 2) {
        setState(() => _yearPassed = true);
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          _year++;
          _year < widget.age ? _loadYear() : _finish(widget.age);
        });
      } else {
        _finish(_year);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context, 'bkPlaceTitle')), backgroundColor: const Color(0xFF7558D6)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _result != null ? _resultView(ar) : (_qs == null ? _loading() : (_yearPassed ? _passedView(ar) : _questionView(ar))),
        ),
      ),
    );
  }

  Widget _loading() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Fanoos(size: 80, mood: FanoosMood.talk),
          const SizedBox(height: 12),
          Text(S.of(context, 'bkLoading'), style: const TextStyle(fontSize: 18)),
        ]),
      );

  Widget _yearsBar(bool ar) => Row(children: [
        for (var y = _firstAge; y < widget.age; y++)
          Expanded(
            child: Container(
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: y < _year || (y == _year && _yearPassed) ? AppColors.teal : (y == _year ? AppColors.gold : AppColors.mintLine),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
      ]);

  Widget _questionView(bool ar) {
    final q = _qs![_i];
    final g = q.hadith.game;
    final solved = _picked != null;
    return ListView(children: [
      _yearsBar(ar),
      const SizedBox(height: 10),
      Text(
        S.of(context, 'bkQ', {'y': arNum(_year, arabic: ar), 'i': arNum(_i + 1, arabic: ar), 'n': arNum(_qs!.length, arabic: ar)}),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted),
      ),
      const SizedBox(height: 10),
      Center(child: Fanoos(size: 70, mood: solved ? (_picked == g.answer ? FanoosMood.happy : FanoosMood.smile) : FanoosMood.talk)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: cardBox(),
        child: Column(children: [
          Text(S.of(context, 'completeHadith'), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.teal)),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, runSpacing: 6, children: [
              if (g.before.isNotEmpty) Text(g.before, style: hadithStyle(size: 22)),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: solved ? AppColors.gold : AppColors.mint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: solved ? AppColors.goldDark : AppColors.teal, width: 2),
                ),
                child: Text(solved ? g.answer : '  ؟  ', style: hadithStyle(size: 22)),
              ),
              if (g.after.isNotEmpty) Text(g.after, style: hadithStyle(size: 22)),
            ]),
          ),
          const SizedBox(height: 6),
          Text(q.hadith.sourceAr, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ),
      const SizedBox(height: 16),
      for (final o in q.options)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: BoxDecoration(
              color: !solved ? Colors.white : (o == g.answer ? const Color(0xFFDFF5E6) : (o == _picked ? const Color(0xFFFFE1DA) : Colors.white)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: !solved ? AppColors.mintLine : (o == g.answer ? AppColors.teal : (o == _picked ? AppColors.coral : AppColors.mintLine)), width: 2.5),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _pick(o),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(o, textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: hadithStyle(size: 22))),
            ),
          ),
        ),
    ]);
  }

  Widget _passedView(bool ar) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _yearsBar(ar),
        const Spacer(),
        const Fanoos(size: 110, mood: FanoosMood.happy),
        const SizedBox(height: 14),
        Text(S.of(context, 'bkYearPassed', {'n': arNum(_year, arabic: ar)}), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.teal)),
        const Spacer(),
      ]);

  Widget _resultView(bool ar) => Column(children: [
        const Spacer(),
        const Stack(alignment: Alignment.center, children: [ConfettiBurst(size: 260), Fanoos(size: 120, mood: FanoosMood.happy)]),
        const SizedBox(height: 14),
        Text(
          _result! >= widget.age ? S.of(context, 'bkResultAll') : S.of(context, 'bkResult', {'n': arNum(_result!, arabic: ar)}),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.5),
        ),
        const Spacer(),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: const Color(0xFF7558D6)),
          onPressed: () => Navigator.of(context).pop(_result),
          child: Text(S.of(context, 'bkGo')),
        ),
      ]);
}

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/progress_store.dart';
import '../widgets/common.dart';
import 'qa_screen.dart';
import 'river_screen.dart';

/// يفتح أي تبويب حسب نوعه (أحاديث بمستويات، أحاديث مفتوحة، أسئلة وأجوبة).
void openTab(BuildContext context, AppTab tab) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: Text(tab.name(S.ar(context))), backgroundColor: hexColor(tab.color, AppColors.navy), foregroundColor: onColor(hexColor(tab.color, AppColors.navy))),
      body: TabBody(tab: tab, inRoute: true),
    ),
  ));
}

void openLevel(BuildContext context, AppTab tab, Level level) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => RiverScreen(tab: tab, level: level)));
}

/// محتوى التبويب نفسه (يُستخدم داخل الشريط السفلي أو في صفحة مستقلة).
class TabBody extends StatelessWidget {
  const TabBody({super.key, required this.tab, this.inRoute = false});
  final AppTab tab;
  final bool inRoute;

  @override
  Widget build(BuildContext context) {
    if (tab.isQa) return QaScreen(tab: tab, showHeader: !inRoute);
    if (!tab.hasLevels) return RiverScreen(tab: tab, embedded: true, showHeader: !inRoute);
    return LevelsList(tab: tab, showHeader: !inRoute);
  }
}

/// قائمة مستويات تبويب (عددها حسب ما يضيفه المدير).
class LevelsList extends StatefulWidget {
  const LevelsList({super.key, required this.tab, this.showHeader = true});
  final AppTab tab;
  final bool showHeader;
  @override
  State<LevelsList> createState() => _LevelsListState();
}

class _LevelsListState extends State<LevelsList> {
  late final Stream<List<Level>> _levels = context.read<ContentRepository>().levels(widget.tab.id);

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final tab = widget.tab;
    final showHeader = widget.showHeader;
    final p = context.watch<ProgressStore>();
    return StreamBuilder<List<Level>>(
      stream: _levels,
      builder: (context, snap) {
        final levels = snap.data ?? const <Level>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (showHeader) ...[
              SafeArea(bottom: false, child: Text(tab.name(ar), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800))),
              const SizedBox(height: 12),
            ],
            if (snap.connectionState == ConnectionState.waiting) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
            if (snap.hasData && levels.isEmpty) Center(child: Text(S.of(context, 'emptyContent'))),
            for (var i = 0; i < levels.length; i++)
              RiseIn(
                delay: i * 80,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: BigTile(
                    color: hexColor(levels[i].color, AppColors.gold),
                    shadow: Colors.black12,
                    onTap: () => openLevel(context, tab, levels[i]),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white,
                        child: p.completedLevels.contains(levels[i].id)
                            ? const RoyalStarIcon(size: 28)
                            : Text(arNum(i + 1, arabic: ar), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.navy)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(levels[i].name(ar), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: onColor(hexColor(levels[i].color)))),
                          if (levels[i].age(ar).isNotEmpty) Text(levels[i].age(ar), style: TextStyle(fontSize: 15, color: onColor(hexColor(levels[i].color)))),
                        ]),
                      ),
                      Icon(ar ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 32, color: onColor(hexColor(levels[i].color))),
                    ]),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

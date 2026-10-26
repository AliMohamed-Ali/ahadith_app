import 'models.dart';

/// حساب النجوم العادية والملكية من تقدم الطفل وإعدادات المدير.
class RewardsCalculator {
  const RewardsCalculator(this.config);
  final RewardsConfig config;

  /// doneCount: عدد مرات الفوز لكل حديث. knownCount: عدد أسئلة «عرفتها».
  int normalStars({required Map<String, int> doneCount, required int knownCount}) {
    final wins = doneCount.values.fold<int>(0, (a, b) => a + b);
    return wins * config.perGame + knownCount * config.perKnow;
  }

  int royalStars({
    required int completedLevels,
    required int openTabsDone,
    required int completedSections,
    required int missionsDone,
    required Map<String, int> doneCount,
  }) {
    var r = 0;
    if (config.level.on) r += completedLevels;
    if (config.openTabs.on && config.openTabs.n > 0) r += openTabsDone ~/ config.openTabs.n;
    if (config.section.on) r += completedSections;
    if (config.mission.on) r += missionsDone;
    if (config.tree.on) r += doneCount.values.where((v) => v >= config.tree.n).length;
    return r;
  }

  /// رقم مستوى فانوس (0..n-1) حسب النجوم العادية.
  int fanoosLevel(int stars) {
    var lv = 0;
    for (var i = 0; i < config.fanoosLevels.length; i++) {
      if (stars >= config.fanoosLevels[i]) lv = i;
    }
    return lv;
  }

  /// مرحلة النبتة في الحديقة: 1 بذرة، 2 وردة، 3 شجرة مثمرة.
  int plantStage(int wins) {
    if (wins <= 0) return 0;
    if (wins >= config.tree.n) return 3;
    return wins >= 2 ? 2 : 1;
  }
}

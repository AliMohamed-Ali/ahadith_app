import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/sounds.dart';

/// ملف الطفل — يُحفظ على الجهاز فقط.
class KidProfile {
  KidProfile({required this.name, this.age = 6, this.avatar = 'cat', this.city = -1, this.area = '', this.photoPath = ''});
  final String name;
  final int age;
  final String avatar;
  final int city;
  final String area;
  final String photoPath;

  bool get hasPhoto => photoPath.isNotEmpty && !kIsWeb && File(photoPath).existsSync();

  KidProfile copyWith({String? name, int? age, String? avatar, int? city, String? area, String? photoPath}) => KidProfile(
        name: name ?? this.name,
        age: age ?? this.age,
        avatar: avatar ?? this.avatar,
        city: city ?? this.city,
        area: area ?? this.area,
        photoPath: photoPath ?? this.photoPath,
      );

  Map<String, dynamic> toJson() => {'name': name, 'age': age, 'avatar': avatar, 'city': city, 'area': area, 'photoPath': photoPath};
  factory KidProfile.fromJson(Map<String, dynamic> j) => KidProfile(
        name: (j['name'] ?? '') as String,
        age: (j['age'] ?? 6) as int,
        avatar: (j['avatar'] ?? 'cat') as String,
        city: (j['city'] ?? -1) as int,
        area: (j['area'] ?? '') as String,
        photoPath: (j['photoPath'] ?? '') as String,
      );
}

/// كل تقدم الطفل: النجوم، الحديقة، المهمات، فانوس، اللغة، الملف.
class ProgressStore extends ChangeNotifier {
  ProgressStore._(this._prefs);
  static const _key = 'hadith-kids-v1';
  final SharedPreferences _prefs;

  String lang = 'ar';
  KidProfile? profile;
  /// عدد مرات الفوز في لعبة كل حديث (= مراجعاته).
  Map<String, int> doneCount = {};
  /// التبويب الذي ينتمي له كل حديث تم فوزه (لحساب نجوم التبويبات المفتوحة).
  Map<String, String> doneTab = {};
  /// أسئلة «عرفتها» بمفتاح sectionId:index
  Set<String> known = {};
  /// المهمات: hadithId -> 'pending' | 'done'
  Map<String, String> missions = {};
  Set<String> completedLevels = {};
  Set<String> completedSections = {};
  Set<String> openTabIds = {};
  String fanColor = 'gold';
  /// زينة فانوس التي يلبسها الآن (مثل crown, bow, halo).
  Set<String> wearing = {};
  bool locOk = false;
  bool showMe = true;
  /// صحيح البخاري: السن اللي الطفل بيبدأ منها (من اختبار تحديد المستوى)، و null لو لسه ما اتحددتش.
  int? bukhariStart;
  /// الأصوات والاهتزاز.
  bool soundOn = true;

  bool get ar => lang == 'ar';

  static Future<ProgressStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = ProgressStore._(prefs);
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        s.lang = (j['lang'] ?? 'ar') as String;
        s.profile = j['profile'] == null ? null : KidProfile.fromJson(Map<String, dynamic>.from(j['profile'] as Map));
        s.doneCount = Map<String, int>.from((j['doneCount'] ?? {}) as Map);
        s.doneTab = Map<String, String>.from((j['doneTab'] ?? {}) as Map);
        s.known = Set<String>.from((j['known'] ?? []) as List);
        s.missions = Map<String, String>.from((j['missions'] ?? {}) as Map);
        s.completedLevels = Set<String>.from((j['completedLevels'] ?? []) as List);
        s.completedSections = Set<String>.from((j['completedSections'] ?? []) as List);
        s.openTabIds = Set<String>.from((j['openTabIds'] ?? []) as List);
        s.fanColor = (j['fanColor'] ?? 'gold') as String;
        s.wearing = Set<String>.from((j['wearing'] ?? []) as List);
        s.locOk = (j['locOk'] ?? false) as bool;
        s.showMe = (j['showMe'] ?? true) as bool;
        s.bukhariStart = j['bukhariStart'] as int?;
        s.soundOn = (j['soundOn'] ?? true) as bool;
      } catch (e) {
        debugPrint('progress load failed: $e');
      }
    }
    Sounds.enabled = s.soundOn;
    return s;
  }

  Future<void> _save() async {
    await _prefs.setString(
      _key,
      jsonEncode({
        'lang': lang,
        'profile': profile?.toJson(),
        'doneCount': doneCount,
        'doneTab': doneTab,
        'known': known.toList(),
        'missions': missions,
        'completedLevels': completedLevels.toList(),
        'completedSections': completedSections.toList(),
        'openTabIds': openTabIds.toList(),
        'fanColor': fanColor,
        'wearing': wearing.toList(),
        'locOk': locOk,
        'showMe': showMe,
        'bukhariStart': bukhariStart,
        'soundOn': soundOn,
      }),
    );
  }

  void _changed() {
    notifyListeners();
    _save();
  }

  // ---------- النجوم ----------
  int normalStars(RewardsConfig c) => RewardsCalculator(c).normalStars(doneCount: doneCount, knownCount: known.length);

  int royalStars(RewardsConfig c) => RewardsCalculator(c).royalStars(
        completedLevels: completedLevels.length,
        openTabsDone: doneTab.entries.where((e) => openTabIds.contains(e.value)).length,
        completedSections: completedSections.length,
        missionsDone: missions.values.where((v) => v == 'done').length,
        doneCount: doneCount,
      );

  int wins(String hadithId) => doneCount[hadithId] ?? 0;
  bool isDone(String hadithId) => wins(hadithId) > 0;
  int get plantsCount => doneCount.length;
  int get butterflies => missions.values.where((v) => v == 'done').length;

  // ---------- الأحداث ----------
  void setLang(String l) {
    lang = l;
    _changed();
  }

  /// يُستدعى عند الفوز في لعبة حديث.
  /// levelHadithIds: كل أحاديث المستوى (لمعرفة اكتماله)، أو null لتبويب مفتوح.
  void winGame(Hadith h, {required bool openTab, String? levelId, List<String>? levelHadithIds}) {
    doneCount[h.id] = wins(h.id) + 1;
    doneTab[h.id] = h.tabId;
    if (openTab) openTabIds.add(h.tabId);
    if (h.mission(true).trim().isNotEmpty && !missions.containsKey(h.id)) missions[h.id] = 'pending';
    if (levelId != null && levelHadithIds != null && levelHadithIds.isNotEmpty && levelHadithIds.every(isDone)) {
      completedLevels.add(levelId);
    }
    _changed();
  }

  void toggleKnown(String key, {required String sectionId, required int sectionSize}) {
    if (known.contains(key)) {
      known.remove(key);
      completedSections.remove(sectionId);
    } else {
      known.add(key);
      final count = known.where((k) => k.startsWith('$sectionId:')).length;
      if (count >= sectionSize && sectionSize > 0) completedSections.add(sectionId);
    }
    _changed();
  }

  void completeMission(String hadithId) {
    missions[hadithId] = 'done';
    _changed();
  }

  void setFanColor(String id) {
    fanColor = id;
    _changed();
  }

  void toggleWear(String id) {
    wearing.contains(id) ? wearing.remove(id) : wearing.add(id);
    _changed();
  }

  /// كل المهمات المعلّقة.
  List<String> get pendingMissions => missions.entries.where((e) => e.value == 'pending').map((e) => e.key).toList();

  void saveProfile(KidProfile p) {
    profile = p;
    _changed();
  }

  void setLocOk(bool v) {
    locOk = v;
    if (v) showMe = true;
    _changed();
  }

  void setSound(bool v) {
    soundOn = v;
    Sounds.enabled = v;
    _changed();
  }

  void setBukhariStart(int age) {
    bukhariStart = age;
    _changed();
  }

  void setShowMe(bool v) {
    showMe = v;
    _changed();
  }

  /// يحفظ الصورة في مجلد الأبلكيشن ويعيد مسارها.
  Future<String> storePhoto(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await f.writeAsBytes(bytes, flush: true);
    final old = profile?.photoPath ?? '';
    if (old.isNotEmpty) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    return f.path;
  }

  Future<void> deleteEverything() async {
    final old = profile?.photoPath ?? '';
    if (old.isNotEmpty && !kIsWeb) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    profile = null;
    doneCount = {};
    doneTab = {};
    known = {};
    missions = {};
    completedLevels = {};
    completedSections = {};
    openTabIds = {};
    fanColor = 'gold';
    wearing = {};
    locOk = false;
    showMe = true;
    bukhariStart = null;
    await _prefs.remove(_key);
    notifyListeners();
  }
}

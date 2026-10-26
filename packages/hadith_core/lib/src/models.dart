import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;

String _s(Object? v) => v is String ? v : (v == null ? '' : v.toString());
int _i(Object? v, [int d = 0]) => v is int ? v : (v is num ? v.toInt() : int.tryParse(_s(v)) ?? d);
bool _b(Object? v, [bool d = false]) => v is bool ? v : d;

/// تبويب محتوى (المستويات، الأربعون النووية، ما لا يسع، أو أي تبويب يضيفه المدير).
class AppTab {
  AppTab({
    required this.id,
    required this.nameAr,
    this.nameEn = '',
    this.type = 'hadith',
    this.mode = 'open',
    this.place = 'home',
    this.color = '#0E7C74',
    this.visible = true,
    this.order = 0,
    this.system = false,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  /// 'hadith' أو 'qa'
  final String type;
  /// 'levels' أو 'open'
  final String mode;
  /// 'home' (كارت في الرئيسية) أو 'tab' (تبويب في الشريط السفلي)
  final String place;
  final String color;
  final bool visible;
  final int order;
  final bool system;

  bool get isHadith => type == 'hadith';
  bool get isQa => type == 'qa';
  bool get hasLevels => isHadith && mode == 'levels';
  String name(bool ar) => ar || nameEn.isEmpty ? nameAr : nameEn;

  factory AppTab.fromJson(String id, Json j) => AppTab(
        id: id,
        nameAr: _s(j['nameAr']),
        nameEn: _s(j['nameEn']),
        type: _s(j['type']).isEmpty ? 'hadith' : _s(j['type']),
        mode: _s(j['mode']).isEmpty ? 'open' : _s(j['mode']),
        place: _s(j['place']).isEmpty ? 'home' : _s(j['place']),
        color: _s(j['color']).isEmpty ? '#0E7C74' : _s(j['color']),
        visible: _b(j['visible'], true),
        order: _i(j['order']),
        system: _b(j['system']),
      );

  factory AppTab.fromDoc(DocumentSnapshot<Json> d) => AppTab.fromJson(d.id, d.data() ?? {});

  Json toJson() => {
        'nameAr': nameAr,
        'nameEn': nameEn,
        'type': type,
        'mode': mode,
        'place': place,
        'color': color,
        'visible': visible,
        'order': order,
        'system': system,
      };

  AppTab copyWith({String? nameAr, String? nameEn, String? type, String? mode, String? place, String? color, bool? visible, int? order}) => AppTab(
        id: id,
        nameAr: nameAr ?? this.nameAr,
        nameEn: nameEn ?? this.nameEn,
        type: type ?? this.type,
        mode: mode ?? this.mode,
        place: place ?? this.place,
        color: color ?? this.color,
        visible: visible ?? this.visible,
        order: order ?? this.order,
        system: system,
      );
}

/// مستوى داخل تبويب أحاديث بمستويات. عددها غير محدود.
class Level {
  Level({required this.id, required this.tabId, required this.nameAr, this.nameEn = '', this.ageAr = '', this.ageEn = '', this.color = '#FFD465', this.order = 0});

  final String id;
  final String tabId;
  final String nameAr;
  final String nameEn;
  final String ageAr;
  final String ageEn;
  final String color;
  final int order;

  String name(bool ar) => ar || nameEn.isEmpty ? nameAr : nameEn;
  String age(bool ar) => ar || ageEn.isEmpty ? ageAr : ageEn;

  factory Level.fromJson(String id, Json j) => Level(
        id: id,
        tabId: _s(j['tabId']),
        nameAr: _s(j['nameAr']),
        nameEn: _s(j['nameEn']),
        ageAr: _s(j['ageAr']),
        ageEn: _s(j['ageEn']),
        color: _s(j['color']).isEmpty ? '#FFD465' : _s(j['color']),
        order: _i(j['order']),
      );

  factory Level.fromDoc(DocumentSnapshot<Json> d) => Level.fromJson(d.id, d.data() ?? {});

  Json toJson() => {'tabId': tabId, 'nameAr': nameAr, 'nameEn': nameEn, 'ageAr': ageAr, 'ageEn': ageEn, 'color': color, 'order': order};

  Level copyWith({String? nameAr, String? nameEn, String? ageAr, String? ageEn, String? color, int? order}) => Level(
        id: id,
        tabId: tabId,
        nameAr: nameAr ?? this.nameAr,
        nameEn: nameEn ?? this.nameEn,
        ageAr: ageAr ?? this.ageAr,
        ageEn: ageEn ?? this.ageEn,
        color: color ?? this.color,
        order: order ?? this.order,
      );
}

/// بيانات لعبة "الكلمة الناقصة".
class GameData {
  GameData({this.before = '', this.answer = '', this.after = '', this.options = const []});
  final String before;
  final String answer;
  final String after;
  final List<String> options;

  bool get isValid => answer.trim().isNotEmpty && options.length >= 2;
  List<String> get wrongOptions => options.where((o) => o != answer).toList();

  factory GameData.fromJson(Json? j) => GameData(
        before: _s(j?['before']),
        answer: _s(j?['answer']),
        after: _s(j?['after']),
        options: ((j?['options'] as List?) ?? const []).map(_s).toList(),
      );

  Json toJson() => {'before': before, 'answer': answer, 'after': after, 'options': options};
}

/// الحكاية المصورة.
class Story {
  Story({this.textAr = '', this.textEn = '', this.sceneKey = '', this.imageUrl = ''});
  final String textAr;
  final String textEn;
  /// اسم رسمة جاهزة داخل الأبلكيشن (مثل s1) إن لم توجد صورة مرفوعة.
  final String sceneKey;
  final String imageUrl;

  bool get isEmpty => textAr.trim().isEmpty && imageUrl.isEmpty;
  String text(bool ar) => ar || textEn.isEmpty ? textAr : textEn;

  factory Story.fromJson(Json j) => Story(textAr: _s(j['textAr']), textEn: _s(j['textEn']), sceneKey: _s(j['sceneKey']), imageUrl: _s(j['imageUrl']));
  Json toJson() => {'textAr': textAr, 'textEn': textEn, 'sceneKey': sceneKey, 'imageUrl': imageUrl};
}

class Hadith {
  Hadith({
    required this.id,
    required this.tabId,
    this.levelId,
    this.order = 0,
    this.titleAr = '',
    this.titleEn = '',
    this.text = '',
    this.translationEn = '',
    this.narratorAr = '',
    this.narratorGenAr = '',
    this.narratorEn = '',
    this.narratorFactAr = '',
    this.narratorFactEn = '',
    this.sourceAr = '',
    this.sourceEn = '',
    this.sourceFactAr = '',
    this.sourceFactEn = '',
    this.isnadInText = false,
    this.explainAr = '',
    this.explainEn = '',
    this.story,
    GameData? game,
    this.missionAr = '',
    this.missionEn = '',
    this.audioUrl = '',
    this.published = false,
  }) : game = game ?? GameData();

  final String id;
  final String tabId;
  final String? levelId;
  final int order;
  final String titleAr;
  final String titleEn;
  final String text;
  final String translationEn;
  final String narratorAr;
  final String narratorGenAr;
  final String narratorEn;
  final String narratorFactAr;
  final String narratorFactEn;
  final String sourceAr;
  final String sourceEn;
  final String sourceFactAr;
  final String sourceFactEn;
  /// true إذا كان السند مكتوبًا داخل النص (مثل الأربعين النووية).
  final bool isnadInText;
  final String explainAr;
  final String explainEn;
  final Story? story;
  final GameData game;
  final String missionAr;
  final String missionEn;
  final String audioUrl;
  final bool published;

  String title(bool ar) => ar || titleEn.isEmpty ? titleAr : titleEn;
  String explain(bool ar) => ar || explainEn.isEmpty ? explainAr : explainEn;
  String mission(bool ar) => ar || missionEn.isEmpty ? missionAr : missionEn;
  bool get hasStory => story != null && !story!.isEmpty;

  /// نص جاهز للنسخ والمشاركة.
  String shareText(bool ar) {
    if (isnadInText) return '$text${sourceAr.isNotEmpty ? '\n$sourceAr' : ''}';
    final ref = ar
        ? (narratorGenAr.isNotEmpty ? 'عن $narratorGenAr رضي الله عنه · $sourceAr' : sourceAr)
        : (narratorEn.isNotEmpty ? 'Narrated by $narratorEn · $sourceEn' : sourceEn);
    return 'قال رسول الله ﷺ: «$text»\n$ref';
  }

  factory Hadith.fromJson(String id, Json j) => Hadith(
        id: id,
        tabId: _s(j['tabId']),
        levelId: j['levelId'] == null || _s(j['levelId']).isEmpty ? null : _s(j['levelId']),
        order: _i(j['order']),
        titleAr: _s(j['titleAr']),
        titleEn: _s(j['titleEn']),
        text: _s(j['text']),
        translationEn: _s(j['translationEn']),
        narratorAr: _s(j['narratorAr']),
        narratorGenAr: _s(j['narratorGenAr']),
        narratorEn: _s(j['narratorEn']),
        narratorFactAr: _s(j['narratorFactAr']),
        narratorFactEn: _s(j['narratorFactEn']),
        sourceAr: _s(j['sourceAr']),
        sourceEn: _s(j['sourceEn']),
        sourceFactAr: _s(j['sourceFactAr']),
        sourceFactEn: _s(j['sourceFactEn']),
        isnadInText: _b(j['isnadInText']),
        explainAr: _s(j['explainAr']),
        explainEn: _s(j['explainEn']),
        story: j['story'] is Map ? Story.fromJson(Map<String, dynamic>.from(j['story'] as Map)) : null,
        game: GameData.fromJson(j['game'] is Map ? Map<String, dynamic>.from(j['game'] as Map) : null),
        missionAr: _s(j['missionAr']),
        missionEn: _s(j['missionEn']),
        audioUrl: _s(j['audioUrl']),
        published: _b(j['published']),
      );

  factory Hadith.fromDoc(DocumentSnapshot<Json> d) => Hadith.fromJson(d.id, d.data() ?? {});

  Json toJson() => {
        'tabId': tabId,
        'levelId': levelId,
        'order': order,
        'titleAr': titleAr,
        'titleEn': titleEn,
        'text': text,
        'translationEn': translationEn,
        'narratorAr': narratorAr,
        'narratorGenAr': narratorGenAr,
        'narratorEn': narratorEn,
        'narratorFactAr': narratorFactAr,
        'narratorFactEn': narratorFactEn,
        'sourceAr': sourceAr,
        'sourceEn': sourceEn,
        'sourceFactAr': sourceFactAr,
        'sourceFactEn': sourceFactEn,
        'isnadInText': isnadInText,
        'explainAr': explainAr,
        'explainEn': explainEn,
        'story': story?.toJson(),
        'game': game.toJson(),
        'missionAr': missionAr,
        'missionEn': missionEn,
        'audioUrl': audioUrl,
        'published': published,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

class QaItem {
  QaItem({required this.q, required this.a, this.order = 0});
  final String q;
  final String a;
  final int order;
  factory QaItem.fromJson(Json j) => QaItem(q: _s(j['q']), a: _s(j['a']), order: _i(j['order']));
  Json toJson() => {'q': q, 'a': a, 'order': order};
}

/// قسم في تبويب أسئلة وأجوبة (مثل "الأصول الثلاثة").
class QaSection {
  QaSection({required this.id, required this.tabId, required this.titleAr, this.titleEn = '', this.color = '#0E7C74', this.order = 0, this.videoScene = '', this.audioUrl = '', this.items = const []});
  final String id;
  final String tabId;
  final String titleAr;
  final String titleEn;
  final String color;
  final int order;
  final String videoScene;
  final String audioUrl;
  final List<QaItem> items;

  String title(bool ar) => ar || titleEn.isEmpty ? titleAr : titleEn;

  factory QaSection.fromJson(String id, Json j) => QaSection(
        id: id,
        tabId: _s(j['tabId']),
        titleAr: _s(j['titleAr']),
        titleEn: _s(j['titleEn']),
        color: _s(j['color']).isEmpty ? '#0E7C74' : _s(j['color']),
        order: _i(j['order']),
        videoScene: _s(j['videoScene']),
        audioUrl: _s(j['audioUrl']),
        items: (((j['items'] as List?) ?? const []).map((e) => QaItem.fromJson(Map<String, dynamic>.from(e as Map))).toList())..sort((a, b) => a.order.compareTo(b.order)),
      );

  factory QaSection.fromDoc(DocumentSnapshot<Json> d) => QaSection.fromJson(d.id, d.data() ?? {});

  Json toJson() => {
        'tabId': tabId,
        'titleAr': titleAr,
        'titleEn': titleEn,
        'color': color,
        'order': order,
        'videoScene': videoScene,
        'audioUrl': audioUrl,
        'items': [for (var i = 0; i < items.length; i++) QaItem(q: items[i].q, a: items[i].a, order: i + 1).toJson()],
      };

  QaSection copyWith({String? titleAr, String? titleEn, String? color, int? order, String? audioUrl, List<QaItem>? items}) => QaSection(
        id: id,
        tabId: tabId,
        titleAr: titleAr ?? this.titleAr,
        titleEn: titleEn ?? this.titleEn,
        color: color ?? this.color,
        order: order ?? this.order,
        videoScene: videoScene,
        audioUrl: audioUrl ?? this.audioUrl,
        items: items ?? this.items,
      );
}

class RoyalRule {
  const RoyalRule({this.on = true, this.n = 1});
  final bool on;
  final int n;
  factory RoyalRule.fromJson(Json? j, {int n = 1}) => RoyalRule(on: _b(j?['on'], true), n: _i(j?['n'], n));
  Json toJson() => {'on': on, 'n': n};
}

/// إعدادات النجوم العادية والملكية ومستويات فانوس.
class RewardsConfig {
  const RewardsConfig({
    this.perGame = 1,
    this.perKnow = 1,
    this.level = const RoyalRule(),
    this.openTabs = const RoyalRule(n: 10),
    this.section = const RoyalRule(),
    this.mission = const RoyalRule(),
    this.tree = const RoyalRule(n: 3),
    this.fanoosLevels = const [0, 3, 6, 10, 16],
  });
  final int perGame;
  final int perKnow;
  final RoyalRule level;
  /// نجمة ملكية لكل n أحاديث من التبويبات المفتوحة (مثل النووية).
  final RoyalRule openTabs;
  final RoyalRule section;
  final RoyalRule mission;
  /// شجرة مثمرة بعد n مراجعات.
  final RoyalRule tree;
  final List<int> fanoosLevels;

  factory RewardsConfig.fromJson(Json? j) {
    final royal = j?['royal'] is Map ? Map<String, dynamic>.from(j!['royal'] as Map) : <String, dynamic>{};
    Json? m(String k) => royal[k] is Map ? Map<String, dynamic>.from(royal[k] as Map) : null;
    return RewardsConfig(
      perGame: _i(j?['perGame'], 1),
      perKnow: _i(j?['perKnow'], 1),
      level: RoyalRule.fromJson(m('level')),
      openTabs: RoyalRule.fromJson(m('nawawi'), n: 10),
      section: RoyalRule.fromJson(m('section')),
      mission: RoyalRule.fromJson(m('mission')),
      tree: RoyalRule.fromJson(m('tree'), n: 3),
      fanoosLevels: ((j?['fanoosLevels'] as List?) ?? const [0, 3, 6, 10, 16]).map((e) => _i(e)).toList(),
    );
  }

  Json toJson() => {
        'perGame': perGame,
        'perKnow': perKnow,
        'royal': {'level': level.toJson(), 'nawawi': openTabs.toJson(), 'section': section.toJson(), 'mission': mission.toJson(), 'tree': tree.toJson()},
        'fanoosLevels': fanoosLevels,
      };

  RewardsConfig copyWith({int? perGame, int? perKnow, RoyalRule? level, RoyalRule? openTabs, RoyalRule? section, RoyalRule? mission, RoyalRule? tree, List<int>? fanoosLevels}) => RewardsConfig(
        perGame: perGame ?? this.perGame,
        perKnow: perKnow ?? this.perKnow,
        level: level ?? this.level,
        openTabs: openTabs ?? this.openTabs,
        section: section ?? this.section,
        mission: mission ?? this.mission,
        tree: tree ?? this.tree,
        fanoosLevels: fanoosLevels ?? this.fanoosLevels,
      );
}

/// عنصر في متجر فانوس (لون أو زينة).
class ShopItem {
  const ShopItem({required this.id, required this.nameAr, this.nameEn = '', this.hex = '#F5B82E', this.kind = 'color', this.currency = 'normal', this.price = 0});
  final String id;
  final String nameAr;
  final String nameEn;
  final String hex;
  /// 'color' أو 'accessory'
  final String kind;
  /// 'normal' أو 'royal'
  final String currency;
  final int price;

  bool get isRoyal => currency == 'royal';
  String name(bool ar) => ar || nameEn.isEmpty ? nameAr : nameEn;

  factory ShopItem.fromJson(Json j) => ShopItem(
        id: _s(j['id']),
        nameAr: _s(j['nameAr']),
        nameEn: _s(j['nameEn']),
        hex: _s(j['hex']).isEmpty ? '#F5B82E' : _s(j['hex']),
        kind: _s(j['kind']).isEmpty ? 'color' : _s(j['kind']),
        currency: _s(j['currency']).isEmpty ? 'normal' : _s(j['currency']),
        price: _i(j['price']),
      );

  Json toJson() => {'id': id, 'nameAr': nameAr, 'nameEn': nameEn, 'hex': hex, 'kind': kind, 'currency': currency, 'price': price};

  ShopItem copyWith({String? currency, int? price}) => ShopItem(id: id, nameAr: nameAr, nameEn: nameEn, hex: hex, kind: kind, currency: currency ?? this.currency, price: price ?? this.price);
}

class AppConfig {
  const AppConfig({this.rewards = const RewardsConfig(), this.shop = AppConfig.defaultShop});
  final RewardsConfig rewards;
  final List<ShopItem> shop;

  static const defaultShop = <ShopItem>[
    ShopItem(id: 'gold', nameAr: 'ذهبي', nameEn: 'Gold', hex: '#F5B82E'),
    ShopItem(id: 'mint', nameAr: 'نعناعي', nameEn: 'Mint', hex: '#3CC7A8', price: 3),
    ShopItem(id: 'crown', nameAr: 'تاج', nameEn: 'Crown', hex: '#FFD95A', kind: 'accessory', currency: 'royal', price: 2),
  ];

  factory AppConfig.fromJson(Json? j) => AppConfig(
        rewards: RewardsConfig.fromJson(j?['rewards'] is Map ? Map<String, dynamic>.from(j!['rewards'] as Map) : null),
        shop: j?['shop'] is List ? (j!['shop'] as List).map((e) => ShopItem.fromJson(Map<String, dynamic>.from(e as Map))).toList() : defaultShop,
      );

  Json toJson() => {'rewards': rewards.toJson(), 'shop': shop.map((e) => e.toJson()).toList()};
}

/// صف في لوحة الشرف. لا يحتوي صورًا ولا مواقع دقيقة.
class LeaderEntry {
  LeaderEntry({required this.uid, required this.nickname, required this.avatar, required this.city, this.area = '', this.stars = 0, this.royal = 0});
  final String uid;
  final String nickname;
  final String avatar;
  final int city;
  final String area;
  final int stars;
  final int royal;

  int get score => royal * 5 + stars;

  factory LeaderEntry.fromDoc(DocumentSnapshot<Json> d) {
    final j = d.data() ?? {};
    return LeaderEntry(uid: d.id, nickname: _s(j['nickname']), avatar: _s(j['avatar']), city: _i(j['city'], -1), area: _s(j['area']), stars: _i(j['stars']), royal: _i(j['royal']));
  }

  Json toJson() => {'nickname': nickname, 'avatar': avatar, 'city': city, 'area': area, 'stars': stars, 'royal': royal, 'score': score, 'updatedAt': FieldValue.serverTimestamp()};
}

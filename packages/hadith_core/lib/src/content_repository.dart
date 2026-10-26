import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';

/// كل القراءة والكتابة من Firestore في مكان واحد.
///
/// الهيكل:
///   config/app        إعدادات الجوائز ومتجر فانوس
///   tabs/{id}         التبويبات
///   levels/{id}       المستويات (tabId)
///   hadiths/{id}      الأحاديث (tabId, levelId)
///   qaSections/{id}   أقسام الأسئلة والأجوبة (tabId, items[])
///   leaderboard/{uid} لوحة الشرف
///   admins/{uid}      قائمة المديرين (تُضاف يدويًا من الكونسول)
class ContentRepository {
  ContentRepository(this.db);
  final FirebaseFirestore db;

  CollectionReference<Json> get _tabs => db.collection('tabs');
  CollectionReference<Json> get _levels => db.collection('levels');
  CollectionReference<Json> get _hadiths => db.collection('hadiths');
  CollectionReference<Json> get _qa => db.collection('qaSections');
  CollectionReference<Json> get _leaders => db.collection('leaderboard');
  DocumentReference<Json> get _config => db.collection('config').doc('app');

  // ---------------- قراءة ----------------

  Stream<List<AppTab>> tabs({bool onlyVisible = false}) => _tabs.snapshots().map((s) {
        final list = s.docs.map(AppTab.fromDoc).where((t) => !onlyVisible || t.visible).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });

  Stream<List<Level>> levels(String tabId) => _levels.where('tabId', isEqualTo: tabId).snapshots().map((s) {
        final list = s.docs.map(Level.fromDoc).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });

  Stream<List<Level>> allLevels() => _levels.snapshots().map((s) {
        final list = s.docs.map(Level.fromDoc).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });

  /// للأطفال: المنشور فقط. للمدير: كل شيء (onlyPublished: false).
  Stream<List<Hadith>> hadiths(String tabId, {String? levelId, bool onlyPublished = true}) {
    Query<Json> q = _hadiths.where('tabId', isEqualTo: tabId);
    if (onlyPublished) q = q.where('published', isEqualTo: true);
    return q.snapshots().map((s) {
      final list = s.docs.map(Hadith.fromDoc).where((h) => levelId == null || h.levelId == levelId).toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  Stream<List<Hadith>> allHadiths({bool onlyPublished = true}) {
    Query<Json> q = _hadiths;
    if (onlyPublished) q = q.where('published', isEqualTo: true);
    return q.snapshots().map((s) => s.docs.map(Hadith.fromDoc).toList());
  }

  Stream<List<QaSection>> qaSections(String tabId) => _qa.where('tabId', isEqualTo: tabId).snapshots().map((s) {
        final list = s.docs.map(QaSection.fromDoc).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });

  Stream<AppConfig> config() => _config.snapshots().map((d) => AppConfig.fromJson(d.data()));

  // ---------------- كتابة (للمدير) ----------------

  String newId(String collection) => db.collection(collection).doc().id;

  Future<void> saveTab(AppTab t) => _tabs.doc(t.id).set(t.toJson());

  /// يحذف التبويب وكل محتواه.
  Future<void> deleteTab(String tabId) async {
    final batch = db.batch();
    for (final c in [_levels, _hadiths, _qa]) {
      final docs = await c.where('tabId', isEqualTo: tabId).get();
      for (final d in docs.docs) {
        batch.delete(d.reference);
      }
    }
    batch.delete(_tabs.doc(tabId));
    await batch.commit();
  }

  Future<void> saveLevel(Level l) => _levels.doc(l.id).set(l.toJson());
  Future<void> deleteLevel(String id) => _levels.doc(id).delete();

  Future<void> saveHadith(Hadith h) => _hadiths.doc(h.id).set(h.toJson());
  Future<void> deleteHadith(String id) => _hadiths.doc(id).delete();
  Future<void> setPublished(String id, bool v) => _hadiths.doc(id).update({'published': v, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> saveQaSection(QaSection s) => _qa.doc(s.id).set(s.toJson());
  Future<void> deleteQaSection(String id) => _qa.doc(id).delete();

  Future<void> saveConfig(AppConfig c) => _config.set(c.toJson());

  /// يعيد ترقيم ترتيب مجموعة مستندات بعد السحب أو الأسهم.
  Future<void> reorder(String collection, List<String> idsInOrder) async {
    final batch = db.batch();
    for (var i = 0; i < idsInOrder.length; i++) {
      batch.update(db.collection(collection).doc(idsInOrder[i]), {'order': i + 1});
    }
    await batch.commit();
  }

  Future<bool> isAdmin(String uid) async => (await db.collection('admins').doc(uid).get()).exists;

  // ---------------- لوحة الشرف ----------------

  Future<void> upsertLeader(LeaderEntry e) => _leaders.doc(e.uid).set(e.toJson());
  Future<void> removeLeader(String uid) => _leaders.doc(uid).delete();

  /// city = null يعني كل البلد.
  Stream<List<LeaderEntry>> leaderboard({int? city, String? area, int limit = 50}) {
    Query<Json> q = _leaders;
    if (city != null) q = q.where('city', isEqualTo: city);
    if (city != null && area != null && area.isNotEmpty) q = q.where('area', isEqualTo: area);
    q = q.orderBy('score', descending: true).limit(limit);
    return q.snapshots().map((s) => s.docs.map(LeaderEntry.fromDoc).toList());
  }
}

import 'dart:math' as math;

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
    // الفلترة بالمستوى على السيرفر: تبويب زي البخاري فيه آلاف الأحاديث.
    if (levelId != null) q = q.where('levelId', isEqualTo: levelId);
    if (onlyPublished) q = q.where('published', isEqualTo: true);
    return q.snapshots().map((s) {
      final list = s.docs.map(Hadith.fromDoc).toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    });
  }

  /// أحاديث معينة بالـ id (للحديقة والمهمات) من غير ما نحمّل كل الأحاديث.
  Future<List<Hadith>> hadithsByIds(Iterable<String> ids) async {
    final list = ids.toSet().toList();
    final out = <Hadith>[];
    // Firestore بيسمح بـ 30 قيمة في whereIn
    for (var i = 0; i < list.length; i += 30) {
      final s = await _hadiths.where(FieldPath.documentId, whereIn: list.sublist(i, (i + 30).clamp(0, list.length))).where('published', isEqualTo: true).get();
      out.addAll(s.docs.map(Hadith.fromDoc));
    }
    return out;
  }

  /// دروس سن معينة في تبويب بالسنين (البخاري).
  Stream<List<Level>> levelsForAge(String tabId, int age) => _levels.where('tabId', isEqualTo: tabId).where('ageYear', isEqualTo: age).snapshots().map((s) {
        final list = s.docs.map(Level.fromDoc).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });

  /// أحاديث سن معينة. للأطفال (اختبار تحديد المستوى) بحد أقصى، وللمدير كلها.
  Future<List<Hadith>> hadithsForAge(String tabId, int age, {bool onlyPublished = true, int? limit}) async {
    Query<Json> q = _hadiths.where('tabId', isEqualTo: tabId).where('ageYear', isEqualTo: age);
    if (onlyPublished) q = q.where('published', isEqualTo: true);
    if (limit != null) q = q.limit(limit);
    final s = await q.get();
    final list = s.docs.map(Hadith.fromDoc).toList()..sort((a, b) => a.bukhariNo.compareTo(b.bukhariNo));
    return list;
  }

  /// عدد المستندات (من غير ما نحمّلها).
  Future<int> countHadiths({bool? published, String? tabId, String? status}) async {
    Query<Json> q = _hadiths;
    if (tabId != null) q = q.where('tabId', isEqualTo: tabId);
    if (published != null) q = q.where('published', isEqualTo: published);
    if (status != null) q = q.where('status', isEqualTo: status);
    return (await q.count().get()).count ?? 0;
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

  /// مراجعة حديث بخاري: يغيّر حالته ونشره مع بعض.
  Future<void> setReview(String id, {required String status, required bool published}) =>
      _hadiths.doc(id).update({'status': status, 'published': published, 'updatedAt': FieldValue.serverTimestamp()});

  /// ينقل حديث بخاري لسن تانية: يدخل آخر درس فيها (أو درس جديد لو الأخير اتملا).
  Future<void> moveHadithToAge(Hadith h, int age, {int lessonSize = 10}) async {
    final levels = (await _levels.where('tabId', isEqualTo: h.tabId).where('ageYear', isEqualTo: age).get()).docs.map(Level.fromDoc).toList()..sort((a, b) => a.order.compareTo(b.order));
    final batch = db.batch();
    if (h.levelId != null) batch.update(_levels.doc(h.levelId), {'hadithIds': FieldValue.arrayRemove([h.id])});
    Level target;
    if (levels.isNotEmpty && levels.last.hadithIds.length < lessonSize) {
      target = levels.last;
      batch.update(_levels.doc(target.id), {'hadithIds': FieldValue.arrayUnion([h.id])});
    } else {
      final unit = levels.length + 1;
      target = Level(
        id: '${h.tabId}_a${age.toString().padLeft(2, '0')}_u${unit.toString().padLeft(3, '0')}_${DateTime.now().millisecondsSinceEpoch}',
        tabId: h.tabId,
        nameAr: 'الدرس ${'$unit'.split('').map((d) => '٠١٢٣٤٥٦٧٨٩'[int.parse(d)]).join()}',
        nameEn: 'Lesson $unit',
        color: '#9B7BEA',
        order: age * 1000 + unit,
        ageYear: age,
        hadithIds: [h.id],
      );
      batch.set(_levels.doc(target.id), target.toJson());
    }
    batch.update(_hadiths.doc(h.id), {'ageYear': age, 'levelId': target.id, 'order': target.hadithIds.length + 1, 'updatedAt': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  /// كتابة كتير مرة واحدة (استيراد): Firestore بيسمح بـ 500 عملية في الدفعة.
  Future<void> writeAll(String collection, List<Json> docs, {void Function(int done)? onProgress}) async {
    for (var i = 0; i < docs.length; i += 400) {
      final batch = db.batch();
      for (final d in docs.skip(i).take(400)) {
        final m = Map<String, dynamic>.from(d);
        final id = m.remove('id') as String;
        batch.set(db.collection(collection).doc(id), m);
      }
      await batch.commit();
      onProgress?.call(math.min(i + 400, docs.length));
    }
  }

  /// الـ ids الموجودة بالفعل في تبويب (عشان الاستيراد ما يكتبش فوق تعديلات المدير).
  Future<Set<String>> existingIds(String collection, String tabId) async =>
      (await db.collection(collection).where('tabId', isEqualTo: tabId).get()).docs.map((d) => d.id).toSet();

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

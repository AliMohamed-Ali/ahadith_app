import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:hadith_core/hadith_core.dart';

/// قسم المستويات = 5 مستويات آداب بس: كل مستوى خريطة جبال، وكل جبل قسم بنهر أحاديثه.
/// الداتا في assets/adab_levels.json (متجهزة بـ tools/levels/build_adab_levels.py من tools/levels/adab_kids.txt).
/// الاستيراد بينضّف القسم: أي مستوى أو حديث تاني فيه بيتمسح.
class AdabService {
  AdabService(this.repo);
  final ContentRepository repo;
  static const tabId = 'levels';

  Future<Map<String, dynamic>> load() async => jsonDecode(await rootBundle.loadString('assets/adab_levels.json')) as Map<String, dynamic>;

  /// اللي هيتمسح (عشان يظهر للمدير قبل ما يأكد).
  Future<({int levels, int hadiths})> leftovers(Map<String, dynamic> j) async {
    final keepLevels = _ids(j, 'parents')..addAll(_ids(j, 'levels'));
    final keepHadiths = _ids(j, 'hadiths');
    final levels = (await repo.existingIds('levels', tabId)).difference(keepLevels);
    final hadiths = (await repo.existingIds('hadiths', tabId)).difference(keepHadiths);
    return (levels: levels.length, hadiths: hadiths.length);
  }

  Set<String> _ids(Map<String, dynamic> j, String key) => (j[key] as List).map((e) => (e as Map)['id'] as String).toSet();

  /// overwrite = false: الأحاديث اللي المدير عدّلها قبل كده بتفضل زي ما هي (بس بتتنقل لمكانها).
  Future<void> import(Map<String, dynamic> j, {bool overwrite = false}) async {
    final haveLevels = await repo.existingIds('levels', tabId);
    final haveHadiths = await repo.existingIds('hadiths', tabId);
    final levels = [...(j['parents'] as List), ...(j['levels'] as List)].map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final hadiths = (j['hadiths'] as List).map((e) => {...Map<String, dynamic>.from(e as Map), 'published': true, 'updatedAt': FieldValue.serverTimestamp()}).toList();

    // المستويات والجبال دايمًا بتتكتب (عشان الترتيب والتقسيم يبقوا زي الملف)
    await repo.writeAll('levels', levels);
    await repo.writeAll('hadiths', hadiths.where((h) => overwrite || !haveHadiths.contains(h['id'])).toList());

    // الأحاديث اللي كانت موجودة ومن غير مهمة: بنضيفلها المهمة بس (من غير ما نلمس باقي تعديلات المدير)
    if (!overwrite) {
      final current = {for (final d in (await repo.db.collection('hadiths').where('tabId', isEqualTo: tabId).get()).docs) d.id: d.data()};
      final missing = hadiths.where((h) => current.containsKey(h['id']) && '${current[h['id']]!['missionAr'] ?? ''}'.trim().isEmpty && '${h['missionAr'] ?? ''}'.isNotEmpty).toList();
      for (var i = 0; i < missing.length; i += 400) {
        final batch = repo.db.batch();
        for (final h in missing.skip(i).take(400)) {
          batch.update(repo.db.collection('hadiths').doc(h['id'] as String), {'missionAr': h['missionAr']});
        }
        await batch.commit();
      }
    }

    // تنضيف: أي مستوى أو حديث قديم في قسم المستويات مش من الآداب بيتمسح
    final keepLevels = levels.map((l) => l['id'] as String).toSet();
    final keepHadiths = hadiths.map((h) => h['id'] as String).toSet();
    final gone = [
      ...haveLevels.difference(keepLevels).map((id) => repo.db.collection('levels').doc(id)),
      ...haveHadiths.difference(keepHadiths).map((id) => repo.db.collection('hadiths').doc(id)),
    ];
    for (var i = 0; i < gone.length; i += 400) {
      final batch = repo.db.batch();
      for (final d in gone.skip(i).take(400)) {
        batch.delete(d);
      }
      await batch.commit();
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// عشان الأبلكيشن يشتغل من غير نت: لما يكون فيه نت بنحمّل المحتوى الأساسي مرة في اليوم
/// (التبويبات، المستويات، الأحاديث، الأسئلة، والإعدادات) فيتحفظ في كاش Firestore على الموبايل.
/// البخاري كبير، فبنحمّل بس أحاديث سن الطفل.
class OfflineCache {
  static const _key = 'offline-warm-at';
  static const _every = Duration(hours: 24);

  static Future<void> warm(FirebaseFirestore db, {int? bukhariYear}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = DateTime.fromMillisecondsSinceEpoch(prefs.getInt(_key) ?? 0);
      if (DateTime.now().difference(last) < _every) return;
      // من السيرفر بس: لو مفيش نت بتفشل بسرعة ومش بنعلّم إن التحميل خلص
      const server = GetOptions(source: Source.server);
      final tabs = await db.collection('tabs').get(server);
      await db.collection('config').get(server);
      await db.collection('levels').get(server);
      await db.collection('qaSections').get(server);
      final small = tabs.docs.where((t) => t.data()['mode'] != 'ages').map((t) => t.id).toList();
      for (var i = 0; i < small.length; i += 10) {
        await db.collection('hadiths').where('tabId', whereIn: small.sublist(i, (i + 10).clamp(0, small.length))).where('published', isEqualTo: true).get(server);
      }
      if (bukhariYear != null) {
        await db.collection('hadiths').where('tabId', isEqualTo: 'bukhari').where('ageYear', isEqualTo: bukhariYear).where('published', isEqualTo: true).get(server);
      }
      await prefs.setInt(_key, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('offline warm skipped: $e');
    }
  }
}

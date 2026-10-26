import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

/// يستورد المحتوى الأولي (المستويات + الأربعون النووية كاملة + ما لا يسع أطفال المسلمين جهله + الإعدادات)
/// من ملف assets/seed_content.json إلى Firestore. يُستخدم مرة واحدة في البداية.
class SeedService {
  SeedService(this.db);
  final FirebaseFirestore db;

  Future<Map<String, int>> import({bool overwrite = false}) async {
    final raw = await rootBundle.loadString('assets/seed_content.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final writes = <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[];
    final counts = <String, int>{};

    void add(String col, List list) {
      for (final e in list) {
        final m = Map<String, dynamic>.from(e as Map);
        final id = m.remove('id') as String;
        writes.add((db.collection(col).doc(id), m));
      }
      counts[col] = list.length;
    }

    writes.add((db.collection('config').doc('app'), Map<String, dynamic>.from(j['config'] as Map)));
    add('tabs', j['tabs'] as List);
    add('levels', j['levels'] as List);
    add('hadiths', (j['hadiths'] as List).map((e) => {...Map<String, dynamic>.from(e as Map), 'published': true, 'updatedAt': FieldValue.serverTimestamp()}).toList());
    add('qaSections', j['qaSections'] as List);

    // لو مش عايزين نكتب فوق التعديلات: نتخطى المستندات الموجودة.
    final toWrite = <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[];
    if (overwrite) {
      toWrite.addAll(writes);
    } else {
      for (final w in writes) {
        if (!(await w.$1.get()).exists) toWrite.add(w);
      }
    }

    // Firestore يسمح بـ 500 عملية في الدفعة الواحدة.
    for (var i = 0; i < toWrite.length; i += 400) {
      final batch = db.batch();
      for (final w in toWrite.skip(i).take(400)) {
        batch.set(w.$1, w.$2);
      }
      await batch.commit();
    }
    counts['written'] = toWrite.length;
    return counts;
  }
}

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/progress_store.dart';
import '../widgets/common.dart';
import '../widgets/parent_gate.dart';
import '../theme.dart';

/// مهمات الحياة الحقيقية: الطفل يعمل المهمة، والأهل يأكدوا ببوابة الكبار.
class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});
  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  // بنحمّل بس الأحاديث اللي الطفل لعبها (مش كل الأحاديث، البخاري لوحده آلاف).
  Future<List<Hadith>>? _future;
  String _key = '';
  Future<List<Hadith>> _byIds(Iterable<String> ids) {
    final k = (ids.toList()..sort()).join(',');
    if (_future == null || k != _key) {
      _key = k;
      _future = context.read<ContentRepository>().hadithsByIds(ids);
    }
    return _future!;
  }

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final p = context.watch<ProgressStore>();
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context, 'missions')), backgroundColor: AppColors.coral),
      body: FutureBuilder<List<Hadith>>(
        future: _byIds(p.missions.keys),
        builder: (context, snap) {
          final byId = {for (final h in snap.data ?? const <Hadith>[]) h.id: h};
          final entries = p.missions.entries.where((e) => byId.containsKey(e.key)).toList()
            ..sort((a, b) => a.value == b.value ? 0 : (a.value == 'pending' ? -1 : 1));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (entries.isEmpty) {
            return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(S.of(context, 'noMissions'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 19))));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final h = byId[entries[i].key]!;
              final done = entries[i].value == 'done';
              return RiseIn(
                delay: i * 50,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: cardBox(color: done ? const Color(0xFFE6F7EC) : Colors.white),
                  child: Row(children: [
                    Icon(done ? Icons.check_circle_rounded : Icons.flag_rounded, color: done ? AppColors.teal : AppColors.coral, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(h.title(ar), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.muted)),
                        Text(h.mission(ar), style: const TextStyle(fontSize: 18)),
                      ]),
                    ),
                    if (!done)
                      FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(48, 44)),
                        onPressed: () async {
                          final ok = await showParentGate(context, body: S.of(context, 'gateMission'));
                          if (ok) p.completeMission(h.id);
                        },
                        child: Text(S.of(context, 'iDidIt')),
                      ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

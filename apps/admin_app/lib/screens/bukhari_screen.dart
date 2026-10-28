import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../ui.dart';
import 'hadith_edit_screen.dart';

const _tabId = 'bukhari';
const _ages = [4, 5, 6, 7, 8, 9, 10, 11, 12];
final _tab = AppTab(id: _tabId, nameAr: 'صحيح البخاري', nameEn: 'Sahih al-Bukhari', mode: 'ages', color: '#7558D6');

const _statusName = {'auto': 'اتقسم تلقائي', 'review': 'محتاج مراجعة', 'ok': 'اتراجع ✓', 'hidden': 'مش مناسب'};
const _statusColor = {'auto': AppColors.muted, 'review': Color(0xFFE08A00), 'ok': AppColors.teal, 'hidden': AppColors.danger};

/// صحيح البخاري: استيراد، ومراجعة كل سن، ونشر، ونقل حديث من سن لسن.
class BukhariAdminScreen extends StatefulWidget {
  const BukhariAdminScreen({super.key});
  @override
  State<BukhariAdminScreen> createState() => _BukhariAdminScreenState();
}

class _BukhariAdminScreenState extends State<BukhariAdminScreen> {
  late final repo = context.read<ContentRepository>();
  late final Stream<List<AppTab>> _tabs = repo.tabs();
  int _age = 4;
  String _filter = 'all';
  String _search = '';
  late Future<List<Hadith>> _list;
  late Future<List<int>> _counts;
  String? _progress;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _list = repo.hadithsForAge(_tabId, _age, onlyPublished: false);
      _counts = Future.wait([
        repo.countHadiths(tabId: _tabId),
        repo.countHadiths(tabId: _tabId, published: true),
        repo.countHadiths(tabId: _tabId, status: 'review'),
      ]);
    });
  }

  Future<void> _import() async {
    final Map<String, dynamic> j = await compute(_decode, await rootBundle.loadString('assets/bukhari_kids.json'));
    if (!mounted) return;
    final stats = Map<String, dynamic>.from(j['stats'] as Map);
    final hadiths = (j['hadiths'] as List).cast<Map>();
    final review = hadiths.where((h) => h['status'] == 'review').length;
    final publishAuto = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('استيراد صحيح البخاري'),
        content: SingleChildScrollView(
          child: Text(
            'المصدر: ${j['source']}\n\n'
            '${hadiths.length} حديث من غير تكرار، متقسمين على ${stats.length} سنين:\n'
            '${stats.entries.map((e) => '• سن ${e.key}: ${e.value['hadiths']} حديث (${e.value['lessons']} درس)').join('\n')}\n\n'
            '$review حديث محتاجين مراجعة، ودول عمرهم ما هيتنشروا تلقائي.\n\n'
            'الأحاديث اللي موجودة قبل كده مش هيتكتب فوقها.\n\n'
            'تنشري الباقي على طول ولا يفضل مسودة لحد ما تراجعيه؟',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')),
          OutlinedButton(onPressed: () => Navigator.pop(c, false), child: const Text('مسودة (أراجع الأول)')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('انشري المناسب')),
        ],
      ),
    );
    if (publishAuto == null || !mounted) return;
    await run(context, () async {
      setState(() => _progress = 'بجهّز…');
      final haveLevels = await repo.existingIds('levels', _tabId);
      final haveHadiths = await repo.existingIds('hadiths', _tabId);
      await repo.saveTab(AppTab.fromJson(_tabId, Map<String, dynamic>.from(j['tab'] as Map)));
      final levels = (j['levels'] as List).cast<Map>().where((l) => !haveLevels.contains(l['id'])).map((l) => Map<String, dynamic>.from(l)).toList();
      await repo.writeAll('levels', levels, onProgress: (n) => setState(() => _progress = 'الدروس: $n / ${levels.length}'));
      final docs = hadiths.where((h) => !haveHadiths.contains(h['id'])).map((h) {
        final m = Map<String, dynamic>.from(h);
        m['published'] = publishAuto && m['status'] == 'auto';
        m['updatedAt'] = FieldValue.serverTimestamp();
        return m;
      }).toList();
      await repo.writeAll('hadiths', docs, onProgress: (n) => setState(() => _progress = 'الأحاديث: $n / ${docs.length}'));
    }, done: 'اتستورد ✓');
    if (mounted) setState(() => _progress = null);
    _reload();
  }

  Future<void> _publishAll(List<Hadith> list) async {
    final ids = list.where((h) => h.status == 'auto' && !h.published).map((h) => h.id).toList();
    if (ids.isEmpty) {
      toast(context, 'مفيش أحاديث مستنية نشر في السن ده');
      return;
    }
    if (!await confirm(context, 'نشر سن $_age', 'هيتنشر ${ids.length} حديث اتقسموا تلقائي. اللي محتاجين مراجعة مش هيتنشروا.', ok: 'انشري')) return;
    if (!mounted) return;
    await run(context, () async {
      for (var i = 0; i < ids.length; i += 400) {
        final batch = repo.db.batch();
        for (final id in ids.skip(i).take(400)) {
          batch.update(repo.db.collection('hadiths').doc(id), {'published': true, 'updatedAt': FieldValue.serverTimestamp()});
        }
        await batch.commit();
      }
    }, done: 'اتنشر ✓');
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('صحيح البخاري'), actions: [
          IconButton(tooltip: 'استيراد', onPressed: _progress == null ? _import : null, icon: const Icon(Icons.cloud_download_rounded)),
        ]),
        body: Column(children: [
          if (_progress != null) ...[const LinearProgressIndicator(), Padding(padding: const EdgeInsets.all(8), child: Text(_progress!))],
          // إظهار/إخفاء البخاري كله في أبلكيشن الأطفال
          StreamBuilder<List<AppTab>>(
            stream: _tabs,
            builder: (context, s) {
              final t = (s.data ?? const <AppTab>[]).where((x) => x.id == _tabId).firstOrNull;
              if (t == null) return const SizedBox.shrink();
              return Card(
                color: t.visible ? const Color(0xFFE6F7EC) : const Color(0xFFFFEDE8),
                elevation: 0,
                shape: cardShape,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: SwitchListTile(
                  title: const Text('صحيح البخاري ظاهر في أبلكيشن الأطفال', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(t.visible ? 'الأطفال شايفين كارت البخاري' : 'مخفي: الأطفال مش شايفينه خالص (حتى الأحاديث المنشورة)'),
                  value: t.visible,
                  onChanged: (v) => run(context, () => repo.saveTab(t.copyWith(visible: v)), done: v ? 'البخاري بقى ظاهر للأطفال ✓' : 'البخاري اتخفى عن الأطفال'),
                ),
              );
            },
          ),
          FutureBuilder<List<int>>(
            future: _counts,
            builder: (context, s) {
              final c = s.data;
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Row(children: [
                  _Stat('كل الأحاديث', c?[0], AppColors.navy),
                  _Stat('منشور', c?[1], AppColors.teal),
                  _Stat('محتاج مراجعة', c?[2], const Color(0xFFE08A00)),
                ]),
              );
            },
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(children: [
              for (final a in _ages)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    label: Text('سن $a'),
                    selected: _age == a,
                    onSelected: (_) {
                      _age = a;
                      _reload();
                    },
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'دوري برقم الحديث أو كلمة', prefixIcon: Icon(Icons.search_rounded), isDense: true),
                  onChanged: (v) => setState(() => _search = v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('الكل')),
                  DropdownMenuItem(value: 'review', child: Text('محتاج مراجعة')),
                  DropdownMenuItem(value: 'draft', child: Text('مش منشور')),
                  DropdownMenuItem(value: 'published', child: Text('منشور')),
                  DropdownMenuItem(value: 'hidden', child: Text('مش مناسب')),
                ],
                onChanged: (v) => setState(() => _filter = v!),
              ),
            ]),
          ),
          Expanded(
            child: FutureBuilder<List<Hadith>>(
              future: _list,
              builder: (context, s) {
                if (s.hasError) return Center(child: Text('خطأ: ${s.error}'));
                if (!s.hasData) return const Center(child: CircularProgressIndicator());
                final all = s.data!;
                if (all.isEmpty) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('مفيش أحاديث في السن ده. لو لسه ما استوردتيش البخاري دوسي استيراد.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(onPressed: _progress == null ? _import : null, icon: const Icon(Icons.cloud_download_rounded), label: const Text('استيراد صحيح البخاري')),
                    ]),
                  );
                }
                final list = all.where((h) {
                  final f = switch (_filter) {
                    'review' => h.status == 'review',
                    'draft' => !h.published && h.status != 'hidden',
                    'published' => h.published,
                    'hidden' => h.status == 'hidden',
                    _ => true,
                  };
                  return f && (_search.isEmpty || '${h.bukhariNo}' == _search || h.text.contains(_search) || h.titleAr.contains(_search));
                }).toList();
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: list.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      final waiting = all.where((h) => h.status == 'auto' && !h.published).length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(children: [
                          Expanded(child: Text('سن $_age: ${all.length} حديث · ${all.where((h) => h.published).length} منشور · ظاهر ${list.length}')),
                          if (waiting > 0) FilledButton.tonal(onPressed: () => _publishAll(all), child: Text('انشري $waiting')),
                        ]),
                      );
                    }
                    return _HadithCard(hadith: list[i - 1], onChanged: _reload);
                  },
                );
              },
            ),
          ),
        ]),
      );
}

Map<String, dynamic> _decode(String raw) => jsonDecode(raw) as Map<String, dynamic>;

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);
  final String label;
  final int? value;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          color: Colors.white,
          elevation: 0,
          shape: cardShape,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(children: [
              Text(value == null ? '…' : '$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
              Text(label, style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ),
      );
}

class _HadithCard extends StatefulWidget {
  const _HadithCard({required this.hadith, required this.onChanged});
  final Hadith hadith;
  final VoidCallback onChanged;
  @override
  State<_HadithCard> createState() => _HadithCardState();
}

class _HadithCardState extends State<_HadithCard> {
  bool _open = false;

  Future<void> _do(Future<void> Function() f, String done) async {
    if (await run(context, f, done: done)) widget.onChanged();
  }

  Future<void> _move(ContentRepository repo) async {
    final h = widget.hadith;
    final age = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('نقل حديث ${h.bukhariNo} لسن…'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in _ages) ChoiceChip(label: Text('$a'), selected: a == h.ageYear, onSelected: (_) => Navigator.pop(c, a)),
            ]),
          ),
        ],
      ),
    );
    if (age == null || age == h.ageYear || !mounted) return;
    await _do(() => repo.moveHadithToAge(h, age), 'اتنقل لسن $age ✓');
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ContentRepository>();
    final h = widget.hadith;
    final st = h.status.isEmpty ? 'auto' : h.status;
    final g = h.game;
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: cardShape,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('${h.bukhariNo}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(child: Text(h.titleAr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted))),
            _Chip(_statusName[st] ?? st, _statusColor[st] ?? AppColors.muted),
          ]),
          // يظهر للأطفال ولا لأ (لو كان محتاج مراجعة أو مش مناسب وفتحتيه، بيتعلّم إنه اتراجع)
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(h.published ? 'ظاهر للأطفال' : 'مخفي عن الأطفال', style: TextStyle(fontWeight: FontWeight.w700, color: h.published ? AppColors.teal : AppColors.goldDark)),
            value: h.published,
            onChanged: (v) => _do(
              () => v && (st == 'review' || st == 'hidden') ? repo.setReview(h.id, status: 'ok', published: true) : repo.setPublished(h.id, v),
              v ? 'بقى ظاهر للأطفال ✓' : 'اتخفى عن الأطفال',
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Text(h.text, maxLines: _open ? null : 3, overflow: _open ? null : TextOverflow.ellipsis, style: GoogleFonts.amiri(fontSize: 18, height: 1.8)),
          ),
          if (_open) ...[
            if (h.isnadAr.isNotEmpty) Text('السند: ${h.isnadAr}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            Text(h.sourceAr, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            if (g.isValid) Text('اللعبة: ${g.before} [${g.answer}] ${g.after}  ·  الاختيارات: ${g.options.join('، ')}', style: const TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (st == 'review')
              FilledButton.icon(onPressed: () => _do(() => repo.setReview(h.id, status: 'ok', published: true), 'اتنشر ✓'), icon: const Icon(Icons.check_rounded), label: const Text('مناسب وانشري')),
            if (st != 'hidden')
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => _do(() => repo.setReview(h.id, status: 'hidden', published: false), 'اتخفى ✓'),
                icon: const Icon(Icons.visibility_off_rounded),
                label: const Text('مش مناسب'),
              ),
            OutlinedButton.icon(onPressed: () => _move(repo), icon: const Icon(Icons.swap_vert_rounded), label: const Text('نقل لسن')),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => HadithEditScreen(tab: _tab, hadith: h)));
                widget.onChanged();
              },
              icon: const Icon(Icons.edit_rounded),
              label: const Text('تعديل'),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.color);
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

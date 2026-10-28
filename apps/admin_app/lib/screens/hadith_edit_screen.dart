import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../services/media_service.dart';
import '../ui.dart';

/// إضافة/تعديل حديث بكل أجزائه: النص، الراوي، المصدر، الشرح، الحكاية، اللعبة، المهمة، الصوت.
class HadithEditScreen extends StatefulWidget {
  const HadithEditScreen({super.key, required this.tab, this.level, this.hadith, this.nextOrder = 1});
  final AppTab tab;
  final Level? level;
  final Hadith? hadith;
  final int nextOrder;
  @override
  State<HadithEditScreen> createState() => _HadithEditScreenState();
}

class _HadithEditScreenState extends State<HadithEditScreen> {
  late final repo = context.read<ContentRepository>();
  late final Stream<List<AppTab>> _tabs = repo.tabs();
  late final Stream<List<Level>> _allLevels = repo.allLevels();

  late String _tabId = widget.hadith?.tabId ?? widget.tab.id;
  late String? _levelId = widget.hadith?.levelId ?? widget.level?.id;
  late bool _isnadInText = widget.hadith?.isnadInText ?? false;
  late String _scene = widget.hadith?.story?.sceneKey ?? '';
  late String _image = widget.hadith?.story?.imageUrl ?? '';
  late String _audio = widget.hadith?.audioUrl ?? '';
  bool _busy = false;

  final c = <String, TextEditingController>{};
  TextEditingController t(String k) => c[k]!;

  @override
  void initState() {
    super.initState();
    final h = widget.hadith;
    final g = h?.game;
    final v = <String, String>{
      'titleAr': h?.titleAr ?? '',
      'titleEn': h?.titleEn ?? '',
      'text': h?.text ?? '',
      'translationEn': h?.translationEn ?? '',
      'narratorAr': h?.narratorAr ?? '',
      'narratorGenAr': h?.narratorGenAr ?? '',
      'narratorEn': h?.narratorEn ?? '',
      'narratorFactAr': h?.narratorFactAr ?? '',
      'narratorFactEn': h?.narratorFactEn ?? '',
      'sourceAr': h?.sourceAr ?? '',
      'sourceEn': h?.sourceEn ?? '',
      'sourceFactAr': h?.sourceFactAr ?? '',
      'sourceFactEn': h?.sourceFactEn ?? '',
      'explainAr': h?.explainAr ?? '',
      'explainEn': h?.explainEn ?? '',
      'storyAr': h?.story?.textAr ?? '',
      'storyEn': h?.story?.textEn ?? '',
      'before': g?.before ?? '',
      'answer': g?.answer ?? '',
      'after': g?.after ?? '',
      'wrong': (g?.wrongOptions ?? const <String>[]).join('، '),
      'missionAr': h?.missionAr ?? '',
      'missionEn': h?.missionEn ?? '',
    };
    v.forEach((k, s) => c[k] = TextEditingController(text: s));
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Hadith _build({required bool published}) {
    String s(String k) => t(k).text.trim();
    final wrong = s('wrong').split(RegExp(r'[،,\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty && e != s('answer')).toList();
    final storyEmpty = s('storyAr').isEmpty && _image.isEmpty;
    final sameParent = widget.hadith != null && widget.hadith!.tabId == _tabId && widget.hadith!.levelId == _levelId;
    return Hadith(
      id: widget.hadith?.id ?? repo.newId('hadiths'),
      tabId: _tabId,
      levelId: _levelId,
      order: sameParent ? widget.hadith!.order : (widget.hadith == null ? widget.nextOrder : 999),
      titleAr: s('titleAr'),
      titleEn: s('titleEn'),
      text: s('text'),
      translationEn: s('translationEn'),
      narratorAr: s('narratorAr'),
      narratorGenAr: s('narratorGenAr').isEmpty ? s('narratorAr') : s('narratorGenAr'),
      narratorEn: s('narratorEn'),
      narratorFactAr: s('narratorFactAr'),
      narratorFactEn: s('narratorFactEn'),
      sourceAr: s('sourceAr'),
      sourceEn: s('sourceEn'),
      sourceFactAr: s('sourceFactAr'),
      sourceFactEn: s('sourceFactEn'),
      isnadInText: _isnadInText,
      explainAr: s('explainAr'),
      explainEn: s('explainEn'),
      story: storyEmpty ? null : Story(textAr: s('storyAr'), textEn: s('storyEn'), sceneKey: _scene, imageUrl: _image),
      game: s('answer').isEmpty ? GameData() : GameData(before: s('before'), answer: s('answer'), after: s('after'), options: [s('answer'), ...wrong]),
      missionAr: s('missionAr'),
      missionEn: s('missionEn'),
      audioUrl: _audio,
      published: published,
      // بيانات البخاري بتفضل زي ما هي (مكانه بيتغير من شاشة مراجعة البخاري)
      ageYear: widget.hadith?.ageYear ?? 0,
      bukhariNo: widget.hadith?.bukhariNo ?? 0,
      status: widget.hadith?.status ?? '',
      isnadAr: widget.hadith?.isnadAr ?? '',
    );
  }

  Future<void> _save({required bool published}) async {
    if (t('titleAr').text.trim().isEmpty || t('text').text.trim().isEmpty) {
      toast(context, 'العنوان والنص مطلوبين', error: true);
      return;
    }
    if (_levelId == null && _needsLevel) {
      toast(context, 'اختاري المستوى', error: true);
      return;
    }
    final h = _build(published: published);
    if (published && t('answer').text.trim().isNotEmpty && h.game.options.length < 2) {
      toast(context, 'اللعبة محتاجة اختيار غلط واحد على الأقل', error: true);
      return;
    }
    setState(() => _busy = true);
    final ok = await run(context, () => repo.saveHadith(h), done: published ? 'اتنشر ✓' : 'اتحفظ كمسودة ✓');
    if (mounted) setState(() => _busy = false);
    if (ok && mounted) Navigator.pop(context);
  }

  bool _needsLevel = false;

  @override
  Widget build(BuildContext context) {
    final isNew = widget.hadith == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'حديث جديد' : 'تعديل: ${widget.hadith!.titleAr}'),
        actions: [
          IconButton(tooltip: 'معاينة', onPressed: () => _preview(context), icon: const Icon(Icons.visibility_rounded)),
          if (!isNew)
            IconButton(
              tooltip: 'حذف',
              onPressed: () async {
                final ok = await confirm(context, 'حذف الحديث؟', 'هيتمسح «${widget.hadith!.titleAr}» نهائيًا.', ok: 'احذف', danger: true);
                if (ok && mounted && await run(context, () => repo.deleteHadith(widget.hadith!.id), done: 'اتمسح') && mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: _busy ? null : () => _save(published: false), child: const Text('حفظ كمسودة'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: _busy ? null : () => _save(published: true), child: const Text('نشر للأطفال'))),
          ]),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        _placeSection(),
        FormSection(title: 'النص', icon: Icons.menu_book_rounded, children: [
          TF(t('titleAr'), 'العنوان بالعربي (مثلًا: الابتسامة)'),
          TF(t('titleEn'), 'العنوان بالإنجليزي', ltr: true),
          TF(t('text'), 'نص الحديث', lines: 3),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('السند مكتوب داخل النص'),
            subtitle: const Text('زي الأربعين النووية: «عن فلان قال...»'),
            value: _isnadInText,
            onChanged: (v) => setState(() => _isnadInText = v),
          ),
          TF(t('translationEn'), 'الترجمة الإنجليزية', lines: 2, ltr: true),
        ]),
        if (!_isnadInText)
          FormSection(title: 'الراوي', icon: Icons.person_rounded, children: [
            TF(t('narratorAr'), 'اسم الراوي (مثلًا: أبو هريرة)'),
            TF(t('narratorGenAr'), 'بعد كلمة «عن» (مثلًا: أبي هريرة)'),
            TF(t('narratorEn'), 'الاسم بالإنجليزي', ltr: true),
            TF(t('narratorFactAr'), 'معلومة عن الراوي للأطفال', lines: 2),
            TF(t('narratorFactEn'), 'المعلومة بالإنجليزي', lines: 2, ltr: true),
          ]),
        FormSection(title: 'المصدر', icon: Icons.library_books_rounded, color: AppColors.goldDark, children: [
          TF(t('sourceAr'), 'المصدر (مثلًا: متفق عليه / رواه مسلم)'),
          TF(t('sourceEn'), 'المصدر بالإنجليزي', ltr: true),
          TF(t('sourceFactAr'), 'شرح المصدر للأطفال', lines: 2),
          TF(t('sourceFactEn'), 'الشرح بالإنجليزي', lines: 2, ltr: true),
        ]),
        FormSection(title: 'الشرح المبسط', icon: Icons.lightbulb_rounded, children: [
          TF(t('explainAr'), 'المعنى بكلام بسيط', lines: 3),
          TF(t('explainEn'), 'المعنى بالإنجليزي', lines: 3, ltr: true),
        ]),
        FormSection(title: 'الحكاية المصورة (اختياري)', icon: Icons.auto_stories_rounded, color: AppColors.royal, children: [
          TF(t('storyAr'), 'الحكاية بالعربي', lines: 3),
          TF(t('storyEn'), 'الحكاية بالإنجليزي', lines: 3, ltr: true),
          Choice<String>(
            label: 'رسمة جاهزة من الأبلكيشن',
            value: _scene,
            options: {'': 'بدون', for (var i = 1; i <= 10; i++) 's$i': 'رسمة $i'},
            onChanged: (v) => setState(() => _scene = v),
          ),
          MediaField(label: 'أو ارفعي صورة (لها الأولوية)', url: _image, kind: MediaKind.image, onChanged: (v) => setState(() => _image = v)),
        ]),
        FormSection(title: 'لعبة الكلمة الناقصة', icon: Icons.sports_esports_rounded, color: AppColors.coral, children: [
          const Text('الطفل بيشوف: [قبل] ___ [بعد] ويختار الكلمة الصح.', style: TextStyle(color: Colors.black54)),
          TF(t('before'), 'الكلام قبل الكلمة'),
          TF(t('answer'), 'الكلمة الصح'),
          TF(t('after'), 'الكلام بعد الكلمة'),
          TF(t('wrong'), 'اختيارات غلط (افصلي بينهم بفاصلة ،)', hint: 'مثلًا: بالألوان، بالأرقام'),
        ]),
        FormSection(title: 'مهمة في الحياة الحقيقية', icon: Icons.flag_rounded, color: AppColors.coral, children: [
          TF(t('missionAr'), 'المهمة (مثلًا: ابتسم في وش ٣ أشخاص النهارده)', lines: 2),
          TF(t('missionEn'), 'المهمة بالإنجليزي', lines: 2, ltr: true),
        ]),
        FormSection(title: 'الصوت', icon: Icons.audiotrack_rounded, color: AppColors.navy, children: [
          MediaField(label: 'ملف صوت الحديث (mp3 / m4a)', url: _audio, kind: MediaKind.audio, onChanged: (v) => setState(() => _audio = v)),
        ]),
        const SizedBox(height: 40),
      ]),
    );
  }

  /// مكان الحديث: أي تبويب وأي مستوى (يسمح بنقله).
  Widget _placeSection() {
    if ((widget.hadith?.ageYear ?? 0) > 0) {
      return FormSection(title: 'مكان الحديث', icon: Icons.place_rounded, children: [
        Text('صحيح البخاري · سن ${widget.hadith!.ageYear} سنين. لنقله لسن تانية استخدمي «نقل لسن» من شاشة مراجعة البخاري.'),
      ]);
    }
    return StreamBuilder<List<AppTab>>(
      stream: _tabs,
      builder: (context, ts) => StreamBuilder<List<Level>>(
        stream: _allLevels,
        builder: (context, ls) {
          final tabs = (ts.data ?? const <AppTab>[]).where((x) => x.isHadith).toList();
          final cur = tabs.where((x) => x.id == _tabId).firstOrNull;
          final levels = (ls.data ?? const <Level>[]).where((l) => l.tabId == _tabId).toList();
          _needsLevel = cur?.hasLevels ?? false;
          return FormSection(title: 'مكان الحديث', icon: Icons.place_rounded, children: [
            Choice<String>(
              label: 'التبويب',
              value: _tabId,
              options: {for (final x in tabs) x.id: x.nameAr},
              onChanged: (v) => setState(() {
                _tabId = v;
                _levelId = null;
              }),
            ),
            if (_needsLevel)
              levels.isEmpty
                  ? const Text('التبويب ده مفيهوش مستويات لسه، ضيفي مستوى الأول.', style: TextStyle(color: AppColors.danger))
                  : Choice<String?>(
                      label: 'المستوى',
                      value: _levelId,
                      options: {for (final l in levels) l.id: l.nameAr},
                      onChanged: (v) => setState(() => _levelId = v),
                    ),
          ]);
        },
      ),
    );
  }

  void _preview(BuildContext context) {
    final h = _build(published: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.mint,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .8,
        builder: (ctx, sc) => ListView(controller: sc, padding: const EdgeInsets.all(16), children: [
          const Text('معاينة زي ما الطفل هيشوفها', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), boxShadow: const [BoxShadow(color: AppColors.mintLine, offset: Offset(0, 5))]),
            child: Column(children: [
              Text(h.titleAr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.teal)),
              const SizedBox(height: 8),
              Text(h.isnadInText ? h.text : '«${h.text}»', textAlign: TextAlign.center, style: GoogleFonts.amiri(fontSize: 24, fontWeight: FontWeight.w700, height: 1.9)),
              const SizedBox(height: 8),
              Text(h.shareText(true).split('\n').last, style: const TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w700)),
            ]),
          ),
          if (h.explainAr.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: Text(h.explainAr, style: const TextStyle(fontSize: 17))),
          ],
          if (h.game.isValid) ...[
            const SizedBox(height: 12),
            Text('اللعبة: ${h.game.before} ___ ${h.game.after}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
            Wrap(alignment: WrapAlignment.center, spacing: 6, children: [for (final o in h.game.options) Chip(label: Text(o), backgroundColor: o == h.game.answer ? const Color(0xFFBFE8CC) : null)]),
          ],
          if (h.missionAr.isNotEmpty) ...[const SizedBox(height: 12), Text('المهمة: ${h.missionAr}', textAlign: TextAlign.center)],
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../state/progress_store.dart';
import '../widgets/common.dart';
import '../widgets/fanoos.dart';
import '../theme.dart';
import 'qa_video_screen.dart';

/// تبويب أسئلة وأجوبة (مثل "ما لا يسع أطفال المسلمين جهله"): أقسام تفتح وتقفل بحركة، ولكل قسم فيديو.
class QaScreen extends StatefulWidget {
  const QaScreen({super.key, required this.tab, this.showHeader = true});
  final AppTab tab;
  final bool showHeader;
  @override
  State<QaScreen> createState() => _QaScreenState();
}

class _QaScreenState extends State<QaScreen> {
  late final Stream<List<QaSection>> _stream = context.read<ContentRepository>().qaSections(widget.tab.id);
  String? _open;

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    return StreamBuilder<List<QaSection>>(
      stream: _stream,
      builder: (context, snap) {
        final list = snap.data ?? const <QaSection>[];
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          if (widget.showHeader)
            SafeArea(
              bottom: false,
              child: Row(children: [
                const Fanoos(size: 50, mood: FanoosMood.talk),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.tab.name(ar), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
              ]),
            ),
          const SizedBox(height: 8),
          if (snap.hasError) Center(child: Text(S.of(context, 'loadError'))),
          if (!snap.hasData && !snap.hasError) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
          if (snap.hasData && list.isEmpty) Center(child: Text(S.of(context, 'emptyContent'))),
          for (var i = 0; i < list.length; i++)
            RiseIn(
              delay: i * 60,
              child: _SectionCard(
                section: list[i],
                open: _open == list[i].id,
                onToggle: () => setState(() => _open = _open == list[i].id ? null : list[i].id),
              ),
            ),
        ]);
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.open, required this.onToggle});
  final QaSection section;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final p = context.watch<ProgressStore>();
    final c = hexColor(section.color);
    final knownN = [for (var i = 0; i < section.items.length; i++) '${section.id}:$i'].where(p.known.contains).length;
    final complete = p.completedSections.contains(section.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardBox(shadow: c.withOpacity(.45)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Material(
          color: c,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                complete ? const RoyalStarIcon(size: 30) : Icon(Icons.lightbulb_rounded, color: onColor(c), size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(section.title(ar), style: TextStyle(color: onColor(c), fontWeight: FontWeight.w800, fontSize: 19)),
                    Text(S.of(context, 'knownOf', {'k': arNum(knownN, arabic: ar), 'n': arNum(section.items.length, arabic: ar)}), style: TextStyle(color: onColor(c).withOpacity(.85), fontSize: 13)),
                  ]),
                ),
                AnimatedRotation(turns: open ? .5 : 0, duration: const Duration(milliseconds: 350), child: Icon(Icons.keyboard_arrow_down_rounded, color: onColor(c), size: 30)),
              ]),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => QaVideoScreen(section: section))),
                      icon: const Icon(Icons.play_circle_fill_rounded),
                      label: Text(S.of(context, 'watchVideo')),
                    ),
                    const SizedBox(height: 10),
                    for (var i = 0; i < section.items.length; i++) _QaItemTile(section: section, index: i, color: c),
                  ]),
                ),
        ),
      ]),
    );
  }
}

class _QaItemTile extends StatefulWidget {
  const _QaItemTile({required this.section, required this.index, required this.color});
  final QaSection section;
  final int index;
  final Color color;
  @override
  State<_QaItemTile> createState() => _QaItemTileState();
}

class _QaItemTileState extends State<_QaItemTile> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProgressStore>();
    final it = widget.section.items[widget.index];
    final key = '${widget.section.id}:${widget.index}';
    final known = p.known.contains(key);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: known ? const Color(0xFFE6F7EC) : AppColors.mint, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _show = !_show),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              CircleAvatar(radius: 14, backgroundColor: widget.color, child: const Icon(Icons.question_mark_rounded, size: 16, color: Colors.white)),
              const SizedBox(width: 10),
              Expanded(child: Text(it.q, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
              Icon(_show ? Icons.remove_rounded : Icons.add_rounded),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: !_show
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(it.a, style: const TextStyle(fontSize: 17, height: 1.7)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilterChip(
                        selected: known,
                        showCheckmark: true,
                        selectedColor: const Color(0xFFBFE8CC),
                        label: Text(S.of(context, 'iKnowIt'), style: const TextStyle(fontWeight: FontWeight.w800)),
                        onSelected: (_) => p.toggleKnown(key, sectionId: widget.section.id, sectionSize: widget.section.items.length),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.copy_rounded, size: 18),
                        label: Text(S.of(context, 'copy')),
                        onPressed: () => copyText(context, '${it.q}\n${it.a}'),
                      ),
                    ]),
                  ]),
                ),
        ),
      ]),
    );
  }
}

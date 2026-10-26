import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';

import '../l10n.dart';
import '../theme.dart';
import '../widgets/audio_button.dart';
import '../widgets/common.dart';
import '../widgets/fanoos.dart';
import 'game_screen.dart';
import 'river_screen.dart';

/// صفحة الحديث: النص + الراوي + المصدر + الشرح + نسخ/مشاركة + صوت.
class HadithScreen extends StatelessWidget {
  const HadithScreen({super.key, required this.flow});
  final FlowCtx flow;

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final h = flow.hadith;
    return Scaffold(
      appBar: AppBar(title: Text(h.title(ar))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: [
        RiseIn(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: cardBox(shadow: AppColors.gold.withOpacity(.5), radius: 30),
            child: Column(children: [
              if (!h.isnadInText) ...[
                Text(S.of(context, 'prophetSaid'), style: const TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 6),
              ],
              SelectableText(
                h.isnadInText ? h.text : '«${h.text}»',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: hadithStyle(size: h.text.length > 220 ? 21 : 27),
              ),
              if (!ar && h.translationEn.isNotEmpty) ...[
                const Divider(height: 28),
                Text(h.translationEn, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, height: 1.6, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                if (h.narratorAr.isNotEmpty || h.narratorEn.isNotEmpty)
                  _FactChip(
                    icon: Icons.person_rounded,
                    color: AppColors.teal,
                    label: ar ? '${S.of(context, 'narrator')}: ${h.narratorAr}' : '${S.of(context, 'narrator')}: ${h.narratorEn.isEmpty ? h.narratorAr : h.narratorEn}',
                    fact: ar ? h.narratorFactAr : (h.narratorFactEn.isEmpty ? h.narratorFactAr : h.narratorFactEn),
                  ),
                if (h.sourceAr.isNotEmpty)
                  _FactChip(
                    icon: Icons.menu_book_rounded,
                    color: AppColors.goldDark,
                    label: ar || h.sourceEn.isEmpty ? h.sourceAr : h.sourceEn,
                    fact: ar ? h.sourceFactAr : (h.sourceFactEn.isEmpty ? h.sourceFactAr : h.sourceFactEn),
                  ),
              ]),
              const SizedBox(height: 14),
              CopyShareRow(text: h.shareText(ar)),
              if (h.audioUrl.isNotEmpty) ...[const SizedBox(height: 10), AudioButton(url: h.audioUrl)],
            ]),
          ),
        ),
        if (h.explain(ar).isNotEmpty) ...[
          const SizedBox(height: 16),
          RiseIn(
            delay: 150,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: cardBox(),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Fanoos(size: 54, mood: FanoosMood.talk),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(S.of(context, 'meaning'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.teal)),
                    const SizedBox(height: 4),
                    Text(h.explain(ar), style: const TextStyle(fontSize: 18, height: 1.7)),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: IconButton(tooltip: S.of(context, 'copy'), onPressed: () => copyText(context, h.explain(ar)), icon: const Icon(Icons.copy_rounded, size: 20)),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 22),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(58), backgroundColor: AppColors.coral),
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => GameScreen(flow: flow))),
          icon: const Icon(Icons.sports_esports_rounded, size: 28),
          label: Text(S.of(context, 'playGame')),
        ),
      ]),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.color, required this.label, required this.fact});
  final IconData icon;
  final Color color;
  final String label;
  final String fact;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, color: color, size: 20),
      label: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      backgroundColor: color.withOpacity(.1),
      side: BorderSide.none,
      shape: const StadiumBorder(),
      onPressed: fact.isEmpty
          ? null
          : () => showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, color: color, size: 40),
                    const SizedBox(height: 8),
                    Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(fact, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 1.7)),
                    const SizedBox(height: 10),
                    CopyShareRow(text: '$label\n$fact', share: false),
                  ]),
                ),
              ),
    );
  }
}

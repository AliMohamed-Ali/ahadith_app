import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';

import '../l10n.dart';
import '../widgets/common.dart';
import '../widgets/fanoos.dart';
import '../widgets/scene.dart';
import '../theme.dart';
import 'hadith_screen.dart';
import 'river_screen.dart';

/// صفحة من كتاب الحكايات: رسمة + حكاية قصيرة توضح معنى الحديث.
class StoryScreen extends StatelessWidget {
  const StoryScreen({super.key, required this.flow});
  final FlowCtx flow;

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final h = flow.hadith;
    final st = h.story!;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: Text(S.of(context, 'storyTitle', {'t': h.title(ar)}))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        RiseIn(
          child: Container(
            decoration: cardBox(shadow: const Color(0xFFEBD9A0), radius: 30),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 320 / 200,
              child: _Bob(
                child: SceneArt(
                  url: st.imageUrl,
                  asset: st.sceneKey.isEmpty ? '' : 'assets/scenes/story_${st.sceneKey}.svg',
                  fit: BoxFit.cover,
                  fallback: const Center(child: Fanoos(size: 90, mood: FanoosMood.happy)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        RiseIn(
          delay: 150,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: cardBox(shadow: const Color(0xFFEBD9A0)),
            child: Column(children: [
              Text(st.text(ar), style: const TextStyle(fontSize: 20, height: 1.8, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              CopyShareRow(text: st.text(ar), share: false),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => HadithScreen(flow: flow))),
          icon: const Icon(Icons.menu_book_rounded),
          label: Text(S.of(context, 'toHadith')),
        ),
      ]),
    );
  }
}

/// حركة خفيفة للرسمة (تطلع وتنزل) عشان تبان حية.
class _Bob extends StatefulWidget {
  const _Bob({required this.child});
  final Widget child;
  @override
  State<_Bob> createState() => _BobState();
}

class _BobState extends State<_Bob> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Transform.scale(scale: 1.02 + Curves.easeInOut.transform(_c.value) * 0.04, child: child),
        child: widget.child,
      );
}

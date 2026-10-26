import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:just_audio/just_audio.dart';

import '../l10n.dart';
import '../widgets/fanoos.dart';
import '../widgets/scene.dart';

/// "فيديو" متحرك لكل قسم: مشاهد متتابعة (رسمة + سؤال وجواب) وفانوس بيتكلم.
/// لو المدير رفع ملف صوت للقسم بيشتغل مع المشاهد.
class QaVideoScreen extends StatefulWidget {
  const QaVideoScreen({super.key, required this.section});
  final QaSection section;
  @override
  State<QaVideoScreen> createState() => _QaVideoScreenState();
}

class _QaVideoScreenState extends State<QaVideoScreen> with SingleTickerProviderStateMixin {
  static const _slideSec = 6;
  late final AnimationController _progress = AnimationController(vsync: this, duration: const Duration(seconds: _slideSec));
  final _player = AudioPlayer();
  int _slide = 0;
  bool _playing = true;

  int get _count => widget.section.items.length + 1;

  @override
  void initState() {
    super.initState();
    _progress.addStatusListener((s) {
      if (s == AnimationStatus.completed) _go(_slide + 1);
    });
    _progress.forward();
    _initAudio();
  }

  Future<void> _initAudio() async {
    if (widget.section.audioUrl.isEmpty) return;
    try {
      await _player.setUrl(widget.section.audioUrl);
      if (_playing) unawaited(_player.play());
    } catch (_) {}
  }

  void _go(int i) {
    if (i >= _count) {
      setState(() => _playing = false);
      _player.pause();
      return;
    }
    setState(() => _slide = i.clamp(0, _count - 1));
    _progress
      ..reset()
      ..forward();
  }

  void _toggle() {
    setState(() => _playing = !_playing);
    if (_playing) {
      if (_slide >= _count - 1 && _progress.isCompleted) _go(0);
      _progress.forward();
      if (widget.section.audioUrl.isNotEmpty) _player.play();
    } else {
      _progress.stop();
      _player.pause();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = S.ar(context);
    final s = widget.section;
    final c = hexColor(s.color);
    final isTitle = _slide == 0;
    final item = isTitle ? null : s.items[_slide - 1];
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(title: Text(s.title(ar))),
      body: SafeArea(
        child: Column(children: [
          // شريط التقدم مقسم على المشاهد
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(children: [
              for (var i = 0; i < _count; i++)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)),
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (_, __) => FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: i < _slide ? 1 : (i == _slide ? _progress.value : 0),
                        child: Container(decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(3))),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _toggle,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .94, end: 1.0).animate(a), child: child)),
                child: Padding(
                  key: ValueKey(_slide),
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: BoxDecoration(color: c.withOpacity(.25), borderRadius: BorderRadius.circular(28)),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(children: [
                          Positioned.fill(
                            child: SceneArt(
                              asset: s.videoScene.isEmpty ? '' : 'assets/scenes/video_${s.videoScene}.svg',
                              fit: BoxFit.contain,
                              fallback: const SizedBox.shrink(),
                            ),
                          ),
                          const PositionedDirectional(bottom: 8, start: 8, child: Fanoos(size: 64, mood: FanoosMood.talk)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      flex: 4,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
                        child: SingleChildScrollView(
                          child: isTitle
                              ? Column(children: [
                                  Text(s.title(ar), textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: c)),
                                  const SizedBox(height: 8),
                                  Text(S.of(context, 'videoIntro', {'n': arNum(s.items.length, arabic: ar)}), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
                                ])
                              : Column(children: [
                                  Text(item!.q, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
                                  const SizedBox(height: 10),
                                  Text(item.a, textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, height: 1.7)),
                                ]),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(iconSize: 40, color: Colors.white, onPressed: () => _go(_slide - 1), icon: Icon(ar ? Icons.skip_next_rounded : Icons.skip_previous_rounded)),
            const SizedBox(width: 12),
            IconButton.filled(
              iconSize: 46,
              style: IconButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.navy),
              onPressed: _toggle,
              icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
            const SizedBox(width: 12),
            IconButton(iconSize: 40, color: Colors.white, onPressed: () => _go(_slide + 1), icon: Icon(ar ? Icons.skip_previous_rounded : Icons.skip_next_rounded)),
          ]),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:just_audio/just_audio.dart';

import '../l10n.dart';

/// زر تشغيل صوت مرفوع من لوحة المدير (يظهر فقط لو فيه رابط صوت).
class AudioButton extends StatefulWidget {
  const AudioButton({super.key, required this.url, this.label});
  final String url;
  final String? label;
  @override
  State<AudioButton> createState() => _AudioButtonState();
}

class _AudioButtonState extends State<AudioButton> {
  final _player = AudioPlayer();
  bool _loaded = false;
  bool _error = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (!_loaded) {
        await _player.setUrl(widget.url);
        _loaded = true;
      }
      if (_player.playing) {
        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.completed) await _player.seek(Duration.zero);
        await _player.play();
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty || _error) return const SizedBox.shrink();
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snap) {
        final playing = snap.data?.playing ?? false;
        final loading = snap.data?.processingState == ProcessingState.loading || snap.data?.processingState == ProcessingState.buffering;
        return FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.royal),
          onPressed: _toggle,
          icon: loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(playing ? Icons.pause_rounded : Icons.volume_up_rounded),
          label: Text(widget.label ?? S.of(context, playing ? 'pause' : 'listen')),
        );
      },
    );
  }
}

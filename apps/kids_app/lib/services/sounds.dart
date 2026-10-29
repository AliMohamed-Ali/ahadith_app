import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// كل أصوات الأبلكيشن (متولّدة بـ tools/sounds/make_sounds.py) + اهتزاز خفيف.
enum Sfx { tap, pop, correct, wrong, win, star, coin, jump, whoosh, swish, snap, land, bump, crumble, welcome, levelUp, salam }

class Sounds {
  Sounds._();

  /// بيتظبط من إعداد الطفل (الأصوات والاهتزاز).
  static bool enabled = true;
  static final Map<Sfx, AudioPool> _pools = {};
  static bool _ready = false;

  static String _file(Sfx s) => s == Sfx.levelUp ? 'level_up' : s.name;

  /// بيتنده مرة واحدة أول ما الأبلكيشن يفتح. لو فشل (مثلاً في التيستات) الأبلكيشن يكمل عادي من غير صوت.
  static Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      // أصوات قصيرة: ما توقفش مزيكا الأهل، وتحترم زرار الصامت في الآيفون.
      await AudioPlayer.global.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers, respectSilence: true).build());
      for (final s in Sfx.values) {
        _pools[s] = await AudioPool.createFromAsset(
          path: 'sounds/${_file(s)}.wav',
          // الأصوات اللي ممكن تتكرر ورا بعض بسرعة محتاجة أكتر من مشغّل
          maxPlayers: const {Sfx.tap, Sfx.pop, Sfx.coin, Sfx.correct, Sfx.snap}.contains(s) ? 3 : 1,
          playerMode: PlayerMode.lowLatency,
        );
      }
    } catch (e) {
      debugPrint('sounds init failed: $e');
    }
  }

  static const _volume = {Sfx.tap: .5, Sfx.swish: .6, Sfx.whoosh: .7, Sfx.wrong: .7, Sfx.crumble: .7, Sfx.salam: 1.0};

  static void play(Sfx s) {
    if (!enabled) return;
    _haptic(s);
    final pool = _pools[s];
    if (pool == null) return;
    pool.start(volume: _volume[s] ?? .9).catchError((Object e) {
      debugPrint('sound $s failed: $e');
      return () async {};
    });
  }

  static void _haptic(Sfx s) {
    switch (s) {
      case Sfx.correct || Sfx.coin || Sfx.snap || Sfx.star:
        HapticFeedback.lightImpact();
      case Sfx.wrong || Sfx.bump || Sfx.crumble:
        HapticFeedback.mediumImpact();
      case Sfx.win || Sfx.levelUp || Sfx.land:
        HapticFeedback.heavyImpact();
      default:
        break;
    }
  }
}

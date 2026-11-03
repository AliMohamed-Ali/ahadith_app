import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../l10n.dart';
import '../services/sounds.dart';
import '../state/progress_store.dart';
import 'fanoos.dart';

/// رسايل تشجيع ودعاء للطفل بتنزل من فوق وهو فاتح الأبلكيشن.
/// بتقف لما الأبلكيشن يروح في الخلفية، وكل الرسايل بتطلع بالدور قبل ما تتكرر.
/// {name} بيتبدل باسم الطفل. لتعديل الرسايل: عدّلي القايمة دي.
const cheerMessages = <String>[
  'برافو يا {name}! ربنا يبارك فيك 🌟',
  'إنت بطل يا {name}، كمّل وربنا معاك 💪',
  'ربنا يزيدك علم ونور يا {name} 🌙',
  'قول معانا: ﴿رَبِّ زِدْنِي عِلْمًا﴾ 📖',
  'ربنا يحفظك ويخليك لبابا وماما ❤️',
  'كل حديث بتتعلمه نور في قلبك يا {name} ✨',
  'قول معانا: ﴿رَبِّ اشْرَحْ لِي صَدْرِي ۝ وَيَسِّرْ لِي أَمْرِي﴾ 🤲',
  'شاطر يا {name}! كل يوم بتكبر وتتعلم حاجة حلوة 🌱',
  'ربنا يفتح عليك ويجعلك من حفّاظ سنة النبي ﷺ 🤲',
  'متنساش تطبّق الحديث اللي اتعلمته النهارده 😊',
  'ربنا يرضى عنك يا {name} زي ما بتفرّح بابا وماما 💛',
  'ربنا يجعلك من الصالحين يا {name} 🤲',
];
class CheerOverlay extends StatefulWidget {
  const CheerOverlay({super.key, required this.child});
  final Widget child;
  @override
  State<CheerOverlay> createState() => _CheerOverlayState();
}

class _CheerOverlayState extends State<CheerOverlay> with WidgetsBindingObserver {
  static const _firstDelay = Duration(seconds: 40);
  static const _every = Duration(minutes: 10);
  static const _showFor = Duration(seconds: 7);

  Timer? _timer, _hide;
  String? _msg;
  bool _visible = false;
  List<String> _queue = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start(_firstDelay);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start(_firstDelay);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _timer?.cancel();
    }
  }

  void _start(Duration first) {
    _timer?.cancel();
    _timer = Timer(first, () {
      _show();
      _timer = Timer.periodic(_every, (_) => _show());
    });
  }

  void _show() {
    if (!mounted) return;
    if (_queue.isEmpty) _queue = [...cheerMessages]..shuffle();
    final p = context.read<ProgressStore>();
    final name = p.profile?.name.trim() ?? '';
    final raw = _queue.removeAt(0);
    setState(() {
      _msg = raw.replaceAll('{name}', name.isEmpty ? S.of(context, 'champ') : name);
      _visible = true;
    });
    Sounds.play(Sfx.star);
    _hide?.cancel();
    _hide = Timer(_showFor, _dismiss);
  }

  void _dismiss() {
    if (mounted) setState(() => _visible = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        if (_msg != null)
          Positioned(
            left: 12,
            right: 12,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: AnimatedSlide(
                offset: _visible ? Offset.zero : const Offset(0, -1.6),
                duration: const Duration(milliseconds: 450),
                curve: _visible ? Curves.easeOutBack : Curves.easeIn,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: Material(
                      color: Colors.white,
                      elevation: 10,
                      shadowColor: Colors.black38,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.gold, width: 2.5)),
                        child: Row(children: [
                          const Fanoos(size: 42, mood: FanoosMood.happy),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_msg!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy, height: 1.4))),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ]);
}

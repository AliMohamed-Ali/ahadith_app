import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import 'fanoos.dart';

/// بيقارن نسخة الأبلكيشن بإعدادات المدير (config/update):
/// - أقدم من أقل نسخة مسموح بيها ← الأبلكيشن كله بيتقفل لحد ما يتحدّث.
/// - أقدم من آخر نسخة ← شريط صغير بيقترح التحديث ويتقفل بـ «بعدين».
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});
  final Widget child;
  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  int? _build;
  String _package = '';
  bool _later = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final i = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _build = int.tryParse(i.buildNumber);
        _package = i.packageName;
      });
    } catch (e) {
      debugPrint('package info failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = context.watch<UpdateConfig>();
    final build = _build;
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (build == null || !(android || ios)) return widget.child;
    final min = android ? cfg.minBuildAndroid : cfg.minBuildIos;
    final latest = android ? cfg.latestBuildAndroid : cfg.latestBuildIos;
    final url = android ? (cfg.androidUrl.isNotEmpty ? cfg.androidUrl : 'https://play.google.com/store/apps/details?id=$_package') : cfg.iosUrl;
    if (build < min) return _UpdateRequired(url: url, message: cfg.message(S.ar(context)));
    if (build < latest && !_later) {
      return Stack(children: [
        widget.child,
        Positioned(left: 12, right: 12, bottom: 12, child: SafeArea(top: false, child: _UpdateBanner(url: url, onLater: () => setState(() => _later = true)))),
      ]);
    }
    return widget.child;
  }
}

Future<void> _openStore(String url) async {
  if (url.isEmpty) return;
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('open store failed: $e');
  }
}

/// شاشة التحديث الإجباري: مفيش منها رجوع.
class _UpdateRequired extends StatelessWidget {
  const _UpdateRequired({required this.url, required this.message});
  final String url, message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1D2B5E), Color(0xFF2E3F82)])),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Spacer(),
                const Fanoos(size: 130, mood: FanoosMood.talk),
                const SizedBox(height: 20),
                Text(S.of(context, 'updateTitle'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 10),
                Text(
                  message.isNotEmpty ? message : S.of(context, 'updateBody'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, height: 1.6, color: Color(0xFFCFE6FF)),
                ),
                const Spacer(),
                if (url.isNotEmpty)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: AppColors.navy, minimumSize: const Size.fromHeight(58)),
                    onPressed: () => _openStore(url),
                    icon: const Icon(Icons.system_update_rounded),
                    label: Text(S.of(context, 'updateNow')),
                  )
                else
                  Text(S.of(context, 'updateFromStore'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 17)),
              ]),
            ),
          ),
        ),
      );
}

/// اقتراح تحديث (مش إجباري).
class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.url, required this.onLater});
  final String url;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 8,
        shadowColor: Colors.black38,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            const Fanoos(size: 40, mood: FanoosMood.happy),
            const SizedBox(width: 10),
            Expanded(child: Text(S.of(context, 'updateSoft'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy))),
            TextButton(onPressed: onLater, child: Text(S.of(context, 'updateLater'))),
            if (url.isNotEmpty) FilledButton(onPressed: () => _openStore(url), child: Text(S.of(context, 'updateShort'))),
          ]),
        ),
      );
}

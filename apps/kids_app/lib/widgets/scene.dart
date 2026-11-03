import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// يعرض رسمة SVG من assets إن وُجدت، أو صورة من الإنترنت، وإلا [fallback].
class SceneArt extends StatelessWidget {
  const SceneArt({super.key, this.asset = '', this.url = '', required this.fallback, this.fit = BoxFit.contain});
  final String asset;
  final String url;
  final Widget fallback;
  final BoxFit fit;

  static final _cache = <String, String?>{};

  Future<String?> _load() async {
    if (_cache.containsKey(asset)) return _cache[asset];
    try {
      final s = await rootBundle.loadString(asset);
      return _cache[asset] = s;
    } catch (_) {
      return _cache[asset] = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (url.isNotEmpty) {
      // الصورة بتتحفظ على الموبايل فبتفتح بعد كده من غير نت
      return CachedNetworkImage(imageUrl: url, fit: fit, errorWidget: (_, __, ___) => fallback, placeholder: (_, __) => const Center(child: CircularProgressIndicator()));
    }
    if (asset.isEmpty) return fallback;
    return FutureBuilder<String?>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const SizedBox.expand();
        final svg = snap.data;
        if (svg == null) return fallback;
        return SvgPicture.string(svg, fit: fit);
      },
    );
  }
}

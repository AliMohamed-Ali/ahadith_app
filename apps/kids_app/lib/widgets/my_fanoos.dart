import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import '../state/progress_store.dart';
import 'fanoos.dart';

/// فانوس الطفل بلونه وزينته المختارة.
class MyFanoos extends StatelessWidget {
  const MyFanoos({super.key, this.size = 72, this.mood = FanoosMood.smile, this.swing = true});
  final double size;
  final FanoosMood mood;
  final bool swing;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProgressStore>();
    final cfg = context.watch<AppConfig>();
    final item = cfg.shop.where((s) => s.id == p.fanColor && s.kind == 'color');
    final color = item.isEmpty ? AppColors.gold : hexColor(item.first.hex, AppColors.gold);
    return Fanoos(
      size: size,
      mood: mood,
      swing: swing,
      color: color,
      crown: p.wearing.contains('crown'),
      bow: p.wearing.contains('bow'),
      halo: p.wearing.contains('halo'),
    );
  }
}

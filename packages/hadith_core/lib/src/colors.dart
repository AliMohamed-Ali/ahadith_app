import 'package:flutter/material.dart';

/// ألوان الهوية المستخدمة في الأبلكيشنين.
class AppColors {
  static const navy = Color(0xFF1D2B5E);
  static const navy2 = Color(0xFF2C3E7A);
  static const teal = Color(0xFF0E7C74);
  static const tealDark = Color(0xFF0A5C56);
  static const gold = Color(0xFFF5B82E);
  static const goldDark = Color(0xFFC27A10);
  static const coral = Color(0xFFF0644A);
  static const mint = Color(0xFFEAF6F0);
  static const mintLine = Color(0xFFCFE6DC);
  static const ink = Color(0xFF2E3B66);
  static const muted = Color(0xFF4A5578);
  static const royal = Color(0xFF9B4DE0);
  static const royalDark = Color(0xFF5B2199);
  static const royalSoft = Color(0xFFF3E8FF);
  static const cream = Color(0xFFFFF3C9);
  static const peach = Color(0xFFFFD3C4);
  static const danger = Color(0xFFC4472A);
}

/// يحوّل نص مثل "#F5B82E" إلى لون.
Color hexColor(String? hex, [Color fallback = AppColors.teal]) {
  if (hex == null || hex.isEmpty) return fallback;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

/// يحوّل اللون إلى "#RRGGBB".
String colorToHex(Color c) {
  final v = c.value & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// لون النص المناسب فوق خلفية معينة.
Color onColor(Color bg) => bg.computeLuminance() > 0.45 ? AppColors.navy : Colors.white;

/// أرقام عربية.
String arNum(Object n, {bool arabic = true}) {
  final s = n.toString();
  if (!arabic) return s;
  const digits = '٠١٢٣٤٥٦٧٨٩';
  return s.replaceAllMapped(RegExp(r'\d'), (m) => digits[int.parse(m[0]!)]);
}

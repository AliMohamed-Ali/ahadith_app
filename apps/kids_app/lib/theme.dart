import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hadith_core/hadith_core.dart';

ThemeData buildKidsTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.teal, primary: AppColors.teal, secondary: AppColors.gold, surface: Colors.white),
    scaffoldBackgroundColor: AppColors.mint,
  );
  return base.copyWith(
    textTheme: GoogleFonts.balooBhaijaan2TextTheme(base.textTheme).apply(bodyColor: AppColors.navy, displayColor: AppColors.navy),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      centerTitle: false,
      elevation: 0,
      titleTextStyle: GoogleFonts.balooBhaijaan2(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.teal,
        minimumSize: const Size(48, 54),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.balooBhaijaan2(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        minimumSize: const Size(48, 48),
        shape: const StadiumBorder(),
        side: const BorderSide(color: AppColors.navy, width: 2),
        textStyle: GoogleFonts.balooBhaijaan2(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.teal,
      contentTextStyle: GoogleFonts.balooBhaijaan2(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

/// خط نصوص الأحاديث.
TextStyle hadithStyle({double size = 26, Color color = AppColors.navy}) => GoogleFonts.amiri(fontSize: size, fontWeight: FontWeight.w700, height: 1.9, color: color);

/// كارت أبيض بظل سفلي بسيط (نفس شكل النموذج).
BoxDecoration cardBox({Color color = Colors.white, Color shadow = AppColors.mintLine, double radius = 26}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 5))],
    );

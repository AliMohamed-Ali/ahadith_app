import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hadith_core/hadith_core.dart';

ThemeData buildAdminTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.teal, primary: AppColors.teal, secondary: AppColors.gold),
    scaffoldBackgroundColor: const Color(0xFFF4F7FB),
  );
  return base.copyWith(
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme).apply(bodyColor: AppColors.navy, displayColor: AppColors.navy),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
  );
}

final cardShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xFFE2E8F0)));

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: error ? AppColors.danger : AppColors.teal, content: Text(msg)));
}

Future<bool> confirm(BuildContext context, String title, String body, {String ok = 'تأكيد', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null, onPressed: () => Navigator.pop(c, true), child: Text(ok)),
      ],
    ),
  );
  return r == true;
}

/// ينفّذ عملية حفظ ويعرض نجاح أو خطأ.
Future<bool> run(BuildContext context, Future<void> Function() f, {String done = 'اتحفظ ✓'}) async {
  try {
    await f();
    if (context.mounted) toast(context, done);
    return true;
  } catch (e) {
    if (context.mounted) toast(context, 'حصل خطأ: $e', error: true);
    return false;
  }
}

const presetColors = ['#F5B82E', '#FFD465', '#0E7C74', '#3CC7A8', '#BDEBE3', '#1D2B5E', '#4FA8F0', '#7558D6', '#9B4DE0', '#F27BA6', '#F0644A', '#E8573A', '#8A5A2B'];

/// اختيار لون من ألوان جاهزة أو كتابة كود اللون.
class ColorField extends StatelessWidget {
  const ColorField({super.key, required this.value, required this.onChanged, this.label = 'اللون'});
  final String value;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in presetColors)
          GestureDetector(
            onTap: () => onChanged(c),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: hexColor(c),
                shape: BoxShape.circle,
                border: Border.all(color: value.toUpperCase() == c ? AppColors.navy : Colors.black12, width: value.toUpperCase() == c ? 3 : 1),
              ),
            ),
          ),
        SizedBox(
          width: 110,
          child: TextFormField(
            key: ValueKey(value),
            initialValue: value,
            decoration: const InputDecoration(isDense: true, hintText: '#RRGGBB'),
            onFieldSubmitted: (v) {
              if (RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(v.trim())) onChanged('#${v.trim().replaceAll('#', '').toUpperCase()}');
            },
          ),
        ),
      ]),
    ]);
  }
}

/// كارت قسم في نموذج التحرير.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.icon, required this.children, this.color = AppColors.teal});
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white,
        elevation: 0,
        shape: cardShape,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Icon(icon, color: color), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color))]),
            const SizedBox(height: 10),
            for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 10), child: c),
          ]),
        ),
      );
}

/// حقل نصي مختصر.
class TF extends StatelessWidget {
  const TF(this.controller, this.label, {super.key, this.lines = 1, this.ltr = false, this.number = false, this.hint});
  final TextEditingController controller;
  final String label;
  final int lines;
  final bool ltr;
  final bool number;
  final String? hint;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 4,
        keyboardType: number ? TextInputType.number : (lines > 1 ? TextInputType.multiline : TextInputType.text),
        textDirection: ltr ? TextDirection.ltr : null,
        decoration: InputDecoration(labelText: label, hintText: hint, alignLabelWithHint: lines > 1),
      );
}

/// اختيار من عدة اختيارات بشكل أزرار.
class Choice<T> extends StatelessWidget {
  const Choice({super.key, required this.label, required this.value, required this.options, required this.onChanged, this.enabled = true});
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in options.entries)
            ChoiceChip(
              label: Text(e.value),
              selected: e.key == value,
              onSelected: enabled ? (_) => onChanged(e.key) : null,
            ),
        ]),
      ]);
}

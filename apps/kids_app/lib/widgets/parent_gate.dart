import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hadith_core/hadith_core.dart';

import '../l10n.dart';

/// بوابة للكبار: سؤال حساب بسيط قبل أي إجراء يخص الأهل.
/// تعيد true إذا أجاب الكبير إجابة صحيحة.
Future<bool> showParentGate(BuildContext context, {required String body}) async {
  final rnd = math.Random();
  final a = 4 + rnd.nextInt(6), b = 3 + rnd.nextInt(6);
  final sum = a + b;
  final choices = [sum, sum + 1, sum - 2]..shuffle(rnd);
  final ar = Directionality.of(context) == TextDirection.rtl;
  var wrong = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(children: [
          const Icon(Icons.lock_rounded, color: AppColors.goldDark),
          const SizedBox(width: 8),
          Text(S.of(ctx, 'gateTitle'), style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.6)),
          const SizedBox(height: 12),
          Text('${arNum(a, arabic: ar)} + ${arNum(b, arabic: ar)} = ؟', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(children: [
            for (final c in choices)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton(
                    onPressed: () {
                      if (c == sum) {
                        Navigator.pop(ctx, true);
                      } else {
                        setS(() => wrong = true);
                      }
                    },
                    child: Text(arNum(c, arabic: ar), style: const TextStyle(fontSize: 22)),
                  ),
                ),
              ),
          ]),
          if (wrong) ...[
            const SizedBox(height: 8),
            Text(S.of(ctx, 'gateWrong'), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
          ],
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.of(ctx, 'cancel')))],
      ),
    ),
  );
  return ok == true;
}

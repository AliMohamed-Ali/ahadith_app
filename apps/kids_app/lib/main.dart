import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'l10n.dart';
import 'screens/splash_screen.dart';
import 'state/progress_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // الخطوط متخزنة في assets/google_fonts، فمش محتاجين نحمّلها من النت.
  GoogleFonts.config.allowRuntimeFetching = false;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // تسجيل مجهول: لا يطلب أي بيانات من الطفل، ويُستخدم فقط للوحة الشرف.
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  } catch (e) {
    debugPrint('anonymous sign-in failed: $e');
  }
  if (!kIsWeb) {
    try {
      await FirebaseMessaging.instance.requestPermission();
      await FirebaseMessaging.instance.subscribeToTopic('kids');
    } catch (e) {
      debugPrint('messaging setup failed: $e');
    }
  }
  final progress = await ProgressStore.load();
  final repo = ContentRepository(FirebaseFirestore.instance);

  runApp(
    MultiProvider(
      providers: [
        Provider<ContentRepository>.value(value: repo),
        ChangeNotifierProvider<ProgressStore>.value(value: progress),
        StreamProvider<AppConfig>(create: (_) => repo.config(), initialData: const AppConfig(), catchError: (_, __) => const AppConfig()),
      ],
      child: const KidsApp(),
    ),
  );
}

/// حجم الخط بيتظبط على مقاس الشاشة (موبايل صغير، كبير، تابلت) ومع إعداد حجم الخط في الموبايل،
/// بس في حدود عشان التصميم ما يبوظش لو الإعداد كبير قوي.
TextScaler appTextScaler(MediaQueryData mq) {
  final byScreen = (mq.size.shortestSide / 390).clamp(.88, 1.2);
  final bySystem = mq.textScaler.scale(10) / 10;
  return TextScaler.linear((byScreen * bySystem.clamp(.9, 1.2)).clamp(.85, 1.35));
}

class KidsApp extends StatelessWidget {
  const KidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.select<ProgressStore, String>((p) => p.lang);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'أحاديث الصغار',
      theme: buildKidsTheme(),
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: appTextScaler(MediaQuery.of(context))),
        child: RoyalStarListener(child: child ?? const SizedBox()),
      ),
      home: const SplashScreen(),
    );
  }
}

/// يظهر رسالة احتفال عند كسب نجمة ملكية جديدة.
class RoyalStarListener extends StatefulWidget {
  const RoyalStarListener({super.key, required this.child});
  final Widget child;
  @override
  State<RoyalStarListener> createState() => _RoyalStarListenerState();
}

class _RoyalStarListenerState extends State<RoyalStarListener> {
  int? _last;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ProgressStore>();
    final cfg = context.watch<AppConfig>();
    final royal = p.royalStars(cfg.rewards);
    if (_last != null && royal > _last!) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final m = ScaffoldMessenger.maybeOf(context);
        m?.showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.royalDark,
          content: Row(children: [
            const Icon(Icons.workspace_premium, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(child: Text(S.of(context, 'royalToast'), style: const TextStyle(fontWeight: FontWeight.w800))),
          ]),
        ));
      });
    }
    _last = royal;
    return widget.child;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hadith_core/hadith_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(Provider<ContentRepository>.value(value: ContentRepository(FirebaseFirestore.instance), child: const AdminApp()));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'لوحة تحكم أحاديث الصغار',
        theme: buildAdminTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        home: const AuthGate(),
      );
}

/// تسجيل الدخول ← التأكد إن الحساب مدير ← لوحة التحكم.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final user = snap.data;
        if (user == null) return const LoginScreen();
        return FutureBuilder<bool>(
          key: ValueKey(user.uid),
          future: context.read<ContentRepository>().isAdmin(user.uid),
          builder: (context, a) {
            if (!a.hasData && !a.hasError) return const Scaffold(body: Center(child: CircularProgressIndicator()));
            if (a.data == true) return const DashboardScreen();
            return NotAdminScreen(user: user);
          },
        );
      },
    );
  }
}

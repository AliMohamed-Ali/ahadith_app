import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hadith_core/hadith_core.dart';

import '../ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: _email.text.trim(), password: _pass.text);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = switch (e.code) {
            'invalid-credential' || 'wrong-password' || 'user-not-found' => 'الإيميل أو كلمة السر غلط',
            'too-many-requests' => 'محاولات كتير، استني شوية',
            _ => 'خطأ: ${e.code}',
          });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      toast(context, 'اكتبي الإيميل الأول', error: true);
      return;
    }
    await run(context, () => FirebaseAuth.instance.sendPasswordResetEmail(email: _email.text.trim()), done: 'اتبعت رابط تغيير كلمة السر على الإيميل');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.admin_panel_settings_rounded, size: 72, color: AppColors.teal),
              const SizedBox(height: 8),
              const Text('لوحة تحكم أحاديث الصغار', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'الإيميل')),
              const SizedBox(height: 12),
              TextField(controller: _pass, obscureText: true, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: 'كلمة السر'), onSubmitted: (_) => _login()),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
              const SizedBox(height: 16),
              FilledButton(onPressed: _busy ? null : _login, child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('دخول')),
              TextButton(onPressed: _reset, child: const Text('نسيت كلمة السر')),
            ]),
          ),
        ),
      ),
    );
  }
}

/// الحساب مسجّل لكنه ليس مديرًا بعد: نعرض الـ UID لإضافته في مجموعة admins من الكونسول.
class NotAdminScreen extends StatelessWidget {
  const NotAdminScreen({super.key, required this.user});
  final User user;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_person_rounded, size: 64, color: AppColors.goldDark),
              const SizedBox(height: 10),
              const Text('الحساب ده لسه مش مدير', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'من Firebase Console ← Firestore اعملي مجموعة اسمها admins، وجواها مستند اسمه نفس الكود ده (أي حقل، مثلًا role = "owner")، وبعدين ادخلي تاني.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              SelectableText(user.uid, textDirection: TextDirection.ltr, style: const TextStyle(fontWeight: FontWeight.w800)),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: user.uid));
                  toast(context, 'اتنسخ');
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('نسخ الكود'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => FirebaseAuth.instance.signOut(), child: const Text('خروج')),
            ]),
          ),
        ),
      );
}

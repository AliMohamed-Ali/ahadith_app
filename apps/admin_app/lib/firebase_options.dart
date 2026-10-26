// هذا الملف مؤقت. شغّلي الأمر التالي داخل مجلد apps/admin_app ليُستبدل تلقائيًا ببيانات مشروعك:
//   flutterfire configure --project=<PROJECT_ID>
// (أو ابعتيلي ملف firebase_options.dart الناتج وأنا أحطه مكانه)
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA5AxC8HcHj3qJx6WRbMUyeo3_ZD4pxbMA',
    appId: '1:262095966926:android:ab6a08ecb12fabcea2b69f',
    messagingSenderId: '262095966926',
    projectId: 'ahadith-6d664',
    storageBucket: 'ahadith-6d664.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC30kaeDR7UuEfvhDf5cF1ds0Qs4zi2q8Y',
    appId: '1:262095966926:ios:35c1fa074c563f5ca2b69f',
    messagingSenderId: '262095966926',
    projectId: 'ahadith-6d664',
    storageBucket: 'ahadith-6d664.firebasestorage.app',
    iosBundleId: 'com.ahadith.adminApp',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    storageBucket: 'REPLACE_ME',
  );
}
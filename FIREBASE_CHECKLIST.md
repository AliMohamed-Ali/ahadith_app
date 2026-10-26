# بيانات Firebase المطلوبة

## ابعتيلي دول (عادي ومش سرّيين)

1. **Project ID** — من Project settings ← General (زي `ahadith-alsighar-12345`).
2. **Package name** لكل أبلكيشن (اللي اخترتيه في `flutter create --org`):
   - أبلكيشن الأطفال: مثلًا `com.yourname.kids_app`
   - لوحة التحكم: مثلًا `com.yourname.admin_app`
3. **ملفات الربط** بعد ما تشغّلي `flutterfire configure` في كل أبلكيشن:
   - `apps/kids_app/lib/firebase_options.dart`
   - `apps/admin_app/lib/firebase_options.dart`
   - (أو بدالهم: `google-services.json` للأندرويد و `GoogleService-Info.plist` للآيفون لكل أبلكيشن)
4. **مكان قاعدة البيانات** (Firestore location) اللي اخترتيه، مثلًا `eur3` أو `europe-west1`. لو مش `europe-west1` قوليلي عشان أغيّر منطقة الدالة السحابية.
5. **لقطة شاشة أو نص الخطأ** لو أي أمر من README فشل، و ناتج `flutter analyze`.

## اعمليهم في الكونسول (خطوة بخطوة)

- [ ] أنشئي مشروع جديد على console.firebase.google.com
- [ ] **Authentication ← Sign-in method:** فعّلي **Anonymous** و **Email/Password**
- [ ] **Firestore Database ← Create database** (Production mode)
- [ ] **Storage ← Get started**
- [ ] **Cloud Messaging:** بيتفعل تلقائيًا. للآيفون محتاجة ترفعي APNs key (Project settings ← Cloud Messaging)
- [ ] **الخطة:** حوّلي لـ **Blaze** (الدفع حسب الاستخدام) عشان الدالة السحابية بتاعة الإشعارات. لو مش عايزة دلوقتي، كل حاجة تانية هتشتغل ما عدا زرار الإشعارات
- [ ] اعملي حساب المدير وضيفي مستند `admins/{UID}` (التفاصيل في README خطوة 5)
- [ ] شغّلي أوامر `firebase deploy` اللي في README خطوة 4

## ⛔ ماتبعتيش دول لحد (ولا ليا)

- ملف **service account** (أي JSON فيه `private_key`)
- كلمة سر حساب جوجل أو حساب المدير
- أي مفاتيح من Google Cloud Console ← Credentials غير اللي في `firebase_options.dart`

> ملحوظة: المفاتيح اللي جوه `firebase_options.dart` و `google-services.json` مش سرية — دي بتتحط جوه الأبلكيشن نفسه، والحماية الحقيقية هي قواعد الأمان اللي في مجلد `firebase/`.

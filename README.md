# أحاديث الصغار — الكود الكامل

مشروع فيه أبلكيشنين Flutter بيشتغلوا على نفس قاعدة بيانات Firebase:

| المجلد | إيه هو |
|---|---|
| `apps/kids_app` | أبلكيشن الأطفال (عربي/إنجليزي): النهر والمحطات، الحكايات، الألعاب (سمك، فقاعات، قطار)، حديقة الحسنات، فانوس ومتجره، المهمات، «ما لا يسع أطفال المسلمين جهله» بالفيديو، الملف الشخصي، لوحة الشرف، نسخ ومشاركة |
| `apps/admin_app` | لوحة التحكم: تبويبات من أي نوع، مستويات بعدد مفتوح، أحاديث (مسودة/منشور)، أقسام أسئلة، النجوم والمتجر، رفع صوت وصور، إشعارات، استيراد المحتوى الأولي |
| `packages/hadith_core` | الكود المشترك: النماذج، الاتصال بـ Firestore، حساب النجوم |
| `firebase/` | قواعد الأمان، الفهارس، والدالة السحابية للإشعارات |

> ⚠️ الكود ده اتكتب من غير ما يتجرب على جهاز (مكانش متاح عندي Flutter). أول مرة شغّليه هيبان شوية أخطاء صغيرة غالبًا — ابعتيلي ناتج `flutter analyze` وأنا أصلحها.

---

## 1) تجهيز الجهاز

- Flutter 3.22 أو أحدث (`flutter --version`)
- Node.js 20 (عشان Firebase CLI والدالة السحابية)
- `npm install -g firebase-tools` ثم `firebase login`
- `dart pub global activate flutterfire_cli`

## 2) إنشاء ملفات أندرويد و iOS

الكود فيه `lib/` و `pubspec.yaml` بس. لكل أبلكيشن شغّلي:

```bash
cd apps/kids_app
flutter create . --org com.YOURNAME --project-name kids_app --platforms android,ios
cd ../admin_app
flutter create . --org com.YOURNAME --project-name admin_app --platforms android,ios
```

(غيّري `com.YOURNAME` لاسمك أو اسم شركتك، ده هيبقى الـ package name.)

بعدها:
- **أندرويد:** في `android/app/build.gradle` خلّي `minSdkVersion 23`.
- **iOS (kids_app):** في `ios/Runner/Info.plist` ضيفي:
  - `NSCameraUsageDescription` = «عشان الطفل ياخد صورة لملفه»
  - `NSPhotoLibraryUsageDescription` = «عشان الطفل يختار صورة لملفه»

## 3) ربط Firebase

```bash
cd apps/kids_app && flutterfire configure --project=PROJECT_ID
cd ../admin_app  && flutterfire configure --project=PROJECT_ID
```
ده هيستبدل `lib/firebase_options.dart` المؤقت ببيانات مشروعك ويحط `google-services.json` و `GoogleService-Info.plist` في مكانهم.

## 4) رفع القواعد والدالة

```bash
cd firebase
firebase use --add            # اختاري المشروع
cd functions && npm install && cd ..
firebase deploy --only firestore:rules,firestore:indexes,storage
firebase deploy --only functions     # محتاج خطة Blaze
```

## 5) أول مدير

1. Firebase Console ← Authentication ← Users ← Add user (إيميلك وكلمة سر).
2. افتحي `admin_app` وادخلي — هيقولك «الحساب ده لسه مش مدير» ويعرضلك كود (UID).
3. Firestore ← Start collection ← اسمها `admins` ← Document ID = الكود ده ← حقل `role` = `owner`.
4. اخرجي وادخلي تاني.
5. من لوحة التحكم دوسي **«استيراد المحتوى الأولي»** — هيضيف المستويات، الأربعين النووية كاملة (٤٢)، الأقسام السبعة لـ «ما لا يسع»، وإعدادات النجوم والمتجر.

## 6) التشغيل

```bash
cd apps/admin_app && flutter pub get && flutter run
cd apps/kids_app  && flutter pub get && flutter run
```

---

## إزاي كل حاجة متوصلة

**Firestore:**
```
config/app          إعدادات النجوم ومتجر فانوس
tabs/{id}           التبويبات (type: hadith|qa, mode: levels|open, place: home|tab)
levels/{id}         المستويات (tabId, order)
hadiths/{id}        الأحاديث (tabId, levelId, published, game, story, ...)
qaSections/{id}     أقسام الأسئلة (tabId, items[])
leaderboard/{uid}   لوحة الشرف (اسم أول + شخصية + نجوم + محافظة/حي فقط)
admins/{uid}        المديرين (تتضاف من الكونسول بس)
notificationsLog    سجل الإشعارات (الدالة بتكتبه)
```
**Storage:** `media/` للصوت والصور والفيديو (المدير بس يرفع، والكل يقرأ).

**الخصوصية:**
- تقدم الطفل وملفه وصورته محفوظين **على الجهاز بس**. الصورة عمرها ما بتترفع (قواعد Storage بتمنع أي حاجة برا `media/`).
- لوحة الشرف بموافقة الأهل (بوابة الكبار)، والطفل يقدر يخفي نفسه أو يمسح بياناته.
- الأطفال بيدخلوا بتسجيل مجهول (Anonymous) — مفيش إيميل ولا رقم تليفون.

**النجوم:**
- عادية: لكل لعبة يكسبها + لكل سؤال «عرفتها» (الأرقام من لوحة التحكم).
- ملكية 👑: لكل مستوى يخلّصه، كل N أحاديث من التبويبات المفتوحة، كل قسم أسئلة، كل مهمة يأكدها الأهل، كل شجرة مثمرة.
- متجر فانوس: «السعر» هو عدد النجوم اللي لازم يوصلها عشان يفتح اللون/الزينة (مش بيتخصم).

**الرسومات:** `apps/kids_app/assets/scenes/` فيها رسومات الحكايات (`story_s1..s10`) ومشاهد الفيديو (`video_s0..s6`). المدير يقدر يختار رسمة جاهزة أو يرفع صورة.

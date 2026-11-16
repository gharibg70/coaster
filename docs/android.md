# تطبيق كوستر الجامعة على Android

هذه النسخة تطبيق Android تجريبي يعمل داخل Android WebView باستخدام Capacitor. معرّف الحزمة هو `com.gharibg70.coaster` والحد الأدنى Android 7 / API 24. التطبيق يعيد استخدام واجهة الويب وخدمات Supabase؛ لا يتضمن مفتاح خدمة خاصاً.

## تنزيل APK التجريبي

بعد نجاح تشغيل **Build Android APK** في GitHub Actions، افتح [صفحة تشغيل بناء APK](https://github.com/gharibg70/coaster/actions/workflows/android-apk.yml) في مستودع `gharibg70/coaster` ونزّل artifact باسم `coaster-android-debug`. فك ضغط الملف `app-debug.apk` ثم ثبته على جهاز Android. قد يطلب Android السماح بالتثبيت من مصدر غير معروف للملف الذي استخدمته.

هذا APK موقّع بمفتاح debug، للاختبار والتثبيت اليدوي فقط. لا يحتوي على مفتاح إصدار، ولا يُنشر إلى Google Play، ولا يخرج AAB. لا تستخدم debug APK كإصدار إنتاجي.

## البناء محلياً باستخدام Android Studio

المتطلبات: Node.js 22 أو أحدث، npm 10.9.9، Android Studio المتوافق مع Capacitor 8، Android SDK API 36، وJDK 21 الذي يوفره Android Studio. بعد استنساخ المستودع:

```sh
npm ci
npm run sync:android
cd android
./gradlew assembleDebug
```

ينتج الملف في `android/app/build/outputs/apk/debug/app-debug.apk`. افتح مجلد `android/` في Android Studio إذا أردت تشغيله على جهاز متصل أو محاكي API 24 أو أحدث.

## الموقع والصلاحيات

يطلب التطبيق إذن الموقع التقريبي والدقيق فقط عندما يبدأ المشرف مشاركة موقع الحافلة. لا يطلب إذن الموقع في الخلفية. مشاركة الموقع تتوقف عند إغلاق شاشة المشرف/التطبيق، وتظل مشاركة الويب تستخدم Geolocation في المتصفح.

إشعارات Android الأصلية غير مهيأة في هذه النسخة؛ تحتاج ربط Firebase Cloud Messaging وإعداداً خادمياً مستقلاً. لهذا يعرض التطبيق ذلك بوضوح ولا يحاول إنشاء اشتراك Web Push غير صالح داخل حاوية Android. إشعارات موقع الويب تبقى منفصلة كما كانت.

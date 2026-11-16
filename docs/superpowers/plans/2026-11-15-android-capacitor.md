# خطة تحويل كوستر الجامعة إلى Android عبر Capacitor

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** إضافة منصة Android قابلة للبناء إلى تطبيق React الحالي وإنتاج APK تجريبي قابل للتثبيت، دون تغيير سلوك نسخة GitHub Pages.

**Architecture:** يُعاد استخدام تطبيق Vite الحالي داخل Capacitor 8. يظل بناء الويب كما هو، بينما يمر بناء Android بقاعدة أصول نسبية. يُستخدم Capacitor Geolocation على Android لمسار مشاركة موقع الحافلة، مع إبقاء `navigator.geolocation` للويب. ينتج GitHub Actions APK debug؛ لا تُنشأ مفاتيح توقيع إصدار متجر.

**Tech Stack:** React 18، Vite 5، Capacitor `8.6.2`، Capacitor Geolocation `8.2.4`، Android API 24+، GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-15-android-capacitor.md`

## Global Constraints

- اسم التطبيق «كوستر الجامعة» ومعرّف الحزمة المقترح `com.gharibg70.coaster`.
- تطبيق Android فقط؛ لا iOS ولا نشر إلى Play Store في هذه المرحلة.
- يبقى بناء Pages على `/coaster-react-vite/`؛ قاعدة Android فقط تكون `./`.
- لا يوضع Supabase service-role key أو VAPID private key داخل التطبيق أو workflow.
- Push الأصلي عبر FCM خارج النطاق حتى تتوفر إعدادات Firebase وموافقة تحديث الخادم؛ لا تعرض الواجهة أن Push الأصلي يعمل.
- تذكير الوصول لا يحصل على صلاحية خلفية جديدة؛ يحافظ على وصفه الحالي بأنه تنبيه أثناء بقاء التطبيق نشطاً.
- أداة Android SDK غير متاحة محلياً؛ APK يُبنى عبر GitHub Actions ويُسلم كـartifact بعد نجاح workflow.
- لا يُستخدم إصدار release أو ملف توقيع إنتاجي؛ الناتج APK debug فقط.

## Review Focus

- بناء الويب بعد تهيئة Capacitor: يجب أن تبقى المسارات تشير إلى `/coaster-react-vite/` في Pages؛ يتحقق ذلك بـ`npm test`, `npm run build` وفحص مسارات `dist/index.html`.
- بناء Android: يجب أن تكون الأصول نسبية وأن تظهر الصفحة الرئيسية وملفات CSS/JS؛ يتحقق ذلك ببناء Vite ثم `npx cap sync android` و`./gradlew assembleDebug`.
- رفض إذن الموقع أو إيقاف خدمات الموقع: لا يبدأ التطبيق مشاركة موقع غير مصرح بها، ويعرض خطأ واضحاً؛ يغطيه اختبار محول الموقع واختبار تدفق الرفض.
- عدم دعم Web Push في Android WebView: تعرض واجهة Push توضيحاً صريحاً ولا تحاول إنشاء اشتراك Service Worker؛ يغطيه اختبار اختيار عرض Push حسب المنصة.
- تسرّب المفاتيح: لا تحتوي ملفات المصدر أو حزمة الويب أو APK على أسرار خادم؛ يجري تشغيل فاحص الأسرار على المصدر والبناء، وفحص الملفات المضمنة في APK.

---

### Task 1: تأسيس مشروع Capacitor وبناء Android منفصل عن الويب

**Files:**
- Modify: `package.json`, `package-lock.json`, `vite.config.js`, `src/main.jsx`
- Create: `capacitor.config.json`
- Generate: `android/`
- Test: `tests/capacitorBuildConfig.test.js`

**Interfaces:**
- ينتج الأمر `npm run build:android` ملفات `dist/` بقاعدة نسبية ثم يزامنها إلى `android/`.
- يستخدم Capacitor `appId=com.gharibg70.coaster`, `appName=كوستر الجامعة`, و`webDir=dist` من `capacitor.config.json`.

- [x] اكتب اختباراً يثبت أن إعداد Capacitor يستخدم `dist` والاسم والمعرّف المقترحين، وأن بناء Android يختار قاعدة `./` من دون تغيير قاعدة Pages.
- [x] شغّل الاختبار وتأكد من فشله قبل إضافة الإعداد.
- [x] ثبّت إصدارات Capacitor المحددة، وأنشئ `capacitor.config.json` ومنصة Android، وأضف `build:android` و`sync:android`.
- [x] امنع تسجيل Service Worker على Android فقط، مع استمرار تسجيله على الويب.
- [x] شغّل الاختبار و`npm run build` و`npm run build:android` و`npx cap sync android`.

### Task 2: دعم صلاحية الموقع وإظهار حد Push بوضوح

**Files:**
- Modify: `src/features/admin/AdminView.jsx`, `src/features/notifications/PushSettings.jsx`
- Create: `src/lib/platformGeolocation.js`, `src/lib/locationRuntime.js`, `src/lib/pushPlatform.js`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `package.json`, `package-lock.json`
- Test: `tests/platformFeatures.test.js`, `tests/capacitorBuildConfig.test.js`

**Interfaces:**
- `createGeolocationController({ platform, nativeGeolocation, webGeolocation }).watch(onPosition, onError, options)` يعيد `{ platform, id }` بعد الحصول على صلاحية الموقع في Android.
- `clearLocationWatch(handle)` ينهي مراقبة Capacitor أو المتصفح المناسبة دون خلط معرّفاتها.

- [x] اكتب اختبارات لمساري Native/Web، وإذن الموقع المرفوض، وإلغاء المراقبة، ورسالة Push غير المدعوم.
- [x] شغّل الاختبارات وتأكد من فشلها قبل التعديل.
- [x] أضف Capacitor Geolocation، واطلب إذن النظام قبل بدء مشاركة موقع الحافلة، مع تنظيف الـwatch عند الإيقاف أو مغادرة العرض. يعلن Android coarse/fine location فقط ولا يعلن background location.
- [x] على Android، اعرض رسالة عربية بأن Push الأصلي غير مهيأ؛ أبقِ واجهة Push الحالية للويب دون تعديل.
- [x] شغّل الاختبارات و`npm test` و`npm run build:android` و`npx cap sync android`.

### Task 3: إنشاء APK تجريبي آلي وتسليم تعليمات تثبيته

**Files:**
- Create: `.github/workflows/android-apk.yml`
- Create: `docs/android.md`
- Use: `public/icon-512.png` لإنتاج موارد launcher وadaptive icon في `android/app/src/main/res/mipmap-*`.

**Interfaces:**
- يرفع workflow ملف `app-debug.apk` كـGitHub Actions artifact باسم `coaster-android-debug`.
- مشغل البناء يستخدم Node 22 وAndroid SDK المتوافق مع Capacitor 8، ويعيد استخدام إعدادات Supabase العميل العامة الموجودة في بناء Pages فقط.

- [x] جهّز أيقونة Android من شعار PWA الحالي واسم التطبيق العربي، وأضف foreground شفافاً للأيقونة التكيفية وخلفية خضراء متوافقة.
- [x] أضف workflow يُشغّل بـ`workflow_dispatch` وعند تغييرات التطبيق ذات الصلة؛ ينفذ `npm ci` وبناء/مزامنة Capacitor و`./gradlew assembleDebug` ثم يفحص أسرار APK ومعرّفه وأذوناته قبل رفعه.
- [x] أضف تعليمات فتح المشروع وبناء APK محلياً من Android Studio وتثبيت APK التجريبي، مع التنبيه أنه غير مهيأ للنشر في المتجر وأن Push الأصلي يحتاج Firebase.
- [ ] تحقق من اختبارات الويب وفاحص أسرار العميل والبناء، ثم ادفع التغييرات إلى المستودع المعتمد وانتظر workflow.
- [ ] نزّل artifact، تحقق من وجود APK وصحة محتواه الأساسي، ثم أرفقه للمستخدم.

## ملاحظات مراجعة ذاتية

- المسارات المنفصلة تمنع `base: './'` من الوصول إلى نسخة Pages.
- صلاحية الموقع المطلوبة هي foreground فقط؛ لا تُطلب background location.
- يوجد اعتماد خارجي لازم لإشعارات Android الأصلية وهو Firebase `google-services.json`، لذلك صيغت هذه الميزة كعمل لاحق لا كجزء مخفي من APK الأول.
- رمز الحزمة اختيار مادي قبل أول نشر متجر؛ المطلوب الآن APK تجريبي فقط، ويمكن تغيير المعرّف قبل اعتماد إصدار متجر.

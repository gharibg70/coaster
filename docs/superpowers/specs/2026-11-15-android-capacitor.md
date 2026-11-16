# مواصفة تحويل كوستر الجامعة إلى تطبيق Android عبر Capacitor

**الحالة:** معتمدة للتنفيذ؛ APK تجريبي فقط، دون نشر إلى Google Play.

## الهدف

تغليف تطبيق React 18 + Vite الحالي كتطبيق Android هجين عبر Capacitor، مع إعادة استخدام الواجهة والخدمات الموجودة والإبقاء على موقع GitHub Pages كما هو.

## نطاق النسخة الأولى

- منصة Android فقط؛ لا يشمل iOS.
- اسم التطبيق: **كوستر الجامعة**.
- معرّف Android المقترح: `com.gharibg70.coaster`. هذا المعرّف ثابت عملياً بعد نشر التطبيق للمتجر، لذا يجب اعتماده قبل توليد ملفات Android.
- استعمال Capacitor `8.6.2` للـcore وCLI وAndroid؛ و`@capacitor/geolocation` `8.2.4` لمسار الموقع الأصلي. هذه أحدث الإصدارات التي أرجعها npm بتاريخ 15 نوفمبر 2026.
- حد Android الأدنى API 24، وفق توثيق Capacitor 8. ضبط `vite.config.js` بحيث تستخدم نسخة Android مسارات نسبية للأصول، مع إبقاء قاعدة GitHub Pages `/coaster-react-vite/` دون تغيير.
- توليد مشروع `android/` وإنتاج **APK تجريبي موقّع بمفتاح debug** عبر GitHub Actions وتنزيله كـartifact. هذا ليس ملف إصدار متجر Play، ولا يتضمن مفتاح توقيع إنتاجي.
- استخدام أيقونات PWA الحالية `public/icon-192.png` و`public/icon-512.png` في موارد التطبيق إن كان شكلها مناسباً.
- تحويل استدعاءات تحديد الموقع الموجودة إلى محول يختار Capacitor Geolocation داخل Android ويبقي `navigator.geolocation` على الويب، مع طلب إذن الموقع من النظام وشرح الاستخدام للمشرف.
- استمرار استخدام Supabase الحالية وإعداداتها العامة نفسها. لا يوضع service-role key أو أي مفتاح خاص داخل التطبيق.
- يبقى إصدار الويب وPWA وإشعاراته الحالية دون تغيير.

## حدود الإشعارات

إشعارات الويب الحالية تعتمد على Service Worker و`PushManager`. إشعارات Android الأصلية عبر Capacitor تعتمد FCM وتتطلب مشروع Firebase وملف `google-services.json` وربطاً بين FCM tokens وخادم الإرسال. لا يتوفر هذا الإعداد ضمن المستودع الحالي؛ لذلك لا تدّعي النسخة الأولى أن Push الأصلي يعمل. تعرض واجهة Android رسالة واضحة عن عدم توفر Push الأصلي بدلاً من تجربة اشتراك ويب مضللة. تبقى هذه المهمة مرحلة لاحقة مستقلة بعد توفير إعداد Firebase والموافقة على تحديث مسار الإرسال الخلفي.

تذكير الوصول الحالي معلن بأنه يعمل أثناء بقاء الصفحة نشطة ولا يضمن الخلفية. يُحفظ هذا القيد؛ لا يضاف تتبع خلفي ولا طلب صلاحية خلفية غير ضرورية في النسخة الأولى.

## قيود البيئة

Node المتوفر `22.13.0` ويلبي شرط Capacitor 8 الرسمي `Node 22+`. لا توجد في بيئة العمل الحالية Android Studio أو Android SDK أو `sdkmanager` أو `adb` أو `gradle`؛ لذلك يُنفّذ بناء APK على GitHub Actions بدلاً من الادعاء بأن بناءً محلياً تم. يشترط إعداد CI لـAndroid Studio/SDK أو ما يعادله، مع الإبقاء على فحوص الويب الحالية.

## معايير القبول

- البناء الحالي لـGitHub Pages يبقى على مساره الحالي دون تغيير، وتنجح اختبارات المشروع وفاحص الأسرار.
- `npx cap sync android` ينجح بعد بناء أصول Android بمسارات صحيحة.
- يحوي APK اسم التطبيق ومعرّف التطبيق المقترح ويبدأ إلى الواجهة العربية RTL.
- تسجيل الدخول والقراءة/الكتابة المعتادة إلى Supabase تبقى باستخدام إعدادات العميل العامة، ولا يظهر مفتاح service-role في المصدر أو الحزمة.
- يطلب تتبع موقع الحافلة إذن الموقع عند الحاجة ويعمل عبر Capacitor على Android؛ ويبقى مسار الويب كما هو.
- واجهة Push على Android تشرح عدم إعداد الإشعارات الأصلية؛ لا تسجل اشتراك Push وهمياً ولا ترسل طلبات غير مدعومة.
- ينجح GitHub Actions في تجميع APK debug ورفعه كـartifact قابل للتنزيل. لا يُنشر التطبيق إلى متجر Play ولا يُنشأ مفتاح توقيع إنتاجي.

## المراجع

[1]: https://capacitorjs.com/docs/getting-started "Installing Capacitor into an existing web app"
[2]: https://capacitorjs.com/docs/android "Capacitor Android Documentation v8"
[3]: https://capacitorjs.com/docs/getting-started/environment-setup "Capacitor Environment Setup v8"
[4]: https://capacitorjs.com/docs/apis/push-notifications "Capacitor Push Notifications API v8"
[5]: https://capacitorjs.com/docs/apis/geolocation "Capacitor Geolocation API v8"
[6]: https://capacitorjs.com/docs/cli/commands/build "Capacitor CLI build command"
[7]: https://www.npmjs.com/package/@capacitor/core "Capacitor Core package"

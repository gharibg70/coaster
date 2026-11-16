# إصدار iOS أصلي للاستخدام الشخصي عبر SideStore أو AltStore Classic

نسخة iOS الحالية تطبيق أصلي بالكامل مبني بـ **SwiftUI**. لا تستخدم React أو Vite أو `WKWebView` أو Capacitor runtime داخل التطبيق. يتصل التطبيق بـ Supabase عبر `URLSession`، ويحفظ جلسة الدخول محلياً، ويستخدم `CoreLocation` للموقع أثناء مشاركة المشرف فقط.

## الحصول على IPA

1. افتح مستودع [`gharibg70/coaster`](https://github.com/gharibg70/coaster) ثم تبويب **Actions**.
2. شغّل **Build iOS IPA** يدوياً أو استخدم آخر تشغيل ناجح.
3. نزّل artifact باسم `coaster-ios-unsigned-ipa`.
4. فك ضغط artifact ثم استورد `coaster-ios-unsigned.ipa` في SideStore أو AltStore Classic.

الـIPA غير موقع بتوقيع توزيع Apple. لا يحتوي المشروع أو GitHub Actions على Apple ID أو كلمة مرور أو شهادة أو مفتاح خاص أو Provisioning Profile.

## SideStore وLiveContainer

عند تحديث التطبيق، احذف النسخة القديمة أولاً. إذا استُخدم LiveContainer فاحذف حاوية التطبيق أو بيانات WebView القديمة إن كان الخيار متاحاً، ثم أغلق LiveContainer تماماً قبل استيراد IPA الجديد. لا تختبر IPA قديماً وتستنتج منه نتيجة النسخة الجديدة؛ تحقّق من SHA-256 الذي يرافق كل artifact.

## الصلاحيات والحدود

يعمل التطبيق على iOS 15 فأحدث، ويحافظ على الواجهة العربية RTL، ومعرّف الحزمة `com.gharibg70.coaster`. يطلب `NSLocationWhenInUseUsageDescription` فقط عند تشغيل مشاركة موقع الحافلة. لا توجد صلاحية موقع في الخلفية ولا `UIBackgroundModes`.

الإشعارات الأصلية غير مهيأة لأنها تحتاج APNs وإعداداً خادمياً مستقلاً. موقع الويب ونسخة Android APK منفصلان ولا يتأثران بتحويل نسخة iOS إلى SwiftUI.

الحساب المجاني يحتاج عادةً إلى **Refresh كل 7 أيام**، وAltStore Classic يحد التطبيقات الجانبية النشطة إلى **3 تطبيقات**. في iOS 16 فأحدث فعّل **Developer Mode**. لا ترسل كلمة مرور Apple ID إلى المستودع أو GitHub Actions أو أي مساعد.

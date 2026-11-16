# مواصفة دعم iOS وAltStore Classic

## الهدف
إضافة هدف Capacitor iOS إلى مشروع كوستر الجامعة مع إبقاء موقع Vite وAndroid APK مستقلين، وإنتاج IPA لجهاز iPhone غير موقع بتوقيع توزيع Apple ليعاد توقيعه محلياً عبر AltStore Classic.

## القيود
- Capacitor و`@capacitor/ios`: 8.6.2، و`@capacitor/geolocation`: 8.2.4.
- الحد الأدنى iOS 15.0، المعرّف `com.gharibg70.coaster` والاسم العربي «كوستر الجامعة».
- الموقع أثناء الاستخدام فقط عبر `NSLocationWhenInUseUsageDescription`؛ لا موقع خلفي ولا `UIBackgroundModes`.
- لا Apple ID أو شهادة أو مفتاح خاص أو Provisioning Profile في المستودع أو CI.
- iOS Push يعيد `native-not-configured` حتى تهيئة APNs خارج هذا النطاق.
- وضع iOS يكشف متغيرات Supabase العامة المعتمدة فقط.

## معيار القبول
تمر اختبارات المنصات وفاحص IPA، ويُبنى IPA على macOS مع Xcode 26+ عبر `CODE_SIGNING_ALLOWED=NO`، ثم يُرفع artifact باسم `coaster-ios-unsigned-ipa`. يبقى Android وPages دون تغيير وظيفي.

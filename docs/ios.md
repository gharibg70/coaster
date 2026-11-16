# إصدار iOS للاستخدام الشخصي عبر AltStore Classic

ينتج Workflow **Build iOS IPA** ملف `coaster-ios-unsigned.ipa` للاستخدام الشخصي. هذا ملف IPA تجريبي غير موقع بتوقيع توزيع Apple، ولا يثبت مباشرة بالنقر عليه مثل APK. لا يحتوي المشروع أو GitHub Actions على Apple ID أو كلمة مرور أو شهادة أو مفتاح خاص أو Provisioning Profile.

## الحصول على الملف

1. افتح مستودع [`gharibg70/coaster`](https://github.com/gharibg70/coaster) ثم تبويب **Actions**.
2. شغّل **Build iOS IPA** يدوياً، أو انتظر تشغيله بعد تغيير ملفات التطبيق ذات الصلة على `main`.
3. بعد نجاح التشغيل نزّل artifact باسم `coaster-ios-unsigned-ipa`. إذا نُزّل كملف ZIP من GitHub، فك ضغطه للحصول على `coaster-ios-unsigned.ipa`.
4. استورد ملف IPA محلياً في AltStore Classic على iPhone، ليعيد AltStore/AltServer توقيعه محلياً باستخدام Apple ID الذي تدخله أنت على جهازك. لا ترسل كلمة المرور إلى المشروع أو GitHub Actions أو أي مساعد.

ثبّت AltStore عبر AltServer على macOS أو Windows، ووافق على الثقة بالمطور إذا طلب iOS ذلك. في iOS 16 فأحدث فعّل **Developer Mode**. يجب أن يبقى AltServer متاحاً عبر USB أو نفس شبكة Wi‑Fi عند تحديث التطبيقات.

الحساب المجاني يحتاج عادةً إلى **Refresh كل 7 أيام**، وAltStore Classic يحد التطبيقات الجانبية النشطة إلى **3 تطبيقات**. لا يعمل هذا IPA على iPhone من دون AltStore أو مسار توقيع Apple صالح، ولا يعني نجاح الـWorkflow أن التثبيت على جهازك تم فعلياً.

## حدود هذه النسخة

يعمل التطبيق على iOS 15 فأحدث، ويحافظ على واجهة RTL العربية ومعرّف الحزمة `com.gharibg70.coaster`. يطلب إذن الموقع فقط عند تشغيل مشاركة المشرف لموقع الحافلة، ولا يطلب صلاحية موقع في الخلفية ولا يشارك الموقع في الخلفية.

الإشعارات الأصلية في iOS غير مهيأة؛ فهي تحتاج APNs وإعداداً خادمياً مستقلاً. لذلك لا تتوقع Push native من نسخة iOS هذه. يبقى موقع الويب وإشعارات الويب ونسخة Android APK مسارات مستقلة.

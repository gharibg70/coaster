# خطة تنفيذ iOS وIPA غير موقع

1. إضافة حزمة Capacitor iOS ومشروع Xcode المصدر، والتحقق من هوية التطبيق وiOS 15.
2. مشاركة مسار Capacitor الأصلي للموقع الجغرافي بين Android وiOS، مع اختبارات الإذن والمراقبة والمسح، وإبقاء الويب على Browser Geolocation.
3. منع Web Push داخل iOS وإضافة فحص الأسرار إلى اختبارات المنصة.
4. بناء فاحص IPA مستقل يعيد استخدام `scanClientText`، ويتحقق من ZIP والمسارات والحدود والبنية وInfo.plist وغياب provisioning profile.
5. إضافة Workflow macOS مستقل: Node 22، Xcode 26+، build/sync iOS، بناء جهاز غير موقع، تحقق، فحص ورفع artifact.
6. توثيق تنزيل artifact واستيراده في AltStore Classic، مع حدود الحساب المجاني وDeveloper Mode وغياب APNs.
7. تشغيل الاختبارات الكاملة، فحوص الأسرار وبناء الويب وAndroid محلياً حيث تسمح الأدوات؛ يظل بناء Xcode الحاسم مسؤولية CI macOS.

import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';

const project = new URL('../ios/App/', import.meta.url);
const native = readFileSync(new URL('App/NativeApp.swift', project), 'utf8');
const student = readFileSync(new URL('App/NativeStudent.swift', project), 'utf8');
const insights = readFileSync(new URL('App/NativeInsights.swift', project), 'utf8');
const chat = readFileSync(new URL('App/NativeChat.swift', project), 'utf8');
const admin = readFileSync(new URL('App/NativeAdmin.swift', project), 'utf8');
const security = readFileSync(new URL('App/NativeSecurity.swift', project), 'utf8');
const osm = readFileSync(new URL('App/NativeOSMMap.swift', project), 'utf8');
const app = readFileSync(new URL('App/CoasterApp.swift', project), 'utf8');
const pbx = readFileSync(new URL('App.xcodeproj/project.pbxproj', project), 'utf8');
const plist = readFileSync(new URL('App/Info.plist', project), 'utf8');

test('ios_target_has_a_swiftui_entrypoint_and_native_services', () => {
  assert.match(app, /@main/);
  assert.match(app, /struct CoasterApp: App/);
  assert.match(native, /struct LoginView: View/);
  assert.match(native, /URLSession\.shared/);
  assert.match(native, /CLLocationManager/);
  assert.match(native, /func signUp\(name: String/);
  assert.match(native, /redeem\(code: code\)/);
  assert.match(native, /حساب جديد/);
  assert.match(student, /struct StudentHomeView: View/);
  assert.match(student, /struct NativeBusMapView: View/);
  assert.match(student, /set_my_attendance/);
  assert.match(student, /get_seats/);
  assert.match(student, /setWeeklyDefault/);
  assert.match(student, /جدولي الثابت/);
  assert.match(student, /NativeOSMMapView/);
  assert.match(insights, /NativeInsightsView/);
  assert.match(insights, /get_road_pulse/);
  assert.match(insights, /NativeArrivalReminderView/);
  assert.match(insights, /radiusMeters/);
  assert.match(chat, /chat_room_access/);
  assert.match(chat, /send_chat_room_message/);
  assert.match(chat, /report_student_chat_room_message/);
  assert.match(chat, /struct NativeChatView: View/);
  assert.match(admin, /admin_create_codes/);
  assert.match(admin, /admin_list_student_chat_reports/);
  assert.match(admin, /admin_delete_student_chat_message/);
  assert.match(admin, /struct NativeAdminDashboard: View/);
  assert.match(security, /SecItemAdd/);
  assert.match(security, /requestAuthorization/);
  assert.match(security, /didRegisterForRemoteNotificationsWithDeviceToken/);
  assert.match(native, /upsertAPNSDevice/);
  assert.match(native, /updateBusLocation/);
  assert.match(native, /push_devices/);
  assert.match(admin, /admin_renew_subscription/);
  assert.match(admin, /admin_set_seat_capacity/);
  assert.match(admin, /admin_set_destination/);
  assert.match(osm, /tile\.openstreetmap\.org/);
  assert.match(osm, /OpenStreetMap contributors/);
  assert.doesNotMatch(student, /Map\(/);
  assert.doesNotMatch(native, /set\(response\.accessToken, forKey: accessTokenKey\)/);
  assert.doesNotMatch(native, /coaster\.native\.userId/);
  assert.doesNotMatch(native, /WKWebView|Capacitor/);
});

test('ios_target_does_not_compile_or_link_capacitor_webview_sources', () => {
  assert.match(pbx, /CoasterApp\.swift in Sources/);
  assert.match(pbx, /NativeApp\.swift in Sources/);
  assert.match(pbx, /NativeStudent\.swift in Sources/);
  assert.match(pbx, /NativeInsights\.swift in Sources/);
  assert.match(pbx, /NativeChat\.swift in Sources/);
  assert.match(pbx, /NativeAdmin\.swift in Sources/);
  assert.match(pbx, /NativeSecurity\.swift in Sources/);
  assert.match(pbx, /NativeOSMMap\.swift in Sources/);
  assert.doesNotMatch(pbx, /CapApp-SPM|Capacitor|capacitor\.config|public in Resources/);
  assert.equal(existsSync(new URL('CapApp-SPM/', project)), false);
});

test('native_ios_keeps_identity_and_foreground_location_permission', () => {
  assert.match(plist, /<key>CFBundleDisplayName<\/key>\s*<string>كوستر الجامعة<\/string>/);
  assert.match(plist, /<key>NSLocationWhenInUseUsageDescription<\/key>/);
  assert.doesNotMatch(plist, /NSLocationAlways|UIBackgroundModes/);
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';

const project = new URL('../ios/App/', import.meta.url);
const native = readFileSync(new URL('App/NativeApp.swift', project), 'utf8');
const student = readFileSync(new URL('App/NativeStudent.swift', project), 'utf8');
const app = readFileSync(new URL('App/CoasterApp.swift', project), 'utf8');
const pbx = readFileSync(new URL('App.xcodeproj/project.pbxproj', project), 'utf8');
const plist = readFileSync(new URL('App/Info.plist', project), 'utf8');

test('ios_target_has_a_swiftui_entrypoint_and_native_services', () => {
  assert.match(app, /@main/);
  assert.match(app, /struct CoasterApp: App/);
  assert.match(native, /struct LoginView: View/);
  assert.match(native, /URLSession\.shared/);
  assert.match(native, /CLLocationManager/);
  assert.match(student, /struct StudentHomeView: View/);
  assert.match(student, /struct NativeBusMapView: View/);
  assert.match(student, /set_my_attendance/);
  assert.match(student, /get_seats/);
  assert.match(student, /Map\(/);
  assert.doesNotMatch(native, /WKWebView|Capacitor/);
});

test('ios_target_does_not_compile_or_link_capacitor_webview_sources', () => {
  assert.match(pbx, /CoasterApp\.swift in Sources/);
  assert.match(pbx, /NativeApp\.swift in Sources/);
  assert.match(pbx, /NativeStudent\.swift in Sources/);
  assert.doesNotMatch(pbx, /CapApp-SPM|Capacitor|capacitor\.config|public in Resources/);
  assert.equal(existsSync(new URL('CapApp-SPM/', project)), false);
});

test('native_ios_keeps_identity_and_foreground_location_permission', () => {
  assert.match(plist, /<key>CFBundleDisplayName<\/key>\s*<string>كوستر الجامعة<\/string>/);
  assert.match(plist, /<key>NSLocationWhenInUseUsageDescription<\/key>/);
  assert.doesNotMatch(plist, /NSLocationAlways|UIBackgroundModes/);
});

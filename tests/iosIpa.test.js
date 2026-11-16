import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const checker = join(root, 'scripts/check-ios-ipa.mjs');

function createIpa(directory, entries) {
  const archive = join(directory, 'fixture.ipa');
  const script = [
    'import sys, zipfile',
    'with zipfile.ZipFile(sys.argv[1], "w", compression=zipfile.ZIP_DEFLATED) as z:',
    '    for pair in sys.argv[2:]:',
    '        name, value = pair.split("=", 1)',
    '        z.writestr(name, value.encode("utf-8"))',
  ].join('\n');
  execFileSync('python3', ['-c', script, archive, ...entries]);
  return archive;
}

function runChecker(archive) {
  try {
    return { output: execFileSync(process.execPath, [checker, archive], { cwd: root, encoding: 'utf8' }) };
  } catch (error) {
    return { error, output: `${error.stdout || ''}${error.stderr || ''}` };
  }
}

const plist = '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>CFBundleIdentifier</key><string>com.gharibg70.coaster</string><key>CFBundleDisplayName</key><string>كوستر الجامعة</string><key>MinimumOSVersion</key><string>15.0</string><key>NSLocationWhenInUseUsageDescription</key><string>يستخدم كوستر الجامعة موقعك أثناء مشاركة المشرف لموقع الحافلة لعرضها للطلاب.</string></dict></plist>';

test('IPA scanner accepts a minimal valid unsigned device archive', (t) => {
  const temp = mkdtempSync(join(tmpdir(), 'coaster-test-ipa-'));
  t.after(() => rmSync(temp, { recursive: true, force: true }));
  const result = runChecker(createIpa(temp, ['Payload/App.app/Info.plist=' + plist, 'Payload/App.app/index.html=ok']));
  assert.equal(result.error, undefined, result.output);
  assert.match(result.output, /iOS IPA check passed/);
});

test('IPA scanner rejects forbidden secret material without printing its value', (t) => {
  const temp = mkdtempSync(join(tmpdir(), 'coaster-test-ipa-'));
  t.after(() => rmSync(temp, { recursive: true, force: true }));
  const secret = 'sb_secret_abcdefghijklmnop';
  const result = runChecker(createIpa(temp, ['Payload/App.app/Info.plist=' + plist, 'Payload/App.app/assets.js=' + secret]));
  assert.ok(result.error);
  assert.match(result.output, /high_confidence_credential_token/);
  assert.doesNotMatch(result.output, new RegExp(secret));
});

test('IPA scanner rejects malformed archives and unsafe paths', (t) => {
  const temp = mkdtempSync(join(tmpdir(), 'coaster-test-ipa-'));
  t.after(() => rmSync(temp, { recursive: true, force: true }));
  const malformed = join(temp, 'bad.ipa');
  execFileSync('node', ['-e', "require('fs').writeFileSync(process.argv[1], 'not zip')", malformed]);
  assert.match(runChecker(malformed).output, /preflight|ZIP|archive/i);
  const unsafe = createIpa(temp, ['../outside=bad']);
  assert.match(runChecker(unsafe).output, /unsafe archive path/);
});

test('IPA scanner rejects provisioning profiles and missing app payload', (t) => {
  const temp = mkdtempSync(join(tmpdir(), 'coaster-test-ipa-'));
  t.after(() => rmSync(temp, { recursive: true, force: true }));
  assert.match(runChecker(createIpa(temp, ['Payload/App.app/Info.plist=' + plist, 'Payload/App.app/embedded.mobileprovision=profile'])).output, /provisioning profile/i);
  assert.match(runChecker(createIpa(temp, ['Payload/readme.txt=missing app'])).output, /Payload\/\*\.app|application bundle/i);
});

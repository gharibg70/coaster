import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('..', import.meta.url)));
const checker = join(root, 'scripts/check-android-apk.mjs');

function createApkFixture(directory, contents, encoding = 'utf-8', entryName = 'classes.dex') {
  const archive = join(directory, 'test.apk');
  execFileSync('python3', ['-c', [
    'import sys, zipfile',
    'data = b"A" * int(sys.argv[2].split(":", 1)[1]) if sys.argv[2].startswith("repeat:") else sys.argv[2].encode(sys.argv[3]) + b"\\x00\\x01"',
    'with zipfile.ZipFile(sys.argv[1], "w", compression=zipfile.ZIP_DEFLATED) as z: z.writestr(sys.argv[4], data)',
  ].join('\n'), archive, contents, encoding, entryName]);
  return archive;
}

test('APK scanner detects server credentials in binary archive members without printing the value', (t) => {
  const temp = mkdtempSync(join(tmpdir(), 'coaster-test-apk-'));
  t.after(() => rmSync(temp, { recursive: true, force: true }));
  const secret = 'sb_secret_abcdefghijklmnop';
  const archive = createApkFixture(temp, `credential=${secret}`);
  let error;
  try {
    execFileSync(process.execPath, [checker, archive], { cwd: root, encoding: 'utf8' });
  } catch (caught) {
    error = caught;
  }
  assert.ok(error, 'the APK scan must fail when it finds a server credential');
  assert.match(error.stderr, /high_confidence_credential_token/);
  assert.doesNotMatch(`${error.stdout || ''}${error.stderr || ''}`, new RegExp(secret));
});

test('APK scanner allows public Supabase client configuration', (t) => {
  const temp = mkdtempSync(join(tmpdir(), 'coaster-test-apk-'));
  t.after(() => rmSync(temp, { recursive: true, force: true }));
  const archive = createApkFixture(temp, 'VITE_SUPABASE_ANON_KEY=sb_publishable_publicclientvalue');
  const output = execFileSync(process.execPath, [checker, archive], { cwd: root, encoding: 'utf8' });
  assert.match(output, /Android APK secret check passed/);
});

test('APK scanner detects UTF-16LE credentials in binary archive members', (t) => {
  const temp = mkdtempSync(join(tmpdir(), 'coaster-test-apk-'));
  t.after(() => rmSync(temp, { recursive: true, force: true }));
  const secret = 'sb_secret_abcdefghijklmnop';
  const archive = createApkFixture(temp, `credential=${secret}`, 'utf-16le');
  let error;
  try {
    execFileSync(process.execPath, [checker, archive], { cwd: root, encoding: 'utf8' });
  } catch (caught) {
    error = caught;
  }
  assert.ok(error, 'the APK scan must detect UTF-16LE credential strings');
  assert.match(error.stderr, /high_confidence_credential_token/);
  assert.doesNotMatch(`${error.stdout || ''}${error.stderr || ''}`, new RegExp(secret));
});

test('APK scanner rejects excessive compression ratios before extracting', (t) => {
  const temp = mkdtempSync(join(tmpdir(), 'coaster-test-apk-'));
  t.after(() => rmSync(temp, { recursive: true, force: true }));
  const archive = createApkFixture(temp, 'repeat:1048576');
  let error;
  try {
    execFileSync(process.execPath, [checker, archive], { cwd: root, encoding: 'utf8' });
  } catch (caught) {
    error = caught;
  }
  assert.ok(error, 'the APK scan must reject zip-bomb-like entries');
  assert.match(error.stderr, /compression-ratio limit/);
});

test('APK scanner rejects unsafe archive paths before extracting', (t) => {
  const temp = mkdtempSync(join(tmpdir(), 'coaster-test-apk-'));
  t.after(() => rmSync(temp, { recursive: true, force: true }));
  const archive = createApkFixture(temp, 'safe text', 'utf-8', '../outside.dex');
  let error;
  try {
    execFileSync(process.execPath, [checker, archive], { cwd: root, encoding: 'utf8' });
  } catch (caught) {
    error = caught;
  }
  assert.ok(error, 'the APK scan must reject paths outside the extraction directory');
  assert.match(error.stderr, /unsafe archive path/);
});

test('APK scanner rejects duplicate archive entries', (t) => {
  const temp = mkdtempSync(join(tmpdir(), 'coaster-test-apk-'));
  t.after(() => rmSync(temp, { recursive: true, force: true }));
  const archive = join(temp, 'duplicate.apk');
  execFileSync('python3', ['-c', [
    'import sys, warnings, zipfile',
    'with warnings.catch_warnings():',
    '    warnings.simplefilter("ignore")',
    '    with zipfile.ZipFile(sys.argv[1], "w") as z:',
    '        z.writestr("classes.dex", b"first")',
    '        z.writestr("classes.dex", b"second")',
  ].join('\n'), archive]);
  let error;
  try {
    execFileSync(process.execPath, [checker, archive], { cwd: root, encoding: 'utf8' });
  } catch (caught) {
    error = caught;
  }
  assert.ok(error, 'the APK scan must reject ambiguous duplicate members');
  assert.match(error.stderr, /duplicate archive paths/);
});

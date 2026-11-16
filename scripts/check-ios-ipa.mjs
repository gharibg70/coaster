import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs';
import { basename, join, relative, resolve, sep } from 'node:path';
import { pathToFileURL } from 'node:url';
import { scanClientText } from './check-client-secrets.mjs';

const ROOT = resolve(import.meta.dirname || new URL('.', import.meta.url).pathname, '..');
const PREFLIGHT = join(ROOT, 'scripts/inspect-ios-archive.py');
const MAX_TEXT_FILE = 20 * 1024 * 1024;

function listFiles(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? listFiles(path) : [path];
  });
}

function parsePlist(plistPath) {
  try {
    return JSON.parse(execFileSync('python3', ['-c', [
      'import json, plistlib, sys',
      'with open(sys.argv[1], "rb") as f: data = plistlib.load(f)',
      'print(json.dumps(data, ensure_ascii=False))',
    ].join('\n'), plistPath], { encoding: 'utf8' }));
  } catch {
    throw new Error('Info.plist is missing or invalid.');
  }
}

export function scanIpa(ipaPath) {
  const archive = resolve(ipaPath);
  if (!existsSync(archive)) throw new Error('IPA file does not exist.');
  let metadata;
  try {
    metadata = JSON.parse(execFileSync('python3', [PREFLIGHT, archive], { encoding: 'utf8', maxBuffer: 4 * 1024 * 1024 }));
  } catch (error) {
    throw new Error(error.stderr?.toString().trim() || 'IPA archive preflight failed.');
  }
  execFileSync('unzip', ['-tq', archive], { stdio: 'pipe' });
  const temp = mkdtempSync(join(resolve(process.env.TMPDIR || '/tmp'), 'coaster-ios-ipa-'));
  try {
    execFileSync('unzip', ['-q', archive, '-d', temp], { stdio: 'pipe' });
    const payload = join(temp, 'Payload');
    if (!existsSync(payload)) throw new Error('IPA must contain a Payload directory.');
    const apps = readdirSync(payload).filter((name) => name.endsWith('.app') && statSync(join(payload, name)).isDirectory());
    if (!apps.length) throw new Error('IPA must contain at least one Payload/*.app application bundle.');
    const app = join(payload, apps[0]);
    const plistPath = join(app, 'Info.plist');
    const plist = parsePlist(plistPath);
    if (plist.CFBundleIdentifier !== 'com.gharibg70.coaster') throw new Error('Info.plist bundle identifier is not approved.');
    if (plist.CFBundleDisplayName !== 'كوستر الجامعة') throw new Error('Info.plist display name is not approved.');
    if (plist.NSLocationWhenInUseUsageDescription !== 'يستخدم كوستر الجامعة موقعك أثناء مشاركة المشرف لموقع الحافلة لعرضها للطلاب.') throw new Error('Info.plist location usage description is missing or incorrect.');
    if (plist.NSLocationAlwaysAndWhenInUseUsageDescription || plist.NSLocationAlwaysUsageDescription || plist.UIBackgroundModes) throw new Error('Background or always-on location permissions are not allowed.');
    const names = metadata.entries;
    if (names.some((name) => /(?:^|\/)embedded\.mobileprovision$|\.mobileprovision$/i.test(name))) throw new Error('Provisioning profile material is not allowed in IPA.');
    const findings = [];
    for (const file of listFiles(temp)) {
      const bytes = readFileSync(file);
      if (bytes.length > MAX_TEXT_FILE) continue;
      const name = `IPA:${relative(temp, file).split(sep).join('/')}`;
      const unique = new Map();
      const collect = (text) => scanClientText(name, text).forEach((finding) => unique.set(`${finding.reason}:${finding.identifier || ''}`, finding));
      collect(bytes.toString('latin1'));
      collect(bytes.toString('utf8'));
      if (bytes.length % 2 === 0) {
        collect(bytes.toString('utf16le'));
        const bigEndian = Buffer.from(bytes); bigEndian.swap16(); collect(bigEndian.toString('utf16le'));
      }
      findings.push(...unique.values());
    }
    return { entries: names, plist, findings };
  } finally {
    rmSync(temp, { recursive: true, force: true });
  }
}

function main() {
  const ipaPath = process.argv[2];
  if (!ipaPath) { console.error('Usage: node scripts/check-ios-ipa.mjs <ipa-path>'); process.exitCode = 2; return; }
  try {
    const { entries, findings } = scanIpa(ipaPath);
    if (findings.length) {
      console.error(`iOS IPA secret check failed (${findings.length} redacted finding(s)):`);
      findings.forEach((finding) => console.error(`- ${finding.file}: ${finding.reason}${finding.identifier ? ` (${finding.identifier})` : ''}`));
      process.exitCode = 1; return;
    }
    console.log(`iOS IPA check passed: ${basename(resolve(ipaPath))} (${entries.length} archive entries scanned).`);
  } catch (error) { console.error(`iOS IPA check failed: ${error.message}`); process.exitCode = 1; }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) main();

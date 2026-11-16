import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, join, relative, resolve, sep } from 'node:path';
import { pathToFileURL } from 'node:url';
import { scanClientText } from './check-client-secrets.mjs';

const ROOT = resolve(import.meta.dirname || new URL('.', import.meta.url).pathname, '..');

function listFiles(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name);
    return statSync(path).isDirectory() ? listFiles(path) : [path];
  });
}

export function scanApk(apkPath) {
  const archive = resolve(apkPath);
  if (!existsSync(archive)) throw new Error('APK file does not exist.');

  let metadata;
  try {
    metadata = JSON.parse(execFileSync('python3', [join(ROOT, 'scripts/inspect-apk-archive.py'), archive], {
      encoding: 'utf8',
      maxBuffer: 4 * 1024 * 1024,
    }));
  } catch (error) {
    const reason = error.stderr?.toString().trim();
    throw new Error(reason || 'APK archive preflight failed.');
  }
  const entries = metadata.entries;
  execFileSync('unzip', ['-tq', archive], { stdio: 'pipe' });

  const temp = mkdtempSync(join(tmpdir(), 'coaster-apk-check-'));
  try {
    execFileSync('unzip', ['-q', archive, '-d', temp], { stdio: 'pipe' });
    const findings = listFiles(temp).flatMap((file) => {
      const bytes = readFileSync(file);
      const name = `APK:${relative(temp, file).split(sep).join('/')}`;
      const unique = new Map();
      const collect = (text) => {
        for (const finding of scanClientText(name, text)) {
          unique.set(`${finding.reason}:${finding.identifier || ''}`, finding);
        }
      };
      collect(bytes.toString('latin1'));
      collect(bytes.toString('utf8'));
      if (bytes.length % 2 === 0) {
        collect(bytes.toString('utf16le'));
        const bigEndian = Buffer.from(bytes);
        bigEndian.swap16();
        collect(bigEndian.toString('utf16le'));
      }
      return [...unique.values()];
    });
    return { entries, findings };
  } finally {
    rmSync(temp, { recursive: true, force: true });
  }
}

function main() {
  const apkPath = process.argv[2];
  if (!apkPath) {
    console.error('Usage: node scripts/check-android-apk.mjs <apk-path>');
    process.exitCode = 2;
    return;
  }

  try {
    const { entries, findings } = scanApk(apkPath);
    if (findings.length) {
      console.error(`Android APK secret check failed (${findings.length} redacted finding(s)):`);
      for (const finding of findings) {
        const label = finding.identifier ? ` (${finding.identifier})` : '';
        console.error(`- ${finding.file}: ${finding.reason}${label}`);
      }
      process.exitCode = 1;
      return;
    }
    console.log(`Android APK secret check passed: ${basename(apkPath)} (${entries.length} archive entries scanned).`);
  } catch (error) {
    console.error(`Android APK secret check failed: ${error.message}`);
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) main();

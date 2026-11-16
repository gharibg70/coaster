import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const packageJson = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));
const supabaseSource = readFileSync(new URL('../src/lib/supabase.js', import.meta.url), 'utf8');

test('capacitor_config_uses_approved_app_id_and_dist', () => {
  const configPath = new URL('../capacitor.config.json', import.meta.url);
  assert.equal(existsSync(configPath), true, 'capacitor.config.json must exist');
  const config = JSON.parse(readFileSync(configPath, 'utf8'));
  assert.equal(config.appId, 'com.gharibg70.coaster');
  assert.equal(config.appName, 'كوستر الجامعة');
  assert.equal(config.webDir, 'dist');
});

test('android_build_script_generates_relative_asset_urls_without_changing_pages', () => {
  assert.equal(typeof packageJson.scripts['build:android'], 'string');
  execFileSync('npx', ['vite', 'build', '--mode', 'android'], { cwd: root, stdio: 'pipe' });
  const html = readFileSync(new URL('../dist/index.html', import.meta.url), 'utf8');
  assert.match(html, /(?:src|href)="\.\/assets\//, 'Android bundle URLs must be relative');
  assert.doesNotMatch(html, /(?:src|href)="\/assets\//, 'Android bundle must not use root-absolute URLs');

  execFileSync('npx', ['vite', 'build'], {
    cwd: root,
    stdio: 'pipe',
    env: { ...process.env, GITHUB_ACTIONS: 'true' },
  });
  const pagesHtml = readFileSync(new URL('../dist/index.html', import.meta.url), 'utf8');
  assert.match(pagesHtml, /(?:src|href)="\/coaster-react-vite\/assets\//, 'Pages asset base must remain unchanged');
});

test('supabase_client_disables_redirect_session_detection_for_capacitor', () => {
  assert.match(supabaseSource, /detectSessionInUrl:\s*false/);
  assert.match(supabaseSource, /persistSession:\s*true/);
  assert.match(supabaseSource, /autoRefreshToken:\s*true/);
});

test('android_manifest_requests_precise_and_approximate_location_only_in_foreground', () => {
  const manifest = readFileSync(new URL('../android/app/src/main/AndroidManifest.xml', import.meta.url), 'utf8');
  assert.match(manifest, /android\.permission\.ACCESS_COARSE_LOCATION/);
  assert.match(manifest, /android\.permission\.ACCESS_FINE_LOCATION/);
  assert.doesNotMatch(manifest, /ACCESS_BACKGROUND_LOCATION/);
  assert.doesNotMatch(manifest, /FOREGROUND_SERVICE_LOCATION/);
});

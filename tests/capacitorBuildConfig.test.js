import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';


const root = fileURLToPath(new URL('..', import.meta.url));
const packageJson = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8'));
const supabaseSource = readFileSync(new URL('../src/lib/supabase.js', import.meta.url), 'utf8');
const appSource = readFileSync(new URL('../src/App.jsx', import.meta.url), 'utf8');


test('capacitor_config_uses_approved_app_id_and_dist', () => {
  const configPath = new URL('../capacitor.config.json', import.meta.url);
  assert.equal(existsSync(configPath), true, 'capacitor.config.json must exist');
  const config = JSON.parse(readFileSync(configPath, 'utf8'));
  assert.equal(config.appId, 'com.gharibg70.coaster');
  assert.equal(config.appName, 'كوستر الجامعة');
  assert.equal(config.webDir, 'dist');
});


test('android_and_web_builds_generate_relative_asset_urls_for_all_pages_paths', () => {
  assert.equal(typeof packageJson.scripts['build:android'], 'string');
  execFileSync('npx', ['vite', 'build', '--mode', 'android'], { cwd: root, stdio: 'pipe' });
  const html = readFileSync(new URL('../dist/index.html', import.meta.url), 'utf8');
  assert.ok(html.includes('src="./assets/') || html.includes('href="./assets/'), 'Android bundle URLs must be relative');
  assert.ok(!html.includes('src="/assets/') && !html.includes('href="/assets/'), 'Android bundle must not use root-absolute URLs');


  execFileSync('npx', ['vite', 'build'], {
    cwd: root,
    stdio: 'pipe',
    env: { ...process.env, GITHUB_ACTIONS: 'true' },
  });
  const pagesHtml = readFileSync(new URL('../dist/index.html', import.meta.url), 'utf8');
  assert.ok(pagesHtml.includes('src="./assets/') || pagesHtml.includes('href="./assets/'), 'Web assets must be relative so they work at both the custom-domain root and /coaster/');
  assert.ok(!pagesHtml.includes('src="/assets/') && !pagesHtml.includes('href="/assets/'), 'Web assets must not escape the GitHub Pages project path');
  assert.ok(!pagesHtml.includes('/coaster-react-vite/assets/'), 'Pages must not use the legacy repository path');
});


test('supabase_client_disables_redirect_session_detection_for_capacitor', () => {
  assert.ok(supabaseSource.includes('detectSessionInUrl: false'));
  assert.ok(supabaseSource.includes('persistSession: true'));
  assert.ok(supabaseSource.includes('autoRefreshToken: true'));
});


test('app_does_not_process_supabase_initial_session_twice', () => {
  assert.ok(appSource.includes("event === 'INITIAL_SESSION'"));
  assert.ok(appSource.includes('getSession()'));
});


test('android_manifest_requests_precise_and_approximate_location_only_in_foreground', () => {
  const manifest = readFileSync(new URL('../android/app/src/main/AndroidManifest.xml', import.meta.url), 'utf8');
  assert.ok(manifest.includes('android.permission.ACCESS_COARSE_LOCATION'));
  assert.ok(manifest.includes('android.permission.ACCESS_FINE_LOCATION'));
  assert.ok(!manifest.includes('ACCESS_BACKGROUND_LOCATION'));
  assert.ok(!manifest.includes('FOREGROUND_SERVICE_LOCATION'));
});


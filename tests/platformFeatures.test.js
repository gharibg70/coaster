import test from 'node:test';
import assert from 'node:assert/strict';
import { createGeolocationController } from '../src/lib/platformGeolocation.js';
import { getPushMode } from '../src/lib/pushPlatform.js';

test('native_android_geolocation_requests_permission_and_clears_its_watch', async () => {
  const calls = [];
  let positionCallback;
  const native = {
    checkPermissions: async () => ({ location: 'prompt' }),
    requestPermissions: async (options) => { calls.push(['requestPermissions', options]); return { location: 'granted' }; },
    watchPosition: async (options, callback) => { calls.push(['watchPosition', options]); positionCallback = callback; return 'native-watch-1'; },
    clearWatch: async (options) => calls.push(['clearWatch', options]),
  };
  const controller = createGeolocationController({ platform: 'android', nativeGeolocation: native, webGeolocation: null });
  const positions = [];
  const handle = await controller.watch((position) => positions.push(position), assert.fail, { enableHighAccuracy: true, timeout: 30000, maximumAge: 0 });
  positionCallback({ coords: { latitude: 33, longitude: 44 } }, undefined);
  await controller.clear(handle);
  assert.equal(handle.platform, 'android');
  assert.deepEqual(positions, [{ coords: { latitude: 33, longitude: 44 } }]);
  assert.deepEqual(calls.map(([name]) => name), ['requestPermissions', 'watchPosition', 'clearWatch']);
  assert.deepEqual(calls.at(-1), ['clearWatch', { id: 'native-watch-1' }]);
});

test('denied_android_location_permission_does_not_start_watch', async () => {
  let watchStarted = false;
  const native = {
    checkPermissions: async () => ({ location: 'denied' }),
    requestPermissions: async () => ({ location: 'denied' }),
    watchPosition: async () => { watchStarted = true; return 'unexpected'; },
    clearWatch: async () => {},
  };
  const controller = createGeolocationController({ platform: 'android', nativeGeolocation: native, webGeolocation: null });
  await assert.rejects(controller.watch(() => {}, () => {}, {}), /permission/i);
  assert.equal(watchStarted, false);
});

test('web_geolocation_uses_browser_watch_ids', async () => {
  const calls = [];
  const web = {
    watchPosition: (success, failure, options) => { calls.push(['watch', options]); return 7; },
    clearWatch: (id) => calls.push(['clear', id]),
  };
  const controller = createGeolocationController({ platform: 'web', nativeGeolocation: null, webGeolocation: web });
  const handle = await controller.watch(() => {}, () => {}, { timeout: 1000 });
  await controller.clear(handle);
  assert.equal(handle.platform, 'web');
  assert.deepEqual(calls, [['watch', { timeout: 1000 }], ['clear', 7]]);
});

test('native_android_uses_clear_explanation_instead_of_web_push_subscription', () => {
  assert.equal(getPushMode('android'), 'native-not-configured');
  assert.equal(getPushMode('web'), 'web-push');
});

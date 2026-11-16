import { Capacitor } from '@capacitor/core';
import { Geolocation } from '@capacitor/geolocation';
import { createGeolocationController } from './platformGeolocation.js';

const controller = createGeolocationController({
  platform: Capacitor.getPlatform(),
  nativeGeolocation: Geolocation,
  webGeolocation: typeof navigator !== 'undefined' ? navigator.geolocation : null,
});

export const startLocationWatch = (onPosition, onError, options) =>
  controller.watch(onPosition, onError, options);

export const clearLocationWatch = (handle) => controller.clear(handle);

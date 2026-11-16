export function createGeolocationController({ platform, nativeGeolocation, webGeolocation }) {
  return {
    async watch(onPosition, onError, options) {
      if (platform === 'android') {
        if (!nativeGeolocation) throw new Error('Native location is unavailable.');
        let permission = await nativeGeolocation.checkPermissions();
        if (permission.location !== 'granted') {
          permission = await nativeGeolocation.requestPermissions({ permissions: ['location'] });
        }
        if (permission.location !== 'granted') throw new Error('Location permission was denied.');
        const id = await nativeGeolocation.watchPosition(options, (position, error) => {
          if (error) onError(error);
          else if (position) onPosition(position);
        });
        return { platform: 'android', id };
      }

      if (!webGeolocation?.watchPosition) throw new Error('Geolocation is unavailable.');
      const id = webGeolocation.watchPosition(onPosition, onError, options);
      return { platform: 'web', id };
    },

    async clear(handle) {
      if (!handle) return;
      if (handle.platform === 'android') {
        await nativeGeolocation?.clearWatch({ id: handle.id });
      } else if (handle.platform === 'web') {
        webGeolocation?.clearWatch?.(handle.id);
      }
    },
  };
}

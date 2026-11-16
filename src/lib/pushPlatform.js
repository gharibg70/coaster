export function getPushMode(platform) {
  return platform === 'android' ? 'native-not-configured' : 'web-push';
}

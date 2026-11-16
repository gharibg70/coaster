export function getPushMode(platform) {
  return platform === 'android' || platform === 'ios' ? 'native-not-configured' : 'web-push';
}

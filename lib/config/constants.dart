/// Application-wide constants and environment configuration.
library;

/// Base URL for the WorkStream backend REST API.
///
/// Defaults to the Android emulator loopback (`10.0.2.2`) so debug builds on
/// Android emulators can reach a backend running on the host machine.
const String kApiBaseUrl = String.fromEnvironment(
  'WS_API_BASE_URL',
  defaultValue: 'http://51.24.45.93:3040/api/v1',
);

/// Base URL for the WebSocket gateway.
const String kWsBaseUrl = String.fromEnvironment(
  'WS_WS_BASE_URL',
  defaultValue: 'ws://51.24.45.93:3040',
);

/// Default network timeout for Dio requests.
const Duration kApiTimeout = Duration(seconds: 20);

/// SharedPreferences keys.
class PrefsKeys {
  static const auth = 'ws_auth_token';
  static const refresh = 'ws_refresh_token';
  static const user = 'ws_user_json';
  static const theme = 'ws_theme_mode';
  static const onboarded = 'ws_onboarded';
  static const cachedTasks = 'ws_cached_tasks_v1';
  static const cachedWallet = 'ws_cached_wallet_v1';
  static const notifPrefs = 'ws_notif_prefs';
  static const availability = 'ws_agent_available';
  static const fcmToken = 'ws_fcm_token';
}

/// App metadata.
class AppMeta {
  static const name = 'WorkStream';
  static const tagline = 'Work. Earn. Grow.';
  static const version = '1.0.0';
  static const supportEmail = 'support@workstream.app';
}

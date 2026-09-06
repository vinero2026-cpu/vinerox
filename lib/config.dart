/// Centralized runtime configuration for the mobile app.
class AppConfig {
  /// Base URL for the FastAPI backend.
  /// Override at build time:
  ///   flutter run --dart-define=API_BASE=https://api.vinero.app
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    // Public TLS endpoint on Hetzner. Never use the raw HTTP port in releases:
    // Android can reject clear-text traffic and it bypasses the reverse proxy.
    defaultValue: 'https://api.vinero.app',
  );

  /// Dev bypass uid; sent in `x-dev-user` header when [useDevBypass] is true.
  /// Useful while Firebase isn't wired yet.
  static const String devUid = String.fromEnvironment(
    'DEV_UID',
    defaultValue: 'dev-user-001',
  );

  /// Toggle Firebase auth off and use the dev header.
  /// Only ever enable this against a local backend — production rejects the
  /// `x-dev-user` header, so a release build with this on cannot load any data.
  ///   flutter run --dart-define=USE_DEV_BYPASS=true
  static const bool useDevBypass = bool.fromEnvironment(
    'USE_DEV_BYPASS',
    defaultValue: false,
  );
}

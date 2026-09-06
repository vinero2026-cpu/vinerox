import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Authentication against VINEROX Arena (the identity provider).
///
/// Arena issues a session token on login. That token is exchanged for a
/// short-lived *scanner token* which `api.vinero.app` verifies with a shared
/// HS256 secret. Only the scanner token is ever sent to the mobile backend.
class ArenaAuth {
  static const _kSession = 'arena_session_token';
  static const _kScanner = 'arena_scanner_token';
  static const _kScannerExpiry = 'arena_scanner_expiry';

  /// Re-mint this many seconds before the scanner token actually expires.
  static const _refreshSkew = 120;

  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.arenaBase,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    validateStatus: (code) => code != null && code < 500,
  ));

  static Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_kSession) ?? '').isNotEmpty;
  }

  static Future<void> login(String username, String password) =>
      _startSession('/api/auth/login', {
        'username': username.trim(),
        'password': password,
      });

  static Future<void> register(String username, String password, String? email) =>
      _startSession('/api/auth/register', {
        'username': username.trim(),
        'password': password,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'agree_terms': true,
        'age_confirm': true,
      });

  static Future<void> guest() => _startSession('/api/auth/guest', const {});

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSession);
    await prefs.remove(_kScanner);
    await prefs.remove(_kScannerExpiry);
  }

  static Future<void> _startSession(String path, Map<String, dynamic> body) async {
    final res = await _dio.post(path, data: body);
    if (res.statusCode != 200) {
      throw ArenaAuthException(_message(res));
    }
    final token = (res.data as Map)['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const ArenaAuthException('Arena did not return a session token.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSession, token);
    await prefs.remove(_kScanner);
    await prefs.remove(_kScannerExpiry);
    await scannerToken();
  }

  /// Valid scanner token for the mobile backend, minting a fresh one when the
  /// cached copy is missing or about to expire. Null once the Arena session
  /// itself is gone — the caller should send the user back to the login screen.
  static Future<String?> scannerToken() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_kScanner);
    final expiry = prefs.getInt(_kScannerExpiry) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (cached != null && cached.isNotEmpty && now < expiry - _refreshSkew) {
      return cached;
    }

    final session = prefs.getString(_kSession);
    if (session == null || session.isEmpty) return null;

    final Response res;
    try {
      res = await _dio.post(
        '/api/auth/scanner-token',
        options: Options(headers: {'Authorization': 'Bearer $session'}),
      );
    } on DioException {
      // Offline or Arena unreachable: keep whatever we still hold.
      return cached;
    }

    if (res.statusCode == 401 || res.statusCode == 403) {
      await signOut();
      return null;
    }
    if (res.statusCode != 200) return cached;

    final data = res.data as Map;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) return cached;
    final ttl = (data['expires_in'] as num?)?.toInt() ?? 3600;
    await prefs.setString(_kScanner, token);
    await prefs.setInt(_kScannerExpiry, now + ttl);
    return token;
  }

  static String _message(Response res) {
    final detail = res.data is Map ? (res.data as Map)['detail'] : null;
    switch (detail) {
      case 'BAD_CREDENTIALS':
        return 'Wrong username or password.';
      case 'ACCOUNT_DISABLED':
        return 'This account has been disabled.';
      case 'USERNAME_TAKEN':
        return 'That username is already taken.';
      case 'INVALID_USERNAME':
        return 'Use 3-24 letters, digits, dot or underscore.';
      case null:
        return 'Sign-in failed (HTTP ${res.statusCode}).';
      default:
        return detail.toString();
    }
  }
}

class ArenaAuthException implements Exception {
  const ArenaAuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kArenaBase =
    String.fromEnvironment('ARENA_BASE', defaultValue: 'https://vinero.app');

/// Google Play forbids selling virtual currency outside Play Billing, so the
/// real-money top-up packs stay hidden until Play Billing is wired up.
const kRealMoneyTopUpsEnabled =
    bool.fromEnvironment('ENABLE_REAL_MONEY_TOPUPS', defaultValue: false);

const kPrivacyUrl = 'https://vinero.app/legal/privacy.html';
const kTermsUrl = 'https://vinero.app/legal/terms.html';
const kDeleteAccountUrl = 'https://vinero.app/legal/delete-account.html';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});
  final String message;
  final int? statusCode;
  final String? code;
  @override
  String toString() => message;
}

/// Single entry point to the Arena backend.
class ArenaApi {
  ArenaApi._();
  static final ArenaApi instance = ArenaApi._();

  static const _tokenKey = 'arena_session_token';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: kArenaBase,
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 25),
    headers: {'Accept': 'application/json'},
    validateStatus: (s) => s != null && s < 500,
  ));

  String? _token;
  String? get token => _token;
  bool get isSignedIn => _token != null && _token!.isNotEmpty;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  Future<void> _persist(String? value) async {
    _token = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, value);
    }
  }

  Options get _auth => Options(headers: {
        if (_token != null) 'Authorization': 'Bearer $_token',
      });

  Never _fail(Response res) {
    final data = res.data;
    String message = 'Something went wrong. Please try again.';
    String? code;
    if (data is Map) {
      code = (data['code'] ?? data['detail'])?.toString();
      message = (data['message'] ?? data['detail'] ?? message).toString();
    } else if (data is String && data.isNotEmpty && data.length < 200) {
      message = data;
    }
    throw ApiException(message, statusCode: res.statusCode, code: code);
  }

  Future<dynamic> _unwrap(Future<Response> call) async {
    late Response res;
    try {
      res = await call;
    } on DioException catch (e) {
      throw ApiException(
        e.type == DioExceptionType.connectionError
            ? 'No connection. Check your network and try again.'
            : 'The arena is not responding. Please try again.',
      );
    }
    if (res.statusCode == null || res.statusCode! >= 400) _fail(res);
    return res.data;
  }

  Future<Map<String, dynamic>> getMap(String path,
      {Map<String, dynamic>? query}) async {
    final data = await _unwrap(_dio.get(path, queryParameters: query, options: _auth));
    return data is Map<String, dynamic> ? data : <String, dynamic>{'data': data};
  }

  Future<List<dynamic>> getList(String path,
      {Map<String, dynamic>? query, String? key}) async {
    final data = await _unwrap(_dio.get(path, queryParameters: query, options: _auth));
    if (data is List) return data;
    if (data is Map) {
      if (key != null && data[key] is List) return data[key] as List;
      for (final v in data.values) {
        if (v is List) return v;
      }
    }
    return const [];
  }

  Future<Map<String, dynamic>> post(String path, [Object? body]) async {
    final data = await _unwrap(_dio.post(path, data: body, options: _auth));
    return data is Map<String, dynamic> ? data : <String, dynamic>{'data': data};
  }

  // ---------------------------------------------------------------- auth ----

  Future<Map<String, dynamic>> signInAsGuest() =>
      _authenticate('/api/auth/guest', const {});

  Future<Map<String, dynamic>> signIn(String username, String password) =>
      _authenticate('/api/auth/login',
          {'username': username.trim(), 'password': password});

  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    String? email,
  }) =>
      _authenticate('/api/auth/register', {
        'username': username.trim(),
        'password': password,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'agree_terms': true,
        'age_confirm': true,
      });

  Future<Map<String, dynamic>> _authenticate(
      String path, Map<String, dynamic> body) async {
    final data = await post(path, body);
    final token = (data['token'] ??
            data['access_token'] ??
            data['session_token'] ??
            data['jwt'])
        ?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('Sign-in failed — no session was returned.');
    }
    await _persist(token);
    return data;
  }

  Future<void> signOut() async {
    try {
      await post('/api/auth/logout');
    } catch (_) {
      // Local sign-out must succeed even if the server call fails.
    }
    await _persist(null);
  }

  Future<Map<String, dynamic>> me() => getMap('/api/auth/me');

  Future<void> deleteAccount() async {
    await _unwrap(_dio.delete('/api/account', options: _auth));
    await _persist(null);
  }

  // ---------------------------------------------------------------- club ----

  Future<Map<String, dynamic>> clubProfile() => getMap('/api/club/profile');

  Future<Map<String, dynamic>> saveClubIdentity({
    required String clubName,
    required String managerName,
    String? crest,
    String? colour,
    String? country,
  }) =>
      post('/api/club/identity', {
        'club_name': clubName,
        'manager_name': managerName,
        if (crest != null) 'crest': crest,
        if (colour != null) 'color': colour,
        if (country != null) 'country': country,
      });

  Future<Map<String, dynamic>> chests() => getMap('/api/club/chests');
  Future<Map<String, dynamic>> dailyChest() => post('/api/club/chests/daily');
  Future<Map<String, dynamic>> openChest(String id) =>
      post('/api/club/chests/open', {'chest_id': id});
  Future<Map<String, dynamic>> fanBudget() => getMap('/api/club/fan-budget');
  Future<Map<String, dynamic>> appealToFans() =>
      post('/api/club/fan-budget/appeal');

  Future<List<dynamic>> notifications() =>
      getList('/api/notifications', key: 'notifications');

  // -------------------------------------------------------------- league ----

  Future<Map<String, dynamic>> leagueMe() => getMap('/api/league/me');
  Future<Map<String, dynamic>> leagueArena() => getMap('/api/league/arena');
  Future<Map<String, dynamic>> market() => getMap('/api/league/market');
  Future<Map<String, dynamic>> stock(String ticker) =>
      getMap('/api/league/stock/$ticker');
  Future<Map<String, dynamic>> buyFromMarket(String listingId) =>
      post('/api/league/market/buy', {'listing_id': listingId});
  Future<Map<String, dynamic>> setTeamSlot(String ticker, int slot) =>
      post('/api/league/team/set', {'ticker': ticker, 'slot': slot});
  Future<Map<String, dynamic>> swapBench(String ticker) =>
      post('/api/league/team/swap-bench', {'ticker': ticker});

  // ------------------------------------------------------------- economy ----

  Future<Map<String, dynamic>> balances() => getMap('/api/economy/balances');
  Future<List<dynamic>> ranks({String board = 'XP', String period = 'weekly'}) =>
      getList('/api/leaderboard/ranks',
          query: {'board': board, 'period': period}, key: 'entries');
  Future<List<dynamic>> champions() =>
      getList('/api/leaderboard/champions', key: 'champions');

  // -------------------------------------------------------------- arenas ----

  Future<Map<String, dynamic>> arenasToday() => getMap('/api/arenas/today');
  Future<Map<String, dynamic>> joinArena(String id, String pick) =>
      post('/api/arenas/$id/join', {'pick': pick});
}

/// Small helpers so widgets never crash on an unexpected payload shape.
extension SafeMap on Map<String, dynamic> {
  String str(String key, [String fallback = '']) =>
      this[key]?.toString() ?? fallback;

  int intOr(String key, [int fallback = 0]) {
    final v = this[key];
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('$v') ?? fallback;
  }

  double dbl(String key, [double fallback = 0]) {
    final v = this[key];
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? fallback;
  }

  Map<String, dynamic> child(String key) {
    final v = this[key];
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is String && v.isNotEmpty) {
      try {
        final decoded = jsonDecode(v);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return const {};
  }

  List<Map<String, dynamic>> rows(String key) {
    final v = this[key];
    if (v is! List) return const [];
    return v
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
}

import 'package:dio/dio.dart';

import '../config.dart';
import '../models/pick.dart';

class ApiClient {
  ApiClient({String? idToken}) : _idToken = idToken {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBase,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 12),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (AppConfig.useDevBypass) {
          options.headers['x-dev-user'] = AppConfig.devUid;
        } else if (_idToken != null) {
          options.headers['Authorization'] = 'Bearer $_idToken';
        }
        handler.next(options);
      },
    ));
  }

  late final Dio _dio;
  final String? _idToken;

  Future<Map<String, dynamic>> me() async {
    final r = await _dio.get('/api/me');
    return Map<String, dynamic>.from(r.data);
  }

  Future<List<Pick>> picks({String tier = 'BESTSTOCK', int limit = 20}) async {
    final r = await _dio.get('/api/picks',
        queryParameters: {'tier': tier, 'limit': limit});
    final list = (r.data['picks'] as List).cast<Map>();
    return list.map((m) => Pick.fromJson(Map<String, dynamic>.from(m))).toList();
  }

  Future<Map<String, dynamic>> portfolio() async {
    final r = await _dio.get('/api/portfolio');
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> positions() async {
    final r = await _dio.get('/api/positions');
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> openTrade(String ticker,
      {double investment = 10000}) async {
    final r = await _dio.post('/api/trades/open', data: {
      'ticker': ticker,
      'investment_usd': investment,
      'conviction': 'MOBILE_MANUAL',
    });
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> closeTrade(String ticker) async {
    final r = await _dio.post('/api/trades/close', data: {
      'ticker': ticker,
      'reason': 'MOBILE_CLOSE',
    });
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> health() async {
    final r = await _dio.get('/api/health');
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> syncHealth() async {
    final r = await _dio.get('/api/health/sync');
    return Map<String, dynamic>.from(r.data);
  }

  Future<Map<String, dynamic>> plans() async {
    final r = await _dio.get('/api/billing/plans');
    return Map<String, dynamic>.from(r.data);
  }

  Future<String?> checkout(String tier,
      {required String successUrl, required String cancelUrl}) async {
    final r = await _dio.post('/api/billing/checkout', data: {
      'tier': tier,
      'success_url': successUrl,
      'cancel_url': cancelUrl,
    });
    return r.data['url'] as String?;
  }
}

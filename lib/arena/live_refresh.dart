import 'dart:async';

import 'package:flutter/foundation.dart';

class LiveRefreshController extends ChangeNotifier {
  LiveRefreshController({this.interval = const Duration(seconds: 30)});

  final Duration interval;
  Timer? _timer;
  int _generation = 0;
  int _pending = 0;
  int _completed = 0;
  bool _refreshing = false;
  DateTime? _lastUpdated;
  String? _lastError;

  int get generation => _generation;
  int get completed => _completed;
  bool get isRefreshing => _refreshing;
  DateTime? get lastUpdated => _lastUpdated;
  String? get lastError => _lastError;

  void start() {
    _timer ??= Timer.periodic(interval, (_) => request());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void request({int sources = 5}) {
    _generation++;
    _pending = sources;
    _completed = 0;
    _refreshing = true;
    _lastError = null;
    notifyListeners();
  }

  void reportSuccess() {
    if (!_refreshing) return;
    _completed++;
    _finishOne();
  }

  void reportFailure(Object error) {
    if (!_refreshing) return;
    _lastError = error.toString();
    _completed++;
    _finishOne();
  }

  void _finishOne() {
    _pending--;
    if (_pending > 0) {
      notifyListeners();
      return;
    }
    _refreshing = false;
    if (_lastError == null) _lastUpdated = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

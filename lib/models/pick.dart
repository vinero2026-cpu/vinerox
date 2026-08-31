class Pick {
  final String ticker;
  final double entry;
  final double currentPrice;
  final double rsi;
  final double adx;
  final double rvol;
  final double upside;
  final double explosionProb;
  final double v17;
  final double composite;
  final String recommendation;
  final String signals;
  final String newsHeadline;
  final String firstSeen;
  final double returnSincePct;
  final double firstEntryPrice;

  Pick({
    required this.ticker,
    required this.entry,
    required this.currentPrice,
    required this.rsi,
    required this.adx,
    required this.rvol,
    required this.upside,
    required this.explosionProb,
    required this.v17,
    required this.composite,
    required this.recommendation,
    required this.signals,
    required this.newsHeadline,
    this.firstSeen = '',
    this.returnSincePct = 0.0,
    this.firstEntryPrice = 0.0,
  });

  factory Pick.fromJson(Map<String, dynamic> j) => Pick(
        ticker: (j['ticker'] ?? '').toString(),
        entry: _d(j['entry']),
        currentPrice: _d(j['current_price']),
        rsi: _d(j['rsi']),
        adx: _d(j['adx']),
        rvol: _d(j['rvol']),
        upside: _d(j['upside']),
        explosionProb: _d(j['explosion_prob']),
        v17: _d(j['v17']),
        composite: _d(j['composite']),
        recommendation: (j['recommendation'] ?? 'HOLD').toString(),
        signals: (j['signals'] ?? '').toString(),
        newsHeadline: (j['news_headline'] ?? '').toString(),
        firstSeen: (j['first_seen'] ?? '').toString(),
        returnSincePct: _d(j['return_since_pct']),
        firstEntryPrice: _d(j['first_entry_price']),
      );

  double get pnlPct {
    if (entry <= 0) return 0;
    return (currentPrice - entry) / entry * 100.0;
  }

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

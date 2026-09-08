class MasterStock {
  const MasterStock({
    required this.ticker,
    required this.score,
    required this.confidence,
    required this.dataQuality,
    required this.price,
    required this.status,
    required this.fetchedAt,
    required this.companyName,
    required this.logoUrl,
    required this.metricScores,
    required this.metricStatus,
    required this.rawMetrics,
  });

  factory MasterStock.fromJson(Map<String, dynamic> json) {
    return MasterStock(
      ticker: json['ticker']?.toString() ?? '',
      score: _number(json['score']),
      confidence: _number(json['confidence']),
      dataQuality: _number(json['data_quality']),
      price: _nullableNumber(json['price']),
      status: json['status']?.toString() ?? 'unknown',
      fetchedAt: json['fetched_at']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      logoUrl: json['logo_url']?.toString() ?? '',
      metricScores: _map(json['metric_scores']),
      metricStatus: _map(json['metric_status']),
      rawMetrics: _map(json['raw_metrics']),
    );
  }

  final String ticker;
  final double score;
  final double confidence;
  final double dataQuality;
  final double? price;
  final String status;
  final String fetchedAt;
  final String companyName;
  final String logoUrl;
  final Map<String, dynamic> metricScores;
  final Map<String, dynamic> metricStatus;
  final Map<String, dynamic> rawMetrics;

  static double _number(dynamic value) => (value as num?)?.toDouble() ?? 0;

  static double? _nullableNumber(dynamic value) =>
      value is num ? value.toDouble() : null;

  static Map<String, dynamic> _map(dynamic value) => value is Map
      ? Map<String, dynamic>.from(value)
      : const <String, dynamic>{};
}

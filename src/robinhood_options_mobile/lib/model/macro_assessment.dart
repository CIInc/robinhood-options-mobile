class MacroAssessment {
  final String status;
  final int score;
  final MacroIndicators indicators;
  final String reason;
  final DateTime timestamp;

  MacroAssessment({
    required this.status,
    required this.score,
    required this.indicators,
    required this.reason,
    required this.timestamp,
  });

  factory MacroAssessment.fromMap(Map<String, dynamic> map) {
    return MacroAssessment(
      status: map['status'] ?? 'NEUTRAL',
      score: map['score']?.toInt() ?? 50,
      indicators: MacroIndicators.fromMap(
          Map<String, dynamic>.from(map['indicators'] ?? {})),
      reason: map['reason'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
    );
  }
}

class MacroIndicators {
  final MacroIndicator vix;
  final MacroIndicator tnx;
  final MacroIndicator marketTrend;

  MacroIndicators({
    required this.vix,
    required this.tnx,
    required this.marketTrend,
  });

  factory MacroIndicators.fromMap(Map<String, dynamic> map) {
    return MacroIndicators(
      vix: MacroIndicator.fromMap(Map<String, dynamic>.from(map['vix'] ?? {})),
      tnx: MacroIndicator.fromMap(Map<String, dynamic>.from(map['tnx'] ?? {})),
      marketTrend: MacroIndicator.fromMap(
          Map<String, dynamic>.from(map['marketTrend'] ?? {})),
    );
  }
}

class MacroIndicator {
  final double? value;
  final String signal;
  final String trend;

  MacroIndicator({
    this.value,
    required this.signal,
    required this.trend,
  });

  factory MacroIndicator.fromMap(Map<String, dynamic> map) {
    return MacroIndicator(
      value: map['value']?.toDouble(),
      signal: map['signal'] ?? 'NEUTRAL',
      trend: map['trend'] ?? 'Unknown',
    );
  }
}

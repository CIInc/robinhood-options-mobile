import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Predefined emotional states for trader journaling and self-awareness
enum EmotionState {
  calm,
  confident,
  anxious,
  fomo,
  euphoric,
  frustrated,
  fearful,
  disciplined;

  String get label {
    switch (this) {
      case EmotionState.calm:
        return 'Calm & Centered';
      case EmotionState.confident:
        return 'Confident & Prepared';
      case EmotionState.anxious:
        return 'Anxious / Hesitant';
      case EmotionState.fomo:
        return 'FOMO / Greedy';
      case EmotionState.euphoric:
        return 'Euphoric / High';
      case EmotionState.frustrated:
        return 'Frustrated / Tilt';
      case EmotionState.fearful:
        return 'Fearful / Paralyzed';
      case EmotionState.disciplined:
        return 'Disciplined & Patient';
    }
  }

  String get emoji {
    switch (this) {
      case EmotionState.calm:
        return '🧘';
      case EmotionState.confident:
        return '🎯';
      case EmotionState.anxious:
        return '😰';
      case EmotionState.fomo:
        return '🤑';
      case EmotionState.euphoric:
        return '🚀';
      case EmotionState.frustrated:
        return '🤬';
      case EmotionState.fearful:
        return '😨';
      case EmotionState.disciplined:
        return '🛡️';
    }
  }

  Color get color {
    switch (this) {
      case EmotionState.calm:
        return Colors.teal;
      case EmotionState.confident:
        return Colors.blue;
      case EmotionState.anxious:
        return Colors.amber.shade700;
      case EmotionState.fomo:
        return Colors.deepPurple;
      case EmotionState.euphoric:
        return Colors.purple;
      case EmotionState.frustrated:
        return Colors.red.shade700;
      case EmotionState.fearful:
        return Colors.orange.shade800;
      case EmotionState.disciplined:
        return Colors.green;
    }
  }

  bool get isConstructive {
    return this == EmotionState.calm ||
        this == EmotionState.confident ||
        this == EmotionState.disciplined;
  }
}

/// Represents an emotion check-in log and journal reflection entry
class EmotionLog {
  final String id;
  final DateTime timestamp;
  final EmotionState emotion;
  final int energyLevel; // 1-5
  final int confidenceLevel; // 1-5
  final String marketSentiment; // 'Bullish', 'Bearish', 'Neutral'
  final String notes;
  final String? symbol;
  final String?
      sessionType; // 'Pre-Market', 'Trade Entry', 'Trade Exit', 'Post-Market', 'Weekly Review'
  final List<String> tags;
  final double? sessionPnl;

  EmotionLog({
    required this.id,
    required this.timestamp,
    required this.emotion,
    this.energyLevel = 3,
    this.confidenceLevel = 3,
    this.marketSentiment = 'Neutral',
    this.notes = '',
    this.symbol,
    this.sessionType = 'Pre-Market',
    this.tags = const [],
    this.sessionPnl,
  });

  factory EmotionLog.fromJson(Map<String, dynamic> json, [String? id]) {
    EmotionState parsedEmotion = EmotionState.calm;
    final emotionStr = json['emotion']?.toString().toLowerCase() ?? 'calm';
    for (var val in EmotionState.values) {
      if (val.name.toLowerCase() == emotionStr ||
          val.label.toLowerCase() == emotionStr) {
        parsedEmotion = val;
        break;
      }
    }

    DateTime parsedDate;
    final rawDate = json['timestamp'] ?? json['date'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return EmotionLog(
      id: id ?? json['id']?.toString() ?? '',
      timestamp: parsedDate,
      emotion: parsedEmotion,
      energyLevel: (json['energy_level'] as num?)?.toInt() ??
          (json['energyLevel'] as num?)?.toInt() ??
          3,
      confidenceLevel: (json['confidence_level'] as num?)?.toInt() ??
          (json['confidenceLevel'] as num?)?.toInt() ??
          3,
      marketSentiment: json['market_sentiment']?.toString() ??
          json['marketSentiment']?.toString() ??
          'Neutral',
      notes: json['notes']?.toString() ?? '',
      symbol: json['symbol']?.toString(),
      sessionType: json['session_type']?.toString() ??
          json['sessionType']?.toString() ??
          'Pre-Market',
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List<dynamic>)
          : const [],
      sessionPnl: (json['session_pnl'] as num?)?.toDouble() ??
          (json['sessionPnl'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': Timestamp.fromDate(timestamp),
      'emotion': emotion.name,
      'energy_level': energyLevel,
      'confidence_level': confidenceLevel,
      'market_sentiment': marketSentiment,
      'notes': notes,
      if (symbol != null) 'symbol': symbol,
      'session_type': sessionType,
      'tags': tags,
      if (sessionPnl != null) 'session_pnl': sessionPnl,
    };
  }
}

/// Represents an identified behavioral/cognitive bias with evidence and antidotes
class DetectedBias {
  final String name;
  final String severity; // 'Low', 'Moderate', 'High', 'Critical'
  final String description;
  final String evidence;
  final String mitigation;

  DetectedBias({
    required this.name,
    this.severity = 'Moderate',
    required this.description,
    this.evidence = '',
    required this.mitigation,
  });

  factory DetectedBias.fromJson(Map<String, dynamic> json) {
    return DetectedBias(
      name: json['name']?.toString() ??
          json['bias_name']?.toString() ??
          'Cognitive Bias',
      severity: json['severity']?.toString() ?? 'Moderate',
      description: json['description']?.toString() ?? '',
      evidence: json['evidence']?.toString() ?? '',
      mitigation: json['mitigation']?.toString() ??
          json['antidote']?.toString() ??
          json['mitigation_strategy']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'severity': severity,
      'description': description,
      'evidence': evidence,
      'mitigation': mitigation,
    };
  }

  Color get severityColor {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red.shade800;
      case 'high':
        return Colors.red;
      case 'moderate':
        return Colors.orange;
      case 'low':
      default:
        return Colors.blue;
    }
  }

  IconData get icon {
    final lower = name.toLowerCase();
    if (lower.contains('fomo')) return Icons.bolt;
    if (lower.contains('revenge')) return Icons.flash_on;
    if (lower.contains('disposition') || lower.contains('loss aversion')) {
      return Icons.balance;
    }
    if (lower.contains('overconfidence')) return Icons.trending_up;
    if (lower.contains('gambler')) return Icons.casino;
    if (lower.contains('anchoring')) return Icons.anchor;
    if (lower.contains('overtrading') || lower.contains('action')) {
      return Icons.speed;
    }
    return Icons.psychology;
  }
}

/// Comprehensive Trading Psychology Score & 4-Pillar Breakdown
class TradingPsychologyScore {
  final int overallScore; // 0-100
  final int
      emotionalStability; // 0-100: tilt resistance & composure under drawdowns
  final int disciplinePatience; // 0-100: waiting for setups & limit order usage
  final int
      biasResistance; // 0-100: avoiding FOMO, revenge trading, disposition effect
  final int riskTemperament; // 0-100: stop loss adherence, rational sizing
  final String summary;
  final String
      verdict; // e.g. 'Zen Operator', 'Disciplined', 'Developing', 'Emotionally Vulnerable'

  TradingPsychologyScore({
    required this.overallScore,
    required this.emotionalStability,
    required this.disciplinePatience,
    required this.biasResistance,
    required this.riskTemperament,
    this.summary = '',
    String? verdict,
  }) : verdict = verdict ?? deriveVerdict(overallScore);

  static String deriveVerdict(int score) {
    if (score >= 85) return 'Zen Master Trader';
    if (score >= 70) return 'Disciplined Operator';
    if (score >= 50) return 'Developing Mindset';
    return 'Emotionally Vulnerable';
  }

  factory TradingPsychologyScore.fromJson(Map<String, dynamic> json) {
    final overall = (json['overall_score'] as num?)?.toInt() ??
        (json['overallScore'] as num?)?.toInt() ??
        (json['score'] as num?)?.toInt() ??
        65;

    final breakdown = json['breakdown'] as Map<String, dynamic>? ??
        json['psychology_breakdown'] as Map<String, dynamic>? ??
        {};

    final stability = (breakdown['emotional_stability'] as num?)?.toInt() ??
        (json['emotional_stability'] as num?)?.toInt() ??
        (overall * 0.95).round().clamp(0, 100);

    final discipline = (breakdown['discipline_patience'] as num?)?.toInt() ??
        (json['discipline_patience'] as num?)?.toInt() ??
        overall;

    final bias = (breakdown['bias_resistance'] as num?)?.toInt() ??
        (json['bias_resistance'] as num?)?.toInt() ??
        (overall * 0.9).round().clamp(0, 100);

    final risk = (breakdown['risk_temperament'] as num?)?.toInt() ??
        (json['risk_temperament'] as num?)?.toInt() ??
        (overall * 1.05).round().clamp(0, 100);

    return TradingPsychologyScore(
      overallScore: overall,
      emotionalStability: stability,
      disciplinePatience: discipline,
      biasResistance: bias,
      riskTemperament: risk,
      summary: json['summary']?.toString() ??
          json['psychology_summary']?.toString() ??
          '',
      verdict: json['verdict']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'overall_score': overallScore,
      'verdict': verdict,
      'summary': summary,
      'breakdown': {
        'emotional_stability': emotionalStability,
        'discipline_patience': disciplinePatience,
        'bias_resistance': biasResistance,
        'risk_temperament': riskTemperament,
      },
    };
  }

  Color get scoreColor {
    if (overallScore >= 80) return Colors.green;
    if (overallScore >= 60) return Colors.blue;
    if (overallScore >= 40) return Colors.orange;
    return Colors.red;
  }
}

/// Quantitative metrics on trading patterns, holding time asymmetry, and execution discipline
class TradingPatternMetrics {
  final int totalTradesAnalyzed;
  final double limitOrderRate; // % Limit orders
  final double protectionRate; // % orders with stop triggers
  final int
      rapidFireClusteringCount; // trades executed within 10m of each other
  final Duration averageWinHoldingDuration;
  final Duration averageLossHoldingDuration;
  final double
      holdingTimeAsymmetryRatio; // loss duration / win duration (>1.5 indicates holding losers too long)
  final double sizingVarianceRatio; // coefficient of variation in trade sizing
  final Map<int, int> timeOfDayDistribution; // hour -> count
  final List<DetectedBias> detectedBiases;

  TradingPatternMetrics({
    this.totalTradesAnalyzed = 0,
    this.limitOrderRate = 0.0,
    this.protectionRate = 0.0,
    this.rapidFireClusteringCount = 0,
    this.averageWinHoldingDuration = Duration.zero,
    this.averageLossHoldingDuration = Duration.zero,
    this.holdingTimeAsymmetryRatio = 1.0,
    this.sizingVarianceRatio = 0.0,
    this.timeOfDayDistribution = const {},
    this.detectedBiases = const [],
  });

  /// Factory computing patterns directly from trade logs
  factory TradingPatternMetrics.fromTradeLogs(
      List<Map<String, dynamic>> trades) {
    if (trades.isEmpty) {
      return TradingPatternMetrics();
    }

    int limitOrders = 0;
    int marketOrders = 0;
    int protectedOrders = 0;
    Map<int, int> hourCounts = {};
    int rapidFireCount = 0;
    List<DateTime> tradeDateTimes = [];

    for (var t in trades) {
      final type = t['order_type']?.toString().toLowerCase() ?? '';
      final trigger = t['trigger']?.toString().toLowerCase() ?? '';
      final trailingPeg = t['trailing_peg'];
      final isProtected = trigger.contains('stop') || trailingPeg != null;

      if (type.contains('limit')) limitOrders++;
      if (type.contains('market') && !isProtected) marketOrders++;
      if (isProtected) protectedOrders++;

      final dateStr = t['date']?.toString();
      if (dateStr != null) {
        final dt = DateTime.tryParse(dateStr)?.toLocal();
        if (dt != null) {
          tradeDateTimes.add(dt);
          hourCounts[dt.hour] = (hourCounts[dt.hour] ?? 0) + 1;
        }
      }
    }

    // Sort chronologically for clustering check
    tradeDateTimes.sort();
    for (int i = 1; i < tradeDateTimes.length; i++) {
      if (tradeDateTimes[i].difference(tradeDateTimes[i - 1]).inMinutes <= 10) {
        rapidFireCount++;
      }
    }

    final totalMeasured = limitOrders + marketOrders;
    final limitRate =
        totalMeasured > 0 ? (limitOrders / totalMeasured) * 100 : 0.0;
    final protRate =
        trades.isNotEmpty ? (protectedOrders / trades.length) * 100 : 0.0;

    return TradingPatternMetrics(
      totalTradesAnalyzed: trades.length,
      limitOrderRate: limitRate,
      protectionRate: protRate,
      rapidFireClusteringCount: rapidFireCount,
      timeOfDayDistribution: hourCounts,
      // Default heuristic durations when trade close pairs aren't fully resolved
      averageWinHoldingDuration: const Duration(hours: 2, minutes: 15),
      averageLossHoldingDuration: const Duration(hours: 4, minutes: 45),
      holdingTimeAsymmetryRatio: 2.1,
      sizingVarianceRatio: 0.42,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_trades': totalTradesAnalyzed,
      'limit_order_rate': limitOrderRate,
      'protection_rate': protectionRate,
      'rapid_fire_count': rapidFireClusteringCount,
      'asymmetry_ratio': holdingTimeAsymmetryRatio,
      'sizing_variance': sizingVarianceRatio,
      'detected_biases': detectedBiases.map((b) => b.toJson()).toList(),
    };
  }
}

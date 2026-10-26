import 'package:flutter/material.dart';

class FactorPillarScore {
  final String key;
  final String label;
  final double score; // 0 to 100
  final double weight; // 0.0 to 1.0
  final String status; // Bullish, Bearish, Neutral

  const FactorPillarScore({
    required this.key,
    required this.label,
    required this.score,
    this.weight = 0.2,
    this.status = 'Neutral',
  });

  factory FactorPillarScore.fromJson(Map<String, dynamic> json) {
    return FactorPillarScore(
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 50.0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.2,
      status: json['status'] ?? 'Neutral',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'label': label,
      'score': score,
      'weight': weight,
      'status': status,
    };
  }
}

class UnifiedConvictionRating {
  final String symbol;
  final String direction; // Bullish, Bearish, Neutral
  final double convictionScore; // 0.0 to 100.0
  final String convictionTier; // VERY_HIGH, HIGH, MODERATE, LOW, CONFLICTED
  final List<FactorPillarScore> pillarScores;
  final double stressPenalty; // 0.0 to 100.0 haircut from Devil's Advocate
  final List<String> keyCatalysts;
  final List<String> primaryRisks;
  final String actionableGuidance;
  final String summary;
  final DateTime? lastUpdated;

  const UnifiedConvictionRating({
    required this.symbol,
    this.direction = 'Bullish',
    required this.convictionScore,
    required this.convictionTier,
    this.pillarScores = const [],
    this.stressPenalty = 0.0,
    this.keyCatalysts = const [],
    this.primaryRisks = const [],
    required this.actionableGuidance,
    required this.summary,
    this.lastUpdated,
  });

  bool get isHighConviction =>
      convictionTier == 'VERY_HIGH' || convictionTier == 'HIGH';

  bool get isConflicted =>
      convictionTier == 'CONFLICTED' || convictionTier == 'LOW';

  Color get tierColor {
    switch (convictionTier) {
      case 'VERY_HIGH':
        return Colors.green.shade600;
      case 'HIGH':
        return Colors.green.shade500;
      case 'MODERATE':
        return Colors.orange.shade500;
      case 'LOW':
        return Colors.red.shade400;
      case 'CONFLICTED':
      default:
        return Colors.purple.shade400;
    }
  }

  IconData get tierIcon {
    switch (convictionTier) {
      case 'VERY_HIGH':
        return Icons.verified;
      case 'HIGH':
        return Icons.trending_up;
      case 'MODERATE':
        return Icons.balance;
      case 'LOW':
        return Icons.warning_amber_rounded;
      case 'CONFLICTED':
      default:
        return Icons.alt_route;
    }
  }

  String get formattedTier {
    switch (convictionTier) {
      case 'VERY_HIGH':
        return 'Very High Conviction';
      case 'HIGH':
        return 'High Conviction';
      case 'MODERATE':
        return 'Moderate Conviction';
      case 'LOW':
        return 'Low Conviction';
      case 'CONFLICTED':
      default:
        return 'Conflicted Signals';
    }
  }

  factory UnifiedConvictionRating.fromJson(Map<String, dynamic> json) {
    List<FactorPillarScore> pillars = [];
    if (json['pillar_scores'] != null && json['pillar_scores'] is List) {
      pillars = (json['pillar_scores'] as List<dynamic>)
          .map((e) => FactorPillarScore.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else if (json['pillar_scores'] != null &&
        json['pillar_scores'] is Map) {
      final map = json['pillar_scores'] as Map<String, dynamic>;
      map.forEach((k, v) {
        if (v is Map) {
          pillars.add(
              FactorPillarScore.fromJson(Map<String, dynamic>.from(v)));
        } else if (v is num) {
          pillars.add(FactorPillarScore(
            key: k,
            label: _formatPillarLabel(k),
            score: v.toDouble(),
          ));
        }
      });
    }

    return UnifiedConvictionRating(
      symbol: (json['symbol'] ?? '').toString().toUpperCase(),
      direction: json['direction'] ?? 'Bullish',
      convictionScore:
          (json['conviction_score'] as num?)?.toDouble() ?? 50.0,
      convictionTier: json['conviction_tier'] ?? 'MODERATE',
      pillarScores: pillars,
      stressPenalty: (json['stress_penalty'] as num?)?.toDouble() ?? 0.0,
      keyCatalysts: (json['key_catalysts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      primaryRisks: (json['primary_risks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      actionableGuidance: json['actionable_guidance'] ?? '',
      summary: json['summary'] ?? '',
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'].toString())
          : null,
    );
  }

  static String _formatPillarLabel(String key) {
    switch (key) {
      case 'trend':
        return 'Trend & Moving Avgs';
      case 'momentum':
        return 'Momentum & Oscillators';
      case 'volatility':
        return 'Volatility & Squeeze';
      case 'flow_gex':
        return 'Options Flow & GEX';
      case 'resilience':
        return 'Adversarial Resilience';
      default:
        return key.replaceAll('_', ' ').toUpperCase();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'direction': direction,
      'conviction_score': convictionScore,
      'conviction_tier': convictionTier,
      'pillar_scores': pillarScores.map((e) => e.toJson()).toList(),
      'stress_penalty': stressPenalty,
      'key_catalysts': keyCatalysts,
      'primary_risks': primaryRisks,
      'actionable_guidance': actionableGuidance,
      'summary': summary,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }
}

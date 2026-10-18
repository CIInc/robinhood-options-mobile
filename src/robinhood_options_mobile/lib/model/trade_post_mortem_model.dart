import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/trading_psychology_model.dart';

/// Flaw identified during trade execution
class ExecutionFlaw {
  final String title;
  final String description;
  final String severity; // High, Medium, Low

  ExecutionFlaw({
    required this.title,
    required this.description,
    this.severity = 'Medium',
  });

  factory ExecutionFlaw.fromJson(Map<String, dynamic> json) {
    return ExecutionFlaw(
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      severity: json['severity']?.toString() ?? 'Medium',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'severity': severity,
    };
  }

  Color get severityColor {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
      default:
        return Colors.blue;
    }
  }
}

/// Comprehensive Post-Mortem Diagnostic Result on an Exited Position
class TradePostMortemAnalysis {
  final String symbol;
  final int executionScore; // 0 - 100
  final String executionGrade; // 'A', 'B', 'C', 'D', 'F'
  final String outcomeVerdict; // 'Good Win', 'Bad Win', 'Good Loss', 'Bad Loss'
  final int thesisAlignmentScore; // 0 - 100
  final List<DetectedBias> detectedBiases;
  final List<ExecutionFlaw> executionFlaws;
  final List<String> tacticalLessons;
  final List<String> autoTags;
  final String coachSummary;
  final DateTime analyzedAt;

  TradePostMortemAnalysis({
    required this.symbol,
    required this.executionScore,
    required this.executionGrade,
    required this.outcomeVerdict,
    required this.thesisAlignmentScore,
    this.detectedBiases = const [],
    this.executionFlaws = const [],
    this.tacticalLessons = const [],
    this.autoTags = const [],
    required this.coachSummary,
    DateTime? analyzedAt,
  }) : analyzedAt = analyzedAt ?? DateTime.now();

  factory TradePostMortemAnalysis.fromJson(Map<String, dynamic> json) {
    final score = (json['execution_score'] as num?)?.toInt() ??
        (json['executionScore'] as num?)?.toInt() ??
        70;
    final grade = json['execution_grade']?.toString() ??
        json['executionGrade']?.toString() ??
        _deriveGrade(score);
    final verdict = json['outcome_verdict']?.toString() ??
        json['outcomeVerdict']?.toString() ??
        'Good Loss';
    final alignment = (json['thesis_alignment_score'] as num?)?.toInt() ??
        (json['thesisAlignmentScore'] as num?)?.toInt() ??
        65;

    final biases = (json['detected_biases'] as List<dynamic>?)
            ?.map((e) => DetectedBias.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final flaws = (json['execution_flaws'] as List<dynamic>?)
            ?.map((e) => ExecutionFlaw.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final lessons = (json['tactical_lessons'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final tags = (json['auto_tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return TradePostMortemAnalysis(
      symbol: json['symbol']?.toString() ?? '',
      executionScore: score,
      executionGrade: grade,
      outcomeVerdict: verdict,
      thesisAlignmentScore: alignment,
      detectedBiases: biases,
      executionFlaws: flaws,
      tacticalLessons: lessons,
      autoTags: tags,
      coachSummary: json['coach_summary']?.toString() ??
          json['coachSummary']?.toString() ??
          '',
      analyzedAt: json['analyzed_at'] != null
          ? DateTime.tryParse(json['analyzed_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  static String _deriveGrade(int score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'execution_score': executionScore,
      'execution_grade': executionGrade,
      'outcome_verdict': outcomeVerdict,
      'thesis_alignment_score': thesisAlignmentScore,
      'detected_biases': detectedBiases.map((b) => b.toJson()).toList(),
      'execution_flaws': executionFlaws.map((f) => f.toJson()).toList(),
      'tactical_lessons': tacticalLessons,
      'auto_tags': autoTags,
      'coach_summary': coachSummary,
      'analyzed_at': analyzedAt.toIso8601String(),
    };
  }

  Color get scoreColor {
    if (executionScore >= 80) return Colors.green;
    if (executionScore >= 65) return Colors.blue;
    if (executionScore >= 50) return Colors.orange;
    return Colors.red;
  }

  Color get outcomeColor {
    final lower = outcomeVerdict.toLowerCase();
    if (lower.contains('good win')) return Colors.green;
    if (lower.contains('good loss')) return Colors.blue;
    if (lower.contains('bad win')) return Colors.orange;
    return Colors.red;
  }

  IconData get outcomeIcon {
    final lower = outcomeVerdict.toLowerCase();
    if (lower.contains('good win')) return Icons.verified;
    if (lower.contains('good loss')) return Icons.shield;
    if (lower.contains('bad win')) return Icons.casino;
    return Icons.warning_amber_rounded;
  }
}

import 'package:flutter/material.dart';

enum NewsSentimentLabel {
  veryBullish,
  bullish,
  neutral,
  bearish,
  veryBearish;

  String get displayName {
    switch (this) {
      case NewsSentimentLabel.veryBullish:
        return 'Very Bullish';
      case NewsSentimentLabel.bullish:
        return 'Bullish';
      case NewsSentimentLabel.neutral:
        return 'Neutral';
      case NewsSentimentLabel.bearish:
        return 'Bearish';
      case NewsSentimentLabel.veryBearish:
        return 'Very Bearish';
    }
  }

  Color get color {
    switch (this) {
      case NewsSentimentLabel.veryBullish:
        return Colors.green.shade700;
      case NewsSentimentLabel.bullish:
        return Colors.green;
      case NewsSentimentLabel.neutral:
        return Colors.grey;
      case NewsSentimentLabel.bearish:
        return Colors.orange.shade800;
      case NewsSentimentLabel.veryBearish:
        return Colors.red;
    }
  }

  static NewsSentimentLabel fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'very bullish':
      case 'verybullish':
        return NewsSentimentLabel.veryBullish;
      case 'bullish':
        return NewsSentimentLabel.bullish;
      case 'very bearish':
      case 'verybearish':
        return NewsSentimentLabel.veryBearish;
      case 'bearish':
        return NewsSentimentLabel.bearish;
      default:
        return NewsSentimentLabel.neutral;
    }
  }
}

enum NewsImpact {
  high,
  medium,
  low;

  String get displayName {
    switch (this) {
      case NewsImpact.high:
        return 'High Impact';
      case NewsImpact.medium:
        return 'Medium Impact';
      case NewsImpact.low:
        return 'Low Impact';
    }
  }

  Color get color {
    switch (this) {
      case NewsImpact.high:
        return Colors.purpleAccent;
      case NewsImpact.medium:
        return Colors.blueAccent;
      case NewsImpact.low:
        return Colors.grey;
    }
  }

  static NewsImpact fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'high':
        return NewsImpact.high;
      case 'medium':
        return NewsImpact.medium;
      default:
        return NewsImpact.low;
    }
  }
}

class NewsArticleItem {
  final String id;
  final String title;
  final String summary;
  final String source;
  final String url;
  final DateTime publishedAt;
  final double sentimentScore; // 0 to 100
  final NewsSentimentLabel sentimentLabel;
  final NewsImpact impact;
  final List<String> symbols;

  const NewsArticleItem({
    required this.id,
    required this.title,
    required this.summary,
    required this.source,
    required this.url,
    required this.publishedAt,
    required this.sentimentScore,
    required this.sentimentLabel,
    required this.impact,
    this.symbols = const [],
  });

  factory NewsArticleItem.fromMap(Map<String, dynamic> map) {
    return NewsArticleItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      summary:
          map['summary']?.toString() ?? map['description']?.toString() ?? '',
      source:
          map['source']?.toString() ?? map['publisher']?.toString() ?? 'News',
      url: map['url']?.toString() ?? '',
      publishedAt: map['publishedAt'] != null
          ? DateTime.tryParse(map['publishedAt'].toString()) ?? DateTime.now()
          : (map['published_at'] != null
              ? DateTime.tryParse(map['published_at'].toString()) ??
                  DateTime.now()
              : DateTime.now()),
      sentimentScore: (map['sentimentScore'] as num?)?.toDouble() ?? 50.0,
      sentimentLabel:
          NewsSentimentLabel.fromString(map['sentimentLabel']?.toString()),
      impact: NewsImpact.fromString(map['impact']?.toString()),
      symbols: (map['symbols'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'source': source,
      'url': url,
      'publishedAt': publishedAt.toIso8601String(),
      'sentimentScore': sentimentScore,
      'sentimentLabel': sentimentLabel.displayName,
      'impact': impact.name,
      'symbols': symbols,
    };
  }
}

class EventImpactPrediction {
  final String direction;
  final double expectedMovePercent;
  final int confidence;
  final String horizon;
  final List<String> drivers;

  const EventImpactPrediction({
    required this.direction,
    required this.expectedMovePercent,
    required this.confidence,
    required this.horizon,
    this.drivers = const [],
  });

  factory EventImpactPrediction.fromMap(Map<String, dynamic>? map) {
    return EventImpactPrediction(
      direction: map?['direction']?.toString() ?? 'Neutral',
      expectedMovePercent:
          (map?['expectedMovePercent'] as num?)?.toDouble() ?? 0.0,
      confidence: (map?['confidence'] as num?)?.toInt() ?? 15,
      horizon: map?['horizon']?.toString() ?? '1-2 weeks',
      drivers: (map?['drivers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class NewsIntelligence {
  final String symbol;
  final double overallSentiment; // 0-100
  final NewsSentimentLabel sentimentLabel;
  final String headlineSummary;
  final List<String> keyTakeaways;
  final List<String> bullishCatalysts;
  final List<String> bearishCatalysts;
  final NewsImpact impactRating;
  final double sentimentScoreChange24h;
  final List<NewsArticleItem> articles;
  final EventImpactPrediction eventImpactPrediction;
  final DateTime updatedAt;

  const NewsIntelligence({
    required this.symbol,
    required this.overallSentiment,
    required this.sentimentLabel,
    required this.headlineSummary,
    this.keyTakeaways = const [],
    this.bullishCatalysts = const [],
    this.bearishCatalysts = const [],
    required this.impactRating,
    this.sentimentScoreChange24h = 0.0,
    this.articles = const [],
    this.eventImpactPrediction = const EventImpactPrediction(
      direction: 'Neutral',
      expectedMovePercent: 0,
      confidence: 15,
      horizon: '1-2 weeks',
    ),
    required this.updatedAt,
  });

  factory NewsIntelligence.fromMap(Map<String, dynamic> map) {
    final rawArticles = map['articles'] as List<dynamic>? ?? [];
    return NewsIntelligence(
      symbol: map['symbol']?.toString() ?? '',
      overallSentiment: (map['overallSentiment'] as num?)?.toDouble() ?? 50.0,
      sentimentLabel:
          NewsSentimentLabel.fromString(map['sentimentLabel']?.toString()),
      headlineSummary: map['headlineSummary']?.toString() ?? '',
      keyTakeaways: (map['keyTakeaways'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      bullishCatalysts: (map['bullishCatalysts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      bearishCatalysts: (map['bearishCatalysts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      impactRating: NewsImpact.fromString(map['impactRating']?.toString()),
      sentimentScoreChange24h:
          (map['sentimentScoreChange24h'] as num?)?.toDouble() ?? 0.0,
      articles: rawArticles
          .whereType<Map>()
          .map((a) => NewsArticleItem.fromMap(Map<String, dynamic>.from(a)))
          .toList(),
      eventImpactPrediction: EventImpactPrediction.fromMap(
          map['eventImpactPrediction'] as Map<String, dynamic>?),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'overallSentiment': overallSentiment,
      'sentimentLabel': sentimentLabel.displayName,
      'headlineSummary': headlineSummary,
      'keyTakeaways': keyTakeaways,
      'bullishCatalysts': bullishCatalysts,
      'bearishCatalysts': bearishCatalysts,
      'impactRating': impactRating.name,
      'sentimentScoreChange24h': sentimentScoreChange24h,
      'articles': articles.map((a) => a.toMap()).toList(),
      'eventImpactPrediction': {
        'direction': eventImpactPrediction.direction,
        'expectedMovePercent': eventImpactPrediction.expectedMovePercent,
        'confidence': eventImpactPrediction.confidence,
        'horizon': eventImpactPrediction.horizon,
        'drivers': eventImpactPrediction.drivers,
      },
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

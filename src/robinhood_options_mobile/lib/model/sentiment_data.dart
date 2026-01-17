enum SentimentSource { news, reddit, twitter, stocktwits, earnings, alphaAgent }

class SentimentData {
  final String? symbol; // Null for overall market sentiment
  final double score; // 0-100 (0=Very Bearish, 100=Very Bullish)
  final double magnitude; // 0-1 (Confidence/Volume weight)
  final SentimentSource source;
  final String summary;
  final DateTime timestamp;
  final List<String> keywords;

  SentimentData({
    this.symbol,
    required this.score,
    required this.magnitude,
    required this.source,
    required this.summary,
    required this.timestamp,
    this.keywords = const [],
  });

  factory SentimentData.fromMap(Map<String, dynamic> map) {
    return SentimentData(
      symbol: map['symbol'],
      score: (map['score'] as num).toDouble(),
      magnitude: (map['magnitude'] as num?)?.toDouble() ?? 1.0,
      source: _parseSource(map['source']),
      summary: map['summary'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      keywords: (map['keywords'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  static SentimentSource _parseSource(String? source) {
    if (source == null) return SentimentSource.news;
    switch (source.toLowerCase()) {
      case 'reddit':
        return SentimentSource.reddit;
      case 'twitter':
        return SentimentSource.twitter;
      case 'stocktwits':
        return SentimentSource.stocktwits;
      case 'earnings':
        return SentimentSource.earnings;
      case 'alpha agent':
        return SentimentSource.alphaAgent;
      default:
        return SentimentSource.news;
    }
  }

  String get sentimentLabel {
    if (score >= 80) return "Very Bullish";
    if (score >= 60) return "Bullish";
    if (score <= 20) return "Very Bearish";
    if (score <= 40) return "Bearish";
    return "Neutral";
  }

  // Helper for UI colors
  String get sentimentColorName {
    if (score >= 60) return "green";
    if (score <= 40) return "red";
    return "grey";
  }
}

class SentimentFeedItem {
  final String title;
  final String sourceName;
  final String url;
  final double sentimentScore;
  final DateTime publishedAt;
  final List<String> relatedSymbols;

  SentimentFeedItem({
    required this.title,
    required this.sourceName,
    required this.url,
    required this.sentimentScore,
    required this.publishedAt,
    required this.relatedSymbols,
  });

  factory SentimentFeedItem.fromMap(Map<String, dynamic> map) {
    return SentimentFeedItem(
      title: map['title'] ?? '',
      sourceName: map['sourceName'] ?? '',
      url: map['url'] ?? '',
      sentimentScore: (map['sentimentScore'] as num).toDouble(),
      publishedAt: DateTime.parse(map['publishedAt']),
      relatedSymbols:
          (map['relatedSymbols'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

class SentimentAnalysisResult {
  final SentimentData market;
  final List<SentimentData> trending;
  final List<SentimentFeedItem> feed;

  SentimentAnalysisResult({
    required this.market,
    required this.trending,
    required this.feed,
  });

  factory SentimentAnalysisResult.fromMap(Map<String, dynamic> map) {
    return SentimentAnalysisResult(
      market: SentimentData.fromMap(
          Map<String, dynamic>.from(map['market'] as Map)),
      trending: (map['trending'] as List<dynamic>)
          .map(
              (e) => SentimentData.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      feed: (map['feed'] as List<dynamic>)
          .map((e) =>
              SentimentFeedItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../model/news_intelligence.dart';

class NewsIntelligenceService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final Map<String, NewsIntelligence> _cache = {};

  Future<NewsIntelligence> getNewsIntelligence(String symbol,
      {List<dynamic>? articles, bool refresh = false}) async {
    final sym = symbol.toUpperCase();
    if (!refresh && _cache.containsKey(sym)) {
      final cached = _cache[sym]!;
      if (DateTime.now().difference(cached.updatedAt).inMinutes < 10) {
        return cached;
      }
    }

    try {
      final callable = _functions.httpsCallable('getNewsIntelligence');
      final response = await callable.call({
        'symbol': sym,
        'articles': articles,
        'refresh': refresh,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final intelligence = NewsIntelligence.fromMap(data);
      _cache[sym] = intelligence;
      return intelligence;
    } catch (e) {
      debugPrint('Error fetching news intelligence for $sym: $e');
      if (articles != null && articles.isNotEmpty) {
        // Local analysis fallback
        final local = _buildLocalNewsIntelligence(sym, articles);
        _cache[sym] = local;
        return local;
      }
      rethrow;
    }
  }

  Future<Map<String, NewsIntelligence>> getWatchlistNewsIntelligence(
      List<String> symbols) async {
    if (symbols.isEmpty) return {};
    try {
      final callable = _functions.httpsCallable('getWatchlistNewsIntelligence');
      final response = await callable.call({
        'symbols': symbols.map((s) => s.toUpperCase()).toList(),
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final result = <String, NewsIntelligence>{};

      data.forEach((key, value) {
        if (value is Map) {
          final item =
              NewsIntelligence.fromMap(Map<String, dynamic>.from(value));
          result[key] = item;
          _cache[key] = item;
        }
      });

      return result;
    } catch (e) {
      debugPrint('Error fetching watchlist news intelligence: $e');
      return {};
    }
  }

  NewsIntelligence _buildLocalNewsIntelligence(
      String symbol, List<dynamic> rawArticles) {
    final items = <NewsArticleItem>[];
    double totalScore = 0;
    final bullish = <String>[];
    final bearish = <String>[];

    for (var i = 0; i < rawArticles.length; i++) {
      final raw = rawArticles[i];
      final title = raw['title']?.toString() ?? 'Market News';
      final summary =
          raw['summary']?.toString() ?? raw['preview_text']?.toString() ?? '';
      final source = raw['source']?.toString() ?? 'News';
      final url = raw['url']?.toString() ?? '';
      final publishedAt = raw['published_at'] != null
          ? DateTime.tryParse(raw['published_at'].toString()) ?? DateTime.now()
          : DateTime.now();

      final lower = '$title $summary'.toLowerCase();
      double score = 50.0;
      if (lower.contains('beat') ||
          lower.contains('record') ||
          lower.contains('upgrade') ||
          lower.contains('growth') ||
          lower.contains('buy')) {
        score = 75.0;
        if (bullish.length < 3) bullish.add(title);
      } else if (lower.contains('miss') ||
          lower.contains('drop') ||
          lower.contains('downgrade') ||
          lower.contains('loss') ||
          lower.contains('lawsuit')) {
        score = 25.0;
        if (bearish.length < 3) bearish.add(title);
      }

      totalScore += score;
      items.add(NewsArticleItem(
        id: '$symbol-news-$i',
        title: title,
        summary: summary,
        source: source,
        url: url,
        publishedAt: publishedAt,
        sentimentScore: score,
        sentimentLabel: score >= 60
            ? NewsSentimentLabel.bullish
            : (score <= 40
                ? NewsSentimentLabel.bearish
                : NewsSentimentLabel.neutral),
        impact: (score - 50).abs() >= 20 ? NewsImpact.high : NewsImpact.medium,
        symbols: [symbol],
      ));
    }

    final avg = items.isNotEmpty ? (totalScore / items.length) : 50.0;
    final label = avg >= 60
        ? NewsSentimentLabel.bullish
        : (avg <= 40 ? NewsSentimentLabel.bearish : NewsSentimentLabel.neutral);

    return NewsIntelligence(
      symbol: symbol,
      overallSentiment: avg,
      sentimentLabel: label,
      headlineSummary: items.isNotEmpty
          ? '$symbol news sentiment is ${label.displayName.toLowerCase()} with ${items.length} recent articles.'
          : 'No breaking news catalysts found.',
      keyTakeaways: items.isNotEmpty ? [items.first.title] : [],
      bullishCatalysts: bullish,
      bearishCatalysts: bearish,
      impactRating: NewsImpact.medium,
      articles: items,
      updatedAt: DateTime.now(),
    );
  }
}

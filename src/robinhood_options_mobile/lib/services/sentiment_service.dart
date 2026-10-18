import 'package:cloud_functions/cloud_functions.dart';
import '../model/sentiment_data.dart';

class SentimentService {
  SentimentAnalysisResult? _cachedResult;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 5);

  Future<SentimentAnalysisResult> getSentimentAnalysis(
      {bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedResult != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      return _cachedResult!;
    }

    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('getSentimentAnalysis');
      final result = await callable.call();

      final data = Map<String, dynamic>.from(result.data as Map);
      _cachedResult = SentimentAnalysisResult.fromMap(data);
      _lastFetchTime = DateTime.now();

      return _cachedResult!;
    } catch (e) {
      throw Exception('Failed to fetch sentiment analysis: $e');
    }
  }

  Future<SentimentData> getMarketSentiment({bool forceRefresh = false}) async {
    final result = await getSentimentAnalysis(forceRefresh: forceRefresh);
    return result.market;
  }

  Future<List<SentimentData>> getTrendingSentiment(
      {bool forceRefresh = false}) async {
    final result = await getSentimentAnalysis(forceRefresh: forceRefresh);
    return result.trending;
  }

  Future<List<SentimentFeedItem>> getSentimentFeed(
      {bool forceRefresh = false}) async {
    final result = await getSentimentAnalysis(forceRefresh: forceRefresh);
    return result.feed;
  }
}

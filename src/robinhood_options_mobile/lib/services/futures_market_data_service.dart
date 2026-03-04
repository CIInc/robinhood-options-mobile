import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';

class FuturesMarketData {
  final List<double> opens;
  final List<double> highs;
  final List<double> lows;
  final List<double> closes;
  final List<int> volumes;
  final List<int> timestamps;
  final double? currentPrice;

  FuturesMarketData({
    required this.opens,
    required this.highs,
    required this.lows,
    required this.closes,
    required this.volumes,
    required this.timestamps,
    this.currentPrice,
  });

  int get length => closes.length;
}

class FuturesMarketDataService {
  final YahooService _yahooService = YahooService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Determines if cached data is still fresh
  bool _isCacheFresh(int? updatedMs, String interval) {
    if (updatedMs == null) return false;

    final now = DateTime.now();
    final cacheAge = now.millisecondsSinceEpoch - updatedMs;

    if (interval == '1d') {
      // For daily data, check if it's from a previous trading day
      return cacheAge < Duration(hours: 24).inMilliseconds;
    } else {
      // For intraday, cache is stale after shorter period
      final maxCacheAge = interval == '15m'
          ? Duration(minutes: 15).inMilliseconds
          : interval == '30m'
              ? Duration(minutes: 30).inMilliseconds
              : Duration(hours: 1).inMilliseconds;
      return cacheAge < maxCacheAge;
    }
  }

  /// Fetch market data for futures with client-side Firestore caching
  /// Avoids server rate limiting by using YahooService directly
  Future<FuturesMarketData> getMarketData({
    required String symbol,
    required int smaPeriodFast,
    required int smaPeriodSlow,
    String interval = '1d',
    String? range,
  }) async {
    final decodedSymbol = Uri.decodeComponent(symbol);
    final cacheKey = interval == '1d'
        ? 'charts/$decodedSymbol'
        : 'charts/${decodedSymbol}_$interval';

    // Try to load from Firestore cache first
    try {
      final doc = await _firestore.doc(cacheKey).get();
      if (doc.exists) {
        final data = doc.data();
        final chart = data?['chart'] as Map<String, dynamic>?;
        final updated = data?['updated'] as int?;

        if (chart != null && _isCacheFresh(updated, interval)) {
          final parsed = _parseChartData(chart);
          if (parsed.closes.isNotEmpty) {
            debugPrint('✅ CACHE HIT: Loaded cached $interval data for '
                '$decodedSymbol (age: ${DateTime.now().millisecondsSinceEpoch - (updated ?? 0)}ms)');
            return parsed;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Cache read failed for $decodedSymbol: $e');
    }

    // Fetch fresh data from Yahoo
    return _fetchAndCacheMarketData(
      symbol: decodedSymbol,
      interval: interval,
      range: range,
      cacheKey: cacheKey,
    );
  }

  /// Fetch market data from Yahoo and cache to Firestore
  Future<FuturesMarketData> _fetchAndCacheMarketData({
    required String symbol,
    required String interval,
    String? range,
    required String cacheKey,
  }) async {
    try {
      // Determine range based on interval if not provided
      final dataRange = range ?? _determineRange(interval, 35);

      debugPrint('🌐 Fetching $interval data for $symbol (range: $dataRange)');

      // Fetch from Yahoo using shared service method
      final result = await _yahooService.getChartData(symbol, dataRange, interval);

      if (result == null) {
        debugPrint('❌ No data returned from Yahoo for $symbol');
        return FuturesMarketData(
          opens: [],
          highs: [],
          lows: [],
          closes: [],
          volumes: [],
          timestamps: [],
        );
      }

      // Cache the raw result matching backend logic
      await _cacheToFirestore(
        cacheKey: cacheKey,
        result: result,
      );

      return _parseChartData(result);
    } catch (e) {
      debugPrint('❌ Failed to fetch market data for $symbol: $e');
      return FuturesMarketData(
        opens: [],
        highs: [],
        lows: [],
        closes: [],
        volumes: [],
        timestamps: [],
      );
    }
  }

  /// Parse cached chart data from Firestore
  FuturesMarketData _parseChartData(Map<String, dynamic> chart) {
    try {
      final timestamp = (chart['timestamp'] as List<dynamic>?)?.cast<int>() ?? [];
      final indicators = chart['indicators'] as Map<String, dynamic>?;
      final quote = (indicators?['quote'] as List<dynamic>?)?[0] as Map<String, dynamic>?;

      if (quote == null || timestamp.isEmpty) {
        return FuturesMarketData(
          opens: [],
          highs: [],
          lows: [],
          closes: [],
          volumes: [],
          timestamps: [],
        );
      }

      final opens = _parseArray(quote['open']);
      final highs = _parseArray(quote['high']);
      final lows = _parseArray(quote['low']);
      final closes = _parseArray(quote['close']);
      final volumes = (quote['volume'] as List?)?.map((v) => (v as num?)?.toInt() ?? 0).toList() ?? [];
      
      // Filter out nulls matching backend logic
      final validIndices = <int>[];
      for (int i = 0; i < closes.length; i++) {
        if (i < timestamp.length && closes[i] != 0.0) {
          validIndices.add(i);
        }
      }

      final fOpens = validIndices.map((i) => opens[i]).toList();
      final fHighs = validIndices.map((i) => highs[i]).toList();
      final fLows = validIndices.map((i) => lows[i]).toList();
      final fCloses = validIndices.map((i) => closes[i]).toList();
      final fVolumes = validIndices.map((i) => volumes[i]).toList();
      final fTimestamps = validIndices.map((i) => timestamp[i]).toList();

      double? currentPrice;
      if (chart['meta'] != null && chart['meta']['regularMarketPrice'] is num) {
        currentPrice = (chart['meta']['regularMarketPrice'] as num).toDouble();
      } else if (fCloses.isNotEmpty) {
        currentPrice = fCloses.last;
      }

      return FuturesMarketData(
        opens: fOpens,
        highs: fHighs,
        lows: fLows,
        closes: fCloses,
        volumes: fVolumes,
        timestamps: fTimestamps,
        currentPrice: currentPrice,
      );
    } catch (e) {
      debugPrint('Error parsing cached chart data: $e');
      return FuturesMarketData(
        opens: [],
        highs: [],
        lows: [],
        closes: [],
        volumes: [],
        timestamps: [],
      );
    }
  }

  /// Helper to parse numeric arrays
  List<double> _parseArray(dynamic data) {
    if (data is List) {
      return data.map((v) {
        if (v is num) {
          return v.toDouble();
        }
        return 0.0;
      }).toList();
    }
    return [];
  }

  /// Determine appropriate range based on interval
  String _determineRange(String interval, int maxPeriod) {
    if (interval == '1d') {
      return maxPeriod > 250 ? '2y' : '1y';
    } else if (interval == '1h') {
      return maxPeriod > 30 ? '1mo' : '5d';
    } else if (interval == '30m') {
      return maxPeriod > 13 ? '5d' : '1d';
    } else if (interval == '15m') {
      return maxPeriod > 26 ? '5d' : '1d';
    }
    return '1y';
  }

  /// Cache market data to Firestore with full chart structure matching backend
  Future<void> _cacheToFirestore({
    required String cacheKey,
    required Map<String, dynamic> result,
  }) async {
    try {
      // Create a copy to modify
      final resultToCache = Map<String, dynamic>.from(result);
      
      // Fix for Firebase which does not support arrays inside arrays
      // Matching backend logic in market-data.ts
      if (resultToCache['meta'] != null) {
        final meta = Map<String, dynamic>.from(resultToCache['meta']);
        meta.remove('tradingPeriods');
        resultToCache['meta'] = meta;
      }

      await _firestore.doc(cacheKey).set({
        'chart': resultToCache,
        'updated': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Failed to cache market data: $e');
    }
  }

  /// Prepopulate cache for multiple symbols - useful for warming cache at app startup
  Future<void> prepopulateCache({
    required List<String> symbols,
    String interval = '1d',
    String? range,
  }) async {
    debugPrint('📥 Prepopulating cache for ${symbols.length} symbols...');
    for (final symbol in symbols) {
      try {
        await getMarketData(
          symbol: symbol,
          smaPeriodFast: 10,
          smaPeriodSlow: 30,
          interval: interval,
          range: range,
        );
      } catch (e) {
        debugPrint('Failed to prepopulate cache for $symbol: $e');
      }
    }
    debugPrint('✅ Cache prepopulation complete');
  }

  /// Clear stale cache entries older than a threshold
  Future<void> clearStaleCache({
    Duration staleDuration = const Duration(days: 7),
  }) async {
    try {
      final cutoffTime =
          DateTime.now().subtract(staleDuration).millisecondsSinceEpoch;
      final snapshot = await _firestore
          .collection('charts')
          .where('updated', isLessThan: cutoffTime)
          .get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
      debugPrint('✅ Cleared ${snapshot.docs.length} stale cache entries');
    } catch (e) {
      debugPrint('Error clearing stale cache: $e');
    }
  }
}

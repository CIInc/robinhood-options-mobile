import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/quote.dart';

/// Represents a cached point-in-time snapshot of the user's portfolio and positions.
class PortfolioSnapshot {
  final DateTime timestamp;
  final List<Account> accounts;
  final List<Portfolio> portfolios;
  final List<InstrumentPosition> stockPositions;
  final List<OptionAggregatePosition> optionPositions;
  final List<ForexHolding> forexHoldings;
  final List<dynamic> futuresPositions;

  PortfolioSnapshot({
    required this.timestamp,
    required this.accounts,
    required this.portfolios,
    required this.stockPositions,
    required this.optionPositions,
    this.forexHoldings = const [],
    this.futuresPositions = const [],
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'accounts': accounts.map((a) => a.toJson()).toList(),
        'portfolios': portfolios.map((p) => p.toJson()).toList(),
        'stockPositions': stockPositions.map((p) => p.toJson()).toList(),
        'optionPositions': optionPositions.map((p) => p.toJson()).toList(),
        'forexHoldings': forexHoldings.map((h) => h.toJson()).toList(),
        'futuresPositions': futuresPositions,
      };

  factory PortfolioSnapshot.fromJson(Map<String, dynamic> json) {
    final timestamp = DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now();

    final accounts = (json['accounts'] as List<dynamic>? ?? [])
        .map((a) => Account.fromJson(a))
        .toList();

    final portfolios = (json['portfolios'] as List<dynamic>? ?? [])
        .map((p) => Portfolio.fromJson(p))
        .toList();

    final stockPositions = (json['stockPositions'] as List<dynamic>? ?? [])
        .map((p) => InstrumentPosition.fromJson(p))
        .toList();

    final optionPositions = (json['optionPositions'] as List<dynamic>? ?? [])
        .map((p) => OptionAggregatePosition.fromJson(p))
        .toList();

    final forexHoldings = (json['forexHoldings'] as List<dynamic>? ?? [])
        .map((h) => ForexHolding.fromJson(h))
        .toList();

    final futuresPositions = (json['futuresPositions'] as List<dynamic>? ?? []);

    return PortfolioSnapshot(
      timestamp: timestamp,
      accounts: accounts,
      portfolios: portfolios,
      stockPositions: stockPositions,
      optionPositions: optionPositions,
      forexHoldings: forexHoldings,
      futuresPositions: futuresPositions,
    );
  }
}

/// Service providing persistent, encrypted/encoded local caching of portfolio
/// balances, positions, market quotes, watchlists, and trade signals for offline viewing.
class OfflineCacheService {
  static const String keyPortfolioSnapshot = 'offline_portfolio_snapshot_v1';
  static const String keyTradeSignals = 'offline_trade_signals_v1';
  static const String keyQuotes = 'offline_quotes_v1';
  static const String keyWatchlists = 'offline_watchlists_v1';
  static const String keyLastSync = 'offline_last_sync_timestamp';

  /// Save full portfolio snapshot to persistent local storage.
  static Future<void> savePortfolioSnapshot({
    required List<Account> accounts,
    required List<Portfolio> portfolios,
    required List<InstrumentPosition> stockPositions,
    required List<OptionAggregatePosition> optionPositions,
    List<ForexHolding>? forexHoldings,
    List<dynamic>? futuresPositions,
    DateTime? customTimestamp,
  }) async {
    try {
      final now = customTimestamp ?? DateTime.now();
      final snapshot = PortfolioSnapshot(
        timestamp: now,
        accounts: accounts,
        portfolios: portfolios,
        stockPositions: stockPositions,
        optionPositions: optionPositions,
        forexHoldings: forexHoldings ?? [],
        futuresPositions: futuresPositions ?? [],
      );

      final jsonString = jsonEncode(snapshot.toJson(), toEncodable: Constants.toEncodable);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyPortfolioSnapshot, jsonString);
      await prefs.setString(keyLastSync, now.toIso8601String());
      debugPrint('OfflineCacheService: Saved snapshot with ${accounts.length} accounts, ${stockPositions.length} stocks, ${optionPositions.length} options at $now');
    } catch (e, stackTrace) {
      debugPrint('OfflineCacheService: Error saving portfolio snapshot: $e\n$stackTrace');
    }
  }

  /// Load cached portfolio snapshot from persistent storage.
  static Future<PortfolioSnapshot?> loadPortfolioSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(keyPortfolioSnapshot);
      if (jsonString == null || jsonString.isEmpty) {
        return null;
      }
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return PortfolioSnapshot.fromJson(decoded);
      }
    } catch (e, stackTrace) {
      debugPrint('OfflineCacheService: Error loading portfolio snapshot: $e\n$stackTrace');
    }
    return null;
  }

  /// Save trade signals to local cache.
  static Future<void> saveTradeSignals(List<Map<String, dynamic>> signals) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(signals, toEncodable: Constants.toEncodable);
      await prefs.setString(keyTradeSignals, jsonString);
    } catch (e) {
      debugPrint('OfflineCacheService: Error saving trade signals: $e');
    }
  }

  /// Load cached trade signals.
  static Future<List<Map<String, dynamic>>> loadTradeSignals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(keyTradeSignals);
      if (jsonString != null && jsonString.isNotEmpty) {
        final decoded = jsonDecode(jsonString);
        if (decoded is List) {
          return decoded.cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      debugPrint('OfflineCacheService: Error loading trade signals: $e');
    }
    return [];
  }

  /// Save market quotes to local cache.
  static Future<void> saveQuotes(List<Quote> quotes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(quotes.map((q) => q.toJson()).toList(),
          toEncodable: Constants.toEncodable);
      await prefs.setString(keyQuotes, jsonString);
    } catch (e) {
      debugPrint('OfflineCacheService: Error saving quotes: $e');
    }
  }

  /// Load cached market quotes.
  static Future<List<Quote>> loadQuotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(keyQuotes);
      if (jsonString != null && jsonString.isNotEmpty) {
        final decoded = jsonDecode(jsonString);
        if (decoded is List) {
          return decoded.map((q) => Quote.fromJson(q)).toList();
        }
      }
    } catch (e) {
      debugPrint('OfflineCacheService: Error loading quotes: $e');
    }
    return [];
  }

  /// Save watchlist symbols to local cache.
  static Future<void> saveWatchlistSymbols(List<String> symbols) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(keyWatchlists, symbols);
    } catch (e) {
      debugPrint('OfflineCacheService: Error saving watchlists: $e');
    }
  }

  /// Load cached watchlist symbols.
  static Future<List<String>> loadWatchlistSymbols() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(keyWatchlists) ?? [];
    } catch (e) {
      debugPrint('OfflineCacheService: Error loading watchlists: $e');
      return [];
    }
  }

  /// Get the timestamp of the last successful data sync.
  static Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final iso = prefs.getString(keyLastSync);
      if (iso != null && iso.isNotEmpty) {
        return DateTime.tryParse(iso);
      }
    } catch (_) {}
    return null;
  }

  /// Clear all cached offline data.
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyPortfolioSnapshot);
      await prefs.remove(keyTradeSignals);
      await prefs.remove(keyQuotes);
      await prefs.remove(keyWatchlists);
      await prefs.remove(keyLastSync);
    } catch (e) {
      debugPrint('OfflineCacheService: Error clearing cache: $e');
    }
  }

  /// Evaluates whether the cached data is considered stale based on a threshold (default 15 mins).
  static bool isDataStale(DateTime? timestamp, {Duration threshold = const Duration(minutes: 15)}) {
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > threshold;
  }

  /// Generates a human-friendly relative time label, e.g. "Just now", "5m ago", "2h ago", "Yesterday".
  static String formatRelativeTime(DateTime? timestamp) {
    if (timestamp == null) return 'Never';
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  /// Formats exact sync date and time, e.g. "Oct 12, 10:30 AM".
  static String formatSyncDateTime(DateTime? timestamp) {
    if (timestamp == null) return 'Unknown';
    return DateFormat('MMM d, h:mm a').format(timestamp);
  }
}

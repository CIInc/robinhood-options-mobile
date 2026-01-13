import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:robinhood_options_mobile/model/option_flow_item.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';

enum FlowSortOption { time, premium, strike, expiration, volOi, score }

class OptionsFlowStore extends ChangeNotifier {
  static const Map<String, String> flagDocumentation = {
    'SWEEP':
        'Orders executed across multiple exchanges to fill a large order quickly. Indicates urgency and stealth. Often a sign of institutional buying.',
    'BLOCK':
        'Large privately negotiated orders. Often institutional rebalancing or hedging. Less urgent than sweeps.',
    'DARK POOL':
        'Off-exchange trading. Used by institutions to hide intent and avoid market impact. Can indicate accumulation.',
    'BULLISH':
        'Positive sentiment. Calls bought at Ask or Puts sold at Bid. Expecting price to rise.',
    'BEARISH':
        'Negative sentiment. Puts bought at Ask or Calls sold at Bid. Expecting price to fall.',
    'NEUTRAL':
        'Neutral sentiment. Trade executed between bid and ask, or straddle/strangle strategy.',
    'ITM':
        'In The Money. Strike price is favorable (e.g. Call Strike < Stock Price). Higher probability, more expensive. Often used for stock replacement.',
    'OTM':
        'Out The Money. Strike price is not yet favorable. Lower probability, cheaper, higher leverage. Pure directional speculation.',
    'WHALE':
        'Massive institutional order >\$1M premium. Represents highest conviction from major players.',
    'Golden Sweep':
        'Large sweep order >\$1M premium executed at/above ask. Strong directional betting.',
    'Steamroller':
        'Massive size (>\$500k), short term (<30 days), aggressive OTM sweep.',
    'Mega Vol':
        'Volume is >10x Open Interest. Extreme unusual activity indicating major new positioning.',
    'Vol Explosion':
        'Volume is >5x Open Interest. Significant unusual activity.',
    'High Vol/OI': 'Volume is >1.5x Open Interest. Indicates unusual interest.',
    'New Position':
        'Volume exceeds Open Interest, confirming new contracts are being opened.',
    'Aggressive':
        'Order executed at or above the ask price, showing urgency to enter the position.',
    'Tight Spread':
        'Bid-Ask spread < 5%. Indicates high liquidity and potential institutional algo execution.',
    'Wide Spread':
        'Bid-Ask spread > 20%. Warning: Low liquidity or poor execution prices.',
    'Bullish Divergence':
        'Call buying while stock is down. Smart money betting on a reversal.',
    'Bearish Divergence':
        'Put buying while stock is up. Smart money betting on a reversal.',
    'Panic Hedge':
        'Short-dated (<7 days), OTM puts with high volume (>5k) and OI (>1k). Fear/hedging against crash.',
    'Gamma Squeeze':
        'Short-dated (<7 days), OTM calls with high volume (>5k) and OI (>1k). Can force dealer buying.',
    'Contrarian':
        'Trade direction opposes current stock trend (>2% move). Betting on reversal.',
    'Earnings Play':
        'Options expiring shortly after earnings (2-14 days). Betting on volatility event.',
    'Extreme IV':
        'Implied Volatility > 250%. Extreme fear/greed or binary event.',
    'High IV': 'Implied Volatility > 100%. Market pricing in a massive move.',
    'Low IV': 'Implied Volatility < 20%. Options are cheap. Good for buying.',
    'Cheap Vol':
        'High volume (>2000) on low-priced options (<\$0.50). Speculative activity on cheap contracts.',
    'High Premium':
        'Significant volume (>100) on expensive options (>\$20.00). High capital commitment per contract.',
    '0DTE': 'Expires today. Maximum gamma risk/reward. Pure speculation.',
    'Weekly OTM':
        'Expires < 1 week and Out-of-the-Money with volume > 500. Short-term speculative bet.',
    'LEAPS': 'Expires > 1 year. Long-term investment substitute for stock.',
    'Lotto':
        'Cheap OTM (>15%) options (< \$1.00). High risk, potential 10x+ return.',
    'ATM Flow':
        'At-The-Money options (strike within 1% of spot). High Gamma potential, often used by market makers.',
    'Deep ITM':
        'Deep In-The-Money contracts (>10% ITM). Often used as a stock replacement strategy.',
    'Deep OTM':
        'Deep Out-Of-The-Money contracts (>15% OTM). Aggressive speculative bets.',
    'UNUSUAL':
        'Volume > Open Interest. Indicates new positioning and potential institutional interest.',
    'Above Ask':
        'Trade executed at a price higher than the ask price. Indicates extreme urgency to buy.',
    'Below Bid':
        'Trade executed at a price lower than the bid price. Indicates extreme urgency to sell.',
    'Mid Market':
        'Trade executed between the bid and ask prices. Often indicates a negotiated block trade or less urgency.',
    'Ask Side': 'Trade executed at the ask price. Indicates buying pressure.',
    'Bid Side': 'Trade executed at the bid price. Indicates selling pressure.',
    'Large Block / Dark Pool':
        'Large block trade, possibly executed off-exchange (Dark Pool). Institutional accumulation or distribution.',
  };

  List<OptionFlowItem> _allItems = [];
  List<OptionFlowItem> _items = [];
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = false;
  String? _filterSymbol;
  List<String>? _filterSymbols;
  Sentiment? _filterSentiment;
  bool _filterUnusual = false;
  bool _filterHighConviction = false;
  String? _filterMoneyness; // 'ITM', 'OTM'
  FlowType? _filterFlowType;
  String? _filterExpiration; // '0-7', '8-30', '30+'
  String? _filterSector;
  double? _filterMinCap; // in billions
  List<String>? _filterFlags;
  FlowSortOption _sortOption = FlowSortOption.time;

  List<OptionFlowItem> get items => _items;
  List<OptionFlowItem> get allItems => _allItems;
  List<Map<String, dynamic>> get alerts => _alerts;
  bool get isLoading => _isLoading;
  String? get filterSymbol => _filterSymbol;
  List<String>? get filterSymbols => _filterSymbols;
  Sentiment? get filterSentiment => _filterSentiment;
  bool get filterUnusual => _filterUnusual;
  bool get filterHighConviction => _filterHighConviction;
  String? get filterMoneyness => _filterMoneyness;
  FlowType? get filterFlowType => _filterFlowType;
  String? get filterExpiration => _filterExpiration;
  String? get filterSector => _filterSector;
  double? get filterMinCap => _filterMinCap;
  List<String>? get filterFlags => _filterFlags;
  FlowSortOption get sortOption => _sortOption;

  double get totalBullishPremium => _items
      .where((i) => i.sentiment == Sentiment.bullish)
      .fold(0.0, (sum, item) => sum + item.premium);

  double get totalBearishPremium => _items
      .where((i) => i.sentiment == Sentiment.bearish)
      .fold(0.0, (sum, item) => sum + item.premium);

  OptionsFlowStore() {
    // Load initial data
    // refresh();
    loadAlerts();
  }

  Future<void> loadAlerts() async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getOptionAlerts')
          .call();
      final data = Map<String, dynamic>.from(result.data);
      _alerts = (data['alerts'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading alerts: $e');
    }
  }

  Future<void> createAlert({
    required String symbol,
    double? targetPremium,
    String? sentiment,
    String? condition,
  }) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('createOptionAlert').call({
        'symbol': symbol,
        'targetPremium': targetPremium,
        'sentiment': sentiment,
        'condition': condition,
      });
      await loadAlerts();
    } catch (e) {
      debugPrint('Error creating alert: $e');
      rethrow;
    }
  }

  Future<void> deleteAlert(String alertId) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('deleteOptionAlert').call({
        'alertId': alertId,
      });
      await loadAlerts();
    } catch (e) {
      debugPrint('Error deleting alert: $e');
      rethrow;
    }
  }

  Future<void> toggleAlert(String alertId, bool isActive) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('toggleOptionAlert').call({
        'alertId': alertId,
        'isActive': isActive,
      });
      await loadAlerts();
    } catch (e) {
      debugPrint('Error toggling alert: $e');
      rethrow;
    }
  }

  void setFilters({
    String? symbol,
    Sentiment? sentiment,
    bool? highConviction,
    bool? unusual,
    String? moneyness,
    FlowType? flowType,
    String? expiration,
    String? sector,
    double? minCap,
    List<String>? flags,
  }) {
    _filterSymbol = symbol;
    _filterSentiment = sentiment;
    _filterHighConviction = highConviction ?? false;
    _filterUnusual = unusual ?? false;
    _filterMoneyness = moneyness;
    _filterFlowType = flowType;
    _filterExpiration = expiration;
    _filterSector = sector;
    _filterMinCap = minCap;
    _filterFlags = flags;
    refresh();
  }

  void setFilterSymbol(String? symbol) {
    _filterSymbol = symbol;
    _filterSymbols = null;
    refresh();
  }

  void setFilterSymbols(List<String>? symbols) {
    _filterSymbols = symbols;
    _filterSymbol = null;
    refresh();
  }

  void setFilterSentiment(Sentiment? sentiment) {
    _filterSentiment = sentiment;
    _applyFilters();
    notifyListeners();
  }

  void setFilterUnusual(bool unusual) {
    _filterUnusual = unusual;
    _applyFilters();
    notifyListeners();
  }

  void setFilterHighConviction(bool highConviction) {
    _filterHighConviction = highConviction;
    _applyFilters();
    notifyListeners();
  }

  void setFilterMoneyness(String? moneyness) {
    _filterMoneyness = moneyness;
    _applyFilters();
    notifyListeners();
  }

  void setFilterFlowType(FlowType? flowType) {
    _filterFlowType = flowType;
    _applyFilters();
    notifyListeners();
  }

  void setFilterExpiration(String? expiration) {
    _filterExpiration = expiration;
    refresh();
  }

  void setFilterSector(String? sector) {
    _filterSector = sector;
    _applyFilters();
    notifyListeners();
  }

  void setFilterMinCap(double? minCap) {
    _filterMinCap = minCap;
    _applyFilters();
    notifyListeners();
  }

  void setFilterFlags(List<String>? flags) {
    _filterFlags = flags;
    _applyFilters();
    notifyListeners();
  }

  void setSortOption(FlowSortOption option) {
    _sortOption = option;
    _applyFilters();
    notifyListeners();
  }

  int _getDaysDifference(DateTime date1, DateTime date2) {
    final d1 = DateTime(date1.year, date1.month, date1.day);
    final d2 = DateTime(date2.year, date2.month, date2.day);
    return d2.difference(d1).inDays;
  }

  List<DateTime> _filterExpirationDates(List<DateTime> dates, String? filter) {
    if (filter == null) return dates;
    final now = DateTime.now();
    return dates.where((date) {
      final days = _getDaysDifference(now, date);
      if (filter == '0-7') return days >= -1 && days <= 7;
      if (filter == '8-30') return days > 7 && days <= 30;
      if (filter == '30+') return days > 30;
      return true;
    }).toList();
  }

  bool _isDateInOptions(DateTime date, List<dynamic> options) {
    return options.any((opt) {
      final calls = opt['calls'] as List?;
      final puts = opt['puts'] as List?;
      final c = calls?.isNotEmpty == true ? calls![0] : null;
      final p = puts?.isNotEmpty == true ? puts![0] : null;
      if (c == null && p == null) return false;

      dynamic val;
      if (c != null && c['expiration'] != null) {
        val = c['expiration'];
      } else if (p != null && p['expiration'] != null) {
        val = p['expiration'];
      }

      DateTime? expDate;
      if (val is DateTime) {
        expDate = val;
      } else if (val is Timestamp) {
        // TODO: Should not occur, to remove
        expDate = val.toDate();
      } else {
        debugPrint('Unexpected expiration date type: ${val.runtimeType}');
      }
      // else if (val is DateTime) {
      //   expDate = val;
      // } else if (val is int) {
      //   expDate = DateTime.fromMillisecondsSinceEpoch(val * 1000);
      // } else if (val is Map && val['raw'] is int) {
      //   expDate = DateTime.fromMillisecondsSinceEpoch(val['raw'] * 1000);
      // }

      if (expDate == null) return false;
      return _getDaysDifference(expDate, date) == 0;
    });
  }

  Future<List<OptionFlowItem>> fetchYahooFlowItems(
      String symbol, String? expiration) async {
    try {
      final db = FirebaseFirestore.instance;
      final docRef = db.collection('yahoo_options_results').doc(symbol);

      Map<String, dynamic>? cachedResult;
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          // final lastUpdated = data['lastUpdated'] as int? ?? 0;
          // // 30 days TTL
          // if (DateTime.now().millisecondsSinceEpoch - lastUpdated <
          //     30 * 24 * 60 * 60 * 1000) {
          cachedResult = data;
          // }

          // Fetch expirations from subcollection
          final expirationsSnapshot =
              await docRef.collection('expirations').get();
          if (expirationsSnapshot.docs.isNotEmpty) {
            final options =
                expirationsSnapshot.docs.map((d) => d.data()).toList();
            cachedResult['options'] = options;
          }
        }
      }

      final yahooService = YahooService();
      if (cachedResult == null) {
        final result = await yahooService.getOptionChain(symbol);

        if (result.isEmpty) {
          return [];
        }

        // Initial processing to match Firestore structure
        cachedResult = Map<String, dynamic>.from(result);
        // cachedResult['lastUpdated'] = DateTime.now().millisecondsSinceEpoch;

        // Fetch sector if missing
        if (cachedResult['quote'] != null &&
            cachedResult['quote']['sector'] == null) {
          try {
            final profileData = await yahooService.getAssetProfile(symbol);
            if (profileData['quoteSummary'] != null &&
                profileData['quoteSummary']['result'] != null &&
                (profileData['quoteSummary']['result'] as List).isNotEmpty) {
              final profile =
                  profileData['quoteSummary']['result'][0]['assetProfile'];
              if (profile != null) {
                if (cachedResult['quote'] is Map) {
                  cachedResult['quote']['sector'] = profile['sector'];
                  cachedResult['quote']['industry'] = profile['industry'];
                }
              }
            }
          } catch (e) {
            debugPrint('Error fetching asset profile: $e');
          }
        }

        // Persist initial cache
        await _saveYahooOptionsResult(docRef, cachedResult);
        // await docRef.set(_sanitizeForFirestore(cachedResult));
      }

      // Now we have cachedResult (either from DB or fresh fetch)
      final expirationDatesRaw = cachedResult['expirationDates'] as List?;
      final List<DateTime> expirationDates = expirationDatesRaw?.map((e) {
            if (e is Timestamp) return e.toDate();
            if (e is int) return DateTime.fromMillisecondsSinceEpoch(e * 1000);
            if (e is DateTime) return e;
            return DateTime.now(); // Should not happen
          }).toList() ??
          [];

      final targetDates = _filterExpirationDates(expirationDates, expiration);

      var existingOptions = (cachedResult['options'] as List?) ?? [];

      // Remove expired options
      final now = DateTime.now();
      existingOptions = existingOptions.where((opt) {
        final exp = opt['expirationDate'];
        if (exp is DateTime) {
          return exp.isAfter(now.subtract(const Duration(days: 1)));
        } else if (exp is Timestamp) {
          final expDate = exp.toDate();
          return expDate.isAfter(now.subtract(const Duration(days: 1)));
        } else if (exp is int) {
          // TODO: Should not occur, to remove
          final expDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
          return expDate.isAfter(now.subtract(const Duration(days: 1)));
        }
        return false;
      }).toList();
      cachedResult['options'] = existingOptions;

      // Find missing dates
      final missingDates = targetDates
          .where((date) => !_isDateInOptions(date, existingOptions))
          .toList();

      if (missingDates.isNotEmpty) {
        // Fetch missing dates (limit to 4)
        final datesToFetch = missingDates.take(1).toList();

        if (datesToFetch.isNotEmpty) {
          // final yahooService = YahooService();
          final futures = datesToFetch.map((date) =>
              yahooService.getOptionChain(symbol,
                  date: date.millisecondsSinceEpoch ~/ 1000));

          final results = await Future.wait(futures);

          final newOptions = results.expand((data) {
            if (data.isEmpty) {
              return [];
            }
            return (data['options'] as List? ?? []);
          }).toList();

          // Merge
          cachedResult['options'] = [...existingOptions, ...newOptions];
          cachedResult['lastUpdated'] = DateTime.now().millisecondsSinceEpoch;

          // Persist updated cache
          try {
            await _saveYahooOptionsResult(docRef, cachedResult);

            // // Deep copy to avoid modifying cachedResult in place during sanitization/conversion
            // final dataToSave = _sanitizeForFirestore(cachedResult);

            // if (dataToSave['expirationDates'] != null) {
            //   dataToSave['expirationDates'] =
            //       (dataToSave['expirationDates'] as List).map((e) {
            //     if (e is int) {
            //       return Timestamp.fromMillisecondsSinceEpoch(e * 1000);
            //     }
            //     if (e is DateTime) return Timestamp.fromDate(e);
            //     return e;
            //   }).toList();
            // }

            // // Options dates conversion
            // if (dataToSave['options'] != null) {
            //   dataToSave['options'] =
            //       (dataToSave['options'] as List).map((opt) {
            //     final optMap = Map<String, dynamic>.from(opt);
            //     // Helper to convert dates in calls/puts
            //     List<Map<String, dynamic>> convertContracts(List? contracts) {
            //       if (contracts == null) return [];
            //       return contracts.map((c) {
            //         final cMap = Map<String, dynamic>.from(c);
            //         if (cMap['expiration'] != null) {
            //           final val = cMap['expiration'];
            //           if (val is int) {
            //             cMap['expiration'] =
            //                 Timestamp.fromMillisecondsSinceEpoch(val * 1000);
            //           } else if (val is Map && val['raw'] is int)
            //             cMap['expiration'] =
            //                 Timestamp.fromMillisecondsSinceEpoch(
            //                     val['raw'] * 1000);
            //           else if (val is DateTime)
            //             cMap['expiration'] = Timestamp.fromDate(val);
            //         }
            //         if (cMap['lastTradeDate'] != null) {
            //           final val = cMap['lastTradeDate'];
            //           if (val is int) {
            //             cMap['lastTradeDate'] =
            //                 Timestamp.fromMillisecondsSinceEpoch(val * 1000);
            //           } else if (val is Map && val['raw'] is int)
            //             cMap['lastTradeDate'] =
            //                 Timestamp.fromMillisecondsSinceEpoch(
            //                     val['raw'] * 1000);
            //           else if (val is DateTime)
            //             cMap['lastTradeDate'] = Timestamp.fromDate(val);
            //         }
            //         return cMap;
            //       }).toList();
            //     }

            //     if (optMap['calls'] != null) {
            //       optMap['calls'] = convertContracts(optMap['calls']);
            //     }
            //     if (optMap['puts'] != null) {
            //       optMap['puts'] = convertContracts(optMap['puts']);
            //     }
            //     return optMap;
            //   }).toList();
            // }

            // await docRef.set(dataToSave);
          } catch (e) {
            debugPrint('Error persisting yahoo options result: $e');
          }
        }
      }

      final quote = cachedResult['quote'];
      final options = cachedResult['options'] as List;
      final double spotPrice = quote['regularMarketPrice']?.toDouble() ?? 0.0;
      final double? marketCap = quote['marketCap']?.toDouble();
      final int? earningsTimestamp = quote['earningsTimestamp'];

      List<OptionFlowItem> newItems = [];

      for (var optionDate in options) {
        // final expirationDate = DateTime.fromMillisecondsSinceEpoch(
        //     optionDate['expirationDate'] * 1000);
        final expirationDate = optionDate['expirationDate'] is DateTime
            ? optionDate['expirationDate']
            : optionDate['expirationDate'] is Timestamp
                ? optionDate['expirationDate'].toDate()
                : DateTime.fromMillisecondsSinceEpoch(
                    optionDate['expirationDate'] * 1000);

        // Process Calls
        if (optionDate['calls'] != null) {
          for (var call in optionDate['calls']) {
            _processOptionContract(
                call, 'Call', symbol, expirationDate, spotPrice, newItems,
                marketCap: marketCap, earningsTimestamp: earningsTimestamp);
          }
        }

        // Process Puts
        if (optionDate['puts'] != null) {
          for (var put in optionDate['puts']) {
            _processOptionContract(
                put, 'Put', symbol, expirationDate, spotPrice, newItems,
                marketCap: marketCap, earningsTimestamp: earningsTimestamp);
          }
        }
      }

      // Apply expiration filter to items
      if (expiration != null) {
        final now = DateTime.now();
        newItems = newItems.where((item) {
          final days = _getDaysDifference(now, item.expirationDate);
          if (expiration == '0-7') return days >= -1 && days <= 7;
          if (expiration == '8-30') return days > 7 && days <= 30;
          if (expiration == '30+') return days > 30;
          return true;
        }).toList();
      }

      // Sort by premium descending
      newItems.sort((a, b) => b.premium.compareTo(a.premium));
      return newItems;
    } catch (e) {
      debugPrint('Error fetching client side flow: $e');
      return [];
    }
  }

  Future<void> _saveYahooOptionsResult(
      DocumentReference docRef, Map<String, dynamic> data) async {
    final options = data['options'] as List?;
    final metadata = Map<String, dynamic>.from(data);
    metadata.remove('options');

    await docRef.set(metadata);

    if (options != null && options.isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();
      final expirationsRef = docRef.collection('expirations');

      for (var opt in options) {
        if (opt is Map<String, dynamic>) {
          dynamic expDate = opt['expirationDate'];
          String? dateId;

          if (expDate is int) {
            dateId = expDate.toString();
          } else if (expDate is Timestamp) {
            dateId = (expDate.seconds).toString();
          } else if (expDate is DateTime) {
            dateId = (expDate.millisecondsSinceEpoch ~/ 1000).toString();
          }

          if (dateId != null) {
            batch.set(expirationsRef.doc(dateId), opt);
          }
        }
      }
      await batch.commit();
    }
  }

  dynamic _sanitizeForFirestore(dynamic value) {
    if (value is double && value.isNaN) {
      return null;
    }
    if (value is Map) {
      // return value.map((k, v) => MapEntry(k, _sanitizeForFirestore(v)));
      return value
          .map((k, v) => MapEntry(k.toString(), _sanitizeForFirestore(v)))
          .cast<String, dynamic>();
    }
    if (value is List) {
      return value.map((e) => _sanitizeForFirestore(e)).toList();
    }
    return value;
  }

  static dynamic _extractValue(dynamic val) {
    if (val is Map) {
      return val['raw'];
    }
    return val;
  }

  static ({Sentiment sentiment, String details, FlowType flowType})
      _analyzeTradeExecution(bool isCall, double lastPrice, double bid,
          double ask, int volume, int openInterest, double premium) {
    Sentiment sentiment = isCall ? Sentiment.bullish : Sentiment.bearish;
    String details = isCall ? 'Ask Side' : 'Bid Side';

    if (bid > 0 && ask > 0) {
      if (lastPrice >= ask) {
        details = 'Above Ask';
        sentiment = isCall ? Sentiment.bullish : Sentiment.bearish;
      } else if (lastPrice <= bid) {
        details = 'Below Bid';
        sentiment = isCall ? Sentiment.bearish : Sentiment.bullish;
      } else {
        final mid = (bid + ask) / 2;
        details = 'Mid Market';
        if (lastPrice > mid) {
          sentiment = isCall ? Sentiment.bullish : Sentiment.bearish;
        } else {
          sentiment = isCall ? Sentiment.bearish : Sentiment.bullish;
        }
      }
    } else {
      details = 'Mid Market';
    }

    FlowType flowType = FlowType.block;
    if (openInterest > 0 && volume > openInterest) {
      flowType = FlowType.sweep;
    } else if (premium > 100000) {
      flowType = FlowType.block;
    }

    if (bid > 0 && ask > 0 && volume > 5000) {
      if (lastPrice == bid || lastPrice == ask) {
        // flowType = FlowType.cross; // Assuming FlowType has cross, if not use block
        details = 'Cross Trade';
        sentiment = Sentiment.neutral;
      }
    }

    return (sentiment: sentiment, details: details, flowType: flowType);
  }

  static ({List<String> flags, List<String> reasons, bool isUnusual})
      _detectFlags({
    required double premium,
    required FlowType flowType,
    required bool isOTM,
    required String details,
    required int openInterest,
    required int volume,
    required int daysToExpiration,
    required bool isCall,
    required double? changePercent,
    required int? earningsTimestamp,
    required DateTime expirationDate,
    required DateTime now,
    required double iv,
    required double spotPrice,
    required double strike,
    required double bid,
    required double ask,
    required double? marketCap,
    required double lastPrice,
    double? delta,
    double? gamma,
  }) {
    final flags = <String>[];
    final reasons = <String>[];
    bool isUnusual = false;

    // Super Whale
    if (premium > 5000000) {
      if (delta != null && delta.abs() > 0.4) {
        flags.add('Delta Whale');
        reasons.add(
            'Massive premium with high delta exposure (${delta.toStringAsFixed(2)})');
      } else {
        flags.add('Super Whale');
        reasons.add('Massive premium > \$5M');
      }
      isUnusual = true;
    }

    // Whale
    final isSmallCap = marketCap != null && marketCap < 2000000000;
    final whaleThreshold = isSmallCap ? 200000 : 1000000;
    if (premium > whaleThreshold && premium <= 5000000) {
      flags.add('WHALE');
      reasons.add('Large premium > \$${whaleThreshold ~/ 1000}k');
      isUnusual = true;
    }

    // Institutional
    if (premium > 2000000 && flowType == FlowType.block) {
      flags.add('Institutional');
      reasons.add('Large block trade > \$2M premium');
      isUnusual = true;
    }

    // Golden Sweep
    if (flowType == FlowType.sweep &&
        premium > 1000000 &&
        isOTM &&
        details == 'Above Ask' &&
        volume > openInterest) {
      flags.add('Golden Sweep');
      reasons.add(
          'High-conviction sweep: Premium > \$1M, OTM, Above Ask, Vol > OI');
      isUnusual = true;
    }

    // Steamroller
    if (((isCall && spotPrice > strike * 1.1) ||
            (!isCall && spotPrice < strike * 0.9)) &&
        volume > 500 &&
        volume > openInterest) {
      flags.add('Steamroller');
      reasons.add('Deep ITM position with heavy volume exceeding OI');
      isUnusual = true;
    }

    // New Position
    if (openInterest > 0 && volume > openInterest) {
      flags.add('New Position');
      reasons.add('Volume exceeds Open Interest');
      isUnusual = true;
    }

    // Gamma Squeeze - enhanced with gamma if avail
    bool isPotentialGammaSqueeze = daysToExpiration <= 2 &&
        isCall &&
        isOTM &&
        volume > openInterest &&
        (changePercent ?? 0) > 1.0;

    if (isPotentialGammaSqueeze) {
      if (gamma != null) {
        if (gamma > 0.1) {
          flags.add('High Gamma Squeeze');
          reasons.add('Short-dated OTM calls with extreme Gamma sensitivity');
          isUnusual = true;
        } else if (gamma > 0.05) {
          flags.add('Gamma Squeeze');
          reasons.add(
              'Short-dated OTM calls with high volume and Gamma sensitivity');
          isUnusual = true;
        } else {
          // Standard gamma squeeze logic
          flags.add('Gamma Squeeze');
          reasons
              .add('Short-dated OTM calls with high volume and rising price');
          isUnusual = true;
        }
      } else {
        flags.add('Gamma Squeeze');
        reasons.add('Short-dated OTM calls with high volume and rising price');
        isUnusual = true;
      }
    } else if (gamma != null && gamma > 0.1 && volume > 1000 && isOTM) {
      // Gamma exposure detection even if not full squeeze conditions
      flags.add('Gamma Exposure');
      reasons.add('High Gamma sensitivity position');
      isUnusual = true;
    }

    // Panic Hedge
    if (!isCall &&
        (changePercent ?? 0) < -2.0 &&
        isOTM &&
        details == 'Above Ask') {
      flags.add('Panic Hedge');
      reasons.add('Aggressive OTM puts bought while stock is down');
      isUnusual = true;
    }

    // Floor Protection
    if (!isCall && spotPrice > strike * 1.2 && volume > 1000) {
      flags.add('Floor Protection');
      reasons.add('High volume deep OTM puts');
    }

    // Earnings Play
    if (earningsTimestamp != null) {
      final earningsDate =
          DateTime.fromMillisecondsSinceEpoch(earningsTimestamp * 1000);
      final daysToEarnings = earningsDate.difference(now).inDays;
      if (daysToEarnings >= 0 &&
          daysToEarnings <= 14 &&
          expirationDate.isAfter(earningsDate)) {
        flags.add('Earnings Play');
        reasons.add('Options expire shortly after earnings');
        isUnusual = true;
      }

      if (daysToEarnings >= 0 && daysToEarnings <= 2 && iv > 1.0) {
        flags.add('IV Crush Risk');
        reasons.add('High IV just before earnings');
      }
    }

    // Contrarian / Divergence
    if (changePercent != null) {
      if (isCall && changePercent < -1.0) {
        flags.add('Bullish Divergence');
        reasons.add('Calls bought despite stock dropping');
        isUnusual = true;
      } else if (!isCall && changePercent > 1.0) {
        flags.add('Bearish Divergence');
        reasons.add('Puts bought despite stock rising');
        isUnusual = true;
      } else if (isCall && changePercent < -2.0) {
        flags.add('Contrarian');
        reasons.add('Calls bought opposing strong downtrend');
        isUnusual = true;
      } else if (!isCall && changePercent > 2.0) {
        flags.add('Contrarian');
        reasons.add('Puts bought opposing strong uptrend');
        isUnusual = true;
      }
    }

    // Unusual Activity
    if (openInterest > 0) {
      final volToOiRatio = volume / openInterest;
      if (volToOiRatio > 10) {
        isUnusual = true;
        flags.add('Mega Vol');
        reasons.add('Volume is ${volToOiRatio.toStringAsFixed(1)}x OI');
      } else if (volToOiRatio > 5) {
        isUnusual = true;
        flags.add('Vol Explosion');
        reasons.add('Volume is ${volToOiRatio.toStringAsFixed(1)}x OI');
      } else if (volToOiRatio > 1.5) {
        isUnusual = true;
        flags.add('High Vol/OI');
        reasons.add('Volume is ${volToOiRatio.toStringAsFixed(1)}x OI');
      }
    }

    if (iv > 2.5) {
      isUnusual = true;
      flags.add('Extreme IV');
      reasons.add('Implied Volatility at ${iv.toStringAsFixed(2)}');
    } else if (iv > 1.0) {
      isUnusual = true;
      flags.add('High IV');
      reasons.add('Implied Volatility at ${iv.toStringAsFixed(2)}');
    } else if (iv < 0.2 && daysToExpiration > 30) {
      flags.add('Low IV');
      reasons.add('Low IV for long-dated option');
    }

    // Spread
    if (bid > 0 && ask > 0) {
      final spread = (ask - bid) / ask;
      if (spread < 0.01 && volume > 500) {
        flags.add('Tight Spread');
        reasons.add(
            'Liquid market with ${(spread * 100).toStringAsFixed(2)}% spread');
      } else if (spread > 0.1) {
        flags.add('Wide Spread');
        reasons.add(
            'Illiquid market with ${(spread * 100).toStringAsFixed(2)}% spread');
      }
    }

    // ATM
    final percentDiff = (strike - spotPrice).abs() / spotPrice;
    if (percentDiff < 0.01 && volume > 500) {
      flags.add('ATM Flow');
      reasons.add('Strike near Spot with significant volume');
    }

    // Deep ITM
    if (isCall && spotPrice > strike * 1.1) {
      flags.add('Deep ITM');
      reasons.add('Call Strike significantly below Spot');
    } else if (!isCall && spotPrice < strike * 0.9) {
      flags.add('Deep ITM');
      reasons.add('Put Strike significantly above Spot');
    }

    // Deep OTM
    if (isCall && spotPrice < strike * 0.8) {
      flags.add('Deep OTM');
      reasons.add('Call Strike significantly above Spot');
    } else if (!isCall && spotPrice > strike * 1.2) {
      flags.add('Deep OTM');
      reasons.add('Put Strike significantly below Spot');
    }

    return (flags: flags, reasons: reasons, isUnusual: isUnusual);
  }

  static int _calculateConvictionScore({
    required double premium,
    required FlowType flowType,
    required bool isOTM,
    required int daysToExpiration,
    required int volume,
    required int openInterest,
    required List<String> flags,
  }) {
    double score = 0;

    // Premium
    if (premium > 5000000) {
      score += 40;
    } else if (premium > 1000000)
      score += 30;
    else if (premium > 500000)
      score += 20;
    else if (premium > 100000) score += 10;

    // Flow Type
    if (flowType == FlowType.sweep) {
      score += 20;
    } else if (flowType == FlowType.block) score += 10;

    // Urgency
    if (isOTM) score += 10;
    if (daysToExpiration <= 1) {
      score += 10;
    } else if (daysToExpiration < 14) score += 5;

    if (flags.contains('Aggressive')) score += 5;
    if (flags.contains('Tight Spread')) score += 5;
    if (flags.contains('ATM Flow')) score += 5;
    if (flags.contains('Gamma Squeeze')) score += 5;
    if (flags.contains('Steamroller')) score += 5;
    if (flags.contains('Earnings Play')) score += 5;

    // Unusual
    if (openInterest > 0) {
      if (volume > openInterest * 10) {
        score += 25;
      } else if (volume > openInterest * 5)
        score += 20;
      else if (volume > openInterest * 2)
        score += 10;
      else if (volume > openInterest) score += 5;
    }

    // Bonus
    if (flags.contains('Golden Sweep')) score *= 1.2;
    if (flags.contains('WHALE')) score *= 1.1;
    if (flags.contains('Bullish Divergence') ||
        flags.contains('Bearish Divergence')) {
      score *= 1.1;
    }
    if (flags.contains('Lotto')) score *= 1.05;

    return min(score.round(), 100);
  }

  void _processOptionContract(dynamic contract, String type, String symbol,
      DateTime expirationDate, double spotPrice, List<OptionFlowItem> items,
      {double? marketCap, int? earningsTimestamp}) {
    final item = processOptionContract(
        contract, type, symbol, expirationDate, spotPrice,
        marketCap: marketCap, earningsTimestamp: earningsTimestamp);
    if (item != null) items.add(item);
  }

  static OptionFlowItem? processOptionContract(dynamic contract, String type,
      String symbol, DateTime expirationDate, double spotPrice,
      {double? marketCap,
      String? sector,
      int? earningsTimestamp,
      bool skipFilters = false,
      double? delta,
      double? gamma}) {
    final int volume = _extractValue(contract['volume'])?.toInt() ?? 0;
    final int openInterest =
        _extractValue(contract['openInterest'])?.toInt() ?? 0;
    final double strike = _extractValue(contract['strike'])?.toDouble() ?? 0.0;
    final double lastPrice =
        _extractValue(contract['lastPrice'])?.toDouble() ?? 0.0;
    final double bid = _extractValue(contract['bid'])?.toDouble() ?? 0.0;
    final double ask = _extractValue(contract['ask'])?.toDouble() ?? 0.0;
    final double impliedVolatility =
        _extractValue(contract['impliedVolatility'])?.toDouble() ?? 0.0;
    final double? changePercent =
        _extractValue(contract['percentChange'])?.toDouble();

    dynamic lastTradeDateVal = _extractValue(contract['lastTradeDate']);
    DateTime? time;
    if (lastTradeDateVal is Timestamp) {
      time = lastTradeDateVal.toDate();
    } else if (lastTradeDateVal is DateTime) {
      time = lastTradeDateVal;
    } else if (lastTradeDateVal is int) {
      time = DateTime.fromMillisecondsSinceEpoch(lastTradeDateVal * 1000);
    } else {
      time = null;
    }

    // Filter for significant activity
    if (!skipFilters) {
      if (volume < 50) return null; // Basic filter

      double premium = volume * lastPrice * 100;
      if (premium < 5000) return null; // Minimum premium filter
    }

    double premium = volume * lastPrice * 100;

    final isCall = type == 'Call';
    final now = DateTime.now();
    final daysToExpiration = expirationDate.difference(now).inDays;
    final isOTM = isCall ? strike > spotPrice : strike < spotPrice;

    final analysis = _analyzeTradeExecution(
        isCall, lastPrice, bid, ask, volume, openInterest, premium);

    final flagResult = _detectFlags(
        premium: premium,
        flowType: analysis.flowType,
        isOTM: isOTM,
        details: analysis.details,
        openInterest: openInterest,
        volume: volume,
        daysToExpiration: daysToExpiration,
        isCall: isCall,
        changePercent: changePercent,
        earningsTimestamp: earningsTimestamp,
        expirationDate: expirationDate,
        now: now,
        iv: impliedVolatility,
        spotPrice: spotPrice,
        strike: strike,
        bid: bid,
        ask: ask,
        marketCap: marketCap,
        lastPrice: lastPrice,
        delta: delta,
        gamma: gamma);

    final score = _calculateConvictionScore(
      premium: premium,
      flowType: analysis.flowType,
      isOTM: isOTM,
      daysToExpiration: daysToExpiration,
      volume: volume,
      openInterest: openInterest,
      flags: flagResult.flags,
    );

    return OptionFlowItem(
      symbol: symbol,
      lastTradeDate: time,
      strike: strike,
      expirationDate: expirationDate,
      type: type,
      spotPrice: spotPrice,
      premium: premium,
      volume: volume,
      openInterest: openInterest,
      impliedVolatility: impliedVolatility,
      flowType: analysis.flowType,
      sentiment: analysis.sentiment,
      details: analysis.details,
      flags: flagResult.flags,
      reasons: flagResult.reasons,
      isUnusual: flagResult.isUnusual,
      score: score,
      bid: bid,
      ask: ask,
      changePercent: changePercent,
      lastPrice: lastPrice,
      marketCap: marketCap,
      sector: sector,
    );
  }

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      final Map<String, dynamic> params = {};
      if (_filterSymbol != null && _filterSymbol!.isNotEmpty) {
        params['symbol'] = _filterSymbol;
      } else if (_filterSymbols != null && _filterSymbols!.isNotEmpty) {
        params['symbols'] = _filterSymbols;
      } else {
        _isLoading = false;
        notifyListeners();
        return; // No symbol filter, do not fetch
      }
      if (_filterExpiration != null) {
        params['expiration'] = _filterExpiration;
      }

      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('getOptionsFlow')
            .call(params);

        final data = Map<String, dynamic>.from(result.data);
        final itemsData = data['items'] as List<dynamic>;

        _allItems = itemsData.map((item) {
          return OptionFlowItem(
            symbol: item['symbol'],
            lastTradeDate: DateTime.parse(item['time']),
            strike: (item['strike'] as num).toDouble(),
            expirationDate: DateTime.parse(item['expirationDate']),
            type: item['type'],
            spotPrice: (item['spotPrice'] as num).toDouble(),
            premium: (item['premium'] as num).toDouble(),
            volume: item['volume'] as int,
            openInterest: item['openInterest'] as int,
            impliedVolatility: (item['impliedVolatility'] as num).toDouble(),
            flowType: FlowType.values.firstWhere(
              (e) => e.name == item['flowType'],
              orElse: () => FlowType.block,
            ),
            sentiment: Sentiment.values.firstWhere(
              (e) => e.name == item['sentiment'],
              orElse: () => Sentiment.neutral,
            ),
            details: item['details'],
            flags: (item['flags'] as List<dynamic>?)?.cast<String>() ?? [],
            reasons: (item['reasons'] as List<dynamic>?)?.cast<String>() ?? [],
            isUnusual: item['isUnusual'] ?? false,
            sector: item['sector'],
            marketCap: item['marketCap'] != null
                ? (item['marketCap'] as num).toDouble()
                : null,
            score: item['score'] as int? ?? 0,
            bid: item['bid'] != null ? (item['bid'] as num).toDouble() : null,
            ask: item['ask'] != null ? (item['ask'] as num).toDouble() : null,
            changePercent: item['changePercent'] != null
                ? (item['changePercent'] as num).toDouble()
                : null,
            lastPrice: item['lastPrice'] != null
                ? (item['lastPrice'] as num).toDouble()
                : null,
          );
        }).toList();
      } catch (e) {
        debugPrint('Error fetching cloud options flow: $e');
        _allItems = [];
      }

      // Fetch from Yahoo if a single symbol is selected
      if (_filterSymbol != null &&
          _filterSymbol!.isNotEmpty &&
          _allItems.isEmpty) {
        final yahooItems =
            await fetchYahooFlowItems(_filterSymbol!, _filterExpiration);
        _allItems.addAll(yahooItems);
      }

      // Fetch from Yahoo if multiple symbols are selected
      if (_filterSymbols != null &&
          _filterSymbols!.isNotEmpty &&
          _allItems.isEmpty) {
        for (var symbol in _filterSymbols!) {
          final yahooItems =
              await fetchYahooFlowItems(symbol, _filterExpiration);
          _allItems.addAll(yahooItems);
        }
        // final futures = _filterSymbols!
        //     .map((symbol) => fetchYahooFlowItems(symbol, _filterExpiration));
        // final results = await Future.wait(futures);
        // for (var items in results) {
        //   _allItems.addAll(items);
        // }
      }

      _applyFilters();
    } catch (e) {
      debugPrint('Error refreshing options flow: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _applyFilters() {
    _items = List.from(_allItems);

    if (_filterSymbol != null && _filterSymbol!.isNotEmpty) {
      _items = _items
          .where((i) =>
              i.symbol.toUpperCase().contains(_filterSymbol!.toUpperCase()))
          .toList();
    } else if (_filterSymbols != null && _filterSymbols!.isNotEmpty) {
      _items = _items
          .where((i) => _filterSymbols!.contains(i.symbol.toUpperCase()))
          .toList();
    }
    if (_filterHighConviction) {
      _items = _items.where((i) => i.score >= 70).toList();
    }
    if (_filterSentiment != null) {
      _items = _items.where((i) => i.sentiment == _filterSentiment).toList();
    }
    if (_filterUnusual) {
      _items = _items.where((i) => i.isUnusual).toList();
    }
    if (_filterMoneyness != null) {
      _items = _items.where((i) {
        final isCall = i.type == 'Call';
        final isITM = isCall ? i.spotPrice > i.strike : i.spotPrice < i.strike;
        if (_filterMoneyness == 'ITM') return isITM;
        if (_filterMoneyness == 'OTM') return !isITM;
        return true;
      }).toList();
    }
    if (_filterFlowType != null) {
      _items = _items.where((i) => i.flowType == _filterFlowType).toList();
    }
    if (_filterExpiration != null) {
      final now = DateTime.now();
      _items = _items.where((i) {
        final diff = i.expirationDate.difference(now);
        final days = (diff.inHours / 24).ceil();
        if (_filterExpiration == '0-7') return days <= 7;
        if (_filterExpiration == '8-30') return days > 7 && days <= 30;
        if (_filterExpiration == '30+') return days > 30;
        return true;
      }).toList();
    }
    if (_filterSector != null) {
      _items = _items.where((i) => i.sector == _filterSector).toList();
    }
    if (_filterMinCap != null) {
      _items = _items.where((i) {
        if (i.marketCap == null) return false;
        // marketCap is in raw value, filter is in billions
        return i.marketCap! >= _filterMinCap! * 1000000000;
      }).toList();
    }
    if (_filterFlags != null && _filterFlags!.isNotEmpty) {
      _items = _items.where((i) {
        // Check if item has ANY of the selected flags (OR logic)
        // Or ALL? Usually filters are AND logic across categories, but OR within category.
        // Let's assume OR logic for flags (e.g. show me WHALES or GOLDEN SWEEPS)
        return _filterFlags!
            .any((flag) => i.flags.any((f) => f.contains(flag)));
      }).toList();
    }

    // Sort
    switch (_sortOption) {
      case FlowSortOption.time:
        _items.sort((a, b) =>
            (b.lastTradeDate ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                    a.lastTradeDate ?? DateTime.fromMillisecondsSinceEpoch(0)));
        break;
      case FlowSortOption.premium:
        _items.sort((a, b) => b.premium.compareTo(a.premium));
        break;
      case FlowSortOption.strike:
        _items.sort((a, b) => b.strike.compareTo(a.strike));
        break;
      case FlowSortOption.expiration:
        _items.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
        break;
      case FlowSortOption.volOi:
        _items.sort((a, b) {
          final ratioA = a.openInterest > 0 ? a.volume / a.openInterest : 0.0;
          final ratioB = b.openInterest > 0 ? b.volume / b.openInterest : 0.0;
          return ratioB.compareTo(ratioA);
        });
        break;
      case FlowSortOption.score:
        _items.sort((a, b) => b.score.compareTo(a.score));
        break;
    }
  }

  // List<OptionFlowItem> _generateMockData() {
  //   final random = Random();
  //   final symbols = [
  //     'AAPL',
  //     'TSLA',
  //     'NVDA',
  //     'AMD',
  //     'MSFT',
  //     'AMZN',
  //     'GOOGL',
  //     'META',
  //     'SPY',
  //     'QQQ'
  //   ];
  //   final details = [
  //     'Ask Side',
  //     'Bid Side',
  //     'Mid Market',
  //     'Above Ask',
  //     'Below Bid',
  //     'Ask Side - Weekly OTM',
  //     'Bid Side - LEAPS'
  //   ];
  //   final sectors = [
  //     'Technology',
  //     'Finance',
  //     'Healthcare',
  //     'Consumer Cyclical',
  //     'Energy'
  //   ];

  //   return List.generate(20, (index) {
  //     final symbol = symbols[random.nextInt(symbols.length)];
  //     final isCall = random.nextBool();
  //     final spotPrice = 100.0 + random.nextInt(900);
  //     final strike = spotPrice + (random.nextInt(50) - 25);
  //     final sentiment =
  //         isCall ? Sentiment.bullish : Sentiment.bearish; // Simplified logic

  //     final flowType = FlowType.values[random.nextInt(FlowType.values.length)];
  //     final isDarkPool = flowType == FlowType.darkPool;

  //     return OptionFlowItem(
  //       symbol: symbol,
  //       time: DateTime.now().subtract(Duration(minutes: random.nextInt(60))),
  //       strike: strike,
  //       expirationDate:
  //           DateTime.now().add(Duration(days: random.nextInt(30) + 1)),
  //       type: isCall ? 'Call' : 'Put',
  //       spotPrice: spotPrice,
  //       premium: random.nextInt(1000000).toDouble(),
  //       volume: random.nextInt(5000),
  //       openInterest: random.nextInt(10000),
  //       impliedVolatility: random.nextDouble(),
  //       flowType: flowType,
  //       sentiment: isDarkPool ? Sentiment.neutral : sentiment,
  //       details: isDarkPool
  //           ? 'Dark Pool Print'
  //           : details[random.nextInt(details.length)],
  //       isUnusual: random.nextBool(),
  //       sector: sectors[random.nextInt(sectors.length)],
  //       marketCap: (random.nextInt(2000) + 10) * 1000000000.0, // 10B to 2T
  //     );
  //   });
  // }
}

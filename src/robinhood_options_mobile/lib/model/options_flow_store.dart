import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/option_flow_item.dart';

enum FlowSortOption { time, premium, strike, expiration, volOi, score }

class OptionsFlowStore extends ChangeNotifier {
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
    refresh();
  }

  void setFilterSymbols(List<String>? symbols) {
    _filterSymbols = symbols;
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
        return; // No symbol filter, do not fetch
      }
      if (_filterExpiration != null) {
        params['expiration'] = _filterExpiration;
      }

      final result = await FirebaseFunctions.instance
          .httpsCallable('getOptionsFlow')
          .call(params);

      final data = Map<String, dynamic>.from(result.data);
      final itemsData = data['items'] as List<dynamic>;

      _allItems = itemsData.map((item) {
        return OptionFlowItem(
          symbol: item['symbol'],
          time: DateTime.parse(item['time']),
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
        );
      }).toList();

      _applyFilters();
    } catch (e) {
      debugPrint('Error fetching options flow: $e');
      // Fallback to mock data if function fails (e.g. during development/offline)
      // _allItems = _generateMockData();
      // _applyFilters();
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
        _items.sort((a, b) => b.time.compareTo(a.time));
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

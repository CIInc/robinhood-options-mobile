import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

class FuturesPaperPosition {
  final String contractId;
  final String symbol;
  double quantity;
  double avgPrice;
  double multiplier;
  double lastPrice;

  FuturesPaperPosition({
    required this.contractId,
    required this.symbol,
    required this.quantity,
    required this.avgPrice,
    required this.multiplier,
    required this.lastPrice,
  });

  double get openPnl => (lastPrice - avgPrice) * quantity * multiplier;

  Map<String, dynamic> toJson() {
    return {
      'contractId': contractId,
      'symbol': symbol,
      'quantity': quantity,
      'avgPrice': avgPrice,
      'multiplier': multiplier,
      'lastPrice': lastPrice,
    };
  }

  factory FuturesPaperPosition.fromJson(Map<String, dynamic> json) {
    return FuturesPaperPosition(
      contractId: json['contractId'] as String,
      symbol: json['symbol'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      avgPrice: (json['avgPrice'] as num?)?.toDouble() ?? 0.0,
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
      lastPrice: (json['lastPrice'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Result of submitting a paper order: immediately 'filled', or resting as
/// 'confirmed' until its trigger/limit price is reached.
class PaperOrderResult {
  final String id;
  final String state; // 'filled' | 'confirmed'
  PaperOrderResult(this.id, this.state);
}

/// A resting (working) paper order awaiting its trigger or limit price.
class PendingPaperOrder {
  final String id;
  final String assetType; // 'stock' | 'option'
  final String symbol; // stock symbol or option chain symbol (display)
  final String side; // 'buy' | 'sell'
  final String orderType; // 'limit' | 'stop' | 'stop_limit'
  final double? limitPrice;
  final double? stopPrice;
  final double quantity;
  final String timeInForce; // 'gtc' | 'gfd'
  final DateTime createdAt;
  bool triggered; // stop_limit only: stop leg fired, now resting as a limit
  final Map<String, dynamic> instrumentJson; // Instrument or OptionInstrument

  /// Transient references to the live objects for same-session fills; not
  /// serialized. Orders restored from Firestore fall back to
  /// [instrumentJson], whose dates Firestore has normalized to Timestamps.
  Instrument? instrumentRef;
  OptionInstrument? optionInstrumentRef;

  PendingPaperOrder({
    required this.id,
    required this.assetType,
    required this.symbol,
    required this.side,
    required this.orderType,
    this.limitPrice,
    this.stopPrice,
    required this.quantity,
    required this.timeInForce,
    required this.createdAt,
    this.triggered = false,
    required this.instrumentJson,
  });

  double get contractMultiplier => assetType == 'option' ? 100.0 : 1.0;

  /// Key used to look up the evaluation price: the stock symbol, or the
  /// option instrument id for options.
  String get priceKey => assetType == 'option'
      ? (instrumentJson['id']?.toString() ?? symbol)
      : symbol;

  /// URL of the traded asset, used to match positions for share reservation.
  String get assetUrl => instrumentJson['url']?.toString() ?? '';

  /// Price used to reserve buying power while the order rests.
  double get reservePrice => limitPrice ?? stopPrice ?? 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetType': assetType,
        'symbol': symbol,
        'side': side,
        'orderType': orderType,
        'limitPrice': limitPrice,
        'stopPrice': stopPrice,
        'quantity': quantity,
        'timeInForce': timeInForce,
        'createdAt': createdAt.toIso8601String(),
        'triggered': triggered,
        'instrumentJson': instrumentJson,
      };

  factory PendingPaperOrder.fromJson(Map<String, dynamic> json) {
    return PendingPaperOrder(
      id: json['id']?.toString() ?? '',
      assetType: json['assetType']?.toString() ?? 'stock',
      symbol: json['symbol']?.toString() ?? '',
      side: json['side']?.toString() ?? 'buy',
      orderType: json['orderType']?.toString() ?? 'limit',
      limitPrice: (json['limitPrice'] as num?)?.toDouble(),
      stopPrice: (json['stopPrice'] as num?)?.toDouble(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      timeInForce: json['timeInForce']?.toString() ?? 'gtc',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      triggered: json['triggered'] == true,
      instrumentJson: json['instrumentJson'] != null
          ? Map<String, dynamic>.from(json['instrumentJson'])
          : {},
    );
  }
}

class PaperTradingStore extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  firebase_auth.User? _user;

  PaperTradingStore({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // State
  double _cashBalance = 100000.0;
  double _initialCapital = 100000.0;
  double _slippage = 0.0;
  double _commission = 0.0;
  List<InstrumentPosition> _positions = [];
  List<OptionAggregatePosition> _optionPositions = [];
  List<FuturesPaperPosition> _futuresPositions = [];
  List<PendingPaperOrder> _pendingOrders = [];
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = false;

  // Getters
  double get cashBalance => _cashBalance;
  double get initialCapital => _initialCapital;
  double get slippage => _slippage;
  double get commission => _commission;
  List<InstrumentPosition> get positions => List.unmodifiable(_positions);
  List<OptionAggregatePosition> get optionPositions =>
      List.unmodifiable(_optionPositions);
  List<FuturesPaperPosition> get futuresPositions =>
      List.unmodifiable(_futuresPositions);
  List<PendingPaperOrder> get pendingOrders =>
      List.unmodifiable(_pendingOrders);
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);
  bool get isLoading => _isLoading;

  /// Cash reserved by working buy orders (each also reserves its commission).
  double get reservedCash => _pendingOrders
      .where((o) => o.side == 'buy')
      .fold(
          0.0,
          (total, o) =>
              total +
              o.quantity * o.reservePrice * o.contractMultiplier +
              _commission);

  /// Buying power net of working buy-order reservations.
  double get availableBuyingPower => _cashBalance - reservedCash;

  double get equity {
    double posValue = _calculatePositionsValue();
    return _cashBalance + posValue;
  }

  double _calculatePositionsValue() {
    double total = 0;
    for (var pos in _positions) {
      // Use current market price if available, otherwise fallback to cost basis (averageBuyPrice)
      double price = pos.instrumentObj?.quoteObj?.lastTradePrice ??
          pos.averageBuyPrice ??
          0;
      total += (pos.quantity ?? 0) * price;
    }
    for (var pos in _optionPositions) {
      // Use current market price if available, otherwise fallback to averageOpenPrice
      double price =
          (pos.optionInstrument?.optionMarketData?.adjustedMarkPrice ??
              pos.averageOpenPrice ??
              0);
      total += (pos.quantity ?? 0) * price * 100;
    }
    for (var pos in _futuresPositions) {
      total += (pos.lastPrice - pos.avgPrice) * pos.quantity * pos.multiplier;
    }
    return total;
  }

  Future<void>? _loadFuture;

  /// The Firebase user this store is currently bound to, if any.
  firebase_auth.User? get user => _user;

  void setUser(firebase_auth.User? user) {
    _user = user;
    if (_user != null) {
      _loadFuture = _load();
    } else {
      _loadFuture = null;
      _resetState();
    }
  }

  /// Binds the store to [user] (if not already) and waits for its state to be
  /// loaded from Firestore. Callers outside the widget tree (e.g.
  /// PaperService) must await this before executing orders so they don't
  /// mutate default state that a pending load would overwrite.
  Future<void> ensureLoaded(firebase_auth.User user) async {
    if (_user?.uid != user.uid) {
      setUser(user);
    }
    final pendingLoad = _loadFuture;
    if (pendingLoad != null) {
      await pendingLoad;
    }
  }

  void _resetState() {
    _cashBalance = 100000.0;
    _initialCapital = 100000.0;
    _positions = [];
    _optionPositions = [];
    _futuresPositions = [];
    _pendingOrders = [];
    _history = [];
    notifyListeners();
  }

  Future<void> _load() async {
    if (_user == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _firestore
          .collection('user')
          .doc(_user!.uid)
          .collection('paper_account')
          .doc('main')
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _cashBalance = (data['cashBalance'] as num?)?.toDouble() ?? 100000.0;
        _initialCapital =
            (data['initialCapital'] as num?)?.toDouble() ?? _cashBalance;
        _slippage = (data['slippage'] as num?)?.toDouble() ?? 0.0;
        _commission = (data['commission'] as num?)?.toDouble() ?? 0.0;

        if (data['positions'] != null) {
          _positions = (data['positions'] as List).map((e) {
            var pos = InstrumentPosition.fromJson(e);
            if (e['instrumentObj'] != null) {
              pos.instrumentObj = Instrument.fromJson(e['instrumentObj']);
            }
            return pos;
          }).toList();
        }

        if (data['optionPositions'] != null) {
          _optionPositions = (data['optionPositions'] as List).map((e) {
            var pos = OptionAggregatePosition.fromJson(e);
            if (e['optionInstrument'] != null) {
              pos.optionInstrument =
                  OptionInstrument.fromJson(e['optionInstrument']);
            }
            return pos;
          }).toList();
        }

        if (data['futuresPositions'] != null) {
          _futuresPositions = (data['futuresPositions'] as List)
              .map((e) =>
                  FuturesPaperPosition.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }

        if (data['pendingOrders'] != null) {
          _pendingOrders = (data['pendingOrders'] as List)
              .map((e) =>
                  PendingPaperOrder.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }

        if (data['history'] != null) {
          _history = List<Map<String, dynamic>>.from(data['history']);
        }
      } else {
        _save();
      }
    } catch (e) {
      debugPrint("Error loading paper account: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    if (_user == null) return;
    try {
      await _firestore
          .collection('user')
          .doc(_user!.uid)
          .collection('paper_account')
          .doc('main')
          .set({
        'cashBalance': _cashBalance,
        'initialCapital': _initialCapital,
        'slippage': _slippage,
        'commission': _commission,
        'positions':
            _positions.map((p) => _instrumentPositionToJson(p)).toList(),
        'optionPositions':
            _optionPositions.map((p) => _optionAggregationToJson(p)).toList(),
        'futuresPositions': _futuresPositions.map((p) => p.toJson()).toList(),
        'pendingOrders': _pendingOrders.map((o) => o.toJson()).toList(),
        'history': _history,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error saving paper account: $e");
    }
  }

  Map<String, dynamic> _instrumentPositionToJson(InstrumentPosition p) {
    return {
      'url': p.url,
      'instrument': p.instrument,
      'instrumentObj': p.instrumentObj?.toJson(),
      'account': p.account,
      'account_number': p.accountNumber,
      'average_buy_price': p.averageBuyPrice,
      'pending_average_buy_price': p.pendingAverageBuyPrice,
      'quantity': p.quantity,
      'intraday_average_buy_price': p.intradayAverageBuyPrice,
      'intraday_quantity': p.intradayQuantity,
      // These properties are not used
      // 'shares_available_for_exercise': p.sharesAvailableForExercise,
      // 'shares_held_for_buys': p.sharesHeldForBuys,
      // 'shares_held_for_sells': p.sharesHeldForSells,
      // 'shares_held_for_stock_grants': p.sharesHeldForStockGrants,
      // 'shares_held_for_options_collateral': p.sharesHeldForOptionsCollateral,
      // 'shares_held_for_options_events': p.sharesHeldForOptionsEvents,
      // 'shares_pending_from_options_events': p.sharesPendingFromOptionsEvents,
      // 'shares_available_for_closing_short_position':
      //     p.sharesAvailableForClosingShortPosition,
      'avg_cost_affected': p.averageCostAffected,
      'updated_at': p.updatedAt?.toIso8601String(),
      'created_at': p.createdAt?.toIso8601String(),
    };
  }

  Map<String, dynamic> _optionAggregationToJson(OptionAggregatePosition p) {
    return {
      'id': p.id,
      'chain': p.chain,
      'account': p.account,
      'symbol': p.symbol,
      'strategy': p.strategy,
      'average_open_price': p.averageOpenPrice,
      'legs': p.legs.map((l) => _optionLegToJson(l)).toList(),
      'quantity': p.quantity,
      'intraday_average_open_price': p.intradayAverageOpenPrice,
      'intraday_quantity': p.intradayQuantity,
      'direction': p.direction,
      'intraday_direction': p.intradayDirection,
      'trade_value_multiplier': p.tradeValueMultiplier,
      'created_at': p.createdAt?.toIso8601String(),
      'updated_at': p.updatedAt?.toIso8601String(),
      'strategy_code': p.strategyCode,
      'optionInstrument': p.optionInstrument != null
          ? _optionInstrumentToJson(p.optionInstrument!)
          : null,
    };
  }

  Map<String, dynamic> _optionInstrumentToJson(OptionInstrument i) {
    return {
      'chain_id': i.chainId,
      'chain_symbol': i.chainSymbol,
      'created_at': i.createdAt?.toIso8601String(),
      'expiration_date': i.expirationDate?.toIso8601String(),
      'id': i.id,
      'issue_date': i.issueDate?.toIso8601String(),
      'min_ticks': i.minTicks.toJson(),
      'rhs_tradability': i.rhsTradability,
      'state': i.state,
      'strike_price': i.strikePrice,
      'tradability': i.tradability,
      'type': i.type,
      'updated_at': i.updatedAt?.toIso8601String(),
      'url': i.url,
      'sellout_datetime': i.selloutDateTime?.toIso8601String(),
      'long_strategy_code': i.longStrategyCode,
      'short_strategy_code': i.shortStrategyCode,
      // We don't save quote/market data to disk as it's stale, but maybe we should for offline viewing?
      // No, let's keep it clean and only save static instrument data.
    };
  }

  Future<void> refreshQuotes(IBrokerageService service, QuoteStore quoteStore,
      OptionInstrumentStore optionInstrumentStore, BrokerageUser user) async {
    bool changed = false;

    // 1. Stocks & Underlying for Options
    var stockSymbols = _positions
        .map((p) => p.instrumentObj?.symbol)
        .whereType<String>()
        .toList();

    // Add underlying symbols from options to fetch quotes for expiration checks
    var optionUnderlyingSymbols = _optionPositions
        .map((p) => p.optionInstrument?.chainSymbol)
        .whereType<String>()
        .toList();

    // Include symbols of working stock orders so triggers can evaluate.
    var pendingStockSymbols = _pendingOrders
        .where((o) => o.assetType == 'stock')
        .map((o) => o.symbol);

    var allSymbols = {
      ...stockSymbols,
      ...optionUnderlyingSymbols,
      ...pendingStockSymbols
    }.toList();

    Map<String, double> underlyingPrices = {};

    if (allSymbols.isNotEmpty) {
      try {
        var quotes = await service.getQuoteByIds(user, quoteStore, allSymbols);
        for (var quote in quotes) {
          underlyingPrices[quote.symbol] = quote.lastTradePrice ?? 0.0;

          // Update stock positions
          try {
            var pos = _positions.firstWhere(
              (p) => p.instrumentObj?.symbol == quote.symbol,
            );
            if (pos.url.isNotEmpty && pos.instrumentObj != null) {
              pos.instrumentObj!.quoteObj = quote;
              changed = true;
            }
          } catch (_) {
            // Position for this symbol might not exist (it might be just an underlying for an option)
          }
        }
      } catch (e) {
        debugPrint("Error refreshing paper stock quotes: $e");
      }
    }

    // 2. Options
    List<OptionAggregatePosition> expiredPositions = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var pos in _optionPositions) {
      if (pos.optionInstrument?.expirationDate != null &&
          pos.optionInstrument!.expirationDate!.isBefore(today)) {
        expiredPositions.add(pos);
      }
    }

    for (var pos in expiredPositions) {
      double underlyingPrice =
          underlyingPrices[pos.optionInstrument?.chainSymbol] ?? 0.0;
      // If underlying price is 0 (fetch failed), we might want to skip expiration processing
      // or assume 0?. For now, if we have a price, we handle it.
      if (underlyingPrice > 0) {
        _processExpiration(pos, underlyingPrice);
        changed = true;
      }
    }

    var optionIds = {
      ..._optionPositions
          .where((p) =>
              !expiredPositions.contains(p) && p.optionInstrument?.id != null)
          .map((p) => p.optionInstrument!.id),
      // Working option orders need marks for trigger evaluation.
      ..._pendingOrders
          .where((o) => o.assetType == 'option')
          .map((o) => o.priceKey),
    }.toList();

    Map<String, double> optionMarks = {};
    if (optionIds.isNotEmpty) {
      try {
        var marketDataList =
            await service.getOptionMarketDataByIds(user, optionIds);
        for (var marketData in marketDataList) {
          final mark =
              marketData.adjustedMarkPrice ?? marketData.markPrice;
          if (mark != null) {
            optionMarks[marketData.instrumentId] = mark;
          }
          try {
            var pos = _optionPositions.firstWhere(
              (p) => p.optionInstrument?.url == marketData.instrument,
            );
            if (pos.optionInstrument != null) {
              pos.optionInstrument!.optionMarketData = marketData;
              changed = true;
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint("Error refreshing paper option quotes: $e");
      }
    }

    // 3. Futures
    var futureIds = _futuresPositions.map((p) => p.contractId).toList();
    if (futureIds.isNotEmpty) {
      try {
        var data = await service.getFuturesClosesByIds(user, futureIds);
        for (var item in data) {
          final id = item['id']?.toString();
          if (id != null) {
            final idx = _futuresPositions.indexWhere((p) => p.contractId == id);
            final lastPrice =
                double.tryParse(item['last_price']?.toString() ?? '0') ?? 0.0;
            if (idx >= 0 && lastPrice > 0) {
              _futuresPositions[idx].lastPrice = lastPrice;
              changed = true;
            }
          }
        }
      } catch (e) {
        debugPrint("Error refreshing paper futures quotes: $e");
      }
    }

    // Evaluate working orders against the fresh prices.
    await evaluatePendingOrders(
        stockPrices: underlyingPrices, optionMarks: optionMarks);

    if (changed) {
      notifyListeners();
    }
  }

  Map<String, dynamic> _optionLegToJson(OptionLeg l) {
    return {
      'id': l.id,
      'position': l.position,
      'position_type': l.positionType,
      'option': l.option,
      'position_effect': l.positionEffect,
      'ratio_quantity': l.ratioQuantity,
      'side': l.side,
      'expiration_date': l.expirationDate?.toIso8601String(),
      'strike_price': l.strikePrice,
      'option_type': l.optionType,
    };
  }

  Future<void> updateSettings({double? slippage, double? commission}) async {
    if (slippage != null) _slippage = slippage;
    if (commission != null) _commission = commission;
    await _save();
    notifyListeners();
  }

  Future<void> resetAccount({double initialCapital = 100000.0}) async {
    _cashBalance = initialCapital;
    _initialCapital = initialCapital;
    _positions = [];
    _optionPositions = [];
    _futuresPositions = [];
    _pendingOrders = [];
    _history = [];
    await _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Resting-order engine
  //
  // Market orders fill immediately. Limit/stop/stop-limit orders rest in
  // [_pendingOrders] (reserving buying power or shares) until
  // [evaluatePendingOrders] observes a price that satisfies them, at which
  // point they fill through the same executeStockOrder/executeOptionOrder
  // primitives (slippage, commission, averaging, history all apply).
  // ---------------------------------------------------------------------

  String _newOrderId() => 'paper_${DateTime.now().microsecondsSinceEpoch}';

  /// Submits a stock order. Market orders (and immediately marketable
  /// limit/stop orders) fill now; everything else rests as a working order.
  Future<PaperOrderResult> submitStockOrder({
    required Instrument instrument,
    required double quantity,
    required String side,
    String orderType = 'market',
    double? limitPrice,
    double? stopPrice,
    double? marketPrice,
    String timeInForce = 'gtc',
  }) async {
    final price = marketPrice ?? instrument.quoteObj?.lastTradePrice;
    return _submitOrder(
      assetType: 'stock',
      symbol: instrument.symbol,
      instrumentJson: instrument.toJson(),
      instrumentRef: instrument,
      quantity: quantity,
      side: side,
      orderType: orderType,
      limitPrice: limitPrice,
      stopPrice: stopPrice,
      marketPrice: price,
      timeInForce: timeInForce,
    );
  }

  /// Submits an option order (long-only). Same semantics as
  /// [submitStockOrder]; prices are per contract with a 100x multiplier.
  Future<PaperOrderResult> submitOptionOrder({
    required OptionInstrument optionInstrument,
    required double quantity,
    required String side,
    String orderType = 'limit',
    double? limitPrice,
    double? stopPrice,
    double? marketPrice,
    String timeInForce = 'gtc',
  }) async {
    final price = marketPrice ??
        optionInstrument.optionMarketData?.adjustedMarkPrice ??
        optionInstrument.optionMarketData?.markPrice;
    return _submitOrder(
      assetType: 'option',
      symbol: optionInstrument.chainSymbol,
      instrumentJson: optionInstrument.toJson(),
      optionInstrumentRef: optionInstrument,
      quantity: quantity,
      side: side,
      orderType: orderType,
      limitPrice: limitPrice,
      stopPrice: stopPrice,
      marketPrice: price,
      timeInForce: timeInForce,
    );
  }

  Future<PaperOrderResult> _submitOrder({
    required String assetType,
    required String symbol,
    required Map<String, dynamic> instrumentJson,
    Instrument? instrumentRef,
    OptionInstrument? optionInstrumentRef,
    required double quantity,
    required String side,
    required String orderType,
    double? limitPrice,
    double? stopPrice,
    double? marketPrice,
    required String timeInForce,
  }) async {
    if (quantity <= 0) {
      throw Exception('Quantity must be greater than zero.');
    }
    final normalizedSide = side.toLowerCase();
    final normalizedType = orderType.toLowerCase().replaceAll(' ', '_');

    switch (normalizedType) {
      case 'market':
        if (marketPrice == null || marketPrice <= 0) {
          throw Exception('No market price available for $symbol.');
        }
        break;
      case 'limit':
        if (limitPrice == null || limitPrice <= 0) {
          throw Exception('A limit price is required for limit orders.');
        }
        break;
      case 'stop':
        if (stopPrice == null || stopPrice <= 0) {
          throw Exception('A stop price is required for stop orders.');
        }
        break;
      case 'stop_limit':
        if (stopPrice == null ||
            stopPrice <= 0 ||
            limitPrice == null ||
            limitPrice <= 0) {
          throw Exception(
              'Stop and limit prices are required for stop-limit orders.');
        }
        break;
      default:
        throw Exception(
            'Order type "$orderType" is not supported in paper trading yet.');
    }

    final order = PendingPaperOrder(
      id: _newOrderId(),
      assetType: assetType,
      symbol: symbol,
      side: normalizedSide,
      orderType: normalizedType,
      limitPrice: limitPrice,
      stopPrice: stopPrice,
      quantity: quantity,
      timeInForce: timeInForce.toLowerCase(),
      createdAt: DateTime.now(),
      instrumentJson: instrumentJson,
    )
      ..instrumentRef = instrumentRef
      ..optionInstrumentRef = optionInstrumentRef;

    // Market orders and already-marketable limit/stop orders fill now.
    if (normalizedType == 'market') {
      await _fillOrder(order, marketPrice!);
      return PaperOrderResult(order.id, 'filled');
    }
    if (await _tryFillPendingOrder(order, marketPrice)) {
      return PaperOrderResult(order.id, 'filled');
    }

    _validateReservation(order);
    _pendingOrders.add(order);
    await _save();
    notifyListeners();
    return PaperOrderResult(order.id, 'confirmed');
  }

  /// Rejects a resting order that could over-commit cash (buys) or shares
  /// (sells) already reserved by other working orders.
  void _validateReservation(PendingPaperOrder order) {
    if (order.side == 'buy') {
      final cost =
          order.quantity * order.reservePrice * order.contractMultiplier +
              _commission;
      if (availableBuyingPower < cost) {
        throw Exception(
            'Insufficient buying power (cash is reserved by working orders).');
      }
    } else {
      double held = 0;
      if (order.assetType == 'stock') {
        final idx =
            _positions.indexWhere((p) => p.instrument == order.assetUrl);
        held = idx >= 0 ? (_positions[idx].quantity ?? 0) : 0;
      } else {
        final idx = _optionPositions.indexWhere((p) =>
            p.legs.isNotEmpty && p.legs.first.option == order.assetUrl);
        held = idx >= 0 ? (_optionPositions[idx].quantity ?? 0) : 0;
      }
      final reserved = _pendingOrders
          .where((o) =>
              o.side == 'sell' &&
              o.assetType == order.assetType &&
              o.assetUrl == order.assetUrl)
          .fold(0.0, (total, o) => total + o.quantity);
      if (held - reserved < order.quantity) {
        throw Exception(
            'Insufficient quantity available (shares are reserved by working orders).');
      }
    }
  }

  /// Fills [order] at [price] through the immediate-execution primitives.
  Future<void> _fillOrder(PendingPaperOrder order, double price) async {
    final label = switch (order.orderType) {
      'stop_limit' => 'Stop Limit',
      'stop' => 'Stop',
      'limit' => 'Limit',
      _ => 'Market',
    };
    if (order.assetType == 'stock') {
      await executeStockOrder(
        instrument:
            order.instrumentRef ?? Instrument.fromJson(order.instrumentJson),
        quantity: order.quantity,
        price: price,
        side: order.side,
        orderType: label,
      );
    } else {
      await executeOptionOrder(
        optionInstrument: order.optionInstrumentRef ??
            OptionInstrument.fromJson(order.instrumentJson),
        quantity: order.quantity,
        price: price,
        side: order.side,
        orderType: label,
      );
    }
  }

  /// Evaluates [order] against the current [price]. Fills and returns true
  /// when the order's conditions are satisfied; may set [order.triggered]
  /// (stop-limit) without filling.
  Future<bool> _tryFillPendingOrder(
      PendingPaperOrder order, double? price) async {
    if (price == null || price <= 0) return false;
    final isBuy = order.side == 'buy';
    bool shouldFill = false;

    switch (order.orderType) {
      case 'limit':
        final limit = order.limitPrice!;
        shouldFill = isBuy ? price <= limit : price >= limit;
        break;
      case 'stop':
        final stop = order.stopPrice!;
        shouldFill = isBuy ? price >= stop : price <= stop;
        break;
      case 'stop_limit':
        final stop = order.stopPrice!;
        if (!order.triggered && (isBuy ? price >= stop : price <= stop)) {
          order.triggered = true;
        }
        if (order.triggered) {
          final limit = order.limitPrice!;
          shouldFill = isBuy ? price <= limit : price >= limit;
        }
        break;
    }

    if (!shouldFill) return false;
    await _fillOrder(order, price);
    return true;
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Evaluates all working orders against fresh prices. [stockPrices] is
  /// keyed by symbol; [optionMarks] by option instrument id. Called from
  /// [refreshQuotes]; [now] is injectable for tests.
  Future<void> evaluatePendingOrders({
    required Map<String, double> stockPrices,
    Map<String, double> optionMarks = const {},
    DateTime? now,
  }) async {
    if (_pendingOrders.isEmpty) return;
    final evalTime = now ?? DateTime.now();
    bool changed = false;

    for (final order in List.of(_pendingOrders)) {
      // Good-for-day orders expire after their trading day.
      if (order.timeInForce == 'gfd' &&
          !_isSameDay(order.createdAt, evalTime)) {
        _pendingOrders.remove(order);
        _addToHistory(order.assetType, order.side, order.symbol,
            order.quantity, order.reservePrice,
            detail: 'GFD order expired unfilled',
            orderType: order.orderType,
            state: 'cancelled');
        changed = true;
        continue;
      }

      final price = order.assetType == 'stock'
          ? stockPrices[order.priceKey]
          : optionMarks[order.priceKey];
      final wasTriggered = order.triggered;

      // Remove before filling so this order's own reservation doesn't
      // count against the fill.
      _pendingOrders.remove(order);
      bool filled = false;
      try {
        filled = await _tryFillPendingOrder(order, price);
      } catch (e) {
        // e.g. cash consumed by an earlier fill — reject rather than retry.
        _addToHistory(order.assetType, order.side, order.symbol,
            order.quantity, order.reservePrice,
            detail: 'Order rejected on trigger: $e',
            orderType: order.orderType,
            state: 'rejected');
        changed = true;
        continue;
      }
      if (!filled) {
        _pendingOrders.add(order);
        if (order.triggered != wasTriggered) changed = true;
      }
    }

    if (changed) {
      await _save();
      notifyListeners();
    }
  }

  /// Cancels a working order and releases its reservation. Returns false if
  /// no working order has [orderId].
  Future<bool> cancelPendingOrder(String orderId) async {
    final idx = _pendingOrders.indexWhere((o) => o.id == orderId);
    if (idx < 0) return false;
    _pendingOrders.removeAt(idx);
    await _save();
    notifyListeners();
    return true;
  }

  Future<void> executeStockOrder({
    required Instrument instrument,
    required double quantity,
    required double price,
    required String side,
    String? orderType,
  }) async {
    double executionPrice = price;
    double amount = 0;
    if (side.toLowerCase() == 'buy') {
      executionPrice += _slippage;
      amount = (quantity * executionPrice) + _commission;
      if (_cashBalance < amount) {
        throw Exception("Insufficient buying power.");
      }
      _cashBalance -= amount;
      _updateStockPosition(instrument, quantity, executionPrice, 1);

      _addToHistory("stock", side, instrument.symbol, quantity, executionPrice,
          detail: orderType != null ? "Type: $orderType" : null,
          orderType: orderType,
          instrumentUrl: instrument.url);
    } else {
      executionPrice -= _slippage;
      amount = (quantity * executionPrice) - _commission;
      var existing = _positions.firstWhere(
          (p) => p.instrument == instrument.url,
          orElse: () => throw Exception("Position not found."));
      if ((existing.quantity ?? 0) < quantity) {
        throw Exception("Insufficient quantity to sell.");
      }

      // Calculate P&L for history
      double costBasis = (existing.averageBuyPrice ?? 0) * quantity;
      double profitLoss = amount - costBasis;

      _cashBalance += amount;
      _updateStockPosition(instrument, quantity, executionPrice, -1);

      _addToHistory("stock", side, instrument.symbol, quantity, executionPrice,
          detail: orderType != null ? "Type: $orderType" : null,
          orderType: orderType,
          instrumentUrl: instrument.url,
          profitLoss: profitLoss);
    }
    await _save();
    notifyListeners();
  }

  void _updateStockPosition(
      Instrument instrument, double quantity, double price, int sign) {
    int index = _positions.indexWhere((p) => p.instrument == instrument.url);

    if (index != -1) {
      var current = _positions[index];
      double currentQty = current.quantity ?? 0;
      double newQty = currentQty + (quantity * sign);

      if (newQty <= 0.000001) {
        _positions.removeAt(index);
      } else {
        double newAvgPrice = current.averageBuyPrice ?? 0;
        if (sign > 0) {
          newAvgPrice = ((currentQty * (current.averageBuyPrice ?? 0)) +
                  (quantity * price)) /
              newQty;
        }

        _positions[index] = InstrumentPosition(
          current.url,
          current.instrument,
          current.account,
          current.accountNumber,
          newAvgPrice,
          current.pendingAverageBuyPrice,
          newQty,
          current.intradayAverageBuyPrice,
          current.intradayQuantity,
          current.sharesAvailableForExercise,
          current.sharesHeldForBuys,
          current.sharesHeldForSells,
          current.sharesHeldForStockGrants,
          current.sharesHeldForOptionsCollateral,
          current.sharesHeldForOptionsEvents,
          current.sharesPendingFromOptionsEvents,
          current.sharesAvailableForClosingShortPosition,
          current.averageCostAffected,
          DateTime.now(),
          current.createdAt,
        )..instrumentObj = instrument;
      }
    } else {
      if (sign < 0) return;
      var newPos = InstrumentPosition(
        "paper_pos_${DateTime.now().millisecondsSinceEpoch}",
        instrument.url,
        "paper_account",
        "PAPER123",
        price,
        0,
        quantity,
        price,
        quantity,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        true,
        DateTime.now(),
        DateTime.now(),
      )..instrumentObj = instrument;
      _positions.add(newPos);
    }
  }

  Future<void> executeOptionOrder({
    required OptionInstrument optionInstrument,
    required double quantity,
    required double price,
    required String side,
    String? orderType,
  }) async {
    double multiplier = 100.0;
    double executionPrice = price;
    double amount = 0;

    if (side.toLowerCase() == 'buy') {
      executionPrice += _slippage;
      amount = (quantity * executionPrice * multiplier) + _commission;
      if (_cashBalance < amount) {
        throw Exception("Insufficient buying power.");
      }
      _cashBalance -= amount;
      _updateOptionPosition(optionInstrument, quantity, executionPrice, 1);

      String detail =
          "${optionInstrument.type} ${optionInstrument.strikePrice} ${optionInstrument.expirationDate}";
      if (orderType != null) {
        detail += " | $orderType";
      }

      _addToHistory("option", side, optionInstrument.chainSymbol, quantity,
          executionPrice,
          detail: detail, orderType: orderType);
    } else {
      executionPrice -= _slippage;
      amount = (quantity * executionPrice * multiplier) - _commission;
      var existingList = _optionPositions.where((p) =>
          p.legs.isNotEmpty && p.legs.first.option == optionInstrument.url);

      if (existingList.isEmpty) {
        throw Exception("Position not found.");
      }
      var existing = existingList.first;

      if ((existing.quantity ?? 0) < quantity) {
        throw Exception("Insufficient quantity to sell.");
      }

      // Calculate P&L for history
      double costBasis =
          (existing.averageOpenPrice ?? 0) * quantity * multiplier;
      double profitLoss = amount - costBasis;

      _cashBalance += amount;
      _updateOptionPosition(optionInstrument, quantity, executionPrice, -1);

      String detail =
          "${optionInstrument.type} ${optionInstrument.strikePrice} ${optionInstrument.expirationDate}";
      if (orderType != null) {
        detail += " | $orderType";
      }

      _addToHistory("option", side, optionInstrument.chainSymbol, quantity,
          executionPrice,
          detail: detail, orderType: orderType, profitLoss: profitLoss);
    }
    await _save();
    notifyListeners();
  }

  Future<void> executeComplexOptionStrategy({
    required double price,
    required double quantity,
    required String strategyName,
    required String direction, // 'debit' or 'credit'
    required List<Map<String, dynamic>>
        legsData, // Contains 'instrument' (OptionInstrument), 'side' (String), 'ratio' (int)
  }) async {
    double multiplier = 100.0;
    double executionPrice = price;
    double amount = 0;

    if (direction == 'debit') {
      executionPrice += _slippage;
      amount = (quantity * executionPrice * multiplier) + _commission;
      if (_cashBalance < amount) {
        throw Exception("Insufficient buying power.");
      }
      _cashBalance -= amount;
    } else {
      // Credit
      executionPrice -= _slippage;
      amount = (quantity * executionPrice * multiplier) - _commission;
      _cashBalance += amount;
    }

    // Create OptionLegs
    List<OptionLeg> newLegs = legsData.map((data) {
      OptionInstrument instr = data['instrument'];
      String side = data['side'];
      int ratio = data['ratio'];
      return OptionLeg(
        "leg_${DateTime.now().microsecondsSinceEpoch}_${instr.id}",
        null,
        side == 'buy' ? 'long' : 'short', // position_type
        instr.url,
        "open", // position_effect
        ratio,
        side, // side
        instr.expirationDate,
        instr.strikePrice,
        instr.type, // call/put
        [],
      );
    }).toList();

    var newPos = OptionAggregatePosition(
      "paper_strat_${DateTime.now().millisecondsSinceEpoch}",
      legsData.isNotEmpty ? legsData.first['instrument'].chainId : "",
      "paper_account",
      legsData.isNotEmpty
          ? legsData.first['instrument'].chainSymbol
          : strategyName,
      strategyName,
      executionPrice,
      newLegs,
      quantity,
      executionPrice,
      quantity,
      direction,
      direction,
      100.0,
      DateTime.now(),
      DateTime.now(),
      strategyName.toLowerCase().replaceAll(" ", "_"),
    );

    _optionPositions.add(newPos);

    _addToHistory("strategy", direction == 'debit' ? 'buy' : 'sell',
        strategyName, quantity, executionPrice,
        detail: "$strategyName (${legsData.length} legs)");
    await _save();
    notifyListeners();
  }

  void _updateOptionPosition(
      OptionInstrument option, double quantity, double price, int sign) {
    int index = _optionPositions.indexWhere(
        (p) => p.legs.isNotEmpty && p.legs.first.option == option.url);

    if (index != -1) {
      var current = _optionPositions[index];
      double currentQty = current.quantity ?? 0;
      double newQty = currentQty + (quantity * sign);

      if (newQty <= 0.000001) {
        _optionPositions.removeAt(index);
      } else {
        double newAvgPrice = current.averageOpenPrice ?? 0;
        if (sign > 0) {
          newAvgPrice = ((currentQty * (current.averageOpenPrice ?? 0)) +
                  (quantity * price)) /
              newQty;
        }

        var newPos = OptionAggregatePosition(
          current.id,
          current.chain,
          current.account,
          current.symbol,
          current.strategy,
          newAvgPrice,
          current.legs,
          newQty,
          current.intradayAverageOpenPrice,
          current.intradayQuantity,
          current.direction,
          current.intradayDirection,
          current.tradeValueMultiplier,
          current.createdAt,
          DateTime.now(),
          current.strategyCode,
        );
        newPos.optionInstrument = option;
        _optionPositions[index] = newPos;
      }
    } else {
      if (sign < 0) return;

      var leg = OptionLeg(
        "leg_${DateTime.now().millisecondsSinceEpoch}",
        "paper_pos",
        "long",
        option.url,
        "open",
        1,
        "buy",
        option.expirationDate,
        option.strikePrice,
        option.type.toLowerCase(), // call/put
        [],
      );

      var newPos = OptionAggregatePosition(
        "paper_opt_${DateTime.now().millisecondsSinceEpoch}",
        option.chainId,
        "paper_account",
        option.chainSymbol,
        option.type, // strategy
        price,
        [leg],
        quantity,
        price,
        quantity,
        'debit',
        'debit',
        100.0,
        DateTime.now(),
        DateTime.now(),
        'long_${option.type.toLowerCase()}',
      );
      newPos.optionInstrument = option;
      _optionPositions.add(newPos);
    }
  }

  /// Records a filled paper trade in a single unified format.
  ///
  /// The entry serves two consumers:
  /// - the dashboard order history ('type' asset class, 'action', 'timestamp')
  /// - InstrumentOrder.fromPaperJson ('side', 'state', 'order_type',
  ///   'instrument', 'created_at'/'updated_at')
  void _addToHistory(
      String type, String action, String symbol, double quantity, double price,
      {String? detail,
      double? profitLoss,
      double? multiplier,
      String? orderType,
      String? instrumentUrl,
      String state = 'filled'}) {
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    _history.insert(0, {
      'id': 'paper_${now.millisecondsSinceEpoch}',
      'timestamp': nowIso,
      'created_at': nowIso,
      'updated_at': nowIso,
      'type': type.toUpperCase(),
      'action': action.toUpperCase(),
      'side': action.toLowerCase(),
      'state': state,
      'symbol': symbol,
      'quantity': quantity,
      'price': price,
      'detail': detail,
      'paperMode': true,
      if (orderType != null) 'order_type': orderType.toLowerCase(),
      if (instrumentUrl != null) 'instrument': instrumentUrl,
      if (profitLoss != null) 'profitLoss': profitLoss,
      if (multiplier != null) 'multiplier': multiplier,
    });
    if (_history.length > 100) {
      _history = _history.sublist(0, 100);
    }
  }

  void _processExpiration(OptionAggregatePosition pos, double underlyingPrice) {
    if (pos.optionInstrument == null) return;

    double intrinsicValue = 0.0;
    double strike = pos.optionInstrument!.strikePrice ?? 0.0;
    String type = pos.optionInstrument!.type;

    if (type.toLowerCase() == 'call') {
      intrinsicValue =
          (underlyingPrice > strike) ? (underlyingPrice - strike) : 0.0;
    } else {
      intrinsicValue =
          (strike > underlyingPrice) ? (strike - underlyingPrice) : 0.0;
    }

    double quantity = pos.quantity ?? 0.0;
    double totalPayout = 0;
    List<String> details = [];

    // Assuming we only hold Long positions for now (as established by _updateOptionPosition logic)
    // If the paper trading store evolves to support shorts, this needs update.
    totalPayout = intrinsicValue * 100 * quantity;
    if (totalPayout > 0) {
      details.add("Exercised: +${totalPayout.toStringAsFixed(2)}");
    }

    _cashBalance += totalPayout;
    _optionPositions.remove(pos);

    if (totalPayout > 0) {
      _addToHistory("expiration", "exercise", pos.symbol, quantity,
          intrinsicValue, // usage of price field for intrinsic val
          detail: "Expired ITM at $underlyingPrice. ${details.join(', ')}");
    } else {
      _addToHistory("expiration", "expired", pos.symbol, quantity, 0,
          detail: "Expired worthless at $underlyingPrice");
    }
    _save();
  }

  void updateFuturesPrice(String contractId, double lastPrice) {
    final idx = _futuresPositions.indexWhere((p) => p.contractId == contractId);
    if (idx >= 0) {
      _futuresPositions[idx].lastPrice = lastPrice;
      notifyListeners();
      _save();
    }
  }

  void applyFuturesTrade({
    required String contractId,
    required String symbol,
    required String side,
    required int quantity,
    required double price,
    required double multiplier,
  }) {
    if (quantity <= 0) return;
    final signedTradeQty = side.toLowerCase() == 'sell' ? -quantity : quantity;

    final idx = _futuresPositions.indexWhere((p) => p.contractId == contractId);
    if (idx >= 0) {
      final pos = _futuresPositions[idx];
      final currentQty = pos.quantity;

      // Check if we are closing part of the position or adding to it
      bool isClosing = (currentQty > 0 && signedTradeQty < 0) ||
          (currentQty < 0 && signedTradeQty > 0);

      if (isClosing) {
        final qtyToClose = signedTradeQty.abs() > currentQty.abs()
            ? currentQty.abs()
            : signedTradeQty.abs();

        // Realize P&L for closed portion
        final realizedPnL = (price - pos.avgPrice) *
            qtyToClose *
            pos.multiplier *
            (currentQty > 0 ? 1 : -1);
        _cashBalance += realizedPnL;

        final newQty = currentQty + signedTradeQty;
        if (newQty.abs() < 0.000001) {
          _futuresPositions.removeAt(idx);
        } else {
          // If we reversed the position (went from long to short or vice-versa)
          if ((currentQty > 0 && newQty < 0) ||
              (currentQty < 0 && newQty > 0)) {
            pos.avgPrice = price; // The "open" price for the reversed portion
          }
          // If we just reduced the position, avgPrice stays the same
          pos.quantity = newQty;
          pos.lastPrice = price;
        }
      } else {
        // Adding to existing position
        final totalCost =
            (pos.avgPrice * currentQty.abs()) + (price * quantity);
        final newQty = currentQty + signedTradeQty;
        pos.avgPrice = totalCost / newQty.abs();
        pos.quantity = newQty;
        pos.lastPrice = price;
      }
    } else {
      // New position
      _futuresPositions.add(FuturesPaperPosition(
        contractId: contractId,
        symbol: symbol,
        quantity: signedTradeQty.toDouble(),
        avgPrice: price,
        multiplier: multiplier,
        lastPrice: price,
      ));
    }

    _cashBalance -= _commission; // Fee for opening/adjusting position

    _addToHistory(
        "futures", side.toLowerCase(), symbol, quantity.toDouble(), price,
        detail: "Contract ID: $contractId, Multiplier: $multiplier",
        multiplier: multiplier);

    notifyListeners();
    _save();
  }
}

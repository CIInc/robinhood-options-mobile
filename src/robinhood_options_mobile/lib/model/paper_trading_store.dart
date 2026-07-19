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
import 'package:robinhood_options_mobile/utils/market_hours.dart';

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
  final String orderType; // 'limit' | 'stop' | 'stop_limit' | 'trailing_stop'
  final double? limitPrice;
  final double? stopPrice;
  final String? trailType; // trailing_stop only: 'percentage' | 'amount'
  final double? trailValue; // trailing_stop only: trail distance
  double? watermark; // trailing_stop only: best observed price
  final double quantity;
  final String timeInForce; // 'gtc' | 'gfd'
  final String positionEffect; // 'auto' | 'open' | 'close' (options)
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
    this.trailType,
    this.trailValue,
    this.watermark,
    required this.quantity,
    required this.timeInForce,
    this.positionEffect = 'auto',
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

  /// Current trigger price of a trailing stop, derived from the watermark
  /// (best observed price) and the trail distance. Falls back to the static
  /// [stopPrice] for non-trailing orders.
  double? get effectiveStopPrice {
    if (orderType != 'trailing_stop' ||
        watermark == null ||
        trailValue == null) {
      return stopPrice;
    }
    final base = watermark!;
    final isBuy = side == 'buy';
    if (trailType == 'percentage') {
      return isBuy
          ? base * (1 + trailValue! / 100)
          : base * (1 - trailValue! / 100);
    }
    return isBuy ? base + trailValue! : base - trailValue!;
  }

  /// Price used to reserve buying power while the order rests. Market
  /// orders queued for the open anchor on the price at submit time (kept
  /// in [watermark]).
  double get reservePrice =>
      limitPrice ?? effectiveStopPrice ?? stopPrice ?? watermark ?? 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'assetType': assetType,
        'symbol': symbol,
        'side': side,
        'orderType': orderType,
        'limitPrice': limitPrice,
        'stopPrice': stopPrice,
        'trailType': trailType,
        'trailValue': trailValue,
        'watermark': watermark,
        'quantity': quantity,
        'timeInForce': timeInForce,
        'positionEffect': positionEffect,
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
      trailType: json['trailType']?.toString(),
      trailValue: (json['trailValue'] as num?)?.toDouble(),
      watermark: (json['watermark'] as num?)?.toDouble(),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
      timeInForce: json['timeInForce']?.toString() ?? 'gtc',
      positionEffect: json['positionEffect']?.toString() ?? 'auto',
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

  /// Whether the market is currently open for fills; injectable so tests
  /// aren't dependent on the wall clock.
  final bool Function() _isMarketOpen;

  PaperTradingStore({FirebaseFirestore? firestore, bool Function()? isMarketOpen})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _isMarketOpen = isMarketOpen ?? (() => MarketHours.isMarketOpen());

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

  /// Initial margin required to open a short: 150% of the entry value
  /// (Reg-T style: the 100% proceeds already credited to cash plus 50%).
  static const double shortStockMarginMultiplier = 1.5;

  /// Ongoing maintenance requirement for short stock: 130% of the current
  /// market value (NYSE-style), marked to market on every quote refresh.
  static const double shortStockMaintenanceMultiplier = 1.3;

  /// Cash held against short stock positions: 130% of current market value
  /// (falls back to the entry price until a quote is available).
  double get shortStockCollateral => _positions
      .where((p) => (p.quantity ?? 0) < 0)
      .fold(
          0.0,
          (total, p) =>
              total +
              (p.quantity ?? 0).abs() *
                  (p.instrumentObj?.quoteObj?.lastTradePrice ??
                      p.averageBuyPrice ??
                      0) *
                  shortStockMaintenanceMultiplier);

  /// Cash securing short puts: strike × 100 per contract.
  double get shortPutCollateral =>
      _optionPositions.where((p) => p.direction == 'credit').fold(0.0,
          (total, p) {
        final leg = p.legs.isNotEmpty ? p.legs.first : null;
        final type =
            (leg?.optionType ?? p.optionInstrument?.type ?? '').toLowerCase();
        if (type != 'put') return total;
        final strike =
            leg?.strikePrice ?? p.optionInstrument?.strikePrice ?? 0.0;
        return total + (p.quantity ?? 0) * strike * 100.0;
      });

  /// Total cash held as collateral for short positions.
  double get collateralCash => shortStockCollateral + shortPutCollateral;

  /// Shares of [symbol] pledged as covered-call collateral (100/contract).
  double coveredCallShares(String symbol) =>
      _optionPositions.where((p) => p.direction == 'credit').fold(0.0,
          (total, p) {
        final leg = p.legs.isNotEmpty ? p.legs.first : null;
        final type =
            (leg?.optionType ?? p.optionInstrument?.type ?? '').toLowerCase();
        if (type != 'call' || p.symbol != symbol) return total;
        return total + (p.quantity ?? 0) * 100.0;
      });

  /// Buying power net of working buy-order reservations and short collateral.
  double get availableBuyingPower =>
      _cashBalance - reservedCash - collateralCash;

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
      // Short (credit) positions are a liability: they subtract from equity.
      final sign = pos.direction == 'credit' ? -1.0 : 1.0;
      total += sign * (pos.quantity ?? 0) * price * 100;
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

        // One-time migration of the embedded (capped) history into the
        // durable paper_orders subcollection, then prefer the subcollection.
        await _migrateHistoryToSubcollection(data);
        await _loadHistoryFromSubcollection();
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

  /// Copies embedded history entries into the paper_orders subcollection
  /// exactly once (guarded by the historyMigrated flag). Legacy entries
  /// without an id get a deterministic one so re-runs stay idempotent.
  Future<void> _migrateHistoryToSubcollection(
      Map<String, dynamic> data) async {
    if (_user == null || data['historyMigrated'] == true) return;
    try {
      final userDoc = _firestore.collection('user').doc(_user!.uid);
      final batch = _firestore.batch();
      for (final entry in _history) {
        final id = entry['id']?.toString() ??
            'legacy_${entry['timestamp'] ?? entry['created_at'] ?? ''}'
                '_${entry['symbol'] ?? ''}'
                '_${entry['quantity'] ?? ''}';
        // The subcollection is ordered by created_at; make sure legacy
        // entries have one or they'd drop out of the query.
        final normalized = Map<String, dynamic>.from(entry);
        normalized['created_at'] ??=
            normalized['timestamp'] ?? normalized['updated_at'] ?? '';
        batch.set(userDoc.collection('paper_orders').doc(id), normalized);
      }
      batch.set(userDoc.collection('paper_account').doc('main'),
          {'historyMigrated': true}, SetOptions(merge: true));
      await batch.commit();
      debugPrint(
          'Migrated ${_history.length} paper fills to paper_orders.');
    } catch (e) {
      debugPrint('Error migrating paper history: $e');
    }
  }

  /// Loads the most recent fills from the durable subcollection into the
  /// in-memory history (newest first). Falls back to the embedded array
  /// already loaded when the query fails.
  Future<void> _loadHistoryFromSubcollection() async {
    if (_user == null) return;
    try {
      final snapshot = await _firestore
          .collection('user')
          .doc(_user!.uid)
          .collection('paper_orders')
          .orderBy('created_at', descending: true)
          .limit(100)
          .get();
      if (snapshot.docs.isNotEmpty) {
        _history = snapshot.docs.map((d) => d.data()).toList();
      }
    } catch (e) {
      debugPrint('Error loading paper fills; using embedded history: $e');
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
    final expiredPositions =
        processExpiredOptions(underlyingPrices: underlyingPrices);
    if (expiredPositions.isNotEmpty) {
      changed = true;
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

    // Evaluate working orders against the fresh prices, then sweep for
    // maintenance-margin deficits the new marks may have created.
    await evaluatePendingOrders(
        stockPrices: underlyingPrices, optionMarks: optionMarks);
    await processMarginCalls(stockPrices: underlyingPrices);

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
    await _clearEquityHistory();
    await _clearFillsSubcollection();
    notifyListeners();
  }

  /// Deletes the durable fills so a reset genuinely starts fresh.
  Future<void> _clearFillsSubcollection() async {
    if (_user == null) return;
    try {
      final snapshot = await _firestore
          .collection('user')
          .doc(_user!.uid)
          .collection('paper_orders')
          .get();
      // Firestore batches cap at 500 operations; the fills are uncapped.
      for (var i = 0; i < snapshot.docs.length; i += 400) {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs.skip(i).take(400)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error clearing paper fills: $e');
    }
  }

  /// Deletes the daily equity snapshots so the portfolio chart restarts
  /// from the new capital instead of showing the pre-reset curve.
  Future<void> _clearEquityHistory() async {
    if (_user == null) return;
    try {
      final snapshot = await _firestore
          .collection('user')
          .doc(_user!.uid)
          .collection('paper_equity_history')
          .get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint("Error clearing paper equity history: $e");
    }
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
    String? trailType,
    double? trailValue,
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
      trailType: trailType,
      trailValue: trailValue,
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
    String positionEffect = 'auto',
    String? trailType,
    double? trailValue,
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
      positionEffect: positionEffect,
      trailType: trailType,
      trailValue: trailValue,
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
    String positionEffect = 'auto',
    String? trailType,
    double? trailValue,
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
      case 'trailing_stop':
        if (trailValue == null || trailValue <= 0) {
          throw Exception(
              'A trail amount is required for trailing stop orders.');
        }
        if (trailType == 'percentage' && trailValue >= 100) {
          throw Exception('Trail percentage must be below 100.');
        }
        if (marketPrice == null || marketPrice <= 0) {
          throw Exception(
              'No market price available to anchor the trailing stop for $symbol.');
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
      trailType: trailType?.toLowerCase(),
      trailValue: trailValue,
      // The trailing watermark starts at the current price.
      watermark: normalizedType == 'trailing_stop' ? marketPrice : null,
      quantity: quantity,
      timeInForce: timeInForce.toLowerCase(),
      positionEffect: positionEffect.toLowerCase(),
      createdAt: DateTime.now(),
      instrumentJson: instrumentJson,
    )
      ..instrumentRef = instrumentRef
      ..optionInstrumentRef = optionInstrumentRef;

    // Fills only happen while the market is open; anything submitted after
    // hours rests as a working order until the next session.
    final marketOpen = _isMarketOpen();

    if (normalizedType == 'market') {
      if (marketOpen) {
        await _fillOrder(order, marketPrice!);
        return PaperOrderResult(order.id, 'filled');
      }
      // Queued for the open: anchor the buying-power reservation to the
      // last seen price.
      order.watermark = marketPrice;
    } else if (marketOpen &&
        await _tryFillPendingOrder(order, marketPrice)) {
      // Already-marketable limit/stop orders fill immediately.
      return PaperOrderResult(order.id, 'filled');
    }

    _validateReservation(order);
    _pendingOrders.add(order);
    await _save();
    notifyListeners();
    return PaperOrderResult(order.id, 'confirmed');
  }

  /// Rejects a resting order that could over-commit cash (buys) or shares
  /// (sells) already reserved by other working orders. Sells beyond the held
  /// quantity are treated as short opens and validated against collateral
  /// capacity instead; final enforcement happens again at fill time.
  void _validateReservation(PendingPaperOrder order) {
    if (order.side == 'buy') {
      final cost =
          order.quantity * order.reservePrice * order.contractMultiplier +
              _commission;
      if (availableBuyingPower < cost) {
        throw Exception(
            'Insufficient buying power (cash is reserved by working orders).');
      }
      return;
    }

    double held = 0;
    if (order.assetType == 'stock') {
      final idx = _positions.indexWhere((p) => p.instrument == order.assetUrl);
      held = idx >= 0 ? (_positions[idx].quantity ?? 0) : 0;
    } else {
      final idx = _optionPositions.indexWhere((p) =>
          p.legs.isNotEmpty &&
          p.legs.first.option == order.assetUrl &&
          p.direction != 'credit');
      held = idx >= 0 ? (_optionPositions[idx].quantity ?? 0) : 0;
    }
    final reserved = _pendingOrders
        .where((o) =>
            o.side == 'sell' &&
            o.assetType == order.assetType &&
            o.assetUrl == order.assetUrl)
        .fold(0.0, (total, o) => total + o.quantity);

    if (held - reserved >= order.quantity) {
      return; // plain sell-to-close, covered by the held quantity
    }
    if (held > 0) {
      // Partially covered sells would mix closing and shorting.
      throw Exception(
          'Insufficient quantity available (shares are reserved by working orders).');
    }

    // Sell-to-open (short) resting order: check collateral capacity now.
    if (order.assetType == 'stock') {
      final extraMargin = order.quantity *
          order.reservePrice *
          (shortStockMarginMultiplier - 1);
      if (availableBuyingPower < extraMargin) {
        throw Exception(
            'Insufficient buying power to open a short (requires 150% collateral).');
      }
    } else {
      final type = order.instrumentJson['type']?.toString().toLowerCase();
      if (type == 'call') {
        final stockIdx = _positions.indexWhere((p) =>
            p.instrumentObj?.symbol == order.symbol && (p.quantity ?? 0) > 0);
        final heldShares =
            stockIdx >= 0 ? (_positions[stockIdx].quantity ?? 0) : 0.0;
        final pledged = coveredCallShares(order.symbol);
        if (heldShares - pledged < order.quantity * 100) {
          throw Exception(
              'Naked calls are not supported; writing calls requires 100 unpledged shares per contract.');
        }
      } else {
        final strike = double.tryParse(
                order.instrumentJson['strike_price']?.toString() ?? '') ??
            0.0;
        final premium = order.quantity * order.reservePrice * 100;
        if (availableBuyingPower + premium < strike * 100 * order.quantity) {
          throw Exception(
              'Insufficient buying power to secure the put (requires strike × 100 in cash).');
        }
      }
    }
  }

  /// Fills [order] at [price] through the immediate-execution primitives.
  Future<void> _fillOrder(PendingPaperOrder order, double price) async {
    final label = switch (order.orderType) {
      'trailing_stop' => 'Trailing Stop',
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
        positionEffect: order.positionEffect,
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
      case 'market':
        // Queued while the market was closed; fills at the first price
        // observed during an open session.
        shouldFill = true;
        break;
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
      case 'trailing_stop':
        // Ratchet the watermark in the favorable direction, then trigger
        // when the price retraces by the trail distance.
        final current = order.watermark;
        if (isBuy) {
          if (current == null || price < current) order.watermark = price;
        } else {
          if (current == null || price > current) order.watermark = price;
        }
        final trailStop = order.effectiveStopPrice;
        if (trailStop != null) {
          shouldFill = isBuy ? price >= trailStop : price <= trailStop;
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
  /// [refreshQuotes]; [now] and [marketOpen] are injectable for tests.
  /// Fills only happen during regular market hours; GFD expiry runs
  /// regardless.
  Future<void> evaluatePendingOrders({
    required Map<String, double> stockPrices,
    Map<String, double> optionMarks = const {},
    DateTime? now,
    bool? marketOpen,
  }) async {
    if (_pendingOrders.isEmpty) return;
    final evalTime = now ?? DateTime.now();
    final open = marketOpen ?? _isMarketOpen();
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

      // Triggers and fills only fire during regular market hours.
      if (!open) continue;

      final price = order.assetType == 'stock'
          ? stockPrices[order.priceKey]
          : optionMarks[order.priceKey];
      final wasTriggered = order.triggered;
      final previousWatermark = order.watermark;

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
        if (order.triggered != wasTriggered ||
            order.watermark != previousWatermark) {
          changed = true;
        }
      }
    }

    if (changed) {
      await _save();
      notifyListeners();
    }
  }

  /// Marks short-stock maintenance to market and force-covers shorts while
  /// the account is under-margined (cash cannot cover working-order
  /// reservations plus maintenance collateral). Covers the largest exposures
  /// first, buying back only as many shares as needed to restore margin.
  /// [stockPrices] is keyed by symbol; positions without a price are skipped.
  /// Returns true when any forced liquidation happened.
  Future<bool> processMarginCalls(
      {required Map<String, double> stockPrices, bool? marketOpen}) async {
    // Forced liquidations execute at market prices, so they only run
    // while the market is open (prices are static after hours anyway).
    if (!(marketOpen ?? _isMarketOpen())) return false;

    double priceFor(InstrumentPosition p) =>
        stockPrices[p.instrumentObj?.symbol] ??
        p.instrumentObj?.quoteObj?.lastTradePrice ??
        p.averageBuyPrice ??
        0;

    double maintenance() => _positions
        .where((p) => (p.quantity ?? 0) < 0)
        .fold(
            0.0,
            (total, p) =>
                total +
                (p.quantity ?? 0).abs() *
                    priceFor(p) *
                    shortStockMaintenanceMultiplier);

    double deficit() =>
        reservedCash + maintenance() + shortPutCollateral - _cashBalance;

    if (deficit() <= 0.01) return false;

    bool liquidated = false;
    final shorts = _positions.where((p) => (p.quantity ?? 0) < 0).toList()
      ..sort((a, b) => ((b.quantity ?? 0).abs() * priceFor(b))
          .compareTo((a.quantity ?? 0).abs() * priceFor(a)));

    for (final pos in shorts) {
      final currentDeficit = deficit();
      if (currentDeficit <= 0.01) break;
      final price = priceFor(pos);
      if (price <= 0) continue;

      // Covering one share spends its price but releases its maintenance
      // requirement, freeing (multiplier - 1) x price of buying power.
      final freedPerShare =
          price * (shortStockMaintenanceMultiplier - 1);
      final held = (pos.quantity ?? 0).abs();
      final sharesToCover =
          (currentDeficit / freedPerShare).ceilToDouble().clamp(0.0, held);
      if (sharesToCover <= 0) continue;

      final avgShort = pos.averageBuyPrice ?? 0;
      final profitLoss = (avgShort - price) * sharesToCover;
      final instrument = pos.instrumentObj ??
          Instrument.forSymbol(
              pos.instrument.split('/').where((s) => s.isNotEmpty).last,
              instrumentUrl: pos.instrument);

      // Direct fill: forced liquidations bypass buying-power checks (the
      // account may legitimately go cash-negative on a blown-up short).
      _cashBalance -= sharesToCover * price;
      _updateStockPosition(instrument, sharesToCover, price, 1);
      _addToHistory('stock', 'buy', instrument.symbol, sharesToCover, price,
          detail:
              'Margin call: bought to cover at ${price.toStringAsFixed(2)}',
          orderType: 'market',
          instrumentUrl: instrument.url,
          profitLoss: profitLoss);
      liquidated = true;
    }

    if (deficit() > 0.01) {
      _addToHistory('margin', 'call', 'ACCOUNT', 0, 0,
          detail: 'Maintenance deficit of '
              '\$${deficit().toStringAsFixed(2)} remains after liquidation',
          state: 'warning');
      liquidated = true;
    }

    if (liquidated) {
      await _save();
      notifyListeners();
    }
    return liquidated;
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
    final index = _positions.indexWhere((p) => p.instrument == instrument.url);
    final heldQty = index >= 0 ? (_positions[index].quantity ?? 0) : 0.0;

    if (side.toLowerCase() == 'buy') {
      executionPrice += _slippage;
      amount = (quantity * executionPrice) + _commission;
      if (_cashBalance < amount) {
        throw Exception("Insufficient buying power.");
      }

      if (heldQty < 0) {
        // Buy-to-cover an existing short.
        if (quantity > heldQty.abs() + 0.000001) {
          throw Exception(
              "Buy exceeds the short position; cover it before going long.");
        }
        final avgShort = _positions[index].averageBuyPrice ?? 0;
        final profitLoss = (avgShort - executionPrice) * quantity - _commission;
        _cashBalance -= amount;
        _updateStockPosition(instrument, quantity, executionPrice, 1);
        _addToHistory(
            "stock", side, instrument.symbol, quantity, executionPrice,
            detail: "Buy to cover${orderType != null ? " | $orderType" : ""}",
            orderType: orderType,
            instrumentUrl: instrument.url,
            profitLoss: profitLoss);
      } else {
        _cashBalance -= amount;
        _updateStockPosition(instrument, quantity, executionPrice, 1);
        _addToHistory(
            "stock", side, instrument.symbol, quantity, executionPrice,
            detail: orderType != null ? "Type: $orderType" : null,
            orderType: orderType,
            instrumentUrl: instrument.url);
      }
    } else {
      executionPrice -= _slippage;
      amount = (quantity * executionPrice) - _commission;

      if (heldQty > 0) {
        // Sell-to-close a long position.
        if (heldQty < quantity) {
          throw Exception(
              "Sell exceeds the long position; close it before going short.");
        }
        // Shares pledged as covered-call collateral can't be sold.
        final pledged = coveredCallShares(instrument.symbol);
        if (heldQty - pledged < quantity) {
          throw Exception(
              "Shares are pledged as covered-call collateral; close the call first.");
        }

        double costBasis =
            (_positions[index].averageBuyPrice ?? 0) * quantity;
        double profitLoss = amount - costBasis;

        _cashBalance += amount;
        _updateStockPosition(instrument, quantity, executionPrice, -1);

        _addToHistory(
            "stock", side, instrument.symbol, quantity, executionPrice,
            detail: orderType != null ? "Type: $orderType" : null,
            orderType: orderType,
            instrumentUrl: instrument.url,
            profitLoss: profitLoss);
      } else {
        // Sell-to-open (or extend) a short position, 150% collateralized:
        // proceeds are credited but the position holds 1.5x entry value.
        final addedCollateral =
            quantity * executionPrice * shortStockMarginMultiplier;
        if (availableBuyingPower + amount < addedCollateral) {
          throw Exception(
              "Insufficient buying power to open a short (requires 150% collateral).");
        }
        _cashBalance += amount;
        _updateStockPosition(instrument, quantity, executionPrice, -1);
        _addToHistory(
            "stock", side, instrument.symbol, quantity, executionPrice,
            detail: "Sell short${orderType != null ? " | $orderType" : ""}",
            orderType: orderType,
            instrumentUrl: instrument.url);
      }
    }
    await _save();
    notifyListeners();
  }

  /// Applies a fill to the stock position book. Positive quantities are
  /// long; negative are short. [sign] is +1 for buys, -1 for sells.
  void _updateStockPosition(
      Instrument instrument, double quantity, double price, int sign) {
    int index = _positions.indexWhere((p) => p.instrument == instrument.url);

    if (index != -1) {
      var current = _positions[index];
      double currentQty = current.quantity ?? 0;
      double newQty = currentQty + (quantity * sign);

      if (newQty.abs() <= 0.000001) {
        _positions.removeAt(index);
      } else {
        double newAvgPrice = current.averageBuyPrice ?? 0;
        final extendsLong = sign > 0 && currentQty >= 0;
        final extendsShort = sign < 0 && currentQty <= 0;
        if (extendsLong || extendsShort) {
          // Average into the position; reductions keep the entry average.
          newAvgPrice = ((currentQty.abs() * (current.averageBuyPrice ?? 0)) +
                  (quantity * price)) /
              newQty.abs();
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
      // New position: long for buys, short (negative quantity) for sells.
      final signedQty = quantity * sign;
      var newPos = InstrumentPosition(
        "paper_pos_${DateTime.now().millisecondsSinceEpoch}",
        instrument.url,
        "paper_account",
        "PAPER123",
        price,
        0,
        signedQty,
        price,
        signedQty,
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
    String positionEffect = 'auto',
  }) async {
    double multiplier = 100.0;
    double executionPrice = price;
    double amount = 0;

    final index = _optionPositions.indexWhere((p) =>
        p.legs.isNotEmpty && p.legs.first.option == optionInstrument.url);
    final existing = index >= 0 ? _optionPositions[index] : null;
    final effect = positionEffect.toLowerCase();

    String detail =
        "${optionInstrument.type} ${optionInstrument.strikePrice} ${optionInstrument.expirationDate}";
    if (orderType != null) {
      detail += " | $orderType";
    }

    if (side.toLowerCase() == 'buy') {
      executionPrice += _slippage;
      amount = (quantity * executionPrice * multiplier) + _commission;
      if (_cashBalance < amount) {
        throw Exception("Insufficient buying power.");
      }

      if (existing?.direction == 'credit' && effect != 'open') {
        // Buy-to-close a written option.
        if ((existing!.quantity ?? 0) < quantity) {
          throw Exception("Buy exceeds the short option position.");
        }
        final profitLoss =
            ((existing.averageOpenPrice ?? 0) - executionPrice) *
                    quantity *
                    multiplier -
                _commission;
        _cashBalance -= amount;
        _updateOptionPosition(optionInstrument, quantity, executionPrice, -1,
            direction: 'credit');
        _addToHistory("option", side, optionInstrument.chainSymbol, quantity,
            executionPrice,
            detail: "Buy to close | $detail",
            orderType: orderType,
            profitLoss: profitLoss);
      } else {
        if (existing?.direction == 'credit') {
          throw Exception(
              "Close the short option position before opening a long.");
        }
        _cashBalance -= amount;
        _updateOptionPosition(optionInstrument, quantity, executionPrice, 1);
        _addToHistory("option", side, optionInstrument.chainSymbol, quantity,
            executionPrice,
            detail: detail, orderType: orderType);
      }
    } else {
      executionPrice -= _slippage;
      amount = (quantity * executionPrice * multiplier) - _commission;

      if (existing?.direction != 'credit' && existing != null &&
          effect != 'open') {
        // Sell-to-close a long position.
        if ((existing.quantity ?? 0) < quantity) {
          throw Exception("Insufficient quantity to sell.");
        }

        double costBasis =
            (existing.averageOpenPrice ?? 0) * quantity * multiplier;
        double profitLoss = amount - costBasis;

        _cashBalance += amount;
        _updateOptionPosition(optionInstrument, quantity, executionPrice, -1);

        _addToHistory("option", side, optionInstrument.chainSymbol, quantity,
            executionPrice,
            detail: detail, orderType: orderType, profitLoss: profitLoss);
      } else {
        if (existing != null && existing.direction != 'credit') {
          throw Exception(
              "Close the long option position before writing this contract.");
        }
        // Sell-to-open (write) a new short, or extend an existing one.
        final type = optionInstrument.type.toLowerCase();
        if (type == 'call') {
          // Covered calls only: 100 unpledged long shares per contract.
          final stockIdx = _positions.indexWhere((p) =>
              p.instrumentObj?.symbol == optionInstrument.chainSymbol &&
              (p.quantity ?? 0) > 0);
          final heldShares =
              stockIdx >= 0 ? (_positions[stockIdx].quantity ?? 0) : 0.0;
          final pledged = coveredCallShares(optionInstrument.chainSymbol);
          if (heldShares - pledged < quantity * multiplier) {
            throw Exception(
                "Naked calls are not supported; writing ${quantity.toStringAsFixed(0)} "
                "call(s) requires ${(quantity * 100).toStringAsFixed(0)} unpledged "
                "shares of ${optionInstrument.chainSymbol}.");
          }
        } else {
          // Cash-secured put: hold strike x 100 per contract.
          final strike = optionInstrument.strikePrice ?? 0.0;
          final addedCollateral = strike * multiplier * quantity;
          if (availableBuyingPower + amount < addedCollateral) {
            throw Exception(
                "Insufficient buying power to secure the put (requires strike × 100 in cash).");
          }
        }
        _cashBalance += amount;
        _updateOptionPosition(optionInstrument, quantity, executionPrice, 1,
            direction: 'credit');
        _addToHistory("option", side, optionInstrument.chainSymbol, quantity,
            executionPrice,
            detail: "Sell to open | $detail", orderType: orderType);
      }
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

  /// Applies a fill to the option position book. Quantity stays positive;
  /// [direction] distinguishes long ('debit') from written ('credit')
  /// positions, and [sign] is +1 to increase exposure, -1 to reduce it.
  void _updateOptionPosition(
      OptionInstrument option, double quantity, double price, int sign,
      {String direction = 'debit'}) {
    int index = _optionPositions.indexWhere((p) =>
        p.legs.isNotEmpty &&
        p.legs.first.option == option.url &&
        p.direction == direction);

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
      final isCredit = direction == 'credit';

      var leg = OptionLeg(
        "leg_${DateTime.now().millisecondsSinceEpoch}",
        "paper_pos",
        isCredit ? "short" : "long",
        option.url,
        "open",
        1,
        isCredit ? "sell" : "buy",
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
        direction,
        direction,
        100.0,
        DateTime.now(),
        DateTime.now(),
        '${isCredit ? "short" : "long"}_${option.type.toLowerCase()}',
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
    // The embedded array is a bounded cache for quick dashboard loads; the
    // durable, uncapped record lives in the paper_orders subcollection.
    if (_history.length > 100) {
      _history = _history.sublist(0, 100);
    }
    _appendFillToSubcollection(_history.first);
  }

  /// Appends a history entry to the append-only `paper_orders`
  /// subcollection — the durable transaction record, immune to the
  /// whole-document overwrites the embedded array is subject to.
  void _appendFillToSubcollection(Map<String, dynamic> entry) {
    if (_user == null) return;
    final id = entry['id']?.toString() ??
        'paper_${DateTime.now().microsecondsSinceEpoch}';
    _firestore
        .collection('user')
        .doc(_user!.uid)
        .collection('paper_orders')
        .doc(id)
        .set(entry)
        .catchError((e) {
      debugPrint('Error appending paper fill $id: $e');
    });
  }

  /// Settles option positions whose expiration has passed, using
  /// [underlyingPrices] keyed by chain symbol. Long positions cash-settle
  /// their intrinsic value; short positions are assigned (puts buy shares at
  /// the strike, covered calls have shares called away). Positions whose
  /// underlying price is unknown are left for the next refresh. Returns the
  /// settled positions. [now] is injectable for tests.
  List<OptionAggregatePosition> processExpiredOptions(
      {required Map<String, double> underlyingPrices, DateTime? now}) {
    final evalNow = now ?? DateTime.now();
    final today = DateTime(evalNow.year, evalNow.month, evalNow.day);

    final expired = _optionPositions
        .where((p) =>
            p.optionInstrument?.expirationDate != null &&
            p.optionInstrument!.expirationDate!.isBefore(today) &&
            (underlyingPrices[p.optionInstrument?.chainSymbol] ?? 0) > 0)
        .toList();

    for (final pos in expired) {
      final underlyingPrice =
          underlyingPrices[pos.optionInstrument!.chainSymbol]!;
      _settleExpiredPosition(pos, underlyingPrice);
    }
    if (expired.isNotEmpty) {
      _save();
    }
    return expired;
  }

  void _settleExpiredPosition(
      OptionAggregatePosition pos, double underlyingPrice) {
    final option = pos.optionInstrument!;
    final strike = option.strikePrice ?? 0.0;
    final type = option.type.toLowerCase();
    final quantity = pos.quantity ?? 0.0;
    final isCall = type == 'call';
    final intrinsicValue = isCall
        ? (underlyingPrice > strike ? underlyingPrice - strike : 0.0)
        : (strike > underlyingPrice ? strike - underlyingPrice : 0.0);
    final shares = quantity * 100;

    _optionPositions.remove(pos);

    if (pos.direction != 'credit') {
      // Long positions cash-settle intrinsic value.
      final totalPayout = intrinsicValue * 100 * quantity;
      _cashBalance += totalPayout;
      if (totalPayout > 0) {
        _addToHistory("expiration", "exercise", pos.symbol, quantity,
            intrinsicValue, // price field carries the intrinsic value
            detail: "Expired ITM at $underlyingPrice. "
                "Exercised: +${totalPayout.toStringAsFixed(2)}");
      } else {
        _addToHistory("expiration", "expired", pos.symbol, quantity, 0,
            detail: "Expired worthless at $underlyingPrice");
      }
      return;
    }

    // Short (written) positions: OTM keeps the premium; ITM is assigned.
    if (intrinsicValue <= 0) {
      _addToHistory("expiration", "expired", pos.symbol, quantity, 0,
          detail:
              "Short ${type == 'call' ? 'call' : 'put'} expired worthless at "
              "$underlyingPrice — premium kept");
      return;
    }

    if (isCall) {
      // Covered call assigned: shares are called away at the strike.
      final stockIdx = _positions.indexWhere((p) =>
          p.instrumentObj?.symbol == pos.symbol && (p.quantity ?? 0) > 0);
      if (stockIdx >= 0) {
        final stockPos = _positions[stockIdx];
        final callAway =
            shares.clamp(0.0, stockPos.quantity ?? 0.0).toDouble();
        final avgCost = stockPos.averageBuyPrice ?? 0;
        _cashBalance += callAway * strike;
        final profitLoss = (strike - avgCost) * callAway;
        _updateStockPosition(
            stockPos.instrumentObj ??
                Instrument.forSymbol(pos.symbol,
                    instrumentUrl: stockPos.instrument),
            callAway,
            strike,
            -1);
        _addToHistory("expiration", "assignment", pos.symbol, quantity, strike,
            detail: "Short call assigned at $underlyingPrice: "
                "${callAway.toStringAsFixed(0)} shares called away at $strike",
            profitLoss: profitLoss);
      } else {
        // Shares are gone (shouldn't happen while pledged): cash-settle.
        _cashBalance -= intrinsicValue * 100 * quantity;
        _addToHistory("expiration", "assignment", pos.symbol, quantity, strike,
            detail: "Short call cash-settled at $underlyingPrice "
                "(-${(intrinsicValue * 100 * quantity).toStringAsFixed(2)})");
      }
    } else {
      // Cash-secured put assigned: buy the shares at the strike, merging
      // into an existing position for the symbol when there is one.
      final stockIdx = _positions.indexWhere(
          (p) => p.instrumentObj?.symbol == pos.symbol);
      final instrument = stockIdx >= 0
          ? (_positions[stockIdx].instrumentObj ??
              Instrument.forSymbol(pos.symbol,
                  instrumentUrl: _positions[stockIdx].instrument))
          : Instrument.forSymbol(pos.symbol);
      _cashBalance -= shares * strike;
      _updateStockPosition(instrument, shares, strike, 1);
      _addToHistory("expiration", "assignment", pos.symbol, quantity, strike,
          detail: "Short put assigned at $underlyingPrice: bought "
              "${shares.toStringAsFixed(0)} shares at $strike");
    }
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

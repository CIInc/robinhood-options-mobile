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

class PaperTradingStore extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  firebase_auth.User? _user;

  PaperTradingStore({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // State
  double _cashBalance = 100000.0;
  List<InstrumentPosition> _positions = [];
  List<OptionAggregatePosition> _optionPositions = [];
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = false;

  // Getters
  double get cashBalance => _cashBalance;
  List<InstrumentPosition> get positions => List.unmodifiable(_positions);
  List<OptionAggregatePosition> get optionPositions =>
      List.unmodifiable(_optionPositions);
  List<Map<String, dynamic>> get history => List.unmodifiable(_history);
  bool get isLoading => _isLoading;

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
      double price = (pos.optionInstrument?.optionMarketData?.adjustedMarkPrice ??
          pos.averageOpenPrice ??
          0);
      total += (pos.quantity ?? 0) * price * 100;
    }
    return total;
  }

  void setUser(firebase_auth.User? user) {
    _user = user;
    if (_user != null) {
      _load();
    } else {
      _resetState();
    }
  }

  void _resetState() {
    _cashBalance = 100000.0;
    _positions = [];
    _optionPositions = [];
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
        'positions':
            _positions.map((p) => _instrumentPositionToJson(p)).toList(),
        'optionPositions':
            _optionPositions.map((p) => _optionAggregationToJson(p)).toList(),
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

  Future<void> refreshQuotes(
      IBrokerageService service,
      QuoteStore quoteStore,
      OptionInstrumentStore optionInstrumentStore,
      BrokerageUser user) async {
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
    
    var allSymbols = {...stockSymbols, ...optionUnderlyingSymbols}.toList();

    Map<String, double> underlyingPrices = {};

    if (allSymbols.isNotEmpty) {
      try {
        var quotes =
            await service.getQuoteByIds(user, quoteStore, allSymbols);
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

    var optionIds = _optionPositions
        .where((p) => !expiredPositions.contains(p) && p.optionInstrument?.id != null)
        .map((p) => p.optionInstrument!.id)
        .toList();

    if (optionIds.isNotEmpty) {
      try {
        var marketDataList =
            await service.getOptionMarketDataByIds(user, optionIds);
        for (var marketData in marketDataList) {
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

  Future<void> resetAccount() async {
    _cashBalance = 100000.0;
    _positions = [];
    _optionPositions = [];
    _history = [];
    await _save();
    notifyListeners();
  }

  Future<void> executeStockOrder({
    required Instrument instrument,
    required double quantity,
    required double price,
    required String side,
    String? orderType,
  }) async {
    double amount = quantity * price;

    if (side.toLowerCase() == 'buy') {
      if (_cashBalance < amount) {
        throw Exception("Insufficient buying power.");
      }
      _cashBalance -= amount;
      _updateStockPosition(instrument, quantity, price, 1);
    } else {
      var existing = _positions.firstWhere(
          (p) => p.instrument == instrument.url,
          orElse: () => throw Exception("Position not found."));
      if ((existing.quantity ?? 0) < quantity) {
        throw Exception("Insufficient quantity to sell.");
      }
      _cashBalance += amount;
      _updateStockPosition(instrument, quantity, price, -1);
    }

    _addToHistory("stock", side, instrument.symbol, quantity, price,
        detail: orderType != null ? "Type: $orderType" : null);
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
    double amount = quantity * price * multiplier;

    if (side.toLowerCase() == 'buy') {
      if (_cashBalance < amount) {
        throw Exception("Insufficient buying power.");
      }
      _cashBalance -= amount;
      _updateOptionPosition(optionInstrument, quantity, price, 1);
    } else {
      var existingList = _optionPositions.where((p) =>
          p.legs.isNotEmpty && p.legs.first.option == optionInstrument.url);

      if (existingList.isEmpty) {
        throw Exception("Position not found.");
      }
      var existing = existingList.first;

      if ((existing.quantity ?? 0) < quantity) {
        throw Exception("Insufficient quantity to sell.");
      }
      _cashBalance += amount;
      _updateOptionPosition(optionInstrument, quantity, price, -1);
    }

    String detail =
        "${optionInstrument.type} ${optionInstrument.strikePrice} ${optionInstrument.expirationDate}";
    if (orderType != null) {
      detail += " | $orderType";
    }

    _addToHistory("option", side, optionInstrument.chainSymbol, quantity, price,
        detail: detail);
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
    double amount = quantity * price * multiplier;

    if (direction == 'debit') {
      if (_cashBalance < amount) {
        throw Exception("Insufficient buying power.");
      }
      _cashBalance -= amount;
    } else {
      // Credit
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
      price,
      newLegs,
      quantity,
      price,
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
        strategyName, quantity, price,
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

  void _addToHistory(
      String type, String side, String symbol, double quantity, double price,
      {String? detail}) {
    _history.insert(0, {
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      'side': side,
      'symbol': symbol,
      'quantity': quantity,
      'price': price,
      'detail': detail,
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
      _addToHistory(
          "expiration",
          "exercise",
          pos.symbol,
          quantity,
          intrinsicValue, // usage of price field for intrinsic val
          detail: "Expired ITM at $underlyingPrice. ${details.join(', ')}");
    } else {
      _addToHistory("expiration", "expired", pos.symbol, quantity, 0,
          detail: "Expired worthless at $underlyingPrice");
    }
    _save();
  }
}

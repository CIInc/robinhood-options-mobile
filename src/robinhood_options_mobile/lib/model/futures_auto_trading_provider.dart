import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/futures_position_store.dart';
import 'package:robinhood_options_mobile/model/futures_strategy_config.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/services/futures_market_data_service.dart';

class FuturesAutoTradingProvider with ChangeNotifier {
  final FirebaseAnalytics _analytics;
  final FuturesMarketDataService _marketDataService =
      FuturesMarketDataService();

  FuturesAutoTradingProvider({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance;

  FuturesTradingConfig _config =
      FuturesTradingConfig(strategyConfig: FuturesStrategyConfig());

  bool _isAutoTrading = false;
  bool _emergencyStopActivated = false;
  DateTime? _lastAutoTradeTime;
  Timer? _autoTradeTimer;
  DateTime? _nextAutoTradeTime;
  int _autoTradeCountdownSeconds = 0;

  final List<Map<String, dynamic>> _autoTradeHistory = [];
  final List<Map<String, dynamic>> _pendingOrders = [];
  final List<String> _activityLog = [];
  final Map<String, double> _highWaterMarks = {}; // Tracking for Trailing Stop

  FuturesTradingConfig get config => _config;
  bool get isAutoTrading => _isAutoTrading;
  bool get emergencyStopActivated => _emergencyStopActivated;
  DateTime? get lastAutoTradeTime => _lastAutoTradeTime;
  DateTime? get nextAutoTradeTime => _nextAutoTradeTime;
  int get autoTradeCountdownSeconds => _autoTradeCountdownSeconds;
  List<Map<String, dynamic>> get autoTradeHistory => _autoTradeHistory;
  List<Map<String, dynamic>> get pendingOrders => _pendingOrders;
  List<String> get activityLog => _activityLog;

  static const Map<String, String> _defaultYahooSymbolMap = {
    'ES': 'ES=F',
    'MES': 'MES=F',
    'NQ': 'NQ=F',
    'MNQ': 'MNQ=F',
    'YM': 'YM=F',
    'MYM': 'MYM=F',
    'RTY': 'RTY=F',
    'M2K': 'M2K=F',
    'CL': 'CL=F',
    'MCL': 'MCL=F',
    'GC': 'GC=F',
    'MGC': 'MGC=F',
    'SI': 'SI=F',
    'SIL': 'SIL=F',
    'HG': 'HG=F',
    'MHG': 'MHG=F',
    'ZB': 'ZB=F',
    'ZN': 'ZN=F',
    'ZF': 'ZF=F',
    'ZC': 'ZC=F',
    'ZW': 'ZW=F',
    'ZS': 'ZS=F',
    '6E': 'EURUSD=X',
    'M6E': 'EURUSD=X',
    '6F': 'GBPUSD=X',
    'M6B': 'GBPUSD=X',
    '6A': 'AUDUSD=X',
    'M6A': 'AUDUSD=X',
    '6J': 'JPYUSD=X',
    'M6J': 'JPYUSD=X',
  };

  void _log(String message) {
    debugPrint(message);
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    _activityLog.insert(0, '[$timeStr] $message');
    if (_activityLog.length > 200) {
      _activityLog.removeLast();
    }
    notifyListeners();
  }

  void loadConfigFromUser(FuturesTradingConfig? config) {
    _config =
        config ?? FuturesTradingConfig(strategyConfig: FuturesStrategyConfig());
    _analytics.logEvent(name: 'futures_auto_trading_config_loaded');
    notifyListeners();
  }

  Future<void> updateConfig(
    FuturesTradingConfig newConfig,
    DocumentReference userDocRef,
  ) async {
    _config = newConfig;
    try {
      await userDocRef.update({
        'futuresTradingConfig': newConfig.toJson(),
      });
      _analytics.logEvent(name: 'futures_auto_trading_config_updated');
    } catch (e) {
      _analytics.logEvent(
        name: 'futures_auto_trading_config_update_failed',
        parameters: {'error': e.toString()},
      );
    }
    notifyListeners();
  }

  void initializeAutoTradeTimer() {
    final interval = _config.checkIntervalMinutes;
    _nextAutoTradeTime = DateTime.now().add(Duration(minutes: interval));
    _autoTradeCountdownSeconds = interval * 60;
    notifyListeners();
  }

  bool tickAutoTradeCountdown() {
    if (_nextAutoTradeTime == null) return false;
    final remaining = _nextAutoTradeTime!.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      resetAutoTradeCountdownForNextCycle();
      return true;
    }
    _autoTradeCountdownSeconds = remaining;
    notifyListeners();
    return false;
  }

  void resetAutoTradeCountdownForNextCycle() {
    final interval = _config.checkIntervalMinutes;
    _nextAutoTradeTime = DateTime.now().add(Duration(minutes: interval));
    _autoTradeCountdownSeconds = interval * 60;
    notifyListeners();
  }

  /// Update the auto-trade countdown (called from settings widget to manually set countdown)
  void updateAutoTradeCountdown(DateTime nextTime, int secondsRemaining) {
    _nextAutoTradeTime = nextTime;
    _autoTradeCountdownSeconds = secondsRemaining;
    notifyListeners();
  }

  /// Activates emergency stop to halt all auto-trading
  void activateEmergencyStop({DocumentReference? userDocRef}) {
    _emergencyStopActivated = true;
    _analytics.logEvent(
      name: 'futures_auto_trading_emergency_stop',
      parameters: {'reason': 'manual_activation'},
    );
    _log('🛑 Emergency stop activated');
    notifyListeners();
  }

  /// Deactivates emergency stop to resume auto-trading
  void deactivateEmergencyStop() {
    _emergencyStopActivated = false;
    _analytics.logEvent(
        name: 'futures_auto_trading_emergency_stop_deactivated');
    _log('▶️ Emergency stop deactivated');
    notifyListeners();
  }

  @override
  void dispose() {
    _autoTradeTimer?.cancel();
    super.dispose();
  }

  /// Prepopulate Firestore cache for futures market data
  /// Reduces initial latency and avoids server rate limiting
  /// Call this at app startup or when configuring new contracts
  Future<void> prepopulateCacheForContracts({
    List<String>? contractIds,
    String interval = '1d',
  }) async {
    final symbols = contractIds ?? _config.strategyConfig.contractIds;
    if (symbols.isEmpty) {
      _log('No contracts configured for cache prepopulation');
      return;
    }

    _log('📥 Prepopulating cache for ${symbols.length} contracts...');
    final yahooSymbols = symbols
        .map((id) => _resolveYahooSymbol(
              contractId: id,
              contract: {'id': id},
            ))
        .toList();

    await _marketDataService.prepopulateCache(
      symbols: yahooSymbols,
      interval: interval,
    );
  }

  void startAutoTradeTimer({
    required BuildContext context,
    required dynamic brokerageService,
    DocumentReference? userDocRef,
  }) {
    if (_autoTradeTimer != null && _autoTradeTimer!.isActive) {
      return;
    }
    _autoTradeTimer?.cancel();
    initializeAutoTradeTimer();
    _autoTradeTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final countdownReachedZero = tickAutoTradeCountdown();
      if (!countdownReachedZero) return;
      await runAutoTradeCycle(
        context: context,
        brokerageService: brokerageService,
        userDocRef: userDocRef,
      );
    });
  }

  bool _isInAllowedSession() {
    final rules = _config.strategyConfig.sessionRules;
    if (!rules.enforceTradingWindow) {
      return true;
    }

    if (rules.tradingWindowStart == null || rules.tradingWindowEnd == null) {
      return true;
    }

    final now = DateTime.now();
    if (!rules.allowWeekend &&
        (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday)) {
      return false;
    }

    final startParts = rules.tradingWindowStart!.split(':');
    final endParts = rules.tradingWindowEnd!.split(':');
    if (startParts.length != 2 || endParts.length != 2) return true;

    final start = DateTime(now.year, now.month, now.day,
        int.parse(startParts[0]), int.parse(startParts[1]));
    final end = DateTime(now.year, now.month, now.day, int.parse(endParts[0]),
        int.parse(endParts[1]));

    if (end.isBefore(start)) {
      return now.isAfter(start) || now.isBefore(end);
    }
    return now.isAfter(start) && now.isBefore(end);
  }

  String _resolveYahooSymbol({
    required String contractId,
    required Map<String, dynamic> contract,
  }) {
    final overrides = _config.strategyConfig.symbolOverrides;
    if (overrides.containsKey(contractId)) {
      return overrides[contractId]!;
    }
    final rawSymbol = contract['rootSymbol']?.toString() ??
        contract['symbol']?.toString() ??
        contract['displaySymbol']?.toString();
    String? root = rawSymbol;
    if (rawSymbol != null) {
      final cleaned = rawSymbol.replaceAll('/', '').split(':').first;
      final match =
          RegExp(r'^([A-Z0-9]{1,4})[FGHJKMNQUVXZ]\d{2}$').firstMatch(cleaned);
      root = match != null ? match.group(1) : cleaned;
    }
    if (root != null && overrides.containsKey(root)) {
      return overrides[root]!;
    }
    if (root != null && _defaultYahooSymbolMap.containsKey(root)) {
      return _defaultYahooSymbolMap[root]!;
    }
    return root ?? contractId;
  }

  Future<String?> _resolveFuturesAccountId({
    required dynamic brokerageService,
    required dynamic brokerageUser,
    required AccountStore accountStore,
  }) async {
    if (accountStore.items.isEmpty) return null;
    final account = accountStore.items.first;
    try {
      final accounts = await brokerageService.getFuturesAccounts(
        brokerageUser,
        account,
      );
      final futures = (accounts as List)
          .firstWhere((a) => a['accountType'] == 'FUTURES', orElse: () => null);
      return futures != null ? futures['id']?.toString() : null;
    } catch (e) {
      _log('⚠️ Failed to resolve futures account: $e');
      return null;
    }
  }

  Future<void> runAutoTradeCycle({
    required BuildContext context,
    required dynamic brokerageService,
    DocumentReference? userDocRef,
  }) async {
    if (_isAutoTrading) {
      _log('⚠️ Futures auto-trade already in progress');
      return;
    }

    if (!_config.autoTradeEnabled) {
      _log('Futures auto-trade disabled');
      return;
    }

    if (_emergencyStopActivated) {
      _log('🛑 Emergency stop is active, skipping cycle');
      return;
    }

    if (!_isInAllowedSession()) {
      _log('Futures auto-trade blocked by session rules');
      return;
    }

    final now = DateTime.now();
    if (_lastAutoTradeTime != null) {
      final cooldown = Duration(minutes: _config.autoTradeCooldownMinutes);
      if (now.difference(_lastAutoTradeTime!) < cooldown) {
        _log('Cooldown active, skipping cycle');
        return;
      }
    }

    _isAutoTrading = true;
    notifyListeners();

    try {
      final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
      final accountStore = Provider.of<AccountStore>(context, listen: false);
      final futuresStore =
          Provider.of<FuturesPositionStore>(context, listen: false);
      final paperStore = Provider.of<PaperTradingStore>(context, listen: false);

      final isPaperMode = _config.paperTradingMode;
      final currentUser = userStore.currentUser;
      if (!isPaperMode && currentUser == null) {
        _log('❌ Missing brokerage user for live futures trading');
        return;
      }

      final contractIds = _config.strategyConfig.contractIds;
      if (contractIds.isEmpty) {
        _log('⚠️ No futures contracts configured for auto-trade');
        return;
      }

      final futuresAccountId = !isPaperMode
          ? await _resolveFuturesAccountId(
              brokerageService: brokerageService,
              brokerageUser: currentUser,
              accountStore: accountStore,
            )
          : null;

      if (!isPaperMode && futuresAccountId == null) {
        _log('❌ No futures account available');
        return;
      }

      final liveBuyingPower = accountStore.items.isNotEmpty
          ? (accountStore.items.first.buyingPower ?? 0.0)
          : 0.0;
      final portfolioState = <String, dynamic>{
        'buyingPower': isPaperMode ? paperStore.cashBalance : liveBuyingPower,
        'cashAvailable': isPaperMode ? paperStore.cashBalance : liveBuyingPower,
      };

      if (isPaperMode) {
        // For paper trading, we have a separate list for futures positions
        // for (final pos in paperStore.positions) {
        //   if (pos.instrumentObj != null) {
        //     portfolioState[pos.instrumentObj!.symbol] = {
        //       'quantity': pos.quantity,
        //       'price': pos.instrumentObj!.quoteObj?.lastTradePrice ??
        //           pos.averageBuyPrice ??
        //           0,
        //     };
        //   }
        // }
        for (final pos in paperStore.futuresPositions) {
          portfolioState[pos.contractId] = {
            'quantity': pos.quantity,
            'price': pos.lastPrice * pos.multiplier,
          };
        }
      } else {
        for (final pos in futuresStore.items) {
          if (pos is Map && pos['contractId'] != null) {
            final qty =
                double.tryParse(pos['quantity']?.toString() ?? '0') ?? 0;
            final price =
                double.tryParse(pos['lastTradePrice']?.toString() ?? '0') ??
                    double.tryParse(pos['avgTradePrice']?.toString() ?? '0') ??
                    0;
            portfolioState[pos['contractId'].toString()] = {
              'quantity': qty,
              'price': price,
            };
          }
        }
      }

      // --- RISK MANAGEMENT & EXIT LOGIC ---
      final strategy = _config.strategyConfig;
      final autoExitEnabled = strategy.autoExitEnabled;
      final autoExitBuffer = strategy.autoExitBufferMinutes;
      final rules = strategy.sessionRules;
      bool isNearingSessionClose = false;

      if (autoExitEnabled &&
          rules.enforceTradingWindow &&
          rules.tradingWindowEnd != null) {
        final now = DateTime.now();
        final endParts = rules.tradingWindowEnd!.split(':');
        if (endParts.length == 2) {
          final end = DateTime(now.year, now.month, now.day,
              int.parse(endParts[0]), int.parse(endParts[1]));
          final timeToClose = end.difference(now).inMinutes;
          if (timeToClose > 0 && timeToClose <= autoExitBuffer) {
            isNearingSessionClose = true;
            _log(
                '🕒 Nearing session close ($timeToClose min). Closing all open positions.');
          }
        }
      }

      // Track existing positions to decide if we need to close them
      final activePositionEntries = portfolioState.entries
          .where((e) => e.value is Map && (e.value as Map)['quantity'] != 0)
          .toList();

      for (final entry in activePositionEntries) {
        final contractId = entry.key;
        final positionData = entry.value as Map;
        final qty = (positionData['quantity'] as num).toDouble();
        final avgPrice = (positionData['price'] as num).toDouble();

        // Check if we should exit this position
        bool shouldExit = isNearingSessionClose;
        String exitReason = 'Session Close Auto-Exit';

        if (!shouldExit) {
          // Get current market price (from quote store or call backend)
          // Optimization: many of these prices are already in QuoteStore.
          final quoteStore = Provider.of<QuoteStore>(context, listen: false);
          final quote = quoteStore.items.cast<Quote?>().firstWhere(
                (q) => q?.symbol == contractId,
                orElse: () => null,
              );
          final lastPrice = (quote?.lastTradePrice ?? avgPrice).toDouble();

          // Stop Loss Check
          if (strategy.stopLossPct > 0) {
            final lossThreshold = qty > 0
                ? avgPrice * (1 - strategy.stopLossPct / 100)
                : avgPrice * (1 + strategy.stopLossPct / 100);
            if ((qty > 0 && lastPrice <= lossThreshold) ||
                (qty < 0 && lastPrice >= lossThreshold)) {
              shouldExit = true;
              exitReason = 'Stop Loss ($lastPrice <= $lossThreshold)';
            }
          }

          // Take Profit Check
          if (strategy.takeProfitPct > 0) {
            final profitThreshold = qty > 0
                ? avgPrice * (1 + strategy.takeProfitPct / 100)
                : avgPrice * (1 - strategy.takeProfitPct / 100);
            if ((qty > 0 && lastPrice >= profitThreshold) ||
                (qty < 0 && lastPrice <= profitThreshold)) {
              shouldExit = true;
              exitReason = 'Take Profit ($lastPrice >= $profitThreshold)';
            }
          }

          // Trailing Stop Check (initial tracking)
          if (strategy.trailingStopEnabled) {
            _highWaterMarks[contractId] ??= avgPrice;
            if (qty > 0) {
              if (lastPrice > _highWaterMarks[contractId]!) {
                _highWaterMarks[contractId] = lastPrice;
              }
            } else if (qty < 0) {
              if (lastPrice < _highWaterMarks[contractId]!) {
                _highWaterMarks[contractId] = lastPrice;
              }
            }
          }
        }

        if (shouldExit) {
          _log('🛑 Risk Exit for $contractId: $exitReason');
          final exitOrder = {
            'contractId': contractId,
            'symbol': contractId,
            'action': qty > 0 ? 'SELL' : 'BUY',
            'quantity': qty.abs(),
            'price': avgPrice, // Execution price will be market
            'multiplier': 1.0,
            'timestamp': DateTime.now().toIso8601String(),
            'proposal': {
              'action': qty > 0 ? 'SELL' : 'BUY',
              'reason': exitReason
            },
          };

          await _executeOrder(
            order: exitOrder,
            isPaperMode: isPaperMode,
            brokerageService: brokerageService,
            brokerageUser: currentUser,
            futuresAccountId: futuresAccountId,
            paperStore: paperStore,
          );
          await _recordHistory(exitOrder, userDocRef);
          _lastAutoTradeTime = DateTime.now();
          _highWaterMarks.remove(contractId);

          // Update portfolioState locally so we don't try to open another one this cycle
          portfolioState[contractId] = {'quantity': 0, 'price': 0};
        }
      }
      // --- END RISK MANAGEMENT ---

      final contracts = currentUser != null
          ? await brokerageService.getFuturesContractsBySymbols(
              currentUser,
              contractIds,
            )
          : contractIds.map((id) => {'id': id}).toList();

      for (final contract in contracts) {
        if (contract == null) continue;
        final contractId = contract['id']?.toString();
        if (contractId == null) continue;

        final yahooSymbol = _resolveYahooSymbol(
          contractId: contractId,
          contract: contract,
        );
        final multiplier =
            double.tryParse(contract['multiplier']?.toString() ?? '1') ?? 1.0;

        // Prepopulate Firestore cache with market data
        // Backend's getMarketData will hit the cache instead of calling Yahoo API
        unawaited(_marketDataService.getMarketData(
          symbol: yahooSymbol,
          smaPeriodFast: _config.strategyConfig.smaPeriodFast,
          smaPeriodSlow: _config.strategyConfig.smaPeriodSlow,
          interval: _config.strategyConfig.interval,
        ));

        // Also prepopulate market index data for regime analysis
        final marketIndexSymbol =
            _config.strategyConfig.marketIndexSymbol ?? 'ES=F';
        unawaited(_marketDataService.getMarketData(
          symbol: marketIndexSymbol,
          smaPeriodFast: _config.strategyConfig.smaPeriodFast,
          smaPeriodSlow: _config.strategyConfig.smaPeriodSlow,
          interval: '1d',
        ));

        final functions = FirebaseFunctions.instance;
        final callable = functions.httpsCallable('getFuturesSignals');
        final result = await callable.call({
          'symbol': yahooSymbol,
          'contractId': contractId,
          'interval': _config.strategyConfig.interval,
          'portfolioState': portfolioState,
          'config': {
            'tradeQuantity': _config.strategyConfig.tradeQuantity,
            'maxContracts': _config.strategyConfig.maxContracts,
            'maxNotional': _config.strategyConfig.maxNotional,
            'maxDailyLoss': _config.strategyConfig.maxDailyLoss,
            'minSignalStrength': _config.strategyConfig.minSignalStrength,
            'rsiPeriod': _config.strategyConfig.rsiPeriod,
            'rocPeriod': _config.strategyConfig.rocPeriod,
            'smaPeriodFast': _config.strategyConfig.smaPeriodFast,
            'smaPeriodSlow': _config.strategyConfig.smaPeriodSlow,
            'marketIndexSymbol': _config.strategyConfig.marketIndexSymbol,
            'enabledIndicators': _config.strategyConfig.enabledIndicators,
            'enableDynamicPositionSizing':
                _config.strategyConfig.enableDynamicPositionSizing,
            'riskPerTrade': _config.strategyConfig.riskPerTrade,
            'atrMultiplier': _config.strategyConfig.atrMultiplier,
            'contractMultiplier': multiplier,
            'stopLossPct': _config.strategyConfig.stopLossPct,
            'takeProfitPct': _config.strategyConfig.takeProfitPct,
            'trailingStopEnabled': _config.strategyConfig.trailingStopEnabled,
            'trailingStopAtrMultiplier':
                _config.strategyConfig.trailingStopAtrMultiplier,
            'skipRiskGuard': _config.strategyConfig.skipRiskGuard,
            'multiIntervalAnalysis':
                _config.strategyConfig.multiIntervalAnalysis,
          },
        });

        final data = Map<String, dynamic>.from(result.data as Map);

        // --- TRAILING STOP LOGIC (AFTER SIGNAL RETRIEVAL) ---
        final multiIndicator = data['multiIndicatorResult'] != null
            ? Map<String, dynamic>.from(data['multiIndicatorResult'] as Map)
            : null;
        final indicators = multiIndicator != null
            ? Map<String, dynamic>.from(multiIndicator['indicators'] as Map)
            : null;
        final atrValue = indicators != null && indicators['atr'] != null
            ? (indicators['atr']['value'] as num?)?.toDouble()
            : null;

        final position = portfolioState[contractId];
        final currentQty =
            position != null ? (position['quantity'] as num).toDouble() : 0.0;
        final currentPrice = (data['proposal'] != null)
            ? (data['proposal']['price'] as num).toDouble()
            : 0.0;

        if (currentQty != 0 &&
            strategy.trailingStopEnabled &&
            atrValue != null) {
          _highWaterMarks[contractId] ??= currentPrice;
          final lastPrice = currentPrice;

          if (currentQty > 0) {
            if (lastPrice > _highWaterMarks[contractId]!) {
              _highWaterMarks[contractId] = lastPrice;
            }
          } else if (currentQty < 0) {
            if (lastPrice < _highWaterMarks[contractId]!) {
              _highWaterMarks[contractId] = lastPrice;
            }
          }

          final stopDist = atrValue * strategy.trailingStopAtrMultiplier;
          final trailPrice = currentQty > 0
              ? _highWaterMarks[contractId]! - stopDist
              : _highWaterMarks[contractId]! + stopDist;

          if ((currentQty > 0 && lastPrice <= trailPrice) ||
              (currentQty < 0 && lastPrice >= trailPrice)) {
            _log(
                '🛑 Trailing Stop triggered for $contractId @ $lastPrice (Trail Price: $trailPrice)');
            final exitOrder = {
              'contractId': contractId,
              'symbol': yahooSymbol,
              'action': currentQty > 0 ? 'SELL' : 'BUY',
              'quantity': currentQty.abs(),
              'price': lastPrice,
              'multiplier': multiplier,
              'timestamp': DateTime.now().toIso8601String(),
              'proposal': {
                'action': currentQty > 0 ? 'SELL' : 'BUY',
                'reason': 'Trailing Stop ($lastPrice reached $trailPrice)'
              },
            };
            await _executeOrder(
              order: exitOrder,
              isPaperMode: isPaperMode,
              brokerageService: brokerageService,
              brokerageUser: currentUser,
              futuresAccountId: futuresAccountId,
              paperStore: paperStore,
            );
            await _recordHistory(exitOrder, userDocRef);
            _lastAutoTradeTime = DateTime.now();
            _highWaterMarks.remove(contractId);
            portfolioState[contractId] = {'quantity': 0, 'price': 0};
            continue; // Skip this contract for further actions this cycle
          }
        }
        // --- END TRAILING STOP LOGIC ---

        if (data['status'] != 'approved') {
          continue;
        }

        final proposal = Map<String, dynamic>.from(data['proposal'] as Map);
        final action = proposal['action']?.toString() ?? 'HOLD';

        // --- POSITION MANAGEMENT ---
        // Don't duplicate positions of the same side
        if (action == 'BUY' && currentQty > 0) {
          _log('Skipping $contractId Signal: Already LONG');
          continue;
        }
        if (action == 'SELL' && currentQty < 0) {
          _log('Skipping $contractId Signal: Already SHORT');
          continue;
        }

        if (action == 'HOLD') {
          continue;
        }
        // --- END POSITION MANAGEMENT ---

        final order = {
          'contractId': contractId,
          'symbol': yahooSymbol,
          'action': action,
          'quantity': proposal['quantity'],
          'price': proposal['price'],
          'multiplier': multiplier,
          'timestamp': DateTime.now().toIso8601String(),
          'proposal': proposal,
        };

        if (_config.requireApproval) {
          _pendingOrders.insert(0, order);
          if (userDocRef != null) {
            await _addPendingOrderToFirestore(userDocRef, order);
          }
          _log('🕒 Futures order pending approval: $contractId');
        } else {
          await _executeOrder(
            order: order,
            isPaperMode: isPaperMode,
            brokerageService: brokerageService,
            brokerageUser: currentUser,
            futuresAccountId: futuresAccountId,
            paperStore: paperStore,
          );
          await _recordHistory(order, userDocRef);
          _lastAutoTradeTime = DateTime.now();
        }
      }
    } catch (e) {
      _log('❌ Futures auto-trade error: $e');
    } finally {
      _isAutoTrading = false;
      notifyListeners();
    }
  }

  Future<void> _executeOrder({
    required Map<String, dynamic> order,
    required bool isPaperMode,
    required dynamic brokerageService,
    required dynamic brokerageUser,
    required String? futuresAccountId,
    required PaperTradingStore paperStore,
  }) async {
    if (isPaperMode) {
      paperStore.applyFuturesTrade(
        contractId: order['contractId'] as String,
        symbol: order['symbol'] as String,
        side: order['action'] == 'SELL' ? 'sell' : 'buy',
        quantity: (order['quantity'] as num).toInt(),
        price: (order['price'] as num).toDouble(),
        multiplier: (order['multiplier'] as num).toDouble(),
      );
      _log('🧪 Paper futures trade executed: ${order['contractId']}');
      return;
    }

    if (futuresAccountId == null) {
      _log('❌ Missing futures account for live order');
      return;
    }

    await brokerageService.placeFuturesOrder(
      brokerageUser,
      futuresAccountId,
      order['contractId'] as String,
      order['action'] == 'SELL' ? 'SELL' : 'BUY',
      (order['quantity'] as num).toInt(),
      price: (order['price'] as num).toDouble(),
      orderType: 'MARKET',
      timeInForce: 'GTC',
    );

    _log('✅ Futures order executed: ${order['contractId']}');
  }

  Future<void> approvePendingOrder({
    required Map<String, dynamic> order,
    required BuildContext context,
    required dynamic brokerageService,
    required DocumentReference? userDocRef,
  }) async {
    final paperStore = Provider.of<PaperTradingStore>(context, listen: false);
    final userStore = Provider.of<BrokerageUserStore>(context, listen: false);
    final accountStore = Provider.of<AccountStore>(context, listen: false);

    final isPaperMode = _config.paperTradingMode;
    final futuresAccountId = !isPaperMode
        ? await _resolveFuturesAccountId(
            brokerageService: brokerageService,
            brokerageUser: userStore.currentUser,
            accountStore: accountStore,
          )
        : null;

    await _executeOrder(
      order: order,
      isPaperMode: isPaperMode,
      brokerageService: brokerageService,
      brokerageUser: userStore.currentUser,
      futuresAccountId: futuresAccountId,
      paperStore: paperStore,
    );

    _pendingOrders.remove(order);
    if (userDocRef != null) {
      await _removePendingOrderFromFirestore(userDocRef, order);
    }
    await _recordHistory(order, userDocRef);
    _lastAutoTradeTime = DateTime.now();
    notifyListeners();
  }

  Future<void> rejectPendingOrder(
      Map<String, dynamic> order, DocumentReference? userDocRef) async {
    _pendingOrders.remove(order);
    if (userDocRef != null) {
      await _removePendingOrderFromFirestore(userDocRef, order);
    }
    notifyListeners();
  }

  Future<void> _recordHistory(
      Map<String, dynamic> order, DocumentReference? userDocRef) async {
    final tradeRecord = {
      ...order,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _autoTradeHistory.insert(0, tradeRecord);
    if (_autoTradeHistory.length > 200) {
      _autoTradeHistory.removeRange(200, _autoTradeHistory.length);
    }
    if (userDocRef != null) {
      await userDocRef
          .collection('futures_auto_trade_history')
          .add(tradeRecord);
    }
    notifyListeners();
  }

  Future<void> loadAutoTradeHistoryFromFirestore(
      DocumentReference? userDocRef) async {
    if (userDocRef == null) return;
    try {
      final snapshot = await userDocRef
          .collection('futures_auto_trade_history')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      _autoTradeHistory
        ..clear()
        ..addAll(snapshot.docs.map((doc) => doc.data()));
      notifyListeners();
    } catch (e) {
      _log('❌ Failed to load futures auto-trade history: $e');
    }
  }

  Future<void> loadPendingOrdersFromFirestore(
      DocumentReference? userDocRef) async {
    if (userDocRef == null) return;
    try {
      final snapshot = await userDocRef
          .collection('futures_pending_orders')
          .orderBy('timestamp', descending: true)
          .get();
      _pendingOrders
        ..clear()
        ..addAll(snapshot.docs.map((doc) {
          final data = doc.data();
          data['firestoreId'] = doc.id;
          return data;
        }));
      notifyListeners();
    } catch (e) {
      _log('❌ Failed to load futures pending orders: $e');
    }
  }

  Future<void> _addPendingOrderToFirestore(
      DocumentReference userDocRef, Map<String, dynamic> order) async {
    final payload = jsonDecode(jsonEncode(order)) as Map<String, dynamic>;
    final docRef =
        await userDocRef.collection('futures_pending_orders').add(payload);
    order['firestoreId'] = docRef.id;
  }

  Future<void> _removePendingOrderFromFirestore(
      DocumentReference userDocRef, Map<String, dynamic> order) async {
    final firestoreId = order['firestoreId'] as String?;
    if (firestoreId == null) return;
    await userDocRef
        .collection('futures_pending_orders')
        .doc(firestoreId)
        .delete();
  }
}

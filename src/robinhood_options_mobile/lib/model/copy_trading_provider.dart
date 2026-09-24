import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/services/copy_trade_risk_guardian_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

class CopyTradingProvider with ChangeNotifier {
  StreamSubscription<QuerySnapshot>? _subscription;
  String? _firebaseUserId;
  BrokerageUser? _brokerageUser;
  IBrokerageService? _service;

  // Safety controls
  int _consecutiveFailures = 0;
  static const int _maxConsecutiveFailures = 3;
  bool _isCircuitBreakerTripped = false;

  // Stores to cache data or pass to service methods
  final AccountStore _accountStore = AccountStore();
  final InstrumentStore _instrumentStore = InstrumentStore();
  final OptionInstrumentStore _optionInstrumentStore = OptionInstrumentStore();
  final QuoteStore _quoteStore = QuoteStore();

  void initialize(String firebaseUserId, BrokerageUser brokerageUser,
      IBrokerageService service) {
    if (_firebaseUserId == firebaseUserId &&
        _brokerageUser?.userName == brokerageUser.userName) {
      return;
    }

    _firebaseUserId = firebaseUserId;
    _brokerageUser = brokerageUser;
    _service = service;
    _cancelSubscription();
    _startListening();
  }

  @override
  void dispose() {
    _cancelSubscription();
    super.dispose();
  }

  void _cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _startListening() {
    if (_firebaseUserId == null) return;

    _subscription = FirebaseFirestore.instance
        .collection('copy_trades')
        .where('targetUserId', isEqualTo: _firebaseUserId)
        .where('executed', isEqualTo: false)
        .where('status', whereIn: ['approved', 'pending_approval'])
        .snapshots()
        .listen(_handleSnapshot);
  }

  Stream<List<CopyTradeRecord>> getTradeHistory() {
    if (_firebaseUserId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('copy_trades')
        .where('targetUserId', isEqualTo: _firebaseUserId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CopyTradeRecord.fromDocument(doc))
            .toList());
  }

  Stream<List<CopyTradeRecord>> getRequests() {
    if (_firebaseUserId == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('copy_trades')
        .where('targetUserId', isEqualTo: _firebaseUserId)
        .where('status', whereIn: ['pending_approval', 'rejected'])
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CopyTradeRecord.fromDocument(doc))
            .toList());
  }

  Future<void> approveRequest(CopyTradeRecord record) async {
    await FirebaseFirestore.instance
        .collection('copy_trades')
        .doc(record.id)
        .update({
      'status': 'approved',
      'actionTime': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectRequest(CopyTradeRecord record) async {
    await FirebaseFirestore.instance
        .collection('copy_trades')
        .doc(record.id)
        .update({
      'status': 'rejected',
      'actionTime': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _handleSnapshot(QuerySnapshot snapshot) async {
    if (_isCircuitBreakerTripped) {
      debugPrint('Copy trading circuit breaker tripped. Skipping execution.');
      return;
    }

    for (final doc in snapshot.docs) {
      final record = CopyTradeRecord.fromDocument(doc);
      // Double check executed flag to avoid race conditions
      if (!record.executed) {
        if (record.status == 'approved') {
          await _executeTrade(record);
        } else if (record.status == 'pending_approval') {
          await _checkAndAutoExecute(record);
        }
      }
    }
  }

  Future<void> _checkAndAutoExecute(CopyTradeRecord record) async {
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('investor_groups')
          .doc(record.groupId)
          .get();

      if (!groupDoc.exists) return;

      final group = InvestorGroup.fromJson(groupDoc.data()!);
      final settings = group.getCopyTradeSettings(_firebaseUserId!);

      if (settings != null && settings.autoExecute && settings.enabled) {
        if (settings.isRiskGuardianTripped) {
          debugPrint('Risk Guardian tripped. Aborting auto-execution.');
          await FirebaseFirestore.instance
              .collection('copy_trades')
              .doc(record.id)
              .update({
            'status': 'aborted',
            'executionResult': 'aborted_risk_guardian_tripped',
            'error':
                'Risk Guardian circuit breaker is tripped: ${settings.riskGuardianTripReason ?? 'Protection active'}',
            'executionTime': FieldValue.serverTimestamp(),
          });
          return;
        }
        debugPrint('Auto-executing copy trade: ${record.id}');
        await _executeTrade(record);
      }
    } catch (e) {
      debugPrint('Error checking auto-execute: $e');
    }
  }

  /// Resets the Risk Guardian trip state and re-enables copy trading for a group
  Future<void> resetRiskGuardian(String groupId) async {
    if (_firebaseUserId == null) return;
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('investor_groups')
          .doc(groupId)
          .get();
      if (!groupDoc.exists) return;
      final group = InvestorGroup.fromJson(groupDoc.data()!);
      final settings = group.getCopyTradeSettings(_firebaseUserId!);
      if (settings != null) {
        CopyTradeRiskGuardianService.resetGuardian(settings);
        settings.enabled = true; // allow resuming
        await FirebaseFirestore.instance
            .collection('investor_groups')
            .doc(groupId)
            .update({
          'memberCopyTradeSettings.${_firebaseUserId}': settings.toJson(),
        });
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error resetting Risk Guardian: $e');
    }
  }

  Future<bool> _checkDailyLimit(CopyTradeRecord record) async {
    try {
      // 1. Fetch Investor Group Settings
      final groupDoc = await FirebaseFirestore.instance
          .collection('investor_groups')
          .doc(record.groupId)
          .get();

      if (!groupDoc.exists) return false;

      final group = InvestorGroup.fromJson(groupDoc.data()!);
      final settings = group.getCopyTradeSettings(_firebaseUserId!);

      if (settings == null || settings.maxDailyAmount == null) {
        return true; // No limit set
      }

      // 2. Calculate today's total executed amount
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final todayTrades = await FirebaseFirestore.instance
          .collection('copy_trades')
          .where('targetUserId', isEqualTo: _firebaseUserId)
          .where('executed', isEqualTo: true)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .get();

      double totalAmount = 0;
      for (var doc in todayTrades.docs) {
        final trade = CopyTradeRecord.fromDocument(doc);
        double tradeAmount = trade.price * trade.copiedQuantity;
        if (trade.orderType == 'option') {
          tradeAmount *= 100; // Options multiplier
        }
        totalAmount += tradeAmount;
      }

      // Add current trade amount
      double currentTradeAmount = record.price * record.copiedQuantity;
      if (record.orderType == 'option') {
        currentTradeAmount *= 100;
      }

      if (totalAmount + currentTradeAmount > settings.maxDailyAmount!) {
        debugPrint(
            'Daily limit exceeded. Limit: ${settings.maxDailyAmount}, Used: $totalAmount, Current: $currentTradeAmount');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error checking daily limit: $e');
      return false; // Fail safe
    }
  }

  Future<void> _executeTrade(CopyTradeRecord record) async {
    if (_service == null || _brokerageUser == null) return;

    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      _isCircuitBreakerTripped = true;
      debugPrint(
          'Circuit breaker tripped after $_consecutiveFailures failures');
      return;
    }

    // 1. Fetch Investor Group Settings for Risk Guardian checks
    CopyTradeSettings? settings;
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('investor_groups')
          .doc(record.groupId)
          .get();
      if (groupDoc.exists) {
        final group = InvestorGroup.fromJson(groupDoc.data()!);
        settings = group.getCopyTradeSettings(_firebaseUserId!);
      }
    } catch (e) {
      debugPrint('Error loading settings for risk evaluation: $e');
    }

    // Risk Guardian Check: If already tripped, abort trade
    if (settings != null && settings.isRiskGuardianTripped) {
      await FirebaseFirestore.instance
          .collection('copy_trades')
          .doc(record.id)
          .update({
        'status': 'aborted',
        'executionResult': 'aborted_risk_guardian_tripped',
        'error':
            'Risk Guardian is tripped: ${settings.riskGuardianTripReason ?? 'Protection active'}',
        'executionTime': FieldValue.serverTimestamp(),
      });
      return;
    }

    // Risk Guardian Check: Auto-disconnect on leader drawdown & return divergence
    if (settings != null && settings.autoDisconnectOnDivergence == true) {
      try {
        final historySnapshot = await FirebaseFirestore.instance
            .collection('copy_trades')
            .where('targetUserId', isEqualTo: _firebaseUserId)
            .where('executed', isEqualTo: true)
            .limit(50)
            .get();
        final executedTrades = historySnapshot.docs
            .map((d) => CopyTradeRecord.fromDocument(d))
            .toList();

        final divergenceResult =
            CopyTradeRiskGuardianService.evaluateDivergence(
          settings: settings,
          trades: executedTrades,
        );

        if (divergenceResult.shouldDisconnect) {
          final tripReason =
              divergenceResult.tripReason ?? 'Divergence threshold exceeded';
          CopyTradeRiskGuardianService.tripGuardian(settings, tripReason);

          await FirebaseFirestore.instance
              .collection('investor_groups')
              .doc(record.groupId)
              .update({
            'memberCopyTradeSettings.${_firebaseUserId}': settings.toJson(),
          });

          await FirebaseFirestore.instance
              .collection('copy_trades')
              .doc(record.id)
              .update({
            'status': 'aborted',
            'executionResult': 'aborted_risk_guardian_tripped',
            'error': 'Risk Guardian triggered auto-disconnect: $tripReason',
            'executionTime': FieldValue.serverTimestamp(),
          });
          debugPrint('Risk Guardian tripped & auto-disconnected: $tripReason');
          return;
        }
      } catch (e) {
        debugPrint('Error evaluating divergence in Risk Guardian: $e');
      }
    }

    // Check daily limit
    final withinLimit = await _checkDailyLimit(record);
    if (!withinLimit) {
      await FirebaseFirestore.instance
          .collection('copy_trades')
          .doc(record.id)
          .update({
        'executionResult': 'skipped_daily_limit',
        'error': 'Daily limit exceeded',
        'executionTime': FieldValue.serverTimestamp(),
      });
      return;
    }

    try {
      // 2. Get Account
      final accounts = await _service!
          .getAccounts(_brokerageUser!, _accountStore, null, null);
      if (accounts.isEmpty) {
        throw Exception('No accounts found for copy trading');
      }
      final account = accounts.first; // Use first account for now
      final accountEquity = account.totalValue ?? account.buyingPower;

      // Risk Guardian Check: Max Capital Allocation per trade
      final effectiveSettings = settings ?? CopyTradeSettings();
      final allocResult = CopyTradeRiskGuardianService.evaluateAllocation(
        record: record,
        settings: effectiveSettings,
        accountEquity: accountEquity,
      );

      if (!allocResult.isAllowed) {
        await FirebaseFirestore.instance
            .collection('copy_trades')
            .doc(record.id)
            .update({
          'status': 'aborted',
          'executionResult': 'aborted_allocation_limit',
          'error':
              allocResult.abortReason ?? 'Capital allocation limit exceeded',
          'executionTime': FieldValue.serverTimestamp(),
        });
        debugPrint(
            'Copy trade aborted due to allocation limit: ${allocResult.abortReason}');
        return;
      }

      final executionQuantity = allocResult.allowedQuantity;

      // Risk Guardian Check: Max Slippage Abort
      double currentMarketPrice = record.price;
      final isBuy = record.side.toLowerCase().contains('buy');
      try {
        if (record.orderType == 'instrument') {
          final quote = await _service!
              .getQuote(_brokerageUser!, _quoteStore, record.symbol);
          final quotePrice = isBuy
              ? (quote.askPrice ?? quote.lastTradePrice)
              : (quote.bidPrice ?? quote.lastTradePrice);
          if (quotePrice != null && quotePrice > 0) {
            currentMarketPrice = quotePrice;
          }
        }
      } catch (e) {
        debugPrint('Could not fetch market quote for slippage evaluation: $e');
      }

      final slippageResult = CopyTradeRiskGuardianService.evaluateSlippage(
        record: record,
        currentMarketPrice: currentMarketPrice,
        settings: effectiveSettings,
      );

      if (!slippageResult.isAllowed) {
        await FirebaseFirestore.instance
            .collection('copy_trades')
            .doc(record.id)
            .update({
          'status': 'aborted',
          'executed': false,
          'executionResult': 'aborted_max_slippage',
          'error': slippageResult.abortReason,
          'priceSlippage': slippageResult.priceDifference,
          'slippageBps': slippageResult.slippageBps,
          'executionTime': FieldValue.serverTimestamp(),
        });
        debugPrint(
            'Copy trade aborted due to excessive slippage: ${slippageResult.abortReason}');
        return;
      }

      final orderPrice = (effectiveSettings.overridePrice ?? false)
          ? currentMarketPrice
          : record.price;

      if (record.orderType == 'instrument') {
        // 3. Get Instrument
        final instrument = await _service!.getInstrumentBySymbol(
            _brokerageUser!, _instrumentStore, record.symbol);
        if (instrument == null) {
          throw Exception('Instrument not found: ${record.symbol}');
        }

        // 4. Place Order
        await _service!.placeInstrumentOrder(
          _brokerageUser!,
          account,
          instrument,
          record.symbol,
          record.side == 'buy' ? 'buy' : 'sell',
          orderPrice,
          executionQuantity.toInt(),
          type: 'limit',
          timeInForce: 'gfd',
        );
      } else if (record.orderType == 'option') {
        if (record.legs == null || record.legs!.isEmpty) {
          throw Exception('No legs for option order');
        }
        final leg = record.legs!.first; // Assuming single leg for now
        if (leg.expirationDate == null ||
            leg.strikePrice == null ||
            leg.optionType == null) {
          throw Exception('Incomplete leg data');
        }

        // 3. Get Underlying Instrument
        final instrument = await _service!.getInstrumentBySymbol(
            _brokerageUser!, _instrumentStore, record.symbol);
        if (instrument == null) {
          throw Exception('Instrument not found: ${record.symbol}');
        }

        // 4. Find Option Instrument
        final expirationDateStr =
            leg.expirationDate!.toIso8601String().substring(0, 10);
        final options = await _service!
            .streamOptionInstruments(_brokerageUser!, _optionInstrumentStore,
                instrument, expirationDateStr, leg.optionType)
            .first;

        final optionInstrument = options.firstWhere(
            (o) =>
                o.strikePrice == leg.strikePrice &&
                o.type == leg.optionType &&
                (o.expirationDate != null &&
                    o.expirationDate!.toIso8601String().substring(0, 10) ==
                        expirationDateStr),
            orElse: () => throw Exception('Option instrument not found'));

        // 5. Place Order
        await _service!.placeOptionsOrder(
          _brokerageUser!,
          account,
          optionInstrument,
          record.side == 'buy' ? 'buy' : 'sell', // Direction
          leg.positionEffect ?? 'open', // Position effect
          record.side == 'buy' ? 'debit' : 'credit', // Credit/Debit
          orderPrice,
          executionQuantity.toInt(),
          type: 'limit',
          timeInForce: 'gfd',
        );
      }

      // Mark as executed with latency and slippage tracking
      final executionTime = DateTime.now();
      final latencyMs =
          executionTime.difference(record.timestamp).inMilliseconds;
      final effectiveLatencyMs = latencyMs >= 0 ? latencyMs : 0;
      final executedPrice = currentMarketPrice;
      final priceSlippage = isBuy
          ? (executedPrice - record.price)
          : (record.price - executedPrice);
      final slippageBps =
          record.price > 0 ? (priceSlippage / record.price) * 10000.0 : 0.0;

      await FirebaseFirestore.instance
          .collection('copy_trades')
          .doc(record.id)
          .update({
        'executed': true,
        'status': 'approved',
        'executionResult': 'success',
        'executionTime': FieldValue.serverTimestamp(),
        'executedPrice': executedPrice,
        'fillLatencyMs': effectiveLatencyMs,
        'priceSlippage': priceSlippage,
        'slippageBps': slippageBps,
        'copiedQuantity': executionQuantity,
      });

      debugPrint(
          'Executed copy trade: ${record.id} (latency: ${effectiveLatencyMs}ms, slippage: ${slippageBps.toStringAsFixed(1)} bps)');
      _consecutiveFailures = 0; // Reset failure counter on success
    } catch (e) {
      debugPrint('Error executing copy trade: $e');
      _consecutiveFailures++;

      // Log failure
      await FirebaseFirestore.instance
          .collection('copy_trades')
          .doc(record.id)
          .update({
        'executionResult': 'failure',
        'error': e.toString(),
        'executionTime': FieldValue.serverTimestamp(),
      });
    }
  }
}

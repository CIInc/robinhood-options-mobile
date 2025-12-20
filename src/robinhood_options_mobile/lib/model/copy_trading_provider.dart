import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
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

  void initialize(String firebaseUserId, BrokerageUser brokerageUser,
      IBrokerageService service) {
    if (_firebaseUserId == firebaseUserId &&
        _brokerageUser?.userName == brokerageUser.userName) return;

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
        .snapshots()
        .listen(_handleSnapshot);
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
        await _executeTrade(record);
      }
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
      dynamic orderResult;

      // 1. Get Account
      final accounts = await _service!
          .getAccounts(_brokerageUser!, _accountStore, null, null);
      if (accounts.isEmpty) {
        throw Exception('No accounts found for copy trading');
      }
      final account = accounts.first; // Use first account for now

      if (record.orderType == 'instrument') {
        // 2. Get Instrument
        final instrument = await _service!.getInstrumentBySymbol(
            _brokerageUser!, _instrumentStore, record.symbol);
        if (instrument == null) {
          throw Exception('Instrument not found: ${record.symbol}');
        }

        // 3. Place Order
        orderResult = await _service!.placeInstrumentOrder(
          _brokerageUser!,
          account,
          instrument,
          record.symbol,
          record.side == 'buy' ? 'buy' : 'sell',
          record.price,
          record.copiedQuantity.toInt(),
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

        // 2. Get Underlying Instrument
        final instrument = await _service!.getInstrumentBySymbol(
            _brokerageUser!, _instrumentStore, record.symbol);
        if (instrument == null) {
          throw Exception('Instrument not found: ${record.symbol}');
        }

        // 3. Find Option Instrument
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
                o.expirationDate == expirationDateStr,
            orElse: () => throw Exception('Option instrument not found'));

        // 4. Place Order
        orderResult = await _service!.placeOptionsOrder(
          _brokerageUser!,
          account,
          optionInstrument,
          record.side == 'buy' ? 'buy' : 'sell', // Direction
          leg.positionEffect ?? 'open', // Position effect
          record.side == 'buy' ? 'debit' : 'credit', // Credit/Debit
          record.price,
          record.copiedQuantity.toInt(),
          type: 'limit',
          timeInForce: 'gfd',
        );
      }

      // Mark as executed
      await FirebaseFirestore.instance
          .collection('copy_trades')
          .doc(record.id)
          .update({
        'executed': true,
        'executionResult': 'success',
        'executionTime': FieldValue.serverTimestamp(),
        // 'orderId': orderResult['id'], // Assuming orderResult has id, depends on brokerage response
      });

      debugPrint('Executed copy trade: ${record.id}');
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

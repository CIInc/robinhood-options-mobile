import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/live_activity_models.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';

void main() {
  group('OptionLiveActivitySession Model Tests', () {
    OptionAggregatePosition createMockPosition({
      required String symbol,
      required double strike,
      required DateTime expiration,
      required double markPrice,
      String direction = 'debit',
      String type = 'call',
      double quantity = 1.0,
      double averageOpenPrice = 500.0, // $5.00 per share
    }) {
      final instrument = OptionInstrument(
        'chain_123',
        symbol,
        DateTime.now().subtract(const Duration(days: 30)),
        expiration,
        'opt_inst_1',
        null,
        const MinTicks(0.01, 0.05, 3.0),
        'tradable',
        'active',
        strike,
        'tradable',
        type,
        DateTime.now(),
        '',
        null,
        '',
        '',
      );

      instrument.optionMarketData = OptionMarketData(
        markPrice, // adjustedMarkPrice
        markPrice + 0.05, // askPrice
        10, // askSize
        markPrice - 0.05, // bidPrice
        10, // bidSize
        strike + markPrice, // breakEvenPrice
        markPrice * 1.1, // highPrice
        'opt_inst_1', // instrument
        'opt_inst_1', // instrumentId
        markPrice, // lastTradePrice
        5, // lastTradeSize
        markPrice * 0.9, // lowPrice
        markPrice, // markPrice
        1000, // openInterest
        DateTime.now().subtract(const Duration(days: 1)), // previousCloseDate
        markPrice * 0.9, // previousClosePrice
        500, // volume
        symbol, // symbol
        '${symbol}261016C00580000', // occSymbol
        0.55, // chanceOfProfitLong
        0.45, // chanceOfProfitShort
        0.50, // delta
        0.05, // gamma
        0.25, // impliedVolatility
        0.01, // rho
        -0.02, // theta
        0.05, // vega
        null, // highFillRateBuyPrice
        null, // highFillRateSellPrice
        null, // lowFillRateBuyPrice
        null, // lowFillRateSellPrice
        DateTime.now(), // updatedAt
      );

      return OptionAggregatePosition(
        'pos_$symbol',
        'chain_123',
        'acct_123',
        symbol,
        type,
        averageOpenPrice,
        [
          OptionLeg('leg_1', null, 'long', 'opt_inst_1', null, 1, 'buy',
              expiration, strike, type, []),
        ],
        quantity,
        null,
        null,
        direction,
        '',
        100.0,
        DateTime.now(),
        DateTime.now(),
        'code_123',
      )
        ..optionInstrument = instrument;
    }

    test('0DTE and DTE detection logic calculates correctly', () {
      final now = DateTime.now();
      final todayExpiry = DateTime(now.year, now.month, now.day, 16, 0);
      final futureExpiry = now.add(const Duration(days: 14));

      expect(OptionLiveActivitySession.calculateIs0DTE(todayExpiry), isTrue);
      expect(OptionLiveActivitySession.calculateDTE(todayExpiry), 0);

      expect(OptionLiveActivitySession.calculateIs0DTE(futureExpiry), isFalse);
      expect(OptionLiveActivitySession.calculateDTE(futureExpiry), 14);

      expect(OptionLiveActivitySession.calculateIs0DTE(null), isFalse);
      expect(OptionLiveActivitySession.calculateDTE(null), 0);
    });

    test('initializes session with correct trailing stop math for long position', () {
      final now = DateTime.now();
      final todayExpiry = DateTime(now.year, now.month, now.day);
      final pos = createMockPosition(
        symbol: 'SPY',
        strike: 580.0,
        expiration: todayExpiry,
        markPrice: 5.00,
        direction: 'debit',
      );

      final session = OptionLiveActivitySession.fromPosition(
        pos,
        trailingStopPercent: 10.0,
      );

      expect(session.symbol, 'SPY');
      expect(session.strikePrice, 580.0);
      expect(session.is0DTE, isTrue);
      expect(session.dte, 0);
      expect(session.currentPrice, 5.00);
      expect(session.peakPrice, 5.00);
      // Stop price is 10% below peak: 5.00 * (1 - 0.10) = 4.50
      expect(session.trailingStopPrice, closeTo(4.50, 0.001));
      expect(session.isTrailingStopTriggered, isFalse);
      expect(session.trailingStopDistancePercent, closeTo(10.0, 0.001));
      expect(session.statusText, '0DTE Active');
    });

    test('trailing stop ratchets up on price increase and triggers on retrace', () {
      final now = DateTime.now();
      final expiry = now.add(const Duration(days: 7));
      final pos = createMockPosition(
        symbol: 'TSLA',
        strike: 250.0,
        expiration: expiry,
        markPrice: 4.00,
      );

      var session = OptionLiveActivitySession.fromPosition(
        pos,
        trailingStopPercent: 15.0,
      );

      expect(session.peakPrice, 4.00);
      expect(session.trailingStopPrice, closeTo(3.40, 0.001)); // 4.00 * 0.85
      expect(session.isTrailingStopTriggered, isFalse);

      // Price advances to $6.00
      final higherPos = createMockPosition(
        symbol: 'TSLA',
        strike: 250.0,
        expiration: expiry,
        markPrice: 6.00,
      );

      session = session.copyWithUpdatedPosition(higherPos);
      expect(session.currentPrice, 6.00);
      expect(session.peakPrice, 6.00);
      // Stop price ratchets up: 6.00 * 0.85 = 5.10
      expect(session.trailingStopPrice, closeTo(5.10, 0.001));
      expect(session.isTrailingStopTriggered, isFalse);

      // Price retraces to $5.50 (above stop of $5.10 -> not triggered)
      final retracePos = createMockPosition(
        symbol: 'TSLA',
        strike: 250.0,
        expiration: expiry,
        markPrice: 5.50,
      );
      session = session.copyWithUpdatedPosition(retracePos);
      expect(session.peakPrice, 6.00);
      expect(session.trailingStopPrice, closeTo(5.10, 0.001));
      expect(session.isTrailingStopTriggered, isFalse);

      // Price breaks down to $4.90 (below stop of $5.10 -> triggered!)
      final breachPos = createMockPosition(
        symbol: 'TSLA',
        strike: 250.0,
        expiration: expiry,
        markPrice: 4.90,
      );
      session = session.copyWithUpdatedPosition(breachPos);
      expect(session.currentPrice, 4.90);
      expect(session.peakPrice, 6.00);
      expect(session.trailingStopPrice, closeTo(5.10, 0.001));
      expect(session.isTrailingStopTriggered, isTrue);
      expect(session.statusText, 'STOP TRIGGERED');
    });

    test('updating trailing stop percentage dynamically recalculates stop price', () {
      final now = DateTime.now();
      final pos = createMockPosition(
        symbol: 'NVDA',
        strike: 130.0,
        expiration: now.add(const Duration(days: 3)),
        markPrice: 10.00,
      );

      var session = OptionLiveActivitySession.fromPosition(
        pos,
        trailingStopPercent: 10.0,
      );
      expect(session.trailingStopPrice, closeTo(9.00, 0.001));

      // Tighten stop to 5%
      session = session.copyWithTrailingStopPercent(5.0);
      expect(session.trailingStopPercent, 5.0);
      expect(session.trailingStopPrice, closeTo(9.50, 0.001));

      // Loosen stop to 20%
      session = session.copyWithTrailingStopPercent(20.0);
      expect(session.trailingStopPercent, 20.0);
      expect(session.trailingStopPrice, closeTo(8.00, 0.001));
    });

    test('serialization and deserialization roundtrip preserves all attributes', () {
      final now = DateTime.now();
      final todayExpiry = DateTime(now.year, now.month, now.day);
      final pos = createMockPosition(
        symbol: 'QQQ',
        strike: 490.0,
        expiration: todayExpiry,
        markPrice: 3.50,
      );

      final session = OptionLiveActivitySession.fromPosition(
        pos,
        trailingStopPercent: 12.0,
        activityId: 'native_act_abc123',
      );

      final map = session.toChannelPayload();
      expect(map['symbol'], 'QQQ');
      expect(map['is0DTE'], isTrue);
      expect(map['trailingStopPercent'], 12.0);
      expect(map['activityId'], 'native_act_abc123');

      final restored = OptionLiveActivitySession.fromJson(map);
      expect(restored.positionId, session.positionId);
      expect(restored.symbol, session.symbol);
      expect(restored.strikePrice, session.strikePrice);
      expect(restored.currentPrice, session.currentPrice);
      expect(restored.trailingStopPrice, closeTo(session.trailingStopPrice, 0.001));
      expect(restored.isTrailingStopTriggered, session.isTrailingStopTriggered);
      expect(restored.is0DTE, session.is0DTE);
      expect(restored.activityId, session.activityId);
    });
  });
}

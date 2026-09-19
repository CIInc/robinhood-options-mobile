import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/option_roll_models.dart';

void main() {
  group('OptionRollCalculation Tests', () {
    final now = DateTime.now();
    final exp1 = now.add(const Duration(days: 7));
    final exp2 = now.add(const Duration(days: 35));

    OptionInstrument createInstrument({
      required String id,
      required String symbol,
      required String type,
      required double strike,
      required DateTime expiration,
      double mark = 1.0,
      double bid = 0.95,
      double ask = 1.05,
      double delta = 0.30,
      double theta = -0.05,
      double iv = 0.25,
    }) {
      final instr = OptionInstrument.fromJson({
        'chain_id': 'chain_$symbol',
        'chain_symbol': symbol,
        'expiration_date': expiration.toIso8601String().split('T').first,
        'id': id,
        'min_ticks': {'above_tick': 0.05, 'below_tick': 0.01, 'cutoff_price': 3.0},
        'rhs_tradability': 'tradable',
        'state': 'active',
        'strike_price': strike.toString(),
        'tradability': 'tradable',
        'type': type,
        'url': 'url_$id',
        'long_strategy_code': '',
        'short_strategy_code': '',
      });
      instr.optionMarketData = OptionMarketData.fromJson({
        'adjusted_mark_price': mark.toString(),
        'ask_price': ask.toString(),
        'ask_size': 10,
        'bid_price': bid.toString(),
        'bid_size': 10,
        'break_even_price': strike.toString(),
        'instrument': instr.url,
        'instrument_id': instr.id,
        'last_trade_price': mark.toString(),
        'mark_price': mark.toString(),
        'open_interest': 100,
        'volume': 50,
        'symbol': symbol,
        'occ_symbol': '${symbol}_TEST',
        'delta': delta.toString(),
        'gamma': '0.02',
        'theta': theta.toString(),
        'vega': '0.15',
        'implied_volatility': iv.toString(),
      });
      return instr;
    }

    test('Covered Call / Short Call Roll Out for Net Credit', () {
      final oldInstr = createInstrument(
        id: 'old_call_100',
        symbol: 'AAPL',
        type: 'call',
        strike: 100.0,
        expiration: exp1,
        mark: 0.50,
        ask: 0.52,
        bid: 0.48,
        delta: 0.20,
        theta: -0.08,
      );

      final newInstr = createInstrument(
        id: 'new_call_100',
        symbol: 'AAPL',
        type: 'call',
        strike: 100.0,
        expiration: exp2,
        mark: 1.80,
        ask: 1.85,
        bid: 1.75,
        delta: 0.35,
        theta: -0.04,
      );

      final leg = OptionLeg(
        'leg_1',
        null,
        'short',
        oldInstr.url,
        'open',
        1,
        'sell',
        exp1,
        100.0,
        'call',
        [],
      );

      final position = OptionAggregatePosition(
        'pos_cc_1',
        'chain_AAPL',
        'acct_1',
        'AAPL',
        'covered_call',
        150.0, // averageOpenPrice per contract = $1.50/share
        [leg],
        2.0, // 2 contracts
        null,
        null,
        'credit',
        '',
        100.0,
        now,
        now,
        'covered_call',
      );
      position.optionInstrument = oldInstr;

      final calc = OptionRollCalculation.calculate(
        position: position,
        oldInstrument: oldInstr,
        newInstrument: newInstr,
        underlyingCostBasis: 98.0,
      );

      expect(calc.isShort, isTrue);
      // Buy to close old at ask (0.52)
      expect(calc.closingPrice, equals(0.52));
      // Sell to open new at bid (1.75)
      expect(calc.openingPrice, equals(1.75));
      // Net credit = 1.75 - 0.52 = 1.23
      expect(calc.creditOrDebit, equals('credit'));
      expect(calc.netPrice, closeTo(1.23, 0.001));
      expect(calc.netCashFlow, closeTo(1.23, 0.001));
      // Total net cash flow for 2 contracts = 1.23 * 2 * 100 = 246.0
      expect(calc.totalNetCashFlow, closeTo(246.0, 0.01));

      // DTE increased
      expect(calc.dteDelta, greaterThan(0));
      // Strike unchanged
      expect(calc.strikeDelta, equals(0.0));

      // Breakeven check:
      // Initial breakeven = basis (98.0) - initial premium (1.50) = 96.50
      expect(calc.currentBreakeven, closeTo(96.50, 0.001));
      // New breakeven with +1.23 credit = 96.50 - 1.23 = 95.27
      expect(calc.updatedBreakeven, closeTo(95.27, 0.001));
      expect(calc.breakevenDelta, closeTo(-1.23, 0.001));

      // 2-leg order builder
      final legs = calc.buildOrderLegs();
      expect(legs.length, equals(2));
      expect(legs[0]['position_effect'], equals('close'));
      expect(legs[0]['side'], equals('buy'));
      expect(legs[1]['position_effect'], equals('open'));
      expect(legs[1]['side'], equals('sell'));
    });

    test('Cash-Secured Put Roll Down & Out', () {
      final oldInstr = createInstrument(
        id: 'old_put_150',
        symbol: 'TSLA',
        type: 'put',
        strike: 150.0,
        expiration: exp1,
        mark: 4.00,
        ask: 4.10,
        bid: 3.90,
      );

      final newInstr = createInstrument(
        id: 'new_put_145',
        symbol: 'TSLA',
        type: 'put',
        strike: 145.0,
        expiration: exp2,
        mark: 4.60,
        ask: 4.70,
        bid: 4.50,
      );

      final leg = OptionLeg(
        'leg_put',
        null,
        'short',
        oldInstr.url,
        'open',
        1,
        'sell',
        exp1,
        150.0,
        'put',
        [],
      );

      final position = OptionAggregatePosition(
        'pos_csp',
        'chain_TSLA',
        'acct_1',
        'TSLA',
        'cash_secured_put',
        300.0, // $3.00 initial premium
        [leg],
        1.0,
        null,
        null,
        'credit',
        '',
        100.0,
        now,
        now,
        'put',
      );

      final calc = OptionRollCalculation.calculate(
        position: position,
        oldInstrument: oldInstr,
        newInstrument: newInstr,
      );

      expect(calc.isShort, isTrue);
      expect(calc.closingPrice, equals(4.10));
      expect(calc.openingPrice, equals(4.50));
      // Net credit = 4.50 - 4.10 = 0.40
      expect(calc.creditOrDebit, equals('credit'));
      expect(calc.netPrice, closeTo(0.40, 0.001));

      // Strike rolled down from 150 to 145
      expect(calc.strikeDelta, equals(-5.0));

      // Original breakeven = 150 - 3.00 = 147.0
      expect(calc.currentBreakeven, closeTo(147.0, 0.001));
      // Updated breakeven = 145 - (3.00 + 0.40) = 141.60
      expect(calc.updatedBreakeven, closeTo(141.60, 0.001));

      expect(calc.summaryLabel, contains('Roll Down & Out'));
    });

    test('Long Call Roll Out for Net Debit', () {
      final oldInstr = createInstrument(
        id: 'old_long_call',
        symbol: 'NVDA',
        type: 'call',
        strike: 120.0,
        expiration: exp1,
        mark: 2.00,
        bid: 1.90,
        ask: 2.10,
      );

      final newInstr = createInstrument(
        id: 'new_long_call',
        symbol: 'NVDA',
        type: 'call',
        strike: 120.0,
        expiration: exp2,
        mark: 5.00,
        bid: 4.90,
        ask: 5.10,
      );

      final leg = OptionLeg(
        'leg_lc',
        null,
        'long',
        oldInstr.url,
        'open',
        1,
        'buy',
        exp1,
        120.0,
        'call',
        [],
      );

      final position = OptionAggregatePosition(
        'pos_lc',
        'chain_NVDA',
        'acct_1',
        'NVDA',
        'long_call',
        250.0, // $2.50 initial debit
        [leg],
        1.0,
        null,
        null,
        'debit',
        '',
        100.0,
        now,
        now,
        'call',
      );

      final calc = OptionRollCalculation.calculate(
        position: position,
        oldInstrument: oldInstr,
        newInstrument: newInstr,
      );

      expect(calc.isShort, isFalse);
      // Sell to close old at bid (1.90)
      expect(calc.closingPrice, equals(1.90));
      // Buy to open new at ask (5.10)
      expect(calc.openingPrice, equals(5.10));
      // Net = 1.90 - 5.10 = -3.20 (debit)
      expect(calc.creditOrDebit, equals('debit'));
      expect(calc.netPrice, closeTo(3.20, 0.001));
      expect(calc.netCashFlow, closeTo(-3.20, 0.001));
      expect(calc.totalNetCashFlow, closeTo(-320.0, 0.01));

      final legs = calc.buildOrderLegs();
      expect(legs[0]['position_effect'], equals('close'));
      expect(legs[0]['side'], equals('sell'));
      expect(legs[1]['position_effect'], equals('open'));
      expect(legs[1]['side'], equals('buy'));
    });

    test('Covered Call Roll Up & Out (Higher Strike and Later Expiration)', () {
      final oldInstr = createInstrument(
        id: 'old_call_200',
        symbol: 'MSFT',
        type: 'call',
        strike: 200.0,
        expiration: exp1,
        mark: 3.00,
        bid: 2.90,
        ask: 3.10,
        delta: 0.55,
      );

      final newInstr = createInstrument(
        id: 'new_call_210',
        symbol: 'MSFT',
        type: 'call',
        strike: 210.0,
        expiration: exp2,
        mark: 3.50,
        bid: 3.40,
        ask: 3.60,
        delta: 0.35,
      );

      final leg = OptionLeg(
        'leg_msft',
        null,
        'short',
        oldInstr.url,
        'open',
        1,
        'sell',
        exp1,
        200.0,
        'call',
        [],
      );

      final position = OptionAggregatePosition(
        'pos_msft',
        'chain_MSFT',
        'acct_1',
        'MSFT',
        'covered_call',
        200.0,
        [leg],
        3.0, // 3 contracts
        null,
        null,
        'credit',
        '',
        100.0,
        now,
        now,
        'covered_call',
      );

      final calc = OptionRollCalculation.calculate(
        position: position,
        oldInstrument: oldInstr,
        newInstrument: newInstr,
        quantity: 3.0,
        underlyingCostBasis: 195.0,
      );

      expect(calc.isShort, isTrue);
      // Buy to close old at 3.10, Sell to open new at 3.40
      // Net credit = 3.40 - 3.10 = 0.30
      expect(calc.creditOrDebit, equals('credit'));
      expect(calc.netPrice, closeTo(0.30, 0.001));
      // Total net cash flow for 3 contracts = 0.30 * 3 * 100 = 90.0
      expect(calc.totalNetCashFlow, closeTo(90.0, 0.01));
      expect(calc.strikeDelta, equals(10.0));
      expect(calc.summaryLabel, contains('Roll Up & Out'));
    });

    test('Fallback to markPrice when bid/ask are zero or null', () {
      final oldInstr = createInstrument(
        id: 'old_zero_bid',
        symbol: 'SPY',
        type: 'call',
        strike: 500.0,
        expiration: exp1,
        mark: 1.20,
        bid: 0.0,
        ask: 0.0,
      );

      final newInstr = createInstrument(
        id: 'new_zero_bid',
        symbol: 'SPY',
        type: 'call',
        strike: 505.0,
        expiration: exp2,
        mark: 2.50,
        bid: 0.0,
        ask: 0.0,
      );

      final leg = OptionLeg(
        'leg_spy',
        null,
        'short',
        oldInstr.url,
        'open',
        1,
        'sell',
        exp1,
        500.0,
        'call',
        [],
      );

      final position = OptionAggregatePosition(
        'pos_spy',
        'chain_SPY',
        'acct_1',
        'SPY',
        'call',
        100.0,
        [leg],
        1.0,
        null,
        null,
        'credit',
        '',
        100.0,
        now,
        now,
        'call',
      );

      final calc = OptionRollCalculation.calculate(
        position: position,
        oldInstrument: oldInstr,
        newInstrument: newInstr,
      );

      expect(calc.closingPrice, equals(1.20));
      expect(calc.openingPrice, equals(2.50));
      expect(calc.creditOrDebit, equals('credit'));
      expect(calc.netPrice, closeTo(1.30, 0.001));
    });
  });
}


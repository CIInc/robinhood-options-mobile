import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_defense_models.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/option_roll_models.dart';

void main() {
  group('OptionDefensePlaybook Tests', () {
    final now = DateTime.now();
    final expNear = now.add(const Duration(days: 7));
    final expFar = now.add(const Duration(days: 35));

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
    }) {
      final instr = OptionInstrument.fromJson({
        'chain_id': 'chain_$symbol',
        'chain_symbol': symbol,
        'expiration_date': expiration.toIso8601String().split('T').first,
        'id': id,
        'min_ticks': {
          'above_tick': 0.05,
          'below_tick': 0.01,
          'cutoff_price': 3.0
        },
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
        'theta': '-0.05',
        'vega': '0.15',
        'implied_volatility': '0.25',
      });
      return instr;
    }

    test('Covered Call / Short Call tested and breached (Spot > Strike)', () {
      final callInstr = createInstrument(
        id: 'call_180',
        symbol: 'AAPL',
        type: 'call',
        strike: 180.0,
        expiration: expNear,
        delta: 0.58,
      );

      final leg = OptionLeg(
        'leg_call',
        null,
        'short',
        callInstr.url,
        'open',
        1,
        'sell',
        expNear,
        180.0,
        'call',
        [],
      );

      final position = OptionAggregatePosition(
        'pos_aapl_call',
        'chain_AAPL',
        'acct_1',
        'AAPL',
        'Covered Call',
        150.0,
        [leg],
        1.0,
        null,
        null,
        'credit',
        '',
        100.0,
        now,
        now,
        'covered_call',
      );

      // Underlying spot price is $183.00, breaching the $180.00 strike
      final playbook = OptionDefensePlaybook.analyze(
        position: position,
        optionInstrument: callInstr,
        underlyingPrice: 183.00,
      );

      expect(playbook.threat.isTested, isTrue);
      expect(playbook.threat.level, OptionDefenseThreatLevel.breached);
      expect(playbook.threat.statusTitle, contains('TESTED'));
      expect(playbook.threat.threatReasons.isNotEmpty, isTrue);

      // Should contain Roll Up & Out and Roll Out recommendations
      expect(
          playbook.actions
              .any((a) => a.actionType == DefenseActionType.rollStrikeAway),
          isTrue);
      expect(
          playbook.actions
              .any((a) => a.suggestedPreset == RollPreset.rollUpAndOut),
          isTrue);
      expect(
          playbook.actions.any((a) => a.suggestedPreset == RollPreset.rollOut),
          isTrue);

      final recommended = playbook.actions.firstWhere((a) => a.isRecommended);
      expect(recommended.actionType, DefenseActionType.rollStrikeAway);
      expect(recommended.suggestedPreset, RollPreset.rollUpAndOut);
    });

    test(
        'Cash-Secured Put in Critical Condition (Spot deep below strike + short DTE)',
        () {
      final putInstr = createInstrument(
        id: 'put_150',
        symbol: 'NVDA',
        type: 'put',
        strike: 150.0,
        expiration: now.add(const Duration(days: 2)), // 2 DTE
        delta: -0.75,
      );

      final leg = OptionLeg(
        'leg_put',
        null,
        'short',
        putInstr.url,
        'open',
        1,
        'sell',
        putInstr.expirationDate,
        150.0,
        'put',
        [],
      );

      final position = OptionAggregatePosition(
        'pos_nvda_put',
        'chain_NVDA',
        'acct_1',
        'NVDA',
        'Cash-Secured Put',
        200.0,
        [leg],
        1.0,
        null,
        null,
        'credit',
        '',
        100.0,
        now,
        now,
        'cash_secured_put',
      );

      // Underlying spot price crashed to $142.00 (breached by > 5%)
      final playbook = OptionDefensePlaybook.analyze(
        position: position,
        optionInstrument: putInstr,
        underlyingPrice: 142.00,
      );

      expect(playbook.threat.isTested, isTrue);
      expect(playbook.threat.level, OptionDefenseThreatLevel.critical);
      expect(playbook.threat.statusTitle, contains('CRITICAL'));
      expect(
          playbook.threat.threatReasons.any((r) => r.contains('DTE')), isTrue);

      // Should recommend Roll Out (same strike), Roll Down & Out, and Close Position
      expect(
          playbook.actions
              .any((a) => a.actionType == DefenseActionType.rollOutTime),
          isTrue);
      expect(
          playbook.actions
              .any((a) => a.actionType == DefenseActionType.closePosition),
          isTrue);
      expect(
          playbook.actions
              .any((a) => a.suggestedPreset == RollPreset.rollDownAndOut),
          isTrue);
    });

    test(
        'Cash-Secured Put Approaching Strike (Caution level: within 2% distance)',
        () {
      final putInstr = createInstrument(
        id: 'put_100',
        symbol: 'AMD',
        type: 'put',
        strike: 100.0,
        expiration: expFar, // 35 DTE
        delta: -0.38,
      );

      final leg = OptionLeg(
        'leg_put',
        null,
        'short',
        putInstr.url,
        'open',
        1,
        'sell',
        expFar,
        100.0,
        'put',
        [],
      );

      final position = OptionAggregatePosition(
        'pos_amd_put',
        'chain_AMD',
        'acct_1',
        'AMD',
        'Cash-Secured Put',
        150.0,
        [leg],
        1.0,
        null,
        null,
        'credit',
        '',
        100.0,
        now,
        now,
        'cash_secured_put',
      );

      // Spot is $101.50 (1.5% from short put strike $100)
      final playbook = OptionDefensePlaybook.analyze(
        position: position,
        optionInstrument: putInstr,
        underlyingPrice: 101.50,
      );

      expect(playbook.threat.isTested, isTrue);
      expect(playbook.threat.level, OptionDefenseThreatLevel.caution);
      expect(playbook.threat.statusTitle, contains('CAUTION'));
      expect(
          playbook.actions
              .any((a) => a.actionType == DefenseActionType.rollOutTime),
          isTrue);
      expect(
          playbook.actions
              .any((a) => a.suggestedPreset == RollPreset.rollDownAndOut),
          isTrue);
    });

    test('Safe Position far OTM (Unthreatened)', () {
      final callInstr = createInstrument(
        id: 'call_250',
        symbol: 'MSFT',
        type: 'call',
        strike: 250.0,
        expiration: expFar,
        delta: 0.12,
      );

      final leg = OptionLeg(
        'leg_call',
        null,
        'short',
        callInstr.url,
        'open',
        1,
        'sell',
        expFar,
        250.0,
        'call',
        [],
      );

      final position = OptionAggregatePosition(
        'pos_msft_call',
        'chain_MSFT',
        'acct_1',
        'MSFT',
        'Covered Call',
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
        'covered_call',
      );

      // Spot is $200.00 (20% below call strike $250.00)
      final playbook = OptionDefensePlaybook.analyze(
        position: position,
        optionInstrument: callInstr,
        underlyingPrice: 200.00,
      );

      expect(playbook.threat.isTested, isFalse);
      expect(playbook.threat.level, OptionDefenseThreatLevel.safe);
      expect(playbook.threat.statusTitle, contains('SAFE'));
      expect(
          playbook.actions
              .any((a) => a.actionType == DefenseActionType.holdOrTakeProfit),
          isTrue);
    });

    test('Vertical Credit Spread tested recommends Convert to Iron Condor', () {
      final putInstr = createInstrument(
        id: 'put_spread_short',
        symbol: 'SPY',
        type: 'put',
        strike: 500.0,
        expiration: expNear,
        delta: -0.55,
      );

      final legShort = OptionLeg(
        'leg_short',
        null,
        'short',
        putInstr.url,
        'open',
        1,
        'sell',
        expNear,
        500.0,
        'put',
        [],
      );

      final legLong = OptionLeg(
        'leg_long',
        null,
        'long',
        'url_put_long',
        'open',
        1,
        'buy',
        expNear,
        495.0,
        'put',
        [],
      );

      final position = OptionAggregatePosition(
        'pos_spy_spread',
        'chain_SPY',
        'acct_1',
        'SPY',
        'Put Credit Spread',
        120.0,
        [legShort, legLong],
        1.0,
        null,
        null,
        'credit',
        '',
        100.0,
        now,
        now,
        'put_credit_spread',
      );

      // Underlying spot price breached 500 strike to 498.50
      final playbook = OptionDefensePlaybook.analyze(
        position: position,
        optionInstrument: putInstr,
        underlyingPrice: 498.50,
      );

      expect(playbook.threat.isTested, isTrue);
      expect(
          playbook.actions
              .any((a) => a.actionType == DefenseActionType.convertIronCondor),
          isTrue);
      final ironCondorAction = playbook.actions.firstWhere(
          (a) => a.actionType == DefenseActionType.convertIronCondor);
      expect(ironCondorAction.badge, 'ZERO MARGIN CREDIT');
    });
  });
}

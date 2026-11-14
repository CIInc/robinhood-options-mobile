import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/services/copy_trade_risk_guardian_service.dart';

void main() {
  group('CopyTradeRiskGuardianService - Allocation Guardrail Tests', () {
    final now = DateTime(2026, 9, 23, 10, 0, 0);

    test('should allow full trade when no allocation limits are configured',
        () {
      final record = CopyTradeRecord(
        id: 'r1',
        sourceUserId: 'trader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'instrument',
        originalOrderId: 'o1',
        symbol: 'AAPL',
        side: 'buy',
        originalQuantity: 10,
        copiedQuantity: 10,
        price: 150.0,
        timestamp: now,
        executed: false,
      );
      final settings = CopyTradeSettings();

      final result = CopyTradeRiskGuardianService.evaluateAllocation(
        record: record,
        settings: settings,
        accountEquity: 10000.0,
      );

      expect(result.isAllowed, isTrue);
      expect(result.allowedQuantity, 10.0);
      expect(result.tradeAmount, 1500.0);
      expect(result.abortReason, isNull);
    });

    test('should clamp instrument quantity down to maxAllocationPerTrade', () {
      final record = CopyTradeRecord(
        id: 'r2',
        sourceUserId: 'trader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'instrument',
        originalOrderId: 'o2',
        symbol: 'AAPL',
        side: 'buy',
        originalQuantity: 10,
        copiedQuantity: 10,
        price: 100.0,
        timestamp: now,
        executed: false,
      );
      // Hard cap of $500 max per trade
      final settings = CopyTradeSettings(maxAllocationPerTrade: 500.0);

      final result = CopyTradeRiskGuardianService.evaluateAllocation(
        record: record,
        settings: settings,
      );

      expect(result.isAllowed, isTrue);
      expect(result.allowedQuantity, 5.0); // 500 / 100
      expect(result.tradeAmount, 500.0);
    });

    test('should clamp quantity based on maxAllocationPct of account equity',
        () {
      final record = CopyTradeRecord(
        id: 'r3',
        sourceUserId: 'trader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'instrument',
        originalOrderId: 'o3',
        symbol: 'TSLA',
        side: 'buy',
        originalQuantity: 20,
        copiedQuantity: 20,
        price: 200.0, // Total 20 * 200 = $4,000
        timestamp: now,
        executed: false,
      );
      // 5% max allocation of $20,000 equity = $1,000 cap
      final settings = CopyTradeSettings(maxAllocationPct: 5.0);

      final result = CopyTradeRiskGuardianService.evaluateAllocation(
        record: record,
        settings: settings,
        accountEquity: 20000.0,
      );

      expect(result.isAllowed, isTrue);
      expect(result.allowedQuantity, 5.0); // 1000 / 200
      expect(result.tradeAmount, 1000.0);
    });

    test('should clamp options quantity to integer contracts >= 1', () {
      final record = CopyTradeRecord(
        id: 'r4',
        sourceUserId: 'trader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'option',
        originalOrderId: 'o4',
        symbol: 'SPY',
        side: 'buy',
        originalQuantity: 5,
        copiedQuantity: 5,
        price: 3.0, // $3.00 * 100 = $300 per contract. Total 5 = $1500
        timestamp: now,
        executed: false,
      );
      // Max allocation $700 -> can afford 2 contracts ($600)
      final settings = CopyTradeSettings(maxAllocationPerTrade: 700.0);

      final result = CopyTradeRiskGuardianService.evaluateAllocation(
        record: record,
        settings: settings,
      );

      expect(result.isAllowed, isTrue);
      expect(result.allowedQuantity, 2.0);
      expect(result.tradeAmount, 600.0);
    });

    test('should abort option trade if allocation cap is less than 1 contract',
        () {
      final record = CopyTradeRecord(
        id: 'r5',
        sourceUserId: 'trader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'option',
        originalOrderId: 'o5',
        symbol: 'NVDA',
        side: 'buy',
        originalQuantity: 1,
        copiedQuantity: 1,
        price: 5.0, // $500 per contract
        timestamp: now,
        executed: false,
      );
      // Max allocation cap $300 is less than 1 contract ($500)
      final settings = CopyTradeSettings(maxAllocationPerTrade: 300.0);

      final result = CopyTradeRiskGuardianService.evaluateAllocation(
        record: record,
        settings: settings,
      );

      expect(result.isAllowed, isFalse);
      expect(result.allowedQuantity, 0.0);
      expect(result.abortReason, contains('exceeds max allocation cap'));
    });
  });

  group('CopyTradeRiskGuardianService - Slippage Abort Guardrail Tests', () {
    final now = DateTime(2026, 9, 23, 10, 0, 0);

    test(
        'should allow buy order when current price equals leader price (zero slippage)',
        () {
      final record = CopyTradeRecord(
        id: 's1',
        sourceUserId: 'trader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'instrument',
        originalOrderId: 'o1',
        symbol: 'AAPL',
        side: 'buy',
        originalQuantity: 10,
        copiedQuantity: 10,
        price: 100.0,
        timestamp: now,
        executed: false,
      );
      final settings = CopyTradeSettings(maxSlippageBps: 50.0);

      final result = CopyTradeRiskGuardianService.evaluateSlippage(
        record: record,
        currentMarketPrice: 100.0,
        settings: settings,
      );

      expect(result.isAllowed, isTrue);
      expect(result.slippageBps, 0.0);
    });

    test(
        'should allow buy order with favorable slippage (cheaper market price)',
        () {
      final record = CopyTradeRecord(
        id: 's2',
        sourceUserId: 'trader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'instrument',
        originalOrderId: 'o2',
        symbol: 'AAPL',
        side: 'buy',
        originalQuantity: 10,
        copiedQuantity: 10,
        price: 100.0,
        timestamp: now,
        executed: false,
      );
      final settings = CopyTradeSettings(maxSlippageBps: 50.0);

      final result = CopyTradeRiskGuardianService.evaluateSlippage(
        record: record,
        currentMarketPrice: 99.0, // -$1.00 (-100 bps) favorable
        settings: settings,
      );

      expect(result.isAllowed, isTrue);
      expect(result.slippageBps, -100.0);
    });

    test('should allow buy order with unfavorable slippage below threshold',
        () {
      final record = CopyTradeRecord(
        id: 's3',
        sourceUserId: 'trader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'instrument',
        originalOrderId: 'o3',
        symbol: 'AAPL',
        side: 'buy',
        originalQuantity: 10,
        copiedQuantity: 10,
        price: 100.0,
        timestamp: now,
        executed: false,
      );
      final settings = CopyTradeSettings(maxSlippageBps: 75.0);

      final result = CopyTradeRiskGuardianService.evaluateSlippage(
        record: record,
        currentMarketPrice: 100.40, // +$0.40 = +40 bps (< 75 bps)
        settings: settings,
      );

      expect(result.isAllowed, isTrue);
      expect(result.slippageBps, closeTo(40.0, 0.01));
    });

    test(
        'should abort buy order when unfavorable slippage exceeds maxSlippageBps',
        () {
      final record = CopyTradeRecord(
        id: 's4',
        sourceUserId: 'trader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'instrument',
        originalOrderId: 'o4',
        symbol: 'AAPL',
        side: 'buy',
        originalQuantity: 10,
        copiedQuantity: 10,
        price: 100.0,
        timestamp: now,
        executed: false,
      );
      final settings = CopyTradeSettings(maxSlippageBps: 50.0); // 0.50%

      final result = CopyTradeRiskGuardianService.evaluateSlippage(
        record: record,
        currentMarketPrice: 101.0, // +$1.00 = +100 bps (> 50 bps)
        settings: settings,
      );

      expect(result.isAllowed, isFalse);
      expect(result.slippageBps, closeTo(100.0, 0.01));
      expect(result.abortReason, contains('exceeded maximum threshold'));
    });

    test(
        'should abort sell order when market price drops significantly below leader exit',
        () {
      final record = CopyTradeRecord(
        id: 's5',
        sourceUserId: 'trader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'instrument',
        originalOrderId: 'o5',
        symbol: 'MSFT',
        side: 'sell',
        originalQuantity: 10,
        copiedQuantity: 10,
        price: 200.0,
        timestamp: now,
        executed: false,
      );
      final settings = CopyTradeSettings(maxSlippageBps: 50.0); // 50 bps max

      // Market dropped to $198.00 (-$2.00 = 100 bps unfavorable for seller)
      final result = CopyTradeRiskGuardianService.evaluateSlippage(
        record: record,
        currentMarketPrice: 198.0,
        settings: settings,
      );

      expect(result.isAllowed, isFalse);
      expect(result.slippageBps, closeTo(100.0, 0.01));
      expect(result.abortReason, contains('exceeded maximum threshold'));
    });
  });

  group('CopyTradeRiskGuardianService - Auto-Disconnect & Divergence Tests',
      () {
    final now = DateTime(2026, 9, 23, 10, 0, 0);

    test('should not disconnect when autoDisconnectOnDivergence is disabled',
        () {
      final settings = CopyTradeSettings(
        autoDisconnectOnDivergence: false,
        maxLeaderDrawdownPct: 10.0,
      );

      final result = CopyTradeRiskGuardianService.evaluateDivergence(
        settings: settings,
        trades: [],
        leaderDrawdownPct: 25.0,
      );

      expect(result.shouldDisconnect, isFalse);
    });

    test('should trigger auto-disconnect when leader drawdown exceeds limit',
        () {
      final settings = CopyTradeSettings(
        autoDisconnectOnDivergence: true,
        maxLeaderDrawdownPct: 15.0,
      );

      final result = CopyTradeRiskGuardianService.evaluateDivergence(
        settings: settings,
        trades: [],
        leaderDrawdownPct: 18.5,
      );

      expect(result.shouldDisconnect, isTrue);
      expect(result.tripReason, contains('Leader peak drawdown reached 18.5%'));
    });

    test(
        'should trigger auto-disconnect when follower return underperforms leader by more than divergence limit',
        () {
      final settings = CopyTradeSettings(
        targetUserId: 'leader_alice',
        autoDisconnectOnDivergence: true,
        maxReturnDivergencePct: 5.0, // 5% divergence threshold
      );

      // Follower achieved +2% while leader achieved +10% -> 8% divergence
      final trades = [
        CopyTradeRecord(
          id: 'd1',
          sourceUserId: 'leader_alice',
          targetUserId: 'follower1',
          groupId: 'grp1',
          orderType: 'instrument',
          originalOrderId: 'o1',
          symbol: 'AAPL',
          side: 'buy',
          originalQuantity: 10,
          copiedQuantity: 10,
          price: 100.0,
          timestamp: now,
          executed: true,
          leaderReturnPct: 0.10, // +10%
          followerReturnPct: 0.02, // +2%
        ),
      ];

      final result = CopyTradeRiskGuardianService.evaluateDivergence(
        settings: settings,
        trades: trades,
      );

      expect(result.shouldDisconnect, isTrue);
      expect(result.returnDivergencePct, closeTo(8.0, 0.01));
      expect(
          result.tripReason, contains('Follower return lagged leader by 8.0%'));
    });

    test('tripGuardian and resetGuardian should mutate settings state properly',
        () {
      final settings = CopyTradeSettings(
        enabled: true,
        autoDisconnectOnDivergence: true,
      );

      expect(settings.enabled, isTrue);
      expect(settings.isRiskGuardianTripped, isFalse);

      CopyTradeRiskGuardianService.tripGuardian(
        settings,
        'Leader drawdown exceeded 15%',
      );

      expect(settings.enabled, isFalse);
      expect(settings.isRiskGuardianTripped, isTrue);
      expect(settings.riskGuardianTripReason, 'Leader drawdown exceeded 15%');
      expect(settings.riskGuardianTrippedAt, isNotNull);

      CopyTradeRiskGuardianService.resetGuardian(settings);

      expect(settings.isRiskGuardianTripped, isFalse);
      expect(settings.riskGuardianTripReason, isNull);
      expect(settings.riskGuardianTrippedAt, isNull);
    });
  });

  group('CopyTradeRiskGuardianService - Inverse & Contract Adaptation', () {
    final now = DateTime(2026, 11, 13, 10, 0, 0);
    final exp = DateTime(2027, 1, 15);

    test('blocks naked short inverse option and suggests defined-risk long put',
        () {
      final record = CopyTradeRecord(
        id: 'inv-1',
        sourceUserId: 'leader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'option',
        originalOrderId: 'o1',
        symbol: 'AAPL',
        side: 'credit',
        originalQuantity: 1,
        copiedQuantity: 1,
        price: 3.0,
        timestamp: now,
        executed: false,
        isInverse: true,
        legs: [
          CopyTradeLeg(
            expirationDate: exp,
            strikePrice: 220,
            optionType: 'call',
            side: 'sell',
            positionEffect: 'open',
            ratioQuantity: 1,
          ),
        ],
      );

      final result =
          CopyTradeRiskGuardianService.evaluateInverseOptionGuardrail(
        record: record,
      );

      expect(result.isAllowed, isFalse);
      expect(result.hasNakedShortRisk, isTrue);
      expect(result.suggestedDefinedRiskRecord, isNotNull);
      expect(result.suggestedDefinedRiskRecord!.side, 'debit');
      expect(result.suggestedDefinedRiskRecord!.legs!.first.side, 'buy');
      expect(result.suggestedDefinedRiskRecord!.legs!.first.optionType, 'put');
    });

    test('allows defined-risk spread in inverse mode', () {
      final record = CopyTradeRecord(
        id: 'inv-2',
        sourceUserId: 'leader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'option',
        originalOrderId: 'o2',
        symbol: 'AAPL',
        side: 'credit',
        originalQuantity: 1,
        copiedQuantity: 1,
        price: 1.5,
        timestamp: now,
        executed: false,
        isInverse: true,
        legs: [
          CopyTradeLeg(
            expirationDate: exp,
            strikePrice: 220,
            optionType: 'call',
            side: 'sell',
            positionEffect: 'open',
            ratioQuantity: 1,
          ),
          CopyTradeLeg(
            expirationDate: exp,
            strikePrice: 230,
            optionType: 'call',
            side: 'buy',
            positionEffect: 'open',
            ratioQuantity: 1,
          ),
        ],
      );

      final result =
          CopyTradeRiskGuardianService.evaluateInverseOptionGuardrail(
        record: record,
      );

      expect(result.isAllowed, isTrue);
      expect(result.hasNakedShortRisk, isFalse);
    });

    test(
        'suggestOptionAdaptations finds cheaper OTM strike and vertical spread',
        () {
      OptionInstrument makeOpt(
          String id, double strike, double bid, double ask) {
        final opt = OptionInstrument(
          'chain1',
          'AAPL',
          now,
          exp,
          id,
          now,
          const MinTicks(0.05, 0.01, 3.0),
          'tradable',
          'active',
          strike,
          'tradable',
          'call',
          now,
          'https://api.robinhood.com/options/instruments/$id/',
          null,
          'long',
          'short',
        );
        opt.optionMarketData = OptionMarketData(
          (bid + ask) / 2,
          ask,
          10,
          bid,
          10,
          strike + ask,
          ask,
          opt.url,
          id,
          ask,
          1,
          bid,
          (bid + ask) / 2,
          500,
          null,
          null,
          100,
          'AAPL',
          'AAPL',
          0.3,
          0.7,
          0.35,
          0.02,
          0.25,
          0.01,
          -0.05,
          0.1,
          ask,
          bid,
          ask,
          bid,
          now,
        );
        return opt;
      }

      final chain = [
        makeOpt('opt-220', 220, 4.80, 5.00), // $500 (over $250 cap)
        makeOpt('opt-230', 230, 1.80, 2.00), // $200 (fits $250 cap)
        makeOpt('opt-235', 235, 0.90, 1.00), // $100
      ];

      final record = CopyTradeRecord(
        id: 'adapt-1',
        sourceUserId: 'leader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'option',
        originalOrderId: 'o3',
        symbol: 'AAPL',
        side: 'debit',
        originalQuantity: 1,
        copiedQuantity: 0,
        price: 5.0,
        timestamp: now,
        executed: false,
        needsContractAdaptation: true,
        legs: [
          CopyTradeLeg(
            expirationDate: exp,
            strikePrice: 220,
            optionType: 'call',
            side: 'buy',
            positionEffect: 'open',
            ratioQuantity: 1,
          ),
        ],
      );

      final suggestions = CopyTradeRiskGuardianService.suggestOptionAdaptations(
        record: record,
        maxAllocationAmount: 250.0,
        chain: chain,
      );

      expect(suggestions.length, 2);
      expect(suggestions.first.adaptationType, 'otm_strike');
      expect(suggestions.first.estimatedTotalCost, lessThanOrEqualTo(250.0));
      expect(suggestions.last.adaptationType, 'vertical_spread');
      expect(suggestions.last.legs.length, 2);
      expect(suggestions.last.estimatedTotalCost, lessThanOrEqualTo(250.0));
    });
  });
}

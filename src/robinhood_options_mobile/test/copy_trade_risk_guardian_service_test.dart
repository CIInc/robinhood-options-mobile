import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/services/copy_trade_risk_guardian_service.dart';

void main() {
  group('CopyTradeRiskGuardianService - Allocation Guardrail Tests', () {
    final now = DateTime(2026, 9, 23, 10, 0, 0);

    test('should allow full trade when no allocation limits are configured', () {
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

    test('should clamp quantity based on maxAllocationPct of account equity', () {
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

    test('should abort option trade if allocation cap is less than 1 contract', () {
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

    test('should allow buy order when current price equals leader price (zero slippage)', () {
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

    test('should allow buy order with favorable slippage (cheaper market price)', () {
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

    test('should allow buy order with unfavorable slippage below threshold', () {
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

    test('should abort buy order when unfavorable slippage exceeds maxSlippageBps', () {
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

    test('should abort sell order when market price drops significantly below leader exit', () {
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

  group('CopyTradeRiskGuardianService - Auto-Disconnect & Divergence Tests', () {
    final now = DateTime(2026, 9, 23, 10, 0, 0);

    test('should not disconnect when autoDisconnectOnDivergence is disabled', () {
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

    test('should trigger auto-disconnect when leader drawdown exceeds limit', () {
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

    test('should trigger auto-disconnect when follower return underperforms leader by more than divergence limit', () {
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
      expect(result.tripReason, contains('Follower return lagged leader by 8.0%'));
    });

    test('tripGuardian and resetGuardian should mutate settings state properly', () {
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
}

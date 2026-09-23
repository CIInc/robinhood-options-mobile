import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';

void main() {
  group('CopyTradeSettings - Risk Guardian Serialization Tests', () {
    test('should serialize and deserialize Risk Guardian fields correctly', () {
      final trippedDate = DateTime(2026, 9, 23, 14, 30, 0);
      final settings = CopyTradeSettings(
        enabled: false,
        targetUserId: 'leader_123',
        autoExecute: true,
        maxAllocationPerTrade: 1500.0,
        maxAllocationPct: 5.0,
        maxSlippageBps: 60.0,
        autoDisconnectOnDivergence: true,
        maxLeaderDrawdownPct: 12.5,
        maxReturnDivergencePct: 4.0,
        isRiskGuardianTripped: true,
        riskGuardianTripReason: 'Leader drawdown reached 13.0%',
        riskGuardianTrippedAt: trippedDate,
      );

      final json = settings.toJson();

      expect(json['maxAllocationPerTrade'], 1500.0);
      expect(json['maxAllocationPct'], 5.0);
      expect(json['maxSlippageBps'], 60.0);
      expect(json['autoDisconnectOnDivergence'], isTrue);
      expect(json['maxLeaderDrawdownPct'], 12.5);
      expect(json['maxReturnDivergencePct'], 4.0);
      expect(json['isRiskGuardianTripped'], isTrue);
      expect(json['riskGuardianTripReason'], 'Leader drawdown reached 13.0%');
      expect(json['riskGuardianTrippedAt'], trippedDate.toIso8601String());

      final restored = CopyTradeSettings.fromJson(json);

      expect(restored.maxAllocationPerTrade, 1500.0);
      expect(restored.maxAllocationPct, 5.0);
      expect(restored.maxSlippageBps, 60.0);
      expect(restored.autoDisconnectOnDivergence, isTrue);
      expect(restored.maxLeaderDrawdownPct, 12.5);
      expect(restored.maxReturnDivergencePct, 4.0);
      expect(restored.isRiskGuardianTripped, isTrue);
      expect(restored.riskGuardianTripReason, 'Leader drawdown reached 13.0%');
      expect(restored.riskGuardianTrippedAt, isNotNull);
      expect(restored.riskGuardianTrippedAt?.year, 2026);
    });

    test('should apply default values when Risk Guardian fields are omitted in JSON', () {
      final json = <String, Object?>{
        'enabled': true,
        'autoExecute': false,
      };

      final settings = CopyTradeSettings.fromJson(json);

      expect(settings.maxAllocationPerTrade, isNull);
      expect(settings.maxAllocationPct, isNull);
      expect(settings.maxSlippageBps, 75.0); // Default 75 bps
      expect(settings.autoDisconnectOnDivergence, isFalse);
      expect(settings.maxLeaderDrawdownPct, isNull);
      expect(settings.maxReturnDivergencePct, isNull);
      expect(settings.isRiskGuardianTripped, isFalse);
      expect(settings.riskGuardianTripReason, isNull);
      expect(settings.riskGuardianTrippedAt, isNull);
    });
  });

  group('CopyTradeRecord - Abort Getters & Execution Results Tests', () {
    final now = DateTime(2026, 9, 23, 10, 0, 0);

    test('should identify aborted slippage trades', () {
      final record = CopyTradeRecord(
        id: 'ab1',
        sourceUserId: 'trader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'instrument',
        originalOrderId: 'o1',
        symbol: 'NVDA',
        side: 'buy',
        originalQuantity: 10,
        copiedQuantity: 10,
        price: 120.0,
        timestamp: now,
        executed: false,
        status: 'aborted',
        executionResult: 'aborted_max_slippage',
        error: 'Slippage of 120 bps exceeded threshold of 75 bps',
      );

      expect(record.isAborted, isTrue);
      expect(record.isAbortedMaxSlippage, isTrue);
      expect(record.isAbortedAllocation, isFalse);
      expect(record.isAbortedRiskGuardian, isFalse);
    });

    test('should identify aborted capital allocation trades', () {
      final record = CopyTradeRecord(
        id: 'ab2',
        sourceUserId: 'trader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'option',
        originalOrderId: 'o2',
        symbol: 'SPY',
        side: 'buy',
        originalQuantity: 5,
        copiedQuantity: 5,
        price: 8.0,
        timestamp: now,
        executed: false,
        status: 'aborted',
        executionResult: 'aborted_allocation_limit',
        error: 'Option capital required exceeds max allocation cap',
      );

      expect(record.isAborted, isTrue);
      expect(record.isAbortedAllocation, isTrue);
      expect(record.isAbortedMaxSlippage, isFalse);
      expect(record.isAbortedRiskGuardian, isFalse);
    });

    test('should identify aborted circuit breaker tripped trades', () {
      final record = CopyTradeRecord(
        id: 'ab3',
        sourceUserId: 'trader1',
        targetUserId: 'follower1',
        groupId: 'grp1',
        orderType: 'instrument',
        originalOrderId: 'o3',
        symbol: 'AAPL',
        side: 'buy',
        originalQuantity: 10,
        copiedQuantity: 10,
        price: 150.0,
        timestamp: now,
        executed: false,
        status: 'aborted',
        executionResult: 'aborted_risk_guardian_tripped',
        error: 'Risk Guardian triggered auto-disconnect: Leader drawdown 20%',
      );

      expect(record.isAborted, isTrue);
      expect(record.isAbortedRiskGuardian, isTrue);
      expect(record.isAbortedMaxSlippage, isFalse);
      expect(record.isAbortedAllocation, isFalse);
    });
  });
}

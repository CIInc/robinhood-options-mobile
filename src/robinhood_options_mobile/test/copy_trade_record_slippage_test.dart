import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';

void main() {
  group('CopyTradeRecord Slippage & Latency Tests', () {
    final now = DateTime(2026, 9, 22, 10, 0, 0);

    test('should construct with all slippage and latency fields', () {
      final executedTime = now.add(const Duration(milliseconds: 145));
      final record = CopyTradeRecord(
        id: 'trade-1',
        sourceUserId: 'leader-123',
        targetUserId: 'follower-456',
        groupId: 'group-789',
        orderType: 'instrument',
        originalOrderId: 'orig-1',
        symbol: 'NVDA',
        side: 'buy',
        originalQuantity: 10,
        copiedQuantity: 5,
        price: 120.0,
        timestamp: now,
        executed: true,
        executionTime: executedTime,
        executedPrice: 120.05,
        fillLatencyMs: 145,
        priceSlippage: 0.05,
        slippageBps: 4.17,
        leaderReturnPct: 0.10,
        followerReturnPct: 0.095,
        returnDivergencePct: -0.005,
      );

      expect(record.id, 'trade-1');
      expect(record.effectiveExecutedPrice, 120.05);
      expect(record.effectiveFillLatencyMs, 145);
      expect(record.dollarSlippage, closeTo(0.05, 0.001));
      expect(record.effectiveSlippageBps, closeTo(4.17, 0.01));
      expect(record.isUnfavorableSlippage, true);
      expect(record.isFavorableSlippage, false);
      expect(record.isZeroSlippage, false);
      expect(record.effectiveReturnDivergencePct, closeTo(-0.005, 0.0001));
    });

    test('should serialize to JSON and deserialize accurately', () {
      final executedTime = now.add(const Duration(milliseconds: 88));
      final record = CopyTradeRecord(
        id: 'trade-2',
        sourceUserId: 'trader-1',
        targetUserId: 'trader-2',
        groupId: 'grp-1',
        orderType: 'instrument',
        originalOrderId: 'o-2',
        symbol: 'AAPL',
        side: 'sell',
        originalQuantity: 50,
        copiedQuantity: 25,
        price: 230.0,
        timestamp: now,
        executed: true,
        executionTime: executedTime,
        executedPrice: 230.10,
        fillLatencyMs: 88,
        priceSlippage: -0.10, // favorable for sell!
        slippageBps: -4.35,
      );

      final json = record.toJson();
      expect(json['executedPrice'], 230.10);
      expect(json['fillLatencyMs'], 88);
      expect(json['priceSlippage'], -0.10);
      expect(json['slippageBps'], -4.35);

      final deserialized = CopyTradeRecord.fromJson(json, 'trade-2');
      expect(deserialized.id, 'trade-2');
      expect(deserialized.effectiveExecutedPrice, 230.10);
      expect(deserialized.effectiveFillLatencyMs, 88);
      expect(deserialized.isFavorableSlippage, true);
      expect(deserialized.isUnfavorableSlippage, false);
    });

    test('should calculate buy order slippage correctly when not explicitly precomputed', () {
      final record = CopyTradeRecord(
        id: 'trade-buy',
        sourceUserId: 'l1',
        targetUserId: 'f1',
        groupId: 'g1',
        orderType: 'instrument',
        originalOrderId: 'o-3',
        symbol: 'TSLA',
        side: 'buy',
        originalQuantity: 20,
        copiedQuantity: 10,
        price: 250.0,
        timestamp: now,
        executed: true,
        executionTime: now.add(const Duration(milliseconds: 210)),
        executedPrice: 250.50, // paid $0.50 more on buy
      );

      expect(record.dollarSlippage, closeTo(0.50, 0.0001));
      expect(record.effectiveSlippageBps, closeTo((0.50 / 250.0) * 10000, 0.01));
      expect(record.effectiveFillLatencyMs, 210);
      expect(record.isUnfavorableSlippage, true);
    });

    test('should calculate sell order slippage correctly when not explicitly precomputed', () {
      final recordFavorable = CopyTradeRecord(
        id: 'trade-sell-fav',
        sourceUserId: 'l1',
        targetUserId: 'f1',
        groupId: 'g1',
        orderType: 'instrument',
        originalOrderId: 'o-4',
        symbol: 'MSFT',
        side: 'sell',
        originalQuantity: 15,
        copiedQuantity: 15,
        price: 400.0,
        timestamp: now,
        executed: true,
        executionTime: now.add(const Duration(milliseconds: 95)),
        executedPrice: 400.80, // sold for $0.80 more than leader! Favorable
      );

      expect(recordFavorable.dollarSlippage, closeTo(-0.80, 0.0001));
      expect(recordFavorable.effectiveSlippageBps, closeTo((-0.80 / 400.0) * 10000, 0.01));
      expect(recordFavorable.isFavorableSlippage, true);
      expect(recordFavorable.isUnfavorableSlippage, false);

      final recordUnfavorable = CopyTradeRecord(
        id: 'trade-sell-unfav',
        sourceUserId: 'l1',
        targetUserId: 'f1',
        groupId: 'g1',
        orderType: 'instrument',
        originalOrderId: 'o-5',
        symbol: 'MSFT',
        side: 'sell',
        originalQuantity: 15,
        copiedQuantity: 15,
        price: 400.0,
        timestamp: now,
        executed: true,
        executionTime: now.add(const Duration(milliseconds: 320)),
        executedPrice: 399.50, // sold for $0.50 less than leader
      );

      expect(recordUnfavorable.dollarSlippage, closeTo(0.50, 0.0001));
      expect(recordUnfavorable.isUnfavorableSlippage, true);
      expect(recordUnfavorable.isFavorableSlippage, false);
    });

    test('should maintain backward compatibility for historical records without new fields', () {
      final legacyJson = {
        'sourceUserId': 'leader-old',
        'targetUserId': 'follower-old',
        'groupId': 'group-old',
        'orderType': 'instrument',
        'originalOrderId': 'order-old',
        'symbol': 'AMZN',
        'side': 'buy',
        'originalQuantity': 100,
        'copiedQuantity': 10,
        'price': 180.0,
        'timestamp': Timestamp.fromDate(now),
        'executed': true,
      };

      final record = CopyTradeRecord.fromJson(legacyJson, 'legacy-1');
      expect(record.effectiveExecutedPrice, 180.0);
      expect(record.effectiveFillLatencyMs, isNull);
      expect(record.dollarSlippage, 0.0);
      expect(record.effectiveSlippageBps, 0.0);
      expect(record.isZeroSlippage, true);
      expect(record.effectiveReturnDivergencePct, isNull);
    });
  });
}

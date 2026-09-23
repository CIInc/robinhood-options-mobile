import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_slippage_card.dart';

void main() {
  group('CopyTradeSlippageCard Widget Tests', () {
    final now = DateTime(2026, 9, 22, 10, 0, 0);

    testWidgets('renders empty state when no executed trades',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CopyTradeSlippageCard(trades: []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Slippage & Latency Analytics'), findsOneWidget);
      expect(find.textContaining('No executed copy trades yet'), findsOneWidget);
    });

    testWidgets('renders full slippage and divergence analytics when trades exist',
        (WidgetTester tester) async {
      final trades = [
        CopyTradeRecord(
          id: 'trade-audit-1',
          sourceUserId: 'trader-alpha-12345',
          targetUserId: 'user-me',
          groupId: 'grp-test',
          orderType: 'instrument',
          originalOrderId: 'o1',
          symbol: 'AAPL',
          side: 'buy',
          originalQuantity: 10,
          copiedQuantity: 10,
          price: 150.0,
          timestamp: now,
          executed: true,
          executionTime: now.add(const Duration(milliseconds: 120)),
          executedPrice: 150.05,
          fillLatencyMs: 120,
          priceSlippage: 0.05,
          slippageBps: 3.33,
          leaderReturnPct: 0.04,
          followerReturnPct: 0.038,
          returnDivergencePct: -0.002,
        ),
        CopyTradeRecord(
          id: 'trade-audit-2',
          sourceUserId: 'trader-beta-67890',
          targetUserId: 'user-me',
          groupId: 'grp-test',
          orderType: 'instrument',
          originalOrderId: 'o2',
          symbol: 'MSFT',
          side: 'sell',
          originalQuantity: 5,
          copiedQuantity: 5,
          price: 300.0,
          timestamp: now,
          executed: true,
          executionTime: now.add(const Duration(milliseconds: 85)),
          executedPrice: 300.10, // favorable sell
          fillLatencyMs: 85,
          priceSlippage: -0.10,
          slippageBps: -3.33,
          leaderReturnPct: 0.06,
          followerReturnPct: 0.063,
          returnDivergencePct: 0.003,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CopyTradeSlippageCard(trades: trades),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title & Hero metrics
      expect(find.text('Slippage & Divergence Audit'), findsOneWidget);
      expect(find.text('Avg Latency'), findsOneWidget);
      expect(find.text('Avg Slippage'), findsOneWidget);
      expect(find.text('Slippage Drag'), findsOneWidget);
      expect(find.text('Fill Quality'), findsOneWidget);

      // Value verification
      // Avg latency: (120 + 85) / 2 = 103 ms (rounded)
      expect(find.text('103 ms'), findsOneWidget);
      // Net return divergence banner
      expect(find.text('Net Return Divergence vs Leader:'), findsOneWidget);
      // Distribution sections
      expect(find.text('Fill Quality Distribution'), findsOneWidget);
      expect(find.text('Latency Breakdown'), findsOneWidget);
      expect(find.text('Slippage by Leader'), findsOneWidget);
    });
  });
}

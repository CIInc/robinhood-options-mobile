import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/widgets/copy_trade_slippage_card.dart';

void main() {
  final now = DateTime(2026, 9, 22, 10, 0, 0);

  testWidgets(
      'CopyTradeSlippageCard renders empty state when no executed trades',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CopyTradeSlippageCard(trades: []),
        ),
      ),
    );

    expect(find.text('Slippage & Latency Analytics'), findsOneWidget);
    expect(
      find.textContaining('No executed copy trades yet.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'CopyTradeSlippageCard renders metric tiles, return divergence, and leader rows with unified semantics',
      (WidgetTester tester) async {
    final trades = [
      CopyTradeRecord(
        id: 't1',
        sourceUserId: 'trader-alice-12345',
        targetUserId: 'user-me',
        groupId: 'grp-1',
        orderType: 'instrument',
        originalOrderId: 'o1',
        symbol: 'AAPL',
        side: 'buy',
        originalQuantity: 10,
        copiedQuantity: 10,
        price: 100.0,
        timestamp: now,
        executed: true,
        executionTime: now.add(const Duration(milliseconds: 50)),
        executedPrice: 99.90,
        fillLatencyMs: 50,
        leaderReturnPct: 0.05,
        followerReturnPct: 0.052,
      ),
      CopyTradeRecord(
        id: 't2',
        sourceUserId: 'trader-bob-67890',
        targetUserId: 'user-me',
        groupId: 'grp-1',
        orderType: 'instrument',
        originalOrderId: 'o2',
        symbol: 'MSFT',
        side: 'buy',
        originalQuantity: 5,
        copiedQuantity: 5,
        price: 200.0,
        timestamp: now,
        executed: true,
        executionTime: now.add(const Duration(milliseconds: 150)),
        executedPrice: 201.00,
        fillLatencyMs: 150,
        leaderReturnPct: 0.08,
        followerReturnPct: 0.075,
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

    expect(find.text('Slippage & Divergence Audit'), findsOneWidget);

    // Verify Metric Tile Semantics
    final avgLatencyFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label != null &&
          widget.properties.label!
              .contains('Avg Latency: 100 ms. Median: 100ms'),
    );
    expect(avgLatencyFinder, findsOneWidget);

    final fillQualityFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label != null &&
          widget.properties.label!
              .contains('Fill Quality: 50.0%. 1/2 on-target'),
    );
    expect(fillQualityFinder, findsOneWidget);

    // Verify Net Return Divergence Banner Semantics
    final returnDivergenceFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label != null &&
          widget.properties.label!.contains('Net Return Divergence vs Leader:'),
    );
    expect(returnDivergenceFinder, findsOneWidget);

    // Verify Leader Comparison Row Semantics
    final traderRowFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label != null &&
          widget.properties.label!.contains(
              'Trader trader-a, 1 trades: average latency 50 milliseconds'),
    );
    expect(traderRowFinder, findsOneWidget);
  });
}

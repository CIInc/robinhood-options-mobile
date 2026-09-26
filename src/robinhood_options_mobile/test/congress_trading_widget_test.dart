import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/congress_trade.dart';
import 'package:robinhood_options_mobile/widgets/congress_trading_widget.dart';
import 'package:robinhood_options_mobile/widgets/congress_trading_dashboard_widget.dart';

void main() {
  final sampleTrade = CongressTrade(
    id: 'test-trade-1',
    politicianName: 'Nancy Pelosi',
    chamber: CongressChamber.house,
    party: CongressParty.democrat,
    state: 'CA',
    district: 'CA-11',
    symbol: 'NVDA',
    assetDescription: 'NVIDIA Corporation',
    transactionType: CongressTransactionType.purchase,
    amount: '\$1,000,001 - \$5,000,000',
    amountMin: 1000001,
    amountMax: 5000000,
    transactionDate: DateTime(2026, 6, 26),
    disclosureDate: DateTime(2026, 7, 2),
    owner: 'Spouse',
    sourceUrl: 'https://example.com/ptr.pdf',
    comment: 'Call options exercise',
    isOverdue: false,
    filingLagDays: 6,
  );

  testWidgets('renders CongressTradingWidget with trade and portfolio overlap banner',
      (WidgetTester tester) async {
    final snapshot = CongressTradingSnapshot(
      symbol: 'NVDA',
      trades: [sampleTrade],
      portfolioOverlap: true,
      overlappingSymbols: ['NVDA'],
      totalTrades: 1,
      totalPurchases: 1000001.0,
      totalSales: 0.0,
      netPurchases: 1000001.0,
      updatedAt: DateTime(2026, 9, 24),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CongressTradingWidget(
              symbol: 'NVDA',
              preloadedSnapshot: snapshot,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Congress Trading (STOCK Act)'), findsOneWidget);
    expect(
      find.textContaining('NVDA is held in your portfolio'),
      findsOneWidget,
    );
    expect(find.text('Rep. Nancy Pelosi'), findsOneWidget);
    expect(find.text('D-CA-11'), findsOneWidget);
    expect(find.text('Purchase'), findsOneWidget);
    expect(find.text('\$1,000,001 - \$5,000,000'), findsOneWidget);
    expect(find.text('6d lag'), findsOneWidget);
    expect(find.text('View PTR Filing'), findsOneWidget);
    expect(find.text('Explore All Political Trades'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders empty state when no disclosures exist for symbol',
      (WidgetTester tester) async {
    final snapshot = CongressTradingSnapshot(
      symbol: 'XYZ',
      trades: const [],
      portfolioOverlap: false,
      overlappingSymbols: const [],
      totalTrades: 0,
      totalPurchases: 0.0,
      totalSales: 0.0,
      netPurchases: 0.0,
      updatedAt: DateTime(2026, 9, 24),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CongressTradingWidget(
              symbol: 'XYZ',
              preloadedSnapshot: snapshot,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Congress Trading (STOCK Act)'), findsOneWidget);
    expect(
      find.text('No recent congressional stock disclosures found for XYZ.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders CongressTradingDashboardWidget with search and filter controls',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CongressTradingDashboardWidget(
          userPortfolioSymbols: ['NVDA', 'AAPL'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Congress Trading Tracker'), findsOneWidget);
    expect(find.text('My Portfolio Overlap'), findsOneWidget);
    expect(find.text('Tracked'), findsOneWidget);
    expect(find.text('Buy Vol (Est)'), findsOneWidget);
    expect(find.text('Held Overlap'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('Showing '), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

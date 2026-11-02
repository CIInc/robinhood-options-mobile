import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/widgets/income_transactions_widget.dart';

void main() {
  testWidgets('IncomeTransactionTile provides unified semantics for dividend',
      (WidgetTester tester) async {
    final instrument = Instrument(
      id: 'inst_1',
      url: '',
      quote: '',
      fundamentals: '',
      splits: '',
      state: '',
      market: '',
      name: 'Apple Inc.',
      tradeable: true,
      tradability: '',
      symbol: 'AAPL',
      bloombergUnique: '',
      country: '',
      type: 'stock',
      rhsTradability: '',
      fractionalTradability: '',
      isSpac: false,
      isTest: false,
      ipoAccessSupportsDsp: false,
      dateCreated: DateTime(2020, 1, 1),
    );

    final transaction = {
      'instrumentObj': instrument,
      'amount': '15.50',
      'payable_date': '2026-10-15T00:00:00Z',
      'rate': '0.25',
      'position': '62.0000',
      'state': 'paid',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IncomeTransactionTile(
            transaction: transaction,
          ),
        ),
      ),
    );

    final date = DateTime.parse('2026-10-15T00:00:00Z');
    final expectedDateStr = formatDate.format(date);
    final expectedLabel =
        'AAPL dividend, \$15.50, paid. \$0.25 per share, 62 shares on $expectedDateStr';

    final semanticsFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == expectedLabel &&
          widget.container == true,
    );

    expect(semanticsFinder, findsOneWidget);
  });

  testWidgets(
      'IncomeTransactionTile provides unified semantics for non-dividend income',
      (WidgetTester tester) async {
    final transaction = {
      'payout_type': 'interest',
      'amount': {'amount': '3.42'},
      'pay_date': '2026-10-20T00:00:00Z',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IncomeTransactionTile(
            transaction: transaction,
          ),
        ),
      ),
    );

    final date = DateTime.parse('2026-10-20T00:00:00Z');
    final expectedDateStr = formatDate.format(date);
    final expectedLabel = 'Interest, \$3.42 on $expectedDateStr';

    final semanticsFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label == expectedLabel &&
          widget.container == true,
    );

    expect(semanticsFinder, findsOneWidget);
  });
}

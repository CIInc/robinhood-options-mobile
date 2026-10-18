import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/sec_disclosure.dart';
import 'package:robinhood_options_mobile/widgets/sec_disclosures_widget.dart';

void main() {
  test('parses a callable SEC disclosure response', () {
    final snapshot = SecDisclosureSnapshot.fromJson({
      'symbol': 'AAPL',
      'portfolioOverlap': true,
      'updatedAt': '2026-09-24T00:00:00.000Z',
      'disclosures': [
        {
          'accessionNumber': '0000000000-26-000001',
          'form': '13F-HR',
          'filedAt': '2026-09-23',
          'companyName': 'Apple Inc.',
          'title': 'Example Fund - 13F',
          'summary': 'Institutional holding reported',
          'url': 'https://www.sec.gov/example',
          'symbols': ['AAPL'],
          'holdings': [
            {
              'issuerName': 'Apple Inc.',
              'shares': 1000,
              'valueThousands': 250,
            },
          ],
        },
      ],
    });

    expect(snapshot.portfolioOverlap, isTrue);
    expect(snapshot.disclosures.single.form, '13F-HR');
    expect(snapshot.disclosures.single.holdings.single.shares, 1000);
  });

  testWidgets('shows portfolio overlap and parsed filing details', (
    WidgetTester tester,
  ) async {
    final snapshot = SecDisclosureSnapshot(
      symbol: 'AAPL',
      portfolioOverlap: true,
      updatedAt: DateTime.utc(2026, 9, 24),
      disclosures: [
        SecDisclosure(
          accessionNumber: '0000000000-26-000001',
          form: '4',
          filedAt: DateTime.utc(2026, 9, 23),
          companyName: 'Apple Inc.',
          title: 'Jane Doe — Form 4',
          summary: '2 open-market insider purchases reported',
          url: 'https://www.sec.gov/example',
          symbols: const ['AAPL'],
          transactionCount: 2,
          openMarketBuyCount: 2,
          insiderClusterCount: 2,
        ),
        SecDisclosure(
          accessionNumber: '0000000000-26-000002',
          form: '8-K',
          filedAt: DateTime.utc(2026, 9, 22),
          companyName: 'Apple Inc.',
          title: 'Apple Inc. — Form 8-K',
          summary: 'Material event disclosure: Items 5.02',
          url: 'https://www.sec.gov/example-8k',
          symbols: const ['AAPL'],
          itemCodes: const ['5.02'],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SecDisclosuresWidget(
              symbol: 'AAPL',
              preloadedSnapshot: snapshot,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SEC EDGAR Filings'), findsOneWidget);
    expect(
      find.textContaining('AAPL is held in your portfolio'),
      findsOneWidget,
    );
    expect(find.textContaining('Insider buy cluster: 2'), findsOneWidget);
    expect(find.text('8-K items: 5.02'), findsOneWidget);
    expect(find.text('Open filing'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/sec_disclosure.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';
import 'package:robinhood_options_mobile/widgets/sec_disclosures_widget.dart';

InstrumentPosition _mockPosition(String symbol, double shares) {
  final pos = InstrumentPosition(
    'https://api.robinhood.com/positions/$symbol/',
    'https://api.robinhood.com/instruments/$symbol/',
    'https://api.robinhood.com/accounts/123/',
    '123',
    100.0,
    0,
    shares,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    false,
    DateTime.utc(2026, 9, 24),
    DateTime.utc(2026, 1, 1),
  );
  pos.instrumentObj = Instrument(
    id: symbol,
    url: 'https://api.robinhood.com/instruments/$symbol/',
    quote: 'https://api.robinhood.com/quotes/$symbol/',
    fundamentals: 'https://api.robinhood.com/fundamentals/$symbol/',
    splits: 'https://api.robinhood.com/splits/$symbol/',
    state: 'active',
    market: 'https://api.robinhood.com/markets/XNAS/',
    name: '$symbol Inc.',
    tradeable: true,
    tradability: 'tradable',
    symbol: symbol,
    bloombergUnique: symbol,
    country: 'US',
    type: 'stock',
    rhsTradability: 'tradable',
    fractionalTradability: 'tradable',
    isSpac: false,
    isTest: false,
    ipoAccessSupportsDsp: false,
    dateCreated: DateTime.utc(2025, 1, 1),
  );
  return pos;
}

void main() {
  test('parses a callable SEC disclosure response with financials and brief',
      () {
    final snapshot = SecDisclosureSnapshot.fromJson({
      'symbol': 'AAPL',
      'portfolioOverlap': true,
      'updatedAt': '2026-09-24T00:00:00.000Z',
      'financials': {
        'fiscalYear': 2026,
        'fiscalPeriod': 'FY',
        'form': '10-K',
        'revenue': 400000000000,
        'revenueGrowthYoY': 14.3,
        'netIncome': 100000000000,
        'netMargin': 25.0,
        'dilutedEps': 6.5,
        'operatingCashFlow': 115000000000,
        'cashAndEquivalents': 65000000000,
        'debtToEquity': 1.5,
      },
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
    expect(snapshot.financials?.revenue, 400000000000);
    expect(snapshot.financials?.revenueGrowthYoY, 14.3);
    expect(snapshot.financials?.periodLabel, 'FY 2026 (10-K)');
    expect(snapshot.disclosures.single.form, '13F-HR');
    expect(snapshot.disclosures.single.holdings.single.shares, 1000);
  });

  testWidgets(
      'shows portfolio overlap, 10-K/Q financials, research assistant, and filings',
      (
    WidgetTester tester,
  ) async {
    final snapshot = SecDisclosureSnapshot(
      symbol: 'AAPL',
      portfolioOverlap: true,
      updatedAt: DateTime.utc(2026, 9, 24),
      financials: const SecFinancialStatementSnapshot(
        fiscalYear: 2026,
        fiscalPeriod: 'FY',
        form: '10-K',
        revenue: 400000000000,
        revenueGrowthYoY: 14.3,
        netIncome: 100000000000,
        netMargin: 25.0,
        dilutedEps: 6.5,
      ),
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
          itemDescriptions: const [
            '5.02: Departure or Election of Directors or Principal Officers',
          ],
          materialEventSeverity: 'warning',
        ),
        SecDisclosure(
          accessionNumber: '0000000000-26-000003',
          form: '10-K',
          filedAt: DateTime.utc(2026, 9, 20),
          companyName: 'Apple Inc.',
          title: 'Apple Inc. — Form 10-K',
          summary: 'Annual report for period ended September 26, 2026',
          url: 'https://www.sec.gov/example-10k',
          symbols: const ['AAPL'],
          riskHighlights: const ['Supply chain, tariff, or geopolitical exposure noted'],
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
    expect(find.text('10-K / 10-Q Financial Statements'), findsOneWidget);
    expect(find.text('EDGAR Filing Research Assistant'), findsOneWidget);
    expect(find.textContaining('Insider buy cluster: 2'), findsOneWidget);
    expect(find.text('8-K items: 5.02'), findsOneWidget);
    expect(find.text('Open filing'), findsNWidgets(3));

    // Tap quick question chip in the research assistant
    await tester.tap(find.text('10-K/10-Q Financials'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('10-K/10-Q Financial Analysis for AAPL'),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });

  test('builds Action Center alerts and evaluates SmartAlertRules for SEC filings',
      () {
    final now = DateTime.utc(2026, 9, 25);
    final disclosures = [
      SecDisclosure(
        accessionNumber: '0001-8k',
        form: '8-K',
        filedAt: DateTime.utc(2026, 9, 23),
        companyName: 'Apple Inc.',
        title: 'Apple Inc. — Form 8-K',
        summary: 'Material event disclosure: Items 4.02',
        url: 'https://www.sec.gov/8k',
        symbols: const ['AAPL'],
        itemCodes: const ['4.02'],
        itemDescriptions: const [
          '4.02: Non-Reliance on Previously Issued Financial Statements',
        ],
        materialEventSeverity: 'critical',
      ),
      SecDisclosure(
        accessionNumber: '0002-form4-buy',
        form: '4',
        filedAt: DateTime.utc(2026, 9, 22),
        companyName: 'Apple Inc.',
        title: 'Jane Doe — Form 4',
        summary: '2 open-market insider purchases reported',
        url: 'https://www.sec.gov/form4',
        symbols: const ['AAPL'],
        openMarketBuyCount: 2,
        insiderClusterCount: 3,
        netTransactionValue: 250000,
      ),
      SecDisclosure(
        accessionNumber: '0003-form4-sell',
        form: '4',
        filedAt: DateTime.utc(2026, 9, 21),
        companyName: 'Apple Inc.',
        title: 'John Smith — Form 4',
        summary: '2 open-market insider sales reported',
        url: 'https://www.sec.gov/form4-sell',
        symbols: const ['AAPL'],
        openMarketSellCount: 2,
        insiderSellClusterCount: 2,
        netTransactionValue: -400000,
      ),
      SecDisclosure(
        accessionNumber: '0004-10k',
        form: '10-K',
        filedAt: DateTime.utc(2026, 9, 20),
        companyName: 'Apple Inc.',
        title: 'Apple Inc. — Form 10-K',
        summary: 'Annual report filed with SEC',
        url: 'https://www.sec.gov/10k',
        symbols: const ['AAPL'],
      ),
    ];

    final alerts = PortfolioAlertService.buildAlerts(
      instrumentPositions: [_mockPosition('AAPL', 10)],
      optionPositions: const [],
      secDisclosures: disclosures,
      now: now,
    );

    final secAlerts =
        alerts.where((a) => a.category == 'SEC Filings').toList();
    expect(secAlerts.length, 4);
    expect(
      secAlerts.any((a) =>
          a.id == 'sec-8k-AAPL-0001-8k' &&
          a.severity == PortfolioAlertSeverity.critical),
      isTrue,
    );
    expect(
      secAlerts.any((a) =>
          a.id == 'sec-form4-buy-AAPL-0002-form4-buy' &&
          a.severity == PortfolioAlertSeverity.positive),
      isTrue,
    );
    expect(
      secAlerts.any((a) =>
          a.id == 'sec-form4-sell-AAPL-0003-form4-sell' &&
          a.severity == PortfolioAlertSeverity.warning),
      isTrue,
    );
    expect(
      secAlerts.any((a) => a.id == 'sec-periodic-AAPL-0004-10k'),
      isTrue,
    );

    expect(
      PortfolioAlertService.evaluateSecDisclosureAlert(
        rule: const SmartAlertRule(
          type: AlertType.sec_filing,
          condition: AlertCondition.sec_8k_material_event,
          value: 0,
        ),
        disclosure: disclosures[0],
      ),
      isTrue,
    );
    expect(
      PortfolioAlertService.evaluateSecDisclosureAlert(
        rule: const SmartAlertRule(
          type: AlertType.sec_filing,
          condition: AlertCondition.sec_form4_insider_buy,
          value: 2,
        ),
        disclosure: disclosures[1],
      ),
      isTrue,
    );
    expect(
      PortfolioAlertService.evaluateSecDisclosureAlert(
        rule: const SmartAlertRule(
          type: AlertType.sec_filing,
          condition: AlertCondition.sec_form4_insider_sell,
          value: 2,
        ),
        disclosure: disclosures[2],
      ),
      isTrue,
    );
    expect(
      PortfolioAlertService.evaluateSecDisclosureAlert(
        rule: const SmartAlertRule(
          type: AlertType.sec_filing,
          condition: AlertCondition.sec_10k_10q_filing,
          value: 0,
        ),
        disclosure: disclosures[3],
      ),
      isTrue,
    );
  });
}

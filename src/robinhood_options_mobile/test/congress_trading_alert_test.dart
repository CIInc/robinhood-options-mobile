import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/congress_trade.dart';
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';

InstrumentPosition _buildInstrumentPosition({
  required String symbol,
  required double quantity,
}) {
  final pos = InstrumentPosition(
    'https://example.com/positions/$symbol/',
    'https://example.com/instruments/$symbol/',
    'https://example.com/accounts/1AB23456/',
    '1AB23456',
    100.0,
    0,
    quantity,
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
    DateTime(2026, 1, 1),
    DateTime(2025, 1, 1),
  );

  pos.instrumentObj = Instrument(
    id: symbol,
    url: 'https://example.com/instruments/$symbol/',
    quote: '',
    fundamentals: '',
    splits: '',
    state: 'active',
    market: '',
    name: symbol,
    tradeable: true,
    tradability: 'tradable',
    symbol: symbol,
    bloombergUnique: '',
    country: 'US',
    type: 'stock',
    rhsTradability: 'tradable',
    fractionalTradability: 'tradable',
    isSpac: false,
    isTest: false,
    ipoAccessSupportsDsp: false,
    dateCreated: DateTime(2025, 1, 1),
  );

  return pos;
}

OptionAggregatePosition _buildOptionPosition({
  required String symbol,
  required double quantity,
}) {
  return OptionAggregatePosition(
    'opt_$symbol',
    'chain_$symbol',
    '1AB23456',
    symbol,
    'long_call',
    2.50,
    const [],
    quantity,
    null,
    null,
    'debit',
    'debit',
    100.0,
    DateTime(2026, 1, 1),
    DateTime(2026, 1, 1),
    'long_call',
  );
}

void main() {
  group('Congress Trading alerts in PortfolioAlertService', () {
    final pelosiBuyNvda = CongressTrade(
      id: 'pelosi-nvda',
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
      sourceUrl: 'https://example.com/ptr1.pdf',
      isOverdue: false,
      filingLagDays: 6,
    );

    final tubervilleSellCrwd = CongressTrade(
      id: 'tuberville-crwd',
      politicianName: 'Tommy Tuberville',
      chamber: CongressChamber.senate,
      party: CongressParty.republican,
      state: 'AL',
      symbol: 'CRWD',
      assetDescription: 'CrowdStrike Holdings',
      transactionType: CongressTransactionType.sale,
      amount: '\$100,001 - \$250,000',
      amountMin: 100001,
      amountMax: 250000,
      transactionDate: DateTime(2026, 7, 22),
      disclosureDate: DateTime(2026, 8, 10),
      owner: 'Joint',
      sourceUrl: 'https://example.com/ptr2.pdf',
      isOverdue: false,
      filingLagDays: 19,
    );

    final crenshawBuyAmzn = CongressTrade(
      id: 'crenshaw-amzn',
      politicianName: 'Dan Crenshaw',
      chamber: CongressChamber.house,
      party: CongressParty.republican,
      state: 'TX',
      district: 'TX-02',
      symbol: 'AMZN',
      assetDescription: 'Amazon.com Inc.',
      transactionType: CongressTransactionType.purchase,
      amount: '\$15,001 - \$50,000',
      amountMin: 15001,
      amountMax: 50000,
      transactionDate: DateTime(2026, 8, 11),
      disclosureDate: DateTime(2026, 8, 30),
      owner: 'Self',
      sourceUrl: 'https://example.com/ptr3.pdf',
      isOverdue: false,
      filingLagDays: 19,
    );

    test('generates portfolio alerts for overlapping stock and option holdings',
        () {
      final now = DateTime(2026, 9, 1);

      // User holds NVDA (stock) and CRWD (option)
      final heldNvda = _buildInstrumentPosition(symbol: 'NVDA', quantity: 10.0);
      final heldCrwdOption =
          _buildOptionPosition(symbol: 'CRWD', quantity: 1.0);

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [heldNvda],
        optionPositions: [heldCrwdOption],
        congressTrades: [pelosiBuyNvda, tubervilleSellCrwd, crenshawBuyAmzn],
        now: now,
      );

      // Should alert on NVDA (buy) and CRWD (sale), but NOT AMZN (user does not hold AMZN)
      final congressAlerts = alerts
          .where((a) => a.target == PortfolioAlertTarget.congressionalTrading)
          .toList();

      expect(congressAlerts.length, 2);

      final nvdaAlert = congressAlerts.firstWhere((a) => a.id.contains('nvda'));
      expect(nvdaAlert.title, 'Congress Trade: Rep. Nancy Pelosi (NVDA)');
      expect(nvdaAlert.severity,
          PortfolioAlertSeverity.positive); // Large purchase ($1M+)
      expect(nvdaAlert.target, PortfolioAlertTarget.congressionalTrading);
      expect(nvdaAlert.detail, contains('held in your portfolio'));

      final crwdAlert = congressAlerts.firstWhere((a) => a.id.contains('crwd'));
      expect(crwdAlert.title, 'Congress Trade: Sen. Tommy Tuberville (CRWD)');
      expect(crwdAlert.severity, PortfolioAlertSeverity.info);
      expect(crwdAlert.target, PortfolioAlertTarget.congressionalTrading);
    });

    test('ignores non-held symbols or zero-quantity positions', () {
      final now = DateTime(2026, 9, 1);

      // User holds 0 shares of NVDA
      final zeroSharesNvda =
          _buildInstrumentPosition(symbol: 'NVDA', quantity: 0.0);

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [zeroSharesNvda],
        optionPositions: const [],
        congressTrades: [pelosiBuyNvda],
        now: now,
      );

      final congressAlerts = alerts
          .where((a) => a.target == PortfolioAlertTarget.congressionalTrading)
          .toList();

      expect(congressAlerts.isEmpty, isTrue);
    });

    test('evaluates SmartAlertRule against CongressTrade disclosures', () {
      // Rule 1: Purchases over $500k
      const buyRule = SmartAlertRule(
        type: AlertType.congress_trading,
        condition: AlertCondition.congress_trade_purchase,
        value: 500000,
      );
      expect(
        PortfolioAlertService.evaluateCongressTradingAlert(
          rule: buyRule,
          trade: pelosiBuyNvda, // $1M+ purchase
        ),
        isTrue,
      );
      expect(
        PortfolioAlertService.evaluateCongressTradingAlert(
          rule: buyRule,
          trade: crenshawBuyAmzn, // $15k purchase, < $500k
        ),
        isFalse,
      );

      // Rule 2: Sales
      const saleRule = SmartAlertRule(
        type: AlertType.congress_trading,
        condition: AlertCondition.congress_trade_sale,
        value: 50000,
      );
      expect(
        PortfolioAlertService.evaluateCongressTradingAlert(
          rule: saleRule,
          trade: tubervilleSellCrwd, // $100k sale
        ),
        isTrue,
      );
      expect(
        PortfolioAlertService.evaluateCongressTradingAlert(
          rule: saleRule,
          trade: pelosiBuyNvda, // purchase, not sale
        ),
        isFalse,
      );

      // Rule 3: Any trade over $10k
      const anyRule = SmartAlertRule(
        type: AlertType.congress_trading,
        condition: AlertCondition.congress_trade_any,
        value: 10000,
      );
      expect(
        PortfolioAlertService.evaluateCongressTradingAlert(
          rule: anyRule,
          trade: crenshawBuyAmzn,
        ),
        isTrue,
      );
    });
  });
}

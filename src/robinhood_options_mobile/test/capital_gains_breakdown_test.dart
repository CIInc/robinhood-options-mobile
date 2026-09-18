import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/capital_gains_model.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';
import 'package:robinhood_options_mobile/services/tax_optimization_service.dart';

void main() {
  group('CapitalGainPosition Model Tests', () {
    final asOfDate = DateTime(2026, 10, 1, 12, 0);

    test('calculates short-term position (> 60 days to long-term) correctly',
        () {
      final acquired = DateTime(2026, 6, 1, 12, 0); // ~122 days ago
      final pos = CapitalGainPosition.create(
        id: 'cg_1',
        symbol: 'AAPL',
        name: 'Apple Inc.',
        quantity: 10,
        averageCostPrice: 150.0,
        totalCost: 1500.0,
        currentPrice: 200.0,
        marketValue: 2000.0,
        gainLoss: 500.0,
        gainLossPercent: 0.333,
        type: 'stock',
        acquiredDate: acquired,
        asOf: asOfDate,
        shortTermTaxRate: 0.24,
        longTermTaxRate: 0.15,
      );

      expect(pos.isLongTerm, isFalse);
      expect(pos.holdingDays, 122);
      expect(pos.daysUntilLongTerm, 366 - 122);
      expect(pos.qualifiesForLongTermSoon, isFalse);
      expect(pos.estimatedShortTermTax, 500.0 * 0.24);
      expect(pos.estimatedLongTermTax, 500.0 * 0.15);
      expect(pos.potentialTaxSavingsIfHeld, (500.0 * 0.24) - (500.0 * 0.15));
      expect(pos.formattedHoldingPeriod, contains('mo'));
      expect(pos.holdingTimerText, contains('days to Long-Term'));
    });

    test('calculates approaching long-term position (<= 60 days) correctly',
        () {
      final acquired = asOfDate.subtract(const Duration(days: 320));
      final pos = CapitalGainPosition.create(
        id: 'cg_2',
        symbol: 'NVDA',
        name: 'NVIDIA Corporation',
        quantity: 20,
        averageCostPrice: 100.0,
        totalCost: 2000.0,
        currentPrice: 130.0,
        marketValue: 2600.0,
        gainLoss: 600.0,
        gainLossPercent: 0.30,
        type: 'stock',
        acquiredDate: acquired,
        asOf: asOfDate,
        shortTermTaxRate: 0.24,
        longTermTaxRate: 0.15,
      );

      expect(pos.isLongTerm, isFalse);
      expect(pos.holdingDays, 320);
      expect(pos.daysUntilLongTerm, 46);
      expect(pos.qualifiesForLongTermSoon, isTrue);
      expect(pos.potentialTaxSavingsIfHeld, (600.0 * 0.24) - (600.0 * 0.15));
      expect(pos.holdingTimerText, contains('46 days until Long-Term'));
    });

    test('calculates long-term position (> 365 days) correctly', () {
      final acquired = DateTime(2025, 5, 1, 12, 0); // ~518 days ago
      final pos = CapitalGainPosition.create(
        id: 'cg_3',
        symbol: 'MSFT',
        name: 'Microsoft Corporation',
        quantity: 15,
        averageCostPrice: 300.0,
        totalCost: 4500.0,
        currentPrice: 420.0,
        marketValue: 6300.0,
        gainLoss: 1800.0,
        gainLossPercent: 0.40,
        type: 'stock',
        acquiredDate: acquired,
        asOf: asOfDate,
        shortTermTaxRate: 0.24,
        longTermTaxRate: 0.15,
      );

      expect(pos.isLongTerm, isTrue);
      expect(pos.daysUntilLongTerm, 0);
      expect(pos.qualifiesForLongTermSoon, isFalse);
      expect(pos.estimatedLongTermTax, 1800.0 * 0.15);
      expect(pos.formattedHoldingPeriod, contains('y'));
      expect(pos.holdingTimerText, contains('Long-Term'));
    });

    test('loss positions do not qualify for approaching long-term status', () {
      final acquired = DateTime(
          2025, 11, 15, 12, 0); // 320 days ago (<= 60 days to long-term)
      final pos = CapitalGainPosition.create(
        id: 'cg_4',
        symbol: 'INTC',
        name: 'Intel Corporation',
        quantity: 50,
        averageCostPrice: 35.0,
        totalCost: 1750.0,
        currentPrice: 22.0,
        marketValue: 1100.0,
        gainLoss: -650.0,
        gainLossPercent: -0.37,
        type: 'stock',
        acquiredDate: acquired,
        asOf: asOfDate,
      );

      expect(pos.isLongTerm, isFalse);
      expect(pos.qualifiesForLongTermSoon, isFalse);
      expect(pos.estimatedShortTermTax, 0.0);
      expect(pos.estimatedLongTermTax, 0.0);
      expect(pos.potentialTaxSavingsIfHeld, 0.0);
    });
  });

  group('CapitalGainsSummary Aggregation Tests', () {
    final asOfDate = DateTime(2026, 10, 1, 12, 0);

    test(
        'aggregates short-term and long-term gains, liabilities, and potential savings',
        () {
      final pos1 = CapitalGainPosition.create(
        id: '1',
        symbol: 'AAPL',
        name: 'Apple',
        quantity: 10,
        averageCostPrice: 100,
        totalCost: 1000,
        currentPrice: 150,
        marketValue: 1500,
        gainLoss: 500,
        gainLossPercent: 0.5,
        type: 'stock',
        acquiredDate: DateTime(2026, 8, 1), // Short term
        asOf: asOfDate,
      );

      final pos2 = CapitalGainPosition.create(
        id: '2',
        symbol: 'NVDA',
        name: 'Nvidia',
        quantity: 10,
        averageCostPrice: 100,
        totalCost: 1000,
        currentPrice: 180,
        marketValue: 1800,
        gainLoss: 800,
        gainLossPercent: 0.8,
        type: 'stock',
        acquiredDate: DateTime(2025, 11, 15), // Approaching (< 60d)
        asOf: asOfDate,
      );

      final pos3 = CapitalGainPosition.create(
        id: '3',
        symbol: 'TSLA',
        name: 'Tesla',
        quantity: 10,
        averageCostPrice: 250,
        totalCost: 2500,
        currentPrice: 200,
        marketValue: 2000,
        gainLoss: -500,
        gainLossPercent: -0.2,
        type: 'stock',
        acquiredDate: DateTime(2026, 7, 1), // Short term loss
        asOf: asOfDate,
      );

      final pos4 = CapitalGainPosition.create(
        id: '4',
        symbol: 'MSFT',
        name: 'Microsoft',
        quantity: 10,
        averageCostPrice: 200,
        totalCost: 2000,
        currentPrice: 350,
        marketValue: 3500,
        gainLoss: 1500,
        gainLossPercent: 0.75,
        type: 'stock',
        acquiredDate: DateTime(2024, 1, 1), // Long term
        asOf: asOfDate,
      );

      final summary = CapitalGainsSummary.fromPositions(
        positions: [pos1, pos2, pos3, pos4],
        shortTermTaxRate: 0.24,
        longTermTaxRate: 0.15,
      );

      expect(summary.allPositions.length, 4);
      expect(summary.shortTermPositions.length, 3);
      expect(summary.longTermPositions.length, 1);
      expect(summary.approachingLongTermPositions.length, 1);
      expect(summary.approachingLongTermPositions.first.symbol, 'NVDA');

      // Short term net: 500 (AAPL) + 800 (NVDA) - 500 (TSLA) = 800
      expect(summary.shortTermNet, 800.0);
      expect(summary.shortTermGains, 1300.0);
      expect(summary.shortTermLosses, -500.0);
      expect(summary.estimatedShortTermTaxLiability, 800.0 * 0.24);

      // Long term net: 1500
      expect(summary.longTermNet, 1500.0);
      expect(summary.estimatedLongTermTaxLiability, 1500.0 * 0.15);

      // Total liability
      expect(
          summary.totalEstimatedTaxLiability, (800.0 * 0.24) + (1500.0 * 0.15));

      // Potential savings from holding NVDA (800 * (0.24 - 0.15) = 72.0)
      expect(summary.potentialTaxSavingsFromHolding, closeTo(72.0, 0.001));
    });
  });

  group('TaxOptimizationService analyzeCapitalGains Integration', () {
    test('analyzes real stock and option position objects', () {
      final asOfDate = DateTime(2026, 10, 15);

      final stockInst = Instrument(
        id: 'inst_1',
        url: '',
        quote: '',
        fundamentals: '',
        splits: '',
        state: '',
        market: '',
        name: 'Amazon.com Inc.',
        tradeable: true,
        tradability: '',
        symbol: 'AMZN',
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
      stockInst.quoteObj = Quote(
        symbol: 'AMZN',
        askPrice: 190.0,
        askSize: 100,
        bidPrice: 190.0,
        bidSize: 100,
        lastTradePrice: 190.0,
        lastExtendedHoursTradePrice: null,
        previousClose: 185.0,
        adjustedPreviousClose: 185.0,
        previousCloseDate: null,
        tradingHalted: false,
        hasTraded: true,
        lastTradePriceSource: '',
        updatedAt: asOfDate,
        instrument: '',
        instrumentId: 'inst_1',
      );

      final stockPos = InstrumentPosition(
        '',
        '/instruments/inst_1/',
        '',
        'acc_1',
        140.0, // buy price
        140.0,
        10.0, // quantity -> cost = 1400, val = 1900, gain = 500
        0,
        0,
        10,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        false,
        asOfDate,
        DateTime(2025, 11, 20), // Approaching long term (~330 days ago)
      );
      stockPos.instrumentObj = stockInst;

      final optInst = OptionInstrument.fromJson({
        'id': 'opt_1',
        'url': '',
        'chain_id': '',
        'chain_symbol': 'SPY',
        'created_at': '2026-01-01T00:00:00Z',
        'expiration_date': '2026-11-20',
        'issue_date': '2026-01-01',
        'min_ticks': {
          'above_tick': '0.05',
          'below_tick': '0.01',
          'cutoff_price': '3.00',
        },
        'rhs_tradability': '',
        'state': '',
        'strike_price': '500.0',
        'tradability': 'tradable',
        'tradable_chain_id': '',
        'type': 'call',
        'updated_at': asOfDate.toIso8601String(),
        'url_chain': '',
        'sellout_date_time': null,
        'long_strategy_code': 'long_call',
        'short_strategy_code': 'short_call',
      });

      final optLegs = OptionLeg.fromJsonArray([
        {
          'id': 'leg_1',
          'position': '',
          'position_type': 'long',
          'option': 'https://api.robinhood.com/options/instruments/opt_1/',
          'position_effect': 'open',
          'strike_price': '500.0',
          'expiration_date': '2026-11-20',
          'ratio_quantity': 1,
          'side': 'buy',
          'option_type': 'call',
        }
      ]);

      final optionPos = OptionAggregatePosition(
        'opt_pos_1',
        'chain_1',
        'acc_1',
        'SPY',
        'long_call',
        5.0, // open price
        optLegs,
        2.0, // quantity -> 2 contracts = 200 shares -> cost = 1000
        0,
        0,
        'debit',
        'debit',
        100.0,
        DateTime(2026, 8, 1), // Short term (75 days ago)
        asOfDate,
        'long_call',
      );
      optionPos.optionInstrument = optInst;

      final summary = TaxOptimizationService.analyzeCapitalGains(
        instrumentPositions: [stockPos],
        optionPositions: [optionPos],
        asOf: asOfDate,
      );

      expect(summary.allPositions.length, 2);
      expect(summary.shortTermPositions.length, 2); // Both < 365 days
      expect(summary.approachingLongTermPositions.length, 1);
      expect(summary.approachingLongTermPositions.first.symbol, 'AMZN');
      expect(
          summary.approachingLongTermPositions.first.qualifiesForLongTermSoon,
          isTrue);
    });
  });

  group('PortfolioAlertService Approaching Long-Term Alert Tests', () {
    test('adds alert when potential tax savings from holding >= \$25', () {
      final asOfDate = DateTime(2026, 10, 15);

      final stockInst = Instrument(
        id: 'inst_nvda',
        url: '',
        quote: '',
        fundamentals: '',
        splits: '',
        state: '',
        market: '',
        name: 'NVIDIA Corp',
        tradeable: true,
        tradability: '',
        symbol: 'NVDA',
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
      stockInst.quoteObj = Quote(
        symbol: 'NVDA',
        askPrice: 120.0,
        askSize: 100,
        bidPrice: 120.0,
        bidSize: 100,
        lastTradePrice: 120.0,
        lastExtendedHoursTradePrice: null,
        previousClose: 115.0,
        adjustedPreviousClose: 115.0,
        previousCloseDate: null,
        tradingHalted: false,
        hasTraded: true,
        lastTradePriceSource: '',
        updatedAt: asOfDate,
        instrument: '',
        instrumentId: 'inst_nvda',
      );

      final stockPos = InstrumentPosition(
        '',
        '/instruments/inst_nvda/',
        '',
        'acc_1',
        70.0, // gain = $50/share * 20 = $1,000 gain
        70.0,
        20.0,
        0,
        0,
        20,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        false,
        DateTime.now(),
        DateTime.now().subtract(const Duration(
            days: 330)), // Approaching: 330 days old -> 36 days left
      );
      stockPos.instrumentObj = stockInst;

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [stockPos],
        optionPositions: const [],
      );

      final approachingAlert =
          alerts.where((a) => a.id == 'capital-gains-approaching').toList();
      expect(approachingAlert, isNotEmpty);
      expect(
          approachingAlert.first.title, contains('nearing Long-Term status'));
      expect(approachingAlert.first.detail, contains('Hold NVDA'));
      expect(approachingAlert.first.metric, contains('savings'));
    });
  });
}

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/tax_harvesting_suggestion.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/tax_optimization_service.dart';
import 'package:robinhood_options_mobile/widgets/tax_optimization_widget.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
    List<AnalyticsEventItem>? items,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

class FakeFirebaseAnalyticsObserver extends Fake
    implements FirebaseAnalyticsObserver {}

class FakeGenerativeService extends Fake implements GenerativeService {}

InstrumentPosition createTestStockPosition({
  required String symbol,
  required String name,
  required double quantity,
  required double buyPrice,
  required double currentPrice,
}) {
  final pos = InstrumentPosition.fromJson({
    'url': 'https://api.robinhood.com/positions/$symbol/',
    'instrument': 'https://api.robinhood.com/instruments/$symbol/',
    'account': 'test_acc',
    'account_number': 'test_acc',
    'average_buy_price': buyPrice.toString(),
    'quantity': quantity.toString(),
    'avg_cost_affected': false,
    'created_at': DateTime.now().toIso8601String(),
    'updated_at': DateTime.now().toIso8601String(),
  });
  pos.instrumentObj = Instrument(
    id: symbol,
    url: 'https://api.robinhood.com/instruments/$symbol/',
    quote: '',
    fundamentals: '',
    splits: '',
    state: 'active',
    market: '',
    name: name,
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
    quoteObj: Quote(
      askPrice: currentPrice,
      askSize: 0,
      bidPrice: currentPrice,
      bidSize: 0,
      lastTradePrice: currentPrice,
      lastExtendedHoursTradePrice: currentPrice,
      previousClose: currentPrice,
      adjustedPreviousClose: currentPrice,
      previousCloseDate: DateTime(2026, 1, 1),
      symbol: symbol,
      tradingHalted: false,
      hasTraded: true,
      lastTradePriceSource: 'test',
      updatedAt: DateTime(2026, 1, 2),
      instrument: '',
      instrumentId: symbol,
    ),
  );
  return pos;
}

OptionAggregatePosition createTestOptionPosition({
  required String symbol,
  required double quantity,
  required double buyPrice,
  required double currentMarkPrice,
}) {
  final optPos = OptionAggregatePosition.fromJson({
    'id': 'opt_$symbol',
    'chain': 'chain_$symbol',
    'account': 'test_acc',
    'symbol': symbol,
    'strategy': 'call',
    'average_open_price': buyPrice.toString(),
    'quantity': quantity.toString(),
    'direction': 'debit',
    'intraday_direction': 'debit',
    'strategy_code': 'call',
    'legs': [],
  });
  optPos.optionInstrument = OptionInstrument.fromJson({
    'id': 'opt_inst_$symbol',
    'chain_id': 'chain_$symbol',
    'chain_symbol': symbol,
    'strike_price': '500.0',
    'type': 'call',
    'state': 'active',
    'tradability': 'tradable',
    'rhs_tradability': 'tradable',
    'url': '',
    'long_strategy_code': '',
    'short_strategy_code': '',
    'min_ticks': {
      'above_tick': 0.01,
      'below_tick': 0.01,
      'cutoff_price': 3.0,
    },
  });
  optPos.optionInstrument!.optionMarketData = OptionMarketData.fromJson({
    'mark_price': currentMarkPrice.toString(),
    'adjusted_mark_price': currentMarkPrice.toString(),
    'ask_price': currentMarkPrice.toString(),
    'ask_size': 0,
    'bid_price': currentMarkPrice.toString(),
    'bid_size': 0,
    'break_even_price': currentMarkPrice.toString(),
    'high_price': currentMarkPrice.toString(),
    'instrument': '',
    'instrument_id': '',
    'last_trade_price': currentMarkPrice.toString(),
    'last_trade_size': 0,
    'low_price': currentMarkPrice.toString(),
    'open_interest': 0,
    'previous_close_price': currentMarkPrice.toString(),
    'volume': 0,
    'symbol': symbol,
    'occ_symbol': symbol,
  });
  return optPos;
}

void main() {
  group('CorrelatedReplacement Model Tests', () {
    test('serializes and deserializes CorrelatedReplacement JSON correctly',
        () {
      const rep = CorrelatedReplacement(
        symbol: 'VOO',
        name: 'Vanguard S&P 500 ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Direct index replacement without wash sale violation.',
        isSubstantiallyIdenticalWarning: false,
      );

      final json = rep.toJson();
      final parsed = CorrelatedReplacement.fromJson(json);

      expect(parsed.symbol, 'VOO');
      expect(parsed.name, 'Vanguard S&P 500 ETF');
      expect(parsed.assetType, 'etf');
      expect(parsed.correlation, 0.99);
      expect(parsed.rationale,
          'Direct index replacement without wash sale violation.');
      expect(parsed.isSubstantiallyIdenticalWarning, isFalse);
    });
  });

  group('TaxOptimizationService Correlated Replacements Tests', () {
    test('returns high-correlation curated replacements for major index ETFs',
        () {
      final spyReps = TaxOptimizationService.getCorrelatedReplacements('SPY');
      expect(spyReps, isNotEmpty);
      expect(spyReps.any((r) => r.symbol == 'VOO' && r.correlation >= 0.98),
          isTrue);
      expect(spyReps.any((r) => r.symbol == 'IVV'), isTrue);

      final qqqReps = TaxOptimizationService.getCorrelatedReplacements('QQQ');
      expect(
          qqqReps.any((r) => r.symbol == 'QQQM' || r.symbol == 'VGT'), isTrue);

      final vtiReps = TaxOptimizationService.getCorrelatedReplacements('VTI');
      expect(
          vtiReps.any((r) => r.symbol == 'ITOT' || r.symbol == 'SCHB'), isTrue);
    });

    test('returns industry and competitor replacements for mega-cap stocks',
        () {
      final nvdaReps = TaxOptimizationService.getCorrelatedReplacements('NVDA');
      expect(nvdaReps.any((r) => r.symbol == 'AMD'), isTrue);
      expect(nvdaReps.any((r) => r.symbol == 'SMH'), isTrue);

      final aaplReps = TaxOptimizationService.getCorrelatedReplacements('AAPL');
      expect(
          aaplReps.any((r) => r.symbol == 'MSFT' || r.symbol == 'XLK'), isTrue);

      final tslaReps = TaxOptimizationService.getCorrelatedReplacements('TSLA');
      expect(tslaReps.any((r) => r.symbol == 'RIVN' || r.symbol == 'CARZ'),
          isTrue);
    });

    test('falls back to broad market ETFs for unmapped tickers', () {
      final fallbackReps =
          TaxOptimizationService.getCorrelatedReplacements('RANDOMTICKER');
      expect(fallbackReps, isNotEmpty);
      expect(fallbackReps.first.symbol, 'VOO');
      expect(fallbackReps.any((r) => r.symbol == 'VTI'), isTrue);
    });
  });

  group('TaxOptimizationService.scanTaxLossHarvestingOpportunities Tests', () {
    late InstrumentPosition losingStock;
    late InstrumentPosition winningStock;
    late OptionAggregatePosition losingOption;

    setUp(() {
      // Cost: 10 * $120 = $1200. Value: 10 * $100 = $1000. Loss: -$200
      losingStock = createTestStockPosition(
        symbol: 'NVDA',
        name: 'NVIDIA Corp',
        quantity: 10.0,
        buyPrice: 120.0,
        currentPrice: 100.0,
      );

      // Cost: 10 * $150 = $1500. Value: 10 * $200 = $2000. Gain: +$500
      winningStock = createTestStockPosition(
        symbol: 'AAPL',
        name: 'Apple Inc',
        quantity: 10.0,
        buyPrice: 150.0,
        currentPrice: 200.0,
      );

      // Robinhood average_open_price is stored per contract ($5.00 * 100 = $500.0).
      // Cost: 1 * $500 = $500. Value: 1 * $3.00 * 100 = $300. Loss: -$200
      losingOption = createTestOptionPosition(
        symbol: 'SPY',
        quantity: 1.0,
        buyPrice: 500.0,
        currentMarkPrice: 3.0,
      );
    });

    test(
        'scans opportunities, computes realized gains offset and ordinary income cap',
        () {
      final result = TaxOptimizationService.scanTaxLossHarvestingOpportunities(
        instrumentPositions: [losingStock, winningStock],
        optionPositions: [losingOption],
        realizedCapitalGains: 150.0, // $150 of realized gains
        effectiveTaxRate: 0.30, // 30% tax rate
      );

      // Total unrealized loss = -$200 (stock) + -$200 (option) = -$400
      expect(result.totalUnrealizedLoss, -400.0);
      expect(result.realizedCapitalGains, 150.0);
      expect(result.netGainsAfterHarvest, 0.0); // $150 - $400 <= 0

      // Offset: $150 gains offset, leaving $250 loss used against ordinary income (under $3000 cap)
      expect(result.capitalLossDeductionUsed, 250.0);
      expect(result.capitalLossCarryforward, 0.0);

      // Total tax savings = ($150 + $250) * 0.30 = $120.0
      expect(result.estimatedTaxSavings, 120.0);
      expect(result.suggestions.length, 2);

      // Check correlated replacements are populated on suggestions
      final stockSuggestion =
          result.suggestions.firstWhere((s) => s.symbol == 'NVDA');
      expect(stockSuggestion.replacements, isNotEmpty);
      expect(
          stockSuggestion.replacements.any((r) => r.symbol == 'AMD'), isTrue);
      expect(stockSuggestion.taxSavingsEstimate, 60.0); // $200 * 0.30
    });

    test(
        'handles IRS ordinary income cap and accumulates carryforward for massive losses',
        () {
      final bigLossStock = createTestStockPosition(
        symbol: 'NVDA',
        name: 'NVIDIA Corp',
        quantity: 100.0,
        buyPrice: 150.0, // Cost = $15,000
        currentPrice: 50.0, // Value = $5,000 -> Loss = -$10,000
      );

      final result = TaxOptimizationService.scanTaxLossHarvestingOpportunities(
        instrumentPositions: [bigLossStock],
        optionPositions: [],
        realizedCapitalGains: 2000.0, // $2000 realized gains
        effectiveTaxRate: 0.25,
      );

      // Total loss = -$10,000
      // Realized gains offset = $2,000
      // Remaining loss = $8,000
      // Ordinary income deduction cap = $3,000
      // Loss carryforward = $8,000 - $3,000 = $5,000
      expect(result.capitalLossDeductionUsed, 3000.0);
      expect(result.capitalLossCarryforward, 5000.0);
      // Tax savings = ($2000 + $3000) * 0.25 = $1250.0
      expect(result.estimatedTaxSavings, 1250.0);
    });

    test('filters opportunities by asset class and minimum loss threshold', () {
      // Filter stocks only
      final stockOnly =
          TaxOptimizationService.scanTaxLossHarvestingOpportunities(
        instrumentPositions: [losingStock],
        optionPositions: [losingOption],
        assetFilter: 'stock',
      );
      expect(stockOnly.suggestions.length, 1);
      expect(stockOnly.suggestions.first.type, 'stock');

      // Filter options only
      final optionOnly =
          TaxOptimizationService.scanTaxLossHarvestingOpportunities(
        instrumentPositions: [losingStock],
        optionPositions: [losingOption],
        assetFilter: 'option',
      );
      expect(optionOnly.suggestions.length, 1);
      expect(optionOnly.suggestions.first.type, 'option');

      // Min loss threshold: $300 (both individual losses are $200)
      final highThreshold =
          TaxOptimizationService.scanTaxLossHarvestingOpportunities(
        instrumentPositions: [losingStock],
        optionPositions: [losingOption],
        minLossThreshold: 300.0,
      );
      expect(highThreshold.suggestions.isEmpty, isTrue);
    });

    test('sorts opportunities by loss %, tax savings, and total dollar loss',
        () {
      // losingStock: loss $200 on $1200 cost = 16.6%
      // losingOption: loss $200 on $500 cost = 40.0%
      final sortedByPercent =
          TaxOptimizationService.scanTaxLossHarvestingOpportunities(
        instrumentPositions: [losingStock],
        optionPositions: [losingOption],
        sortBy: 'percent',
      );
      expect(sortedByPercent.suggestions.first.symbol, 'SPY'); // 40% loss
    });
  });

  group('TaxOptimizationWidget Scanner UI Tests', () {
    final testUser = BrokerageUser(
      BrokerageSource.demo,
      'test_trader',
      null,
      null,
    );
    final testService = DemoService();
    final testAnalytics = FakeFirebaseAnalytics();
    final testObserver = FakeFirebaseAnalyticsObserver();
    final testGenService = FakeGenerativeService();

    Widget createWidgetUnderTest({
      required List<InstrumentPosition> stockPositions,
      required List<OptionAggregatePosition> optionPositions,
    }) {
      final stockStore = InstrumentPositionStore();
      for (final p in stockPositions) {
        stockStore.add(p);
      }

      final optionStore = OptionPositionStore();
      for (final p in optionPositions) {
        optionStore.add(p);
      }

      final instrumentStore = InstrumentStore();

      return MultiProvider(
        providers: [
          ChangeNotifierProvider<InstrumentPositionStore>.value(
              value: stockStore),
          ChangeNotifierProvider<OptionPositionStore>.value(value: optionStore),
          ChangeNotifierProvider<InstrumentStore>.value(value: instrumentStore),
        ],
        child: MaterialApp(
          home: TaxOptimizationWidget(
            user: testUser,
            service: testService,
            analytics: testAnalytics,
            observer: testObserver,
            generativeService: testGenService,
            appUser: null,
            userDocRef: null,
            portfolioHistoricals: PortfolioHistoricals.fromJson({
              'use_new_hp': false,
              'total_return': '500.0',
              'interval': 'day',
              'span': 'day',
              'bounds': 'regular',
              'equity_historicals': [],
            }),
            initialTabIndex: 0,
          ),
        ),
      );
    }

    testWidgets(
        'renders scanner summary metrics, filter chips, and correlated replacements',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testPositions = [
        createTestStockPosition(
          symbol: 'SPY',
          name: 'SPDR S&P 500 ETF Trust',
          quantity: 10.0,
          buyPrice: 500.0,
          currentPrice: 440.0, // loss = -$600
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest(
        stockPositions: testPositions,
        optionPositions: [],
      ));
      await tester.pumpAndSettle();

      // Verify Header & Summary Card
      expect(find.text('Total Potential Tax Loss'), findsOneWidget);
      expect(find.textContaining(r'$600'), findsWidgets);
      expect(find.textContaining('Est. Tax Alpha:'), findsOneWidget);

      // Verify Scanner Filter Chips
      expect(find.text('All (1)'), findsOneWidget);
      expect(find.text('Stocks (1)'), findsOneWidget);
      expect(find.text('Options (0)'), findsOneWidget);
      expect(find.text('Any Loss'), findsOneWidget);
      expect(find.text(r'>$100'), findsOneWidget);
      expect(find.text('Loss \$'), findsOneWidget);

      // Verify Correlated Replacement Recommendations on the card
      expect(find.text('Correlated Replacements'), findsOneWidget);
      expect(find.text('Safe CUSIP'), findsOneWidget);
      expect(find.text('VOO'), findsOneWidget);
      expect(find.textContaining('corr'), findsWidgets);
      expect(find.text('Est. Relief'), findsOneWidget);
    });
  });
}

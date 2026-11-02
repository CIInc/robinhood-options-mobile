import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/return_attribution.dart';
import 'package:robinhood_options_mobile/services/return_attribution_service.dart';
import 'package:robinhood_options_mobile/widgets/portfolio/analytics/analytics_csv_export.dart';

import 'return_attribution_fixtures.dart';

typedef S = ReturnAttributionService;

void main() {
  group('Brinson-Fachler attribution', () {
    // Two-sector benchmark: Tech 60% @ +2%, Financials 40% @ −1% → RB = 0.8%.
    const weights = {S.infoTech: 60.0, S.financials: 40.0};
    const sectorReturns = {S.infoTech: 0.02, S.financials: -0.01};

    test('matches a hand-computed two-sector example', () {
      // Portfolio: Tech 80% @ +3%, Financials 20% @ −1% → RP = 2.2%.
      final result = S.calculateBrinsonAttribution(
        holdings: const [
          AttributionHolding(
              symbol: 'AAPL',
              sector: S.infoTech,
              beginValue: 8000,
              endValue: 8240),
          AttributionHolding(
              symbol: 'JPM',
              sector: S.financials,
              beginValue: 2000,
              endValue: 1980),
        ],
        benchmarkSectorWeights: weights,
        benchmarkSectorReturns: sectorReturns,
        benchmarkSymbol: 'TEST',
      );

      expect(result.totalBenchmarkReturn, closeTo(0.008, 1e-12));
      expect(result.totalPortfolioReturn, closeTo(0.022, 1e-12));
      expect(result.activeReturn, closeTo(0.014, 1e-12));
      // Tech A=.2·(.02−.008), S=.6·.01, I=.2·.01; Fin A=−.2·(−.018).
      expect(result.totalAllocationEffect, closeTo(0.0024 + 0.0036, 1e-12));
      expect(result.totalSelectionEffect, closeTo(0.006, 1e-12));
      expect(result.totalInteractionEffect, closeTo(0.002, 1e-12));
      expect(result.sumOfEffects, closeTo(result.activeReturn, 1e-12));

      final tech =
          result.sectorAttributions.firstWhere((r) => r.sector == S.infoTech);
      expect(tech.portfolioWeight, closeTo(0.8, 1e-12));
      expect(tech.benchmarkWeight, closeTo(0.6, 1e-12));
      expect(tech.totalEffect, closeTo(0.0104, 1e-12));
      expect(result.totalPortfolioPnL, closeTo(220, 1e-9));
    });

    test('sum identity holds with cash, unmapped funds and SPY weights', () {
      final holdings = S.holdingsFromPositions([
        attributionStock(
            symbol: 'NVDA',
            sector: 'Electronic Technology',
            quantity: 10,
            previousClose: 120,
            price: 126),
        attributionStock(
            symbol: 'JPM',
            sector: 'Finance',
            quantity: 5,
            previousClose: 200,
            price: 196),
        attributionStock(
            symbol: 'XOM',
            sector: 'Energy Minerals',
            quantity: 8,
            previousClose: 110,
            price: 111),
        attributionStock(
            symbol: 'VTI',
            sector: '',
            quantity: 3,
            previousClose: 250,
            price: 252.5),
      ]);
      final result = S.calculateBrinsonAttribution(
        holdings: holdings,
        cashBalance: 1500,
        benchmarkSectorWeights: S.benchmarkSectorWeightsFor('SPY'),
        benchmarkSectorReturns:
            S.sectorReturnsFromQuotes(attributionSectorQuotes()),
        benchmarkSymbol: 'SPY',
      );

      expect(result.sumOfEffects, closeTo(result.activeReturn, 1e-12));
      final sectors = result.sectorAttributions.map((r) => r.sector).toSet();
      expect(sectors, containsAll([S.cash, S.other, S.energy]));
      final portfolioWeightSum = result.sectorAttributions
          .fold<double>(0, (a, r) => a + r.portfolioWeight);
      final benchmarkWeightSum = result.sectorAttributions
          .fold<double>(0, (a, r) => a + r.benchmarkWeight);
      expect(portfolioWeightSum, closeTo(1, 1e-12));
      expect(benchmarkWeightSum, closeTo(1, 1e-12));
      // Effects are sorted by magnitude.
      final magnitudes =
          result.sectorAttributions.map((r) => r.totalEffect.abs()).toList();
      expect(magnitudes,
          orderedEquals([...magnitudes]..sort((a, b) => b.compareTo(a))));
    });

    test('benchmark-weighted portfolio has zero allocation effect', () {
      final result = S.calculateBrinsonAttribution(
        holdings: const [
          AttributionHolding(
              symbol: 'A', sector: S.infoTech, beginValue: 600, endValue: 630),
          AttributionHolding(
              symbol: 'B',
              sector: S.financials,
              beginValue: 400,
              endValue: 390),
        ],
        benchmarkSectorWeights: weights,
        benchmarkSectorReturns: sectorReturns,
        benchmarkSymbol: 'TEST',
      );
      expect(result.totalAllocationEffect, closeTo(0, 1e-12));
      expect(result.totalInteractionEffect, closeTo(0, 1e-12));
      expect(result.totalSelectionEffect, closeTo(result.activeReturn, 1e-12));
    });

    test('sector-matching returns have zero selection and interaction', () {
      final result = S.calculateBrinsonAttribution(
        holdings: const [
          AttributionHolding(
              symbol: 'A', sector: S.infoTech, beginValue: 900, endValue: 918),
          AttributionHolding(
              symbol: 'B', sector: S.financials, beginValue: 100, endValue: 99),
        ],
        benchmarkSectorWeights: weights,
        benchmarkSectorReturns: sectorReturns,
        benchmarkSymbol: 'TEST',
      );
      expect(result.totalSelectionEffect, closeTo(0, 1e-12));
      expect(result.totalInteractionEffect, closeTo(0, 1e-12));
      expect(result.totalAllocationEffect, closeTo(result.activeReturn, 1e-12));
    });

    test('an all-cash portfolio shows benchmark return as cash drag', () {
      final result = S.calculateBrinsonAttribution(
        holdings: const [],
        cashBalance: 10000,
        benchmarkSectorWeights: weights,
        benchmarkSectorReturns: sectorReturns,
        benchmarkSymbol: 'TEST',
      );
      expect(result.totalPortfolioReturn, 0);
      expect(result.totalAllocationEffect, closeTo(-0.008, 1e-12));
      expect(result.sumOfEffects, closeTo(result.activeReturn, 1e-12));
    });

    test('missing sector returns are dropped and weights renormalized', () {
      final result = S.calculateBrinsonAttribution(
        holdings: const [
          AttributionHolding(
              symbol: 'A', sector: S.infoTech, beginValue: 100, endValue: 101),
        ],
        benchmarkSectorWeights: weights,
        benchmarkSectorReturns: const {S.infoTech: 0.02},
        benchmarkSymbol: 'TEST',
      );
      expect(result.totalBenchmarkReturn, closeTo(0.02, 1e-12));
      expect(result.sumOfEffects, closeTo(result.activeReturn, 1e-12));
    });

    test('returns an empty result with no holdings and no cash', () {
      final result = S.calculateBrinsonAttribution(
        holdings: const [],
        benchmarkSectorWeights: weights,
        benchmarkSectorReturns: sectorReturns,
        benchmarkSymbol: 'TEST',
      );
      expect(result.isEmpty, isTrue);
    });
  });

  group('Inputs and reference data', () {
    test('normalizeSector maps vendor labels onto GICS sectors', () {
      expect(S.normalizeSector('Electronic Technology'), S.infoTech);
      expect(S.normalizeSector('Technology Services'), S.infoTech);
      expect(S.normalizeSector('Health Technology'), S.healthCare);
      expect(S.normalizeSector('Finance'), S.financials);
      expect(S.normalizeSector('Financial Services'), S.financials);
      expect(S.normalizeSector('Retail Trade'), S.consumerDiscretionary);
      expect(S.normalizeSector('Consumer Cyclical'), S.consumerDiscretionary);
      expect(S.normalizeSector('Consumer Non-Durables'), S.consumerStaples);
      expect(S.normalizeSector('Communications'), S.communicationServices);
      expect(S.normalizeSector('Energy Minerals'), S.energy);
      expect(S.normalizeSector('Non-Energy Minerals'), S.materials);
      expect(S.normalizeSector('Producer Manufacturing'), S.industrials);
      expect(S.normalizeSector('Real Estate'), S.realEstate);
      expect(S.normalizeSector('Utilities'), S.utilities);
      expect(S.normalizeSector(''), S.other);
      expect(S.normalizeSector(null), S.other);
      expect(S.normalizeSector('Miscellaneous'), S.other);
    });

    test('benchmark sector weights are normalized; custom falls back to SPY',
        () {
      for (final symbol in ['SPY', 'QQQ', 'DIA', 'IWM']) {
        final total = S
            .benchmarkSectorWeightsFor(symbol)
            .values
            .fold<double>(0, (a, b) => a + b);
        expect(total, closeTo(1, 1e-12), reason: symbol);
        expect(S.hasPublishedSectorWeights(symbol), isTrue);
      }
      expect(S.hasPublishedSectorWeights('ARKK'), isFalse);
      expect(S.benchmarkSectorWeightsFor('ARKK'),
          S.benchmarkSectorWeightsFor('SPY'));
    });

    test('sectorReturnsFromQuotes reads ETF proxy daily returns', () {
      final returns = S.sectorReturnsFromQuotes(attributionSectorQuotes());
      expect(returns.length, 11);
      expect(returns[S.infoTech], closeTo(0.02, 1e-12));
      expect(returns[S.financials], closeTo(-0.01, 1e-12));
      expect(returns[S.utilities], closeTo(0, 1e-12));
    });

    test('holdingsFromPositions skips positions without a usable quote', () {
      final unpriced = attributionStock(
          symbol: 'ZZZ',
          sector: 'Finance',
          quantity: 1,
          previousClose: 10,
          price: 11);
      unpriced.instrumentObj!.quoteObj = null;
      final holdings = S.holdingsFromPositions([
        unpriced,
        attributionStock(
            symbol: 'AAPL',
            sector: 'Electronic Technology',
            quantity: 2,
            previousClose: 100,
            price: 105),
      ]);
      expect(holdings, hasLength(1));
      expect(holdings.single.beginValue, 200);
      expect(holdings.single.endValue, 210);
      expect(holdings.single.sector, S.infoTech);
    });

    test('incomeWithinWindow sums paid dividends and interest in window', () {
      final income = S.incomeWithinWindow(
        dividends: [
          {'state': 'paid', 'payable_date': '2026-11-02', 'amount': '12.50'},
          {'state': 'voided', 'payable_date': '2026-11-02', 'amount': '99'},
          {'state': 'paid', 'payable_date': '2026-10-01', 'amount': '5'},
          'not-a-map',
        ],
        interest: [
          {
            'pay_date': '2026-11-02',
            'amount': {'amount': '3.25'}
          },
        ],
        start: DateTime(2026, 11, 2),
        end: DateTime(2026, 11, 2, 23, 59, 59),
      );
      expect(income, closeTo(15.75, 1e-12));
    });
  });

  group('Options Greek attribution', () {
    test('Taylor terms sum with implied vega to the observed P&L', () {
      // Δ=.5, Γ=.02, Θ=−.05, ν=.12; ΔS=+2; option +1.10; 1 long contract.
      final row = S.attributeOptionPosition(
        symbol: 'AAPL',
        scale: 100,
        underlyingChange: 2,
        optionPriceChange: 1.10,
        delta: 0.5,
        gamma: 0.02,
        theta: -0.05,
        vega: 0.12,
      );
      expect(row.deltaPnL, closeTo(100, 1e-9));
      expect(row.gammaPnL, closeTo(4, 1e-9));
      expect(row.thetaPnL, closeTo(-5, 1e-9));
      expect(row.actualPnL, closeTo(110, 1e-9));
      expect(row.vegaPnL, closeTo(11, 1e-9));
      expect(row.residualPnL, 0);
      expect(row.explainedPnL + row.residualPnL, closeTo(row.actualPnL, 1e-9));
    });

    test('contracts without vega report the remainder as residual', () {
      final row = S.attributeOptionPosition(
        symbol: 'X',
        scale: 100,
        underlyingChange: 1,
        optionPriceChange: 0.6,
        delta: 0.5,
      );
      expect(row.vegaPnL, 0);
      expect(row.residualPnL, closeTo(10, 1e-9));
    });

    test('short positions flip the sign of every bucket', () {
      final long = S.attributeOptionPosition(
          symbol: 'X',
          scale: 100,
          underlyingChange: 2,
          optionPriceChange: 1.1,
          delta: 0.5,
          gamma: 0.02,
          theta: -0.05,
          vega: 0.12);
      final short = S.attributeOptionPosition(
          symbol: 'X',
          scale: -100,
          underlyingChange: 2,
          optionPriceChange: 1.1,
          delta: 0.5,
          gamma: 0.02,
          theta: -0.05,
          vega: 0.12);
      expect(short.deltaPnL, closeTo(-long.deltaPnL, 1e-9));
      expect(short.thetaPnL, closeTo(-long.thetaPnL, 1e-9));
      expect(short.vegaPnL, closeTo(-long.vegaPnL, 1e-9));
    });

    test('aggregates live option positions and adds income', () {
      final result = S.calculateOptionsGreekAttribution(
        positions: [
          attributionOption(
            symbol: 'AAPL',
            direction: 'debit',
            quantity: 2,
            underlyingPreviousClose: 100,
            underlyingPrice: 102,
            optionPreviousClose: 2.0,
            optionMark: 3.1,
          ),
          attributionOption(
            symbol: 'TSLA',
            direction: 'credit',
            quantity: 1,
            underlyingPreviousClose: 200,
            underlyingPrice: 200,
            optionPreviousClose: 4.0,
            optionMark: 3.9,
            delta: 0.3,
            gamma: 0.01,
            theta: -0.10,
            vega: 0.2,
          ),
        ],
        incomePnL: 12.5,
      );

      expect(result.contractCount, 3);
      // AAPL: 2 × (Δ100 + Γ4 + Θ−5 + ν11) = 220; TSLA short: Θ +10, ν 0.
      expect(result.totalDeltaPnL, closeTo(200, 1e-9));
      expect(result.totalGammaPnL, closeTo(8, 1e-9));
      expect(result.totalThetaPnL, closeTo(-10 + 10, 1e-9));
      expect(result.totalVegaPnL, closeTo(22, 1e-9));
      // AAPL +220 on the option mark, TSLA short gains $10 on −0.10.
      expect(result.totalOptionPnL, closeTo(230, 1e-9));
      expect(result.totalPnL, closeTo(242.5, 1e-9));
    });
  });

  group('CSV export', () {
    test('appends Brinson and Greek attribution sections', () {
      final metrics = <String, dynamic>{
        'alignedDates': [DateTime(2026, 10, 30), DateTime(2026, 11, 2)],
        'alignedPortfolioPrices': [100.0, 102.0],
        'alignedBenchmarkPrices': [50.0, 50.5],
        'sharpeRatio': 1.2,
      };
      final brinson = S.calculateBrinsonAttribution(
        holdings: const [
          AttributionHolding(
              symbol: 'A', sector: S.infoTech, beginValue: 800, endValue: 824),
        ],
        cashBalance: 200,
        benchmarkSectorWeights: S.benchmarkSectorWeightsFor('SPY'),
        benchmarkSectorReturns:
            S.sectorReturnsFromQuotes(attributionSectorQuotes()),
        benchmarkSymbol: 'SPY',
      );
      final options = S.calculateOptionsGreekAttribution(
        positions: const [],
        incomePnL: 4,
      );

      final rows = AnalyticsCsvExport.buildRows(
        metrics,
        benchmarkSymbol: 'SPY',
        brinsonAttribution: brinson,
        optionsAttribution: options,
      )!;
      final firstCells = rows.where((r) => r.isNotEmpty).map((r) => r.first);
      expect(
          firstCells, contains('Sector Attribution (Brinson-Fachler) vs SPY'));
      expect(firstCells, contains('Options Greeks P&L Attribution'));
      expect(firstCells, contains(S.infoTech));
      final totalRow =
          rows.firstWhere((r) => r.isNotEmpty && r.first == 'Total');
      expect(totalRow.last as double, closeTo(brinson.activeReturn, 1e-12));
      final incomeRow =
          rows.firstWhere((r) => r.isNotEmpty && r.first == 'Income/Yield P&L');
      expect(incomeRow.last, 4);
    });

    test('omits attribution sections when not supplied', () {
      final rows = AnalyticsCsvExport.buildRows(
        <String, dynamic>{
          'alignedDates': [DateTime(2026, 11, 2)],
          'alignedPortfolioPrices': [100.0],
          'alignedBenchmarkPrices': [50.0],
        },
        benchmarkSymbol: 'SPY',
      )!;
      expect(rows.any((r) => r.isNotEmpty && '${r.first}'.contains('Brinson')),
          isFalse);
      expect(AnalyticsCsvExport.buildRows(const {}, benchmarkSymbol: 'SPY'),
          isNull);
    });
  });
}

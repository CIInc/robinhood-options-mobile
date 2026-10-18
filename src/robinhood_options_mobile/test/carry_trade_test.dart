import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/carry_trade_model.dart';

void main() {
  group('Central Bank Rates', () {
    test(
        'returns standard central bank rates with correct real rate calculation',
        () {
      final rates = CarryTradeOptimizer.getCentralBankRates();
      expect(rates.isNotEmpty, isTrue);

      final usdRate = rates.firstWhere((r) => r.currencyCode == 'USD');
      expect(usdRate.rate, 5.25);
      expect(usdRate.inflationRate, 2.8);
      expect(usdRate.realRate, closeTo(2.45, 0.01));

      final jpyRate = rates.firstWhere((r) => r.currencyCode == 'JPY');
      expect(jpyRate.rate, 0.25);
      expect(jpyRate.direction, 'hiking');
    });
  });

  group('CurrencyCarryPair Calculations', () {
    test('calculates correct net carry yields and recommended directions', () {
      const usdjpy = CurrencyCarryPair(
        symbol: 'USD/JPY',
        baseCurrency: 'USD',
        quoteCurrency: 'JPY',
        baseRate: 5.25,
        quoteRate: 0.25,
        currentPrice: 154.20,
        volatility: 9.8,
        pipSize: 0.01,
      );

      // Long net yield: (5.25 - 0.25) - 0.25 = 4.75%
      expect(usdjpy.longNetYield, closeTo(4.75, 0.01));
      // Short net yield: (0.25 - 5.25) - 0.25 = -5.25%
      expect(usdjpy.shortNetYield, closeTo(-5.25, 0.01));
      expect(usdjpy.recommendedDirection, 'Buy');
      expect(usdjpy.recommendedYield, closeTo(4.75, 0.01));

      // Carry to risk: 4.75 / 9.8 = ~0.484
      expect(usdjpy.carryToRiskRatio, closeTo(0.484, 0.01));

      // Daily swap on $10,000 notional: (10000 * 0.0475) / 365 = ~$1.301
      expect(usdjpy.dailySwapPer10k, closeTo(1.30, 0.05));
    });

    test('recommends Sell for inverse rate differential pairs', () {
      const eurusd = CurrencyCarryPair(
        symbol: 'EUR/USD',
        baseCurrency: 'EUR',
        quoteCurrency: 'USD',
        baseRate: 3.75,
        quoteRate: 5.25,
        currentPrice: 1.0850,
        volatility: 6.2,
      );

      // Short net yield: (5.25 - 3.75) - 0.25 = 1.25%
      expect(eurusd.shortNetYield, closeTo(1.25, 0.01));
      // Long net yield: (3.75 - 5.25) - 0.25 = -1.75%
      expect(eurusd.longNetYield, closeTo(-1.75, 0.01));
      expect(eurusd.recommendedDirection, 'Sell');
      expect(eurusd.recommendedYield, closeTo(1.25, 0.01));
    });

    test(
        'evaluates unwind risk based on low-yield funding currencies and volatility',
        () {
      const highVolUsdJpy = CurrencyCarryPair(
        symbol: 'USD/JPY',
        baseCurrency: 'USD',
        quoteCurrency: 'JPY',
        baseRate: 5.25,
        quoteRate: 0.25,
        currentPrice: 154.20,
        volatility: 12.5,
      );
      expect(highVolUsdJpy.unwindRisk, UnwindRiskLevel.extreme);

      const moderateVolUsdJpy = CurrencyCarryPair(
        symbol: 'USD/JPY',
        baseCurrency: 'USD',
        quoteCurrency: 'JPY',
        baseRate: 5.25,
        quoteRate: 0.25,
        currentPrice: 154.20,
        volatility: 8.5,
      );
      expect(moderateVolUsdJpy.unwindRisk, UnwindRiskLevel.low);
    });
  });

  group('CarryTradeOptimizer Basket Builder', () {
    test(
        'optimizes capital allocation across strategies with normalized weights',
        () {
      const capital = 20000.0;

      final maxYieldBasket = CarryTradeOptimizer.optimizeBasket(
        capital,
        CarryStrategyType.maxYield,
      );
      expect(maxYieldBasket.isNotEmpty, isTrue);

      final totalWeight = maxYieldBasket.fold(0.0, (acc, a) => acc + a.weight);
      expect(totalWeight, closeTo(1.0, 0.001));

      final totalNotional =
          maxYieldBasket.fold(0.0, (acc, a) => acc + a.notionalAmount);
      expect(totalNotional, closeTo(capital, 0.01));

      final totalDailyCarry =
          maxYieldBasket.fold(0.0, (acc, a) => acc + a.expectedDailyCarry);
      expect(totalDailyCarry, greaterThan(0));

      final riskAdjustedBasket = CarryTradeOptimizer.optimizeBasket(
        capital,
        CarryStrategyType.riskAdjusted,
      );
      expect(riskAdjustedBasket.isNotEmpty, isTrue);

      final diversifiedBasket = CarryTradeOptimizer.optimizeBasket(
        capital,
        CarryStrategyType.diversified,
      );
      expect(diversifiedBasket.isNotEmpty, isTrue);
    });

    test('respects RISK_OFF macro regime during risk-adjusted optimization',
        () {
      final basket = CarryTradeOptimizer.optimizeBasket(
        10000.0,
        CarryStrategyType.riskAdjusted,
        macroRegime: 'RISK_OFF',
      );
      for (var alloc in basket) {
        expect(alloc.pair.unwindRisk, isNot(UnwindRiskLevel.extreme));
      }
    });

    test('supports copyWith on CurrencyCarryPair', () {
      final base = CarryTradeOptimizer.getCarryPairs().first;
      final updated = base.copyWith(currentPrice: 160.0);
      expect(updated.currentPrice, 160.0);
      expect(updated.symbol, base.symbol);
    });

    test('fetches live/delayed carry pairs from market data provider',
        () async {
      final livePairs = await CarryTradeOptimizer.fetchLiveCarryPairs();
      expect(livePairs.isNotEmpty, isTrue);
      for (var pair in livePairs) {
        expect(pair.currentPrice, greaterThan(0));
      }
    });
  });
}

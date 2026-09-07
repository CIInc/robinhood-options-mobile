import 'dart:math' as math;
import 'package:robinhood_options_mobile/services/yahoo_service.dart';

enum UnwindRiskLevel {
  low,
  moderate,
  elevated,
  extreme,
}

enum CarryPairCategory {
  major,
  cross,
  emerging,
}

enum CarryStrategyType {
  riskAdjusted,
  maxYield,
  diversified,
}

class CentralBankRate {
  final String currencyCode;
  final String countryOrRegion;
  final String centralBankName;
  final double rate;
  final String direction; // 'hiking', 'cutting', 'holding'
  final double inflationRate;
  final DateTime lastUpdated;

  const CentralBankRate({
    required this.currencyCode,
    required this.countryOrRegion,
    required this.centralBankName,
    required this.rate,
    required this.direction,
    required this.inflationRate,
    required this.lastUpdated,
  });

  double get realRate => rate - inflationRate;
}

class CurrencyCarryPair {
  final String symbol;
  final String baseCurrency;
  final String quoteCurrency;
  final double baseRate;
  final double quoteRate;
  final double currentPrice;
  final double volatility; // Annualized realized volatility %
  final double pipSize;
  final CarryPairCategory category;
  final double brokerSpreadHaircut;

  const CurrencyCarryPair({
    required this.symbol,
    required this.baseCurrency,
    required this.quoteCurrency,
    required this.baseRate,
    required this.quoteRate,
    required this.currentPrice,
    required this.volatility,
    this.pipSize = 0.0001,
    this.category = CarryPairCategory.major,
    this.brokerSpreadHaircut = 0.25, // 0.25% annual funding spread haircut
  });

  /// Net annualized carry yield if Long (Buy Base, Sell Quote)
  double get longNetYield => (baseRate - quoteRate) - brokerSpreadHaircut;

  /// Net annualized carry yield if Short (Sell Base, Buy Quote)
  double get shortNetYield => (quoteRate - baseRate) - brokerSpreadHaircut;

  /// Best direction to collect positive carry
  String get recommendedDirection =>
      longNetYield >= shortNetYield ? 'Buy' : 'Sell';

  /// Best net annualized carry percentage
  double get recommendedYield => math.max(longNetYield, shortNetYield);

  /// Risk-adjusted carry score (Carry-to-Risk ratio)
  double get carryToRiskRatio =>
      volatility > 0 ? (recommendedYield / volatility) : 0.0;

  /// Estimated daily swap income (USD) on a $10,000 notional position
  double get dailySwapPer10k {
    final annualReturn = 10000.0 * (recommendedYield / 100.0);
    return annualReturn / 365.0;
  }

  /// Estimated daily pip swap points on standard 10,000 unit contract
  double get dailyPipSwap {
    if (currentPrice <= 0 || pipSize <= 0) return 0.0;
    final dailyReturn = (10000.0 * (recommendedYield / 100.0)) / 365.0;
    final pipValueInQuote = pipSize * 10000.0;
    return pipValueInQuote > 0 ? (dailyReturn / pipValueInQuote) : 0.0;
  }

  /// Macro / unwind risk assessment
  UnwindRiskLevel get unwindRisk {
    // If quote or base is JPY or CHF and volatility > 10%
    final isLowYieldFunder = quoteCurrency == 'JPY' ||
        baseCurrency == 'JPY' ||
        quoteCurrency == 'CHF' ||
        baseCurrency == 'CHF';

    if (isLowYieldFunder && volatility >= 12.0) {
      return UnwindRiskLevel.extreme;
    } else if (isLowYieldFunder && volatility >= 9.5) {
      return UnwindRiskLevel.elevated;
    } else if (volatility >= 10.0 || category == CarryPairCategory.emerging) {
      return UnwindRiskLevel.moderate;
    }
    return UnwindRiskLevel.low;
  }

  CurrencyCarryPair copyWith({
    String? symbol,
    String? baseCurrency,
    String? quoteCurrency,
    double? baseRate,
    double? quoteRate,
    double? currentPrice,
    double? volatility,
    double? pipSize,
    CarryPairCategory? category,
    double? brokerSpreadHaircut,
  }) {
    return CurrencyCarryPair(
      symbol: symbol ?? this.symbol,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      quoteCurrency: quoteCurrency ?? this.quoteCurrency,
      baseRate: baseRate ?? this.baseRate,
      quoteRate: quoteRate ?? this.quoteRate,
      currentPrice: currentPrice ?? this.currentPrice,
      volatility: volatility ?? this.volatility,
      pipSize: pipSize ?? this.pipSize,
      category: category ?? this.category,
      brokerSpreadHaircut: brokerSpreadHaircut ?? this.brokerSpreadHaircut,
    );
  }
}

class CarryBasketAllocation {
  final CurrencyCarryPair pair;
  final String direction; // 'Buy' or 'Sell'
  final double weight; // 0.0 to 1.0
  final double notionalAmount;
  final double units;
  final double expectedAnnualCarry;
  final double expectedDailyCarry;

  const CarryBasketAllocation({
    required this.pair,
    required this.direction,
    required this.weight,
    required this.notionalAmount,
    required this.units,
    required this.expectedAnnualCarry,
    required this.expectedDailyCarry,
  });
}

class CarryTradeOptimizer {
  /// Benchmark Central Bank Policy Rates
  static List<CentralBankRate> getCentralBankRates() {
    final now = DateTime.now();
    return [
      CentralBankRate(
        currencyCode: 'USD',
        countryOrRegion: 'United States',
        centralBankName: 'Federal Reserve',
        rate: 5.25,
        direction: 'holding',
        inflationRate: 2.8,
        lastUpdated: now,
      ),
      CentralBankRate(
        currencyCode: 'EUR',
        countryOrRegion: 'Eurozone',
        centralBankName: 'European Central Bank',
        rate: 3.75,
        direction: 'cutting',
        inflationRate: 2.4,
        lastUpdated: now,
      ),
      CentralBankRate(
        currencyCode: 'GBP',
        countryOrRegion: 'United Kingdom',
        centralBankName: 'Bank of England',
        rate: 5.00,
        direction: 'cutting',
        inflationRate: 2.6,
        lastUpdated: now,
      ),
      CentralBankRate(
        currencyCode: 'JPY',
        countryOrRegion: 'Japan',
        centralBankName: 'Bank of Japan',
        rate: 0.25,
        direction: 'hiking',
        inflationRate: 2.7,
        lastUpdated: now,
      ),
      CentralBankRate(
        currencyCode: 'CHF',
        countryOrRegion: 'Switzerland',
        centralBankName: 'Swiss National Bank',
        rate: 1.25,
        direction: 'cutting',
        inflationRate: 1.3,
        lastUpdated: now,
      ),
      CentralBankRate(
        currencyCode: 'AUD',
        countryOrRegion: 'Australia',
        centralBankName: 'Reserve Bank of Australia',
        rate: 4.35,
        direction: 'holding',
        inflationRate: 3.8,
        lastUpdated: now,
      ),
      CentralBankRate(
        currencyCode: 'CAD',
        countryOrRegion: 'Canada',
        centralBankName: 'Bank of Canada',
        rate: 4.50,
        direction: 'cutting',
        inflationRate: 2.7,
        lastUpdated: now,
      ),
      CentralBankRate(
        currencyCode: 'NZD',
        countryOrRegion: 'New Zealand',
        centralBankName: 'Reserve Bank of New Zealand',
        rate: 5.25,
        direction: 'holding',
        inflationRate: 3.3,
        lastUpdated: now,
      ),
      CentralBankRate(
        currencyCode: 'MXN',
        countryOrRegion: 'Mexico',
        centralBankName: 'Banco de México',
        rate: 10.75,
        direction: 'cutting',
        inflationRate: 4.8,
        lastUpdated: now,
      ),
      CentralBankRate(
        currencyCode: 'BRL',
        countryOrRegion: 'Brazil',
        centralBankName: 'Banco Central do Brasil',
        rate: 10.50,
        direction: 'holding',
        inflationRate: 4.2,
        lastUpdated: now,
      ),
    ];
  }

  /// Supported Currency Pairs with Realized Volatility & Spot Rates
  static List<CurrencyCarryPair> getCarryPairs() {
    return [
      const CurrencyCarryPair(
        symbol: 'USD/JPY',
        baseCurrency: 'USD',
        quoteCurrency: 'JPY',
        baseRate: 5.25,
        quoteRate: 0.25,
        currentPrice: 154.20,
        volatility: 9.8,
        pipSize: 0.01,
        category: CarryPairCategory.major,
      ),
      const CurrencyCarryPair(
        symbol: 'AUD/JPY',
        baseCurrency: 'AUD',
        quoteCurrency: 'JPY',
        baseRate: 4.35,
        quoteRate: 0.25,
        currentPrice: 101.50,
        volatility: 8.6,
        pipSize: 0.01,
        category: CarryPairCategory.cross,
      ),
      const CurrencyCarryPair(
        symbol: 'NZD/JPY',
        baseCurrency: 'NZD',
        quoteCurrency: 'JPY',
        baseRate: 5.25,
        quoteRate: 0.25,
        currentPrice: 93.80,
        volatility: 8.9,
        pipSize: 0.01,
        category: CarryPairCategory.cross,
      ),
      const CurrencyCarryPair(
        symbol: 'GBP/JPY',
        baseCurrency: 'GBP',
        quoteCurrency: 'JPY',
        baseRate: 5.00,
        quoteRate: 0.25,
        currentPrice: 198.60,
        volatility: 9.2,
        pipSize: 0.01,
        category: CarryPairCategory.cross,
      ),
      const CurrencyCarryPair(
        symbol: 'USD/MXN',
        baseCurrency: 'USD',
        quoteCurrency: 'MXN',
        baseRate: 5.25,
        quoteRate: 10.75,
        currentPrice: 19.85,
        volatility: 12.4,
        pipSize: 0.0001,
        category: CarryPairCategory.emerging,
      ),
      const CurrencyCarryPair(
        symbol: 'EUR/USD',
        baseCurrency: 'EUR',
        quoteCurrency: 'USD',
        baseRate: 3.75,
        quoteRate: 5.25,
        currentPrice: 1.0850,
        volatility: 6.2,
        pipSize: 0.0001,
        category: CarryPairCategory.major,
      ),
      const CurrencyCarryPair(
        symbol: 'GBP/USD',
        baseCurrency: 'GBP',
        quoteCurrency: 'USD',
        baseRate: 5.00,
        quoteRate: 5.25,
        currentPrice: 1.2920,
        volatility: 7.1,
        pipSize: 0.0001,
        category: CarryPairCategory.major,
      ),
      const CurrencyCarryPair(
        symbol: 'USD/CHF',
        baseCurrency: 'USD',
        quoteCurrency: 'CHF',
        baseRate: 5.25,
        quoteRate: 1.25,
        currentPrice: 0.8840,
        volatility: 7.5,
        pipSize: 0.0001,
        category: CarryPairCategory.major,
      ),
      const CurrencyCarryPair(
        symbol: 'AUD/USD',
        baseCurrency: 'AUD',
        quoteCurrency: 'USD',
        baseRate: 4.35,
        quoteRate: 5.25,
        currentPrice: 0.6580,
        volatility: 8.2,
        pipSize: 0.0001,
        category: CarryPairCategory.major,
      ),
      const CurrencyCarryPair(
        symbol: 'USD/CAD',
        baseCurrency: 'USD',
        quoteCurrency: 'CAD',
        baseRate: 5.25,
        quoteRate: 4.50,
        currentPrice: 1.3780,
        volatility: 5.8,
        pipSize: 0.0001,
        category: CarryPairCategory.major,
      ),
    ];
  }

  /// Fetches live/delayed quotes for all supported carry pairs from Yahoo Finance,
  /// updating the current spot prices with real-time or delayed market data.
  static Future<List<CurrencyCarryPair>> fetchLiveCarryPairs({
    YahooService? yahooService,
  }) async {
    final basePairs = getCarryPairs();
    final service = yahooService ?? YahooService();

    try {
      final symbols = basePairs.map((p) => p.symbol).toList();
      final quotes = await service.getForexQuotesByIds(symbols);
      final quoteMap = {for (var q in quotes) q.symbol.toUpperCase(): q};

      return basePairs.map((pair) {
        final cleanSym = pair.symbol.replaceAll('/', '').toUpperCase();
        final quote = quoteMap[cleanSym];
        if (quote != null && (quote.markPrice ?? 0) > 0) {
          return pair.copyWith(
            currentPrice: quote.markPrice!,
          );
        }
        return pair;
      }).toList();
    } catch (_) {
      return basePairs;
    }
  }

  /// Optimize a diversified carry trade basket based on investment capital and strategy risk mode.
  static List<CarryBasketAllocation> optimizeBasket(
    double totalCapital,
    CarryStrategyType strategy, {
    List<CurrencyCarryPair>? pairs,
    String macroRegime = 'NEUTRAL',
  }) {
    if (totalCapital <= 0) return [];

    final allPairs = pairs ?? getCarryPairs();
    // Filter to positive net carry opportunities
    final positivePairs =
        allPairs.where((p) => p.recommendedYield > 0.5).toList();

    if (positivePairs.isEmpty) return [];

    List<CurrencyCarryPair> selectedPairs;
    List<double> rawWeights;

    switch (strategy) {
      case CarryStrategyType.maxYield:
        // Sort purely by net yield descending
        positivePairs
            .sort((a, b) => b.recommendedYield.compareTo(a.recommendedYield));
        selectedPairs = positivePairs.take(3).toList();
        rawWeights = selectedPairs.map((p) => p.recommendedYield).toList();
        break;

      case CarryStrategyType.riskAdjusted:
        // Sort by carry-to-risk ratio (Sharpe-like metric)
        positivePairs
            .sort((a, b) => b.carryToRiskRatio.compareTo(a.carryToRiskRatio));
        // Prefer lower unwind risk
        selectedPairs = positivePairs
            .where((p) => macroRegime == 'RISK_OFF'
                ? p.unwindRisk != UnwindRiskLevel.extreme
                : true)
            .take(4)
            .toList();
        if (selectedPairs.isEmpty) {
          selectedPairs = positivePairs.take(3).toList();
        }
        rawWeights = selectedPairs.map((p) => p.carryToRiskRatio).toList();
        break;

      case CarryStrategyType.diversified:
        // Select top pairs across different funding currencies (JPY, CHF, USD/MXN)
        final byFunding = <String, CurrencyCarryPair>{};
        for (var p in positivePairs) {
          final funding = p.recommendedDirection == 'Buy'
              ? p.quoteCurrency
              : p.baseCurrency;
          if (!byFunding.containsKey(funding) ||
              p.carryToRiskRatio > byFunding[funding]!.carryToRiskRatio) {
            byFunding[funding] = p;
          }
        }
        selectedPairs = byFunding.values.take(4).toList();
        // Equal or inverse-volatility weighting
        rawWeights = selectedPairs
            .map((p) => p.volatility > 0 ? (1.0 / p.volatility) : 1.0)
            .toList();
        break;
    }

    final sumRaw = rawWeights.fold(0.0, (a, b) => a + b);
    final normalizedWeights =
        sumRaw > 0 ? rawWeights.map((w) => w / sumRaw).toList() : [];

    final List<CarryBasketAllocation> allocations = [];
    for (int i = 0; i < selectedPairs.length; i++) {
      final pair = selectedPairs[i];
      final weight = normalizedWeights[i];
      final notional = totalCapital * weight;
      final units =
          pair.currentPrice > 0 ? (notional / pair.currentPrice) : 0.0;
      final annualCarry = notional * (pair.recommendedYield / 100.0);
      final dailyCarry = annualCarry / 365.0;

      allocations.add(
        CarryBasketAllocation(
          pair: pair,
          direction: pair.recommendedDirection,
          weight: weight,
          notionalAmount: notional,
          units: units,
          expectedAnnualCarry: annualCarry,
          expectedDailyCarry: dailyCarry,
        ),
      );
    }

    return allocations;
  }
}

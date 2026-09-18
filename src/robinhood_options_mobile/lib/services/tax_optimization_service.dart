import 'dart:math';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/capital_gains_model.dart';
import 'package:robinhood_options_mobile/model/form_8949_model.dart';
import 'package:robinhood_options_mobile/model/tax_harvesting_suggestion.dart';
import 'package:robinhood_options_mobile/model/wash_sale_record.dart';
import 'package:robinhood_options_mobile/model/tax_lot.dart';

class TaxOptimizationService {
  static double calculateEstimatedRealizedGains({
    required PortfolioHistoricals? portfolioHistoricals,
    required List<InstrumentPosition> instrumentPositions,
    required List<OptionAggregatePosition> optionPositions,
  }) {
    if (portfolioHistoricals == null ||
        portfolioHistoricals.totalReturn == null) {
      return 0.0;
    }

    // 1. Get Total Return (YTD/1Y)
    final totalReturn = portfolioHistoricals.totalReturn!;

    // 2. Calculate Total Unrealized P&L (Stocks + Options)
    double totalUnrealizedPnl = 0.0;

    for (var pos in instrumentPositions) {
      totalUnrealizedPnl += pos.gainLoss;
    }

    for (var pos in optionPositions) {
      totalUnrealizedPnl += pos.gainLoss;
    }

    return totalReturn - totalUnrealizedPnl;
  }

  static final Map<String, List<CorrelatedReplacement>>
      _curatedCorrelatedReplacements = {
    'SPY': const [
      CorrelatedReplacement(
        symbol: 'VOO',
        name: 'Vanguard S&P 500 ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale:
            'Direct S&P 500 substitute by Vanguard; different issuer and CUSIP safely avoids IRS wash sales.',
      ),
      CorrelatedReplacement(
        symbol: 'IVV',
        name: 'iShares Core S&P 500 ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale:
            'BlackRock S&P 500 ETF with identical market performance and low expense ratio.',
      ),
      CorrelatedReplacement(
        symbol: 'SPLG',
        name: 'SPDR Portfolio S&P 500 ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Ultra-low cost core large-cap S&P 500 index proxy.',
      ),
    ],
    'VOO': const [
      CorrelatedReplacement(
        symbol: 'SPY',
        name: 'SPDR S&P 500 ETF Trust',
        assetType: 'etf',
        correlation: 0.99,
        rationale:
            'High-liquidity State Street S&P 500 benchmark ETF substitute.',
      ),
      CorrelatedReplacement(
        symbol: 'IVV',
        name: 'iShares Core S&P 500 ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Core S&P 500 ETF from BlackRock with ~0.99 correlation.',
      ),
    ],
    'IVV': const [
      CorrelatedReplacement(
        symbol: 'VOO',
        name: 'Vanguard S&P 500 ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale:
            'Vanguard S&P 500 ETF alternative without wash sale violation.',
      ),
      CorrelatedReplacement(
        symbol: 'SPY',
        name: 'SPDR S&P 500 ETF Trust',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Primary S&P 500 benchmark tracker.',
      ),
    ],
    'QQQ': const [
      CorrelatedReplacement(
        symbol: 'QQQM',
        name: 'Invesco NASDAQ 100 ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale:
            'Lower-expense NASDAQ 100 share class; distinct security identifier avoids wash sale.',
      ),
      CorrelatedReplacement(
        symbol: 'VGT',
        name: 'Vanguard Information Tech ETF',
        assetType: 'etf',
        correlation: 0.95,
        rationale:
            'Tech-focused ETF offering heavy mega-cap technology exposure.',
      ),
      CorrelatedReplacement(
        symbol: 'XLK',
        name: 'Technology Select Sector SPDR',
        assetType: 'etf',
        correlation: 0.95,
        rationale: 'S&P 500 Technology sector index proxy.',
      ),
    ],
    'QQQM': const [
      CorrelatedReplacement(
        symbol: 'QQQ',
        name: 'Invesco QQQ Trust',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Flagship NASDAQ 100 ETF with high liquidity.',
      ),
      CorrelatedReplacement(
        symbol: 'VGT',
        name: 'Vanguard Information Tech ETF',
        assetType: 'etf',
        correlation: 0.95,
        rationale: 'Tech sector proxy maintaining growth exposure.',
      ),
    ],
    'VTI': const [
      CorrelatedReplacement(
        symbol: 'ITOT',
        name: 'iShares Core S&P Total U.S. Stock Market',
        assetType: 'etf',
        correlation: 0.99,
        rationale:
            'Tracks S&P Total Market Index; different index from CRSP avoids wash sale.',
      ),
      CorrelatedReplacement(
        symbol: 'SCHB',
        name: 'Schwab U.S. Broad Market ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale:
            'Tracks Dow Jones U.S. Broad Market Index with ~0.99 correlation.',
      ),
    ],
    'ITOT': const [
      CorrelatedReplacement(
        symbol: 'VTI',
        name: 'Vanguard Total Stock Market ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale:
            'Comprehensive total market alternative tracking CRSP US Total Market.',
      ),
      CorrelatedReplacement(
        symbol: 'SCHB',
        name: 'Schwab U.S. Broad Market ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Schwab broad market proxy.',
      ),
    ],
    'IWM': const [
      CorrelatedReplacement(
        symbol: 'VB',
        name: 'Vanguard Small-Cap ETF',
        assetType: 'etf',
        correlation: 0.97,
        rationale:
            'Tracks CRSP US Small Cap Index; different benchmark avoids wash sale.',
      ),
      CorrelatedReplacement(
        symbol: 'SCHA',
        name: 'Schwab U.S. Small-Cap ETF',
        assetType: 'etf',
        correlation: 0.97,
        rationale:
            'Schwab small cap proxy maintaining Russell-like factor exposure.',
      ),
      CorrelatedReplacement(
        symbol: 'IJR',
        name: 'iShares Core S&P Small-Cap 600',
        assetType: 'etf',
        correlation: 0.96,
        rationale: 'Small-cap benchmark with S&P profitability filter.',
      ),
    ],
    'DIA': const [
      CorrelatedReplacement(
        symbol: 'NOBL',
        name: 'ProShares S&P 500 Dividend Aristocrats',
        assetType: 'etf',
        correlation: 0.91,
        rationale: 'High-quality blue-chip dividend replacement for Dow 30.',
      ),
      CorrelatedReplacement(
        symbol: 'SPY',
        name: 'SPDR S&P 500 ETF Trust',
        assetType: 'etf',
        correlation: 0.93,
        rationale: 'Large-cap core US benchmark replacement.',
      ),
    ],
    'NVDA': const [
      CorrelatedReplacement(
        symbol: 'AMD',
        name: 'Advanced Micro Devices, Inc.',
        assetType: 'stock',
        correlation: 0.85,
        rationale:
            'Direct GPU and AI datacenter competitor without identical CUSIP.',
      ),
      CorrelatedReplacement(
        symbol: 'SMH',
        name: 'VanEck Semiconductor ETF',
        assetType: 'etf',
        correlation: 0.92,
        rationale:
            'Semiconductor industry ETF with top NVIDIA exposure; safe from wash sale.',
      ),
      CorrelatedReplacement(
        symbol: 'AVGO',
        name: 'Broadcom Inc.',
        assetType: 'stock',
        correlation: 0.81,
        rationale: 'Large-cap custom AI ASIC and semiconductor peer.',
      ),
    ],
    'AMD': const [
      CorrelatedReplacement(
        symbol: 'NVDA',
        name: 'NVIDIA Corporation',
        assetType: 'stock',
        correlation: 0.85,
        rationale: 'Leading AI accelerator and GPU competitor.',
      ),
      CorrelatedReplacement(
        symbol: 'SMH',
        name: 'VanEck Semiconductor ETF',
        assetType: 'etf',
        correlation: 0.93,
        rationale: 'Diversified semiconductor ETF keeping chip exposure.',
      ),
    ],
    'AAPL': const [
      CorrelatedReplacement(
        symbol: 'MSFT',
        name: 'Microsoft Corporation',
        assetType: 'stock',
        correlation: 0.80,
        rationale: 'Mega-cap consumer and enterprise platform peer.',
      ),
      CorrelatedReplacement(
        symbol: 'XLK',
        name: 'Technology Select Sector SPDR',
        assetType: 'etf',
        correlation: 0.88,
        rationale:
            'Tech sector ETF with prominent Apple weighting and high correlation.',
      ),
      CorrelatedReplacement(
        symbol: 'VGT',
        name: 'Vanguard Information Tech ETF',
        assetType: 'etf',
        correlation: 0.87,
        rationale: 'Broad tech index proxy.',
      ),
    ],
    'MSFT': const [
      CorrelatedReplacement(
        symbol: 'AAPL',
        name: 'Apple Inc.',
        assetType: 'stock',
        correlation: 0.80,
        rationale: 'Mega-cap technology platform peer.',
      ),
      CorrelatedReplacement(
        symbol: 'GOOGL',
        name: 'Alphabet Inc.',
        assetType: 'stock',
        correlation: 0.82,
        rationale: 'Enterprise cloud, productivity, and AI peer.',
      ),
      CorrelatedReplacement(
        symbol: 'XLK',
        name: 'Technology Select Sector SPDR',
        assetType: 'etf',
        correlation: 0.89,
        rationale: 'Technology sector ETF with major Microsoft allocation.',
      ),
    ],
    'GOOGL': const [
      CorrelatedReplacement(
        symbol: 'META',
        name: 'Meta Platforms, Inc.',
        assetType: 'stock',
        correlation: 0.84,
        rationale: 'Digital advertising and generative AI platform peer.',
      ),
      CorrelatedReplacement(
        symbol: 'XLC',
        name: 'Communication Services Select SPDR',
        assetType: 'etf',
        correlation: 0.89,
        rationale:
            'Communications sector ETF holding Alphabet as a top weight.',
      ),
    ],
    'GOOG': const [
      CorrelatedReplacement(
        symbol: 'META',
        name: 'Meta Platforms, Inc.',
        assetType: 'stock',
        correlation: 0.84,
        rationale: 'Digital advertising and AI platform peer.',
      ),
      CorrelatedReplacement(
        symbol: 'XLC',
        name: 'Communication Services Select SPDR',
        assetType: 'etf',
        correlation: 0.89,
        rationale:
            'Communications sector ETF holding Alphabet as a top weight.',
      ),
    ],
    'META': const [
      CorrelatedReplacement(
        symbol: 'GOOGL',
        name: 'Alphabet Inc.',
        assetType: 'stock',
        correlation: 0.84,
        rationale: 'Digital ad duopoly peer and AI competitor.',
      ),
      CorrelatedReplacement(
        symbol: 'XLC',
        name: 'Communication Services Select SPDR',
        assetType: 'etf',
        correlation: 0.90,
        rationale: 'Sector ETF with primary Meta exposure.',
      ),
    ],
    'AMZN': const [
      CorrelatedReplacement(
        symbol: 'XLY',
        name: 'Consumer Discretionary Select SPDR',
        assetType: 'etf',
        correlation: 0.86,
        rationale: 'Consumer discretionary ETF with massive Amazon weighting.',
      ),
      CorrelatedReplacement(
        symbol: 'MSFT',
        name: 'Microsoft Corporation',
        assetType: 'stock',
        correlation: 0.78,
        rationale: 'Hyperscale cloud (AWS vs Azure) competitor.',
      ),
      CorrelatedReplacement(
        symbol: 'WMT',
        name: 'Walmart Inc.',
        assetType: 'stock',
        correlation: 0.65,
        rationale: 'Omnichannel retail and e-commerce leader.',
      ),
    ],
    'TSLA': const [
      CorrelatedReplacement(
        symbol: 'RIVN',
        name: 'Rivian Automotive, Inc.',
        assetType: 'stock',
        correlation: 0.72,
        rationale: 'Pure-play electric vehicle and software-defined auto peer.',
      ),
      CorrelatedReplacement(
        symbol: 'CARZ',
        name: 'First Trust NASDAQ Global Auto ETF',
        assetType: 'etf',
        correlation: 0.75,
        rationale: 'Automotive and clean mobility sector ETF.',
      ),
      CorrelatedReplacement(
        symbol: 'XLY',
        name: 'Consumer Discretionary Select SPDR',
        assetType: 'etf',
        correlation: 0.78,
        rationale: 'Consumer discretionary ETF with top Tesla allocation.',
      ),
    ],
    'JPM': const [
      CorrelatedReplacement(
        symbol: 'BAC',
        name: 'Bank of America Corp.',
        assetType: 'stock',
        correlation: 0.91,
        rationale: 'Direct money-center commercial banking peer.',
      ),
      CorrelatedReplacement(
        symbol: 'XLF',
        name: 'Financial Select Sector SPDR',
        assetType: 'etf',
        correlation: 0.93,
        rationale: 'Financial sector ETF with heavy JPMorgan weighting.',
      ),
    ],
    'BAC': const [
      CorrelatedReplacement(
        symbol: 'JPM',
        name: 'JPMorgan Chase & Co.',
        assetType: 'stock',
        correlation: 0.91,
        rationale: 'Top US money-center bank peer.',
      ),
      CorrelatedReplacement(
        symbol: 'XLF',
        name: 'Financial Select Sector SPDR',
        assetType: 'etf',
        correlation: 0.93,
        rationale: 'Financial sector benchmark ETF.',
      ),
    ],
    'XOM': const [
      CorrelatedReplacement(
        symbol: 'CVX',
        name: 'Chevron Corporation',
        assetType: 'stock',
        correlation: 0.90,
        rationale: 'Integrated energy supermajor peer.',
      ),
      CorrelatedReplacement(
        symbol: 'XLE',
        name: 'Energy Select Sector SPDR',
        assetType: 'etf',
        correlation: 0.94,
        rationale: 'Broad energy sector ETF with Exxon as top holding.',
      ),
    ],
    'CVX': const [
      CorrelatedReplacement(
        symbol: 'XOM',
        name: 'Exxon Mobil Corporation',
        assetType: 'stock',
        correlation: 0.90,
        rationale: 'Integrated energy supermajor peer.',
      ),
      CorrelatedReplacement(
        symbol: 'XLE',
        name: 'Energy Select Sector SPDR',
        assetType: 'etf',
        correlation: 0.94,
        rationale: 'Broad energy sector ETF.',
      ),
    ],
    'SMH': const [
      CorrelatedReplacement(
        symbol: 'SOXX',
        name: 'iShares Semiconductor ETF',
        assetType: 'etf',
        correlation: 0.97,
        rationale:
            'Modified market-cap semiconductor index substitute; different index avoids wash sale.',
      ),
      CorrelatedReplacement(
        symbol: 'XSD',
        name: 'SPDR S&P Semiconductor ETF',
        assetType: 'etf',
        correlation: 0.91,
        rationale: 'Equal-weighted semiconductor index ETF.',
      ),
    ],
    'SOXX': const [
      CorrelatedReplacement(
        symbol: 'SMH',
        name: 'VanEck Semiconductor ETF',
        assetType: 'etf',
        correlation: 0.97,
        rationale: 'Semiconductor ETF alternative.',
      ),
    ],
    'XLK': const [
      CorrelatedReplacement(
        symbol: 'VGT',
        name: 'Vanguard Information Tech ETF',
        assetType: 'etf',
        correlation: 0.98,
        rationale: 'Vanguard tech ETF with broader software and hardware mix.',
      ),
      CorrelatedReplacement(
        symbol: 'FTEC',
        name: 'Fidelity MSCI Information Tech ETF',
        assetType: 'etf',
        correlation: 0.98,
        rationale: 'Low-expense MSCI tech index ETF.',
      ),
    ],
    'XLE': const [
      CorrelatedReplacement(
        symbol: 'VDE',
        name: 'Vanguard Energy ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Vanguard energy sector replacement ETF.',
      ),
      CorrelatedReplacement(
        symbol: 'XOP',
        name: 'SPDR S&P Oil & Gas Exploration ETF',
        assetType: 'etf',
        correlation: 0.92,
        rationale: 'Upstream exploration and production proxy.',
      ),
    ],
    'XLF': const [
      CorrelatedReplacement(
        symbol: 'VFH',
        name: 'Vanguard Financials ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Vanguard broad financials sector ETF.',
      ),
      CorrelatedReplacement(
        symbol: 'KBE',
        name: 'SPDR S&P Bank ETF',
        assetType: 'etf',
        correlation: 0.93,
        rationale: 'Bank-focused ETF proxy.',
      ),
    ],
    'XLV': const [
      CorrelatedReplacement(
        symbol: 'VHT',
        name: 'Vanguard Health Care ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Vanguard healthcare sector replacement ETF.',
      ),
    ],
    'XLI': const [
      CorrelatedReplacement(
        symbol: 'VIS',
        name: 'Vanguard Industrials ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Vanguard industrials sector replacement ETF.',
      ),
    ],
    'XLY': const [
      CorrelatedReplacement(
        symbol: 'VCR',
        name: 'Vanguard Consumer Discretionary ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Consumer discretionary alternative ETF.',
      ),
    ],
    'XLP': const [
      CorrelatedReplacement(
        symbol: 'VDC',
        name: 'Vanguard Consumer Staples ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Consumer staples sector alternative ETF.',
      ),
    ],
    'XLU': const [
      CorrelatedReplacement(
        symbol: 'VPU',
        name: 'Vanguard Utilities ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Utilities sector alternative ETF.',
      ),
    ],
    'XLRE': const [
      CorrelatedReplacement(
        symbol: 'VNQ',
        name: 'Vanguard Real Estate ETF',
        assetType: 'etf',
        correlation: 0.98,
        rationale: 'Comprehensive US REIT and real estate ETF.',
      ),
    ],
    'TLT': const [
      CorrelatedReplacement(
        symbol: 'SPTL',
        name: 'SPDR Portfolio Long Term Treasury ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Long-duration Treasury bond ETF proxy.',
      ),
      CorrelatedReplacement(
        symbol: 'IEF',
        name: 'iShares 7-10 Year Treasury Bond ETF',
        assetType: 'etf',
        correlation: 0.92,
        rationale: 'Intermediate Treasury alternative.',
      ),
    ],
    'GLD': const [
      CorrelatedReplacement(
        symbol: 'IAU',
        name: 'iShares Gold Trust',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'BlackRock physical gold trust substitute.',
      ),
      CorrelatedReplacement(
        symbol: 'SGOL',
        name: 'abrdn Physical Gold Shares ETF',
        assetType: 'etf',
        correlation: 0.99,
        rationale: 'Physically backed gold shares alternative.',
      ),
    ],
    'COIN': const [
      CorrelatedReplacement(
        symbol: 'BITO',
        name: 'ProShares Bitcoin Strategy ETF',
        assetType: 'etf',
        correlation: 0.85,
        rationale: 'Regulated digital asset ETF maintaining crypto beta.',
      ),
      CorrelatedReplacement(
        symbol: 'MARA',
        name: 'MARA Holdings, Inc.',
        assetType: 'stock',
        correlation: 0.82,
        rationale: 'Bitcoin mining and digital infrastructure peer.',
      ),
    ],
  };

  /// Returns curated or sector-derived correlated replacements for a ticker symbol
  /// to maintain market exposure while safely avoiding IRS Section 1091 wash sales.
  static List<CorrelatedReplacement> getCorrelatedReplacements(
    String symbol, {
    String? sector,
  }) {
    final upper = symbol.toUpperCase().trim();
    if (_curatedCorrelatedReplacements.containsKey(upper)) {
      return _curatedCorrelatedReplacements[upper]!;
    }

    // Sector-based heuristics
    final sec = sector?.toLowerCase() ?? '';
    if (sec.contains('tech') ||
        sec.contains('software') ||
        sec.contains('semiconductor')) {
      return const [
        CorrelatedReplacement(
          symbol: 'XLK',
          name: 'Technology Select Sector SPDR',
          assetType: 'etf',
          correlation: 0.82,
          rationale:
              'Technology sector ETF; maintains tech exposure safely without wash sale.',
        ),
        CorrelatedReplacement(
          symbol: 'QQQ',
          name: 'Invesco QQQ Trust',
          assetType: 'etf',
          correlation: 0.80,
          rationale: 'Broad tech-heavy NASDAQ 100 proxy.',
        ),
      ];
    } else if (sec.contains('finan') || sec.contains('bank')) {
      return const [
        CorrelatedReplacement(
          symbol: 'XLF',
          name: 'Financial Select Sector SPDR',
          assetType: 'etf',
          correlation: 0.84,
          rationale: 'Financials sector ETF providing sector diversification.',
        ),
      ];
    } else if (sec.contains('energy') ||
        sec.contains('oil') ||
        sec.contains('gas')) {
      return const [
        CorrelatedReplacement(
          symbol: 'XLE',
          name: 'Energy Select Sector SPDR',
          assetType: 'etf',
          correlation: 0.85,
          rationale:
              'Energy sector ETF maintaining commodity/upstream exposure.',
        ),
      ];
    } else if (sec.contains('health') ||
        sec.contains('bio') ||
        sec.contains('pharma')) {
      return const [
        CorrelatedReplacement(
          symbol: 'XLV',
          name: 'Health Care Select Sector SPDR',
          assetType: 'etf',
          correlation: 0.82,
          rationale: 'Healthcare sector ETF providing sector risk exposure.',
        ),
      ];
    } else if (sec.contains('consumer')) {
      return const [
        CorrelatedReplacement(
          symbol: 'XLY',
          name: 'Consumer Discretionary Select SPDR',
          assetType: 'etf',
          correlation: 0.80,
          rationale: 'Consumer discretionary ETF proxy.',
        ),
      ];
    }

    // Default core index fallback
    return [
      CorrelatedReplacement(
        symbol: 'VOO',
        name: 'Vanguard S&P 500 ETF',
        assetType: 'etf',
        correlation: 0.75,
        rationale:
            'Broad US Large-Cap equity replacement; maintains market exposure while avoiding wash sale on $upper.',
      ),
      CorrelatedReplacement(
        symbol: 'VTI',
        name: 'Vanguard Total Stock Market ETF',
        assetType: 'etf',
        correlation: 0.75,
        rationale: 'Comprehensive US total market index replacement.',
      ),
    ];
  }

  /// Scans unrealized losses across equity and options positions against realized
  /// capital gains, models tax offsets and IRS $3,000 ordinary income deduction,
  /// and provides correlated replacement recommendations to avoid wash sales.
  static TaxHarvestingScanResult scanTaxLossHarvestingOpportunities({
    required List<InstrumentPosition> instrumentPositions,
    required List<OptionAggregatePosition> optionPositions,
    PortfolioHistoricals? portfolioHistoricals,
    double? realizedCapitalGains,
    double effectiveTaxRate = 0.29, // Default 24% federal + 5% state blend
    String assetFilter = 'all', // 'all', 'stock', 'option'
    double minLossThreshold = 0.0, // Minimum loss threshold (e.g. 0, 100, 500)
    String sortBy = 'loss', // 'loss', 'percent', 'tax_savings'
  }) {
    // 1. Calculate Realized Capital Gains if not explicitly provided
    final resolvedRealizedGains = realizedCapitalGains ??
        calculateEstimatedRealizedGains(
          portfolioHistoricals: portfolioHistoricals,
          instrumentPositions: instrumentPositions,
          optionPositions: optionPositions,
        );

    final normalizedRealizedGains = max(0.0, resolvedRealizedGains);

    // 2. Scan all candidate positions
    final allSuggestions = <TaxHarvestingSuggestion>[];
    int totalScanned = 0;

    // Scan Stocks
    for (var pos in instrumentPositions) {
      if (pos.quantity != null &&
          pos.quantity! > 0 &&
          pos.averageBuyPrice != null) {
        totalScanned++;
        if (pos.gainLoss < 0) {
          final sym = pos.instrumentObj?.symbol ?? 'Unknown';
          final name = pos.instrumentObj?.name ?? 'Unknown';
          final loss = pos.gainLoss;
          final cost = pos.totalCost;
          final lossPct = cost > 0 ? (loss.abs() / cost) : 0.0;
          final estTaxSavings = loss.abs() * effectiveTaxRate;
          final replacements = getCorrelatedReplacements(
            sym,
            sector: pos.instrumentObj?.fundamentalsObj?.sector,
          );

          allSuggestions.add(TaxHarvestingSuggestion(
            symbol: sym,
            name: name,
            quantity: pos.quantity!,
            averageBuyPrice: pos.averageBuyPrice!,
            currentPrice:
                (pos.quantity! > 0) ? (pos.marketValue / pos.quantity!) : 0,
            estimatedLoss: loss,
            totalCost: cost,
            type: 'stock',
            position: pos,
            replacements: replacements,
            taxSavingsEstimate: estTaxSavings,
            lossPercentage: lossPct,
          ));
        }
      }
    }

    // Scan Options
    for (var pos in optionPositions) {
      if (pos.quantity != null &&
          pos.quantity! > 0 &&
          pos.averageOpenPrice != null) {
        totalScanned++;
        double estimatedLoss = 0;
        if (pos.direction == 'debit') {
          if (pos.gainLoss < 0) {
            estimatedLoss = pos.gainLoss;
          }
        } else {
          if (pos.gainLoss > 0) {
            estimatedLoss = -pos.gainLoss;
          }
        }

        if (estimatedLoss < 0) {
          final sym = pos.symbol;
          final name = pos.optionInstrument?.chainSymbol ?? pos.symbol;
          final cost = pos.totalCost;
          final lossPct = cost > 0 ? (estimatedLoss.abs() / cost) : 0.0;
          final estTaxSavings = estimatedLoss.abs() * effectiveTaxRate;
          final replacements = getCorrelatedReplacements(sym);

          allSuggestions.add(TaxHarvestingSuggestion(
            symbol: sym,
            name: name,
            quantity: pos.quantity!,
            averageBuyPrice: pos.averageOpenPrice!,
            currentPrice: (pos.quantity! > 0)
                ? (pos.marketValue / (pos.quantity! * 100))
                : 0,
            estimatedLoss: estimatedLoss,
            totalCost: cost,
            type: 'option',
            position: pos,
            replacements: replacements,
            taxSavingsEstimate: estTaxSavings,
            lossPercentage: lossPct,
          ));
        }
      }
    }

    // 3. Compute Aggregate Financial & Tax Mechanics (IRS Schedule D Rules)
    final totalUnrealizedLoss = allSuggestions.fold<double>(
        0.0, (sum, item) => sum + item.estimatedLoss); // Negative value
    final absLoss = totalUnrealizedLoss.abs();

    // Gain offset: capital losses first offset realized capital gains $1 for $1
    final gainsOffset = min(normalizedRealizedGains, absLoss);
    final remainingLoss = absLoss - gainsOffset;

    // IRS Section 1211 limit: up to $3,000 net capital loss deductible against ordinary income
    final ordinaryIncomeUsed = min(3000.0, remainingLoss);
    final carryforward = remainingLoss - ordinaryIncomeUsed;

    // Total tax base reduced = gains offset + ordinary income deduction
    final totalTaxReliefBase = gainsOffset + ordinaryIncomeUsed;
    final totalTaxSavings = totalTaxReliefBase * effectiveTaxRate;

    final netGainsAfterHarvest = max(0.0, normalizedRealizedGains - absLoss);

    // 4. Apply Filters to Displayed Suggestions
    var filtered = allSuggestions.where((item) {
      if (assetFilter == 'stock' && item.type != 'stock') return false;
      if (assetFilter == 'option' && item.type != 'option') return false;
      if (minLossThreshold > 0 && item.estimatedLoss.abs() < minLossThreshold) {
        return false;
      }
      return true;
    }).toList();

    // 5. Apply Sorting
    switch (sortBy) {
      case 'percent':
        filtered.sort((a, b) => b.lossPercentage.compareTo(a.lossPercentage));
        break;
      case 'tax_savings':
        filtered.sort((a, b) =>
            (b.taxSavingsEstimate ?? 0).compareTo(a.taxSavingsEstimate ?? 0));
        break;
      case 'loss':
      default:
        // Largest loss first (most negative estimatedLoss first)
        filtered.sort((a, b) => a.estimatedLoss.compareTo(b.estimatedLoss));
        break;
    }

    return TaxHarvestingScanResult(
      totalUnrealizedLoss: totalUnrealizedLoss,
      realizedCapitalGains: normalizedRealizedGains,
      netGainsAfterHarvest: netGainsAfterHarvest,
      capitalLossDeductionUsed: ordinaryIncomeUsed,
      capitalLossCarryforward: carryforward,
      estimatedTaxSavings: totalTaxSavings,
      effectiveTaxRate: effectiveTaxRate,
      suggestions: filtered,
      totalScannedPositions: totalScanned,
    );
  }

  static List<TaxHarvestingSuggestion> calculateTaxHarvestingOpportunities({
    required List<InstrumentPosition> instrumentPositions,
    required List<OptionAggregatePosition> optionPositions,
  }) {
    final scanResult = scanTaxLossHarvestingOpportunities(
      instrumentPositions: instrumentPositions,
      optionPositions: optionPositions,
    );
    return scanResult.suggestions;
  }

  /// Detects wash sales and active 30-day restriction windows per IRS Section 1091.
  ///
  /// Evaluates closed orders, open positions, and optional historical/initial records
  /// across equities and substantially identical options contracts.
  static List<WashSaleRecord> detectWashSales({
    List<InstrumentOrder> stockOrders = const [],
    List<OptionOrder> optionOrders = const [],
    List<InstrumentPosition> instrumentPositions = const [],
    List<OptionAggregatePosition> optionPositions = const [],
    List<WashSaleRecord>? initialRecords,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final results = <WashSaleRecord>[];
    final processedRecordIds = <String>{};

    // 1. Incorporate and evaluate initial or recorded wash sale entries
    if (initialRecords != null) {
      for (final record in initialRecords) {
        WashSaleRecord updated = record;

        // Check if active record was replaced by subsequent stock or option orders
        if (record.status == WashSaleStatus.activeWindow) {
          // Check stock replacement buy orders
          final stockReplacements = stockOrders.where((order) {
            final symbol = order.instrumentObj?.symbol.toUpperCase();
            if (symbol != record.symbol.toUpperCase()) return false;
            final isBuy = order.side.toLowerCase() == 'buy';
            final orderDate = order.createdAt ?? order.updatedAt;
            if (orderDate == null) return false;
            return isBuy &&
                orderDate.isAfter(record.windowStartDate) &&
                orderDate.isBefore(
                    record.windowEndDate.add(const Duration(days: 1))) &&
                (order.state.toLowerCase() == 'filled' ||
                    order.state.toLowerCase() == 'confirmed');
          }).toList();

          // Check option replacement buy orders (Call options or ITM contracts to acquire stock)
          final optionReplacements = optionOrders.where((order) {
            final symbol = order.chainSymbol.toUpperCase();
            if (symbol != record.symbol.toUpperCase()) return false;
            final isBuy = order.direction.toLowerCase() == 'debit';
            final orderDate = order.createdAt ?? order.updatedAt;
            if (orderDate == null) return false;
            return isBuy &&
                orderDate.isAfter(record.windowStartDate) &&
                orderDate.isBefore(
                    record.windowEndDate.add(const Duration(days: 1))) &&
                (order.state.toLowerCase() == 'filled' ||
                    order.state.toLowerCase() == 'confirmed');
          }).toList();

          if (stockReplacements.isNotEmpty) {
            final rep = stockReplacements.first;
            final repQty = rep.cumulativeQuantity ?? rep.quantity ?? 1.0;
            final repPrice = rep.averagePrice ?? rep.price ?? 0.0;
            final disallowed = min(
                record.realizedLoss.abs(),
                record.realizedLoss.abs() *
                    (repQty / max(record.quantitySold, 1.0)));
            updated = WashSaleRecord(
              id: record.id,
              symbol: record.symbol,
              name: record.name,
              assetType: record.assetType,
              saleDate: record.saleDate,
              salePrice: record.salePrice,
              quantitySold: record.quantitySold,
              realizedLoss: record.realizedLoss,
              windowStartDate: record.windowStartDate,
              windowEndDate: record.windowEndDate,
              status: WashSaleStatus.disallowed,
              replacementDate: rep.createdAt ?? rep.updatedAt,
              replacementPrice: repPrice,
              replacementQuantity: repQty,
              replacementAssetType: 'stock',
              disallowedLoss: disallowed,
              adjustedCostBasis: (repPrice * repQty) + disallowed,
            );
          } else if (optionReplacements.isNotEmpty) {
            final rep = optionReplacements.first;
            final repQty = rep.processedQuantity ?? rep.quantity ?? 1.0;
            final repPrice = rep.processedPremium != null
                ? rep.processedPremium! / (repQty * 100)
                : (rep.price ?? 0.0);
            final disallowed = record.realizedLoss.abs();
            updated = WashSaleRecord(
              id: record.id,
              symbol: record.symbol,
              name: record.name,
              assetType: record.assetType,
              saleDate: record.saleDate,
              salePrice: record.salePrice,
              quantitySold: record.quantitySold,
              realizedLoss: record.realizedLoss,
              windowStartDate: record.windowStartDate,
              windowEndDate: record.windowEndDate,
              status: WashSaleStatus.disallowed,
              replacementDate: rep.createdAt ?? rep.updatedAt,
              replacementPrice: repPrice,
              replacementQuantity: repQty,
              replacementAssetType: 'option',
              disallowedLoss: disallowed,
              adjustedCostBasis: (repPrice * repQty * 100) + disallowed,
            );
          } else if (now.isAfter(record.windowEndDate)) {
            updated = WashSaleRecord(
              id: record.id,
              symbol: record.symbol,
              name: record.name,
              assetType: record.assetType,
              saleDate: record.saleDate,
              salePrice: record.salePrice,
              quantitySold: record.quantitySold,
              realizedLoss: record.realizedLoss,
              windowStartDate: record.windowStartDate,
              windowEndDate: record.windowEndDate,
              status: WashSaleStatus.cleared,
            );
          }
        }

        results.add(updated);
        processedRecordIds.add(updated.id);
      }
    }

    // 2. Scan stock orders for executed loss sales
    final filledStockOrders = stockOrders
        .where((o) =>
            (o.state.toLowerCase() == 'filled' ||
                o.state.toLowerCase() == 'confirmed') &&
            (o.createdAt != null || o.updatedAt != null))
        .toList();

    // Map recent buy orders to compare cost basis
    final buyOrdersBySymbol = <String, List<InstrumentOrder>>{};
    for (final order in filledStockOrders) {
      if (order.side.toLowerCase() == 'buy') {
        final symbol = order.instrumentObj?.symbol.toUpperCase();
        if (symbol != null) {
          buyOrdersBySymbol.putIfAbsent(symbol, () => []).add(order);
        }
      }
    }

    // Analyze sell orders
    for (final sellOrder in filledStockOrders) {
      if (sellOrder.side.toLowerCase() != 'sell') continue;
      final symbol = sellOrder.instrumentObj?.symbol.toUpperCase();
      if (symbol == null) continue;

      final saleDate = sellOrder.createdAt ?? sellOrder.updatedAt!;
      final windowStart = saleDate.subtract(const Duration(days: 30));
      final windowEnd = saleDate.add(const Duration(days: 30));

      final sellPrice = sellOrder.averagePrice ?? sellOrder.price ?? 0.0;
      final sellQty = sellOrder.cumulativeQuantity ?? sellOrder.quantity ?? 0.0;
      if (sellQty <= 0 || sellPrice <= 0) continue;

      // Find preceding buy order to determine cost basis
      final priorBuys = (buyOrdersBySymbol[symbol] ?? []).where((b) {
        final bDate = b.createdAt ?? b.updatedAt;
        return bDate != null && bDate.isBefore(saleDate);
      }).toList();

      double buyPrice = 0.0;
      if (priorBuys.isNotEmpty) {
        buyPrice = priorBuys.last.averagePrice ?? priorBuys.last.price ?? 0.0;
      }

      // Check if sold at a loss
      if (buyPrice > 0 && sellPrice < buyPrice) {
        final loss = (sellPrice - buyPrice) * sellQty; // Negative
        final recordId =
            'wash_sale_${symbol}_${saleDate.millisecondsSinceEpoch}';

        if (processedRecordIds.contains(recordId)) continue;

        // Check for replacement buy in window [windowStart, windowEnd]
        final replacementBuys = (buyOrdersBySymbol[symbol] ?? []).where((b) {
          final bDate = b.createdAt ?? b.updatedAt;
          if (bDate == null) return false;
          return bDate.isAfter(saleDate) &&
              bDate.isBefore(windowEnd.add(const Duration(days: 1)));
        }).toList();

        final replacementOptionBuys = optionOrders.where((o) {
          final oSymbol = o.chainSymbol.toUpperCase();
          if (oSymbol != symbol) return false;
          final oDate = o.createdAt ?? o.updatedAt;
          if (oDate == null) return false;
          return o.direction.toLowerCase() == 'debit' &&
              oDate.isAfter(saleDate) &&
              oDate.isBefore(windowEnd.add(const Duration(days: 1))) &&
              (o.state.toLowerCase() == 'filled' ||
                  o.state.toLowerCase() == 'confirmed');
        }).toList();

        if (replacementBuys.isNotEmpty) {
          final rep = replacementBuys.first;
          final repQty = rep.cumulativeQuantity ?? rep.quantity ?? 1.0;
          final repPrice = rep.averagePrice ?? rep.price ?? 0.0;
          final disallowed = min(loss.abs(), loss.abs() * (repQty / sellQty));

          results.add(WashSaleRecord(
            id: recordId,
            symbol: symbol,
            name: sellOrder.instrumentObj?.name ?? symbol,
            assetType: 'stock',
            saleDate: saleDate,
            salePrice: sellPrice,
            quantitySold: sellQty,
            realizedLoss: loss,
            windowStartDate: windowStart,
            windowEndDate: windowEnd,
            status: WashSaleStatus.disallowed,
            replacementDate: rep.createdAt ?? rep.updatedAt,
            replacementPrice: repPrice,
            replacementQuantity: repQty,
            replacementAssetType: 'stock',
            disallowedLoss: disallowed,
            adjustedCostBasis: (repPrice * repQty) + disallowed,
          ));
        } else if (replacementOptionBuys.isNotEmpty) {
          final rep = replacementOptionBuys.first;
          final repQty = rep.processedQuantity ?? rep.quantity ?? 1.0;
          final repPrice = rep.processedPremium != null
              ? rep.processedPremium! / (repQty * 100)
              : (rep.price ?? 0.0);
          final disallowed = loss.abs();

          results.add(WashSaleRecord(
            id: recordId,
            symbol: symbol,
            name: sellOrder.instrumentObj?.name ?? symbol,
            assetType: 'stock',
            saleDate: saleDate,
            salePrice: sellPrice,
            quantitySold: sellQty,
            realizedLoss: loss,
            windowStartDate: windowStart,
            windowEndDate: windowEnd,
            status: WashSaleStatus.disallowed,
            replacementDate: rep.createdAt ?? rep.updatedAt,
            replacementPrice: repPrice,
            replacementQuantity: repQty,
            replacementAssetType: 'option',
            disallowedLoss: disallowed,
            adjustedCostBasis: (repPrice * repQty * 100) + disallowed,
          ));
        } else {
          final isCleared = now.isAfter(windowEnd);
          results.add(WashSaleRecord(
            id: recordId,
            symbol: symbol,
            name: sellOrder.instrumentObj?.name ?? symbol,
            assetType: 'stock',
            saleDate: saleDate,
            salePrice: sellPrice,
            quantitySold: sellQty,
            realizedLoss: loss,
            windowStartDate: windowStart,
            windowEndDate: windowEnd,
            status: isCleared
                ? WashSaleStatus.cleared
                : WashSaleStatus.activeWindow,
          ));
        }
        processedRecordIds.add(recordId);
      }
    }

    // Sort: Active windows first (fewest days left first), then Disallowed (highest loss first), then Cleared
    results.sort((a, b) {
      if (a.isWindowActive(now) && !b.isWindowActive(now)) return -1;
      if (!a.isWindowActive(now) && b.isWindowActive(now)) return 1;
      if (a.isDisallowed && !b.isDisallowed) return -1;
      if (!a.isDisallowed && b.isDisallowed) return 1;
      if (a.isWindowActive(now) && b.isWindowActive(now)) {
        return a.getDaysRemaining(now).compareTo(b.getDaysRemaining(now));
      }
      return (b.disallowedLoss ?? b.realizedLoss.abs())
          .compareTo(a.disallowedLoss ?? a.realizedLoss.abs());
    });

    return results;
  }

  static List<WashSaleRecord> getActiveWashSaleWindows(
    List<WashSaleRecord> records, [
    DateTime? asOf,
  ]) {
    return records.where((r) => r.isWindowActive(asOf)).toList();
  }

  static List<WashSaleRecord> getDisallowedWashSales(
    List<WashSaleRecord> records,
  ) {
    return records.where((r) => r.isDisallowed).toList();
  }

  static String getSeasonalityMessage() {
    final now = DateTime.now();
    if (now.month == 12) {
      return "Urgent: End of tax year approaching. Harvest losses now to offset this year's gains.";
    } else if (now.month >= 10) {
      return "Tax season is approaching. Consider harvesting losses to optimize your tax liability.";
    } else {
      return "Monitor these positions for potential tax loss harvesting opportunities throughout the year.";
    }
  }

  // 0: Low, 1: Medium, 2: High
  static int getSeasonalityUrgency() {
    final now = DateTime.now();
    if (now.month == 12) {
      return 2;
    } else if (now.month >= 10) {
      return 1;
    } else {
      return 0;
    }
  }

  /// Analyzes open equity and option positions for Short-Term vs. Long-Term
  /// capital gains tax treatment, holding duration countdown timers, and tax liability projections.
  static CapitalGainsSummary analyzeCapitalGains({
    required List<InstrumentPosition> instrumentPositions,
    required List<OptionAggregatePosition> optionPositions,
    DateTime? asOf,
    double shortTermTaxRate = 0.24,
    double longTermTaxRate = 0.15,
  }) {
    final now = asOf ?? DateTime.now();
    final capitalGainPositions = <CapitalGainPosition>[];

    // 1. Process Stocks
    for (var pos in instrumentPositions) {
      if (pos.quantity != null &&
          pos.quantity! > 0 &&
          pos.averageBuyPrice != null) {
        final symbol = pos.instrumentObj?.symbol ?? 'Unknown';
        final name = pos.instrumentObj?.name ?? symbol;
        final acquiredDate = pos.createdAt ?? pos.updatedAt ?? now;
        final costBasis = pos.totalCost;
        final marketVal = pos.marketValue;
        final gainLoss = pos.gainLoss;
        final gainLossPct = costBasis > 0 ? (gainLoss / costBasis) : 0.0;
        final currentPrice =
            (pos.quantity! > 0) ? (marketVal / pos.quantity!) : 0.0;

        capitalGainPositions.add(CapitalGainPosition.create(
          id: 'stock_${pos.instrumentId}_${acquiredDate.millisecondsSinceEpoch}',
          symbol: symbol,
          name: name,
          quantity: pos.quantity!,
          averageCostPrice: pos.averageBuyPrice!,
          totalCost: costBasis,
          currentPrice: currentPrice,
          marketValue: marketVal,
          gainLoss: gainLoss,
          gainLossPercent: gainLossPct,
          type: 'stock',
          acquiredDate: acquiredDate,
          asOf: now,
          shortTermTaxRate: shortTermTaxRate,
          longTermTaxRate: longTermTaxRate,
          underlyingPosition: pos,
        ));
      }
    }

    // 2. Process Options
    for (var pos in optionPositions) {
      if (pos.quantity != null &&
          pos.quantity! > 0 &&
          pos.averageOpenPrice != null) {
        final symbol = pos.symbol;
        final name = pos.optionInstrument?.chainSymbol ?? pos.symbol;
        final acquiredDate = pos.createdAt ?? pos.updatedAt ?? now;
        final costBasis = pos.totalCost;
        final marketVal = pos.marketValue;
        double gainLoss = 0.0;
        if (pos.direction == 'debit') {
          gainLoss = pos.gainLoss;
        } else {
          gainLoss = -pos.gainLoss;
        }
        final gainLossPct = costBasis > 0 ? (gainLoss / costBasis) : 0.0;
        final currentPrice =
            (pos.quantity! > 0) ? (marketVal / (pos.quantity! * 100)) : 0.0;

        capitalGainPositions.add(CapitalGainPosition.create(
          id: 'option_${pos.id}_${acquiredDate.millisecondsSinceEpoch}',
          symbol: symbol,
          name: name,
          quantity: pos.quantity!,
          averageCostPrice: pos.averageOpenPrice!,
          totalCost: costBasis,
          currentPrice: currentPrice,
          marketValue: marketVal,
          gainLoss: gainLoss,
          gainLossPercent: gainLossPct,
          type: 'option',
          acquiredDate: acquiredDate,
          asOf: now,
          shortTermTaxRate: shortTermTaxRate,
          longTermTaxRate: longTermTaxRate,
          underlyingPosition: pos,
        ));
      }
    }

    return CapitalGainsSummary.fromPositions(
      positions: capitalGainPositions,
      shortTermTaxRate: shortTermTaxRate,
      longTermTaxRate: longTermTaxRate,
    );
  }

  /// Reconciles realized stock and option dispositions into IRS Form 8949
  /// (Part I Short-Term & Part II Long-Term), matches disallowed wash sale losses
  /// with adjustment code 'W', and computes Schedule D summary totals.
  static Form8949Reconciliation reconcileForm8949({
    List<InstrumentOrder> stockOrders = const [],
    List<OptionOrder> optionOrders = const [],
    List<WashSaleRecord> washSales = const [],
    List<Form8949Entry>? initialEntries,
    int? taxYear,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final entries = <Form8949Entry>[];

    // If initialEntries provided, incorporate them
    if (initialEntries != null && initialEntries.isNotEmpty) {
      for (final e in initialEntries) {
        if (taxYear == null || e.soldDate.year == taxYear) {
          entries.add(e);
        }
      }
    }

    // 1. Process filled stock sell orders
    final filledStockOrders = stockOrders
        .where((o) =>
            (o.state.toLowerCase() == 'filled' ||
                o.state.toLowerCase() == 'confirmed') &&
            (o.createdAt != null || o.updatedAt != null))
        .toList();

    // Map buy orders by symbol to match cost basis & acquisition dates
    final buyOrdersBySymbol = <String, List<InstrumentOrder>>{};
    for (final order in filledStockOrders) {
      if (order.side.toLowerCase() == 'buy') {
        final sym = order.instrumentObj?.symbol.toUpperCase();
        if (sym != null) {
          buyOrdersBySymbol.putIfAbsent(sym, () => []).add(order);
        }
      }
    }

    // Map wash sales by symbol
    final washSalesBySymbol = <String, List<WashSaleRecord>>{};
    for (final ws in washSales) {
      washSalesBySymbol.putIfAbsent(ws.symbol.toUpperCase(), () => []).add(ws);
    }

    for (final sell in filledStockOrders) {
      if (sell.side.toLowerCase() != 'sell') continue;
      final sym = sell.instrumentObj?.symbol.toUpperCase();
      if (sym == null) continue;

      final saleDate = sell.createdAt ?? sell.updatedAt ?? now;
      if (taxYear != null && saleDate.year != taxYear) continue;

      final sellQty = sell.cumulativeQuantity ?? sell.quantity ?? 0.0;
      final sellPrice = sell.averagePrice ?? sell.price ?? 0.0;
      if (sellQty <= 0 || sellPrice <= 0) continue;

      final proceeds = sellPrice * sellQty;

      // Find prior buy orders for acquisition date and cost basis
      final priorBuys = (buyOrdersBySymbol[sym] ?? []).where((b) {
        final bDate = b.createdAt ?? b.updatedAt;
        return bDate != null && bDate.isBefore(saleDate);
      }).toList();

      DateTime acquiredDate;
      double costPrice;
      if (priorBuys.isNotEmpty) {
        final buy = priorBuys.last;
        acquiredDate = buy.createdAt ??
            buy.updatedAt ??
            saleDate.subtract(const Duration(days: 90));
        costPrice = buy.averagePrice ?? buy.price ?? sellPrice;
      } else {
        acquiredDate = saleDate.subtract(const Duration(days: 120));
        costPrice = sellPrice;
      }

      final costBasis = costPrice * sellQty;

      // Check wash sales matching this sale
      String? adjCode;
      double adjAmount = 0.0;
      String? wsId;

      final matchingWs = (washSalesBySymbol[sym] ?? []).where((ws) {
        return ws.isDisallowed &&
            saleDate.difference(ws.saleDate).inDays.abs() <= 2;
      }).toList();

      if (matchingWs.isNotEmpty) {
        final ws = matchingWs.first;
        adjCode = 'W';
        adjAmount = ws.disallowedLoss ?? ws.realizedLoss.abs();
        wsId = ws.id;
      }

      final sharesText = sellQty == sellQty.roundToDouble()
          ? '${sellQty.toInt()}'
          : sellQty.toStringAsFixed(2);
      final desc = '$sharesText sh. $sym';

      entries.add(Form8949Entry.create(
        id: 'form8949_stock_${sell.id}',
        description: desc,
        symbol: sym,
        assetType: 'stock',
        quantity: sellQty,
        acquiredDate: acquiredDate,
        soldDate: saleDate,
        proceeds: proceeds,
        costBasis: costBasis,
        adjustmentCode: adjCode,
        adjustmentAmount: adjAmount,
        washSaleRecordId: wsId,
      ));
    }

    // 2. Process filled closing option orders
    final filledOptionOrders = optionOrders
        .where((o) =>
            (o.state.toLowerCase() == 'filled' ||
                o.state.toLowerCase() == 'confirmed') &&
            (o.createdAt != null || o.updatedAt != null))
        .toList();

    // Map debit/buy options by chainSymbol
    final openOptionOrdersBySymbol = <String, List<OptionOrder>>{};
    for (final order in filledOptionOrders) {
      if (order.direction.toLowerCase() == 'debit') {
        final sym = order.chainSymbol.toUpperCase();
        openOptionOrdersBySymbol.putIfAbsent(sym, () => []).add(order);
      }
    }

    for (final order in filledOptionOrders) {
      if (order.direction.toLowerCase() != 'credit') continue;
      final sym = order.chainSymbol.toUpperCase();
      final saleDate = order.createdAt ?? order.updatedAt ?? now;
      if (taxYear != null && saleDate.year != taxYear) continue;

      final qty = order.processedQuantity ?? order.quantity ?? 1.0;
      final proceeds = order.processedPremium ??
          (order.price != null ? order.price! * qty * 100 : 0.0);
      if (proceeds <= 0 && (order.price ?? 0) <= 0) continue;

      final priorDebits = (openOptionOrdersBySymbol[sym] ?? []).where((b) {
        final bDate = b.createdAt ?? b.updatedAt;
        return bDate != null && bDate.isBefore(saleDate);
      }).toList();

      DateTime acquiredDate;
      double costBasis;
      if (priorDebits.isNotEmpty) {
        final debit = priorDebits.last;
        acquiredDate = debit.createdAt ??
            debit.updatedAt ??
            saleDate.subtract(const Duration(days: 30));
        costBasis = debit.processedPremium ??
            (debit.price != null ? debit.price! * qty * 100 : proceeds);
      } else {
        acquiredDate = saleDate.subtract(const Duration(days: 45));
        costBasis = proceeds;
      }

      String? adjCode;
      double adjAmount = 0.0;
      String? wsId;

      final matchingWs = (washSalesBySymbol[sym] ?? []).where((ws) {
        return ws.isDisallowed &&
            saleDate.difference(ws.saleDate).inDays.abs() <= 2;
      }).toList();

      if (matchingWs.isNotEmpty) {
        final ws = matchingWs.first;
        adjCode = 'W';
        adjAmount = ws.disallowedLoss ?? ws.realizedLoss.abs();
        wsId = ws.id;
      }

      final contractDesc = order.legs.isNotEmpty
          ? '${qty.toInt()} $sym ${order.legs.first.strikePrice != null ? "\$${order.legs.first.strikePrice!.toStringAsFixed(1)} " : ""}${order.legs.first.optionType.toUpperCase()}'
          : '${qty.toInt()} $sym Option';

      entries.add(Form8949Entry.create(
        id: 'form8949_option_${order.id}',
        description: contractDesc,
        symbol: sym,
        assetType: 'option',
        quantity: qty,
        acquiredDate: acquiredDate,
        soldDate: saleDate,
        proceeds: proceeds,
        costBasis: costBasis,
        adjustmentCode: adjCode,
        adjustmentAmount: adjAmount,
        washSaleRecordId: wsId,
      ));
    }

    // 3. Fallback demo data if no entries found from live orders and initialEntries wasn't supplied
    if (entries.isEmpty && initialEntries == null) {
      final demoEntries = getDemoForm8949Entries(asOf: now, taxYear: taxYear);
      entries.addAll(demoEntries);
    }

    // 4. Partition into Part I (Short-Term) and Part II (Long-Term)
    final shortTerm = entries.where((e) => !e.isLongTerm).toList();
    final longTerm = entries.where((e) => e.isLongTerm).toList();

    // Sort by soldDate descending
    shortTerm.sort((a, b) => b.soldDate.compareTo(a.soldDate));
    longTerm.sort((a, b) => b.soldDate.compareTo(a.soldDate));

    final stTotals = Form8949Totals.fromEntries(shortTerm);
    final ltTotals = Form8949Totals.fromEntries(longTerm);
    final grandTotals = Form8949Totals.fromEntries(entries);

    final washSaleTotal = entries
        .where((e) => e.adjustmentCode == 'W')
        .fold<double>(0.0, (sum, e) => sum + e.adjustmentAmount);

    return Form8949Reconciliation(
      taxYear: taxYear,
      generatedAt: now,
      shortTermEntries: shortTerm,
      longTermEntries: longTerm,
      shortTermTotals: stTotals,
      longTermTotals: ltTotals,
      grandTotals: grandTotals,
      totalWashSaleDisallowed: washSaleTotal,
    );
  }

  /// Provides realistic sample dispositions for IRS Form 8949 demonstration and testing.
  static List<Form8949Entry> getDemoForm8949Entries({
    DateTime? asOf,
    int? taxYear,
  }) {
    final now = asOf ?? DateTime.now();
    final targetYear = taxYear ?? now.year;

    final demo = <Form8949Entry>[
      // Short-Term Gain (AAPL)
      Form8949Entry.create(
        id: 'demo_8949_1',
        description: '15 sh. AAPL',
        symbol: 'AAPL',
        assetType: 'stock',
        quantity: 15,
        acquiredDate: DateTime(targetYear, 2, 10),
        soldDate: DateTime(targetYear, 6, 15),
        proceeds: 3375.0, // $225/sh
        costBasis: 2850.0, // $190/sh
        // Gain = +$525
      ),
      // Short-Term Loss with Wash Sale Code W (NVDA)
      Form8949Entry.create(
        id: 'demo_8949_2',
        description: '20 sh. NVDA',
        symbol: 'NVDA',
        assetType: 'stock',
        quantity: 20,
        acquiredDate: DateTime(targetYear, 3, 5),
        soldDate: DateTime(targetYear, 5, 20),
        proceeds: 2200.0, // $110/sh
        costBasis: 2600.0, // $130/sh (Tentative loss = -$400)
        adjustmentCode: 'W',
        adjustmentAmount: 400.0, // Disallowed wash sale
        // Reconciled gain/loss = $2200 - $2600 + $400 = $0.00
      ),
      // Short-Term Option Gain (SPY Call)
      Form8949Entry.create(
        id: 'demo_8949_3',
        description: '2 SPY 10/16/2026 550 Call',
        symbol: 'SPY',
        assetType: 'option',
        quantity: 2,
        acquiredDate: DateTime(targetYear, 4, 1),
        soldDate: DateTime(targetYear, 7, 10),
        proceeds: 1450.0,
        costBasis: 900.0,
        // Gain = +$550
      ),
      // Long-Term Gain (MSFT)
      Form8949Entry.create(
        id: 'demo_8949_4',
        description: '25 sh. MSFT',
        symbol: 'MSFT',
        assetType: 'stock',
        quantity: 25,
        acquiredDate: DateTime(targetYear - 2, 8, 15),
        soldDate: DateTime(targetYear, 8, 25),
        proceeds: 11250.0, // $450/sh
        costBasis: 7750.0, // $310/sh
        // Long-term gain = +$3500
      ),
      // Long-Term Loss (TSLA)
      Form8949Entry.create(
        id: 'demo_8949_5',
        description: '10 sh. TSLA',
        symbol: 'TSLA',
        assetType: 'stock',
        quantity: 10,
        acquiredDate: DateTime(targetYear - 2, 1, 12),
        soldDate: DateTime(targetYear, 4, 18),
        proceeds: 1800.0, // $180/sh
        costBasis: 2400.0, // $240/sh
        // Long-term loss = -$600
      ),
    ];

    return demo;
  }

  /// Evaluates and applies a tax lot disposition strategy against available lots
  /// for a specified order quantity and current price.
  ///
  /// Computes allocated shares, cost basis, realized gains/losses, tax liability,
  /// and tax savings compared to default FIFO execution.
  static TaxLotAllocation applyTaxLotStrategy({
    required List<TaxLot> lots,
    required TaxLotStrategy strategy,
    required double orderQuantity,
    required double currentPrice,
    Map<String, double>? manualAllocations,
    double shortTermTaxRate = 0.24,
    double longTermTaxRate = 0.15,
  }) {
    final eligibleLots = lots
        .where((l) => l.isSelectable && l.quantityAvailable > 0)
        .toList();

    // 1. Calculate baseline FIFO allocation to determine baseline tax liability
    final fifoAllocatedLots = _allocateGreedy(
      lots: List<TaxLot>.from(eligibleLots)..sort((a, b) => a.openDate.compareTo(b.openDate)),
      orderQuantity: orderQuantity,
    );
    final fifoLiability = _calculateTaxLiability(
      fifoAllocatedLots,
      currentPrice,
      shortTermTaxRate: shortTermTaxRate,
      longTermTaxRate: longTermTaxRate,
    );

    // 2. Sort or map lots based on requested strategy
    List<AllocatedLot> targetAllocatedLots;

    if (strategy == TaxLotStrategy.specified && manualAllocations != null) {
      targetAllocatedLots = [];
      for (final lot in eligibleLots) {
        final assigned = manualAllocations[lot.openLotId] ?? 0.0;
        if (assigned > 0) {
          final alloc = min(assigned, lot.quantityAvailable);
          targetAllocatedLots.add(AllocatedLot(lot: lot, allocatedQuantity: alloc));
        }
      }
    } else {
      final sorted = List<TaxLot>.from(eligibleLots);
      switch (strategy) {
        case TaxLotStrategy.fifo:
          // Oldest first
          sorted.sort((a, b) => a.openDate.compareTo(b.openDate));
          break;
        case TaxLotStrategy.lifo:
          // Newest first
          sorted.sort((a, b) => b.openDate.compareTo(a.openDate));
          break;
        case TaxLotStrategy.hifo:
          // Highest cost per share first (max loss / min gain)
          sorted.sort((a, b) {
            final cmp = b.costPerShare.compareTo(a.costPerShare);
            return cmp != 0 ? cmp : a.openDate.compareTo(b.openDate);
          });
          break;
        case TaxLotStrategy.lofo:
          // Lowest cost per share first (max gain)
          sorted.sort((a, b) {
            final cmp = a.costPerShare.compareTo(b.costPerShare);
            return cmp != 0 ? cmp : a.openDate.compareTo(b.openDate);
          });
          break;
        case TaxLotStrategy.taxMinimizer:
          // Prioritize:
          // 1. Short-term losses (highest cost first)
          // 2. Long-term losses (highest cost first)
          // 3. Long-term gains (lowest gain / highest cost first)
          // 4. Short-term gains (lowest gain / highest cost first)
          sorted.sort((a, b) {
            int score(TaxLot l) {
              final loss = l.costPerShare > currentPrice;
              if (loss && l.isShortTerm) return 1;
              if (loss && l.isLongTerm) return 2;
              if (!loss && l.isLongTerm) return 3;
              return 4; // Short-term gain
            }

            final scoreA = score(a);
            final scoreB = score(b);
            if (scoreA != scoreB) return scoreA.compareTo(scoreB);
            // Within the same bucket, highest cost per share first
            return b.costPerShare.compareTo(a.costPerShare);
          });
          break;
        case TaxLotStrategy.specified:
          sorted.sort((a, b) => a.openDate.compareTo(b.openDate));
          break;
      }
      targetAllocatedLots = _allocateGreedy(lots: sorted, orderQuantity: orderQuantity);
    }

    // 3. Compute allocation metrics
    double totalAllocated = 0.0;
    double totalCostBasis = 0.0;
    double stGainLoss = 0.0;
    double ltGainLoss = 0.0;

    for (final al in targetAllocatedLots) {
      totalAllocated += al.allocatedQuantity;
      totalCostBasis += al.costBasis;
      final gl = al.gainLoss(currentPrice);
      if (al.isLongTerm) {
        ltGainLoss += gl;
      } else {
        stGainLoss += gl;
      }
    }

    final avgCost = totalAllocated > 0 ? totalCostBasis / totalAllocated : 0.0;
    final proceeds = currentPrice * totalAllocated;
    final totalRealizedGainLoss = proceeds - totalCostBasis;

    final targetLiability = _calculateTaxLiability(
      targetAllocatedLots,
      currentPrice,
      shortTermTaxRate: shortTermTaxRate,
      longTermTaxRate: longTermTaxRate,
    );

    // Savings = FIFO liability - Target liability (when positive)
    final savings = max(0.0, fifoLiability - targetLiability);

    return TaxLotAllocation(
      strategy: strategy,
      allocatedLots: targetAllocatedLots,
      totalAllocatedQuantity: totalAllocated,
      totalCostBasis: totalCostBasis,
      averageCostPerShare: avgCost,
      estimatedProceeds: proceeds,
      estimatedRealizedGainLoss: totalRealizedGainLoss,
      shortTermGainLoss: stGainLoss,
      longTermGainLoss: ltGainLoss,
      estimatedTaxLiability: targetLiability,
      taxSavingsVsFifo: savings,
    );
  }

  static List<AllocatedLot> _allocateGreedy({
    required List<TaxLot> lots,
    required double orderQuantity,
  }) {
    final result = <AllocatedLot>[];
    double remaining = orderQuantity;

    for (final lot in lots) {
      if (remaining <= 0) break;
      final toTake = min(remaining, lot.quantityAvailable);
      if (toTake > 0) {
        result.add(AllocatedLot(lot: lot, allocatedQuantity: toTake));
        remaining -= toTake;
      }
    }
    return result;
  }

  static double _calculateTaxLiability(
    List<AllocatedLot> lots,
    double currentPrice, {
    required double shortTermTaxRate,
    required double longTermTaxRate,
  }) {
    double stGain = 0.0;
    double ltGain = 0.0;

    for (final al in lots) {
      final gl = al.gainLoss(currentPrice);
      if (al.isLongTerm) {
        ltGain += gl;
      } else {
        stGain += gl;
      }
    }

    final stTax = stGain > 0 ? stGain * shortTermTaxRate : 0.0;
    final ltTax = ltGain > 0 ? ltGain * longTermTaxRate : 0.0;
    return stTax + ltTax;
  }

  /// Generates synthetic, deterministic tax lots for an equity position
  /// to support paper trading, demo mode, and offline modeling.
  static List<TaxLot> generateMockTaxLots(
    String symbol,
    double currentPrice,
    double totalQuantity,
  ) {
    if (totalQuantity <= 0) return [];

    final now = DateTime.now();
    final lots = <TaxLot>[];

    if (totalQuantity <= 10) {
      // Single lot
      final buyPrice = currentPrice * 0.95;
      lots.add(
        TaxLot(
          openLotId: 'mock_${symbol.toLowerCase()}_lot_1',
          symbol: symbol,
          quantity: totalQuantity,
          quantityAvailable: totalQuantity,
          costPerShare: buyPrice,
          taxCostBasis: buyPrice * totalQuantity,
          openDate: now.subtract(const Duration(days: 45)),
          term: 'st',
        ),
      );
      return lots;
    }

    // Split across 3 distinct lots with varied cost basis and holding periods
    final qty1 = (totalQuantity * 0.4).roundToDouble();
    final qty2 = (totalQuantity * 0.35).roundToDouble();
    final qty3 = totalQuantity - qty1 - qty2;

    // Lot 1: Acquired 14 months ago (Long-term gain)
    final p1 = currentPrice * 0.82;
    lots.add(
      TaxLot(
        openLotId: 'mock_${symbol.toLowerCase()}_lot_1',
        symbol: symbol,
        quantity: qty1,
        quantityAvailable: qty1,
        costPerShare: p1,
        taxCostBasis: p1 * qty1,
        openDate: now.subtract(const Duration(days: 420)),
        term: 'lt',
      ),
    );

    // Lot 2: Acquired 3 months ago at higher price (Short-term loss / harvest opportunity)
    final p2 = currentPrice * 1.15;
    lots.add(
      TaxLot(
        openLotId: 'mock_${symbol.toLowerCase()}_lot_2',
        symbol: symbol,
        quantity: qty2,
        quantityAvailable: qty2,
        costPerShare: p2,
        taxCostBasis: p2 * qty2,
        openDate: now.subtract(const Duration(days: 90)),
        term: 'st',
      ),
    );

    if (qty3 > 0) {
      // Lot 3: Acquired 3 weeks ago near current price (Short-term minor gain)
      final p3 = currentPrice * 0.98;
      lots.add(
        TaxLot(
          openLotId: 'mock_${symbol.toLowerCase()}_lot_3',
          symbol: symbol,
          quantity: qty3,
          quantityAvailable: qty3,
          costPerShare: p3,
          taxCostBasis: p3 * qty3,
          openDate: now.subtract(const Duration(days: 21)),
          term: 'st',
        ),
      );
    }

    return lots;
  }
}


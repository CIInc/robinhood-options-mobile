import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';

class TradeSignalsProvider with ChangeNotifier {
  /// Returns documentation for a given indicator key.
  /// Returns a Map with 'title', 'description', and 'technicalDetails' keys.
  static Map<String, String> indicatorDocumentation(String key) {
    switch (key) {
      case 'priceMovement':
        return {
          'title': 'Price Movement',
          'description':
              'Analyzes recent price trends and chart patterns to identify bullish or bearish momentum. '
                  'Uses moving averages and price action to determine if the stock is in an uptrend (BUY), '
                  'downtrend (SELL), or sideways movement (HOLD).',
          'technicalDetails': '**Multi-pattern technical analysis** detecting 7 chart patterns:\n'
              '\n'
              '- **Breakout/Breakdown**: Price crosses `20-period MA` by ±2% with volume confirmation (1.3x avg)\n'
              '- **Double Top/Bottom**: Two similar peaks/troughs within 1% tolerance\n'
              '- **Head & Shoulders**: 3 peaks with middle highest, shoulders ±2% tolerance\n'
              '- **Triangles**: Ascending (flat highs, rising lows) or Descending (falling highs, flat lows)\n'
              '- **Cup & Handle**: Recovery from 10-bar handle, 5% above low, `MA5 > MA10`\n'
              '- **Bull/Bear Flags**: Sharp move (6%+) followed by tight consolidation (<1.5%)\n'
              '\n'
              '**Parameters**: 30-60 bar lookback with `MA5`, `MA10`, `MA20`.\n'
              '**Trigger**: Pattern confidence ≥60%'
        };
      case 'momentum':
        return {
          'title': 'Momentum (RSI)',
          'description':
              'Relative Strength Index (RSI) measures the speed and magnitude of price changes. '
                  'Values above 70 indicate overbought conditions (potential SELL), while values below 30 '
                  'indicate oversold conditions (potential BUY). RSI between 30-70 suggests neutral momentum.',
          'technicalDetails':
              '**Formula**: `RSI = 100 - (100 / (1 + RS))` where `RS = Avg Gain / Avg Loss`\n'
                  '\n'
                  '**Parameters**:\n'
                  '- Period: `14 bars` (smoothed using Wilder\'s method)\n'
                  '\n'
                  '**Thresholds**:\n'
                  '- **Oversold**: `RSI < 30` → BUY signal\n'
                  '- **Overbought**: `RSI > 70` → SELL signal\n'
                  '- **Bullish momentum**: `RSI 60-70` → BUY\n'
                  '- **Bearish momentum**: `RSI 30-40` → SELL\n'
                  '\n'
                  '**Divergence Detection** (requires 20+ bars):\n'
                  '- **Bullish**: Price falling (-1%) but RSI rising (+3) when `RSI < 50`\n'
                  '- **Bearish**: Price rising (+1%) but RSI falling (-3) when `RSI > 50`\n'
                  '\n'
                  '_Note: Divergence signals override standard thresholds._'
        };
      case 'marketDirection':
        return {
          'title': 'Market Direction',
          'description':
              'Evaluates the overall market trend using moving averages on major indices (SPY/QQQ). '
                  'When the market index is trending up (fast MA > slow MA), stocks tend to perform better (BUY). '
                  'When the market is trending down, it suggests caution (SELL/HOLD).',
          'technicalDetails': '**Moving Averages**:\n'
              '- Fast MA: `10-period SMA`\n'
              '- Slow MA: `30-period SMA`\n'
              '\n'
              '**Trend Strength**: `((Fast MA - Slow MA) / Slow MA) × 100`\n'
              '\n'
              '**Signals**:\n'
              '- **Bullish Crossover**: Fast MA crosses above Slow MA → BUY\n'
              '- **Bearish Crossover**: Fast MA crosses below Slow MA → SELL\n'
              '- **Strong Uptrend**: Trend strength > +2% → BUY\n'
              '- **Strong Downtrend**: Trend strength < -2% → SELL\n'
              '- **Neutral**: -2% ≤ Trend strength ≤ +2% → HOLD\n'
              '\n'
              '_Market correlation helps confirm individual stock signals._'
        };
      case 'volume':
        return {
          'title': 'Volume',
          'description':
              'Confirms price movements with trading volume. Strong price moves with high volume are more '
                  'reliable. BUY signals require increasing volume on up days, SELL signals require volume on down days. '
                  'Low volume suggests weak conviction and generates HOLD signals.',
          'technicalDetails': '**Formula**: `Volume Ratio = Current Volume / 20-period Avg Volume`\n'
              '\n'
              '**Signals**:\n'
              '- **Accumulation** (BUY): Volume ratio `> 1.5` with price increase `> 0.5%`\n'
              '- **Distribution** (SELL): Volume ratio `> 1.5` with price decrease `> 0.5%`\n'
              '- **Low Volume** (HOLD): Volume ratio `< 0.7` indicates weak conviction\n'
              '- **Confirmed Trend**: Normal volume (0.9-1.5x) with price change `> 1%` → BUY\n'
              '- **Neutral**: Volume ratio 0.7-1.5x without strong price movement\n'
              '\n'
              '_High volume confirms trend strength; low volume suggests wait for confirmation._'
        };
      case 'macd':
        return {
          'title': 'MACD',
          'description':
              'Moving Average Convergence Divergence (MACD) shows the relationship between two moving averages. '
                  'When the MACD line crosses above the signal line, it generates a BUY signal. When MACD crosses below the signal line, '
                  'it generates a SELL signal. The histogram shows the strength of the trend.',
          'technicalDetails': '**Components**:\n'
              '- Fast EMA: `12-period`\n'
              '- Slow EMA: `26-period`\n'
              '- Signal Line: `9-period EMA` of MACD\n'
              '\n'
              '**Formulas**:\n'
              '- `MACD Line = Fast EMA - Slow EMA`\n'
              '- `Histogram = MACD Line - Signal Line`\n'
              '\n'
              '**Signals**:\n'
              '- **Bullish Crossover**: Histogram crosses above `0` → BUY\n'
              '- **Bearish Crossover**: Histogram crosses below `0` → SELL\n'
              '- **Bullish Momentum**: Histogram `> 0` → BUY\n'
              '- **Bearish Momentum**: Histogram `< 0` → SELL\n'
              '\n'
              '_Minimum 35 periods (26 + 9) required. Histogram magnitude indicates momentum strength._'
        };
      case 'bollingerBands':
        return {
          'title': 'Bollinger Bands',
          'description':
              'Volatility indicator using standard deviations around a moving average. Price near the lower band '
                  'suggests oversold conditions (potential BUY), while price near the upper band suggests overbought (potential SELL). '
                  'Price in the middle suggests neutral conditions. Band width indicates volatility levels.',
          'technicalDetails': '**Band Calculation**:\n'
              '- Middle Band: `20-period SMA`\n'
              '- Upper Band: `Middle + (2 × StdDev)`\n'
              '- Lower Band: `Middle - (2 × StdDev)`\n'
              '- StdDev: Sample standard deviation (N-1 denominator)\n'
              '\n'
              '**Position Formula**: `(Price - Lower) / (Upper - Lower) × 100`\n'
              '\n'
              '**Signals**:\n'
              '- **Oversold**: Price ≤ Lower Band (±0.5%) → BUY\n'
              '- **Overbought**: Price ≥ Upper Band (±0.5%) → SELL\n'
              '- **Lower Region**: Position `< 30%` → BUY\n'
              '- **Upper Region**: Position `> 70%` → SELL\n'
              '- **Neutral**: `30% ≤ Position ≤ 70%` → HOLD\n'
              '\n'
              '_Band width indicates volatility: narrow = low vol, wide = high vol._'
        };
      case 'stochastic':
        return {
          'title': 'Stochastic',
          'description':
              'Stochastic Oscillator compares the closing price to its price range over a period. Values above 80 indicate '
                  'overbought conditions (potential SELL), below 20 indicates oversold (potential BUY). Crossovers of %K and %D '
                  'lines provide additional signals. Works best in ranging markets.',
          'technicalDetails': '**Parameters**:\n'
              '- %K Period: `14 bars`\n'
              '- %D Period: `3 bars` (SMA of %K)\n'
              '\n'
              '**Formulas**:\n'
              '- `%K = ((Close - Lowest Low) / (Highest High - Lowest Low)) × 100`\n'
              '- `%D = 3-period SMA of %K values`\n'
              '\n'
              '**Signals**:\n'
              '- **Oversold**: `%K < 20` and `%D < 20` → BUY\n'
              '- **Overbought**: `%K > 80` and `%D > 80` → SELL\n'
              '- **Bullish Crossover**: %K crosses above %D in oversold region → BUY\n'
              '- **Bearish Crossover**: %K crosses below %D in overbought region → SELL\n'
              '- **Neutral**: `20 ≤ %K ≤ 80` → HOLD\n'
              '\n'
              '_Best used in ranging/sideways markets. Fast-reacting momentum oscillator._'
        };
      case 'atr':
        return {
          'title': 'ATR (Volatility)',
          'description':
              'Average True Range (ATR) measures market volatility. High ATR indicates large price swings and increased risk. '
                  'Rising ATR suggests strong trending conditions, while falling ATR indicates consolidation. Used to set stop-loss '
                  'levels and position sizing based on current market conditions.',
          'technicalDetails': '**Parameters**: `14 bars` (Wilder\'s smoothing)\n'
              '\n'
              '**Formulas**:\n'
              '- `True Range = max(High - Low, |High - Prev Close|, |Low - Prev Close|)`\n'
              '- `ATR = 14-period smoothed average of True Range`\n'
              '- `ATR % = (ATR / Current Price) × 100`\n'
              '- `ATR Ratio = Current ATR / Historical Avg ATR`\n'
              '\n'
              '**Interpretation**:\n'
              '- **High Volatility**: ATR ratio `> 1.5` → HOLD (caution, wide swings)\n'
              '- **Low Volatility**: ATR ratio `< 0.6` → BUY (breakout setup, tight ranges)\n'
              '- **Normal**: `0.6 ≤ ATR ratio ≤ 1.5` → HOLD\n'
              '\n'
              '_Used for stop-loss placement (2-3× ATR) and position sizing. Not directional._'
        };
      case 'obv':
        return {
          'title': 'OBV (On-Balance Volume)',
          'description':
              'On-Balance Volume (OBV) tracks cumulative volume flow. Rising OBV confirms uptrends (BUY), falling OBV confirms '
                  'downtrends (SELL). Divergences between OBV and price can signal potential reversals. Volume precedes price, making '
                  'OBV a leading indicator for trend confirmation.',
          'technicalDetails': '**Calculation**:\n'
              '- If `close > prev close`: `OBV += volume`\n'
              '- If `close < prev close`: `OBV -= volume`\n'
              '\n'
              '**Trend Analysis**:\n'
              '- OBV Trend: Compare recent 10-bar avg vs previous 10-bar avg\n'
              '- Price Trend: Compare recent 10-bar price avg vs previous 10-bar avg\n'
              '\n'
              '**Signals**:\n'
              '- **Bullish Divergence**: OBV trend `> +5%` while price trend `< 0%` → BUY (strong)\n'
              '- **Bearish Divergence**: OBV trend `< -5%` while price trend `> 0%` → SELL (strong)\n'
              '- **Confirmed Uptrend**: OBV trend `> +10%` with price rising → BUY\n'
              '- **Confirmed Downtrend**: OBV trend `< -10%` with price falling → SELL\n'
              '- **Neutral**: `-5% ≤ OBV trend ≤ +5%` → HOLD\n'
              '\n'
              '_Leading indicator: volume changes often precede price movements._'
        };
      case 'vwap':
        return {
          'title': 'VWAP (Volume Weighted Average Price)',
          'description':
              'VWAP represents the average price weighted by volume throughout the trading session. Price below VWAP suggests '
                  'undervaluation (potential BUY), while price above VWAP indicates overvaluation (potential SELL). Institutional '
                  'traders use VWAP as a benchmark for execution quality. Bands at ±1σ and ±2σ provide support/resistance levels.',
          'technicalDetails': '**Formulas**:\n'
              '- `Typical Price = (High + Low + Close) / 3`\n'
              '- `VWAP = Σ(Typical Price × Volume) / Σ(Volume)`\n'
              '- Standard Deviation: Sample StdDev of typical prices from VWAP\n'
              '\n'
              '**Bands**:\n'
              '- Upper Band 1σ: `VWAP + 1 StdDev`\n'
              '- Lower Band 1σ: `VWAP - 1 StdDev`\n'
              '- Upper Band 2σ: `VWAP + 2 StdDev`\n'
              '- Lower Band 2σ: `VWAP - 2 StdDev`\n'
              '\n'
              '**Signals**:\n'
              '- **Below -2σ**: Oversold → BUY (strong)\n'
              '- **Below -1σ**: Undervalued → BUY\n'
              '- **Above +1σ**: Overvalued → SELL\n'
              '- **Above +2σ**: Overbought → SELL (strong)\n'
              '\n'
              '_Institutional benchmark for execution quality. Resets each trading session._'
        };
      case 'adx':
        return {
          'title': 'ADX (Average Directional Index)',
          'description':
              'ADX measures trend strength regardless of direction. Values above 25 indicate a strong trend, above 40 indicates '
                  'a very strong trend, while below 20 suggests a weak or ranging market. Combined with +DI and -DI to determine '
                  'trend direction: +DI > -DI suggests bullish trend (BUY), -DI > +DI suggests bearish trend (SELL).',
          'technicalDetails': '**Parameters**: `14 bars` (requires 28+ bars total)\n'
              '\n'
              '**Formulas**:\n'
              '- `+DM = Current High - Previous High` (if > 0 and > -DM)\n'
              '- `-DM = Previous Low - Current Low` (if > 0 and > +DM)\n'
              '- `True Range = max(High - Low, |High - Prev Close|, |Low - Prev Close|)`\n'
              '- `+DI = (Smoothed +DM / Smoothed TR) × 100`\n'
              '- `-DI = (Smoothed -DM / Smoothed TR) × 100`\n'
              '- `DX = (|+DI - -DI| / (+DI + -DI)) × 100`\n'
              '- `ADX = 14-period smoothed average of DX` (Wilder\'s smoothing)\n'
              '\n'
              '**Signals**:\n'
              '- **Bullish**: `ADX > 25` and `+DI > -DI` → BUY (strong if `ADX > 40`)\n'
              '- **Bearish**: `ADX > 25` and `-DI > +DI` → SELL (strong if `ADX > 40`)\n'
              '- **Weak/Ranging**: `ADX < 20` → HOLD\n'
              '\n'
              '_Non-directional trend strength: ADX only shows strength, DI shows direction._'
        };
      case 'williamsR':
        return {
          'title': 'Williams %R',
          'description':
              'Williams %R is a momentum oscillator ranging from -100 to 0. Values below -80 indicate oversold conditions '
                  '(potential BUY), while values above -20 indicate overbought conditions (potential SELL). Similar to Stochastic '
                  'but inverted. Rising from oversold or falling from overbought regions provides stronger reversal signals.',
          'technicalDetails':
              '**Formula**: `((Highest High - Close) / (Highest High - Lowest Low)) × -100`\n'
                  '\n'
                  '**Parameters**:\n'
                  '- Period: `14 bars` for highest/lowest calculation\n'
                  '- Range: `-100` (oversold) to `0` (overbought)\n'
                  '\n'
                  '**Signals**:\n'
                  '- **Oversold**: `%R ≤ -80` → BUY\n'
                  '- **Oversold Reversal**: %R rising from `≤ -80` → BUY (stronger signal)\n'
                  '- **Overbought**: `%R ≥ -20` → SELL\n'
                  '- **Overbought Reversal**: %R falling from `≥ -20` → SELL (stronger signal)\n'
                  '- **Neutral**: `-80 < %R < -20` → HOLD\n'
                  '\n'
                  '_Similar to Stochastic but inverted scale. Fast-reacting oscillator for momentum shifts._'
        };
      default:
        return {
          'title': 'Technical Indicator',
          'description':
              'Technical indicator used to analyze market conditions and generate trading signals.',
          'technicalDetails': ''
        };
    }
  }

  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  StreamSubscription<QuerySnapshot>? _tradeSignalsSubscription;
  List<Map<String, dynamic>> _tradeSignals = [];
  List<String>? _currentSymbols;
  int _currentLimit = 50;
  String? _selectedInterval; // Will be auto-set based on market hours

  String? _tradeProposalMessage;
  String? _error;
  Map<String, dynamic>? _lastTradeProposal;
  Map<String, dynamic>? _lastAssessment;
  bool _isTradeInProgress = false;
  bool _isLoading = false;
  Map<String, dynamic>? _tradeSignal;

  List<Map<String, dynamic>> get tradeSignals => _tradeSignals;
  String? get tradeProposalMessage => _tradeProposalMessage;
  String? get error => _error;
  Map<String, dynamic>? get lastTradeProposal => _lastTradeProposal;
  Map<String, dynamic>? get lastAssessment => _lastAssessment;
  bool get isTradeInProgress => _isTradeInProgress;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get tradeSignal => _tradeSignal;
  String get selectedInterval {
    final interval = _selectedInterval ?? _getDefaultInterval();
    debugPrint(
        '🎯 selectedInterval getter called: $_selectedInterval (default: ${_getDefaultInterval()}) -> returning: $interval');
    return interval;
  }

  TradeSignalsProvider();

  String _getDefaultInterval() {
    return MarketHours.isMarketOpen() ? '1h' : '1d';
  }

  @override
  void dispose() {
    debugPrint('🧹 Disposing TradeSignalsProvider - cancelling subscription');
    _tradeSignalsSubscription?.cancel();
    super.dispose();
  }

  Future<void> fetchTradeSignal(String symbol, {String? interval}) async {
    try {
      if (symbol.isEmpty) {
        _tradeSignal = null;
        notifyListeners();
        return;
      }

      final effectiveInterval =
          interval ?? _selectedInterval ?? _getDefaultInterval();
      final docId = effectiveInterval == '1d'
          ? 'signals_$symbol'
          : 'signals_${symbol}_$effectiveInterval';

      final doc = await FirebaseFirestore.instance
          .collection('agentic_trading')
          .doc(docId)
          .get(const GetOptions(source: Source.server));
      if (doc.exists && doc.data() != null) {
        _tradeSignal = doc.data();

        // Also update the signal in the _tradeSignals list
        final signalData = doc.data()!;
        final index = _tradeSignals.indexWhere((s) =>
            s['symbol'] == symbol &&
            (s['interval'] ?? '1d') == effectiveInterval);
        if (index != -1) {
          // Update existing signal in the list
          _tradeSignals[index] = signalData;
        } else {
          // Add new signal to the list
          _tradeSignals.insert(0, signalData);
        }
        // Re-sort by timestamp
        _tradeSignals.sort((a, b) {
          final aTimestamp = a['timestamp'] as int? ?? 0;
          final bTimestamp = b['timestamp'] as int? ?? 0;
          return bTimestamp.compareTo(aTimestamp);
        });
      } else {
        _tradeSignal = null;
        // Remove signal from list if it no longer exists
        _tradeSignals.removeWhere((s) =>
            s['symbol'] == symbol &&
            (s['interval'] ?? '1d') == effectiveInterval);
      }
      notifyListeners();
    } catch (e) {
      _tradeSignal = null;
      _tradeProposalMessage = 'Failed to fetch trade signal: ${e.toString()}';
      notifyListeners();
    }
  }

  Query<Map<String, dynamic>> _buildQuery({
    String? signalType,
    List<String>? indicators,
    Map<String, String>? indicatorFilters,
    int? minSignalStrength,
    int? maxSignalStrength,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? symbols,
    String? interval,
    String sortBy = 'signalStrength',
  }) {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('agentic_trading');

    final effectiveInterval = interval ?? selectedInterval;

    if (indicatorFilters != null && indicatorFilters.isNotEmpty) {
      indicatorFilters.forEach((indicator, signal) {
        query = query.where('multiIndicatorResult.indicators.$indicator.signal',
            isEqualTo: signal);
      });
    } else if (signalType != null && signalType.isNotEmpty) {
      if (indicators == null || indicators.isEmpty) {
        query = query.where('signal', isEqualTo: signalType);
      } else {
        for (final indicator in indicators) {
          query = query.where(
              'multiIndicatorResult.indicators.$indicator.signal',
              isEqualTo: signalType);
        }
      }
    }
    if (minSignalStrength != null) {
      query = query.where('multiIndicatorResult.signalStrength',
          isGreaterThanOrEqualTo: minSignalStrength);
    }
    if (maxSignalStrength != null) {
      query = query.where('multiIndicatorResult.signalStrength',
          isLessThanOrEqualTo: maxSignalStrength);
    }

    query = query.where('interval', isEqualTo: effectiveInterval);

    final queryLimit = 200;

    debugPrint(
        '⏰ Query will fetch up to $queryLimit docs, client-side filter for market hours');

    if (startDate != null) {
      query = query.where('timestamp',
          isGreaterThanOrEqualTo: startDate.millisecondsSinceEpoch);
    }
    if (endDate != null) {
      query = query.where('timestamp',
          isLessThanOrEqualTo: endDate.millisecondsSinceEpoch);
    }

    if (symbols != null && symbols.isNotEmpty) {
      if (symbols.length <= 30) {
        query = query.where('symbol', whereIn: symbols);
      }
    }

    if (sortBy == 'signalStrength') {
      query = query.orderBy('multiIndicatorResult.signalStrength',
          descending: true);
      query = query.orderBy('timestamp', descending: true);
    } else {
      query = query.orderBy('timestamp', descending: true);
      query = query.orderBy('multiIndicatorResult.signalStrength',
          descending: true);
    }
    query = query.limit(queryLimit);
    return query;
  }

  void streamTradeSignals({
    String? signalType,
    List<String>? indicators,
    Map<String, String>? indicatorFilters,
    int? minSignalStrength,
    int? maxSignalStrength,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? symbols,
    int? limit,
    String? interval,
    String sortBy = 'signalStrength',
  }) {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _currentSymbols = symbols;
    _currentLimit = limit ?? 50;

    debugPrint('🚀 Setting up new trade signals subscription with filters:');
    debugPrint('   Signal type: $signalType');
    debugPrint('   Indicators: ${indicators?.join(", ") ?? "all"}');
    debugPrint('   Indicator Filters: $indicatorFilters');
    debugPrint('   Min signal strength: $minSignalStrength');
    debugPrint('   Max signal strength: $maxSignalStrength');
    debugPrint('   Start date: $startDate');
    debugPrint('   End date: $endDate');
    debugPrint('   Symbols: ${symbols?.length ?? 0} symbols');
    debugPrint('   Limit: $_currentLimit');
    debugPrint('   Sort by: $sortBy');

    // Cancel existing subscription
    _tradeSignalsSubscription?.cancel();

    try {
      final effectiveInterval = interval ?? selectedInterval;
      final query = _buildQuery(
        signalType: signalType,
        indicators: indicators,
        indicatorFilters: indicatorFilters,
        minSignalStrength: minSignalStrength,
        maxSignalStrength: maxSignalStrength,
        startDate: startDate,
        endDate: endDate,
        symbols: symbols,
        interval: effectiveInterval,
        sortBy: sortBy,
      );

      _tradeSignalsSubscription = query.snapshots().listen((snapshot) {
        debugPrint('📥 Stream update received: ${snapshot.docs.length} docs');
        _updateTradeSignalsFromSnapshot(
            snapshot, _currentSymbols, effectiveInterval);
      }, onError: (e) {
        _tradeSignals = [];
        _error = 'Failed to stream trade signals: ${e.toString()}';
        debugPrint('❌ Error streaming trade signals: ${e.toString()}');
        _isLoading = false;
        notifyListeners();
      });
    } catch (e) {
      _tradeSignals = [];
      _error = 'Failed to setup trade signals stream: ${e.toString()}';
      debugPrint('❌ Error setting up trade signals stream: ${e.toString()}');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAllTradeSignals({
    String? signalType,
    List<String>? indicators,
    Map<String, String>? indicatorFilters,
    int? minSignalStrength,
    int? maxSignalStrength,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? symbols,
    int? limit,
    String? interval,
    String sortBy = 'signalStrength',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    _currentSymbols = symbols;
    _currentLimit = limit ?? 50;

    debugPrint('🚀 Setting up new trade signals subscription with filters:');
    debugPrint('   Signal type: $signalType');
    debugPrint('   Indicators: ${indicators?.join(", ") ?? "all"}');
    debugPrint('   Indicator Filters: $indicatorFilters');
    debugPrint('   Min signal strength: $minSignalStrength');
    debugPrint('   Max signal strength: $maxSignalStrength');
    debugPrint('   Start date: $startDate');
    debugPrint('   End date: $endDate');
    debugPrint('   Symbols: ${symbols?.length ?? 0} symbols');
    debugPrint('   Limit: $_currentLimit');
    debugPrint('   Sort by: $sortBy');

    try {
      final effectiveInterval = interval ?? selectedInterval;
      final query = _buildQuery(
        signalType: signalType,
        indicators: indicators,
        indicatorFilters: indicatorFilters,
        minSignalStrength: minSignalStrength,
        maxSignalStrength: maxSignalStrength,
        startDate: startDate,
        endDate: endDate,
        symbols: symbols,
        interval: effectiveInterval,
        sortBy: sortBy,
      );

      final snapshot = await query.get(const GetOptions(source: Source.server));
      debugPrint('📥 Server fetch completed: ${snapshot.docs.length} docs');
      _updateTradeSignalsFromSnapshot(
          snapshot, _currentSymbols, effectiveInterval);
    } catch (e) {
      _tradeSignals = [];
      _error = 'Failed to fetch trade signals: ${e.toString()}';
      debugPrint('❌ Error fetching trade signals: ${e.toString()}');
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updateTradeSignalsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    List<String>? symbols,
    String effectiveInterval,
  ) {
    final isMarketOpen = MarketHours.isMarketOpen();

    debugPrint('📊 Processing ${snapshot.docs.length} documents');
    debugPrint('   Market status: ${isMarketOpen ? "OPEN" : "CLOSED"}');
    debugPrint('   Selected interval: $effectiveInterval');

    _tradeSignals = snapshot.docs
        .where((doc) {
          final data = doc.data();
          final interval = data['interval'] as String?;

          final include = effectiveInterval == '1d'
              ? (interval == null || interval == '1d')
              : (interval == effectiveInterval);

          if (include) {
            debugPrint(
                '   ✅ ${doc.id}: interval=$interval matches selected $effectiveInterval');
          }
          return include;
        })
        .map((doc) {
          final data = doc.data();
          if (data.containsKey('timestamp')) {
            return data;
          }
          return null;
        })
        .where((data) => data != null)
        .cast<Map<String, dynamic>>()
        .toList();

    if (symbols != null && symbols.isNotEmpty && symbols.length > 30) {
      _tradeSignals = _tradeSignals
          .where((signal) => symbols.contains(signal['symbol']))
          .toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  void setSelectedInterval(String interval) {
    _selectedInterval = interval;
    notifyListeners();
  }

  Future<void> initiateTradeProposal({
    required String symbol,
    required double currentPrice,
    required Map<String, dynamic> portfolioState,
    required Map<String, dynamic> config,
    String? interval,
  }) async {
    _isTradeInProgress = true;
    _tradeProposalMessage = 'Initiating trade proposal...';
    notifyListeners();

    final effectiveInterval = interval ?? selectedInterval;
    final payload = {
      'symbol': symbol,
      'currentPrice': currentPrice,
      'portfolioState': portfolioState,
      'interval': effectiveInterval,
      'smaPeriodFast': config['smaPeriodFast'],
      'smaPeriodSlow': config['smaPeriodSlow'],
      'tradeQuantity': config['tradeQuantity'],
      'maxPositionSize': config['maxPositionSize'],
      'maxPortfolioConcentration': config['maxPortfolioConcentration'],
    };

    try {
      final result =
          await _functions.httpsCallable('initiateTradeProposal').call(payload);
      final data = result.data as Map<String, dynamic>?;
      if (data == null) throw Exception('Empty response from function');

      final status = data['status'] as String? ?? 'error';
      final reason = data['reason']?.toString();
      final intervalLabel = effectiveInterval == '1d'
          ? 'Daily'
          : effectiveInterval == '1h'
              ? 'Hourly'
              : effectiveInterval == '30m'
                  ? '30-min'
                  : effectiveInterval == '15m'
                      ? '15-min'
                      : effectiveInterval;
      if (status == 'approved') {
        final proposal =
            Map<String, dynamic>.from(data['proposal'] as Map? ?? {});
        _lastTradeProposal = proposal;
        final assessment =
            Map<String, dynamic>.from(data['assessment'] as Map? ?? {});
        _lastAssessment = assessment;
        final reasonMsg =
            (reason != null && reason.isNotEmpty) ? '\n$reason' : '';
        _tradeProposalMessage =
            'Trade proposal approved for $symbol ($intervalLabel).\n${proposal['action']} ${proposal['quantity']} of ${proposal['symbol']}$reasonMsg';
        _analytics.logEvent(
            name: 'trade_signals_trade_approved',
            parameters: {'interval': effectiveInterval});
      } else {
        _lastTradeProposal = null;
        _lastAssessment = null;
        final message = data['message']?.toString() ?? 'Rejected by agent';
        final reasonMsg =
            (reason != null && reason.isNotEmpty) ? '\n$reason' : '';
        _tradeProposalMessage =
            'Trade proposal rejected for $symbol ($intervalLabel).\n$message\n$reasonMsg';
        _analytics.logEvent(name: 'trade_signals_trade_rejected', parameters: {
          'reason': reason ?? message,
          'interval': effectiveInterval
        });
      }
    } catch (e) {
      _tradeProposalMessage =
          'Function call failed, falling back to local simulation: ${e.toString()}';
      await Future.delayed(const Duration(seconds: 1));
      final simulatedTradeProposal = {
        'symbol': symbol,
        'action': 'BUY',
        'quantity': config['tradeQuantity'],
        'price': currentPrice,
      };
      _lastTradeProposal = Map<String, dynamic>.from(simulatedTradeProposal);
      _tradeProposalMessage =
          'Trade proposal (simulated): ${_lastTradeProposal!['action']} ${_lastTradeProposal!['quantity']} of ${_lastTradeProposal!['symbol']}';
      _analytics.logEvent(
          name: 'trade_signals_trade_approved_simulated',
          parameters: {'error': e.toString()});
    }

    _isTradeInProgress = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> assessTradeRisk({
    required Map<String, dynamic> proposal,
    required Map<String, dynamic> portfolioState,
    required Map<String, dynamic> config,
  }) async {
    try {
      final result = await _functions.httpsCallable('riskguardTask').call({
        'proposal': proposal,
        'portfolioState': portfolioState,
        'config': config,
      });
      notifyListeners();
      if (result.data is Map<String, dynamic>) {
        return Map<String, dynamic>.from(result.data);
      } else {
        return {'approved': false, 'reason': 'Unexpected response format'};
      }
    } catch (e) {
      return {'approved': false, 'reason': 'Error: ${e.toString()}'};
    }
  }
}

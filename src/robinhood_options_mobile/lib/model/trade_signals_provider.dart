import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/utils/market_hours.dart';
import 'package:robinhood_options_mobile/services/home_widget_service.dart';

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
                  'indicate oversold conditions (potential BUY). Trend filters adjust these thresholds.',
          'technicalDetails': '**Formula**: `RSI = 100 - (100 / (1 + RS))` where `RS = Avg Gain / Avg Loss`\n'
              '\n'
              '**Parameters**:\n'
              '- Period: `14 bars` (smoothed using Wilder\'s method)\n'
              '- Trend Filter: `Price > SMA200` (Bullish Trend) or `Price < SMA200` (Bearish Trend)\n'
              '\n'
              '**Thresholds**:\n'
              '- **Oversold**: `RSI < 30` → BUY signal\n'
              '- **Overbought**: `RSI > 70` → SELL signal\n'
              '- **Bullish momentum**: `RSI 60-70` → BUY\n'
              '- **Bearish momentum**: `RSI 30-40` → SELL\n'
              '\n'
              '**Thresholds with Trend Context**:\n'
              '- **Uptrend (Bull Market)**: Oversold at 40 (Aggressive Buy), Overbought at 80.\n'
              '- **Downtrend (Bear Market)**: Oversold at 20, Overbought at 60 (Aggressive Short).\n'
              '\n'
              '**Divergence Detection** (requires 20+ bars):\n'
              '- **Bullish**: Price falling but RSI rising (divergence).\n'
              '- **Bearish**: Price rising but RSI falling (divergence).\n'
              '\n'
              '_Note: Divergence signals or trend-aligned signals carry higher weight._'
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
          'description': 'Moving Average Convergence Divergence (MACD) shows the relationship between two moving averages. '
              'When the MACD line crosses above the signal line, it generates a BUY signal. When MACD crosses below the signal line, '
              'it generates a SELL signal. The histogram shows the strength of the trend. '
              'Additionally, Histogram momentum reversals often precede crossovers, providing earlier entries.',
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
              '- **Bullish Momentum**: Histogram `> 0` and expanding → BUY\n'
              '- **Bearish Momentum**: Histogram `< 0` and expanding (more negative) → SELL\n'
              '- **Momentum Reversal**: Histogram reversal (2+ bars) indicates slowing momentum before a cross.\n'
              '\n'
              '_Reversal signals are "Early Warnings" that often eventually lead to full crossovers._'
        };
      case 'bollingerBands':
        return {
          'title': 'Bollinger Bands',
          'description': 'Volatility indicator using standard deviations around a moving average. Price near the lower band '
              'suggests oversold conditions (potential BUY), while price near the upper band suggests overbought (potential SELL). '
              'Price in the middle suggests neutral conditions. Band width indicates volatility levels. '
              'A "Squeeze" (very narrow bands) alerts to an impending explosive move, while a "Breakout" from a Squeeze is a high-conviction signal.',
          'technicalDetails': '**Band Calculation**:\n'
              '- Middle Band: `20-period SMA`\n'
              '- Upper Band: `Middle + (2 × StdDev)`\n'
              '- Lower Band: `Middle - (2 × StdDev)`\n'
              '- StdDev: Sample standard deviation (N-1 denominator)\n'
              '- **Bandwidth**: `(Upper - Lower) / Middle`\n'
              '\n'
              '**Position Formula**: `(Price - Lower) / (Upper - Lower) × 100`\n'
              '\n'
              '**Signals**:\n'
              '- **Oversold**: Price ≤ Lower Band (±0.5%) → BUY\n'
              '- **Overbought**: Price ≥ Upper Band (±0.5%) → SELL\n'
              '- **Lower Region**: Position `< 30%` → BUY\n'
              '- **Upper Region**: Position `> 70%` → SELL\n'
              '- **Neutral**: `30% ≤ Position ≤ 70%` → HOLD\n'
              '- **Squeeze**: Bandwidth < 6-month low (within 5%) → HOLD (Warning of big move).\n'
              '- **Squeeze Breakout**: Price breaking bands after a Squeeze → STRONG BUY/SELL.\n'
              '- **Mean Reversion**: Price touching bands in ranging market → Reversal.\n'
              '\n'
              '_Squeezes are the most powerful signal in this system._'
        };
      case 'stochastic':
        return {
          'title': 'Stochastic',
          'description':
              'Stochastic Oscillator compares the closing price to its price range over a period. Values above 80 indicate '
                  'overbought conditions (potential SELL), below 20 indicates oversold (potential BUY). Crossovers of %K and %D '
                  'lines provide additional signals. Works best in ranging markets, but can identify momentum shifts in trends.',
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
              '- **Bullish Crossover**: %K crosses above %D in Low/Oversold region → BUY\n'
              '- **Bearish Crossover**: %K crosses below %D in High/Overbought region → SELL\n'
              '- **Stochastic Pop**: %K crosses above 80 and sustains → BUY (Momentum)\n'
              '- **Stochastic Drop**: %K crosses below 20 and sustains → SELL (Momentum)\n'
              '- **Bullish Divergence**: Price Lower Low, %K Higher Low (< 30) → BUY\n'
              '- **Bearish Divergence**: Price Higher High, %K Lower High (> 70) → SELL\n'
              '\n'
              '_Best used in ranging markets, but Divergence signals are powerful reversal indicators._'
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
              '- **Extreme Volatility**: ATR ratio `> 2.0` → HOLD (Exhaustion Risk)\n'
              '- **Squeeze (Low Volatility)**: ATR ratio `< 0.7` → BUY (Potential Breakout)\n'
              '- **Normal**: `0.7 ≤ ATR ratio ≤ 1.5` → HOLD\n'
              '\n'
              '_Used for stop-loss placement (2-3× ATR) and position sizing. Low ATR Squeezes often precede breakouts._'
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
              '- **OBV Breakout**: OBV makes new high before Price → BUY (Accumulation)\n'
              '- **OBV Breakdown**: OBV makes new low before Price → SELL (Distribution)\n'
              '- **Bullish Divergence**: OBV trend `> +5%` while price trend `< 0%` → BUY\n'
              '- **Bearish Divergence**: OBV trend `< -5%` while price trend `> 0%` → SELL\n'
              '- **Confirmed Uptrend**: OBV trend `> +5%` with price rising → BUY\n'
              '- **Confirmed Downtrend**: OBV trend `< -5%` with price falling → SELL\n'
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
              '- **Bullish Crossover**: Price crosses VWAP from below → BUY\n'
              '- **Bearish Crossover**: Price crosses VWAP from above → SELL\n'
              '- **Below -2σ**: Extended/Oversold → BUY (Mean Reversion)\n'
              '- **Below -1σ**: Undervalued → BUY\n'
              '- **Above +1σ**: Overvalued → SELL\n'
              '- **Above +2σ**: Extended/Overbought → SELL (Mean Reversion)\n'
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
              '- **New Trend**: ADX crosses above 20 → BUY/SELL (based on DI)\n'
              '- **Trend Exhaustion**: ADX > 50 and turning down → HOLD (Take Profit)\n'
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
      case 'ichimoku':
        return {
          'title': 'Ichimoku Cloud',
          'description':
              'Ichimoku Kinko Hyo represents trend direction, momentum, and support/resistance levels all in one. '
                  'Price above the cloud with green cloud suggests a strong uptrend (BUY). Price below the red cloud indicates '
                  'a strong downtrend (SELL). The crossover of Tenkan-sen and Kijun-sen provides early entry signals.',
          'technicalDetails': '**Components**:\n'
              '- Tenkan-sen (Conversion Line): `(9-period High + Low) / 2`\n'
              '- Kijun-sen (Base Line): `(26-period High + Low) / 2`\n'
              '- Senkou Span A (Leading A): `(Tenkan + Kijun) / 2` projected 26 periods ahead\n'
              '- Senkou Span B (Leading B): `(52-period High + Low) / 2` projected 26 periods ahead\n'
              '- Kumo (Cloud): Area between Span A and Span B\n'
              '- Chikou Span (Lagging): Close plotted 26 periods behind\n'
              '\n'
              '**Signals**:\n'
              '- **Strong Buy**: Price > Cloud, Tenkan > Kijun, Cloud Green (Span A > B)\n'
              '- **Strong Sell**: Price < Cloud, Tenkan < Kijun, Cloud Red (Span A < B)\n'
              '- **TK Cross**: Tenkan crossing Kijun (Buy above cloud, Sell below)\n'
              '- **Kumo Breakout**: Price breaking out of the cloud\n'
              '\n'
              '_Comprehensive system for identifying trend and potential reversals._'
        };
      case 'cci':
        return {
          'title': 'CCI (Commodity Channel Index)',
          'description':
              'CCI measures the current price level relative to an average price level over a given period. '
                  'High positive values indicate that prices are unusually high compared to average (overbought), '
                  'while low negative values indicate prices are unusually low (oversold). CCI is also used to '
                  'spot new trends.',
          'technicalDetails': '**Formula**: `(Typical Price - SMA) / (0.015 * Mean Deviation)`\n'
              '\n'
              '**Parameters**:\n'
              '- Period: `20 bars`\n'
              '- Constant: `0.015` to ensure 70-80% of values fall within ±100\n'
              '\n'
              '**Signals**:\n'
              '- **Oversold**: `CCI < -100` → BUY (potential bounce)\n'
              '- **Overbought**: `CCI > 100` → SELL (potential pullback)\n'
              '- **Bullish Breakout**: Crossing above `+100` → BUY (trend continuation)\n'
              '- **Bearish Breakdown**: Crossing below `-100` → SELL (trend continuation)\n'
              '- **Neutral**: `-100 ≤ CCI ≤ 100` → HOLD\n'
              '\n'
              '_Versatile indicator for both cyclical range trading and trend following._'
        };
      case 'sar':
      case 'parabolicSar':
        return {
          'title': 'Parabolic SAR',
          'description':
              'Parabolic SAR (Stop and Reverse) is a trend-following indicator that highlights direction '
                  'and potential reversals. Dots below price indicate an uptrend (BUY), while dots above '
                  'price indicate a downtrend (SELL). The dots also serve as trailing stop levels.',
          'technicalDetails': '**Formulas**:\n'
              '- **Uptrend**: `SAR(new) = SAR(curr) + AF * (EP - SAR(curr))`\n'
              '- **Downtrend**: `SAR(new) = SAR(curr) - AF * (SAR(curr) - EP)`\n'
              '- **AF (Acceleration Factor)**: Starts at `0.02`, increases by `0.02` each new extreme, max `0.20`\n'
              '- **EP (Extreme Point)**: Highest high (uptrend) or lowest low (downtrend)\n'
              '\n'
              '**Signals**:\n'
              '- **Buy**: Price crosses above SAR dots (dots move below price)\n'
              '- **Sell**: Price crosses below SAR dots (dots move above price)\n'
              '\n'
              '**Usage**: Excellent for setting trailing stops in strong trends. '
              'Prone to whipsaws in ranging/sideways markets.'
        };
      case 'roc':
        return {
          'title': 'ROC (Rate of Change)',
          'description':
              'Rate of Change (ROC) is a momentum oscillator that measures the percentage change '
                  'in price between the current price and the price n periods ago. '
                  'Values above 0 indicate sufficient upside momentum (BUY), while values below 0 indicate '
                  'downside momentum (SELL).',
          'technicalDetails':
              '**Formula**: `((Price - Price[n]) / Price[n]) * 100`\n'
                  '\n'
                  '**Parameters**:\n'
                  '- Period: `9 bars` by default\n'
                  '\n'
                  '**Signals**:\n'
                  '- **Bullish**: ROC > 5% → BUY (Strong Momentum)\n'
                  '- **Bearish**: ROC < -5% → SELL (Strong Drop)\n'
                  '- **Neutral**: -5% ≤ ROC ≤ 5% → HOLD\n'
                  '\n'
                  '_Pure momentum indicator showing the speed of price change._'
        };
      case 'chaikinMoneyFlow':
        return {
          'title': 'Chaikin Money Flow (CMF)',
          'description':
              'Combines price and volume to measure buying and selling pressure based on the close relative to the high-low range. '
                  'Values above zero indicate accumulation (buying pressure), while values below zero indicate distribution (selling pressure).',
          'technicalDetails': '**Formula**:\n'
              '- `MF Multiplier = ((Close - Low) - (High - Close)) / (High - Low)`\n'
              '- `MF Volume = MF Multiplier × Volume`\n'
              '- `CMF = Sum(MF Volume, n) / Sum(Volume, n)`\n'
              '\n'
              '**Parameters**: `20-period` default.\n'
              '\n'
              '**Signals**:\n'
              '- **BUY**: CMF > 0.05 (Buying Pressure)\n'
              '- **SELL**: CMF < -0.05 (Selling Pressure)\n'
              '- **HOLD**: -0.05 ≤ CMF ≤ 0.05 (Neutral)\n'
              '\n'
              '_Confirms trend strength with volume flow._'
        };
      case 'fibonacciRetracements':
        return {
          'title': 'Fibonacci Retracements',
          'description':
              'Identifies potential support and resistance levels using horizontal lines at key Fibonacci ratios '
                  '(23.6%, 38.2%, 50%, 61.8%). Prices often retrace a portion of a move before continuing in the original direction.',
          'technicalDetails': '**Logic**:\n'
              '- Identifies significant High and Low over lookback period (e.g. 50 bars).\n'
              '- Calculates vertical distance (Range = High - Low).\n'
              '- Projects levels: 23.6%, 38.2%, 50%, 61.8%.\n'
              '\n'
              '**Signals**:\n'
              '- **BUY**: Price bounces off support level (e.g. 61.8% or 50% retracement in uptrend).\n'
              '- **SELL**: Price rejects resistance level (in downtrend).\n'
              '- **Golden Ratio**: 61.8% level is considered strongest support/resistance.\n'
        };
      case 'pivotPoints':
        return {
          'title': 'Pivot Points',
          'description':
              'Calculates intraday support and resistance levels based on the previous day\'s High, Low, and Close. '
                  'Pivot Points are used to identify potential turning points and trend direction.',
          'technicalDetails': '**Formulas** (Standard Method):\n'
              '- **Pivot Point (P)**: `(High + Low + Close) / 3`\n'
              '- **Resistance 1 (R1)**: `(2 * P) - Low`\n'
              '- **Support 1 (S1)**: `(2 * P) - High`\n'
              '- **Resistance 2 (R2)**: `P + (High - Low)`\n'
              '- **Support 2 (S2)**: `P - (High - Low)`\n'
              '- **Resistance 3 (R3)**: `High + 2 * (P - Low)`\n'
              '- **Support 3 (S3)**: `Low - 2 * (High - P)`\n'
              '\n'
              '**Signals**:\n'
              '- **BUY**: Price bounces off S1, S2, or S3 support levels.\n'
              '- **SELL**: Price rejects R1, R2, or R3 resistance levels.\n'
              '- **Trend Context**: Price above Pivot suggests bullish bias; price below suggest bearish bias.\n'
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

  String? _error;
  bool _isTradeInProgress = false;
  bool _isLoading = false;
  Map<String, dynamic>? _tradeSignal;

  String _sortBy = 'signalStrength';
  String get sortBy => _sortBy;
  set sortBy(String value) {
    if (_sortBy != value) {
      _sortBy = value;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> get tradeSignals => _tradeSignals;
  String? get error => _error;
  bool get isTradeInProgress => _isTradeInProgress;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get tradeSignal => _tradeSignal;
  String get selectedInterval {
    final interval = _selectedInterval ?? _getDefaultInterval();
    // debugPrint(
    //     '🎯 selectedInterval getter called: $_selectedInterval (default: ${_getDefaultInterval()}) -> returning: $interval');
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
      } else {
        _tradeSignal = null;
      }
      notifyListeners();
    } catch (e) {
      _tradeSignal = null;
      _error = 'Failed to fetch trade signal: ${e.toString()}';
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
    String? searchQuery,
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

    // Only apply strength filters if not searching (avoid multiple inequality error)
    if (searchQuery == null || searchQuery.isEmpty) {
      if (minSignalStrength != null) {
        query = query.where('multiIndicatorResult.signalStrength',
            isGreaterThanOrEqualTo: minSignalStrength);
      }
      if (maxSignalStrength != null) {
        query = query.where('multiIndicatorResult.signalStrength',
            isLessThanOrEqualTo: maxSignalStrength);
      }
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

    // Handle search query (prefix search)
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final searchUpper = searchQuery.toUpperCase();
      query = query
          .where('symbol', isGreaterThanOrEqualTo: searchUpper)
          .where('symbol', isLessThan: '${searchUpper}z');
    } else if (symbols != null && symbols.isNotEmpty) {
      if (symbols.length <= 30) {
        query = query.where('symbol', whereIn: symbols);
      }
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      // Must order by symbol first when using range filter on symbol
      query = query.orderBy('symbol');
      query = query.orderBy('timestamp', descending: true);
    } else if (sortBy == 'signalStrength') {
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

  Future<List<Map<String, dynamic>>> fetchSignals({
    String? signalType,
    List<String>? indicators,
    Map<String, String>? indicatorFilters,
    int? minSignalStrength,
    int? maxSignalStrength,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? symbols,
    String? searchQuery,
    String? interval,
    String sortBy = 'signalStrength',
    int limit = 200,
  }) async {
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
        searchQuery: searchQuery,
        interval: effectiveInterval,
        sortBy: sortBy,
      );

      // Note: _buildQuery applies a limit of 200.
      // If we want to support custom limit, we might need to modify _buildQuery or apply it here if _buildQuery didn't.
      // _buildQuery applies .limit(200).

      final snapshot = await query.get();

      return snapshot.docs
          // .where((doc) {
          //   final data = doc.data();
          //   final docInterval = data['interval'] as String?;
          //   return effectiveInterval == '1d'
          //       ? (docInterval == null || docInterval == '1d')
          //       : (docInterval == effectiveInterval);
          // })
          .map((doc) => doc.data())
          .toList();
    } catch (e) {
      debugPrint('Error fetching signals: $e');
      return [];
    }
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
    String? searchQuery,
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
    debugPrint('   Search: $searchQuery');
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
        searchQuery: searchQuery,
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

  // Future<void> fetchAllTradeSignals({
  //   String? signalType,
  //   List<String>? indicators,
  //   Map<String, String>? indicatorFilters,
  //   int? minSignalStrength,
  //   int? maxSignalStrength,
  //   DateTime? startDate,
  //   DateTime? endDate,
  //   List<String>? symbols,
  //   int? limit,
  //   String? interval,
  //   String sortBy = 'signalStrength',
  // }) async {
  //   _isLoading = true;
  //   _error = null;
  //   notifyListeners();

  //   _currentSymbols = symbols;
  //   _currentLimit = limit ?? 50;

  //   debugPrint('🚀 Setting up new trade signals subscription with filters:');
  //   debugPrint('   Signal type: $signalType');
  //   debugPrint('   Indicators: ${indicators?.join(", ") ?? "all"}');
  //   debugPrint('   Indicator Filters: $indicatorFilters');
  //   debugPrint('   Min signal strength: $minSignalStrength');
  //   debugPrint('   Max signal strength: $maxSignalStrength');
  //   debugPrint('   Start date: $startDate');
  //   debugPrint('   End date: $endDate');
  //   debugPrint('   Symbols: ${symbols?.length ?? 0} symbols');
  //   debugPrint('   Limit: $_currentLimit');
  //   debugPrint('   Sort by: $sortBy');

  //   try {
  //     final effectiveInterval = interval ?? selectedInterval;
  //     final query = _buildQuery(
  //       signalType: signalType,
  //       indicators: indicators,
  //       indicatorFilters: indicatorFilters,
  //       minSignalStrength: minSignalStrength,
  //       maxSignalStrength: maxSignalStrength,
  //       startDate: startDate,
  //       endDate: endDate,
  //       symbols: symbols,
  //       interval: effectiveInterval,
  //       sortBy: sortBy,
  //     );

  //     final snapshot = await query.get(const GetOptions(source: Source.server));
  //     debugPrint('📥 Server fetch completed: ${snapshot.docs.length} docs');
  //     _updateTradeSignalsFromSnapshot(
  //         snapshot, _currentSymbols, effectiveInterval);
  //   } catch (e) {
  //     _tradeSignals = [];
  //     _error = 'Failed to fetch trade signals: ${e.toString()}';
  //     debugPrint('❌ Error fetching trade signals: ${e.toString()}');
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }

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

          // if (include) {
          //   debugPrint(
          //       '   ✅ ${doc.id}: interval=$interval matches selected $effectiveInterval');
          // }
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

    // Update home screen widget with latest trade signals
    debugPrint(
        'TradeSignalsProvider: Updating widget with ${_tradeSignals.length} signals');
    HomeWidgetService.updateTradeSignals(_tradeSignals);
  }

  void setSelectedInterval(String interval) {
    _selectedInterval = interval;
    notifyListeners();
  }

  Future<Map<String, dynamic>> initiateTradeProposal({
    required String symbol,
    required double currentPrice,
    required Map<String, dynamic> portfolioState,
    required AgenticTradingConfig config,
    String? interval,
    bool skipSignalUpdate = false,
  }) async {
    _isTradeInProgress = true;
    notifyListeners();

    final effectiveInterval = interval ?? selectedInterval;
    final payload = {
      'symbol': symbol,
      'currentPrice': currentPrice,
      'portfolioState': portfolioState,
      'interval': effectiveInterval,
      'smaPeriodFast': config.strategyConfig.smaPeriodFast,
      'smaPeriodSlow': config.strategyConfig.smaPeriodSlow,
      'tradeQuantity': config.strategyConfig.tradeQuantity,
      'maxPositionSize': config.strategyConfig.maxPositionSize,
      'maxPortfolioConcentration':
          config.strategyConfig.maxPortfolioConcentration,
      'enableDynamicPositionSizing':
          config.strategyConfig.enableDynamicPositionSizing,
      'riskPerTrade': config.strategyConfig.riskPerTrade,
      'atrMultiplier': config.strategyConfig.atrMultiplier,
      'rsiPeriod': config.strategyConfig.rsiPeriod,
      'rocPeriod': config.strategyConfig.rocPeriod,
      'marketIndexSymbol': config.strategyConfig.marketIndexSymbol,
      'dailyTradeLimit': config.strategyConfig.dailyTradeLimit,
      'minSignalStrength': config.strategyConfig.minSignalStrength,
      'requireAllIndicatorsGreen':
          config.strategyConfig.requireAllIndicatorsGreen,
      'timeBasedExitEnabled': config.strategyConfig.timeBasedExitEnabled,
      'timeBasedExitMinutes': config.strategyConfig.timeBasedExitMinutes,
      'marketCloseExitEnabled': config.strategyConfig.marketCloseExitEnabled,
      'marketCloseExitMinutes': config.strategyConfig.marketCloseExitMinutes,
      'enablePartialExits': config.strategyConfig.enablePartialExits,
      // Pass exit stages as list of maps
      'exitStages':
          config.strategyConfig.exitStages.map((e) => e.toJson()).toList(),
      'reduceSizeOnRiskOff': config.strategyConfig.reduceSizeOnRiskOff,
      'riskOffSizeReduction': config.strategyConfig.riskOffSizeReduction,
      'rsiExitEnabled': config.strategyConfig.rsiExitEnabled,
      'rsiExitThreshold': config.strategyConfig.rsiExitThreshold,
      'signalStrengthExitEnabled':
          config.strategyConfig.signalStrengthExitEnabled,
      'signalStrengthExitThreshold':
          config.strategyConfig.signalStrengthExitThreshold,
      'enableSectorLimits': config.strategyConfig.enableSectorLimits,
      'maxSectorExposure': config.strategyConfig.maxSectorExposure,
      'enableCorrelationChecks': config.strategyConfig.enableCorrelationChecks,
      'maxCorrelation': config.strategyConfig.maxCorrelation,
      'enableVolatilityFilters': config.strategyConfig.enableVolatilityFilters,
      'minVolatility': config.strategyConfig.minVolatility,
      'maxVolatility': config.strategyConfig.maxVolatility,
      'enableDrawdownProtection':
          config.strategyConfig.enableDrawdownProtection,
      'maxDrawdown': config.strategyConfig.maxDrawdown,
      'skipSignalUpdate': skipSignalUpdate,
    };

    try {
      final result =
          await _functions.httpsCallable('initiateTradeProposal').call(payload);
      final data = result.data as Map<String, dynamic>?;
      if (data == null) throw Exception('Empty response from function');

      final status = data['status'] as String? ?? 'error';
      final reason = data['reason']?.toString();

      if (status == 'approved') {
        _analytics.logEvent(
            name: 'trade_signals_trade_approved',
            parameters: {'interval': effectiveInterval});
      } else {
        final message = data['message']?.toString() ?? 'Rejected by agent';
        _analytics.logEvent(name: 'trade_signals_trade_rejected', parameters: {
          'reason': reason ?? message,
          'interval': effectiveInterval
        });
      }

      _isTradeInProgress = false;
      notifyListeners();
      return data;
    } catch (e) {
      await Future.delayed(const Duration(seconds: 1));
      final simulatedTradeProposal = {
        'symbol': symbol,
        'action': 'BUY',
        'quantity': config.strategyConfig.tradeQuantity,
        'price': currentPrice,
      };
      _analytics.logEvent(
          name: 'trade_signals_trade_approved_simulated',
          parameters: {'error': e.toString()});

      _isTradeInProgress = false;
      notifyListeners();
      return {
        'status': 'error',
        'message': e.toString(),
        'proposal': simulatedTradeProposal
      };
    }
  }

  Future<Map<String, dynamic>> assessTradeRisk({
    required Map<String, dynamic> proposal,
    required Map<String, dynamic> portfolioState,
    required AgenticTradingConfig config,
  }) async {
    try {
      final result = await _functions.httpsCallable('riskguardTask').call({
        'proposal': proposal,
        'portfolioState': portfolioState,
        'config': config.toJson(),
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

import 'dart:math';
import 'package:candlesticks/candlesticks.dart';

class TechnicalIndicators {
  /// Calculates Simple Moving Average (SMA)
  static List<double?> calculateSMA(List<Candle> candles, int period) {
    if (candles.length < period) return List.filled(candles.length, null);

    List<double?> sma = List.filled(candles.length, null);

    // Calculate first SMA
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += candles[i].close;
    }
    sma[period - 1] = sum / period;

    // Calculate remaining SMA
    for (int i = period; i < candles.length; i++) {
      sum += candles[i].close - candles[i - period].close;
      sma[i] = sum / period;
    }

    return sma;
  }

  /// Calculates Exponential Moving Average (EMA)
  static List<double?> calculateEMA(List<Candle> candles, int period) {
    if (candles.length < period) return List.filled(candles.length, null);

    List<double?> ema = List.filled(candles.length, null);

    // Start with SMA
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += candles[i].close;
    }
    ema[period - 1] = sum / period;

    double multiplier = 2 / (period + 1);

    for (int i = period; i < candles.length; i++) {
      ema[i] = (candles[i].close - ema[i - 1]!) * multiplier + ema[i - 1]!;
    }

    return ema;
  }

  /// Calculates Relative Strength Index (RSI)
  static List<double?> calculateRSI(List<Candle> candles, [int period = 14]) {
    if (candles.length < period + 1) return List.filled(candles.length, null);

    List<double?> rsi = List.filled(candles.length, null);
    double avgGain = 0;
    double avgLoss = 0;

    // Initial calculation
    for (int i = 1; i <= period; i++) {
      double change = candles[i].close - candles[i - 1].close;
      if (change > 0) {
        avgGain += change;
      } else {
        avgLoss += change.abs();
      }
    }

    avgGain /= period;
    avgLoss /= period;

    if (avgLoss == 0) {
      rsi[period] = 100;
    } else {
      double rs = avgGain / avgLoss;
      rsi[period] = 100 - (100 / (1 + rs));
    }

    // Smoothed calculation
    for (int i = period + 1; i < candles.length; i++) {
      double change = candles[i].close - candles[i - 1].close;
      double gain = change > 0 ? change : 0;
      double loss = change < 0 ? change.abs() : 0;

      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;

      if (avgLoss == 0) {
        rsi[i] = 100;
      } else {
        double rs = avgGain / avgLoss;
        rsi[i] = 100 - (100 / (1 + rs));
      }
    }

    return rsi;
  }

  /// Calculates Bollinger Bands
  static Map<String, List<double?>> calculateBollingerBands(
      List<Candle> candles,
      [int period = 20,
      double stdDevMultiplier = 2.0]) {
    List<double?> sma = calculateSMA(candles, period);
    List<double?> upper = List.filled(candles.length, null);
    List<double?> lower = List.filled(candles.length, null);

    for (int i = period - 1; i < candles.length; i++) {
      double sumSqDiff = 0;
      for (int j = 0; j < period; j++) {
        sumSqDiff += pow(candles[i - j].close - sma[i]!, 2);
      }
      double stdDev = sqrt(sumSqDiff / period);

      upper[i] = sma[i]! + (stdDev * stdDevMultiplier);
      lower[i] = sma[i]! - (stdDev * stdDevMultiplier);
    }

    return {'middle': sma, 'upper': upper, 'lower': lower};
  }

  /// Calculates Keltner Channels
  static Map<String, List<double?>> calculateKeltnerChannels(
      List<Candle> candles,
      [int period = 20,
      int atrPeriod = 10,
      double multiplier = 1.5]) {
    List<double?> ema = calculateEMA(candles, period);
    List<double?> atr = calculateATR(candles, atrPeriod);
    List<double?> upper = List.filled(candles.length, null);
    List<double?> lower = List.filled(candles.length, null);

    for (int i = 0; i < candles.length; i++) {
      if (ema[i] != null && atr[i] != null) {
        upper[i] = ema[i]! + (atr[i]! * multiplier);
        lower[i] = ema[i]! - (atr[i]! * multiplier);
      }
    }

    return {'middle': ema, 'upper': upper, 'lower': lower};
  }

  /// Calculates MACD (Moving Average Convergence Divergence)
  static Map<String, List<double?>> calculateMACD(List<Candle> candles,
      [int fastPeriod = 12, int slowPeriod = 26, int signalPeriod = 9]) {
    List<double?> fastEMA = calculateEMA(candles, fastPeriod);
    List<double?> slowEMA = calculateEMA(candles, slowPeriod);

    List<double?> macdLine = List.filled(candles.length, null);

    // MACD Line = Fast EMA - Slow EMA
    for (int i = 0; i < candles.length; i++) {
      if (fastEMA[i] != null && slowEMA[i] != null) {
        macdLine[i] = fastEMA[i]! - slowEMA[i]!;
      }
    }

    // Signal Line = EMA of MACD Line

    List<double?> signalLine = List.filled(candles.length, null);
    List<double?> histogram = List.filled(candles.length, null);

    // Find first valid MACD index
    int firstValidIndex = -1;
    for (int i = 0; i < macdLine.length; i++) {
      if (macdLine[i] != null) {
        firstValidIndex = i;
        break;
      }
    }

    if (firstValidIndex != -1 &&
        (candles.length - firstValidIndex) >= signalPeriod) {
      // Calculate SMA for first Signal line point
      double sum = 0;
      for (int i = 0; i < signalPeriod; i++) {
        sum += macdLine[firstValidIndex + i]!;
      }
      signalLine[firstValidIndex + signalPeriod - 1] = sum / signalPeriod;

      double multiplier = 2 / (signalPeriod + 1);

      for (int i = firstValidIndex + signalPeriod; i < candles.length; i++) {
        signalLine[i] = (macdLine[i]! - signalLine[i - 1]!) * multiplier +
            signalLine[i - 1]!;
      }
    }

    for (int i = 0; i < candles.length; i++) {
      if (macdLine[i] != null && signalLine[i] != null) {
        histogram[i] = macdLine[i]! - signalLine[i]!;
      }
    }

    return {'macd': macdLine, 'signal': signalLine, 'histogram': histogram};
  }

  /// Calculates Stochastic Oscillator
  static Map<String, List<double?>> calculateStochastic(List<Candle> candles,
      [int kPeriod = 14, int dPeriod = 3]) {
    List<double?> kLine = List.filled(candles.length, null);

    for (int i = kPeriod - 1; i < candles.length; i++) {
      double highestHigh = -double.maxFinite;
      double lowestLow = double.maxFinite;

      for (int j = 0; j < kPeriod; j++) {
        if (candles[i - j].high > highestHigh) {
          highestHigh = candles[i - j].high;
        }
        if (candles[i - j].low < lowestLow) lowestLow = candles[i - j].low;
      }

      if (highestHigh != lowestLow) {
        kLine[i] =
            ((candles[i].close - lowestLow) / (highestHigh - lowestLow)) * 100;
      } else {
        kLine[i] = 50; // Fallback
      }
    }

    // Check signal period for D line which is SMA of K
    List<double?> dLine = List.filled(candles.length, null);

    int startD = kPeriod - 1 + dPeriod - 1;
    if (startD < candles.length) {
      // Calculate first SMA for D
      double sum = 0;
      int validPoints = 0;
      for (int j = 0; j < dPeriod; j++) {
        int kIndex = kPeriod - 1 + j;
        if (kLine[kIndex] != null) {
          sum += kLine[kIndex]!;
          validPoints++;
        }
      }
      if (validPoints == dPeriod) {
        dLine[kPeriod + dPeriod - 2] = sum / dPeriod;

        for (int i = kPeriod + dPeriod - 1; i < candles.length; i++) {
          sum += kLine[i]! - kLine[i - dPeriod]!;
          dLine[i] = sum / dPeriod;
        }
      }
    }

    return {'k': kLine, 'd': dLine};
  }

  /// Calculates VWAP (Volume Weighted Average Price)
  static List<double?> calculateVWAP(List<Candle> candles) {
    List<double?> vwap = List.filled(candles.length, null);

    double cumulativeTPV = 0;
    double cumulativeVolume = 0;

    int lastDay = -1;

    for (int i = 0; i < candles.length; i++) {
      // Assuming candles are sorted
      DateTime date = candles[i].date;
      if (date.day != lastDay) {
        cumulativeTPV = 0;
        cumulativeVolume = 0;
        lastDay = date.day;
      }

      double typicalPrice =
          (candles[i].high + candles[i].low + candles[i].close) / 3;
      double volume = candles[i].volume;

      cumulativeTPV += typicalPrice * volume;
      cumulativeVolume += volume;

      if (cumulativeVolume != 0) {
        vwap[i] = cumulativeTPV / cumulativeVolume;
      }
    }

    return vwap;
  }

  /// Calculates ATR (Average True Range)
  static List<double?> calculateATR(List<Candle> candles, [int period = 14]) {
    if (candles.length < period) return List.filled(candles.length, null);

    List<double> tr = List.filled(candles.length, 0.0);

    // TR for first candle is high - low
    tr[0] = candles[0].high - candles[0].low;

    for (int i = 1; i < candles.length; i++) {
      double hl = candles[i].high - candles[i].low;
      double hcp = (candles[i].high - candles[i - 1].close).abs();
      double lcp = (candles[i].low - candles[i - 1].close).abs();

      tr[i] = max(hl, max(hcp, lcp));
    }

    List<double?> atr = List.filled(candles.length, null);

    // First ATR is simple average of TR
    double sumTR = 0;
    for (int i = 0; i < period; i++) {
      sumTR += tr[i];
    }
    atr[period - 1] = sumTR / period;

    // Subsequent ATR is smoothed (RMA)
    for (int i = period; i < candles.length; i++) {
      atr[i] = (atr[i - 1]! * (period - 1) + tr[i]) / period;
    }

    return atr;
  }

  /// Calculates OBV (On Balance Volume)
  static List<double> calculateOBV(List<Candle> candles) {
    if (candles.isEmpty) return [];

    List<double> obv = List.filled(candles.length, 0.0);
    obv[0] = candles[0].volume;

    for (int i = 1; i < candles.length; i++) {
      if (candles[i].close > candles[i - 1].close) {
        obv[i] = obv[i - 1] + candles[i].volume;
      } else if (candles[i].close < candles[i - 1].close) {
        obv[i] = obv[i - 1] - candles[i].volume;
      } else {
        obv[i] = obv[i - 1];
      }
    }

    return obv;
  }

  /// Calculates Williams %R
  static List<double?> calculateWilliamsR(List<Candle> candles,
      [int period = 14]) {
    if (candles.length < period) return List.filled(candles.length, null);

    List<double?> wr = List.filled(candles.length, null);

    for (int i = period - 1; i < candles.length; i++) {
      double highestHigh = -double.maxFinite;
      double lowestLow = double.maxFinite;

      for (int j = 0; j < period; j++) {
        if (candles[i - j].high > highestHigh) {
          highestHigh = candles[i - j].high;
        }
        if (candles[i - j].low < lowestLow) lowestLow = candles[i - j].low;
      }

      if (highestHigh != lowestLow) {
        wr[i] = ((highestHigh - candles[i].close) / (highestHigh - lowestLow)) *
            -100;
      } else {
        wr[i] = -50;
      }
    }

    return wr;
  }

  /// Calculates CCI (Commodity Channel Index)
  static List<double?> calculateCCI(List<Candle> candles, [int period = 20]) {
    if (candles.length < period) return List.filled(candles.length, null);

    List<double?> cci = List.filled(candles.length, null);
    List<double> tp =
        candles.map((c) => (c.high + c.low + c.close) / 3).toList();

    for (int i = period - 1; i < candles.length; i++) {
      // Calculates SMA of TP
      double smaTp = 0;
      for (int j = 0; j < period; j++) {
        smaTp += tp[i - j];
      }
      smaTp /= period;

      // Calculate Mean Deviation
      double meanDev = 0;
      for (int j = 0; j < period; j++) {
        meanDev += (tp[i - j] - smaTp).abs();
      }
      meanDev /= period;

      if (meanDev != 0) {
        cci[i] = (tp[i] - smaTp) / (0.015 * meanDev);
      } else {
        cci[i] = 0;
      }
    }

    return cci;
  }

  /// Calculates ADX (Average Directional Index)
  static Map<String, List<double?>> calculateADX(List<Candle> candles,
      [int period = 14]) {
    if (candles.length < period * 2) return {'adx': [], 'pdi': [], 'mdi': []};

    List<double> tr = List.filled(candles.length, 0.0);
    List<double> dmPlus = List.filled(candles.length, 0.0);
    List<double> dmMinus = List.filled(candles.length, 0.0);

    tr[0] = candles[0].high - candles[0].low;

    for (int i = 1; i < candles.length; i++) {
      double hl = candles[i].high - candles[i].low;
      double hcp = (candles[i].high - candles[i - 1].close).abs();
      double lcp = (candles[i].low - candles[i - 1].close).abs();
      tr[i] = max(hl, max(hcp, lcp));

      double upMove = candles[i].high - candles[i - 1].high;
      double downMove = candles[i - 1].low - candles[i].low;

      if (upMove > downMove && upMove > 0) {
        dmPlus[i] = upMove;
      }

      if (downMove > upMove && downMove > 0) {
        dmMinus[i] = downMove;
      }
    }

    List<double?> atr = List.filled(candles.length, null);
    List<double?> smoothDmPlus = List.filled(candles.length, null);
    List<double?> smoothDmMinus = List.filled(candles.length, null);

    atr[period - 1] = tr.sublist(0, period).reduce((a, b) => a + b) / period;
    smoothDmPlus[period - 1] =
        dmPlus.sublist(0, period).reduce((a, b) => a + b) / period;
    smoothDmMinus[period - 1] =
        dmMinus.sublist(0, period).reduce((a, b) => a + b) / period;

    for (int i = period; i < candles.length; i++) {
      atr[i] = (atr[i - 1]! * (period - 1) + tr[i]) / period;
      smoothDmPlus[i] =
          (smoothDmPlus[i - 1]! * (period - 1) + dmPlus[i]) / period;
      smoothDmMinus[i] =
          (smoothDmMinus[i - 1]! * (period - 1) + dmMinus[i]) / period;
    }

    List<double?> diPlus = List.filled(candles.length, null);
    List<double?> diMinus = List.filled(candles.length, null);
    List<double?> dx = List.filled(candles.length, null);

    for (int i = period - 1; i < candles.length; i++) {
      if (atr[i] != 0 && atr[i] != null) {
        diPlus[i] = (smoothDmPlus[i]! / atr[i]!) * 100;
        diMinus[i] = (smoothDmMinus[i]! / atr[i]!) * 100;

        double diSum = diPlus[i]! + diMinus[i]!;
        double diDiff = (diPlus[i]! - diMinus[i]!).abs();

        if (diSum != 0) {
          dx[i] = (diDiff / diSum) * 100;
        } else {
          dx[i] = 0;
        }
      }
    }

    List<double?> adx = List.filled(candles.length, null);

    int startAdx = (period - 1) + (period - 1);

    if (startAdx < candles.length) {
      double sumDx = 0;
      for (int i = 0; i < period; i++) {
        sumDx += (dx[period - 1 + i] ?? 0);
      }
      adx[startAdx] = sumDx / period;

      for (int i = startAdx + 1; i < candles.length; i++) {
        double currentDx = dx[i] ?? 0;
        double prevAdx = adx[i - 1] ?? 0;
        adx[i] = (prevAdx * (period - 1) + currentDx) / period;
      }
    }

    return {'adx': adx, 'pdi': diPlus, 'mdi': diMinus};
  }

  /// Calculates Rate of Change (ROC)
  static List<double?> calculateROC(List<Candle> candles, [int period = 9]) {
    if (candles.length < period + 1) return List.filled(candles.length, null);

    List<double?> roc = List.filled(candles.length, null);

    for (int i = period; i < candles.length; i++) {
      double currentPrice = candles[i].close;
      double prevPrice = candles[i - period].close;

      if (prevPrice != 0) {
        roc[i] = ((currentPrice - prevPrice) / prevPrice) * 100;
      } else {
        roc[i] = 0;
      }
    }

    return roc;
  }

  /// Calculates Chaikin Money Flow (CMF)
  static List<double?> calculateChaikinMoneyFlow(List<Candle> candles,
      [int period = 20]) {
    if (candles.length < period) return List.filled(candles.length, null);

    List<double?> cmf = List.filled(candles.length, null);
    List<double> moneyFlowVolumes = [];
    List<double> volumes = [];

    for (int i = 0; i < candles.length; i++) {
      double h = candles[i].high;
      double l = candles[i].low;
      double c = candles[i].close;
      double v = candles[i].volume;

      double divisor = (h - l) == 0 ? 0.000001 : (h - l);
      double mfm = ((c - l) - (h - c)) / divisor;
      double mfv = mfm * v;

      moneyFlowVolumes.add(mfv);
      volumes.add(v);
    }

    for (int i = period - 1; i < candles.length; i++) {
      double sumMfv = 0;
      double sumVol = 0;

      for (int j = 0; j < period; j++) {
        sumMfv += moneyFlowVolumes[i - j];
        sumVol += volumes[i - j];
      }

      if (sumVol != 0) {
        cmf[i] = sumMfv / sumVol;
      } else {
        cmf[i] = 0;
      }
    }

    return cmf;
  }

  /// Calculates Ichimoku Cloud
  static Map<String, List<double?>> calculateIchimokuCloud(List<Candle> candles,
      [int conversionPeriod = 9,
      int basePeriod = 26,
      int spanBPeriod = 52,
      int displacement = 26]) {
    int len = candles.length;
    List<double?> conversionLine = List.filled(len, null);
    List<double?> baseLine = List.filled(len, null);
    List<double?> spanA = List.filled(len, null);
    List<double?> spanB = List.filled(len, null);
    List<double?> laggingSpan = List.filled(len, null);

    // Helper to get midpoint
    double? getMidpoint(int idx, int period) {
      if (idx < period - 1) return null;
      double highestHigh = -double.maxFinite;
      double lowestLow = double.maxFinite;
      for (int i = 0; i < period; i++) {
        if (candles[idx - i].high > highestHigh) {
          highestHigh = candles[idx - i].high;
        }
        if (candles[idx - i].low < lowestLow) {
          lowestLow = candles[idx - i].low;
        }
      }
      return (highestHigh + lowestLow) / 2;
    }

    for (int i = 0; i < len; i++) {
      conversionLine[i] = getMidpoint(i, conversionPeriod);
      baseLine[i] = getMidpoint(i, basePeriod);

      // Span A is (Conversion + Base) / 2, shifted forward by displacement
      // So Span A at [i + displacement] = (conv[i] + base[i]) / 2
      if (conversionLine[i] != null && baseLine[i] != null) {
        if (i + displacement < len) {
          spanA[i + displacement] = (conversionLine[i]! + baseLine[i]!) / 2;
        }
      }

      // Span B is midpoint of spanBPeriod, shifted forward
      double? midpointB = getMidpoint(i, spanBPeriod);
      if (midpointB != null) {
        if (i + displacement < len) {
          spanB[i + displacement] = midpointB;
        }
      }

      // Lagging Span is close price shifted backwards
      // laggingSpan[i - displacement] = close[i]
      if (i - displacement >= 0) {
        laggingSpan[i - displacement] = candles[i].close;
      }
    }

    return {
      'conversionLine': conversionLine,
      'baseLine': baseLine,
      'spanA': spanA,
      'spanB': spanB,
      'laggingSpan': laggingSpan
    };
  }

  /// Calculates Parabolic SAR
  static Map<String, List<dynamic>> calculateParabolicSAR(List<Candle> candles,
      [double startStep = 0.02, double maxStep = 0.2]) {
    if (candles.length < 2) {
      return {
        'sar': List<double?>.filled(candles.length, null),
        'isUptrend': List<bool?>.filled(candles.length, null)
      };
    }

    List<double?> sarList = List.filled(candles.length, null);
    List<bool?> isUptrendList = List.filled(candles.length, null);

    bool isUptrend = true;
    double ep = candles[0].high;
    double sar = candles[0].low;
    double af = startStep;

    sarList[0] = sar;
    isUptrendList[0] = isUptrend;

    for (int i = 1; i < candles.length; i++) {
      double prevSar = sar;
      sar = prevSar + af * (ep - prevSar);

      if (isUptrend) {
        if (i >= 1) sar = min(sar, candles[i - 1].low);
        if (i >= 2) sar = min(sar, candles[i - 2].low);

        if (candles[i].low < sar) {
          isUptrend = false;
          sar = ep;
          ep = candles[i].low;
          af = startStep;
        } else {
          if (candles[i].high > ep) {
            ep = candles[i].high;
            af = min(af + startStep, maxStep);
          }
        }
      } else {
        if (i >= 1) sar = max(sar, candles[i - 1].high);
        if (i >= 2) sar = max(sar, candles[i - 2].high);

        if (candles[i].high > sar) {
          isUptrend = true;
          sar = ep;
          ep = candles[i].high;
          af = startStep;
        } else {
          if (candles[i].low < ep) {
            ep = candles[i].low;
            af = min(af + startStep, maxStep);
          }
        }
      }

      sarList[i] = sar;
      isUptrendList[i] = isUptrend;
    }

    return {'sar': sarList, 'isUptrend': isUptrendList};
  }

  /// Calculates Fibonacci Levels (Retracements)
  /// Returns a map of levels for the latest window of [period]
  static Map<String, double>? calculateFibonacciLevels(List<Candle> candles,
      [int period = 50]) {
    if (candles.length < period) return null;

    // Use the latest 'period' candles
    int startIdx = candles.length - period;
    List<Candle> window = candles.sublist(startIdx);

    double maxHigh = -double.maxFinite;
    double minLow = double.maxFinite;

    for (var c in window) {
      if (c.high > maxHigh) maxHigh = c.high;
      if (c.low < minLow) minLow = c.low;
    }

    bool isUptrend = candles.last.close > candles[startIdx].close;
    double diff = maxHigh - minLow;

    if (diff == 0) return null;

    if (isUptrend) {
      // Retracement from High
      return {
        '0.0': maxHigh,
        '0.236': maxHigh - 0.236 * diff,
        '0.382': maxHigh - 0.382 * diff,
        '0.5': maxHigh - 0.5 * diff,
        '0.618': maxHigh - 0.618 * diff,
        '0.786': maxHigh - 0.786 * diff,
        '1.0': minLow,
      };
    } else {
      // Retracement from Low (bounce)
      return {
        '0.0': minLow,
        '0.236': minLow + 0.236 * diff,
        '0.382': minLow + 0.382 * diff,
        '0.5': minLow + 0.5 * diff,
        '0.618': minLow + 0.618 * diff,
        '0.786': minLow + 0.786 * diff,
        '1.0': maxHigh,
      };
    }
  }

  /// Calculates Pivot Points (Standard) for the latest candle based on previous
  static Map<String, double>? calculatePivotPoints(List<Candle> candles) {
    if (candles.length < 2) return null;

    // Previous candle (yesterday/last period)
    Candle prev = candles[candles.length - 2];

    double pp = (prev.high + prev.low + prev.close) / 3;
    double r1 = 2 * pp - prev.low;
    double s1 = 2 * pp - prev.high;
    double r2 = pp + (prev.high - prev.low);
    double s2 = pp - (prev.high - prev.low);
    double r3 = prev.high + 2 * (pp - prev.low);
    double s3 = prev.low - 2 * (prev.high - pp);

    return {
      'pp': pp,
      'r1': r1,
      's1': s1,
      'r2': r2,
      's2': s2,
      'r3': r3,
      's3': s3
    };
  }
}

import 'package:candlesticks/candlesticks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/utils/technical_indicators.dart';

void main() {
  group('TechnicalIndicators Tests', () {
    late List<Candle> candles;

    setUp(() {
      final now = DateTime.now();
      candles = List.generate(40, (index) {
        final basePrice = 100.0 + index * 0.5;
        return Candle(
          date: now.add(Duration(days: index)),
          open: basePrice,
          high: basePrice + 2.0,
          low: basePrice - 1.0,
          close: basePrice + 1.0,
          volume: 1000.0 + index * 10,
        );
      });
    });

    test(
        'calculateADX returns correct values and non-empty maps for sufficient candles',
        () {
      final result = TechnicalIndicators.calculateADX(candles, 14);

      expect(result.containsKey('adx'), isTrue);
      expect(result.containsKey('pdi'), isTrue);
      expect(result.containsKey('mdi'), isTrue);

      final adx = result['adx']!;
      final pdi = result['pdi']!;
      final mdi = result['mdi']!;

      expect(adx.length, equals(candles.length));
      expect(pdi.length, equals(candles.length));
      expect(mdi.length, equals(candles.length));

      // With 40 candles and period 14:
      // atr/pdi/mdi first non-null index is period - 1 = 13.
      expect(pdi[13], isNotNull);
      expect(mdi[13], isNotNull);

      // ADX start index is (14 - 1) + (14 - 1) = 26.
      expect(adx[25], isNull);
      expect(adx[26], isNotNull);
      expect(adx[26]!, greaterThan(0));
    });

    test('calculateADX returns empty lists when insufficient candles', () {
      final shortCandles = candles.sublist(0, 20); // 20 < 14 * 2 (28)
      final result = TechnicalIndicators.calculateADX(shortCandles, 14);

      expect(result['adx'], isEmpty);
      expect(result['pdi'], isEmpty);
      expect(result['mdi'], isEmpty);
    });

    test('calculateSMA calculates expected moving averages', () {
      final sma = TechnicalIndicators.calculateSMA(candles, 5);
      expect(sma.length, equals(candles.length));
      expect(sma[0], isNull);
      expect(sma[3], isNull);
      expect(sma[4], isNotNull);
    });
  });
}

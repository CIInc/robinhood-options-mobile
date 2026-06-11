import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/gamma_exposure_model.dart';

void main() {
  group('GEX Data Validation Tests', () {
    final mockGexJson = {
      'symbol': 'TSLA',
      'spotPrice': 200.0,
      'totalCallGEX': 1500000.0,
      'totalPutGEX': 500000.0,
      'totalNetGEX': 1000000.0,
      'gammaFlip': 195.0,
      'maxGammaStrike': 200.0,
      'dealerPositioning': 'long_gamma',
      'signalStrength': 50,
      'updatedAt': 1717750000000,
      'expirationFilter': 'all',
      'callWall': 210.0,
      'putWall': 190.0,
      'gexRatio': 0.75,
      'gexByStrike': [
        {
          'strike': 190.0,
          'callGamma': 0.01,
          'putGamma': 0.08,
          'callOI': 100.0,
          'putOI': 800.0,
          'callGEX': 20000.0,
          'putGEX': 160000.0,
          'netGEX': -140000.0,
        },
        {
          'strike': 195.0,
          'callGamma': 0.05,
          'putGamma': 0.05,
          'callOI': 400.0,
          'putOI': 400.0,
          'callGEX': 100000.0,
          'putGEX': 100000.0,
          'netGEX': 0.0,
        },
        {
          'strike': 200.0,
          'callGamma': 0.15,
          'putGamma': 0.02,
          'callOI': 1000.0,
          'putOI': 100.0,
          'callGEX': 300000.0,
          'putGEX': 40000.0,
          'netGEX': 260000.0,
        },
        {
          'strike': 210.0,
          'callGamma': 0.04,
          'putGamma': 0.001,
          'callOI': 1200.0,
          'putOI': 50.0,
          'callGEX': 400000.0,
          'putGEX': 10000.0,
          'netGEX': 390000.0,
        }
      ]
    };

    test('GammaExposureData should deserialize from JSON correctly', () {
      final gexData = GammaExposureData.fromJson(mockGexJson);

      expect(gexData.symbol, equals('TSLA'));
      expect(gexData.spotPrice, equals(200.0));
      expect(gexData.totalCallGEX, equals(1500000.0));
      expect(gexData.totalPutGEX, equals(500000.0));
      expect(gexData.totalNetGEX, equals(1000000.0));
      expect(gexData.gammaFlip, equals(195.0));
      expect(gexData.maxGammaStrike, equals(200.0));
      expect(gexData.dealerPositioning, equals(DealerPositioning.longGamma));
      expect(gexData.signalStrength, equals(50));
      expect(gexData.updatedAt, equals(1717750000000));
      expect(gexData.expirationFilter, equals('all'));
      expect(gexData.callWall, equals(210.0));
      expect(gexData.putWall, equals(190.0));
      expect(gexData.gexRatio, equals(0.75));

      expect(gexData.gexByStrike.length, equals(4));
      expect(gexData.gexByStrike[0].strike, equals(190.0));
      expect(gexData.gexByStrike[0].netGEX, equals(-140000.0));
    });

    test('GammaExposureData should serialize to JSON correctly', () {
      final originData = GammaExposureData.fromJson(mockGexJson);
      final json = originData.toJson();

      expect(json['symbol'], equals('TSLA'));
      expect(json['spotPrice'], equals(200.0));
      expect(json['totalCallGEX'], equals(1500000.0));
      expect(json['totalPutGEX'], equals(500000.0));
      expect(json['totalNetGEX'], equals(1000000.0));
      expect(json['gammaFlip'], equals(195.0));
      expect(json['maxGammaStrike'], equals(200.0));
      expect(json['dealerPositioning'], equals('long_gamma'));
      expect(json['signalStrength'], equals(50));
      expect(json['callWall'], equals(210.0));
      expect(json['putWall'], equals(190.0));
      expect(json['gexRatio'], equals(0.75));

      final gexByStrikeJson = json['gexByStrike'] as List<dynamic>;
      expect(gexByStrikeJson.length, equals(4));
      expect(gexByStrikeJson[0]['strike'], equals(190.0));
    });

    test('nearMoneyStrikes should return list sorted and closest to spot', () {
      final gexData = GammaExposureData.fromJson(mockGexJson);
      final nearMoney = gexData.nearMoneyStrikes;

      expect(nearMoney, isNotEmpty);
      expect(nearMoney.length, equals(4)); // only has 4 strikes total in mock
      // should be sorted mathematically by strike ascending
      expect(nearMoney[0].strike, equals(190.0));
      expect(nearMoney[1].strike, equals(195.0));
      expect(nearMoney[2].strike, equals(200.0));
      expect(nearMoney[3].strike, equals(210.0));
    });

    test('getVisibleStrikes should contain key GEX levels', () {
      final gexData = GammaExposureData.fromJson(mockGexJson);

      // Request visible strikes
      final visible = gexData.getVisibleStrikes(count: 2);

      // Key levels like callWall (210), putWall (190), gammaFlip (195), maxGammaStrike (200) must be included
      final strikes = visible.map((e) => e.strike).toList();
      expect(strikes, contains(210.0));
      expect(strikes, contains(190.0));
      expect(strikes, contains(195.0));
      expect(strikes, contains(200.0));
    });

    test('DealerPositioning displays correct label and description', () {
      const longGamma = DealerPositioning.longGamma;
      const shortGamma = DealerPositioning.shortGamma;
      const neutral = DealerPositioning.neutral;

      expect(longGamma.displayLabel, equals('Long Gamma'));
      expect(shortGamma.displayLabel, equals('Short Gamma'));
      expect(neutral.displayLabel, equals('Neutral'));

      expect(longGamma.description, contains('net long gamma'));
      expect(shortGamma.description, contains('net short gamma'));
      expect(neutral.description, contains('near zero'));
    });
  });
}

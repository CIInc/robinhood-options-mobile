import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/retail_order_flow.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('RetailOrderFlow & RetailOrderFlowPoint Models', () {
    test('parses retail order flow with direct percentage values', () {
      final json = {
        'instrument_id': 'inst_aapl_123',
        'symbol': 'AAPL',
        'updated_at': '2026-09-10T20:00:00Z',
        'buy_percentage': 62.4,
        'sell_percentage': 37.6,
        'net_buy_percentage': 24.8,
        'volume_change_percentage': -3.5,
        'num_buy_orders': 48300,
        'num_sell_orders': 29100,
        'sentiment_direction': 'bullish',
        'history': [
          {
            'date': '2026-09-09',
            'buy_percentage': 60.0,
            'sell_percentage': 40.0,
            'net_buy_percentage': 20.0,
            'volume_change_percentage': -2.0,
          },
          {
            'date': '2026-09-10',
            'buy_percentage': 62.4,
            'sell_percentage': 37.6,
            'net_buy_percentage': 24.8,
            'volume_change_percentage': -3.5,
          },
        ],
      };

      final flow = RetailOrderFlow.fromJson(json);

      expect(flow.instrumentId, 'inst_aapl_123');
      expect(flow.symbol, 'AAPL');
      expect(flow.buyPercentage, 62.4);
      expect(flow.sellPercentage, 37.6);
      expect(flow.netBuyPercentage, 24.8);
      expect(flow.volumeChangePercentage, -3.5);
      expect(flow.numBuyOrders, 48300);
      expect(flow.numSellOrders, 29100);
      expect(flow.direction, 'bullish');
      expect(flow.sentimentLabel, 'Bullish');
      expect(flow.isBullish, isTrue);
      expect(flow.isBearish, isFalse);
      expect(flow.isNeutral, isFalse);
      expect(flow.buyRatioFormatted, '62.4%');
      expect(flow.sellRatioFormatted, '37.6%');
      expect(flow.netBuyFormatted, '+24.8%');
      expect(flow.volumeChangeFormatted, '-3.5%');

      expect(flow.history.length, 2);
      expect(flow.history.first.buyFormatted, '60.0%');
      expect(flow.history.first.sellFormatted, '40.0%');
      expect(flow.history.first.netBuyFormatted, '+20.0%');
    });

    test('normalizes decimal fractions to 0-100 percentages', () {
      final json = {
        'id': 'inst_tsla_456',
        'symbol': 'TSLA',
        'buy_pct': 0.785,
        'sell_pct': 0.215,
        'volume_growth': 0.248,
      };

      final flow = RetailOrderFlow.fromJson(json);

      expect(flow.instrumentId, 'inst_tsla_456');
      expect(flow.symbol, 'TSLA');
      expect(flow.buyPercentage, closeTo(78.5, 0.01));
      expect(flow.sellPercentage, closeTo(21.5, 0.01));
      expect(flow.netBuyPercentage, closeTo(57.0, 0.01));
      expect(flow.volumeChangePercentage, closeTo(24.8, 0.01));
      expect(flow.sentimentLabel, 'Strong Bullish');
      expect(flow.isBullish, isTrue);
      expect(flow.netBuyFormatted, '+57.0%');
      expect(flow.volumeChangeFormatted, '+24.8%');
    });

    test('infers sellPercentage and netBuyPercentage when omitted', () {
      final json = {
        'instrument_id': 'inst_789',
        'buy_percentage': 72.0,
      };

      final flow = RetailOrderFlow.fromJson(json);

      expect(flow.buyPercentage, 72.0);
      expect(flow.sellPercentage, 28.0);
      expect(flow.netBuyPercentage, 44.0);
      expect(flow.sentimentLabel, 'Strong Bullish');
      expect(flow.isBullish, isTrue);
    });

    test('parses nested Robinhood API status & data wrapper structure', () {
      final json = {
        'status': 'SUCCESS',
        'data': {
          'instrument_id': 'f87d7cd7-a842-47cc-9b32-c607d96e7dfb',
          'symbol': 'PCG',
          'updated_at': '2026-09-10T16:00:00Z',
          'buy_percentage': 51.5,
          'sell_percentage': 48.5,
          'net_buy_percentage': 3.0,
          'volume_change_percentage': 2.1,
          'daily_sentiment': [
            {
              'date': '2026-09-09',
              'buy_percentage': 49.0,
              'sell_percentage': 51.0,
            },
            {
              'date': '2026-09-10',
              'buy_percentage': 51.5,
              'sell_percentage': 48.5,
            },
          ]
        }
      };

      final flow = RetailOrderFlow.fromJson(json);

      expect(flow.instrumentId, 'f87d7cd7-a842-47cc-9b32-c607d96e7dfb');
      expect(flow.symbol, 'PCG');
      expect(flow.buyPercentage, 51.5);
      expect(flow.sellPercentage, 48.5);
      expect(flow.sentimentLabel, 'Neutral');
      expect(flow.isNeutral, isTrue);
      expect(flow.isBullish, isFalse);
      expect(flow.isBearish, isFalse);
      expect(flow.history.length, 2);
    });

    test('parses exact Robinhood API example response with daily_transactions',
        () {
      final json = {
        "instrument_id": "943c5009-a0bb-4665-8cf4-a95dab5874e4",
        "daily_transactions": [
          {
            "date": "2026-08-12",
            "net_buy_percentage": 6.733010406913009,
            "net_sell_percentage": -6.733010406913009,
            "buy_volume_percentage_change": null,
            "sell_volume_percentage_change": null
          },
          {
            "date": "2026-08-13",
            "net_buy_percentage": 2.2814620083776327,
            "net_sell_percentage": -2.2814620083776327,
            "buy_volume_percentage_change": -34.70567348204625,
            "sell_volume_percentage_change": -28.611824946031497
          },
          {
            "date": "2026-08-14",
            "net_buy_percentage": -5.055151777329453,
            "net_sell_percentage": 5.055151777329453,
            "buy_volume_percentage_change": -13.866593391011422,
            "sell_volume_percentage_change": -0.24434133127768348
          },
          {
            "date": "2026-09-09",
            "net_buy_percentage": 31.58138057168694,
            "net_sell_percentage": -31.58138057168694,
            "buy_volume_percentage_change": 112.82247169835675,
            "sell_volume_percentage_change": 54.81522591529
          }
        ]
      };

      final flow = RetailOrderFlow.fromJson(json);

      expect(flow.instrumentId, '943c5009-a0bb-4665-8cf4-a95dab5874e4');
      expect(flow.history.length, 4);

      // Latest point is 2026-09-09 with +31.58% net buy
      expect(flow.netBuyPercentage, closeTo(31.58, 0.01));
      expect(flow.netSellPercentage, closeTo(-31.58, 0.01));
      // Derived buy: 50 + 31.58138 / 2 = 65.79%
      expect(flow.buyPercentage, closeTo(65.79, 0.01));
      expect(flow.sellPercentage, closeTo(34.21, 0.01));
      expect(flow.sentimentLabel, 'Bullish');
      expect(flow.isBullish, isTrue);
      expect(flow.buyVolumeChangePercentage, closeTo(112.82, 0.01));
      expect(flow.sellVolumeChangePercentage, closeTo(54.82, 0.01));
      expect(flow.updatedAt, DateTime(2026, 9, 9));

      // Check first point (2026-08-12)
      final firstPt = flow.history.first;
      expect(firstPt.date, DateTime(2026, 8, 12));
      expect(firstPt.netBuyPercentage, closeTo(6.73, 0.01));
      expect(firstPt.buyPercentage, closeTo(53.37, 0.01));
      expect(firstPt.sellPercentage, closeTo(46.63, 0.01));
      expect(firstPt.buyVolumeChangePercentage, isNull);
      expect(firstPt.sellVolumeChangePercentage, isNull);

      // Check point with negative net buy (2026-08-14)
      final negPt = flow.history[2];
      expect(negPt.netBuyPercentage, closeTo(-5.06, 0.01));
      expect(negPt.netSellPercentage, closeTo(5.06, 0.01));
      expect(negPt.buyPercentage, closeTo(47.47, 0.01));
      expect(negPt.sellPercentage, closeTo(52.53, 0.01));
    });

    test('correctly classifies Bearish and Strong Bearish sentiment regimes',
        () {
      final bearishJson = {
        'instrument_id': 'inst_bear',
        'buy_percentage': 38.0,
        'sell_percentage': 62.0,
        'volume_change_percentage': -12.4,
      };

      final bearishFlow = RetailOrderFlow.fromJson(bearishJson);
      expect(bearishFlow.sentimentLabel, 'Bearish');
      expect(bearishFlow.isBearish, isTrue);
      expect(bearishFlow.netBuyFormatted, '-24.0%');

      final strongBearishJson = {
        'instrument_id': 'inst_strong_bear',
        'buy_percentage': 24.5,
        'sell_percentage': 75.5,
      };

      final strongBearishFlow = RetailOrderFlow.fromJson(strongBearishJson);
      expect(strongBearishFlow.sentimentLabel, 'Strong Bearish');
      expect(strongBearishFlow.isBearish, isTrue);
      expect(strongBearishFlow.netBuyFormatted, '-51.0%');
    });

    test('RetailOrderFlowPoint parses date, volumes and formats properly', () {
      final pointJson = {
        'date': '2026-09-08',
        'buy_percentage': 82.5,
        'sell_percentage': 17.5,
        'net_buy_percentage': 65.0,
        'volume_change_percentage': 15.2,
        'num_buy_orders': 15200,
        'num_sell_orders': 3100,
      };

      final pt = RetailOrderFlowPoint.fromJson(pointJson);
      expect(pt.date, DateTime(2026, 9, 8));
      expect(pt.buyFormatted, '82.5%');
      expect(pt.sellFormatted, '17.5%');
      expect(pt.netBuyFormatted, '+65.0%');
      expect(pt.volumeChangeFormatted, '+15.2%');
      expect(pt.numBuyOrders, 15200);
      expect(pt.numSellOrders, 3100);
    });
  });

  group('DemoService Retail Order Flow Integration', () {
    final demoService = DemoService();
    final user = BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);

    test('returns Strong Bullish retail frenzy flow for GME', () async {
      final res = await demoService.getRetailSentiment(user, 'inst_gme_01');
      expect(res, isNotNull);

      final flow = RetailOrderFlow.fromJson(res as Map<String, dynamic>);
      expect(flow.symbol, 'GME');
      expect(flow.sentimentLabel, 'Strong Bullish');
      expect(flow.buyPercentage, greaterThan(80.0));
      expect(flow.volumeChangePercentage, greaterThan(50.0));
      expect(flow.history.length, 5);
    });

    test('returns Bullish retail flow for TSLA', () async {
      final res = await demoService.getRetailSentiment(user, 'inst_tsla_01');
      expect(res, isNotNull);

      final flow = RetailOrderFlow.fromJson(res as Map<String, dynamic>);
      expect(flow.symbol, 'TSLA');
      expect(flow.sentimentLabel, 'Strong Bullish');
      expect(flow.buyPercentage, closeTo(78.5, 0.1));
      expect(flow.history.isNotEmpty, isTrue);
    });

    test('returns Bearish retail flow for ticker with bear ID', () async {
      final res = await demoService.getRetailSentiment(user, 'inst_bear_etf');
      expect(res, isNotNull);

      final flow = RetailOrderFlow.fromJson(res as Map<String, dynamic>);
      expect(flow.sentimentLabel, 'Bearish');
      expect(flow.isBearish, isTrue);
      expect(flow.netBuyPercentage, lessThan(0));
    });

    test('returns default moderate Bullish retail flow for AAPL', () async {
      final res = await demoService.getRetailSentiment(user, 'inst_aapl_01');
      expect(res, isNotNull);

      final flow = RetailOrderFlow.fromJson(res as Map<String, dynamic>);
      expect(flow.symbol, 'AAPL');
      expect(flow.sentimentLabel, 'Bullish');
      expect(flow.buyPercentage, closeTo(65.8, 0.1));
      expect(flow.sellPercentage, closeTo(34.2, 0.1));
      expect(flow.netBuyPercentage, closeTo(31.58, 0.01));
      expect(flow.buyVolumeChangePercentage, closeTo(112.82, 0.01));
      expect(flow.sellVolumeChangePercentage, closeTo(54.82, 0.01));
    });
  });
}

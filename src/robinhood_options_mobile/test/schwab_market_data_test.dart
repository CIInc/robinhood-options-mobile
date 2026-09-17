import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_historical.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/midlands_movers_item.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

void main() {
  group('Schwab Market Data Tests', () {
    test('Quote.fromSchwabJson parses real-time quote correctly', () {
      final json = {
        'assetMainType': 'EQUITY',
        'assetSubType': 'CO',
        'quoteType': 'EQUITY',
        'realtime': true,
        'ssid': 12345,
        'symbol': 'AAPL',
        'reference': {
          'cusip': '037833100',
          'description': 'Apple Inc.',
          'exchange': 'Q',
          'exchangeName': 'NASDAQ',
        },
        'quote': {
          '52WeekHigh': 237.23,
          '52WeekLow': 164.08,
          'askPrice': 220.15,
          'askSize': 200,
          'bidPrice': 220.10,
          'bidSize': 100,
          'closePrice': 219.50,
          'highPrice': 221.00,
          'lastPrice': 220.12,
          'lowPrice': 218.80,
          'mark': 220.12,
          'netChange': 0.62,
          'netPercentChange': 0.28,
          'openPrice': 219.00,
          'postMarketPrice': 220.45,
          'quoteTime': 1726000000000,
          'totalVolume': 45000000,
          'tradeTime': 1726000000000,
          'securityStatus': 'Normal',
        },
      };

      final quote = Quote.fromSchwabJson(json);
      expect(quote.symbol, 'AAPL');
      expect(quote.lastTradePrice, 220.12);
      expect(quote.askPrice, 220.15);
      expect(quote.askSize, 200);
      expect(quote.bidPrice, 220.10);
      expect(quote.bidSize, 100);
      expect(quote.previousClose, 219.50);
      expect(quote.adjustedPreviousClose, 219.50);
      expect(quote.lastExtendedHoursTradePrice, 220.45);
      expect(quote.tradingHalted, isFalse);
      expect(quote.hasTraded, isTrue);
      expect(quote.instrumentId, '037833100');
    });

    test('Quote.fromSchwabJson handles halted security and zero volume', () {
      final json = {
        'symbol': 'HALT',
        'reference': {'cusip': '999999999'},
        'quote': {
          'lastPrice': 10.0,
          'openPrice': 10.0,
          'securityStatus': 'Halted',
          'totalVolume': 0,
        },
      };

      final quote = Quote.fromSchwabJson(json);
      expect(quote.tradingHalted, isTrue);
      expect(quote.hasTraded, isFalse);
      expect(quote.previousClose, 10.0);
    });

    test('Fundamentals.fromSchwabJson parses equity fundamentals correctly', () {
      final json = {
        'cusip': '037833100',
        'symbol': 'AAPL',
        'description': 'Apple Inc.',
        'exchange': 'NASDAQ',
        'assetType': 'EQUITY',
        'fundamental': {
          'symbol': 'AAPL',
          'high52': 237.23,
          'low52': 164.08,
          'dividendAmount': 1.00,
          'dividendYield': 0.45,
          'peRatio': 33.5,
          'pbRatio': 45.2,
          'sharesOutstanding': 15300000000.0,
          'marketCapFloat': 3400000000000.0,
          'marketCap': 3450000000000.0,
          'vol1DayAvg': 45000000.0,
          'vol10DayAvg': 48000000.0,
          'vol3MonthAvg': 50000000.0,
        },
      };

      final fundamentals = Fundamentals.fromSchwabJson(
        json,
        instrument: 'https://api.schwabapi.com/marketdata/v1/instruments?symbol=AAPL',
        description: 'Apple Inc.',
      );

      expect(fundamentals.high52Weeks, 237.23);
      expect(fundamentals.low52Weeks, 164.08);
      expect(fundamentals.dividendYield, 0.45);
      expect(fundamentals.peRatio, 33.5);
      expect(fundamentals.pbRatio, 45.2);
      expect(fundamentals.marketCap, 3450000000000.0);
      expect(fundamentals.float, 3400000000000.0);
      expect(fundamentals.sharesOutstanding, 15300000000.0);
      expect(fundamentals.volume, 45000000.0);
      expect(fundamentals.averageVolume2Weeks, 48000000.0);
      expect(fundamentals.averageVolume, 50000000.0);
      expect(fundamentals.description, 'Apple Inc.');
    });

    test('Parses Schwab price history candles into InstrumentHistoricals', () {
      final candlesJson = {
        'candles': [
          {
            'open': 220.10,
            'high': 221.50,
            'low': 219.80,
            'close': 220.90,
            'volume': 123456,
            'datetime': 1726000000000,
          },
          {
            'open': 220.90,
            'high': 222.00,
            'low': 220.50,
            'close': 221.75,
            'volume': 234567,
            'datetime': 1726000300000,
          },
        ],
        'empty': false,
        'previousClose': 219.50,
        'previousCloseDate': 1725900000000,
        'symbol': 'AAPL',
      };

      List<InstrumentHistorical> historicals = [];
      for (var c in candlesJson['candles'] as List) {
        historicals.add(InstrumentHistorical(
          DateTime.fromMillisecondsSinceEpoch(c['datetime'] as int, isUtc: true),
          parseDouble(c['open']),
          parseDouble(c['close']),
          parseDouble(c['high']),
          parseDouble(c['low']),
          (c['volume'] as num?)?.toInt() ?? 0,
          'regular',
          false,
        ));
      }

      final instrumentHistoricals = InstrumentHistoricals(
        'https://api.schwabapi.com/marketdata/v1/quotes?symbols=AAPL',
        'AAPL',
        '5minute',
        'day',
        'trading',
        parseDouble(candlesJson['previousClose']),
        DateTime.fromMillisecondsSinceEpoch(
            candlesJson['previousCloseDate'] as int,
            isUtc: true),
        historicals.first.openPrice,
        historicals.first.beginsAt,
        'AAPL',
        'AAPL',
        historicals,
      );

      expect(instrumentHistoricals.symbol, 'AAPL');
      expect(instrumentHistoricals.previousClosePrice, 219.50);
      expect(instrumentHistoricals.historicals.length, 2);
      expect(instrumentHistoricals.historicals[0].openPrice, 220.10);
      expect(instrumentHistoricals.historicals[0].closePrice, 220.90);
      expect(instrumentHistoricals.historicals[1].highPrice, 222.00);
      expect(instrumentHistoricals.historicals[1].volume, 234567);

      final store = InstrumentHistoricalsStore();
      store.set(instrumentHistoricals);
      expect(store.items, hasLength(1));
      expect(store.items.first.symbol, 'AAPL');
    });

    test('Parses Schwab market movers screeners into MidlandMoversItem', () {
      final screenersJson = {
        'screeners': [
          {
            'change': 12.45,
            'description': 'Fortinet Inc.',
            'direction': 'up',
            'last': 75.20,
            'symbol': 'FTNT',
            'totalVolume': 8540000,
          },
          {
            'change': 8.90,
            'description': 'NVIDIA Corp.',
            'direction': 'up',
            'last': 125.50,
            'symbol': 'NVDA',
            'totalVolume': 45000000,
          },
        ],
      };

      List<MidlandMoversItem> movers = [];
      for (var item in screenersJson['screeners'] as List) {
        movers.add(MidlandMoversItem(
          item['symbol'],
          item['symbol'],
          DateTime.now().toUtc(),
          (item['change'] as num?)?.toDouble(),
          (item['last'] as num?)?.toDouble(),
          item['description'] as String? ?? '',
        ));
      }

      expect(movers, hasLength(2));
      expect(movers[0].symbol, 'FTNT');
      expect(movers[0].marketHoursPriceMovement, 12.45);
      expect(movers[0].marketHoursLastPrice, 75.20);
      expect(movers[0].description, 'Fortinet Inc.');
      expect(movers[1].symbol, 'NVDA');
      expect(movers[1].marketHoursPriceMovement, 8.90);
    });

    test('Parses Schwab market movers with null or alternative field names safely', () {
      final screenersJson = {
        'screeners': [
          {
            'symbol': 'XYZ',
            'netPercentChange': 5.25,
            'lastPrice': 100.5,
            'description': 'XYZ Corp',
          },
          {
            'symbol': 'NULL_ITEM',
            'change': null,
            'last': null,
            'description': 'Null Corp',
          },
        ],
      };

      List<MidlandMoversItem> movers = [];
      for (var item in screenersJson['screeners'] as List) {
        double? change = (item['change'] as num?)?.toDouble() ??
            (item['netPercentChange'] as num?)?.toDouble() ??
            (item['percentChange'] as num?)?.toDouble() ??
            (item['netChange'] as num?)?.toDouble();
        if (change == null && item['change'] != null) {
          change = double.tryParse(item['change'].toString());
        }
        double? last = (item['last'] as num?)?.toDouble() ??
            (item['lastPrice'] as num?)?.toDouble() ??
            (item['price'] as num?)?.toDouble();
        if (last == null && item['last'] != null) {
          last = double.tryParse(item['last'].toString());
        }
        movers.add(MidlandMoversItem(
          item['symbol'],
          item['symbol'],
          DateTime.now().toUtc(),
          change,
          last,
          item['description'] as String? ?? '',
        ));
      }

      expect(movers, hasLength(2));
      expect(movers[0].marketHoursPriceMovement, 5.25);
      expect(movers[0].marketHoursLastPrice, 100.5);
      expect(movers[1].marketHoursPriceMovement, isNull);
      expect(movers[1].marketHoursLastPrice, isNull);

      // Verify null movement does not crash calculations like in search_widget
      final mover = movers[1];
      final movement = mover.marketHoursPriceMovement ?? 0.0;
      expect(movement > 0, isFalse);
      expect(movement < 0, isFalse);
      expect(movement.abs() / 100, 0.0);
    });

    test('Parses Schwab option expiration chain response', () {
      final expirationChainJson = {
        'status': 'SUCCESS',
        'expirationList': [
          {
            'expirationDate': '2026-09-18',
            'daysToExpiration': 3,
            'expirationType': 'S',
            'settlementType': 'P',
          },
          {
            'expirationDate': '2026-09-25',
            'daysToExpiration': 10,
            'expirationType': 'S',
            'settlementType': 'P',
          },
          {
            'expirationDate': '2026-10-16',
            'daysToExpiration': 31,
            'expirationType': 'R',
            'settlementType': 'P',
          },
        ],
      };

      List<DateTime> dates = [];
      for (var item in expirationChainJson['expirationList'] as List) {
        dates.add(DateTime.parse(item['expirationDate'] as String));
      }

      expect(dates, hasLength(3));
      expect(dates[0], DateTime(2026, 9, 18));
      expect(dates[1], DateTime(2026, 9, 25));
      expect(dates[2], DateTime(2026, 10, 16));
    });

    test('Position store updates quotes safely without throwing StateError', () {
      final store = InstrumentPositionStore();
      final pos1 = InstrumentPosition.fromSchwabJson(
        {
          'averagePrice': 150.0,
          'longQuantity': 10.0,
          'instrument': {
            'assetType': 'EQUITY',
            'cusip': 'CUSIP1',
            'symbol': 'AAPL',
            'type': 'COMMON_STOCK',
          },
        },
        accountNumber: 'account-1',
      );
      final pos2 = InstrumentPosition.fromSchwabJson(
        {
          'averagePrice': 155.0,
          'longQuantity': 5.0,
          'instrument': {
            'assetType': 'EQUITY',
            'cusip': 'CUSIP1',
            'symbol': 'AAPL',
            'type': 'COMMON_STOCK',
          },
        },
        accountNumber: 'account-2',
      );
      store.add(pos1);
      store.add(pos2);

      // Simulate quoteObjs containing AAPL and an unknown symbol MSFT (which has no position in store)
      final quoteAapl = Quote.fromSchwabJson({
        'symbol': 'AAPL',
        'quote': {
          'lastPrice': 220.0,
          'openPrice': 219.0,
        },
        'reference': {'cusip': 'CUSIP1'},
      });
      final quoteMsft = Quote.fromSchwabJson({
        'symbol': 'MSFT',
        'quote': {
          'lastPrice': 430.0,
          'openPrice': 428.0,
        },
        'reference': {'cusip': 'CUSIP2'},
      });

      final quoteObjs = [quoteAapl, quoteMsft];

      // Safe update using where()
      for (var quoteObj in quoteObjs) {
        var matchingPositions = store.items.where((element) =>
            element.instrumentObj != null &&
            element.instrumentObj!.symbol == quoteObj.symbol);
        for (var position in matchingPositions) {
          position.instrumentObj!.quoteObj = quoteObj;
          store.update(position);
        }
      }

      expect(pos1.instrumentObj?.quoteObj?.lastTradePrice, 220.0);
      expect(pos2.instrumentObj?.quoteObj?.lastTradePrice, 220.0);
    });

    test('Quote.fromSchwabJson falls back to defaultSymbol if symbol is absent', () {
      final quote = Quote.fromSchwabJson({
        'quote': {
          'lastPrice': 100.0,
          'closePrice': 98.0,
        },
      }, defaultSymbol: 'XYZ');

      expect(quote.symbol, 'XYZ');
      expect(quote.lastTradePrice, 100.0);
      expect(quote.adjustedPreviousClose, 98.0);
    });

    test('Store notifies listeners when position quotes are refreshed', () {
      final store = InstrumentPositionStore();
      final pos = InstrumentPosition.fromSchwabJson(
        {
          'averagePrice': 50.0,
          'longQuantity': 10.0,
          'instrument': {
            'assetType': 'EQUITY',
            'cusip': 'CUSIP-XYZ',
            'symbol': 'XYZ',
            'type': 'COMMON_STOCK',
          },
        },
        accountNumber: 'account-1',
      );
      store.add(pos);

      int notificationCount = 0;
      store.addListener(() {
        notificationCount++;
      });

      final quote = Quote.fromSchwabJson({
        'symbol': 'XYZ',
        'quote': {
          'lastPrice': 55.0,
          'closePrice': 52.0,
        },
      });

      var positions = store.items.where(
          (element) => element.instrumentObj?.symbol == quote.symbol);
      for (var p in positions) {
        if (p.instrumentObj != null) {
          p.instrumentObj!.quoteObj = quote;
          store.update(p);
        }
      }

      expect(notificationCount, greaterThan(0));
      expect(pos.instrumentObj?.quoteObj?.lastTradePrice, 55.0);
      expect(store.equity, 550.0); // 10 shares * $55.0
    });

    test('OptionMarketData.fromSchwabJson parses quotes, Greeks, and calculations correctly', () {
      final json = {
        'symbol': 'UBER  260220C00090000',
        'description': 'UBER 02/20/2026 90.00 C',
        'bid': 1.80,
        'ask': 1.95,
        'mark': 1.88,
        'markChange': 0.08,
        'last': 1.86,
        'closePrice': 1.80,
        'totalVolume': 350,
        'openInterest': 1200,
        'volatility': 35.5,
        'delta': 0.42,
        'gamma': 0.015,
        'theta': -0.02,
        'vega': 0.18,
        'rho': 0.05,
        'optionRoot': 'UBER',
      };

      final data = OptionMarketData.fromSchwabJson(json);

      expect(data.symbol, 'UBER');
      expect(data.occSymbol, 'UBER  260220C00090000');
      expect(data.markPrice, 1.88);
      expect(data.askPrice, 1.95);
      expect(data.bidPrice, 1.80);
      expect(data.lastTradePrice, 1.86);
      expect(data.previousClosePrice, 1.80);
      expect(data.delta, 0.42);
      expect(data.gamma, 0.015);
      expect(data.theta, -0.02);
      expect(data.vega, 0.18);
      expect(data.rho, 0.05);
      expect(data.impliedVolatility, 35.5);
      expect(data.openInterest, 1200);
      expect(data.volume, 350);
      expect(data.changeToday, closeTo(0.08, 0.001));
    });

    test('Defensive chains parser does not throw StateError on empty expiration maps', () {
      final emptyChainJson = {
        'status': 'SUCCESS',
        'symbol': 'GOOG',
        'callExpDateMap': <String, dynamic>{},
        'putExpDateMap': <String, dynamic>{},
      };

      OptionMarketData? parseMarketData(dynamic resultJson, String type) {
        var map = resultJson['${type.toLowerCase()}ExpDateMap'];
        if (map is Map && map.isNotEmpty) {
          var expEntry = map.entries.firstOrNull;
          if (expEntry != null &&
              expEntry.value is Map &&
              (expEntry.value as Map).isNotEmpty) {
            var strikeEntry = (expEntry.value as Map).entries.firstOrNull;
            if (strikeEntry != null &&
                strikeEntry.value is List &&
                (strikeEntry.value as List).isNotEmpty) {
              return OptionMarketData.fromSchwabJson(strikeEntry.value.first);
            }
          }
        }
        return null;
      }

      expect(() => parseMarketData(emptyChainJson, 'CALL'), returnsNormally);
      expect(parseMarketData(emptyChainJson, 'CALL'), isNull);
      expect(parseMarketData(emptyChainJson, 'PUT'), isNull);

      final populatedChainJson = {
        'status': 'SUCCESS',
        'symbol': 'GOOG',
        'callExpDateMap': {
          '2026-02-20:5': {
            '90.0': [
              {
                'symbol': 'GOOG  260220C00090000',
                'mark': 5.50,
                'closePrice': 5.00,
                'optionRoot': 'GOOG',
              }
            ]
          }
        }
      };

      final parsed = parseMarketData(populatedChainJson, 'CALL');
      expect(parsed, isNotNull);
      expect(parsed!.markPrice, 5.50);
      expect(parsed.symbol, 'GOOG');
    });

    test('OptionPositionStore and OptionInstrumentStore update and calculate equity', () {
      final account = Account.fromSchwabJson({
        'securitiesAccount': {
          'accountNumber': 'SCHWAB-OPT-1',
          'type': 'MARGIN',
          'currentBalances': {
            'liquidationValue': 10000.0,
            'cashBalance': 5000.0,
          },
        },
      });

      final posJson = {
        'shortQuantity': 0.0,
        'averagePrice': 2.50, // $250 total per contract
        'longQuantity': 2.0,
        'instrument': {
          'assetType': 'OPTION',
          'cusip': '0UBER.BK60090000',
          'symbol': 'UBER  260220C00090000',
          'description': 'UBER TECHNOLOGIES INC 02/20/2026 \$90 Call',
          'type': 'VANILLA',
          'putCall': 'CALL',
          'underlyingSymbol': 'UBER',
        },
      };

      final position = OptionAggregatePosition.fromSchwabJson(posJson, account);
      final optionStore = OptionPositionStore();
      final instrumentStore = OptionInstrumentStore();

      optionStore.add(position);
      expect(optionStore.items, hasLength(1));
      expect(position.marketValue, 0.0); // Before market data attached

      // Simulate refreshOptionMarketData attaching live quotes
      final liveData = OptionMarketData.fromSchwabJson({
        'symbol': 'UBER  260220C00090000',
        'optionRoot': 'UBER',
        'mark': 3.00,
        'closePrice': 2.80,
      });

      position.optionInstrument!.optionMarketData = liveData;
      instrumentStore.addOrUpdate(position.optionInstrument!);
      optionStore.update(position);

      // 2 contracts * 100 shares * $3.00 = $600 market value
      expect(position.marketValue, 600.0);
      // Total cost: 2 contracts * (2.50 * 100) = $500
      expect(position.totalCost, 500.0);
      // Gain: 600 - 500 = $100
      expect(position.gainLoss, 100.0);
      expect(optionStore.equity, 600.0);
    });

    test('getTopMovers converts MidlandMoversItem into Instruments with Quotes', () {
      final instrumentStore = InstrumentStore();
      final mover = MidlandMoversItem(
        'PLTR',
        'PLTR',
        DateTime.now().toUtc(),
        8.5, // 8.5% up
        35.0, // Last price $35.0
        'Palantir Technologies Inc.',
      );

      // Simulate getTopMovers logic
      final last = mover.marketHoursLastPrice;
      final pct = mover.marketHoursPriceMovement;
      final prevClose = (last != null && pct != null && (1 + pct / 100) != 0)
          ? last / (1 + pct / 100)
          : null;

      var instrument = Instrument.fromSchwabJson({
        'symbol': mover.symbol,
        'description':
            mover.description.isNotEmpty ? mover.description : mover.symbol,
        'assetType': 'stock',
      });
      instrument.quoteObj = Quote(
        symbol: mover.symbol,
        lastTradePrice: last,
        previousClose: prevClose,
        adjustedPreviousClose: prevClose,
        askSize: 0,
        bidSize: 0,
        tradingHalted: false,
        hasTraded: true,
        lastTradePriceSource: 'SCHW',
        instrument: '',
        instrumentId: mover.symbol,
        updatedAt: mover.updatedAt ?? DateTime.now().toUtc(),
      );
      instrumentStore.add(instrument);

      expect(instrumentStore.items, hasLength(1));
      final inst = instrumentStore.items.first;
      expect(inst.symbol, 'PLTR');
      expect(inst.quoteObj, isNotNull);
      expect(inst.quoteObj!.lastTradePrice, 35.0);
      expect(inst.quoteObj!.previousClose, closeTo(32.258, 0.001));
      expect(inst.quoteObj!.changeToday, closeTo(2.742, 0.001));
      expect(inst.quoteObj!.changePercentToday, closeTo(0.085, 0.001));
    });
  });
}

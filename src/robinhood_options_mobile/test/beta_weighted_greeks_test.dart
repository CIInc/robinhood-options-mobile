import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/utils/analytics_utils.dart';

Quote _makeQuote(String symbol, double price) {
  return Quote.fromJson({
    'symbol': symbol,
    'last_trade_price': price.toString(),
    'ask_price': price.toString(),
    'bid_price': price.toString(),
    'ask_size': 100,
    'bid_size': 100,
    'trading_halted': 'false',
    'has_traded': 'true',
    'last_trade_price_source': 'consolidated',
    'instrument': 'https://api.robinhood.com/instruments/$symbol/',
    'instrument_id': symbol,
  });
}

OptionInstrument _makeOptionInstrument({
  required String symbol,
  required String type,
  required double strikePrice,
  required double delta,
  double gamma = 0.0,
  double theta = 0.0,
  double vega = 0.0,
}) {
  return OptionInstrument.fromJson({
    'id': 'opt-$symbol',
    'chain_id': 'chain-$symbol',
    'symbol': symbol,
    'url': 'https://api.robinhood.com/options/instruments/opt-$symbol/',
    'expiration_date': '2026-12-31',
    'strike_price': strikePrice.toString(),
    'type': type,
    'chain_symbol': symbol,
    'min_ticks': <String, dynamic>{},
    'rhs_tradability': 'tradable',
    'state': 'active',
    'tradability': 'tradable',
    'long_strategy_code': 'buy',
    'short_strategy_code': 'sell',
    'option_market_data': {
      'instrument': 'opt-$symbol',
      'instrument_id': 'opt-$symbol',
      'last_trade_size': 1,
      'bid_size': 100,
      'ask_size': 100,
      'open_interest': 1000,
      'volume': 100,
      'symbol': symbol,
      'occ_symbol': '${symbol}261231C00000000',
      'delta': delta.toString(),
      'gamma': gamma.toString(),
      'theta': theta.toString(),
      'vega': vega.toString(),
    },
  });
}

InstrumentPosition _makeStockPosition({
  required String symbol,
  required double quantity,
  required double price,
}) {
  final pos = InstrumentPosition.fromJson({
    'url': 'https://api.robinhood.com/positions/$symbol/',
    'instrument': 'https://api.robinhood.com/instruments/$symbol/',
    'account': 'acc_1',
    'account_number': 'acc_1',
    'average_buy_price': price.toString(),
    'quantity': quantity.toString(),
    'avg_cost_affected': false,
  });
  pos.instrumentObj = Instrument.forSymbol(symbol)
    ..quoteObj = _makeQuote(symbol, price);
  return pos;
}

void main() {
  group('Beta-Weighted Portfolio Greeks Engine', () {
    test('calculates equity beta-weighted delta and SPY equivalent shares', () {
      final position = _makeStockPosition(
        symbol: 'AAPL',
        quantity: 100.0,
        price: 150.0,
      );

      // AAPL beta = 1.2, SPY price = $500
      // Dollar Delta = 100 * $150 = $15,000
      // Weighted Dollar Delta = $15,000 * 1.2 = $18,000
      // Equivalent SPY shares = $18,000 / $500 = 36.0
      // Dollar Delta 1% = $18,000 * 0.01 = $180.00
      final result = AnalyticsUtils.calculateBetaWeightedGreeks(
        equityPositions: [position],
        benchmarkSymbol: 'SPY',
        benchmarkPrice: 500.0,
        assetBetas: {'AAPL': 1.2},
      );

      expect(result.hasData, isTrue);
      expect(result.benchmarkSymbol, 'SPY');
      expect(result.benchmarkPrice, 500.0);
      expect(result.netDeltaShares, closeTo(36.0, 0.001));
      expect(result.dollarDelta1Pct, closeTo(180.0, 0.001));
      expect(result.equityDeltaShares, closeTo(36.0, 0.001));
      expect(result.optionDeltaShares, 0.0);
      expect(result.stance, 'Bullish');
      expect(result.topDrivers.length, 1);
      expect(result.topDrivers.first.symbol, 'AAPL');
      expect(result.topDrivers.first.beta, 1.2);
    });

    test('calculates inverse ETF with negative beta', () {
      final position = _makeStockPosition(
        symbol: 'SQQQ',
        quantity: 200.0,
        price: 10.0,
      );

      // SQQQ automatic beta = -3.0, SPY = $500
      // Dollar Delta = 200 * $10 = $2,000
      // Weighted Dollar Delta = $2,000 * (-3.0) = -$6,000
      // SPY equivalent shares = -$6,000 / $500 = -12.0
      // Dollar Delta 1% = -$6,000 * 0.01 = -$60.00
      final result = AnalyticsUtils.calculateBetaWeightedGreeks(
        equityPositions: [position],
        benchmarkSymbol: 'SPY',
        benchmarkPrice: 500.0,
      );

      expect(result.netDeltaShares, closeTo(-12.0, 0.001));
      expect(result.dollarDelta1Pct, closeTo(-60.0, 0.001));
      expect(result.stance, 'Bearish');
      expect(result.topDrivers.first.beta, -3.0);
    });

    test('calculates options delta beta-weighting with underlying spot price', () {
      final underlying = Instrument.forSymbol('NVDA')
        ..quoteObj = _makeQuote('NVDA', 120.0);

      final optionPos = OptionAggregatePosition(
        'pos-id',
        'chain-id',
        'acc-id',
        'NVDA',
        'call',
        5.0,
        [],
        2.0, // 2 contracts
        null,
        null,
        'debit',
        '',
        100.0,
        null,
        null,
        'long_call',
      )
        ..instrumentObj = underlying
        ..optionInstrument = _makeOptionInstrument(
          symbol: 'NVDA',
          type: 'call',
          strikePrice: 120.0,
          delta: 0.50,
          gamma: 0.04,
          theta: -0.15,
          vega: 0.25,
        );

      // 2 contracts * 100 * 0.50 delta = 100 share delta
      // Raw Dollar Delta = 100 * $120 spot = $12,000
      // NVDA beta = 1.75
      // Weighted Dollar Delta = $12,000 * 1.75 = $21,000
      // SPY equivalent shares = $21,000 / $500 = 42.0
      // 1% move = $210.00
      // Aggregate options Greeks:
      // netGamma = 0.04 * 200 = 8.0
      // netTheta = -0.15 * 200 = -30.0
      // netVega = 0.25 * 200 = 50.0
      final result = AnalyticsUtils.calculateBetaWeightedGreeks(
        optionPositions: [optionPos],
        benchmarkSymbol: 'SPY',
        benchmarkPrice: 500.0,
        assetBetas: {'NVDA': 1.75},
      );

      expect(result.optionDeltaShares, closeTo(42.0, 0.001));
      expect(result.netDeltaShares, closeTo(42.0, 0.001));
      expect(result.dollarDelta1Pct, closeTo(210.0, 0.001));
      expect(result.netGamma, closeTo(8.0, 0.001));
      expect(result.netTheta, closeTo(-30.0, 0.001));
      expect(result.netVega, closeTo(50.0, 0.001));
      expect(result.stance, 'Bullish');
    });

    test('combines cross-asset holdings (stocks, options, futures, crypto)', () {
      // 1. Stock: 50 shares of MSFT at $400, beta 1.1 -> $20,000 * 1.1 = $22,000
      final msftStock = _makeStockPosition(
        symbol: 'MSFT',
        quantity: 50.0,
        price: 400.0,
      );

      // 2. Put Option: Long 1 SPY Put (delta -0.30, spot $500, beta 1.0)
      // scale = 1 * 100 = 100; raw dollar delta = -30 * $500 = -$15,000
      // weighted = -$15,000 * 1.0 = -$15,000
      final spyPut = OptionAggregatePosition(
        'spy-put',
        'c-1',
        'a-1',
        'SPY',
        'put',
        2.0,
        [],
        1.0,
        null,
        null,
        'debit',
        '',
        100.0,
        null,
        null,
        'long_put',
      )
        ..instrumentObj = (Instrument.forSymbol('SPY')
          ..quoteObj = _makeQuote('SPY', 500.0))
        ..optionInstrument = _makeOptionInstrument(
          symbol: 'SPY',
          type: 'put',
          strikePrice: 495.0,
          delta: -0.30,
          gamma: 0.02,
          theta: -0.10,
          vega: 0.20,
        );

      // 3. Futures: /ES notional $50,000, beta 1.0 -> $50,000 * 1.0 = $50,000
      final futuresPos = {
        'symbol': '/ESU26',
        'notionalValue': 50000.0,
      };

      // 4. Crypto: BTC market value $10,000, beta 1.4 -> $10,000 * 1.4 = $14,000
      final cryptoHolding = ForexHolding.fromJson({
        'id': 'btc-1',
        'currency': {
          'id': 'cur-1',
          'code': 'BTC',
          'name': 'Bitcoin',
          'type': 'cryptocurrency',
        },
        'quantity': '0.15',
      })..quoteObj = ForexQuote.fromJson({
          'symbol': 'BTC',
          'id': 'btc-quote',
          'mark_price': '66666.67',
        });

      // Net Weighted Dollar Delta =
      // MSFT: $22,000
      // SPY Put: -$15,000
      // Futures: $50,000
      // Crypto: $14,000
      // Total = $71,000
      // SPY benchmark ($500):
      // Net Delta Shares = $71,000 / $500 = 142.0 shares
      // Dollar Delta 1% = $710.00
      final result = AnalyticsUtils.calculateBetaWeightedGreeks(
        equityPositions: [msftStock],
        optionPositions: [spyPut],
        futuresPositions: [futuresPos],
        forexHoldings: [cryptoHolding],
        benchmarkSymbol: 'SPY',
        benchmarkPrice: 500.0,
        assetBetas: {'MSFT': 1.1},
      );

      expect(result.hasData, isTrue);
      expect(result.totalPositions, 4);
      expect(result.pricedPositions, 4);
      expect(result.netDeltaShares, closeTo(142.0, 0.5));
      expect(result.dollarDelta1Pct, closeTo(710.0, 2.0));
      expect(result.equityDeltaShares, closeTo(44.0, 0.01)); // $22k / 500
      expect(result.optionDeltaShares, closeTo(-30.0, 0.01)); // -$15k / 500
      expect(result.futuresDeltaShares, closeTo(100.0, 0.01)); // $50k / 500
      expect(result.forexDeltaShares, closeTo(28.0, 0.5)); // $14k / 500
      expect(result.stance, 'Bullish');
      expect(result.topDrivers.length, 4);
    });

    test('handles empty or unpriced portfolio gracefully', () {
      final result = AnalyticsUtils.calculateBetaWeightedGreeks(
        equityPositions: [],
        optionPositions: [],
      );

      expect(result.hasData, isFalse);
      expect(result.netDeltaShares, 0.0);
      expect(result.dollarDelta1Pct, 0.0);
      expect(result.netGamma, 0.0);
      expect(result.netTheta, 0.0);
      expect(result.netVega, 0.0);
      expect(result.stance, 'Neutral');
      expect(result.topDrivers, isEmpty);
    });

    test('recalculates cleanly across different benchmark symbols', () {
      final position = _makeStockPosition(
        symbol: 'AAPL',
        quantity: 100.0,
        price: 200.0,
      );

      // Weighted Dollar Delta = 100 * $200 * 1.0 = $20,000
      // When benchmark is SPY at $500: Delta_SPY = 40.0 shares
      final spyResult = AnalyticsUtils.calculateBetaWeightedGreeks(
        equityPositions: [position],
        benchmarkSymbol: 'SPY',
        benchmarkPrice: 500.0,
      );
      expect(spyResult.netDeltaShares, closeTo(40.0, 0.001));

      // When benchmark is QQQ at $400: Delta_QQQ = 50.0 shares
      final qqqResult = AnalyticsUtils.calculateBetaWeightedGreeks(
        equityPositions: [position],
        benchmarkSymbol: 'QQQ',
        benchmarkPrice: 400.0,
      );
      expect(qqqResult.netDeltaShares, closeTo(50.0, 0.001));
    });

    test('sanitizes driver symbols avoiding raw IDs, UUIDs, or stringified maps', () {
      // 1. Futures position with nested map containing 'id' and 'rootSymbol'
      final futuresWithMap = {
        'contractId': '9330028e-455f-4acf-9954-77f60b19151d',
        'contract': {
          'id': '9330028e-455f-4acf-9954-77f60b19151d',
          'rootSymbol': 'ES',
          'symbol': 'ESU4',
          'name': 'E-mini S&P 500',
        },
        'product': {
          'symbol': '/ES',
          'name': 'E-mini S&P 500',
        },
        'notionalValue': 50000.0,
      };

      // 2. Futures position with only UUID contractId and no clean symbol
      final rawIdFutures = {
        'contractId': '96deed82-18b1-4f04-b77c-eb8530424d1a',
        'notionalValue': 20000.0,
      };

      // 3. Option with UUID symbol, but clean chainSymbol
      final uuidOption = OptionAggregatePosition(
        'pos-1',
        'chain-1',
        'acc-1',
        '96deed82-18b1-4f04-b77c-eb8530424d1a', // raw ID in symbol field
        'call',
        2.0,
        [],
        1.0,
        null,
        null,
        'debit',
        '',
        100.0,
        null,
        null,
        'long_call',
      )
        ..instrumentObj = (Instrument.forSymbol('AAPL')
          ..quoteObj = _makeQuote('AAPL', 200.0))
        ..optionInstrument = _makeOptionInstrument(
          symbol: 'AAPL',
          type: 'call',
          strikePrice: 200.0,
          delta: 0.5,
        );

      // 4. Equity position with UUID symbol
      final uuidEquity = InstrumentPosition.fromJson({
        'url': '',
        'instrument':
            'https://api.robinhood.com/instruments/6a256052-716b-4521-a324-447dc13c0fe3/',
        'account': 'acc-1',
        'account_number': 'acc-1',
        'average_buy_price': '100.0',
        'quantity': '10.0',
        'avg_cost_affected': false,
      })..instrumentObj =
          (Instrument.forSymbol('6a256052-716b-4521-a324-447dc13c0fe3')
            ..quoteObj =
                _makeQuote('6a256052-716b-4521-a324-447dc13c0fe3', 100.0));

      final result = AnalyticsUtils.calculateBetaWeightedGreeks(
        equityPositions: [uuidEquity],
        optionPositions: [uuidOption],
        futuresPositions: [futuresWithMap, rawIdFutures],
        benchmarkSymbol: 'SPY',
        benchmarkPrice: 500.0,
      );

      final symbols = result.topDrivers.map((d) => d.symbol).toList();
      // Should contain clean ticker symbols, not UUIDs, '{id:...}', or 'id'
      expect(symbols, contains('/ES'));
      expect(symbols, contains('Futures'));
      expect(symbols, contains('AAPL (Opt)'));
      expect(symbols, contains('Stock'));

      for (final s in symbols) {
        expect(s.startsWith('{'), isFalse);
        expect(s.toLowerCase(), isNot('id'));
        expect(s.contains('96deed82'), isFalse);
        expect(s.contains('6a256052'), isFalse);
        expect(s.contains('9330028e'), isFalse);
      }
    });
  });
}

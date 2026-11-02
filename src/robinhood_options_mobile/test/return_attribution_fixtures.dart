import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/quote.dart';

/// Shared fixtures for return attribution tests.
Quote attributionQuote(String symbol,
    {required double previousClose, required double price}) {
  return Quote(
    askPrice: price,
    askSize: 0,
    bidPrice: price,
    bidSize: 0,
    lastTradePrice: price,
    lastExtendedHoursTradePrice: price,
    previousClose: previousClose,
    adjustedPreviousClose: previousClose,
    previousCloseDate: DateTime(2026, 10, 30),
    symbol: symbol,
    tradingHalted: false,
    hasTraded: true,
    lastTradePriceSource: 'test',
    updatedAt: DateTime(2026, 11, 2),
    instrument: '',
    instrumentId: symbol,
  );
}

InstrumentPosition attributionStock({
  required String symbol,
  required String sector,
  required double quantity,
  required double previousClose,
  required double price,
}) {
  final pos = InstrumentPosition(
    'https://example.com/positions/$symbol/',
    'https://example.com/instruments/$symbol/',
    'https://example.com/accounts/acc_1/',
    'acc_1',
    previousClose,
    0,
    quantity,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    false,
    DateTime(2026, 1, 1),
    DateTime(2025, 1, 1),
  );
  pos.instrumentObj = Instrument.forSymbol(symbol)
    ..quoteObj =
        attributionQuote(symbol, previousClose: previousClose, price: price)
    ..fundamentalsObj = Fundamentals(sector: sector);
  return pos;
}

OptionAggregatePosition attributionOption({
  required String symbol,
  required String direction,
  required double quantity,
  required double underlyingPreviousClose,
  required double underlyingPrice,
  required double optionPreviousClose,
  required double optionMark,
  double delta = 0.5,
  double gamma = 0.02,
  double theta = -0.05,
  double vega = 0.12,
}) {
  final leg = OptionLeg(
    'leg-$symbol',
    null,
    direction == 'credit' ? 'short' : 'long',
    'option-1',
    'open',
    1,
    'buy',
    DateTime(2026, 11, 20),
    100,
    'call',
    [],
  );
  final opt = OptionAggregatePosition(
    'opt_pos_$symbol',
    'chain_$symbol',
    'acc_1',
    symbol,
    'long_call',
    optionPreviousClose,
    [leg],
    quantity,
    null,
    null,
    direction,
    direction,
    100.0,
    DateTime(2026, 1, 1),
    DateTime(2026, 1, 1),
    'long_call',
  );
  opt.instrumentObj = Instrument.forSymbol(symbol)
    ..quoteObj = attributionQuote(symbol,
        previousClose: underlyingPreviousClose, price: underlyingPrice);

  final optionInst = OptionInstrument(
    'chain_$symbol',
    symbol,
    DateTime(2026, 1, 1),
    DateTime(2026, 11, 20),
    'opt_inst_$symbol',
    DateTime(2026, 1, 1),
    MinTicks(0.01, 0.01, 3.0),
    'tradable',
    'active',
    100,
    'tradable',
    'call',
    DateTime(2026, 1, 1),
    'https://example.com/options/instruments/opt_inst_$symbol/',
    null,
    'call',
    'call',
  );
  optionInst.optionMarketData = OptionMarketData(
    optionMark, // adjustedMarkPrice
    optionMark,
    10,
    optionMark,
    10,
    100,
    optionMark,
    'https://example.com/options/instruments/opt_inst_$symbol/',
    'opt_inst_$symbol',
    optionMark,
    1,
    optionMark,
    optionMark, // markPrice
    100,
    DateTime(2026, 10, 30),
    optionPreviousClose, // previousClosePrice
    50,
    symbol,
    symbol,
    0.5,
    0.5,
    delta,
    gamma,
    0.25,
    0.01,
    theta,
    vega,
    optionMark,
    optionMark,
    optionMark,
    optionMark,
    DateTime(2026, 11, 2),
  );
  opt.optionInstrument = optionInst;
  return opt;
}

/// Sector ETF quotes: XLK +2%, XLF −1%, everything else flat.
List<Quote> attributionSectorQuotes({
  double techReturn = 0.02,
  double financialsReturn = -0.01,
}) {
  const etfs = [
    'XLK',
    'XLF',
    'XLV',
    'XLY',
    'XLC',
    'XLI',
    'XLP',
    'XLE',
    'XLU',
    'XLRE',
    'XLB'
  ];
  return [
    for (final etf in etfs)
      attributionQuote(
        etf,
        previousClose: 100,
        price: etf == 'XLK'
            ? 100 * (1 + techReturn)
            : etf == 'XLF'
                ? 100 * (1 + financialsReturn)
                : 100,
      ),
  ];
}

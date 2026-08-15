import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/screener_criterion.dart';

void main() {
  final instrument = Instrument(
    id: 'instrument-id',
    url: '',
    quote: '',
    fundamentals: '',
    splits: '',
    state: 'active',
    market: '',
    name: 'Example Corp',
    tradeable: true,
    tradability: 'tradable',
    symbol: 'EXMP',
    bloombergUnique: '',
    country: 'US',
    type: 'stock',
    rhsTradability: 'tradable',
    fractionalTradability: 'tradable',
    isSpac: false,
    isTest: false,
    ipoAccessSupportsDsp: false,
    dateCreated: DateTime(2026),
    quoteObj: const Quote(
      askSize: 1,
      bidSize: 1,
      lastTradePrice: 75,
      symbol: 'EXMP',
      tradingHalted: false,
      hasTraded: true,
      lastTradePriceSource: 'test',
      instrument: '',
      instrumentId: 'instrument-id',
    ),
    fundamentalsObj: const Fundamentals(
      marketCap: 5000000000,
      peRatio: 18,
      dividendYield: 2.5,
      averageVolume: 1500000,
      pbRatio: 3,
      low52Weeks: 50,
      high52Weeks: 100,
      sector: 'Technology Services',
    ),
  );

  test('matches multiple numeric factors with open-ended bounds', () {
    const criteria = [
      ScreenerCriterion(field: ScreenerField.marketCap, minimum: 1000000000),
      ScreenerCriterion(field: ScreenerField.peRatio, maximum: 20),
      ScreenerCriterion(field: ScreenerField.price, maximum: 100),
    ];

    expect(
        criteria.every((criterion) => criterion.matches(instrument)), isTrue);
  });

  test('matches sector and normalized 52-week position', () {
    final sector = ScreenerCriterion(
      field: ScreenerField.sector,
      textValue: 'Technology Services',
    );
    final position = ScreenerCriterion(
      field: ScreenerField.fiftyTwoWeekPosition,
      minimum: 40,
      maximum: 60,
    );

    expect(sector.matches(instrument), isTrue);
    expect(position.matches(instrument), isTrue);
  });

  test('rejects invalid ranges and round-trips JSON', () {
    final invalid = ScreenerCriterion(
      field: ScreenerField.pbRatio,
      minimum: 4,
      maximum: 2,
    );
    final original = ScreenerCriterion(
      field: ScreenerField.dividendYield,
      minimum: 2.5,
      maximum: 6,
    );

    expect(invalid.isValid, isFalse);
    expect(invalid.matches(instrument), isFalse);
    expect(ScreenerCriterion.fromJson(original.toJson()).toJson(),
        original.toJson());
  });
}

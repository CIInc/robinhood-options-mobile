import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/watchlist_item.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/watchlist_grid_item_widget.dart';

class MockIBrokerageService implements IBrokerageService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirebaseAnalytics implements FirebaseAnalytics {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockFirebaseAnalyticsObserver implements FirebaseAnalyticsObserver {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockGenerativeService implements GenerativeService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockIBrokerageService mockService;
  late MockFirebaseAnalytics mockAnalytics;
  late MockFirebaseAnalyticsObserver mockObserver;
  late MockGenerativeService mockGenerativeService;
  late BrokerageUser mockBrokerageUser;

  setUp(() {
    mockService = MockIBrokerageService();
    mockAnalytics = MockFirebaseAnalytics();
    mockObserver = MockFirebaseAnalyticsObserver();
    mockGenerativeService = MockGenerativeService();
    mockBrokerageUser =
        BrokerageUser(BrokerageSource.robinhood, 'test_user', '123', null);
  });

  testWidgets('WatchlistGridItemWidget renders positive semantic label',
      (WidgetTester tester) async {
    final instrument = Instrument.forSymbol('AAPL');
    instrument.quoteObj = const Quote(
      symbol: 'AAPL',
      askSize: 0,
      bidSize: 0,
      tradingHalted: false,
      hasTraded: true,
      lastTradePriceSource: 'consolidated',
      instrument: '',
      instrumentId: 'aapl-id',
      lastTradePrice: 150.0,
      adjustedPreviousClose: 146.34,
      previousClose: 146.34,
    );

    final watchListItem = WatchlistItem(
      '1',
      'instrument',
      'aapl-id',
      'http://api.robinhood.com/instruments/aapl-id/',
      DateTime.now(),
      'watchlist-1',
      'http://api.robinhood.com/watchlists/watchlist-1/',
    );
    watchListItem.instrumentObj = instrument;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WatchlistGridItemWidget(
            watchListItem,
            mockBrokerageUser,
            mockService,
            mockAnalytics,
            mockObserver,
            mockGenerativeService,
            null,
            null,
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(WatchlistGridItemWidget));
    expect(semantics.label, contains('AAPL'));
    expect(semantics.label, contains('up 2.50%'));
  });

  testWidgets('WatchlistGridItemWidget renders negative semantic label',
      (WidgetTester tester) async {
    final instrument = Instrument(
      id: 'tsla-id',
      url: '',
      quote: '',
      fundamentals: '',
      splits: '',
      state: 'active',
      market: '',
      simpleName: 'Tesla',
      name: 'Tesla, Inc.',
      tradeable: true,
      tradability: 'tradable',
      symbol: 'TSLA',
      bloombergUnique: '',
      country: 'US',
      type: 'stock',
      rhsTradability: 'tradable',
      fractionalTradability: 'tradable',
      isSpac: false,
      isTest: false,
      ipoAccessSupportsDsp: false,
      dateCreated: DateTime.now(),
    );
    instrument.quoteObj = const Quote(
      symbol: 'TSLA',
      askSize: 0,
      bidSize: 0,
      tradingHalted: false,
      hasTraded: true,
      lastTradePriceSource: 'consolidated',
      instrument: '',
      instrumentId: 'tsla-id',
      lastTradePrice: 200.0,
      adjustedPreviousClose: 210.0,
      previousClose: 210.0,
    );

    final watchListItem = WatchlistItem(
      '2',
      'instrument',
      'tsla-id',
      'http://api.robinhood.com/instruments/tsla-id/',
      DateTime.now(),
      'watchlist-1',
      'http://api.robinhood.com/watchlists/watchlist-1/',
    );
    watchListItem.instrumentObj = instrument;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WatchlistGridItemWidget(
            watchListItem,
            mockBrokerageUser,
            mockService,
            mockAnalytics,
            mockObserver,
            mockGenerativeService,
            null,
            null,
          ),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(WatchlistGridItemWidget));
    expect(semantics.label, contains('TSLA'));
    expect(semantics.label, contains('down 4.76%'));
    expect(semantics.label, contains('Tesla'));
  });
}

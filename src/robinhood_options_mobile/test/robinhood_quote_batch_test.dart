import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';

void main() {
  test('fetches quote batches concurrently with a bounded request count',
      () async {
    var activeRequests = 0;
    var maxActiveRequests = 0;
    final requestedSymbols = <String>{};
    final mockHttpClient = MockClient((request) async {
      final batchSymbols = request.url.queryParameters['symbols']!.split(',');
      requestedSymbols.addAll(batchSymbols);
      activeRequests++;
      if (activeRequests > maxActiveRequests) {
        maxActiveRequests = activeRequests;
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
      activeRequests--;

      return http.Response(
        jsonEncode({
          'results': batchSymbols.map((symbol) => _quoteJson(symbol)).toList(),
        }),
        200,
      );
    });
    final oauthClient = oauth2.Client(
      oauth2.Credentials('test-access-token'),
      httpClient: mockHttpClient,
    );
    final user = BrokerageUser(
      BrokerageSource.robinhood,
      'test-user',
      null,
      oauthClient,
    );
    final firestore = FakeFirebaseFirestore();
    final service = RobinhoodService(
      firestoreService: FirestoreService(firestore: firestore),
    );
    final quoteStore = QuoteStore()..add(_cachedQuote('SYM0'));
    final symbols = List.generate(152, (index) => 'SYM$index')..add('SYM1');

    try {
      final quotes = await service.getQuoteByIds(user, quoteStore, symbols);

      expect(quotes, hasLength(152));
      expect(quotes.map((quote) => quote.symbol).toSet(), hasLength(152));
      expect(requestedSymbols, hasLength(151));
      expect(requestedSymbols, isNot(contains('SYM0')));
      expect(maxActiveRequests, 3);
      expect(quoteStore.items, hasLength(152));
    } finally {
      oauthClient.close();
    }
  });
}

Quote _cachedQuote(String symbol) => Quote(
      askPrice: 1,
      askSize: 1,
      bidPrice: 1,
      bidSize: 1,
      lastTradePrice: 1,
      previousClose: 1,
      adjustedPreviousClose: 1,
      symbol: symbol,
      tradingHalted: false,
      hasTraded: true,
      lastTradePriceSource: 'test',
      instrument: 'https://api.robinhood.com/instruments/$symbol/',
      instrumentId: symbol,
    );

Map<String, dynamic> _quoteJson(String symbol) => {
      'ask_price': '1.00',
      'ask_size': 1,
      'bid_price': '1.00',
      'bid_size': 1,
      'last_trade_price': '1.00',
      'previous_close': '1.00',
      'adjusted_previous_close': '1.00',
      'symbol': symbol,
      'trading_halted': false,
      'has_traded': true,
      'last_trade_price_source': 'test',
      'instrument': 'https://api.robinhood.com/instruments/$symbol/',
      'instrument_id': symbol,
    };

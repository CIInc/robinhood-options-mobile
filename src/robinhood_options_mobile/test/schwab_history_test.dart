import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_order_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/option_order_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';
import 'package:robinhood_options_mobile/widgets/option_order_widget.dart';

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logScreenView({
    String? screenClass,
    String? screenName,
    Map<String, Object>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

class FakeFirebaseAnalyticsObserver extends Fake
    implements FirebaseAnalyticsObserver {}

class FakeGenerativeService extends Fake implements GenerativeService {}

void main() {
  group('Schwab History & Orders Tests', () {
    test('InstrumentOrder.fromSchwabJson parses equity limit order correctly',
        () {
      final json = {
        'orderId': 10001,
        'accountNumber': '12345678',
        'orderType': 'LIMIT',
        'status': 'FILLED',
        'duration': 'DAY',
        'price': 150.25,
        'quantity': 10,
        'filledQuantity': 10,
        'remainingQuantity': 0,
        'enteredTime': '2026-09-15T14:30:00.000Z',
        'closeTime': '2026-09-15T14:31:00.000Z',
        'orderLegCollection': [
          {
            'orderLegType': 'EQUITY',
            'instruction': 'BUY',
            'instrument': {
              'symbol': 'AAPL',
              'instrumentId': 12345,
            },
          },
        ],
      };

      final order = InstrumentOrder.fromSchwabJson(json);
      expect(order.id, '10001');
      expect(order.instrument, 'AAPL');
      expect(order.instrumentId, '12345');
      expect(order.state, 'filled');
      expect(order.type, 'limit');
      expect(order.side, 'buy');
      expect(order.quantity, 10.0);
      expect(order.cumulativeQuantity, 10.0);
      expect(order.price, 150.25);
      expect(order.averagePrice, 150.25);
      expect(order.stopPrice, isNull);
      expect(order.createdAt, DateTime.parse('2026-09-15T14:30:00.000Z'));
    });

    test(
        'InstrumentOrder.fromSchwabJson handles market order with null price safely',
        () {
      final json = {
        'orderId': 10002,
        'accountNumber': '12345678',
        'orderType': 'MARKET',
        'status': 'QUEUED',
        'duration': 'DAY',
        'price': null,
        'stopPrice': null,
        'quantity': 5,
        'filledQuantity': null,
        'remainingQuantity': 5,
        'enteredTime': '2026-09-15T15:00:00.000Z',
        'orderLegCollection': [
          {
            'orderLegType': 'EQUITY',
            'instruction': 'SELL',
            'instrument': {
              'symbol': 'TSLA',
              'instrumentId': 67890,
            },
          },
        ],
      };

      final order = InstrumentOrder.fromSchwabJson(json);
      expect(order.id, '10002');
      expect(order.instrument, 'TSLA');
      expect(order.state, 'queued');
      expect(order.type, 'market');
      expect(order.side, 'sell');
      expect(order.price, 0.0);
      expect(order.averagePrice, 0.0);
      expect(order.quantity, 5.0);
      expect(order.cumulativeQuantity, 0.0);
      expect(order.stopPrice, isNull);
    });

    test(
        'OptionOrder.fromSchwabJson parses single-leg option limit order correctly',
        () {
      final json = {
        'orderId': 20001,
        'orderType': 'LIMIT',
        'status': 'FILLED',
        'duration': 'DAY',
        'price': 2.50,
        'quantity': 2,
        'filledQuantity': 2,
        'remainingQuantity': 0,
        'enteredTime': '2026-09-15T14:40:00.000Z',
        'closeTime': '2026-09-15T14:41:00.000Z',
        'orderLegCollection': [
          {
            'orderLegType': 'OPTION',
            'instruction': 'BUY_TO_OPEN',
            'instrument': {
              'symbol': 'AAPL  260918C00230000',
              'instrumentId': 99999,
              'underlyingSymbol': 'AAPL',
            },
          },
        ],
        'orderActivityCollection': [
          {
            'executionLegs': [
              {
                'price': 2.50,
                'quantity': 2,
              },
            ],
          },
        ],
      };

      final order = OptionOrder.fromSchwabJson(json);
      expect(order.id, '20001');
      expect(order.chainSymbol, 'AAPL');
      expect(order.chainId, '99999');
      expect(order.state, 'filled');
      expect(order.type, 'limit');
      expect(order.direction, 'debit');
      expect(order.price, 2.50);
      expect(order.premium, 2.50);
      expect(order.quantity, 2.0);
      expect(order.processedQuantity, 2.0);
      expect(order.processedPremium, 500.0);
      expect(order.canceledQuantity, 0.0);
      expect(order.legs, hasLength(1));
    });

    test(
        'OptionOrder.fromSchwabJson handles market order with null price safely',
        () {
      final json = {
        'orderId': 20002,
        'orderType': 'MARKET',
        'status': 'WORKING',
        'duration': 'DAY',
        'price': null,
        'quantity': 1,
        'filledQuantity': null,
        'remainingQuantity': 1,
        'enteredTime': '2026-09-15T15:10:00.000Z',
        'orderLegCollection': [
          {
            'orderLegType': 'OPTION',
            'instruction': 'SELL_TO_CLOSE',
            'instrument': {
              'symbol': 'NVDA  260918P00115000',
              'instrumentId': 88888,
              'underlyingSymbol': 'NVDA',
            },
          },
        ],
      };

      final order = OptionOrder.fromSchwabJson(json);
      expect(order.id, '20002');
      expect(order.chainSymbol, 'NVDA');
      expect(order.state, 'working');
      expect(order.type, 'market');
      expect(order.direction, 'credit');
      expect(order.price, 0.0);
      expect(order.premium, 0.0);
      expect(order.quantity, 1.0);
      expect(order.pendingQuantity, 1.0);
      expect(order.processedQuantity, 0.0);
      expect(order.canceledQuantity, 0.0);
    });

    test('Schwab user session validity: token expired but canRefresh is true',
        () {
      final credentials = oauth2.Credentials(
        'expired_access_token',
        refreshToken: 'valid_refresh_token',
        tokenEndpoint: Uri.parse('https://api.schwabapi.com/v1/oauth/token'),
        expiration: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(credentials.isExpired, isTrue);
      expect(credentials.canRefresh, isTrue);

      final client = oauth2.Client(
        credentials,
        identifier: 'client_id',
        secret: 'client_secret',
      );

      final user = BrokerageUser(
        BrokerageSource.schwab,
        'test_schwab',
        credentials.toJson(),
        client,
      );

      // Verify the session validity logic implemented in history_widget.dart
      final isValidForHistory = user.oauth2Client != null &&
          (!user.oauth2Client!.credentials.isExpired ||
              user.oauth2Client!.credentials.canRefresh);
      expect(isValidForHistory, isTrue);

      final isSessionExpired = user.oauth2Client == null ||
          (user.oauth2Client!.credentials.isExpired &&
              !user.oauth2Client!.credentials.canRefresh);
      expect(isSessionExpired, isFalse);
    });

    test(
        'Schwab user session validity: token expired and cannot refresh is false',
        () {
      final credentials = oauth2.Credentials(
        'expired_access_token',
        tokenEndpoint: Uri.parse('https://api.schwabapi.com/v1/oauth/token'),
        expiration: DateTime.now().subtract(const Duration(hours: 1)),
      );
      expect(credentials.isExpired, isTrue);
      expect(credentials.canRefresh, isFalse);

      final client = oauth2.Client(
        credentials,
        identifier: 'client_id',
        secret: 'client_secret',
      );

      final user = BrokerageUser(
        BrokerageSource.schwab,
        'test_schwab',
        credentials.toJson(),
        client,
      );

      final isValidForHistory = user.oauth2Client != null &&
          (!user.oauth2Client!.credentials.isExpired ||
              user.oauth2Client!.credentials.canRefresh);
      expect(isValidForHistory, isFalse);

      final isSessionExpired = user.oauth2Client == null ||
          (user.oauth2Client!.credentials.isExpired &&
              !user.oauth2Client!.credentials.canRefresh);
      expect(isSessionExpired, isTrue);
    });

    test('SchwabService streams yield empty list gracefully on error',
        () async {
      final service = SchwabService();
      // User with null client will throw in getJson
      final user = BrokerageUser(BrokerageSource.schwab, 'user', null, null);

      final positionOrders = await service
          .streamPositionOrders(
            user,
            InstrumentOrderStore(),
            InstrumentStore(),
          )
          .first;
      expect(positionOrders, isEmpty);

      final optionOrders = await service
          .streamOptionOrders(
            user,
            OptionOrderStore(),
          )
          .first;
      expect(optionOrders, isEmpty);
    });

    test('SchwabService.getInstrument returns cached instrument from store',
        () async {
      final service = SchwabService();
      final user = BrokerageUser(BrokerageSource.schwab, 'user', null, null);
      final store = InstrumentStore();
      final inst = Instrument.forSymbol('AAPL', instrumentUrl: 'AAPL');
      store.add(inst);

      final result = await service.getInstrument(user, store, 'AAPL');
      expect(result.symbol, 'AAPL');
      expect(result.id, inst.id);
    });

    test(
        'SchwabService.getInstrument handles symbol and returns fallback without throwing UnimplementedError',
        () async {
      final service = SchwabService();
      // Client is null so network fails gracefully and falls back to Instrument.forSymbol
      final user = BrokerageUser(BrokerageSource.schwab, 'user', null, null);
      final store = InstrumentStore();

      final result = await service.getInstrument(user, store, 'MSFT');
      expect(result.symbol, 'MSFT');
      expect(store.items.any((e) => e.symbol == 'MSFT'), isTrue);
    });

    test(
        'SchwabService.getInstrumentsByIds returns instruments for symbol list',
        () async {
      final service = SchwabService();
      final user = BrokerageUser(BrokerageSource.schwab, 'user', null, null);
      final store = InstrumentStore();

      final results =
          await service.getInstrumentsByIds(user, store, ['NVDA', 'TSLA']);
      expect(results.length, 2);
      expect(
          results.map((e) => e.symbol).toList(), containsAll(['NVDA', 'TSLA']));
    });

    testWidgets(
        'OptionOrderWidget renders successfully for Schwab option order',
        (tester) async {
      final service = SchwabService();
      final user =
          BrokerageUser(BrokerageSource.schwab, 'schwab_user', null, null);
      final instrumentStore = InstrumentStore();
      final quoteStore = QuoteStore();

      final optionOrder = OptionOrder.fromSchwabJson({
        'orderId': 20001,
        'orderType': 'LIMIT',
        'status': 'FILLED',
        'duration': 'DAY',
        'price': 2.45,
        'quantity': 2,
        'filledQuantity': 2,
        'remainingQuantity': 0,
        'enteredTime': '2026-09-15T16:00:00.000Z',
        'closeTime': '2026-09-15T16:05:00.000Z',
        'orderLegCollection': [
          {
            'orderLegType': 'OPTION',
            'instruction': 'BUY_TO_OPEN',
            'instrument': {
              'symbol': 'AAPL  260918C00150000',
              'underlyingSymbol': 'AAPL',
              'instrumentId': 54321,
            },
          },
        ],
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: instrumentStore),
            ChangeNotifierProvider.value(value: quoteStore),
          ],
          child: MaterialApp(
            home: OptionOrderWidget(
              user,
              service,
              optionOrder,
              analytics: FakeFirebaseAnalytics(),
              observer: FakeFirebaseAnalyticsObserver(),
              generativeService: FakeGenerativeService(),
              user: null,
              userDocRef: null,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header components
      expect(find.textContaining('AAPL'), findsWidgets);
      expect(find.text('FILLED'), findsOneWidget);
      expect(find.text('Order Detail'), findsOneWidget);
      expect(find.text('Execution'), findsOneWidget);
      expect(find.text('Quantity'), findsOneWidget);
    });
  });
}

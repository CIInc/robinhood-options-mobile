import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';

void main() {
  test('fetches the live futures quote for a contract', () async {
    late Uri requestedUri;
    final mockHttpClient = MockClient((request) async {
      requestedUri = request.url;
      return http.Response(
        jsonEncode({
          'status': 'SUCCESS',
          'data': [
            {
              'status': 'SUCCESS',
              'data': {
                'instrument_id': 'contract-1',
                'last_trade_price': '5200.25',
              },
            },
          ],
        }),
        200,
      );
    });
    final oauthClient = oauth2.Client(
      oauth2.Credentials('test-access-token'),
      httpClient: mockHttpClient,
    );
    final user = BrokerageUser(
        BrokerageSource.robinhood, 'test-user', null, oauthClient);
    final service = RobinhoodService(
      firestoreService: FirestoreService(firestore: FakeFirebaseFirestore()),
    );

    try {
      expect(await service.getFuturesQuote(user, 'contract-1'), 5200.25);
      expect(requestedUri.path, '/marketdata/futures/quotes/v1/');
      expect(requestedUri.queryParameters['ids'], 'contract-1');
    } finally {
      oauthClient.close();
    }
  });

  test('rejects failed futures order responses', () async {
    final mockHttpClient = MockClient((_) async => http.Response('{}', 403));
    final oauthClient = oauth2.Client(
      oauth2.Credentials('test-access-token'),
      httpClient: mockHttpClient,
    );
    final user = BrokerageUser(
        BrokerageSource.robinhood, 'test-user', null, oauthClient);
    final service = RobinhoodService(
      firestoreService: FirestoreService(firestore: FakeFirebaseFirestore()),
    );

    try {
      await expectLater(
        service.placeFuturesOrder(
          user,
          'account-1',
          'contract-1',
          'BUY',
          1,
        ),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('403'),
        )),
      );
    } finally {
      oauthClient.close();
    }
  });
}

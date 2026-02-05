import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/portfolio_analytics_widget.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/model/user.dart';

class FakeBrokerageService implements IBrokerageService {
  @override
  Future<dynamic> search(BrokerageUser user, String query) async {
    return {'results': []};
  }

  @override
  noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {}

class FakeFirebaseAnalyticsObserver extends Fake
    implements FirebaseAnalyticsObserver {}

class FakeGenerativeService extends Fake implements GenerativeService {}

void main() {
  testWidgets('PortfolioAnalyticsWidget renders correctly',
      (WidgetTester tester) async {
    final fakeService = FakeBrokerageService();
    final user =
        BrokerageUser(BrokerageSource.robinhood, 'test_user', '123', null);
    final appUser = User(
      devices: [],
      dateCreated: DateTime.now(),
      brokerageUsers: [],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => InstrumentPositionStore()),
          ChangeNotifierProvider(create: (_) => OptionPositionStore()),
          ChangeNotifierProvider(create: (_) => PortfolioHistoricalsStore()),
          ChangeNotifierProvider(create: (_) => InstrumentHistoricalsStore()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PortfolioAnalyticsWidget(
              user: user,
              service: fakeService,
              analytics: FakeFirebaseAnalytics(),
              observer: FakeFirebaseAnalyticsObserver(),
              generativeService: FakeGenerativeService(),
              appUser: appUser,
              userDocRef: null,
            ),
          ),
        ),
      ),
    );

    // Allow Future.delayed and other async ops to complete
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byType(PortfolioAnalyticsWidget), findsOneWidget);
  });
}

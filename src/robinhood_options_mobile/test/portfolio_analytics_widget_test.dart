import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/portfolio_analytics_widget.dart';
import 'package:robinhood_options_mobile/enums.dart';

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

void main() {
  testWidgets('PortfolioAnalyticsWidget renders correctly',
      (WidgetTester tester) async {
    final fakeService = FakeBrokerageService();
    final user =
        BrokerageUser(BrokerageSource.robinhood, 'test_user', '123', null);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PortfolioHistoricalsStore()),
          ChangeNotifierProvider(create: (_) => InstrumentHistoricalsStore()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PortfolioAnalyticsWidget(
              user: user,
              service: fakeService,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PortfolioAnalyticsWidget), findsOneWidget);
  });
}

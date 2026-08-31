import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/widgets/login_widget.dart';

import 'firebase_mocks.dart';

void main() {
  setUp(() async {
    await setupFirebaseMocks();
  });

  testWidgets(
      'login carousel adds an invisible end spacer so final option stays swipe-reachable',
      (tester) async {
    final analytics = FirebaseAnalytics.instance;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => BrokerageUserStore([], 0),
        child: MaterialApp(
          home: LoginWidget(
            analytics: analytics,
            observer: FirebaseAnalyticsObserver(analytics: analytics),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final carousel = tester.widget<CarouselView>(find.byType(CarouselView));
    expect(carousel.children, hasLength(6));
    expect(find.text('Fidelity'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/web_promotion_banner_widget.dart';

void main() {
  testWidgets('renders the mobile app promotion in a sliver list', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 600,
              child: CustomScrollView(
                slivers: [WebPromotionBannerSliver()],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Take RealizeAlpha with you'), findsOneWidget);
    expect(
      find.text(
        'Explore the mobile app for a focused, on-the-go '
        'portfolio and market research experience.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

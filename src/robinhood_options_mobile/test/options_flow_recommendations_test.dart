import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/option_flow_item.dart';
import 'package:robinhood_options_mobile/model/options_flow_store.dart';
import 'package:robinhood_options_mobile/widgets/option_flow_list_item.dart';

void main() {
  test('every documented options flow flag has a recommendation', () {
    expect(
      OptionsFlowStore.flagRecommendations.keys.toSet(),
      containsAll(OptionsFlowStore.flagDocumentation.keys),
    );
  });

  test('tooltip includes definition, item reason, and recommendation', () {
    final message = buildOptionFlowTooltipMessage(
      'Golden Sweep',
      reason: 'Trade executed above the ask.',
    );

    expect(
      message,
      '${OptionsFlowStore.flagDocumentation['Golden Sweep']}\n\n'
      'Trade executed above the ask.\n\n'
      'Recommendation: '
      '${OptionsFlowStore.flagRecommendations['Golden Sweep']}',
    );
  });

  test('recommendations preserve priority and remove duplicate labels', () {
    final recommendations = buildOptionFlowRecommendations([
      'Golden Sweep',
      '0DTE',
      'Golden Sweep',
      'Not Documented',
      'BULLISH',
    ]);

    expect(
      recommendations.map((entry) => entry.key),
      ['Golden Sweep', '0DTE', 'BULLISH'],
    );
  });

  testWidgets('flag opens structured guidance sheet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: OptionFlowFlagBadge(
              flag: 'Golden Sweep',
              reason: 'Trade executed above the ask.',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Golden Sweep'));
    await tester.pumpAndSettle();

    expect(find.text('Definition'), findsOneWidget);
    expect(find.text('Why it was detected'), findsOneWidget);
    expect(find.text('Recommendation'), findsOneWidget);
    expect(find.text('Trade executed above the ask.'), findsOneWidget);
  });

  testWidgets('flag guidance exposes an accessible button action',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: OptionFlowFlagBadge(
              flag: 'Golden Sweep',
              reason: 'Trade executed above the ask.',
            ),
          ),
        ),
      ),
    );

    final guidanceFinder =
        find.bySemanticsLabel(RegExp('Golden Sweep guidance'));
    expect(guidanceFinder, findsOneWidget);

    final semantics = tester.getSemantics(guidanceFinder).getSemanticsData();
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);

    semanticsHandle.dispose();
  });

  testWidgets('OptionFlowListItem exposes unified accessible semantics',
      (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    final item = OptionFlowItem(
      symbol: 'AAPL',
      lastTradeDate: DateTime.now(),
      strike: 150.0,
      expirationDate: DateTime.now().add(const Duration(days: 30)),
      type: 'CALL',
      spotPrice: 155.0,
      premium: 500000,
      volume: 1200,
      openInterest: 500,
      impliedVolatility: 0.35,
      flowType: FlowType.sweep,
      sentiment: Sentiment.bullish,
      details: 'Above Ask',
      flags: ['SWEEP'],
      score: 85,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OptionFlowListItem(
            item: item,
          ),
        ),
      ),
    );

    final itemFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          widget.properties.label != null &&
          widget.properties.label!.startsWith('Option flow for ${item.symbol}'),
    );

    expect(itemFinder, findsOneWidget);

    final semantics = tester.getSemantics(itemFinder).getSemanticsData();
    expect(semantics.flagsCollection.isButton, isTrue);

    semanticsHandle.dispose();
  });
}

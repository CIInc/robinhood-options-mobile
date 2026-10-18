import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/widgets/chart_bar_widget.dart';

void main() {
  testWidgets(
      'clears opted-in chart selection so the same bar can be selected again',
      (WidgetTester tester) async {
    const datum = {'domain': 'EUR/USD', 'measure': 12};
    final selections = <dynamic>[];
    final series = charts.Series<Map<String, Object>, String>(
      id: 'positions',
      data: const [datum],
      domainFn: (item, _) => item['domain']! as String,
      measureFn: (item, _) => item['measure']! as int,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 240,
              child: BarChart(
                [series],
                animate: false,
                clearSelectionAfterSelect: true,
                onSelected: selections.add,
              ),
            ),
          ),
        ),
      ),
    );

    final chartCenter = tester.getCenter(find.byType(BarChart));
    await tester.tapAt(chartCenter);
    await tester.pumpAndSettle();
    await tester.tapAt(chartCenter);
    await tester.pumpAndSettle();

    expect(selections.where((selection) => selection == datum), hasLength(2));
    expect(selections.where((selection) => selection == null), hasLength(2));
  });
}

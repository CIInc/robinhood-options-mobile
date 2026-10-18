import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/equity_historical.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_selection_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/widgets/chart_time_series_widget.dart';
import 'package:robinhood_options_mobile/widgets/home/portfolio_chart_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('hiding balances masks portfolio historical chart values',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final accountStore = AccountStore();
    final historicalsStore = PortfolioHistoricalsStore()
      ..set(_buildHistoricals());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: accountStore),
          ChangeNotifierProvider.value(value: historicalsStore),
          ChangeNotifierProvider(
            create: (_) => PortfolioHistoricalsSelectionStore(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PortfolioChartWidget(
              brokerageUser:
                  BrokerageUser(BrokerageSource.demo, 'demo', null, null),
              chartDateSpanFilter: ChartDateSpan.day,
              chartBoundsFilter: Bounds.regular,
              onFilterChanged: (_, __) {},
              isFullScreen: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    var chart = tester.widget<TimeSeriesChart>(find.byType(TimeSeriesChart));
    expect(chart.open, 1000);
    expect(chart.close, 1100);
    expect(chart.showRangeAnnotationValues, isTrue);
    expect(chart.hidePrimaryMeasureAxisValues, isFalse);
    expect(chart.key, const ValueKey('portfolio-history-true'));
    expect(chart.primaryMeasureAxis, isNull);
    expect(find.byIcon(Icons.candlestick_chart), findsOneWidget);

    accountStore.toggleShowBalances();
    await tester.pump();

    chart = tester.widget<TimeSeriesChart>(find.byType(TimeSeriesChart));
    expect(chart.open, 1000);
    expect(chart.close, 1100);
    expect(chart.showRangeAnnotationValues, isFalse);
    expect(chart.hidePrimaryMeasureAxisValues, isTrue);
    expect(chart.key, const ValueKey('portfolio-history-false'));
    expect(chart.primaryMeasureAxis, isNull);
    expect(find.text('\$••••••'), findsOneWidget);
    expect(find.byIcon(Icons.candlestick_chart), findsNothing);
  });
}

PortfolioHistoricals _buildHistoricals() {
  final start = DateTime(2026, 8, 12, 9, 30);
  return PortfolioHistoricals(
    1000,
    1000,
    1000,
    1000,
    null,
    '5minute',
    'day',
    'regular',
    100,
    [
      EquityHistorical(1000, 1000, 1000, 1000, 1000, 1000, start, 0, 'reg'),
      EquityHistorical(1100, 1100, 1100, 1100, 1100, 1100,
          start.add(const Duration(hours: 1)), 100, 'reg'),
    ],
    false,
  );
}

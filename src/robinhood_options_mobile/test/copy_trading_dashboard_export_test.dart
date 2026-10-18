import 'dart:convert';

import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/copy_trade_record.dart';
import 'package:robinhood_options_mobile/model/copy_trading_provider.dart';
import 'package:robinhood_options_mobile/widgets/copy_trading_dashboard_widget.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

void main() {
  late SharePlatform originalSharePlatform;
  late _FakeSharePlatform fakeSharePlatform;

  setUp(() {
    originalSharePlatform = SharePlatform.instance;
    fakeSharePlatform = _FakeSharePlatform();
    SharePlatform.instance = fakeSharePlatform;
  });

  tearDown(() {
    SharePlatform.instance = originalSharePlatform;
  });

  testWidgets('exports trade history and realized performance as a CSV file',
      (tester) async {
    final entryTime = DateTime(2026, 9, 1, 10);
    final exitTime = DateTime(2026, 9, 2, 10);
    final provider = _FakeCopyTradingProvider([
      _trade(id: 'entry', side: 'buy', price: 100, timestamp: entryTime),
      _trade(id: 'exit', side: 'sell', price: 102, timestamp: exitTime),
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<CopyTradingProvider>.value(
        value: provider,
        child: const MaterialApp(home: CopyTradingDashboardWidget()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Export CSV'));
    await tester.pumpAndSettle();

    final params = fakeSharePlatform.lastParams!;
    expect(params.text, isNull);
    expect(params.files, hasLength(1));
    expect(params.files!.single.mimeType, 'text/csv');
    expect(params.fileNameOverrides, ['copy-trade-history.csv']);

    final rows = Csv().decode(
      utf8.decode(await params.files!.single.readAsBytes()),
    );
    expect(rows.first, containsAll(['Symbol', 'P&L', 'Return %']));

    final closingTrade = rows.firstWhere(
      (row) => row[1] == 'AAPL' && row[2] == 'sell',
    );
    expect(closingTrade[13], '20.00');
    expect(closingTrade[14], '2.00%');
  });

  testWidgets('plots cumulative realized P&L in exit-date order',
      (tester) async {
    final firstEntry = DateTime(2026, 9, 1, 10);
    final firstExit = DateTime(2026, 9, 2, 10);
    final secondEntry = DateTime(2026, 9, 3, 10);
    final secondExit = DateTime(2026, 9, 4, 10);
    final provider = _FakeCopyTradingProvider([
      _trade(id: 'second-exit', side: 'sell', price: 99, timestamp: secondExit),
      _trade(
          id: 'second-entry', side: 'buy', price: 100, timestamp: secondEntry),
      _trade(id: 'first-exit', side: 'sell', price: 102, timestamp: firstExit),
      _trade(id: 'first-entry', side: 'buy', price: 100, timestamp: firstEntry),
    ]);

    await tester.pumpWidget(
      ChangeNotifierProvider<CopyTradingProvider>.value(
        value: provider,
        child: const MaterialApp(home: CopyTradingDashboardWidget()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cumulative P&L'), findsOneWidget);
    final chart = tester.widget<charts.TimeSeriesChart>(
      find.byType(charts.TimeSeriesChart),
    );
    final series = chart.seriesList.single;

    expect(
      List.generate(series.data.length, (index) => series.domainFn(index)),
      [firstExit, secondExit],
    );
    expect(
      List.generate(series.data.length, (index) => series.measureFn(index)),
      [20, 10],
    );
  });
}

CopyTradeRecord _trade({
  required String id,
  required String side,
  required double price,
  required DateTime timestamp,
}) {
  return CopyTradeRecord(
    id: id,
    sourceUserId: 'leader-123',
    targetUserId: 'follower-123',
    groupId: 'group-123',
    orderType: 'instrument',
    originalOrderId: 'order-$id',
    symbol: 'AAPL',
    side: side,
    originalQuantity: 10,
    copiedQuantity: 10,
    price: price,
    timestamp: timestamp,
    executed: true,
  );
}

class _FakeCopyTradingProvider extends CopyTradingProvider {
  _FakeCopyTradingProvider(this.trades);

  final List<CopyTradeRecord> trades;

  @override
  Stream<List<CopyTradeRecord>> getTradeHistory() => Stream.value(trades);
}

class _FakeSharePlatform extends SharePlatform {
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    return ShareResult.unavailable;
  }
}

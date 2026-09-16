import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/services/paper_service.dart';

void main() {
  group('PaperService chart data parameters', () {
    final cases =
        <ChartDateSpan, ({String range, String interval, String appInterval})>{
      ChartDateSpan.day: (range: '1d', interval: '5m', appInterval: '5minute'),
      ChartDateSpan.week: (range: '5d', interval: '5m', appInterval: '5minute'),
      ChartDateSpan.month: (
        range: '1mo',
        interval: '5m',
        appInterval: '5minute'
      ),
      ChartDateSpan.month_3: (range: '3mo', interval: '1d', appInterval: 'day'),
      ChartDateSpan.year: (range: '1y', interval: '1d', appInterval: 'day'),
      ChartDateSpan.year_5: (range: '5y', interval: '1wk', appInterval: 'week'),
    };

    for (final entry in cases.entries) {
      test('${entry.key.name} uses a supported Yahoo range and interval', () {
        expect(
          PaperService.chartDataParameters(entry.key),
          entry.value,
        );
      });
    }

    test('an explicit chart interval still overrides the span default', () {
      expect(
        PaperService.chartDataParameters(
          ChartDateSpan.month,
          chartInterval: 'day',
        ),
        (range: '1mo', interval: '1d', appInterval: 'day'),
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/utils/income_chart_viewport.dart';

void main() {
  group('shouldUseAutomaticIncomeChartViewport', () {
    test('uses all plotted income dates for the one-year range decision', () {
      final shouldUseAutomaticViewport = shouldUseAutomaticIncomeChartViewport(
        dateFilter: 'Year',
        incomeDates: [
          DateTime(2023, 1, 1), // Older interest transaction.
          DateTime(2025, 10, 1), // Recent dividend transaction.
          DateTime(2026, 3, 1),
        ],
      );

      expect(shouldUseAutomaticViewport, isFalse);
    });

    test('keeps automatic viewport for data contained within one year', () {
      expect(
        shouldUseAutomaticIncomeChartViewport(
          dateFilter: 'Year',
          incomeDates: [DateTime(2025, 10, 1), DateTime(2026, 3, 1)],
        ),
        isTrue,
      );
    });

    test('keeps automatic viewport for the all-time range', () {
      expect(
        shouldUseAutomaticIncomeChartViewport(
          dateFilter: 'All',
          incomeDates: [DateTime(2023, 1, 1), DateTime(2026, 3, 1)],
        ),
        isTrue,
      );
    });
  });
}

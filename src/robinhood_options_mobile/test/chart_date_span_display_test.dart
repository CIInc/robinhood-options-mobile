import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';

void main() {
  test('chart spans expose the labels shown in portfolio value changes', () {
    expect(
      ChartDateSpan.values.map((span) => span.label),
      ['1H', '1D', '1W', '1M', '3M', 'YTD', '1Y', '2Y', '3Y', '5Y', 'All'],
    );
  });
}

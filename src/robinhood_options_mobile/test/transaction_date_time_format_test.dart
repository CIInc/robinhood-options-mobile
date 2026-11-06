import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/constants.dart';

void main() {
  test('formatLocalDateTime includes the local time', () {
    final dateTime = DateTime(2026, 11, 5, 14, 30);

    final formattedDateTime = formatLocalDateTime(dateTime);
    expect(formattedDateTime, contains('2:30'));
    expect(formattedDateTime, contains('PM'));
  });
}

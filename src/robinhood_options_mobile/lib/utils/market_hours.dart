import 'package:flutter/material.dart';

/// Utility functions for US market hours checking (Eastern Time)
class MarketHours {
  /// Checks if the market is currently open (9:30 AM - 4:00 PM ET, Monday-Friday)
  static bool isMarketOpen() {
    final now = DateTime.now().toUtc();

    // Determine if we're in EDT (summer) or EST (winter)
    // DST in US: Second Sunday in March to First Sunday in November
    final year = now.year;
    final isDST = _isDaylightSavingTime(now, year);
    final offset = isDST ? 4 : 5; // EDT is UTC-4, EST is UTC-5

    final etTime = now.subtract(Duration(hours: offset));

    debugPrint('🕐 Market hours check:');
    debugPrint('   UTC time: $now');
    debugPrint('   DST active: $isDST (offset: -$offset hours)');
    debugPrint('   ET time: $etTime');
    debugPrint('   Day of week: ${etTime.weekday} (${[
      '',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun'
    ][etTime.weekday]})');

    // Market is closed on weekends
    if (etTime.weekday == DateTime.saturday ||
        etTime.weekday == DateTime.sunday) {
      debugPrint('   ❌ Weekend - market closed');
      return false;
    }

    // Market hours: 9:30 AM - 4:00 PM ET
    // Create times in UTC to match etTime (which is also UTC)
    final marketOpen =
        DateTime.utc(etTime.year, etTime.month, etTime.day, 9, 30);
    final marketClose =
        DateTime.utc(etTime.year, etTime.month, etTime.day, 16, 0);

    final isOpen = etTime.isAfter(marketOpen) && etTime.isBefore(marketClose);
    debugPrint('   Market open: $marketOpen');
    debugPrint('   Market close: $marketClose');
    debugPrint(
        '   Current ET: ${etTime.hour}:${etTime.minute.toString().padLeft(2, '0')}');
    debugPrint(
        '   isAfter(open)=${etTime.isAfter(marketOpen)}, isBefore(close)=${etTime.isBefore(marketClose)}');
    debugPrint('   ${isOpen ? "✅ MARKET OPEN" : "❌ MARKET CLOSED"}');

    return isOpen;
  }

  /// Helper to determine if a given UTC time falls within Daylight Saving Time
  static bool _isDaylightSavingTime(DateTime utcTime, int year) {
    // DST starts: Second Sunday in March at 2:00 AM local time (7:00 AM UTC during EST)
    // DST ends: First Sunday in November at 2:00 AM local time (6:00 AM UTC during EDT)

    // Find second Sunday in March
    DateTime marchFirst = DateTime.utc(year, 3, 1);
    // Calculate days to first Sunday
    int daysToFirstSunday = (DateTime.sunday - marchFirst.weekday) % 7;
    // Second Sunday is 7 days after first Sunday
    DateTime secondSundayMarch =
        DateTime.utc(year, 3, 1 + daysToFirstSunday + 7, 7); // 7 AM UTC

    // Find first Sunday in November
    DateTime novemberFirst = DateTime.utc(year, 11, 1);
    int daysToFirstSundayNov = (DateTime.sunday - novemberFirst.weekday) % 7;
    DateTime firstSundayNovember =
        DateTime.utc(year, 11, 1 + daysToFirstSundayNov, 6); // 6 AM UTC

    debugPrint('   DST period: $secondSundayMarch to $firstSundayNovember');
    debugPrint('   Current UTC: $utcTime');

    return utcTime.isAfter(secondSundayMarch) &&
        utcTime.isBefore(firstSundayNovember);
  }
}

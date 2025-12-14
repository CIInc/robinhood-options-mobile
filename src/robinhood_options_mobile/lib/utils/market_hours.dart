import 'package:flutter/material.dart';

/// Trading session types
enum TradingSession {
  preMarket, // 4:00 AM - 9:30 AM ET
  regular, // 9:30 AM - 4:00 PM ET
  afterHours, // 4:00 PM - 8:00 PM ET
  closed, // Market closed
}

/// Utility functions for US market hours checking (Eastern Time)
class MarketHours {
  /// Checks if the market is currently open (9:30 AM - 4:00 PM ET, Monday-Friday)
  /// Optionally includes extended hours (pre-market and after-hours)
  static bool isMarketOpen({bool includeExtendedHours = false}) {
    final session = getCurrentTradingSession();

    if (includeExtendedHours) {
      return session != TradingSession.closed;
    } else {
      return session == TradingSession.regular;
    }
  }

  /// Gets the current trading session
  static TradingSession getCurrentTradingSession() {
    final now = DateTime.now().toUtc();

    // Determine if we're in EDT (summer) or EST (winter)
    // DST in US: Second Sunday in March to First Sunday in November
    final year = now.year;
    final isDST = _isDaylightSavingTime(now, year);
    final offset = isDST ? 4 : 5; // EDT is UTC-4, EST is UTC-5

    final etTime = now.subtract(Duration(hours: offset));

    debugPrint('🕐 Trading session check:');
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
      return TradingSession.closed;
    }

    final currentTimeInMinutes = etTime.hour * 60 + etTime.minute;

    // Pre-market: 4:00 AM - 9:30 AM ET
    final preMarketOpen = 4 * 60; // 240 minutes
    final preMarketClose = 9 * 60 + 30; // 570 minutes

    // Regular market: 9:30 AM - 4:00 PM ET
    final regularOpen = 9 * 60 + 30; // 570 minutes
    final regularClose = 16 * 60; // 960 minutes

    // After-hours: 4:00 PM - 8:00 PM ET
    final afterHoursOpen = 16 * 60; // 960 minutes
    final afterHoursClose = 20 * 60; // 1200 minutes

    debugPrint(
        '   Current ET: ${etTime.hour}:${etTime.minute.toString().padLeft(2, '0')}');
    debugPrint('   Current minutes: $currentTimeInMinutes');

    if (currentTimeInMinutes >= preMarketOpen &&
        currentTimeInMinutes < preMarketClose) {
      debugPrint('   📈 PRE-MARKET SESSION');
      return TradingSession.preMarket;
    } else if (currentTimeInMinutes >= regularOpen &&
        currentTimeInMinutes < regularClose) {
      debugPrint('   ✅ REGULAR MARKET SESSION');
      return TradingSession.regular;
    } else if (currentTimeInMinutes >= afterHoursOpen &&
        currentTimeInMinutes < afterHoursClose) {
      debugPrint('   📉 AFTER-HOURS SESSION');
      return TradingSession.afterHours;
    } else {
      debugPrint('   ❌ MARKET CLOSED');
      return TradingSession.closed;
    }
  }

  /// Gets a human-readable description of the current trading session
  static String getSessionDescription() {
    final session = getCurrentTradingSession();
    switch (session) {
      case TradingSession.preMarket:
        return 'Pre-Market (4:00 AM - 9:30 AM ET)';
      case TradingSession.regular:
        return 'Regular Market (9:30 AM - 4:00 PM ET)';
      case TradingSession.afterHours:
        return 'After-Hours (4:00 PM - 8:00 PM ET)';
      case TradingSession.closed:
        return 'Market Closed';
    }
  }

  /// Gets the next market open time
  /// If includeExtendedHours is true, returns next extended hours session
  static DateTime getNextMarketOpen({bool includeExtendedHours = false}) {
    final now = DateTime.now();
    var checkTime = now.add(const Duration(minutes: 1));

    // Check up to 5 days ahead
    for (int i = 0; i < 5; i++) {
      final session = _getTradingSessionForTime(checkTime,
          includeExtendedHours: includeExtendedHours);
      if (session != TradingSession.closed) {
        return checkTime;
      }
      checkTime = checkTime.add(const Duration(days: 1));
    }

    // Fallback to tomorrow's open
    return _getNextSessionStartTime(checkTime, includeExtendedHours);
  }

  /// Internal helper to check trading session for a specific time
  static TradingSession _getTradingSessionForTime(DateTime checkTime,
      {bool includeExtendedHours = false}) {
    final year = checkTime.year;
    final isDST = _isDaylightSavingTime(checkTime, year);
    final offset = isDST ? 4 : 5;
    final etTime = checkTime.subtract(Duration(hours: offset));

    if (etTime.weekday == DateTime.saturday ||
        etTime.weekday == DateTime.sunday) {
      return TradingSession.closed;
    }

    final currentTimeInMinutes = etTime.hour * 60 + etTime.minute;
    const preMarketOpen = 240; // 4:00 AM
    const preMarketClose = 570; // 9:30 AM
    const regularOpen = 570; // 9:30 AM
    const regularClose = 960; // 4:00 PM
    const afterHoursOpen = 960; // 4:00 PM
    const afterHoursClose = 1200; // 8:00 PM

    if (currentTimeInMinutes >= preMarketOpen &&
        currentTimeInMinutes < preMarketClose) {
      return TradingSession.preMarket;
    } else if (currentTimeInMinutes >= regularOpen &&
        currentTimeInMinutes < regularClose) {
      return TradingSession.regular;
    } else if (currentTimeInMinutes >= afterHoursOpen &&
        currentTimeInMinutes < afterHoursClose) {
      return TradingSession.afterHours;
    } else {
      return TradingSession.closed;
    }
  }

  /// Helper to get the start time of the next trading session
  static DateTime _getNextSessionStartTime(
      DateTime fromTime, bool includeExtendedHours) {
    final year = fromTime.year;
    final isDST = _isDaylightSavingTime(fromTime, year);
    final offset = isDST ? 4 : 5;
    final etTime = fromTime.subtract(Duration(hours: offset));
    final currentTimeInMinutes = etTime.hour * 60 + etTime.minute;

    DateTime nextOpen;

    if (includeExtendedHours) {
      // Check if it's before pre-market
      if (currentTimeInMinutes < 240) {
        // Return today's pre-market open
        nextOpen = DateTime(etTime.year, etTime.month, etTime.day, 4, 0);
      } else if (currentTimeInMinutes < 570) {
        // In pre-market, return regular open
        nextOpen = DateTime(etTime.year, etTime.month, etTime.day, 9, 30);
      } else if (currentTimeInMinutes < 960) {
        // In regular hours, return after-hours open
        nextOpen = DateTime(etTime.year, etTime.month, etTime.day, 16, 0);
      } else if (currentTimeInMinutes < 1200) {
        // In after-hours, return tomorrow's pre-market
        nextOpen = DateTime(etTime.year, etTime.month, etTime.day + 1, 4, 0);
      } else {
        // After after-hours, return tomorrow's pre-market
        nextOpen = DateTime(etTime.year, etTime.month, etTime.day + 1, 4, 0);
      }
    } else {
      // Regular hours only
      if (currentTimeInMinutes < 570) {
        // Return today's regular open
        nextOpen = DateTime(etTime.year, etTime.month, etTime.day, 9, 30);
      } else {
        // Return tomorrow's regular open
        nextOpen = DateTime(etTime.year, etTime.month, etTime.day + 1, 9, 30);
      }
    }

    // Convert back from ET to UTC
    return nextOpen.add(Duration(hours: offset));
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

/// Trading session types
enum TradingSession {
  preMarket, // 4:00 AM - 9:30 AM ET
  regular, // 9:30 AM - 4:00 PM ET
  afterHours, // Regular close - 8:00 PM ET
  closed, // Market closed
}

/// Utility functions for US market hours checking (Eastern Time)
class MarketHours {
  /// Test-only override for current time
  static DateTime? testTime;

  static bool isMarketHoliday(DateTime easternDate) {
    final year = easternDate.year;
    final date = DateTime.utc(year, easternDate.month, easternDate.day);
    final holidays = <DateTime>{
      _observedHoliday(year, 1, 1),
      _nthWeekdayOfMonth(year, 1, DateTime.monday, 3),
      _nthWeekdayOfMonth(year, 2, DateTime.monday, 3),
      _easterSunday(year).subtract(const Duration(days: 2)),
      _lastWeekdayOfMonth(year, 5, DateTime.monday),
      _observedHoliday(year, 7, 4),
      _nthWeekdayOfMonth(year, 9, DateTime.monday, 1),
      _nthWeekdayOfMonth(year, 11, DateTime.thursday, 4),
      _observedHoliday(year, 12, 25),
    };
    if (year >= 2022) {
      holidays.add(_observedHoliday(year, 6, 19));
    }
    final nextNewYear = _observedHoliday(year + 1, 1, 1);
    if (nextNewYear.year == year) holidays.add(nextNewYear);
    return holidays.contains(date);
  }

  static DateTime _observedHoliday(int year, int month, int day) {
    final date = DateTime.utc(year, month, day);
    if (date.weekday == DateTime.saturday) {
      return date.subtract(const Duration(days: 1));
    }
    if (date.weekday == DateTime.sunday) {
      return date.add(const Duration(days: 1));
    }
    return date;
  }

  static DateTime _nthWeekdayOfMonth(
    int year,
    int month,
    int weekday,
    int occurrence,
  ) {
    final first = DateTime.utc(year, month, 1);
    final daysUntilWeekday = (weekday - first.weekday + 7) % 7;
    return first.add(Duration(days: daysUntilWeekday + (occurrence - 1) * 7));
  }

  static DateTime _lastWeekdayOfMonth(int year, int month, int weekday) {
    final last = DateTime.utc(year, month + 1, 0);
    final daysSinceWeekday = (last.weekday - weekday + 7) % 7;
    return last.subtract(Duration(days: daysSinceWeekday));
  }

  static DateTime _easterSunday(int year) {
    final a = year % 19;
    final b = year ~/ 100;
    final c = year % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final easterMonth = (h + l - 7 * m + 114) ~/ 31;
    final easterDay = (h + l - 7 * m + 114) % 31 + 1;
    return DateTime.utc(year, easterMonth, easterDay);
  }

  static bool _isTradingDate(DateTime date) =>
      date.weekday != DateTime.saturday &&
      date.weekday != DateTime.sunday &&
      !isMarketHoliday(date);

  static int _regularCloseMinutes(DateTime date) =>
      _isEarlyClose(date) ? 13 * 60 : 16 * 60;

  static bool _isEarlyClose(DateTime date) {
    if (!_isTradingDate(date)) return false;
    final thanksgiving =
        _nthWeekdayOfMonth(date.year, 11, DateTime.thursday, 4);
    final dayAfterThanksgiving = thanksgiving.add(const Duration(days: 1));
    return date == dayAfterThanksgiving ||
        (date.month == 12 && date.day == 24) ||
        (date.month == 7 && date.day == 3);
  }

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

  static bool isTradingSessionAllowed({
    required bool allowPreMarket,
    required bool allowAfterHours,
  }) {
    return switch (getCurrentTradingSession()) {
      TradingSession.regular => true,
      TradingSession.preMarket => allowPreMarket,
      TradingSession.afterHours => allowAfterHours,
      TradingSession.closed => false,
    };
  }

  /// Converts an instant to Eastern wall-clock components using the US DST
  /// rules already used by the market-session helpers.
  static DateTime easternWallTime(DateTime instant) {
    final utc = instant.toUtc();
    final offset = _isDaylightSavingTime(utc, utc.year) ? 4 : 5;
    return utc.subtract(Duration(hours: offset));
  }

  /// Returns the most recent trading date whose regular session has ended.
  static DateTime mostRecentCompletedTradingDate(DateTime instant) {
    final eastern = easternWallTime(instant);
    final date = DateTime.utc(eastern.year, eastern.month, eastern.day);
    final minutes = eastern.hour * 60 + eastern.minute;
    if (_isTradingDate(date) && minutes >= _regularCloseMinutes(date)) {
      return date;
    }
    return previousTradingDate(date);
  }

  /// Returns the prior weekday before an Eastern calendar date.
  static DateTime previousTradingDate(DateTime easternDate) {
    var date = DateTime.utc(
      easternDate.year,
      easternDate.month,
      easternDate.day,
    );
    do {
      date = DateTime.utc(date.year, date.month, date.day - 1);
    } while (!_isTradingDate(date));
    return date;
  }

  /// Returns the UTC instant of a configured pre-close exit deadline.
  static DateTime marketCloseDeadlineUtc(
    DateTime tradingDate,
    int exitMinutes,
  ) {
    final year = tradingDate.year;
    final month = tradingDate.month;
    final day = tradingDate.day;
    final dstProbe = DateTime.utc(year, month, day, 18);
    final offset = _isDaylightSavingTime(dstProbe, year) ? 4 : 5;
    final closeMinutes = _regularCloseMinutes(tradingDate);
    return DateTime.utc(year, month, day, closeMinutes ~/ 60 + offset)
        .subtract(Duration(minutes: exitMinutes));
  }

  /// Formats an instant as YYYY-MM-DD in Eastern Time.
  static String easternDateKey(DateTime instant) {
    final eastern = easternWallTime(instant);
    return calendarDateKey(eastern);
  }

  /// Formats an Eastern calendar date represented by its wall-clock fields.
  static String calendarDateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// Gets the current trading session
  static TradingSession getCurrentTradingSession() {
    final now = (testTime ?? DateTime.now()).toUtc();

    // Determine if we're in EDT (summer) or EST (winter)
    // DST in US: Second Sunday in March to First Sunday in November
    final year = now.year;
    final isDST = _isDaylightSavingTime(now, year);
    final offset = isDST ? 4 : 5; // EDT is UTC-4, EST is UTC-5

    final etTime = now.subtract(Duration(hours: offset));

    // debugPrint('🕐 Trading session check:');
    // debugPrint('   UTC time: $now');
    // debugPrint('   DST active: $isDST (offset: -$offset hours)');
    // debugPrint('   ET time: $etTime');
    // debugPrint('   Day of week: ${etTime.weekday} (${[
    //   '',
    //   'Mon',
    //   'Tue',
    //   'Wed',
    //   'Thu',
    //   'Fri',
    //   'Sat',
    //   'Sun'
    // ][etTime.weekday]})');

    final easternDate = DateTime.utc(etTime.year, etTime.month, etTime.day);
    if (!_isTradingDate(easternDate)) {
      return TradingSession.closed;
    }

    final currentTimeInMinutes = etTime.hour * 60 + etTime.minute;

    // Pre-market: 4:00 AM - 9:30 AM ET
    final preMarketOpen = 4 * 60; // 240 minutes
    final preMarketClose = 9 * 60 + 30; // 570 minutes

    // Regular market: 9:30 AM - 4:00 PM ET
    final regularOpen = 9 * 60 + 30; // 570 minutes
    final regularClose = _regularCloseMinutes(easternDate);

    // After-hours begins at the regular close, including early-close days.
    final afterHoursOpen = regularClose;
    final afterHoursClose = 20 * 60; // 1200 minutes

    // debugPrint(
    //     '   Current ET: ${etTime.hour}:${etTime.minute.toString().padLeft(2, '0')}');
    // debugPrint('   Current minutes: $currentTimeInMinutes');

    if (currentTimeInMinutes >= preMarketOpen &&
        currentTimeInMinutes < preMarketClose) {
      // debugPrint('   📈 PRE-MARKET SESSION');
      return TradingSession.preMarket;
    } else if (currentTimeInMinutes >= regularOpen &&
        currentTimeInMinutes < regularClose) {
      // debugPrint('   ✅ REGULAR MARKET SESSION');
      return TradingSession.regular;
    } else if (currentTimeInMinutes >= afterHoursOpen &&
        currentTimeInMinutes < afterHoursClose) {
      // debugPrint('   📉 AFTER-HOURS SESSION');
      return TradingSession.afterHours;
    } else {
      // debugPrint('   ❌ MARKET CLOSED');
      return TradingSession.closed;
    }
  }

  /// Returns the number of minutes until the regular market closes (4:00 PM ET).
  /// Returns null if the market is not in the regular session.
  static int? minutesUntilMarketClose() {
    final now = (testTime ?? DateTime.now()).toUtc();
    final year = now.year;
    final isDST = _isDaylightSavingTime(now, year);
    final offset = isDST ? 4 : 5;
    final etTime = now.subtract(Duration(hours: offset));

    final easternDate = DateTime.utc(etTime.year, etTime.month, etTime.day);
    if (!_isTradingDate(easternDate)) return null;

    final currentTimeInMinutes = etTime.hour * 60 + etTime.minute;
    final regularOpen = 9 * 60 + 30; // 570 minutes
    final regularClose = _regularCloseMinutes(easternDate);

    if (currentTimeInMinutes >= regularOpen &&
        currentTimeInMinutes < regularClose) {
      return regularClose - currentTimeInMinutes;
    }

    return null;
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
        return 'After-Hours (regular close - 8:00 PM ET)';
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

    final easternDate = DateTime.utc(etTime.year, etTime.month, etTime.day);
    if (!_isTradingDate(easternDate)) return TradingSession.closed;

    final currentTimeInMinutes = etTime.hour * 60 + etTime.minute;
    const preMarketOpen = 240; // 4:00 AM
    const preMarketClose = 570; // 9:30 AM
    const regularOpen = 570; // 9:30 AM
    final regularClose = _regularCloseMinutes(easternDate);
    final afterHoursOpen = regularClose;
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

    // debugPrint('   DST period: $secondSundayMarch to $firstSundayNovember');
    // debugPrint('   Current UTC: $utcTime');

    return utcTime.isAfter(secondSundayMarch) &&
        utcTime.isBefore(firstSundayNovember);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/earnings_calendar_event.dart';
import 'package:robinhood_options_mobile/model/earnings_iv_crush_model.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';

InstrumentPosition buildStockPosition({
  required String symbol,
  required double quantity,
  List<dynamic>? earningsObj,
}) {
  final pos = InstrumentPosition(
    'https://example.com/positions/$symbol/',
    'https://example.com/instruments/$symbol/',
    'https://example.com/accounts/1AB23456/',
    '1AB23456',
    100.0,
    0,
    quantity,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    false,
    DateTime(2026, 1, 1),
    DateTime(2025, 1, 1),
  );

  pos.instrumentObj = Instrument(
    id: symbol,
    url: 'https://example.com/instruments/$symbol/',
    quote: '',
    fundamentals: '',
    splits: '',
    state: 'active',
    market: '',
    name: symbol,
    tradeable: true,
    tradability: 'tradable',
    symbol: symbol,
    bloombergUnique: '',
    country: 'US',
    type: 'stock',
    rhsTradability: 'tradable',
    fractionalTradability: 'tradable',
    isSpac: false,
    isTest: false,
    ipoAccessSupportsDsp: false,
    dateCreated: DateTime(2025, 1, 1),
    earningsObj: earningsObj,
  );

  return pos;
}

OptionAggregatePosition buildOptionPosition({
  required String symbol,
  required double quantity,
  List<dynamic>? earningsObj,
}) {
  final pos = OptionAggregatePosition(
    'pos_$symbol',
    'chain_$symbol',
    '1AB23456',
    symbol,
    'long_call',
    2.50,
    const [],
    quantity,
    null,
    null,
    'debit',
    'debit',
    100.0,
    DateTime(2026, 1, 1),
    DateTime(2026, 1, 1),
    'long_call',
  );

  pos.instrumentObj = Instrument(
    id: symbol,
    url: 'https://example.com/instruments/$symbol/',
    quote: '',
    fundamentals: '',
    splits: '',
    state: 'active',
    market: '',
    name: symbol,
    tradeable: true,
    tradability: 'tradable',
    symbol: symbol,
    bloombergUnique: '',
    country: 'US',
    type: 'stock',
    rhsTradability: 'tradable',
    fractionalTradability: 'tradable',
    isSpac: false,
    isTest: false,
    ipoAccessSupportsDsp: false,
    dateCreated: DateTime(2025, 1, 1),
    earningsObj: earningsObj,
  );

  return pos;
}

void main() {
  final fixedNow = DateTime(2026, 9, 24, 10, 0, 0);

  group('EarningsCalendarEvent Model', () {
    test('calculates daysUntil correctly', () {
      final eventToday = EarningsCalendarEvent(
        symbol: 'AAPL',
        date: DateTime(2026, 9, 24, 16, 30),
      );
      expect(eventToday.daysUntil(fixedNow), equals(0));

      final eventTomorrow = EarningsCalendarEvent(
        symbol: 'MSFT',
        date: DateTime(2026, 9, 25, 9, 0),
      );
      expect(eventTomorrow.daysUntil(fixedNow), equals(1));

      final eventFuture = EarningsCalendarEvent(
        symbol: 'NVDA',
        date: DateTime(2026, 9, 29),
      );
      expect(eventFuture.daysUntil(fixedNow), equals(5));

      final eventPast = EarningsCalendarEvent(
        symbol: 'TSLA',
        date: DateTime(2026, 9, 20),
      );
      expect(eventPast.daysUntil(fixedNow), equals(-4));
    });

    test('formats timing display and tags', () {
      final am = EarningsCalendarEvent(
        symbol: 'AAPL',
        date: DateTime(2026, 9, 24),
        timing: 'am',
      );
      expect(am.timingDisplay, equals('Before Open'));
      expect(am.timingTag, equals('BMO'));

      final pm = EarningsCalendarEvent(
        symbol: 'GOOG',
        date: DateTime(2026, 9, 24),
        timing: 'pm',
      );
      expect(pm.timingDisplay, equals('After Close'));
      expect(pm.timingTag, equals('AMC'));

      final untimed = EarningsCalendarEvent(
        symbol: 'AMZN',
        date: DateTime(2026, 9, 24),
      );
      expect(untimed.timingDisplay, isEmpty);
      expect(untimed.timingTag, isEmpty);
    });

    test('parses from Robinhood earnings json format', () {
      final json = {
        'symbol': 'META',
        'year': 2026,
        'quarter': 3,
        'eps': {'estimate': '4.85', 'actual': null},
        'report': {'date': '2026-09-25', 'timing': 'pm', 'verified': true},
        'call': {'datetime': '2026-09-25T21:00:00Z'},
      };

      final event = EarningsCalendarEvent.fromRobinhoodJson(
        json,
        sharesHeld: 150.0,
      );

      expect(event.symbol, equals('META'));
      expect(event.year, equals(2026));
      expect(event.quarter, equals(3));
      expect(event.epsEstimate, equals(4.85));
      expect(event.epsActual, isNull);
      expect(event.timing, equals('pm'));
      expect(event.verified, isTrue);
      expect(event.sharesHeld, equals(150.0));
      expect(event.formattedEstimate, equals('\$4.85'));
    });

    test('serialization roundtrip toJson and fromJson', () {
      final original = EarningsCalendarEvent(
        symbol: 'NVDA',
        date: DateTime(2026, 9, 28),
        timing: 'am',
        year: 2026,
        quarter: 3,
        epsEstimate: 1.25,
        epsActual: null,
        verified: true,
        sharesHeld: 50.0,
        contractsHeld: 2,
      );

      final json = original.toJson();
      final revived = EarningsCalendarEvent.fromJson(json);

      expect(revived.symbol, equals(original.symbol));
      expect(revived.date, equals(original.date));
      expect(revived.timing, equals(original.timing));
      expect(revived.year, equals(original.year));
      expect(revived.quarter, equals(original.quarter));
      expect(revived.epsEstimate, equals(original.epsEstimate));
      expect(revived.sharesHeld, equals(original.sharesHeld));
      expect(revived.contractsHeld, equals(original.contractsHeld));
    });
  });

  group('PortfolioAlertService Earnings Calendar Alerts', () {
    test(
        'raises critical alert for 0 DTE earnings today with timing and consensus',
        () {
      final aapl = buildStockPosition(
        symbol: 'AAPL',
        quantity: 100,
        earningsObj: [
          {
            'symbol': 'AAPL',
            'year': 2026,
            'quarter': 3,
            'eps': {'estimate': '1.60'},
            'report': {'date': '2026-09-24', 'timing': 'pm', 'verified': true},
          }
        ],
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [aapl],
        optionPositions: const [],
        now: fixedNow,
      );

      final earningsAlerts =
          alerts.where((a) => a.id.startsWith('earnings-')).toList();
      expect(earningsAlerts.length, equals(1));

      final alert = earningsAlerts.first;
      expect(alert.id, equals('earnings-today-AAPL'));
      expect(alert.severity, equals(PortfolioAlertSeverity.critical));
      expect(
          alert.title, contains('AAPL Reports Earnings Today (After Close)'));
      expect(alert.detail, contains('You hold 100 shares'));
      expect(alert.detail, contains('Consensus EPS: \$1.60'));
      expect(alert.metric, equals('Today'));
      expect(alert.target, equals(PortfolioAlertTarget.earningsIvCrush));
    });

    test('raises warning alert for 1 DTE earnings tomorrow', () {
      final msft = buildStockPosition(
        symbol: 'MSFT',
        quantity: 50,
        earningsObj: [
          {
            'symbol': 'MSFT',
            'year': 2026,
            'quarter': 3,
            'eps': {'estimate': '3.10'},
            'report': {'date': '2026-09-25', 'timing': 'am', 'verified': true},
          }
        ],
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [msft],
        optionPositions: const [],
        now: fixedNow,
      );

      final earningsAlerts =
          alerts.where((a) => a.id.startsWith('earnings-')).toList();
      expect(earningsAlerts.length, equals(1));

      final alert = earningsAlerts.first;
      expect(alert.id, equals('earnings-tomorrow-MSFT'));
      expect(alert.severity, equals(PortfolioAlertSeverity.warning));
      expect(alert.title,
          contains('MSFT Reports Earnings Tomorrow (Before Open)'));
      expect(alert.detail, contains('You hold 50 shares'));
      expect(alert.detail, contains('Consensus EPS: \$3.10'));
      expect(alert.metric, equals('1d'));
      expect(alert.target, equals(PortfolioAlertTarget.earningsIvCrush));
    });

    test('raises info alert with countdown for 2-7 DTE upcoming earnings', () {
      final goog = buildStockPosition(
        symbol: 'GOOG',
        quantity: 200,
        earningsObj: [
          {
            'symbol': 'GOOG',
            'year': 2026,
            'quarter': 3,
            'eps': {'estimate': '1.85'},
            'report': {'date': '2026-09-28', 'timing': 'pm', 'verified': true},
          }
        ],
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [goog],
        optionPositions: const [],
        now: fixedNow, // Sep 24 -> Sep 28 is 4 days
      );

      final alert =
          alerts.firstWhere((a) => a.id == 'earnings-upcoming-GOOG-4');
      expect(alert.severity, equals(PortfolioAlertSeverity.info));
      expect(alert.title, contains('GOOG Earnings in 4 Days'));
      expect(alert.detail, contains('You hold 200 shares'));
      expect(alert.detail, contains('Consensus EPS: \$1.85'));
      expect(alert.metric, equals('4d'));
      expect(alert.target, equals(PortfolioAlertTarget.earningsIvCrush));
    });

    test('consolidates shares and options into a single alert per symbol', () {
      final nvdaStock = buildStockPosition(
        symbol: 'NVDA',
        quantity: 150,
        earningsObj: [
          {
            'symbol': 'NVDA',
            'year': 2026,
            'quarter': 3,
            'eps': {'estimate': '0.95'},
            'report': {'date': '2026-09-25', 'timing': 'pm', 'verified': true},
          }
        ],
      );

      final nvdaOption = buildOptionPosition(
        symbol: 'NVDA',
        quantity: 3,
        earningsObj: nvdaStock.instrumentObj?.earningsObj,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [nvdaStock],
        optionPositions: [nvdaOption],
        now: fixedNow,
      );

      final nvdaAlerts = alerts
          .where((a) => a.id.startsWith('earnings-') && a.id.contains('NVDA'))
          .toList();
      expect(nvdaAlerts.length, equals(1));

      final alert = nvdaAlerts.first;
      expect(alert.id, equals('earnings-tomorrow-NVDA'));
      expect(
          alert.detail, contains('You hold 150 shares and 3 option contracts'));
      expect(alert.detail, contains('Consensus EPS: \$0.95'));
    });

    test('ignores past reports (<0 days) and far future reports (>7 days)', () {
      final pastStock = buildStockPosition(
        symbol: 'OLD',
        quantity: 10,
        earningsObj: [
          {
            'symbol': 'OLD',
            'year': 2026,
            'quarter': 2,
            'report': {'date': '2026-09-10'},
          }
        ],
      );

      final farStock = buildStockPosition(
        symbol: 'FAR',
        quantity: 10,
        earningsObj: [
          {
            'symbol': 'FAR',
            'year': 2026,
            'quarter': 4,
            'report': {'date': '2026-10-30'}, // 36 days away
          }
        ],
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [pastStock, farStock],
        optionPositions: const [],
        now: fixedNow,
      );

      final earningsAlerts = alerts
          .where((a) =>
              a.id.startsWith('earnings-today') ||
              a.id.startsWith('earnings-tomorrow') ||
              a.id.startsWith('earnings-upcoming'))
          .toList();
      expect(earningsAlerts, isEmpty);
    });

    test(
        'falls back to earningsCrushAnalyses if position earningsObj is missing',
        () {
      final stockWithoutObj = buildStockPosition(
        symbol: 'CRSH',
        quantity: 25,
        earningsObj: null,
      );

      final crushAnalysis = EarningsIvCrushAnalysis(
        symbol: 'CRSH',
        spotPrice: 100,
        nextEarningsDate: DateTime(2026, 9, 25),
        daysToEarnings: 1,
        currentIv: 0.65,
        postEarningsEstimatedIv: 0.35,
        summary: const EarningsIvCrushSummary(
          quartersAnalyzed: 12,
          averageImpliedMovePct: 6.8,
          averageActualMovePct: 3.5,
          impliedVsActualSpread: 3.3,
          overpricingRatePct: 75.0,
          averageIvCrushPct: 45.0,
          crushProbabilityScore: 78,
          riskTier: EarningsIvCrushRiskTier.high,
          maxHistoricalMovePct: 8.0,
          minHistoricalMovePct: 1.2,
          upMovesCount: 7,
          downMovesCount: 5,
        ),
        quarters: const [],
        updatedAt: fixedNow,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [stockWithoutObj],
        optionPositions: const [],
        earningsCrushAnalyses: [crushAnalysis],
        now: fixedNow,
      );

      final alert = alerts.firstWhere((a) => a.id == 'earnings-tomorrow-CRSH');
      expect(alert.severity, equals(PortfolioAlertSeverity.warning));
      expect(alert.title, contains('CRSH Reports Earnings Tomorrow'));
      expect(alert.metric, equals('1d'));
    });
  });

  group('SmartAlertRule evaluateEarningsCalendarAlert', () {
    test('evaluates earnings_today condition', () {
      final eventToday = EarningsCalendarEvent(
        symbol: 'AAPL',
        date: DateTime(2026, 9, 24),
      );
      final eventTomorrow = EarningsCalendarEvent(
        symbol: 'AAPL',
        date: DateTime(2026, 9, 25),
      );

      const rule = SmartAlertRule(
        type: AlertType.earnings_calendar,
        condition: AlertCondition.earnings_today,
        value: 0,
      );

      expect(
        PortfolioAlertService.evaluateEarningsCalendarAlert(
          rule: rule,
          event: eventToday,
          now: fixedNow,
        ),
        isTrue,
      );

      expect(
        PortfolioAlertService.evaluateEarningsCalendarAlert(
          rule: rule,
          event: eventTomorrow,
          now: fixedNow,
        ),
        isFalse,
      );
    });

    test('evaluates earnings_tomorrow condition', () {
      final eventTomorrow = EarningsCalendarEvent(
        symbol: 'MSFT',
        date: DateTime(2026, 9, 25),
      );

      const rule = SmartAlertRule(
        type: AlertType.earnings_calendar,
        condition: AlertCondition.earnings_tomorrow,
        value: 1,
      );

      expect(
        PortfolioAlertService.evaluateEarningsCalendarAlert(
          rule: rule,
          event: eventTomorrow,
          now: fixedNow,
        ),
        isTrue,
      );
    });

    test('evaluates days_until_earnings condition with threshold', () {
      final eventIn3Days = EarningsCalendarEvent(
        symbol: 'GOOG',
        date: DateTime(2026, 9, 27), // 3 days
      );

      const ruleThreshold5 = SmartAlertRule(
        type: AlertType.earnings_calendar,
        condition: AlertCondition.days_until_earnings,
        value: 5,
      );

      const ruleThreshold2 = SmartAlertRule(
        type: AlertType.earnings_calendar,
        condition: AlertCondition.days_until_earnings,
        value: 2,
      );

      expect(
        PortfolioAlertService.evaluateEarningsCalendarAlert(
          rule: ruleThreshold5,
          event: eventIn3Days,
          now: fixedNow,
        ),
        isTrue,
      );

      expect(
        PortfolioAlertService.evaluateEarningsCalendarAlert(
          rule: ruleThreshold2,
          event: eventIn3Days,
          now: fixedNow,
        ),
        isFalse,
      );
    });
  });
}

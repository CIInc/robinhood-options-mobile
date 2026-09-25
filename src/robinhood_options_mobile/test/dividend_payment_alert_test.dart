import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/dividend_payment_event.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';

InstrumentPosition buildStockPosition({
  required String symbol,
  required double quantity,
  double? dividendYield,
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
  );

  return pos;
}

void main() {
  group('DividendPaymentEvent Model', () {
    test('calculates daysUntilPayable and daysUntilExDividend correctly', () {
      final now = DateTime(2026, 9, 24, 10, 0);

      final event = DividendPaymentEvent(
        symbol: 'AAPL',
        payableDate: DateTime(2026, 9, 28, 14, 0),
        exDividendDate: DateTime(2026, 9, 25, 8, 30),
        amount: 25.0,
        rate: 0.25,
        sharesHeld: 100.0,
      );

      expect(event.daysUntilPayable(now), 4);
      expect(event.daysUntilExDividend(now), 1);
    });

    test('returns null when dates are not set', () {
      final now = DateTime(2026, 9, 24);
      const event = DividendPaymentEvent(symbol: 'MSFT');

      expect(event.daysUntilPayable(now), isNull);
      expect(event.daysUntilExDividend(now), isNull);
    });

    test('formats amount, rate, and yield strings', () {
      const event = DividendPaymentEvent(
        symbol: 'KO',
        amount: 48.5,
        rate: 0.485,
        sharesHeld: 100.0,
        dividendYield: 3.15,
      );

      expect(event.formattedAmount, '\$48.50');
      expect(event.formattedRate, '\$0.48/share'); // 0.485 rounds or fixed 2 decimal
      expect(event.formattedYield, '3.15%');
    });

    test('parses from Robinhood and Schwab dividend map format', () {
      final rhMap = {
        'symbol': 'JNJ',
        'payable_date': '2026-09-24T00:00:00Z',
        'record_date': '2026-09-10T00:00:00Z',
        'ex_dividend_date': '2026-09-08T00:00:00Z',
        'amount': '124.00',
        'rate': '1.24',
        'position': '100',
        'state': 'paid',
        'is_reinvested': true,
      };

      final event = DividendPaymentEvent.fromDividendMap(rhMap);

      expect(event.symbol, 'JNJ');
      expect(event.amount, 124.0);
      expect(event.rate, 1.24);
      expect(event.sharesHeld, 100.0);
      expect(event.state, 'paid');
      expect(event.isPaid, isTrue);
      expect(event.isReinvested, isTrue);
    });

    test('calculates amount from rate * fallbackShares if amount is omitted', () {
      final map = {
        'symbol': 'O',
        'rate': 0.26,
        'payable_date': '2026-09-30',
        'state': 'pending',
      };

      final event =
          DividendPaymentEvent.fromDividendMap(map, fallbackShares: 50.0);

      expect(event.symbol, 'O');
      expect(event.sharesHeld, 50.0);
      expect(event.amount, closeTo(13.0, 0.001));
      expect(event.isPending, isTrue);
    });

    test('serialization roundtrip toJson and fromJson', () {
      final original = DividendPaymentEvent(
        symbol: 'SCHD',
        payableDate: DateTime(2026, 9, 29),
        exDividendDate: DateTime(2026, 9, 24),
        amount: 82.50,
        rate: 0.825,
        sharesHeld: 100.0,
        state: 'pending',
        isReinvested: true,
        frequency: 'quarterly',
        dividendYield: 3.45,
      );

      final json = original.toJson();
      final revived = DividendPaymentEvent.fromJson(json);

      expect(revived.symbol, 'SCHD');
      expect(revived.amount, 82.50);
      expect(revived.rate, 0.825);
      expect(revived.sharesHeld, 100.0);
      expect(revived.state, 'pending');
      expect(revived.isReinvested, isTrue);
      expect(revived.frequency, 'quarterly');
      expect(revived.dividendYield, 3.45);
    });
  });

  group('PortfolioAlertService Dividend Alerts', () {
    test('raises warning alert for 0 DTE ex-dividend date today', () {
      final now = DateTime(2026, 9, 24, 9, 30);
      final pos = buildStockPosition(symbol: 'AAPL', quantity: 50.0);

      final event = DividendPaymentEvent(
        symbol: 'AAPL',
        exDividendDate: DateTime(2026, 9, 24),
        rate: 0.25,
        amount: 12.50,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [pos],
        optionPositions: const [],
        dividendEvents: [event],
        now: now,
      );

      final exAlert = alerts.firstWhere(
        (a) => a.id == 'dividend_ex_date_today_AAPL',
      );

      expect(exAlert.severity, PortfolioAlertSeverity.warning);
      expect(exAlert.title, 'AAPL Ex-Dividend Date Today');
      expect(exAlert.detail, contains('Must hold 50 shares before market close'));
      expect(exAlert.detail, contains('Estimated payout: \$12.50'));
      expect(exAlert.target, PortfolioAlertTarget.performance);
    });

    test('raises info alert for 1 DTE ex-dividend tomorrow', () {
      final now = DateTime(2026, 9, 24, 10, 0);
      final pos = buildStockPosition(symbol: 'MSFT', quantity: 40.0);

      final event = DividendPaymentEvent(
        symbol: 'MSFT',
        exDividendDate: DateTime(2026, 9, 25),
        rate: 0.75,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [pos],
        optionPositions: const [],
        dividendEvents: [event],
        now: now,
      );

      final exAlert = alerts.firstWhere(
        (a) => a.id == 'dividend_ex_date_tomorrow_MSFT',
      );

      expect(exAlert.severity, PortfolioAlertSeverity.info);
      expect(exAlert.title, 'MSFT Ex-Dividend Tomorrow');
      expect(exAlert.metric, 'Tomorrow');
    });

    test('raises info alert with countdown for 2-7 DTE upcoming ex-dividend', () {
      final now = DateTime(2026, 9, 24, 10, 0);
      final pos = buildStockPosition(symbol: 'JNJ', quantity: 30.0);

      final event = DividendPaymentEvent(
        symbol: 'JNJ',
        exDividendDate: DateTime(2026, 9, 28), // in 4 days
        rate: 1.24,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [pos],
        optionPositions: const [],
        dividendEvents: [event],
        now: now,
      );

      final exAlert = alerts.firstWhere(
        (a) => a.id == 'dividend_ex_date_upcoming_JNJ_4',
      );

      expect(exAlert.severity, PortfolioAlertSeverity.info);
      expect(exAlert.title, 'JNJ Ex-Dividend in 4 days');
      expect(exAlert.metric, '4d');
    });

    test('raises positive alert for 0 DTE dividend payable today', () {
      final now = DateTime(2026, 9, 24, 11, 0);
      final pos = buildStockPosition(symbol: 'PG', quantity: 80.0);

      final event = DividendPaymentEvent(
        symbol: 'PG',
        payableDate: DateTime(2026, 9, 24),
        amount: 80.80,
        rate: 1.01,
        state: 'pending',
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [pos],
        optionPositions: const [],
        dividendEvents: [event],
        now: now,
      );

      final payAlert = alerts.firstWhere(
        (a) => a.id == 'dividend_payable_today_PG',
      );

      expect(payAlert.severity, PortfolioAlertSeverity.positive);
      expect(payAlert.title, 'PG Dividend Payable Today');
      expect(payAlert.detail, contains('payable today for your 80 shares'));
      expect(payAlert.target, PortfolioAlertTarget.performance);
    });

    test('raises positive alert for 0 DTE dividend already marked paid', () {
      final now = DateTime(2026, 9, 24, 11, 0);
      final pos = buildStockPosition(symbol: 'PEP', quantity: 50.0);

      final event = DividendPaymentEvent(
        symbol: 'PEP',
        payableDate: DateTime(2026, 9, 24),
        amount: 63.25,
        rate: 1.265,
        state: 'paid',
        isReinvested: true,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [pos],
        optionPositions: const [],
        dividendEvents: [event],
        now: now,
      );

      final payAlert = alerts.firstWhere(
        (a) => a.id == 'dividend_payable_today_PEP',
      );

      expect(payAlert.severity, PortfolioAlertSeverity.positive);
      expect(payAlert.title, contains('PEP Dividend Paid'));
      expect(payAlert.detail, contains('(DRIP enabled)'));
    });

    test('raises info alert for 1-7 DTE upcoming dividend payment', () {
      final now = DateTime(2026, 9, 24, 11, 0);
      final pos = buildStockPosition(symbol: 'VZ', quantity: 200.0);

      final event = DividendPaymentEvent(
        symbol: 'VZ',
        payableDate: DateTime(2026, 9, 27), // in 3 days
        amount: 133.00,
        rate: 0.665,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [pos],
        optionPositions: const [],
        dividendEvents: [event],
        now: now,
      );

      final payAlert = alerts.firstWhere(
        (a) => a.id == 'dividend_payable_upcoming_VZ_3',
      );

      expect(payAlert.severity, PortfolioAlertSeverity.info);
      expect(payAlert.title, 'VZ Dividend in 3 days');
      expect(payAlert.detail, contains('Scheduled payout of \$133.00'));
    });

    test('raises positive alert for dividend paid within last 48 hours', () {
      final now = DateTime(2026, 9, 24, 14, 0);
      final pos = buildStockPosition(symbol: 'CVX', quantity: 60.0);

      final event = DividendPaymentEvent(
        symbol: 'CVX',
        payableDate: DateTime(2026, 9, 23), // 1 day ago
        amount: 97.80,
        rate: 1.63,
        state: 'paid',
        isReinvested: true,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [pos],
        optionPositions: const [],
        dividendEvents: [event],
        now: now,
      );

      final payAlert = alerts.firstWhere(
        (a) => a.id == 'dividend_recently_paid_CVX',
      );

      expect(payAlert.severity, PortfolioAlertSeverity.positive);
      expect(payAlert.title, contains('CVX Dividend Paid'));
      expect(payAlert.detail, contains('(DRIP reinvested)'));
    });

    test('ingests raw dividendItems from DividendStore map', () {
      final now = DateTime(2026, 9, 24, 10, 0);
      final pos = buildStockPosition(symbol: 'HD', quantity: 25.0);

      final rawItem = {
        'symbol': 'HD',
        'payable_date': '2026-09-24T00:00:00Z',
        'amount': '56.25',
        'rate': '2.25',
        'state': 'pending',
      };

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [pos],
        optionPositions: const [],
        dividendItems: [rawItem],
        now: now,
      );

      final alert = alerts.firstWhere(
        (a) => a.id == 'dividend_payable_today_HD',
      );

      expect(alert.severity, PortfolioAlertSeverity.positive);
      expect(alert.title, 'HD Dividend Payable Today');
    });

    test('ignores distant future (>7 days) and distant past (<-2 days) events', () {
      final now = DateTime(2026, 9, 24, 10, 0);
      final pos = buildStockPosition(symbol: 'WMT', quantity: 50.0);

      final distantEvent = DividendPaymentEvent(
        symbol: 'WMT',
        payableDate: DateTime(2026, 10, 15), // in 21 days
        exDividendDate: DateTime(2026, 10, 5), // in 11 days
        amount: 40.0,
      );

      final ancientEvent = DividendPaymentEvent(
        symbol: 'WMT',
        payableDate: DateTime(2026, 8, 1), // in distant past
        state: 'paid',
        amount: 40.0,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [pos],
        optionPositions: const [],
        dividendEvents: [distantEvent, ancientEvent],
        now: now,
      );

      expect(
        alerts.any((a) => a.id.contains('WMT')),
        isFalse,
      );
    });
  });

  group('SmartAlertRule evaluateDividendAlert', () {
    final now = DateTime(2026, 9, 24);

    test('evaluates ex_dividend_today condition', () {
      final eventToday = DividendPaymentEvent(
        symbol: 'T',
        exDividendDate: DateTime(2026, 9, 24),
      );
      final eventTomorrow = DividendPaymentEvent(
        symbol: 'T',
        exDividendDate: DateTime(2026, 9, 25),
      );

      const rule = SmartAlertRule(
        type: AlertType.dividend_payment,
        condition: AlertCondition.ex_dividend_today,
        value: 0,
      );

      expect(
          PortfolioAlertService.evaluateDividendAlert(
              rule: rule, event: eventToday, now: now),
          isTrue);
      expect(
          PortfolioAlertService.evaluateDividendAlert(
              rule: rule, event: eventTomorrow, now: now),
          isFalse);
    });

    test('evaluates ex_dividend_tomorrow condition', () {
      final eventTomorrow = DividendPaymentEvent(
        symbol: 'T',
        exDividendDate: DateTime(2026, 9, 25),
      );

      const rule = SmartAlertRule(
        type: AlertType.dividend_payment,
        condition: AlertCondition.ex_dividend_tomorrow,
        value: 0,
      );

      expect(
          PortfolioAlertService.evaluateDividendAlert(
              rule: rule, event: eventTomorrow, now: now),
          isTrue);
    });

    test('evaluates ex_dividend_imminent condition with custom window', () {
      final eventIn3Days = DividendPaymentEvent(
        symbol: 'ABBV',
        exDividendDate: DateTime(2026, 9, 27),
      );
      final eventIn10Days = DividendPaymentEvent(
        symbol: 'ABBV',
        exDividendDate: DateTime(2026, 10, 4),
      );

      const rule = SmartAlertRule(
        type: AlertType.dividend_payment,
        condition: AlertCondition.ex_dividend_imminent,
        value: 5,
      );

      expect(
          PortfolioAlertService.evaluateDividendAlert(
              rule: rule, event: eventIn3Days, now: now),
          isTrue);
      expect(
          PortfolioAlertService.evaluateDividendAlert(
              rule: rule, event: eventIn10Days, now: now),
          isFalse);
    });

    test('evaluates dividend_payable_today condition', () {
      final eventPayToday = DividendPaymentEvent(
        symbol: 'MO',
        payableDate: DateTime(2026, 9, 24),
      );

      const rule = SmartAlertRule(
        type: AlertType.dividend_payment,
        condition: AlertCondition.dividend_payable_today,
        value: 0,
      );

      expect(
          PortfolioAlertService.evaluateDividendAlert(
              rule: rule, event: eventPayToday, now: now),
          isTrue);
    });

    test('evaluates dividend_payable_upcoming condition with threshold', () {
      final eventIn5Days = DividendPaymentEvent(
        symbol: 'XOM',
        payableDate: DateTime(2026, 9, 29),
      );

      const rule = SmartAlertRule(
        type: AlertType.dividend_payment,
        condition: AlertCondition.dividend_payable_upcoming,
        value: 7,
      );

      expect(
          PortfolioAlertService.evaluateDividendAlert(
              rule: rule, event: eventIn5Days, now: now),
          isTrue);
    });

    test('evaluates above and below payout amount thresholds', () {
      const event = DividendPaymentEvent(
        symbol: 'IBM',
        amount: 150.0,
      );

      const ruleAbove = SmartAlertRule(
        type: AlertType.dividend_payment,
        condition: AlertCondition.above,
        value: 100.0,
      );
      const ruleBelow = SmartAlertRule(
        type: AlertType.dividend_payment,
        condition: AlertCondition.below,
        value: 100.0,
      );

      expect(
          PortfolioAlertService.evaluateDividendAlert(
              rule: ruleAbove, event: event, now: now),
          isTrue);
      expect(
          PortfolioAlertService.evaluateDividendAlert(
              rule: ruleBelow, event: event, now: now),
          isFalse);
    });
  });
}

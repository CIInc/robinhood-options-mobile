import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/dividend_payment_event.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/model/unified_account.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';

/// Builds a position worth `price * quantity`, bought at `costBasis` per share
/// and closing yesterday at `previousClose`.
InstrumentPosition buildPosition({
  required String symbol,
  required double price,
  required double quantity,
  double? costBasis,
  double? previousClose,
}) {
  final position = InstrumentPosition(
    'https://example.com/positions/$symbol/',
    'https://example.com/instruments/$symbol/',
    'https://example.com/accounts/1AB23456/',
    '1AB23456',
    costBasis ?? price,
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

  position.instrumentObj = Instrument(
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
    quoteObj: Quote(
      askPrice: price,
      askSize: 0,
      bidPrice: price,
      bidSize: 0,
      lastTradePrice: price,
      lastExtendedHoursTradePrice: price,
      previousClose: previousClose ?? price,
      adjustedPreviousClose: previousClose ?? price,
      previousCloseDate: DateTime(2026, 1, 1),
      symbol: symbol,
      tradingHalted: false,
      hasTraded: true,
      lastTradePriceSource: 'test',
      updatedAt: DateTime(2026, 1, 2),
      instrument: '',
      instrumentId: symbol,
    ),
  );

  return position;
}

Account buildAccount({double? cash, double? buyingPower}) => Account(
      'https://example.com/accounts/1AB23456/',
      cash,
      '1AB23456',
      'margin',
      buyingPower,
      '2',
      0,
      0,
      0,
    );

OptionAggregatePosition buildOptionPosition({
  required String symbol,
  required double strikePrice,
  required String optionType,
  required DateTime expirationDate,
  double quantity = 1.0,
  String direction = 'debit',
  String positionType = 'long',
  String strategy = 'call',
  double? underlyingPrice,
  double? markPrice,
}) {
  final leg = OptionLeg(
    'leg-$symbol-$strikePrice-$optionType',
    null,
    positionType,
    'option-1',
    'open',
    1,
    'buy',
    expirationDate,
    strikePrice,
    optionType,
    [],
  );

  final pos = OptionAggregatePosition(
    'pos-$symbol-$strikePrice-$optionType',
    'chain-1',
    '1AB23456',
    symbol,
    strategy,
    markPrice != null ? markPrice * 100.0 : 250.0,
    [leg],
    quantity,
    null,
    null,
    direction,
    direction,
    100.0,
    DateTime(2026, 1, 1),
    DateTime(2026, 1, 1),
    strategy,
  );

  if (underlyingPrice != null) {
    pos.instrumentObj =
        buildPosition(symbol: symbol, price: underlyingPrice, quantity: 0)
            .instrumentObj;
  }

  return pos;
}

void main() {
  group('PortfolioAlertService concentration', () {
    test('stays quiet when no holding exceeds the warning weight', () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [
          buildPosition(symbol: 'AAA', price: 100, quantity: 10),
          buildPosition(symbol: 'BBB', price: 100, quantity: 10),
          buildPosition(symbol: 'CCC', price: 100, quantity: 10),
          buildPosition(symbol: 'DDD', price: 100, quantity: 10),
          buildPosition(symbol: 'EEE', price: 100, quantity: 10),
          buildPosition(symbol: 'FFF', price: 100, quantity: 10),
        ],
        optionPositions: const [],
      );

      expect(
        alerts.where((alert) => alert.id.startsWith('concentration-')),
        isEmpty,
      );
    });

    test('flags the dominant holding as critical past 30%', () {
      // NVDA is 4,000 of a 5,000 portfolio — 80%.
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [
          buildPosition(symbol: 'NVDA', price: 100, quantity: 40),
          buildPosition(symbol: 'AAPL', price: 100, quantity: 10),
        ],
        optionPositions: const [],
      );

      final alert = alerts.firstWhere((a) => a.id == 'concentration-NVDA');
      expect(alert.severity, PortfolioAlertSeverity.critical);
      expect(
        alert.target,
        anyOf(PortfolioAlertTarget.instrument, PortfolioAlertTarget.rebalance),
      );
      expect(alert.metric, '80%');
    });
  });

  group('PortfolioAlertService cash', () {
    test('flags an under-deployed account', () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        account: buildAccount(cash: 8200, buyingPower: 8200),
        totalEquity: 10000,
      );

      final alert = alerts.firstWhere((a) => a.id == 'high-cash');
      expect(alert.severity, PortfolioAlertSeverity.info);
      expect(alert.target, PortfolioAlertTarget.search);
      expect(alert.actionLabel, 'Deploy Cash');
      expect(alert.title, contains('82%'));
    });

    test('stays quiet when cash is a normal buffer', () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        account: buildAccount(cash: 500, buyingPower: 500),
        totalEquity: 10000,
      );

      expect(alerts.where((alert) => alert.id == 'high-cash'), isEmpty);
    });
  });

  group('PortfolioAlertService movers', () {
    test('surfaces the largest dollar mover of the day', () {
      // META gained $10/share on 100 shares; TSLA lost $6/share on 10.
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [
          buildPosition(
              symbol: 'META', price: 110, quantity: 100, previousClose: 100),
          buildPosition(
              symbol: 'TSLA', price: 94, quantity: 10, previousClose: 100),
        ],
        optionPositions: const [],
      );

      final alert = alerts.firstWhere((a) => a.id.startsWith('mover-'));
      expect(alert.id, 'mover-META');
      expect(alert.severity, PortfolioAlertSeverity.positive);
      expect(alert.icon, Icons.trending_up);
    });

    test('describes a negative move as a fall', () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [
          buildPosition(
              symbol: 'HOOD', price: 94.8, quantity: 10, previousClose: 100),
        ],
        optionPositions: const [],
      );

      final alert = alerts.firstWhere((a) => a.id == 'mover-HOOD');
      expect(alert.title, 'HOOD fell 5.2% today');
      expect(alert.severity, PortfolioAlertSeverity.warning);
      expect(alert.icon, Icons.trending_down);
    });

    test('ignores moves below the notable threshold', () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [
          buildPosition(
              symbol: 'KO', price: 101, quantity: 100, previousClose: 100),
        ],
        optionPositions: const [],
      );

      expect(alerts.where((alert) => alert.id.startsWith('mover-')), isEmpty);
    });
  });

  group('PortfolioAlertService analytics rules', () {
    test('are skipped entirely when metrics are not yet computed', () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        analytics: null,
      );

      expect(alerts.where((a) => a.id == 'benchmark-delta'), isEmpty);
      expect(alerts.where((a) => a.id == 'drawdown'), isEmpty);
      expect(alerts.where((a) => a.id == 'volatility'), isEmpty);
    });

    test('report trailing the benchmark', () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        analytics: const {'excessReturn': -0.089},
      );

      final alert = alerts.firstWhere((a) => a.id == 'benchmark-delta');
      expect(alert.severity, PortfolioAlertSeverity.warning);
      expect(alert.title, 'Trailing SPY by 8.9%');
      expect(alert.target, PortfolioAlertTarget.performance);
    });

    test('report beating the benchmark as positive', () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        analytics: const {'excessReturn': 0.089},
      );

      final alert = alerts.firstWhere((a) => a.id == 'benchmark-delta');
      expect(alert.severity, PortfolioAlertSeverity.positive);
      expect(alert.title, 'Beating SPY by 8.9%');
    });

    test('escalate a deep drawdown to critical', () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: const [],
        analytics: const {'currentDrawdown': -0.24},
      );

      final alert = alerts.firstWhere((a) => a.id == 'drawdown');
      expect(alert.severity, PortfolioAlertSeverity.critical);
    });
  });

  test('alerts are ordered most severe first', () {
    final alerts = PortfolioAlertService.buildAlerts(
      instrumentPositions: [
        buildPosition(symbol: 'NVDA', price: 100, quantity: 40),
        buildPosition(
            symbol: 'META', price: 110, quantity: 100, previousClose: 100),
      ],
      optionPositions: const [],
      account: buildAccount(cash: 8200, buyingPower: 8200),
      totalEquity: 10000,
    );

    final severities = alerts.map((alert) => alert.severity.index).toList();
    expect(severities, orderedEquals(List.of(severities)..sort()));
    expect(alerts.first.severity, PortfolioAlertSeverity.critical);
  });

  group('PortfolioAlertService option expiration', () {
    final fixedNow = DateTime(2026, 9, 24, 10, 0, 0);

    test('flags 0 DTE ITM long call as critical with exercise warning', () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: [
          buildOptionPosition(
            symbol: 'AAPL',
            strikePrice: 150,
            optionType: 'call',
            expirationDate: DateTime(2026, 9, 24),
            underlyingPrice: 160,
          ),
        ],
        now: fixedNow,
      );

      final expAlerts =
          alerts.where((a) => a.id.startsWith('opt-exp-')).toList();
      expect(expAlerts, hasLength(1));
      final alert = expAlerts.first;
      expect(alert.severity, PortfolioAlertSeverity.critical);
      expect(alert.title, contains('AAPL \$150 CALL expires today'));
      expect(alert.detail, contains('In-The-Money (ITM)'));
      expect(alert.detail, contains('automatically exercised'));
      expect(alert.metric, '0 DTE • ITM');
      expect(alert.target, PortfolioAlertTarget.optionPositions);
      expect(alert.icon, Icons.timer_outlined);
    });

    test(
        'flags 0 DTE OTM long put as critical with worthless expiration notice',
        () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: [
          buildOptionPosition(
            symbol: 'TSLA',
            strikePrice: 200,
            optionType: 'put',
            expirationDate: DateTime(2026, 9, 24),
            underlyingPrice: 220,
          ),
        ],
        now: fixedNow,
      );

      final alert = alerts.firstWhere((a) => a.id.startsWith('opt-exp-'));
      expect(alert.severity, PortfolioAlertSeverity.critical);
      expect(alert.title, contains('TSLA \$200 PUT expires today'));
      expect(alert.detail, contains('Out-of-The-Money (OTM)'));
      expect(alert.detail, contains('expire worthless'));
      expect(alert.metric, '0 DTE • OTM');
    });

    test(
        'flags 0 DTE short call as critical assignment risk targeting strategies',
        () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: [
          buildOptionPosition(
            symbol: 'NVDA',
            strikePrice: 120,
            optionType: 'call',
            direction: 'credit',
            positionType: 'short',
            strategy: 'short_call',
            expirationDate: DateTime(2026, 9, 24),
            underlyingPrice: 125,
          ),
        ],
        now: fixedNow,
      );

      final alert = alerts.firstWhere((a) => a.id.startsWith('opt-exp-'));
      expect(alert.severity, PortfolioAlertSeverity.critical);
      expect(alert.title, contains('NVDA \$120 CALL expires today'));
      expect(alert.detail, contains('assignment'));
      expect(alert.target, PortfolioAlertTarget.strategies);
      expect(alert.icon, Icons.assignment_late_outlined);
    });

    test('flags 1 DTE contracts as warning', () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: [
          buildOptionPosition(
            symbol: 'SPY',
            strikePrice: 550,
            optionType: 'call',
            expirationDate: DateTime(2026, 9, 25),
            underlyingPrice: 555,
          ),
        ],
        now: fixedNow,
      );

      final alert = alerts.firstWhere((a) => a.id.startsWith('opt-exp-'));
      expect(alert.severity, PortfolioAlertSeverity.warning);
      expect(alert.title, contains('SPY \$550 CALL expires tomorrow'));
      expect(alert.metric, contains('1 DTE'));
      expect(alert.icon, Icons.alarm_on_outlined);
    });

    test('flags 2-3 DTE contracts with countdown notice', () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: [
          buildOptionPosition(
            symbol: 'AMD',
            strikePrice: 170,
            optionType: 'call',
            expirationDate: DateTime(2026, 9, 27),
            underlyingPrice: 165,
          ),
        ],
        now: fixedNow,
      );

      final alert = alerts.firstWhere((a) => a.id.startsWith('opt-exp-'));
      expect(alert.severity, PortfolioAlertSeverity.info);
      expect(alert.title, contains('AMD \$170 CALL expires in 3 days'));
      expect(alert.metric, contains('3d DTE'));
      expect(alert.icon, Icons.event_available_outlined);
    });

    test(
        'ignores contracts expiring past 3 days or already expired in the past',
        () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: [
          buildOptionPosition(
            symbol: 'MSFT',
            strikePrice: 400,
            optionType: 'call',
            expirationDate: DateTime(2026, 10, 15),
          ),
          buildOptionPosition(
            symbol: 'GOOG',
            strikePrice: 180,
            optionType: 'call',
            expirationDate: DateTime(2026, 9, 20),
          ),
        ],
        now: fixedNow,
      );

      expect(alerts.where((a) => a.id.startsWith('opt-exp-')), isEmpty);
    });

    test('ignores option positions with zero quantity', () {
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: [
          buildOptionPosition(
            symbol: 'AAPL',
            strikePrice: 150,
            optionType: 'call',
            expirationDate: DateTime(2026, 9, 24),
            quantity: 0,
          ),
        ],
        now: fixedNow,
      );

      expect(alerts.where((a) => a.id.startsWith('opt-exp-')), isEmpty);
    });

    test(
        'evaluateOptionEarlyAssignmentAlert triggers when short call extrinsic <= 1.25x dividend',
        () {
      // Strike 100, spot 105 (ITM by $5.00). Mark = 5.20 -> Intrinsic = 5.00, Extrinsic = 0.20
      final pos = buildOptionPosition(
        symbol: 'IBM',
        strikePrice: 100,
        optionType: 'call',
        direction: 'credit',
        positionType: 'short',
        strategy: 'short_call',
        expirationDate: DateTime(2026, 10, 15), // Expiration is 21 days out
        underlyingPrice: 105.0,
        markPrice: 5.20,
      );

      final divEvent = DividendPaymentEvent(
        symbol: 'IBM',
        exDividendDate: DateTime(2026, 9, 27), // Ex-div is in 3 days
        rate: 0.25, // 1.25 * 0.25 = 0.3125 >= 0.20 extrinsic
      );

      final alert = PortfolioAlertService.evaluateOptionEarlyAssignmentAlert(
        pos,
        fixedNow,
        [divEvent],
      );

      expect(alert, isNotNull);
      expect(alert!.severity, PortfolioAlertSeverity.critical);
      expect(alert.id, contains('opt-exdiv-assignment-'));
      expect(alert.title, contains('IBM \$100 CALL Ex-Div Assignment Hazard'));
      expect(alert.target, PortfolioAlertTarget.strategies);
      expect(alert.payload?['isExDivRisk'], isTrue);
      expect(alert.payload?['extrinsicValue'], closeTo(0.20, 0.001));
    });

    test(
        'evaluateOptionPinRiskAlert flags 0DTE/1DTE short option with Margin Shock deficit',
        () {
      // Strike 300, spot 301.50 (within 0.5% proximity <= 1.0%), 0 DTE
      final pos = buildOptionPosition(
        symbol: 'MSFT',
        strikePrice: 300,
        optionType: 'put',
        direction: 'credit',
        positionType: 'short',
        strategy: 'short_put',
        expirationDate: DateTime(2026, 9, 24),
        underlyingPrice: 301.50,
        quantity: 3, // Notional = 100 * 300 * 3 = $90,000
      );

      final account = buildAccount(buyingPower: 35000); // Deficit = $55,000

      final alert = PortfolioAlertService.evaluateOptionPinRiskAlert(
        pos,
        fixedNow,
        account: account,
      );

      expect(alert, isNotNull);
      expect(alert!.severity, PortfolioAlertSeverity.critical);
      expect(alert.id, contains('opt-pin-risk-'));
      expect(alert.title, contains('MSFT \$300 PUT Margin Shock Pin Risk'));
      expect(
          alert.detail,
          contains(
              'Assignment notional (\$90000) exceeds buying power (\$35000) by \$55000'));
      expect(alert.payload?['isMarginShock'], isTrue);
      expect(alert.payload?['notionalObligation'], 90000.0);
      expect(alert.payload?['marginDeficit'], 55000.0);
      expect(alert.actionLabel, 'Emergency Close');
    });

    test(
        'evaluateOptionPinRiskAlert flags 0DTE short option without margin shock if buying power covers obligation',
        () {
      final pos = buildOptionPosition(
        symbol: 'SPY',
        strikePrice: 500,
        optionType: 'call',
        direction: 'credit',
        positionType: 'short',
        strategy: 'short_call',
        expirationDate: DateTime(2026, 9, 24),
        underlyingPrice: 498.0, // within 0.4% proximity
        quantity: 1, // Notional = $50,000
      );

      final unifiedAccount = const UnifiedAccount(
        accountNumber: '1AB23456',
        buyingPower: 120000,
      );

      final alert = PortfolioAlertService.evaluateOptionPinRiskAlert(
        pos,
        fixedNow,
        unifiedAccount: unifiedAccount,
      );

      expect(alert, isNotNull);
      expect(alert!.severity, PortfolioAlertSeverity.critical);
      expect(alert.title, contains('SPY \$500 CALL 0DTE/1DTE Pin Risk'));
      expect(alert.payload?['isMarginShock'], isFalse);
      expect(alert.actionLabel, 'Manage Defense');
    });

    test(
        'PortfolioAlertService.buildAlerts surfaces both ex-dividend and pin-risk alerts',
        () {
      final exDivPos = buildOptionPosition(
        symbol: 'IBM',
        strikePrice: 100,
        optionType: 'call',
        direction: 'credit',
        positionType: 'short',
        strategy: 'short_call',
        expirationDate: DateTime(2026, 10, 15),
        underlyingPrice: 105.0,
        markPrice: 5.15, // extrinsic = 0.15 <= 1.25 * 0.20 = 0.25
      );

      final pinPos = buildOptionPosition(
        symbol: 'TSLA',
        strikePrice: 200,
        optionType: 'put',
        direction: 'credit',
        positionType: 'short',
        strategy: 'short_put',
        expirationDate: DateTime(2026, 9, 24),
        underlyingPrice: 200.80, // 0.4% away
        quantity: 2, // Notional = $40,000
      );

      final divEvent = DividendPaymentEvent(
        symbol: 'IBM',
        exDividendDate: DateTime(2026, 9, 28),
        rate: 0.20,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: [exDivPos, pinPos],
        account: buildAccount(
            buyingPower: 25000), // Deficit for TSLA: 40000 - 25000 = $15000
        dividendEvents: [divEvent],
        now: fixedNow,
      );

      expect(
          alerts.any((a) => a.id.startsWith('opt-exdiv-assignment-')), isTrue);
      expect(alerts.any((a) => a.id.startsWith('opt-pin-risk-')), isTrue);
      final pinAlert =
          alerts.firstWhere((a) => a.id.startsWith('opt-pin-risk-'));
      expect(pinAlert.title, contains('Margin Shock Pin Risk'));
    });
  });
}

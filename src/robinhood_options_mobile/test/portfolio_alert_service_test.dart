import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
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
    2.5,
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
      expect(alert.target, PortfolioAlertTarget.risk);
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
      expect(alert.target, PortfolioAlertTarget.rebalance);
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
      expect(alert.target, PortfolioAlertTarget.positions);
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

    test('ignores contracts expiring past 3 days or already expired in the past',
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
  });
}

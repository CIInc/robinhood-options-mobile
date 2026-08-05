import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
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
}

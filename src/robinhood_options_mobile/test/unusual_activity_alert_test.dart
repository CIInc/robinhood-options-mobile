import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/custom_alert.dart';
import 'package:robinhood_options_mobile/model/fundamentals.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_leg.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';

InstrumentPosition buildStockPosition({
  required String symbol,
  required double quantity,
  double lastPrice = 100.0,
  double adjustedPreviousClose = 100.0,
  double? volume,
  double? averageVolume30Days,
  double? averageVolume,
}) {
  final pos = InstrumentPosition(
    'https://example.com/positions/$symbol/',
    'https://example.com/instruments/$symbol/',
    'https://example.com/accounts/1AB23456/',
    '1AB23456',
    adjustedPreviousClose,
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

  pos.instrumentObj!.quoteObj = Quote(
    askPrice: lastPrice,
    askSize: 100,
    bidPrice: lastPrice,
    bidSize: 100,
    lastTradePrice: lastPrice,
    previousClose: adjustedPreviousClose,
    adjustedPreviousClose: adjustedPreviousClose,
    symbol: symbol,
    tradingHalted: false,
    hasTraded: true,
    lastTradePriceSource: 'consolidated',
    instrument: 'https://example.com/instruments/$symbol/',
    instrumentId: symbol,
  );

  if (volume != null || averageVolume30Days != null || averageVolume != null) {
    pos.instrumentObj!.fundamentalsObj = Fundamentals(
      volume: volume,
      averageVolume30Days: averageVolume30Days,
      averageVolume: averageVolume,
    );
  }

  return pos;
}

OptionAggregatePosition buildOptionPosition({
  required String id,
  required String symbol,
  required double quantity,
  required double strikePrice,
  required String optionType,
  required int volume,
  required int openInterest,
}) {
  final pos = OptionAggregatePosition(
    id,
    'chain_$symbol',
    '1AB23456',
    symbol,
    'long_$optionType',
    2.50,
    [
      OptionLeg(
        'leg_$id',
        null,
        'long',
        'opt_$id',
        null,
        1,
        'buy',
        DateTime(2026, 10, 16),
        strikePrice,
        optionType,
        const [],
      )
    ],
    quantity,
    null,
    null,
    'debit',
    'debit',
    100.0,
    DateTime(2026, 1, 1),
    DateTime(2026, 1, 1),
    'long_$optionType',
  );

  pos.optionInstrument = OptionInstrument(
    'chain_$symbol',
    symbol,
    DateTime(2026, 1, 1),
    DateTime(2026, 10, 16),
    'opt_$id',
    DateTime(2026, 1, 1),
    const MinTicks(0.01, 0.05, 3.0),
    'tradable',
    'active',
    strikePrice,
    'tradable',
    optionType,
    DateTime(2026, 1, 1),
    '',
    null,
    '',
    '',
  );

  pos.optionInstrument!.optionMarketData = OptionMarketData.fromJson({
    'adjusted_mark_price': '2.50',
    'mark_price': '2.50',
    'ask_price': '2.55',
    'ask_size': 10,
    'bid_price': '2.45',
    'bid_size': 10,
    'instrument': 'opt_$id',
    'instrument_id': 'opt_$id',
    'open_interest': openInterest,
    'volume': volume,
    'symbol': symbol,
    'occ_symbol': '${symbol}261016C00$strikePrice',
  });

  return pos;
}

void main() {
  group('PortfolioAlertService Unusual Activity Alerts', () {
    test('surfaces critical alert for heavy-volume selloff confluence (>= 3.0x vol and <= -4% drop)', () {
      final stocks = [
        buildStockPosition(
          symbol: 'TSLA',
          quantity: 100.0,
          adjustedPreviousClose: 200.0,
          lastPrice: 190.0, // -5.0% drop
          volume: 30000000.0,
          averageVolume30Days: 10000000.0, // 3.0x volume multiple
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
      );

      final unusualAlerts =
          alerts.where((a) => a.id.startsWith('unusual-activity-')).toList();
      expect(unusualAlerts, hasLength(1));
      final alert = unusualAlerts.first;
      expect(alert.id, 'unusual-activity-TSLA');
      expect(alert.severity, PortfolioAlertSeverity.critical);
      expect(alert.title, contains('Heavy-volume selloff'));
      expect(alert.title, contains('3.0x vol'));
      expect(alert.detail, contains('Held in portfolio (100 shares)'));
      expect(alert.detail, contains('institutional distribution'));
      expect(alert.metric, '3.0x vol');
      expect(alert.target, PortfolioAlertTarget.positions);
    });

    test('surfaces warning alert for heavy-volume selloff confluence (2.2x vol and -4.5% drop)', () {
      final stocks = [
        buildStockPosition(
          symbol: 'GOOG',
          quantity: 50.0,
          adjustedPreviousClose: 180.0,
          lastPrice: 171.9, // -4.5% drop
          volume: 2200000.0,
          averageVolume30Days: 1000000.0, // 2.2x volume multiple
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
      );

      final unusualAlerts =
          alerts.where((a) => a.id == 'unusual-activity-GOOG').toList();
      expect(unusualAlerts, hasLength(1));
      final alert = unusualAlerts.first;
      expect(alert.severity, PortfolioAlertSeverity.warning);
      expect(alert.title, contains('Heavy-volume selloff'));
      expect(alert.title, contains('2.2x vol'));
      expect(alert.detail, contains('Held in portfolio (50 shares)'));
    });

    test('surfaces positive alert for high-volume breakout confluence (>= 2.0x vol and >= +4% gain)', () {
      final stocks = [
        buildStockPosition(
          symbol: 'NVDA',
          quantity: 25.0,
          adjustedPreviousClose: 120.0,
          lastPrice: 128.4, // +7.0% gain
          volume: 50000000.0,
          averageVolume30Days: 20000000.0, // 2.5x volume multiple
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
      );

      final unusualAlerts =
          alerts.where((a) => a.id == 'unusual-activity-NVDA').toList();
      expect(unusualAlerts, hasLength(1));
      final alert = unusualAlerts.first;
      expect(alert.severity, PortfolioAlertSeverity.positive);
      expect(alert.title, contains('High-volume breakout'));
      expect(alert.title, contains('2.5x vol'));
      expect(alert.detail, contains('Held in portfolio (25 shares)'));
      expect(alert.detail, contains('upward price momentum'));
      expect(alert.metric, '2.5x vol');
      expect(alert.target, PortfolioAlertTarget.positions);
    });

    test('surfaces warning alert for extreme unusual volume (>= 2.5x avg vol) without large price move', () {
      final stocks = [
        buildStockPosition(
          symbol: 'MSFT',
          quantity: 40.0,
          adjustedPreviousClose: 400.0,
          lastPrice: 404.0, // +1.0% small move
          volume: 28000000.0,
          averageVolume30Days: 10000000.0, // 2.8x volume multiple
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
      );

      final unusualAlerts =
          alerts.where((a) => a.id == 'unusual-activity-MSFT').toList();
      expect(unusualAlerts, hasLength(1));
      final alert = unusualAlerts.first;
      expect(alert.severity, PortfolioAlertSeverity.warning);
      expect(alert.title, contains('Extreme unusual volume'));
      expect(alert.title, contains('2.8x'));
      expect(alert.detail, contains('Held in portfolio (40 shares)'));
      expect(alert.detail, contains('repositioning'));
      expect(alert.metric, '2.8x vol');
    });

    test('surfaces critical alert for sharp intraday price drop (<= -6%) even without volume multiplier', () {
      final stocks = [
        buildStockPosition(
          symbol: 'META',
          quantity: 30.0,
          adjustedPreviousClose: 500.0,
          lastPrice: 460.0, // -8.0% drop
          volume: 1200000.0,
          averageVolume30Days: 1000000.0, // 1.2x volume (not >= 2.0x)
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
      );

      final unusualAlerts =
          alerts.where((a) => a.id == 'unusual-activity-META').toList();
      expect(unusualAlerts, hasLength(1));
      final alert = unusualAlerts.first;
      expect(alert.severity, PortfolioAlertSeverity.critical);
      expect(alert.title, contains('Sharp intraday drop'));
      expect(alert.detail, contains('Held in portfolio (30 shares)'));
      expect(alert.target, PortfolioAlertTarget.positions);
    });

    test('surfaces positive alert for sharp intraday rally (>= +6%) without 2.0x volume', () {
      final stocks = [
        buildStockPosition(
          symbol: 'AMZN',
          quantity: 20.0,
          adjustedPreviousClose: 180.0,
          lastPrice: 194.4, // +8.0% rally
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: stocks,
        optionPositions: const [],
      );

      final unusualAlerts =
          alerts.where((a) => a.id == 'unusual-activity-AMZN').toList();
      expect(unusualAlerts, hasLength(1));
      final alert = unusualAlerts.first;
      expect(alert.severity, PortfolioAlertSeverity.positive);
      expect(alert.title, contains('Sharp intraday rally'));
      expect(alert.detail, contains('Held in portfolio (20 shares)'));
      expect(alert.target, PortfolioAlertTarget.positions);
    });

    test('surfaces critical alert for unusual option volume (>= 3.0x OI)', () {
      final options = [
        buildOptionPosition(
          id: 'pos_aapl_call',
          symbol: 'AAPL',
          quantity: 5.0,
          strikePrice: 230.0,
          optionType: 'call',
          volume: 3500,
          openInterest: 1000, // 3.5x OI
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: options,
      );

      final optionAlerts =
          alerts.where((a) => a.id.startsWith('unusual-option-')).toList();
      expect(optionAlerts, hasLength(1));
      final alert = optionAlerts.first;
      expect(alert.id, 'unusual-option-pos_aapl_call');
      expect(alert.severity, PortfolioAlertSeverity.critical);
      expect(alert.title, contains('Unusual option volume'));
      expect(alert.title, contains('3.5x OI on \$230 CALL'));
      expect(alert.detail, contains('Held in portfolio (5 contracts)'));
      expect(alert.metric, '3.5x OI');
      expect(alert.target, PortfolioAlertTarget.positions);
    });

    test('surfaces warning alert for unusual option volume (2.2x OI)', () {
      final options = [
        buildOptionPosition(
          id: 'pos_spy_put',
          symbol: 'SPY',
          quantity: 2.0,
          strikePrice: 560.0,
          optionType: 'put',
          volume: 2200,
          openInterest: 1000, // 2.2x OI
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: options,
      );

      final optionAlerts =
          alerts.where((a) => a.id == 'unusual-option-pos_spy_put').toList();
      expect(optionAlerts, hasLength(1));
      final alert = optionAlerts.first;
      expect(alert.severity, PortfolioAlertSeverity.warning);
      expect(alert.title, contains('2.2x OI on \$560 PUT'));
    });

    test('ignores option volume below minimum threshold to avoid false alarms', () {
      final options = [
        buildOptionPosition(
          id: 'pos_illiquid',
          symbol: 'ILLQ',
          quantity: 1.0,
          strikePrice: 50.0,
          optionType: 'call',
          volume: 20, // Low volume (< 500)
          openInterest: 5, // 4.0x ratio, but only 20 contracts
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: const [],
        optionPositions: options,
      );

      final optionAlerts =
          alerts.where((a) => a.id.startsWith('unusual-option-')).toList();
      expect(optionAlerts, isEmpty);
    });

    test('ignores positions with zero quantity or zero market value', () {
      final zeroStocks = [
        buildStockPosition(
          symbol: 'ZERO',
          quantity: 0.0,
          volume: 10000000.0,
          averageVolume30Days: 1000000.0,
        ),
      ];
      final zeroOptions = [
        buildOptionPosition(
          id: 'pos_zero',
          symbol: 'ZERO_OPT',
          quantity: 0.0,
          strikePrice: 100.0,
          optionType: 'call',
          volume: 5000,
          openInterest: 1000,
        ),
      ];

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: zeroStocks,
        optionPositions: zeroOptions,
      );

      final unusualAlerts = alerts
          .where((a) =>
              a.id.startsWith('unusual-activity-') ||
              a.id.startsWith('unusual-option-'))
          .toList();
      expect(unusualAlerts, isEmpty);
    });
  });

  group('SmartAlertRule evaluateUnusualActivityAlert', () {
    test('evaluates unusual_volume condition with default and custom threshold', () {
      final defaultRule = const SmartAlertRule(
        type: AlertType.volume,
        condition: AlertCondition.unusual_volume,
        value: 0.0, // default 2.0x
      );
      final customRule = const SmartAlertRule(
        type: AlertType.unusual_activity,
        condition: AlertCondition.unusual_volume,
        value: 3.0, // custom 3.0x
      );

      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: defaultRule,
          volume: 2500000,
          averageVolume: 1000000, // 2.5x
        ),
        isTrue,
      );
      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: defaultRule,
          volume: 1500000,
          averageVolume: 1000000, // 1.5x (< 2.0x)
        ),
        isFalse,
      );
      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: customRule,
          volume: 2500000,
          averageVolume: 1000000, // 2.5x (< 3.0x)
        ),
        isFalse,
      );
      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: customRule,
          volume: 3500000,
          averageVolume: 1000000, // 3.5x (>= 3.0x)
        ),
        isTrue,
      );
    });

    test('evaluates volume_spike condition with raw volume and multiplier', () {
      final rawCountRule = const SmartAlertRule(
        type: AlertType.volume,
        condition: AlertCondition.volume_spike,
        value: 1000000.0, // raw 1M volume
      );
      final multiplierRule = const SmartAlertRule(
        type: AlertType.volume,
        condition: AlertCondition.volume_spike,
        value: 2.5, // 2.5x multiplier
      );

      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: rawCountRule,
          volume: 1500000,
        ),
        isTrue,
      );
      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: rawCountRule,
          volume: 800000,
        ),
        isFalse,
      );
      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: multiplierRule,
          volume: 3000000,
          averageVolume: 1000000,
        ),
        isTrue,
      );
    });

    test('evaluates unusual_options_volume condition', () {
      final rule = const SmartAlertRule(
        type: AlertType.volume,
        condition: AlertCondition.unusual_options_volume,
        value: 2.0,
      );

      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: rule,
          optionVolume: 2500,
          optionOpenInterest: 1000, // 2.5x
        ),
        isTrue,
      );
      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: rule,
          optionVolume: 1200,
          optionOpenInterest: 1000, // 1.2x
        ),
        isFalse,
      );
    });

    test('evaluates price_spike and price_drop conditions', () {
      final spikeRule = const SmartAlertRule(
        type: AlertType.unusual_activity,
        condition: AlertCondition.price_spike,
        value: 5.0, // +5.0%
      );
      final dropRule = const SmartAlertRule(
        type: AlertType.unusual_activity,
        condition: AlertCondition.price_drop,
        value: 5.0, // -5.0%
      );

      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: spikeRule,
          priceChangePercent: 6.2,
        ),
        isTrue,
      );
      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: spikeRule,
          priceChangePercent: 3.5,
        ),
        isFalse,
      );
      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: dropRule,
          priceChangePercent: -7.1,
        ),
        isTrue,
      );
      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: dropRule,
          priceChangePercent: -2.0,
        ),
        isFalse,
      );
    });

    test('evaluates spike, drop, percent_change, above, and below conditions', () {
      final spikeRule = const SmartAlertRule(
        type: AlertType.volume,
        condition: AlertCondition.spike,
        value: 2.0,
      );
      final dropRule = const SmartAlertRule(
        type: AlertType.price,
        condition: AlertCondition.drop,
        value: 4.0,
      );
      final pctRule = const SmartAlertRule(
        type: AlertType.price,
        condition: AlertCondition.percent_change,
        value: 6.0,
      );

      // Spike triggered by volume
      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: spikeRule,
          volume: 2200000,
          averageVolume: 1000000,
          priceChangePercent: 1.0,
        ),
        isTrue,
      );

      // Drop triggered by price drop
      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: dropRule,
          priceChangePercent: -5.5,
        ),
        isTrue,
      );

      // Percent change triggered on absolute change
      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: pctRule,
          priceChangePercent: -7.0,
        ),
        isTrue,
      );
      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: pctRule,
          priceChangePercent: 2.0,
        ),
        isFalse,
      );
    });

    test('evaluateVolumeAlert alias works identically to evaluateUnusualActivityAlert', () {
      final rule = const SmartAlertRule(
        type: AlertType.volume,
        condition: AlertCondition.unusual_volume,
        value: 2.0,
      );

      expect(
        PortfolioAlertService.evaluateVolumeAlert(
          rule: rule,
          volume: 3000000,
          averageVolume: 1000000,
        ),
        isTrue,
      );
    });

    test('returns false when rule type is unrelated', () {
      final rule = const SmartAlertRule(
        type: AlertType.rsi,
        condition: AlertCondition.above,
        value: 70.0,
      );

      expect(
        PortfolioAlertService.evaluateUnusualActivityAlert(
          rule: rule,
          volume: 5000000,
          averageVolume: 1000000,
        ),
        isFalse,
      );
    });
  });
}

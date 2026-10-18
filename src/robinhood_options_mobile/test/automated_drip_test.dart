import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/automated_drip_config.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/automated_drip_service.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AutomatedDripConfig Model Tests', () {
    test('Default values are initialized correctly', () {
      final config = AutomatedDripConfig();
      expect(config.enabled, false);
      expect(config.defaultMode, DripThresholdMode.belowCostBasis);
      expect(config.defaultDiscountPercent, 5.0);
      expect(config.defaultOrderType, 'market');
      expect(config.instrumentRules.isEmpty, true);
      expect(config.transactions.isEmpty, true);
    });

    test('Serialization and deserialization works correctly', () {
      final now = DateTime.now();
      final config = AutomatedDripConfig(
        enabled: true,
        defaultMode: DripThresholdMode.belowFixedPrice,
        defaultDiscountPercent: 8.5,
        defaultOrderType: 'limit',
        instrumentRules: {
          'AAPL': InstrumentDripRule(
            symbol: 'AAPL',
            enabled: true,
            thresholdMode: DripThresholdMode.belowFixedPrice,
            targetPrice: 175.0,
            discountPercent: 5.0,
            orderType: 'limit',
            notes: 'Target valuation limit',
          ),
          'SCHD': InstrumentDripRule(
            symbol: 'SCHD',
            enabled: false,
            thresholdMode: DripThresholdMode.discountFromCostBasis,
            discountPercent: 7.0,
          ),
        },
        transactions: [
          DripTransaction(
            id: 'tx_123',
            timestamp: now,
            symbol: 'AAPL',
            instrumentName: 'Apple Inc.',
            dividendAmount: 25.0,
            executionPrice: 170.0,
            thresholdPrice: 175.0,
            sharesPurchased: 0.147,
            status: 'executed',
            orderId: 'ord_999',
            notes: 'Executed below target price',
          ),
        ],
      );

      final json = config.toJson();
      final deserialized = AutomatedDripConfig.fromJson(json);

      expect(deserialized.enabled, true);
      expect(deserialized.defaultMode, DripThresholdMode.belowFixedPrice);
      expect(deserialized.defaultDiscountPercent, 8.5);
      expect(deserialized.defaultOrderType, 'limit');
      expect(deserialized.instrumentRules.length, 2);
      expect(deserialized.instrumentRules['AAPL']?.targetPrice, 175.0);
      expect(deserialized.instrumentRules['SCHD']?.enabled, false);
      expect(deserialized.transactions.length, 1);
      expect(deserialized.transactions.first.symbol, 'AAPL');
      expect(deserialized.transactions.first.sharesPurchased, 0.147);
    });

    test('copyWith updates specified fields only', () {
      final initial = AutomatedDripConfig(enabled: false);
      final updated =
          initial.copyWith(enabled: true, defaultOrderType: 'limit');
      expect(updated.enabled, true);
      expect(updated.defaultOrderType, 'limit');
      expect(updated.defaultMode, DripThresholdMode.belowCostBasis);
    });

    test('User model properly includes automatedDripConfig in JSON', () {
      final user = User(
        devices: [],
        dateCreated: DateTime.now(),
        brokerageUsers: [],
        automatedDripConfig: AutomatedDripConfig(
          enabled: true,
          defaultMode: DripThresholdMode.discountFromCostBasis,
        ),
      );

      final json = user.toJson();
      expect(json['automatedDripConfig'], isNotNull);
      final deserialized = User.fromJson(json);
      expect(deserialized.automatedDripConfig?.enabled, true);
      expect(deserialized.automatedDripConfig?.defaultMode,
          DripThresholdMode.discountFromCostBasis);
    });
  });

  group('AutomatedDripService Evaluation Tests', () {
    test('Suppresses reinvestment when globally disabled', () {
      final service = AutomatedDripService(
        initialConfig: AutomatedDripConfig(enabled: false),
      );

      final result = service.evaluateDividend(
        symbol: 'AAPL',
        currentPrice: 150.0,
        costBasis: 180.0,
      );

      expect(result.shouldReinvest, false);
      expect(result.reason, contains('globally disabled'));
    });

    test('Suppresses reinvestment when symbol rule is specifically paused', () {
      final service = AutomatedDripService(
        initialConfig: AutomatedDripConfig(
          enabled: true,
          instrumentRules: {
            'O': InstrumentDripRule(symbol: 'O', enabled: false),
          },
        ),
      );

      final result = service.evaluateDividend(
        symbol: 'O',
        currentPrice: 50.0,
        costBasis: 55.0,
      );

      expect(result.shouldReinvest, false);
      expect(result.reason, contains('disabled for O'));
    });

    test('Evaluates belowCostBasis mode correctly', () {
      final service = AutomatedDripService(
        initialConfig: AutomatedDripConfig(
          enabled: true,
          defaultMode: DripThresholdMode.belowCostBasis,
        ),
      );

      // 1. Current price <= cost basis -> eligible
      final eligible = service.evaluateDividend(
        symbol: 'SCHD',
        currentPrice: 75.0,
        costBasis: 80.0,
      );
      expect(eligible.shouldReinvest, true);
      expect(eligible.thresholdPrice, 80.0);

      // 2. Current price > cost basis -> held in cash
      final ineligible = service.evaluateDividend(
        symbol: 'SCHD',
        currentPrice: 85.0,
        costBasis: 80.0,
      );
      expect(ineligible.shouldReinvest, false);
      expect(ineligible.reason, contains('Dividend held in cash'));
    });

    test('Evaluates belowFixedPrice mode correctly', () {
      final service = AutomatedDripService(
        initialConfig: AutomatedDripConfig(
          enabled: true,
          instrumentRules: {
            'AAPL': InstrumentDripRule(
              symbol: 'AAPL',
              thresholdMode: DripThresholdMode.belowFixedPrice,
              targetPrice: 170.0,
            ),
          },
        ),
      );

      // Price at 168.50 is <= 170.00
      final ok = service.evaluateDividend(
        symbol: 'AAPL',
        currentPrice: 168.50,
      );
      expect(ok.shouldReinvest, true);
      expect(ok.thresholdPrice, 170.0);

      // Price at 175.00 exceeds 170.00
      final exceeded = service.evaluateDividend(
        symbol: 'AAPL',
        currentPrice: 175.00,
      );
      expect(exceeded.shouldReinvest, false);
      expect(exceeded.reason, contains('exceeds target'));
    });

    test('Evaluates discountFromCostBasis mode correctly', () {
      final service = AutomatedDripService(
        initialConfig: AutomatedDripConfig(
          enabled: true,
          defaultMode: DripThresholdMode.discountFromCostBasis,
          defaultDiscountPercent:
              10.0, // 10% discount from $100 = $90 max price
        ),
      );

      // Price at $88 meets 10% discount from $100
      final meetsDiscount = service.evaluateDividend(
        symbol: 'MSFT',
        currentPrice: 88.0,
        costBasis: 100.0,
      );
      expect(meetsDiscount.shouldReinvest, true);
      expect(meetsDiscount.thresholdPrice, 90.0);

      // Price at $95 does not meet 10% discount
      final missesDiscount = service.evaluateDividend(
        symbol: 'MSFT',
        currentPrice: 95.0,
        costBasis: 100.0,
      );
      expect(missesDiscount.shouldReinvest, false);
      expect(missesDiscount.reason, contains('Dividend held in cash'));
    });
  });

  group('AutomatedDripService Execution & History Tests', () {
    test('executeReinvestment executes and logs transaction when eligible',
        () async {
      final service = AutomatedDripService(
        initialConfig: AutomatedDripConfig(
          enabled: true,
          defaultMode: DripThresholdMode.belowCostBasis,
        ),
      );

      final instrument = Instrument.forSymbol('KO');
      final account = Account.fromJson({
        'url': 'https://api.robinhood.com/accounts/acc_1/',
        'account_number': 'ACC123',
        'type': 'margin',
        'portfolio_cash': '1000',
        'buying_power': '1000',
        'option_level': '3',
        'cash_held_for_options_collateral': '0',
        'unsettled_debit': '0',
        'settled_amount_borrowed': '0',
      });
      final user = BrokerageUser.fromJson({
        'source': 'Robinhood',
        'userName': 'user_1',
      });

      final dividend = {'amount': '60.00'};
      final currentPrice = 60.00;
      final costBasis = 65.00;

      final tx = await service.executeReinvestment(
        brokerageUser: user,
        account: account,
        instrument: instrument,
        dividend: dividend,
        currentPrice: currentPrice,
        costBasis: costBasis,
      );

      expect(tx.status, 'executed');
      expect(tx.symbol, 'KO');
      expect(tx.dividendAmount, 60.00);
      expect(tx.sharesPurchased, 1.0);
      expect(service.config.transactions.length, 1);
      expect(service.config.transactions.first.id, tx.id);

      // Check notification creation
      final notif = service.createNotificationForTransaction(tx);
      expect(notif.category, 'dividends');
      expect(notif.title, contains('DRIP Reinvested: KO'));
    });

    test('executeReinvestment holds cash and logs unmet threshold', () async {
      final service = AutomatedDripService(
        initialConfig: AutomatedDripConfig(
          enabled: true,
          defaultMode: DripThresholdMode.belowCostBasis,
        ),
      );

      final instrument = Instrument.forSymbol('PEP');
      final account = Account.fromJson({
        'url': 'https://api.robinhood.com/accounts/acc_2/',
        'account_number': 'ACC456',
        'type': 'margin',
        'portfolio_cash': '1000',
        'buying_power': '1000',
        'option_level': '3',
        'cash_held_for_options_collateral': '0',
        'unsettled_debit': '0',
        'settled_amount_borrowed': '0',
      });
      final user = BrokerageUser.fromJson({
        'source': 'Robinhood',
        'userName': 'user_2',
      });

      final dividend = {'amount': '45.00'};
      // Current price is $170, cost basis was $160 (price is too high!)
      final currentPrice = 170.00;
      final costBasis = 160.00;

      final tx = await service.executeReinvestment(
        brokerageUser: user,
        account: account,
        instrument: instrument,
        dividend: dividend,
        currentPrice: currentPrice,
        costBasis: costBasis,
      );

      expect(tx.status, 'threshold_unmet');
      expect(tx.sharesPurchased, 0.0);
      expect(service.config.transactions.length, 1);

      // Notification tells user dividend was kept as cash
      final notif = service.createNotificationForTransaction(tx);
      expect(notif.title, contains('DRIP Paused: PEP'));
      expect(notif.message, contains('credited to cash'));
    });

    test('clearHistory removes all transaction logs', () async {
      final service = AutomatedDripService(
        initialConfig: AutomatedDripConfig(
          enabled: true,
          transactions: [
            DripTransaction(
              id: 'tx_1',
              timestamp: DateTime.now(),
              symbol: 'T',
              dividendAmount: 10.0,
              executionPrice: 15.0,
              sharesPurchased: 0.66,
              status: 'executed',
            ),
          ],
        ),
      );

      expect(service.config.transactions.length, 1);
      await service.clearHistory();
      expect(service.config.transactions.isEmpty, true);
    });
  });

  group('PortfolioAlertService DRIP Integration Tests', () {
    test('Surfaces positive alert when DRIP is executed', () {
      final config = AutomatedDripConfig(
        enabled: true,
        transactions: [
          DripTransaction(
            id: 'tx_alert_1',
            timestamp: DateTime.now(),
            symbol: 'JNJ',
            dividendAmount: 50.0,
            executionPrice: 150.0,
            sharesPurchased: 0.333,
            status: 'executed',
          ),
        ],
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        automatedDripConfig: config,
      );

      final dripAlert = alerts.firstWhere(
        (a) => a.id.startsWith('drip_exec_'),
        orElse: () => throw Exception('DRIP alert not found'),
      );

      expect(dripAlert.severity, PortfolioAlertSeverity.positive);
      expect(dripAlert.title, contains('DRIP Reinvested: JNJ'));
      expect(dripAlert.metric, '\$50.00');
    });

    test('Surfaces info alert when dividend is held in cash', () {
      final config = AutomatedDripConfig(
        enabled: true,
        transactions: [
          DripTransaction(
            id: 'tx_alert_2',
            timestamp: DateTime.now(),
            symbol: 'PG',
            dividendAmount: 30.0,
            executionPrice: 165.0,
            thresholdPrice: 155.0,
            sharesPurchased: 0.0,
            status: 'threshold_unmet',
          ),
        ],
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        automatedDripConfig: config,
      );

      final heldAlert = alerts.firstWhere(
        (a) => a.id.startsWith('drip_held_'),
        orElse: () => throw Exception('DRIP held alert not found'),
      );

      expect(heldAlert.severity, PortfolioAlertSeverity.info);
      expect(heldAlert.title, contains('DRIP Paused: PG'));
      expect(heldAlert.detail, contains('held in cash'));
    });

    test('No alerts when DRIP is disabled', () {
      final config = AutomatedDripConfig(
        enabled: false,
        transactions: [
          DripTransaction(
            id: 'tx_alert_3',
            timestamp: DateTime.now(),
            symbol: 'PG',
            dividendAmount: 30.0,
            executionPrice: 165.0,
            sharesPurchased: 0.2,
            status: 'executed',
          ),
        ],
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        automatedDripConfig: config,
      );

      expect(alerts.any((a) => a.id.contains('drip')), false);
    });
  });
}

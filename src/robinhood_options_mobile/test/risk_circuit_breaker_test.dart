import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/risk_circuit_breaker_config.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';
import 'package:robinhood_options_mobile/services/risk_circuit_breaker_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RiskCircuitBreakerConfig Model Tests', () {
    test('Default values are initialized correctly', () {
      final config = RiskCircuitBreakerConfig();
      expect(config.enabled, false);
      expect(config.maxDailyLossAmount, isNull);
      expect(config.maxDailyLossPercent, 3.0);
      expect(config.maxDrawdownPercent, 10.0);
      expect(config.maxConsecutiveLosses, 3);
      expect(config.minMarginBufferPercent, 15.0);
      expect(config.coolingOffDurationMinutes, 60);
      expect(config.isTripped, false);
      expect(config.currentConsecutiveLosses, 0);
      expect(config.isInCoolingOff, false);
      expect(config.isExecutionBlocked, false);
    });

    test('Serialization and deserialization works correctly', () {
      final now = DateTime.now();
      final coolingUntil = now.add(const Duration(minutes: 45));

      final config = RiskCircuitBreakerConfig(
        enabled: true,
        maxDailyLossAmount: 750.0,
        maxDailyLossPercent: 4.5,
        maxDrawdownPercent: 12.0,
        maxConsecutiveLosses: 4,
        minMarginBufferPercent: 20.0,
        coolingOffDurationMinutes: 45,
        coolingOffUntil: coolingUntil,
        isTripped: true,
        tripReason: 'Daily loss limit reached',
        trippedAt: now,
        peakPortfolioEquity: 25000.0,
        currentConsecutiveLosses: 2,
      );

      final json = config.toJson();
      final deserialized = RiskCircuitBreakerConfig.fromJson(json);

      expect(deserialized.enabled, true);
      expect(deserialized.maxDailyLossAmount, 750.0);
      expect(deserialized.maxDailyLossPercent, 4.5);
      expect(deserialized.maxDrawdownPercent, 12.0);
      expect(deserialized.maxConsecutiveLosses, 4);
      expect(deserialized.minMarginBufferPercent, 20.0);
      expect(deserialized.coolingOffDurationMinutes, 45);
      expect(deserialized.isTripped, true);
      expect(deserialized.tripReason, 'Daily loss limit reached');
      expect(deserialized.peakPortfolioEquity, 25000.0);
      expect(deserialized.currentConsecutiveLosses, 2);
      expect(deserialized.isInCoolingOff, true);
      expect(deserialized.isExecutionBlocked, true);
    });

    test('copyWith updates specified fields only', () {
      final config = RiskCircuitBreakerConfig(enabled: false, maxDailyLossAmount: 500);
      final updated = config.copyWith(enabled: true, maxDailyLossAmount: 1000);

      expect(updated.enabled, true);
      expect(updated.maxDailyLossAmount, 1000);
      expect(updated.maxDailyLossPercent, config.maxDailyLossPercent);
    });
  });

  group('RiskCircuitBreakerService Guardrail Tests', () {
    test('Allows execution when circuit breaker is disabled', () {
      final service = RiskCircuitBreakerService(
        initialConfig: RiskCircuitBreakerConfig(
          enabled: false,
          maxDailyLossAmount: 100.0,
        ),
      );

      final result = service.evaluateRisk(
        equity: 5000.0,
        dayPnL: -500.0, // Exceeds limit, but disabled
        dayPnLPercent: -10.0,
      );

      expect(result.allowed, true);
    });

    test('Blocks execution when max daily dollar loss is breached', () {
      final service = RiskCircuitBreakerService(
        initialConfig: RiskCircuitBreakerConfig(
          enabled: true,
          maxDailyLossAmount: 500.0,
          maxDailyLossPercent: null, // Test dollar amount specifically
        ),
      );

      // Safe trade
      var result = service.evaluateRisk(
        equity: 10000.0,
        dayPnL: -450.0,
        dayPnLPercent: -4.5,
      );
      expect(result.allowed, true);

      // Breached trade
      result = service.evaluateRisk(
        equity: 10000.0,
        dayPnL: -500.50,
        dayPnLPercent: -5.0,
      );
      expect(result.allowed, false);
      expect(result.triggerType, 'daily_loss_amount');
      expect(result.isCoolingOff, true);
      expect(service.config.isTripped, true);
      expect(service.config.tripReason, contains('Daily loss limit reached'));
    });

    test('Blocks execution when max daily percentage loss is breached', () {
      final service = RiskCircuitBreakerService(
        initialConfig: RiskCircuitBreakerConfig(
          enabled: true,
          maxDailyLossAmount: null,
          maxDailyLossPercent: 3.0,
        ),
      );

      // Safe percent
      var result = service.evaluateRisk(
        equity: 10000.0,
        dayPnL: -250.0,
        dayPnLPercent: -2.5,
      );
      expect(result.allowed, true);

      // Breached percent
      result = service.evaluateRisk(
        equity: 10000.0,
        dayPnL: -350.0,
        dayPnLPercent: -3.5,
      );
      expect(result.allowed, false);
      expect(result.triggerType, 'daily_loss_percent');
      expect(service.config.isTripped, true);
    });

    test('Blocks execution when peak-to-trough drawdown exceeds threshold', () {
      final service = RiskCircuitBreakerService(
        initialConfig: RiskCircuitBreakerConfig(
          enabled: true,
          maxDailyLossAmount: null,
          maxDailyLossPercent: null,
          maxDrawdownPercent: 10.0,
          peakPortfolioEquity: 20000.0,
        ),
      );

      // 8% drawdown: Safe
      var result = service.evaluateRisk(
        equity: 18400.0,
        dayPnL: 0.0,
        dayPnLPercent: 0.0,
      );
      expect(result.allowed, true);

      // 12% drawdown ($20,000 -> $17,600): Breached
      result = service.evaluateRisk(
        equity: 17600.0,
        dayPnL: 0.0,
        dayPnLPercent: 0.0,
      );
      expect(result.allowed, false);
      expect(result.triggerType, 'drawdown');
      expect(service.config.isTripped, true);
      expect(service.config.tripReason, contains('Maximum portfolio drawdown reached'));
    });

    test('Blocks execution when margin buffer falls below required threshold', () {
      final service = RiskCircuitBreakerService(
        initialConfig: RiskCircuitBreakerConfig(
          enabled: true,
          maxDailyLossAmount: null,
          maxDailyLossPercent: null,
          minMarginBufferPercent: 15.0,
        ),
      );

      // Margin buffer safe (20%)
      var result = service.evaluateRisk(
        equity: 10000.0,
        dayPnL: 0.0,
        dayPnLPercent: 0.0,
        marginBufferPercent: 20.0,
      );
      expect(result.allowed, true);

      // Margin buffer critical (10%)
      result = service.evaluateRisk(
        equity: 10000.0,
        dayPnL: 0.0,
        dayPnLPercent: 0.0,
        marginBufferPercent: 10.0,
      );
      expect(result.allowed, false);
      expect(result.triggerType, 'margin_buffer');
      expect(result.reason, contains('Margin buffer too low'));
    });

    test('Tracks consecutive losses and trips when threshold reached', () {
      final service = RiskCircuitBreakerService(
        initialConfig: RiskCircuitBreakerConfig(
          enabled: true,
          maxConsecutiveLosses: 3,
        ),
      );

      service.recordTradeOutcome(isWin: false, pnl: -100);
      expect(service.config.currentConsecutiveLosses, 1);
      expect(service.config.isTripped, false);

      service.recordTradeOutcome(isWin: false, pnl: -50);
      expect(service.config.currentConsecutiveLosses, 2);
      expect(service.config.isTripped, false);

      // 3rd consecutive loss trips breaker
      service.recordTradeOutcome(isWin: false, pnl: -75);
      expect(service.config.currentConsecutiveLosses, 3);
      expect(service.config.isTripped, true);
      expect(service.config.tripReason, contains('Consecutive loss limit reached'));
    });

    test('Winning trade resets consecutive losses count', () {
      final service = RiskCircuitBreakerService(
        initialConfig: RiskCircuitBreakerConfig(
          enabled: true,
          maxConsecutiveLosses: 3,
        ),
      );

      service.recordTradeOutcome(isWin: false, pnl: -100);
      service.recordTradeOutcome(isWin: false, pnl: -50);
      expect(service.config.currentConsecutiveLosses, 2);

      // Win resets streak
      service.recordTradeOutcome(isWin: true, pnl: 200);
      expect(service.config.currentConsecutiveLosses, 0);
      expect(service.config.isTripped, false);
    });

    test('Reset clears tripped state and lifts suspension', () async {
      final service = RiskCircuitBreakerService(
        initialConfig: RiskCircuitBreakerConfig(
          enabled: true,
          isTripped: true,
          tripReason: 'Test trip',
          coolingOffUntil: DateTime.now().add(const Duration(hours: 1)),
          currentConsecutiveLosses: 3,
        ),
      );

      expect(service.config.isExecutionBlocked, true);

      await service.resetCircuitBreaker();

      expect(service.config.isTripped, false);
      expect(service.config.tripReason, isNull);
      expect(service.config.coolingOffUntil, isNull);
      expect(service.config.currentConsecutiveLosses, 0);
      expect(service.config.isExecutionBlocked, false);
    });

    test('User model properly includes riskCircuitBreakerConfig in JSON', () {
      final user = User(
        name: 'Risk Tester',
        devices: [],
        dateCreated: DateTime.now(),
        brokerageUsers: [],
        riskCircuitBreakerConfig: RiskCircuitBreakerConfig(
          enabled: true,
          maxDailyLossAmount: 1000.0,
          maxConsecutiveLosses: 2,
        ),
      );

      final json = user.toJson();
      expect(json['riskCircuitBreakerConfig'], isNotNull);

      final userFromJson = User.fromJson(json);
      expect(userFromJson.riskCircuitBreakerConfig, isNotNull);
      expect(userFromJson.riskCircuitBreakerConfig!.enabled, true);
      expect(userFromJson.riskCircuitBreakerConfig!.maxDailyLossAmount, 1000.0);
      expect(userFromJson.riskCircuitBreakerConfig!.maxConsecutiveLosses, 2);
    });
  });

  group('PortfolioAlertService Circuit Breaker Tests', () {
    test('Surfaces critical alert when cooling off is active', () {
      final config = RiskCircuitBreakerConfig(
        enabled: true,
        coolingOffUntil: DateTime.now().add(const Duration(minutes: 25)),
        tripReason: 'Daily loss limit reached',
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        riskCircuitBreakerConfig: config,
      );

      final cbAlert = alerts.firstWhere((a) => a.id == 'risk-circuit-breaker-cooling-off');
      expect(cbAlert.severity, PortfolioAlertSeverity.critical);
      expect(cbAlert.title, contains('Trading Suspended'));
      expect(cbAlert.detail, contains('Daily loss limit reached'));
    });

    test('Surfaces critical alert when tripped without cooling off', () {
      final config = RiskCircuitBreakerConfig(
        enabled: true,
        isTripped: true,
        tripReason: 'Max drawdown reached',
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        riskCircuitBreakerConfig: config,
      );

      final cbAlert = alerts.firstWhere((a) => a.id == 'risk-circuit-breaker-tripped');
      expect(cbAlert.severity, PortfolioAlertSeverity.critical);
      expect(cbAlert.title, 'Circuit Breaker Tripped');
      expect(cbAlert.detail, 'Max drawdown reached');
    });

    test('Surfaces warning alert when daily loss approaches threshold', () {
      final config = RiskCircuitBreakerConfig(
        enabled: true,
        maxDailyLossAmount: 500.0,
      );

      // Loss of -$420 is 84% of $500 limit (> 80%)
      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        riskCircuitBreakerConfig: config,
        dayPnL: -420.0,
      );

      final cbAlert = alerts.firstWhere((a) => a.id == 'risk-circuit-breaker-near-daily-loss');
      expect(cbAlert.severity, PortfolioAlertSeverity.warning);
      expect(cbAlert.title, contains('Approaching Daily Loss Limit (84%)'));
      expect(cbAlert.metric, '-\$420');
    });

    test('Stays quiet when disabled or risk is within normal parameters', () {
      final config = RiskCircuitBreakerConfig(
        enabled: false,
        maxDailyLossAmount: 500.0,
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        riskCircuitBreakerConfig: config,
        dayPnL: -450.0,
      );

      expect(alerts.any((a) => a.id.startsWith('risk-circuit-breaker')), false);
    });
  });
}


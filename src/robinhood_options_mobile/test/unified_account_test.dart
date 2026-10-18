import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/portfolio.dart';
import 'package:robinhood_options_mobile/model/portfolio_alert.dart';
import 'package:robinhood_options_mobile/model/unified_account.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/services/portfolio_alert_service.dart';

void main() {
  group('MarginHealth Model', () {
    test('parses healthy status when buffer > 25%', () {
      final json = {
        'status': 'healthy',
        'margin_buffer': 14250.75,
        'margin_buffer_percentage': 0.42,
        'borrowed_amount': 5000.0,
        'margin_limit': 25000.0,
        'maintenance_requirement': 10500.0,
        'portfolio_equity': 24750.75,
        'leverage_ratio': 1.20,
        'margin_call_amount': 0.0,
      };

      final health = MarginHealth.fromJson(json);
      expect(health.status, MarginHealthStatus.healthy);
      expect(health.isHealthy, isTrue);
      expect(health.isWarning, isFalse);
      expect(health.isCritical, isFalse);
      expect(health.isMarginCall, isFalse);
      expect(health.isUnleveraged, isFalse);
      expect(health.displayStatus, 'Healthy');
      expect(health.marginBuffer, 14250.75);
      expect(health.marginBufferPercentage, 0.42);
      expect(health.borrowedAmount, 5000.0);
      expect(health.leverageRatio, 1.20);
    });

    test('normalizes whole percentage (42.0 -> 0.42)', () {
      final json = {
        'margin_buffer': 4200.0,
        'margin_buffer_percentage': 42.0,
        'borrowed_amount': 2000.0,
        'portfolio_equity': 10000.0,
      };

      final health = MarginHealth.fromJson(json);
      expect(health.marginBufferPercentage, 0.42);
      expect(health.status, MarginHealthStatus.healthy);
    });

    test('parses warning status when buffer between 10% and 25%', () {
      final json = {
        'margin_buffer': 1500.0,
        'margin_buffer_percentage': 0.15,
        'borrowed_amount': 5000.0,
        'portfolio_equity': 10000.0,
      };

      final health = MarginHealth.fromJson(json);
      expect(health.status, MarginHealthStatus.warning);
      expect(health.isWarning, isTrue);
      expect(health.displayStatus, 'Low Buffer');
    });

    test('parses critical status when buffer < 10%', () {
      final json = {
        'margin_buffer': 800.0,
        'margin_buffer_percentage': 0.08,
        'borrowed_amount': 8000.0,
        'portfolio_equity': 10000.0,
      };

      final health = MarginHealth.fromJson(json);
      expect(health.status, MarginHealthStatus.critical);
      expect(health.isCritical, isTrue);
      expect(health.displayStatus, 'Critical Buffer');
    });

    test('parses marginCall status when deficit exists', () {
      final json = {
        'status': 'margin_call',
        'margin_call_amount': 2500.0,
        'borrowed_amount': 15000.0,
        'portfolio_equity': 8000.0,
      };

      final health = MarginHealth.fromJson(json);
      expect(health.status, MarginHealthStatus.marginCall);
      expect(health.isMarginCall, isTrue);
      expect(health.displayStatus, 'Margin Call');
      expect(health.marginCallAmount, 2500.0);
    });

    test('parses unleveraged status when borrowed amount is zero', () {
      final json = {
        'borrowed_amount': 0.0,
        'portfolio_equity': 25000.0,
      };

      final health = MarginHealth.fromJson(json);
      expect(health.status, MarginHealthStatus.unleveraged);
      expect(health.isUnleveraged, isTrue);
      expect(health.displayStatus, 'Unleveraged');
    });
  });

  group('CollateralAllocations Model', () {
    test('parses multi-asset collateral holds from json', () {
      final json = {
        'total_collateral_held': 4000.0,
        'cash_held_for_options': 2500.0,
        'equity_held_for_options': 1500.0,
        'crypto_held_for_orders': 0.0,
        'pending_order_holds': 0.0,
      };

      final col = CollateralAllocations.fromJson(json);
      expect(col.totalCollateralHeld, 4000.0);
      expect(col.cashHeldForOptions, 2500.0);
      expect(col.equityHeldForOptions, 1500.0);
      expect(col.cryptoHeldForOrders, 0.0);
      expect(col.hasCollateralHolds, isTrue);
    });

    test('sums component holds if total is omitted', () {
      final json = {
        'cash_held_for_options': 1000.0,
        'equity_held_for_options': 500.0,
        'crypto_held_for_orders': 200.0,
        'pending_order_holds': 100.0,
      };

      final col = CollateralAllocations.fromJson(json);
      expect(col.totalCollateralHeld, 1800.0);
      expect(col.hasCollateralHolds, isTrue);
    });
  });

  group('UnifiedAccount Model', () {
    test('parses full unified account payload', () {
      final json = {
        'account_number': '5QR12345',
        'account_type': 'margin',
        'buying_power': 25000.0,
        'options_buying_power': 18500.0,
        'crypto_buying_power': 12000.0,
        'cash_available_for_withdrawal': 4500.0,
        'unsettled_funds': 250.0,
        'margin_health': {
          'status': 'healthy',
          'margin_buffer': 14250.75,
          'margin_buffer_percentage': 0.42,
          'borrowed_amount': 5000.0,
          'margin_limit': 25000.0,
          'maintenance_requirement': 10500.0,
          'portfolio_equity': 24750.75,
          'leverage_ratio': 1.20,
          'margin_call_amount': 0.0,
        },
        'collateral': {
          'total_collateral_held': 4000.0,
          'cash_held_for_options': 2500.0,
          'equity_held_for_options': 1500.0,
        },
        'day_trade_ratio': 0.25,
        'day_trade_buying_power': 35000.0,
      };

      final unified = UnifiedAccount.fromJson(json);
      expect(unified.accountNumber, '5QR12345');
      expect(unified.accountType, 'margin');
      expect(unified.isMarginAccount, isTrue);
      expect(unified.buyingPower, 25000.0);
      expect(unified.optionsBuyingPower, 18500.0);
      expect(unified.cryptoBuyingPower, 12000.0);
      expect(unified.cashAvailableForWithdrawal, 4500.0);
      expect(unified.unsettledFunds, 250.0);
      expect(unified.marginHealth.status, MarginHealthStatus.healthy);
      expect(unified.collateral.totalCollateralHeld, 4000.0);
      expect(unified.dayTradeRatio, 0.25);
      expect(unified.dayTradeBuyingPower, 35000.0);
    });

    test('unwraps results envelope', () {
      final json = {
        'results': [
          {
            'account_number': '5QR99999',
            'buying_power': 10000.0,
            'margin_health': {'borrowed_amount': 0.0},
          }
        ]
      };

      final unified = UnifiedAccount.fromJson(json);
      expect(unified.accountNumber, '5QR99999');
      expect(unified.buyingPower, 10000.0);
      expect(unified.marginHealth.isUnleveraged, isTrue);
    });

    test('constructs client fallback from Account and Portfolio', () {
      final account = Account(
        'https://api.robinhood.com/accounts/5QR11111/',
        5000.0,
        '5QR11111',
        'margin',
        15000.0,
        'tier_3',
        2000.0, // cash held for options
        0.0,
        4000.0, // settled amount borrowed
      );

      final portfolio = Portfolio(
        'https://api.robinhood.com/portfolios/5QR11111/',
        'https://api.robinhood.com/accounts/5QR11111/',
        DateTime(2020, 1, 1),
        20000.0, // market value
        24000.0, // equity
        null, null, null, null, null, null,
        null,
        18000.0, // excess maintenance (buffer)
        null, null, null, null, null, null,
        3000.0, // withdrawable amount
        null, null, null,
      );

      final unified =
          UnifiedAccount.fromAccountAndPortfolio(account, portfolio);
      expect(unified.accountNumber, '5QR11111');
      expect(unified.buyingPower, 15000.0);
      expect(unified.optionsBuyingPower, 13000.0); // 15000 - 2000 collateral
      expect(unified.collateral.cashHeldForOptions, 2000.0);
      expect(unified.cashAvailableForWithdrawal, 3000.0);
      expect(unified.marginHealth.borrowedAmount, 4000.0);
      expect(unified.marginHealth.marginBuffer, 18000.0);
      expect(unified.marginHealth.status, MarginHealthStatus.healthy);
    });
  });

  group('DemoService Unified Account Contract', () {
    test('returns realistic mock unified account payload', () async {
      final service = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demouser',
        'credentials',
        null,
      );

      final raw = await service.getUnifiedAccount(user);
      expect(raw, isNotNull);

      final unified = UnifiedAccount.fromJson(raw);
      expect(unified.accountNumber, '5QR12345');
      expect(unified.buyingPower, 25000.0);
      expect(unified.optionsBuyingPower, 18500.0);
      expect(unified.cryptoBuyingPower, 12000.0);
      expect(unified.marginHealth.isHealthy, isTrue);
      expect(unified.marginHealth.marginBuffer, 14250.75);
      expect(unified.collateral.totalCollateralHeld, 4000.0);
    });

    test('parses real Robinhood phoenix/accounts/unified payload correctly',
        () {
      final json = {
        "account_buying_power": {
          "amount": "53408.5104",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "cash_available_from_instant_deposits": {
          "amount": "0",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "cash_held_for_currency_orders": {
          "amount": "0",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "cash_held_for_dividends": {
          "amount": "0",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "cash_held_for_equity_orders": {
          "amount": "0",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "cash_held_for_options_collateral": {
          "amount": "0",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "cash_held_for_orders": {
          "amount": "0",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "cash_held_for_restrictions": {
          "amount": "0",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "crypto": {
          "equity": {
            "amount": "4739.78",
            "currency_code": "USD",
            "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
          },
          "market_value": {
            "amount": "4739.78",
            "currency_code": "USD",
            "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
          },
          "opened_at": "2018-12-07T01:25:13.512301Z"
        },
        "crypto_buying_power": {
          "amount": "26704.2552",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "equities": {
          "active_subscription_id": "ed9af327-ff97-56af-8172-0731f1afc505",
          "apex_account_number": "5QR24141",
          "available_margin": null,
          "equity": {
            "amount": "50945.027189",
            "currency_code": "USD",
            "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
          },
          "margin_maintenance": {
            "amount": "17617.024289",
            "currency_code": "USD",
            "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
          },
          "market_value": {
            "amount": "43870.977189",
            "currency_code": "USD",
            "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
          },
          "opened_at": "2015-02-12T22:41:50.744964Z",
          "rhs_account_number": "101241412",
          "total_margin": {
            "amount": "49807.6204",
            "currency_code": "USD",
            "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
          }
        },
        "extended_hours_portfolio_equity": {
          "amount": "55684.807189",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "instant_allocated": {
          "amount": "0",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "levered_amount": {
          "amount": "0",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "near_margin_call": false,
        "options_buying_power": {
          "amount": "26704.2552",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "portfolio_equity": {
          "amount": "55684.807189",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "portfolio_previous_close": {
          "amount": "55151.864035",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "previous_close": {
          "amount": "55151.864035",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "regular_hours_portfolio_equity": {
          "amount": "55570.113449",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "total_equity": {
          "amount": "55684.807189",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "total_extended_hours_equity": {
          "amount": "55684.807189",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "total_extended_hours_market_value": {
          "amount": "48610.757189",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "total_market_value": {
          "amount": "48610.757189",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "total_regular_hours_equity": {
          "amount": "55570.113449",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "total_regular_hours_market_value": {
          "amount": "48638.313449",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "uninvested_cash": {
          "amount": "7074.05",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "withdrawable_cash": {
          "amount": "5336.7128",
          "currency_code": "USD",
          "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
        },
        "margin_health": {
          "margin_health_state": "healthy",
          "margin_buffer": "1.0000",
          "margin_buffer_amount": {
            "amount": "51915.157189",
            "currency_code": "USD",
            "currency_id": "1072fc76-1862-41ab-82c2-485837590762"
          }
        },
        "buying_power_display_currency": null
      };

      final unified = UnifiedAccount.fromJson(json);
      expect(unified.accountNumber, '101241412');
      expect(unified.buyingPower, closeTo(53408.51, 0.01));
      expect(unified.optionsBuyingPower, closeTo(26704.25, 0.01));
      expect(unified.cryptoBuyingPower, closeTo(26704.25, 0.01));
      expect(unified.cashAvailableForWithdrawal, closeTo(5336.71, 0.01));
      expect(unified.uninvestedCash, closeTo(7074.05, 0.01));
      expect(unified.totalEquity, closeTo(55684.81, 0.01));
      expect(unified.cryptoEquity, closeTo(4739.78, 0.01));
      expect(unified.marginHealth.status, MarginHealthStatus.healthy);
      expect(unified.marginHealth.marginBuffer, closeTo(51915.16, 0.01));
      expect(unified.marginHealth.marginBufferPercentage, 1.0);
      expect(
          unified.marginHealth.maintenanceRequirement, closeTo(17617.02, 0.01));
      expect(unified.marginHealth.marginLimit, closeTo(49807.62, 0.01));
      expect(unified.collateral.totalCollateralHeld, 0.0);
    });
  });

  group('PortfolioAlertService Margin Health Alerts', () {
    test('triggers critical alert on active margin call deficit', () {
      final unified = UnifiedAccount(
        accountNumber: '5QR12345',
        marginHealth: const MarginHealth(
          status: MarginHealthStatus.marginCall,
          marginCallAmount: 3500.0,
          borrowedAmount: 10000.0,
        ),
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        unifiedAccount: unified,
      );

      final callAlert = alerts.firstWhere((a) => a.id == 'margin-call-deficit');
      expect(callAlert.severity, PortfolioAlertSeverity.critical);
      expect(callAlert.title, contains('Margin call active'));
      expect(callAlert.target, PortfolioAlertTarget.risk);
    });

    test('triggers critical alert on critical margin buffer (<10%)', () {
      final unified = UnifiedAccount(
        accountNumber: '5QR12345',
        marginHealth: const MarginHealth(
          status: MarginHealthStatus.critical,
          marginBuffer: 800.0,
          marginBufferPercentage: 0.08,
          borrowedAmount: 6000.0,
        ),
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        unifiedAccount: unified,
      );

      final critAlert =
          alerts.firstWhere((a) => a.id == 'margin-buffer-critical');
      expect(critAlert.severity, PortfolioAlertSeverity.critical);
      expect(critAlert.title, contains('Critical margin buffer'));
      expect(critAlert.detail, contains('\$800'));
    });

    test('triggers warning alert on low margin buffer (<25%)', () {
      final unified = UnifiedAccount(
        accountNumber: '5QR12345',
        marginHealth: const MarginHealth(
          status: MarginHealthStatus.warning,
          marginBuffer: 1800.0,
          marginBufferPercentage: 0.18,
          borrowedAmount: 5000.0,
        ),
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        unifiedAccount: unified,
      );

      final warnAlert =
          alerts.firstWhere((a) => a.id == 'margin-buffer-warning');
      expect(warnAlert.severity, PortfolioAlertSeverity.warning);
      expect(warnAlert.title, contains('Low margin buffer'));
    });

    test('no margin alerts generated for unleveraged accounts', () {
      final unified = UnifiedAccount(
        accountNumber: '5QR12345',
        marginHealth: const MarginHealth(
          status: MarginHealthStatus.unleveraged,
          borrowedAmount: 0.0,
        ),
      );

      final alerts = PortfolioAlertService.buildAlerts(
        instrumentPositions: [],
        optionPositions: [],
        unifiedAccount: unified,
      );

      expect(alerts.any((a) => a.id.startsWith('margin-')), isFalse);
    });
  });
}

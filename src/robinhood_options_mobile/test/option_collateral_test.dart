import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/option_collateral.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('OptionCollateralCash Model Tests', () {
    test('parses normal cash collateral correctly', () {
      final json = {
        'amount': '3250.5000',
        'direction': 'debit',
        'infinite': false,
      };

      final cash = OptionCollateralCash.fromJson(json);
      expect(cash.amount, 3250.5);
      expect(cash.direction, 'debit');
      expect(cash.infinite, isFalse);
      expect(cash.hasCollateral, isTrue);
      expect(cash.formattedAmount, contains('3,250.50'));
    });

    test('parses infinite cash collateral correctly', () {
      final json = {
        'amount': '0.0000',
        'direction': 'debit',
        'infinite': true,
      };

      final cash = OptionCollateralCash.fromJson(json);
      expect(cash.infinite, isTrue);
      expect(cash.hasCollateral, isTrue);
      expect(cash.formattedAmount, 'Unlimited');
    });

    test('handles zero or invalid json gracefully', () {
      final cash = OptionCollateralCash.fromJson(null);
      expect(cash.amount, 0.0);
      expect(cash.hasCollateral, isFalse);
    });

    test('roundtrips to and from json', () {
      const original = OptionCollateralCash(
        amount: 1500.0,
        direction: 'credit',
        infinite: false,
      );
      final json = original.toJson();
      final parsed = OptionCollateralCash.fromJson(json);

      expect(parsed.amount, original.amount);
      expect(parsed.direction, original.direction);
      expect(parsed.infinite, original.infinite);
    });
  });

  group('OptionCollateralEquity Model Tests', () {
    test('parses equity shares collateral correctly', () {
      final json = {
        'quantity': '100.00000000',
        'direction': 'debit',
        'instrument':
            'https://api.robinhood.com/instruments/943c5009-a0bb-4665-8cf4-a95dab5874e4/',
        'symbol': 'GOOG',
      };

      final equity = OptionCollateralEquity.fromJson(json);
      expect(equity.symbol, 'GOOG');
      expect(equity.quantity, 100.0);
      expect(equity.direction, 'debit');
      expect(equity.hasCollateral, isTrue);
      expect(equity.formattedQuantity, '100');
    });

    test('handles zero shares correctly', () {
      final json = {
        'quantity': '0E-8',
        'uncovered_shares': '0E-8',
        'direction': 'debit',
        'symbol': 'AAPL',
      };

      final equity = OptionCollateralEquity.fromJson(json);
      expect(equity.quantity, 0.0);
      expect(equity.uncoveredShares, 0.0);
      expect(equity.hasCollateral, isFalse);
      expect(equity.formattedQuantity, '0');
      expect(equity.formattedUncoveredShares, '0');
    });

    test('parses uncovered shares correctly', () {
      final json = {
        'quantity': '100.00000000',
        'uncovered_shares': '25.00000000',
        'direction': 'debit',
        'symbol': 'AMZN',
      };

      final equity = OptionCollateralEquity.fromJson(json);
      expect(equity.symbol, 'AMZN');
      expect(equity.quantity, 100.0);
      expect(equity.uncoveredShares, 25.0);
      expect(equity.hasCollateral, isTrue);
      expect(equity.formattedQuantity, '100');
      expect(equity.formattedUncoveredShares, '25');
    });
  });

  group('OptionCollateralBreakdown Model Tests', () {
    test('filters activeEquities and ignores zero-share entries', () {
      final breakdown = OptionCollateralBreakdown.fromJson({
        'cash': {'amount': '0.0000', 'direction': 'debit', 'infinite': false},
        'equities': [
          {
            'quantity': '0E-8',
            'uncovered_shares': '0E-8',
            'symbol': 'AMZN',
          },
          {
            'quantity': '100.00000000',
            'uncovered_shares': '0E-8',
            'symbol': 'AAPL',
          }
        ]
      });

      expect(breakdown.equities.length, 2);
      expect(breakdown.activeEquities.length, 1);
      expect(breakdown.activeEquities.first.symbol, 'AAPL');
      expect(breakdown.totalShares, 100.0);
      expect(breakdown.hasCollateral, isTrue);
    });
  });

  group('OptionChainCollateral Model Tests', () {
    test(
        'parses real Robinhood API zero-collateral response with scientific notation and account_number',
        () {
      final json = {
        "account_number": "5QR24141",
        "collateral": {
          "cash": {"amount": "0.0000", "direction": "debit", "infinite": false},
          "equities": [
            {
              "quantity": "0E-8",
              "direction": "debit",
              "uncovered_shares": "0E-8",
              "instrument":
                  "https://api.robinhood.com/instruments/c0bb3aec-bd1e-471e-a4f0-ca011cbec711/",
              "symbol": "AMZN"
            }
          ]
        },
        "collateral_held_for_orders": {
          "cash": {"amount": "0.0000", "direction": "debit", "infinite": false},
          "equities": [
            {
              "quantity": "0E-8",
              "direction": "debit",
              "uncovered_shares": "0E-8",
              "instrument":
                  "https://api.robinhood.com/instruments/c0bb3aec-bd1e-471e-a4f0-ca011cbec711/",
              "symbol": "AMZN"
            }
          ]
        }
      };

      final collateral =
          OptionChainCollateral.fromJson('chain_amzn', 'fallback_acct', json);

      expect(collateral.chainId, 'chain_amzn');
      expect(collateral.accountNumber, '5QR24141');
      expect(collateral.totalCashLocked, 0.0);
      expect(collateral.totalSharesLocked, 0.0);
      expect(collateral.hasAnyCollateral, isFalse);
      expect(collateral.collateral.hasCollateral, isFalse);
      expect(collateral.collateral.activeEquities, isEmpty);
      expect(collateral.collateralHeldForOrders.hasCollateral, isFalse);
      expect(collateral.collateralHeldForOrders.activeEquities, isEmpty);
      expect(collateral.collateral.equities.first.uncoveredShares, 0.0);
    });

    test('parses full options chain collateral payload', () {
      final json = {
        'collateral': {
          'cash': {
            'amount': '2500.0000',
            'direction': 'debit',
            'infinite': false,
          },
          'equities': [
            {
              'quantity': '100.00000000',
              'direction': 'debit',
              'symbol': 'TSLA',
              'instrument': 'https://api.robinhood.com/instruments/tsla/',
            }
          ]
        },
        'collateral_held_for_orders': {
          'cash': {
            'amount': '500.0000',
            'direction': 'debit',
            'infinite': false,
          },
          'equities': [
            {
              'quantity': '50.00000000',
              'direction': 'debit',
              'symbol': 'TSLA',
            }
          ]
        }
      };

      final collateral = OptionChainCollateral.fromJson(
        'chain_123',
        'ACCT_456',
        json,
      );

      expect(collateral.chainId, 'chain_123');
      expect(collateral.accountNumber, 'ACCT_456');
      expect(collateral.collateral.cash.amount, 2500.0);
      expect(collateral.collateralHeldForOrders.cash.amount, 500.0);
      expect(collateral.totalCashLocked, 3000.0);
      expect(collateral.totalSharesLocked, 150.0);
      expect(collateral.hasAnyCollateral, isTrue);
      expect(collateral.formattedTotalCash, contains('3,000.00'));
      expect(collateral.formattedTotalShares, '150');
    });

    test('handles empty collateral json correctly', () {
      final collateral = OptionChainCollateral.fromJson(
        'chain_empty',
        'ACCT_EMPTY',
        {},
      );

      expect(collateral.totalCashLocked, 0.0);
      expect(collateral.totalSharesLocked, 0.0);
      expect(collateral.hasAnyCollateral, isFalse);
    });
  });

  group('OptionUpgradeStatus Model Tests', () {
    test('parses Level 2 account needing Level 3 upgrade', () {
      final json = {
        'should_show_options_upgrade': true,
        'option_level': 'option_level_2',
        'current_tier': 2,
        'target_tier': 3,
        'upgrade_title': 'Upgrade to Options Level 3',
        'upgrade_subtitle': 'Unlock multi-leg strategies',
        'upgrade_url': 'https://robinhood.com/account/options/upgrade',
        'is_eligible': true,
        'requirements': [
          'Margin account enabled',
        ],
        'features': [
          'Credit & debit spreads',
          'Iron condors',
        ],
      };

      final status = OptionUpgradeStatus.fromJson(json);
      expect(status.shouldShowUpgrade, isTrue);
      expect(status.currentTier, 2);
      expect(status.targetTier, 3);
      expect(status.title, 'Upgrade to Options Level 3');
      expect(status.isEligible, isTrue);
      expect(status.requirements.length, 1);
      expect(status.tierFeatures.length, 2);
      expect(status.tierBadgeLabel, 'Level 2');
    });

    test('parses Level 3 account with full privileges active', () {
      final json = {
        'should_show_options_upgrade': false,
        'option_level': 'option_level_3',
        'current_tier': 3,
        'target_tier': 3,
        'upgrade_title': 'Level 3 Active',
      };

      final status = OptionUpgradeStatus.fromJson(json);
      expect(status.shouldShowUpgrade, isFalse);
      expect(status.currentTier, 3);
      expect(status.tierBadgeLabel, 'Level 3');
    });

    test('generates sensible defaults when json is null', () {
      final status = OptionUpgradeStatus.fromJson(null,
          defaultAccountLevel: 'option_level_2');
      expect(status.currentTier, 2);
      expect(status.targetTier, 3);
      expect(status.shouldShowUpgrade, isTrue);
      expect(status.tierFeatures, isNotEmpty);
      expect(status.requirements, isNotEmpty);
    });
  });

  group('DemoService Collateral & Upgrade Integration Tests', () {
    test('returns demo option chain collateral with cash and equity', () async {
      final demoService = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'test_user',
        null,
        null,
      );

      final result = await demoService.getOptionChainCollateral(
        user,
        'chain_goog',
        'demo_acct',
      );

      expect(result, isNotNull);
      final model = OptionChainCollateral.fromJson(
        'chain_goog',
        'demo_acct',
        result,
      );

      expect(model.totalCashLocked, 3900.0);
      expect(model.totalSharesLocked, 100.0);
      expect(model.collateral.equities.first.symbol, 'GOOG');
      expect(model.hasAnyCollateral, isTrue);
    });

    test('returns demo options upgrade status', () async {
      final demoService = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'test_user',
        null,
        null,
      );

      final result =
          await demoService.getOptionsUpgradeStatus(user, 'demo_acct');
      expect(result, isNotNull);

      final status = OptionUpgradeStatus.fromJson(result);
      expect(status.shouldShowUpgrade, isTrue);
      expect(status.currentTier, 2);
      expect(status.targetTier, 3);
      expect(status.tierFeatures, contains('Multi-leg debit & credit spreads'));
    });
  });
}

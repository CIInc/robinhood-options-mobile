import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_buying_power.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('InstrumentBuyingPower Model Tests', () {
    test('parses standard marginable instrument buying power correctly', () {
      final now = DateTime.now();
      final json = {
        'account_number': '5QR12345',
        'instrument_id': 'inst_aapl_123',
        'buying_power': '41505.26',
        'short_buying_power': '20752.63',
        'cash_only': false,
        'margin_rate': '0.50',
        'maintenance_margin_rate': '0.30',
        'max_shares': '350.0',
        'max_short_shares': '175.0',
        'is_marginable': true,
        'leverage_ratio': '2.0',
        'updated_at': now.toIso8601String(),
      };

      final bp = InstrumentBuyingPower.fromJson('inst_aapl_123', json);

      expect(bp.instrumentId, 'inst_aapl_123');
      expect(bp.accountNumber, '5QR12345');
      expect(bp.buyingPower, 41505.26);
      expect(bp.shortBuyingPower, 20752.63);
      expect(bp.cashOnly, isFalse);
      expect(bp.isMarginable, isTrue);
      expect(bp.marginRate, 0.50);
      expect(bp.maintenanceMarginRate, 0.30);
      expect(bp.maxShares, 350.0);
      expect(bp.maxShortShares, 175.0);
      expect(bp.leverageRatio, 2.0);
      expect(bp.formattedBuyingPower, contains('41,505.26'));
      expect(bp.formattedShortBuyingPower, contains('20,752.63'));
      expect(bp.marginPercentage, '50%');
      expect(bp.maintenanceMarginPercentage, '30%');
      expect(bp.marginStatusLabel, '50% Initial Margin');
      expect(bp.hasShortCapacity, isTrue);
    });

    test('parses 100% cash-only / non-marginable instrument correctly', () {
      final json = {
        'account_number': '5QR12345',
        'instrument_id': 'inst_gme_456',
        'buying_power': 10000.0,
        'short_buying_power': 0.0,
        'cash_only': true,
        'margin_rate': 1.0,
        'maintenance_margin_rate': 1.0,
        'max_shares': 50.0,
        'max_short_shares': 0.0,
        'is_marginable': false,
      };

      final bp = InstrumentBuyingPower.fromJson('inst_gme_456', json);

      expect(bp.cashOnly, isTrue);
      expect(bp.isMarginable, isFalse);
      expect(bp.marginRate, 1.0);
      expect(bp.marginStatusLabel, '100% Cash Required');
      expect(bp.hasShortCapacity, isFalse);
    });

    test('normalizes percentage margin rates over 1.0 (e.g. 50.0 -> 0.50)', () {
      final json = {
        'initial_margin_rate': '50.0',
        'maintenance_margin_rate': '35.0',
        'buying_power': '5000',
      };

      final bp = InstrumentBuyingPower.fromJson('inst_test', json);
      expect(bp.marginRate, 0.50);
      expect(bp.maintenanceMarginRate, 0.35);
      expect(bp.marginPercentage, '50%');
      expect(bp.maintenanceMarginPercentage, '35%');
    });

    test('handles empty or non-map json gracefully', () {
      final bp = InstrumentBuyingPower.fromJson('inst_empty', null);
      expect(bp.instrumentId, 'inst_empty');
      expect(bp.buyingPower, 0.0);
      expect(bp.shortBuyingPower, isNull);
    });

    test('roundtrips to and from json', () {
      final original = InstrumentBuyingPower(
        instrumentId: 'inst_rt',
        accountNumber: '5QR999',
        buyingPower: 15200.50,
        shortBuyingPower: 7600.25,
        cashOnly: false,
        marginRate: 0.50,
        maintenanceMarginRate: 0.30,
        maxShares: 120.0,
        maxShortShares: 60.0,
        isMarginable: true,
        leverageRatio: 2.0,
        updatedAt: DateTime.parse('2026-09-13T12:00:00Z'),
      );

      final json = original.toJson();
      final reconstituted = InstrumentBuyingPower.fromJson('inst_rt', json);

      expect(reconstituted.instrumentId, original.instrumentId);
      expect(reconstituted.accountNumber, original.accountNumber);
      expect(reconstituted.buyingPower, original.buyingPower);
      expect(reconstituted.shortBuyingPower, original.shortBuyingPower);
      expect(reconstituted.cashOnly, original.cashOnly);
      expect(reconstituted.marginRate, original.marginRate);
      expect(
        reconstituted.maintenanceMarginRate,
        original.maintenanceMarginRate,
      );
      expect(reconstituted.maxShares, original.maxShares);
      expect(reconstituted.maxShortShares, original.maxShortShares);
    });
  });

  group('InstrumentTradeWarning & InstrumentTradeWarnings Tests', () {
    test('parses trade warnings correctly with severity mapping', () {
      final json = {
        'id': 'warn_1',
        'type': 'high_volatility',
        'title': 'High Volatility Warning',
        'message': 'Extreme price moves detected.',
        'severity': 'warning',
        'requires_acknowledgement': true,
      };

      final warning = InstrumentTradeWarning.fromJson(json);

      expect(warning.id, 'warn_1');
      expect(warning.type, 'high_volatility');
      expect(warning.title, 'High Volatility Warning');
      expect(warning.message, 'Extreme price moves detected.');
      expect(warning.severity, InstrumentWarningSeverity.warning);
      expect(warning.requiresAcknowledgement, isTrue);
      expect(warning.displaySeverity, 'Warning');
    });

    test('maps critical severity for halt or bankruptcy types', () {
      final haltWarn = InstrumentTradeWarning.fromJson({
        'type': 'halt',
        'message': 'Trading halted by FINRA.',
      });
      expect(haltWarn.severity, InstrumentWarningSeverity.critical);
      expect(haltWarn.title, 'Trading Halt Notice');
      expect(haltWarn.displaySeverity, 'Critical Risk');

      final delistWarn = InstrumentTradeWarning.fromJson({
        'type': 'bankruptcy',
        'message': 'Chapter 11 proceedings filed.',
      });
      expect(delistWarn.severity, InstrumentWarningSeverity.critical);
      expect(delistWarn.title, 'Bankruptcy / Delisting Risk');
    });

    test(
      'InstrumentTradeWarnings container parses list and detects criticals',
      () {
        final containerJson = {
          'instrument_id': 'inst_volatile',
          'halted': false,
          'trade_restricted': false,
          'warnings': [
            {
              'id': 'w1',
              'type': 'volatility',
              'title': 'Volatile Stock',
              'message': 'High price swing',
              'severity': 'warning',
            },
            {
              'id': 'w2',
              'type': 'reverse_split',
              'title': 'Reverse Split',
              'message': '1-for-10 split occurred',
              'severity': 'info',
            },
          ],
        };

        final container = InstrumentTradeWarnings.fromJson(
          'inst_volatile',
          containerJson,
        );

        expect(container.hasWarnings, isTrue);
        expect(container.hasCritical, isFalse);
        expect(container.warnings.length, 2);
        expect(container.highestSeverity, InstrumentWarningSeverity.warning);
        expect(container.primaryWarning?.id, 'w1');
      },
    );

    test(
      'InstrumentTradeWarnings synthesizes halt warning if halted is true',
      () {
        final haltedJson = {
          'instrument_id': 'inst_halted',
          'halted': true,
          'warnings': [],
        };

        final container = InstrumentTradeWarnings.fromJson(
          'inst_halted',
          haltedJson,
        );

        expect(container.isHalted, isTrue);
        expect(container.hasWarnings, isTrue);
        expect(container.hasCritical, isTrue);
        expect(container.highestSeverity, InstrumentWarningSeverity.critical);
        expect(container.warnings.length, 1);
        expect(container.warnings.first.type, 'halt');
      },
    );
  });

  group('DemoService Instrument Buying Power & Warnings Integration', () {
    test('returns standard margin terms for normal instruments', () async {
      final demoService = DemoService();
      final user = BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);

      final bpJson = await demoService.getInstrumentBuyingPower(
        user,
        '5QR12345',
        'inst_aapl',
      );
      expect(bpJson, isNotNull);

      final bp = InstrumentBuyingPower.fromJson('inst_aapl', bpJson);
      expect(bp.cashOnly, isFalse);
      expect(bp.marginRate, 0.50);
      expect(bp.buyingPower, 41505.26);
      expect(bp.hasShortCapacity, isTrue);

      final warnJson = await demoService.getInstrumentWarnings(
        user,
        'inst_aapl',
      );
      expect(warnJson, isNotNull);

      final warnings = InstrumentTradeWarnings.fromJson('inst_aapl', warnJson);
      expect(warnings.hasWarnings, isFalse);
    });

    test('returns 100% cash and warnings for volatile symbols', () async {
      final demoService = DemoService();
      final user = BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);

      final bpJson = await demoService.getInstrumentBuyingPower(
        user,
        '5QR12345',
        'inst_gme_meme',
      );
      expect(bpJson, isNotNull);

      final bp = InstrumentBuyingPower.fromJson('inst_gme_meme', bpJson);
      expect(bp.cashOnly, isTrue);
      expect(bp.marginRate, 1.0);
      expect(bp.buyingPower, 17546.87);
      expect(bp.marginStatusLabel, '100% Cash Required');

      final warnJson = await demoService.getInstrumentWarnings(
        user,
        'inst_gme_meme',
      );
      expect(warnJson, isNotNull);

      final warnings = InstrumentTradeWarnings.fromJson(
        'inst_gme_meme',
        warnJson,
      );
      expect(warnings.hasWarnings, isTrue);
      expect(warnings.warnings.length, 2);
      expect(warnings.primaryWarning?.type, 'volatility');
    });
  });
}

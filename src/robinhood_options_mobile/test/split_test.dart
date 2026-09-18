import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/split.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('Split Model Tests', () {
    test('parses corporate stock split correctly', () {
      final json = {
        'id': 'split_01',
        'instrument': 'https://api.robinhood.com/instruments/inst_01/',
        'url': 'https://api.robinhood.com/instruments/inst_01/splits/split_01/',
        'execution_date': '2024-06-10T00:00:00Z',
        'multiplier': '10.0',
        'divisor': '1.0',
      };

      final split = Split.fromJson(json);

      expect(split.id, 'split_01');
      expect(split.multiplier, 10.0);
      expect(split.divisor, 1.0);
      expect(split.effectiveMultiplier, 10.0);
      expect(split.isForwardSplit, isTrue);
      expect(split.isReverseSplit, isFalse);
      expect(split.formattedRatio, '10 for 1 Split');
      expect(split.shortRatioBadge, '10:1 Split');
      expect(split.executionDate, DateTime.parse('2024-06-10T00:00:00Z'));
    });

    test('parses reverse stock split correctly', () {
      final json = {
        'id': 'split_02',
        'execution_date': '2024-01-16T00:00:00Z',
        'multiplier': '1.0',
        'divisor': '25.0',
      };

      final split = Split.fromJson(json);

      expect(split.multiplier, 1.0);
      expect(split.divisor, 25.0);
      expect(split.effectiveMultiplier, 0.04);
      expect(split.isForwardSplit, isFalse);
      expect(split.isReverseSplit, isTrue);
      expect(split.formattedRatio, '1 for 25 Reverse Split');
      expect(split.shortRatioBadge, '1:25 Rev Split');
    });

    test('roundtrips Split to and from json', () {
      final original = Split(
        id: 'split_roundtrip',
        instrument: 'inst_123',
        url: 'https://example.com',
        executionDate: DateTime(2024, 6, 10),
        multiplier: 4.0,
        divisor: 1.0,
      );

      final json = original.toJson();
      final parsed = Split.fromJson(json);

      expect(parsed.id, original.id);
      expect(parsed.multiplier, original.multiplier);
      expect(parsed.divisor, original.divisor);
      expect(parsed.effectiveMultiplier, original.effectiveMultiplier);
    });

    test('handles empty and invalid json gracefully', () {
      final splitFromNull = Split.fromJson(null);
      expect(splitFromNull.id, isNull);
      expect(splitFromNull.multiplier, 1.0);
      expect(splitFromNull.divisor, 1.0);

      final splitFromEmpty = Split.fromJson({});
      expect(splitFromEmpty.id, isNull);
      expect(splitFromEmpty.multiplier, 1.0);
      expect(splitFromEmpty.divisor, 1.0);
    });
  });

  group('SplitPayment Model Tests', () {
    test('parses forward stock split payment with cash-in-lieu correctly', () {
      final json = {
        'id': 'split_pay_nvda_2024',
        'account_number': '5Q12345678',
        'instrument_id': 'inst_nvda_01',
        'symbol': 'NVDA',
        'action_type': 'forward_split',
        'multiplier': '10.0',
        'divisor': '1.0',
        'old_shares': '15.5',
        'new_shares': '155.0',
        'cash_in_lieu': '14.25',
        'currency_code': 'USD',
        'state': 'settled',
        'execution_date': '2024-06-10T13:30:00Z',
        'payment_date': '2024-06-10T20:00:00Z',
        'description': 'NVIDIA Corp 10-for-1 Forward Stock Split',
      };

      final payment = SplitPayment.fromJson(json);

      expect(payment.id, 'split_pay_nvda_2024');
      expect(payment.accountNumber, '5Q12345678');
      expect(payment.instrumentId, 'inst_nvda_01');
      expect(payment.symbol, 'NVDA');
      expect(payment.actionType, 'forward_split');
      expect(payment.multiplier, 10.0);
      expect(payment.divisor, 1.0);
      expect(payment.effectiveMultiplier, 10.0);
      expect(payment.oldShares, 15.5);
      expect(payment.newShares, 155.0);
      expect(payment.sharesDelta, 139.5);
      expect(payment.cashInLieu, 14.25);
      expect(payment.hasCashInLieu, isTrue);
      expect(payment.isForwardSplit, isTrue);
      expect(payment.isReverseSplit, isFalse);
      expect(payment.isSettled, isTrue);
      expect(payment.isPending, isFalse);
      expect(payment.formattedRatio, '10 for 1 Split');
      expect(payment.shortRatioBadge, '10:1 Split');
      expect(payment.formattedOldShares, '15.5');
      expect(payment.formattedNewShares, '155');
      expect(payment.formattedSharesDelta, '+139.5 sh');
      expect(payment.formattedCashInLieu, '\$14.25');
      expect(payment.description, 'NVIDIA Corp 10-for-1 Forward Stock Split');
    });

    test('parses reverse stock split payment with cash-in-lieu correctly', () {
      final json = {
        'id': 'split_pay_bior_2024',
        'account_number': '5Q12345678',
        'instrument_id': 'inst_bior_04',
        'symbol': 'BIOR',
        'action_type': 'reverse_split',
        'multiplier': '1.0',
        'divisor': '25.0',
        'old_shares': '55.0',
        'new_shares': '2.0',
        'cash_in_lieu': '18.40',
        'currency_code': 'USD',
        'state': 'settled',
        'execution_date': '2024-01-16T14:30:00Z',
        'payment_date': '2024-01-16T21:00:00Z',
        'description': 'Biora Therapeutics 1-for-25 Reverse Stock Split',
      };

      final payment = SplitPayment.fromJson(json);

      expect(payment.id, 'split_pay_bior_2024');
      expect(payment.symbol, 'BIOR');
      expect(payment.isForwardSplit, isFalse);
      expect(payment.isReverseSplit, isTrue);
      expect(payment.multiplier, 1.0);
      expect(payment.divisor, 25.0);
      expect(payment.effectiveMultiplier, 0.04);
      expect(payment.oldShares, 55.0);
      expect(payment.newShares, 2.0);
      expect(payment.sharesDelta, -53.0);
      expect(payment.formattedSharesDelta, '-53 sh');
      expect(payment.hasCashInLieu, isTrue);
      expect(payment.formattedCashInLieu, '\$18.40');
      expect(payment.formattedRatio, '1 for 25 Reverse Split');
      expect(payment.shortRatioBadge, '1:25 Rev Split');
    });

    test('roundtrips SplitPayment to and from json', () {
      final payment = SplitPayment(
        id: 'split_roundtrip_test',
        accountNumber: 'ACC100',
        instrumentId: 'INST200',
        symbol: 'TSLA',
        actionType: 'forward_split',
        multiplier: 3.0,
        divisor: 1.0,
        oldShares: 20.0,
        newShares: 60.0,
        cashInLieu: 0.0,
        currencyCode: 'USD',
        state: 'settled',
        executionDate: DateTime(2022, 8, 25),
        paymentDate: DateTime(2022, 8, 25),
        description: 'Tesla 3:1 Split',
      );

      final json = payment.toJson();
      final parsed = SplitPayment.fromJson(json);

      expect(parsed.id, payment.id);
      expect(parsed.accountNumber, payment.accountNumber);
      expect(parsed.symbol, payment.symbol);
      expect(parsed.multiplier, payment.multiplier);
      expect(parsed.newShares, payment.newShares);
      expect(parsed.cashInLieu, payment.cashInLieu);
      expect(parsed.state, payment.state);
    });

    test('handles empty or missing json fields safely', () {
      final payment = SplitPayment.fromJson({});
      expect(payment.id, '');
      expect(payment.symbol, '');
      expect(payment.displaySymbol, 'Stock');
      expect(payment.multiplier, 1.0);
      expect(payment.oldShares, 0.0);
      expect(payment.cashInLieu, 0.0);
      expect(payment.hasCashInLieu, isFalse);
    });

    test('extracts instrument and split from nested URLs or maps', () {
      final json = {
        'id': 'sp-12345',
        'instrument': 'https://api.robinhood.com/instruments/9423262b-de3b-47e1-b715-fced3a076039/',
        'split': 'https://api.robinhood.com/corp_actions/v2/splits/split-uuid-999/',
        'multiplier': '4.0',
        'divisor': '1.0',
      };

      final payment = SplitPayment.fromJson(json);
      expect(payment.instrumentId, '9423262b-de3b-47e1-b715-fced3a076039');
      expect(payment.splitUrl, 'https://api.robinhood.com/corp_actions/v2/splits/split-uuid-999/');
      expect(payment.split == 'https://api.robinhood.com/corp_actions/v2/splits/split-uuid-999/', isTrue);
      expect(payment.symbol, '');
      expect(payment.displaySymbol, '9423262B');
      expect(payment.shortInstrumentId, '9423262b-de3b-47e1-b715-fced3a076039');
    });

    test('copyWith updates fields as expected', () {
      const payment = SplitPayment(
        id: 'sp-1',
        accountNumber: 'ACC1',
        symbol: '',
        instrumentId: 'inst-1',
      );
      final updated = payment.copyWith(
        symbol: 'AAPL',
        description: 'Apple Inc.',
      );

      expect(updated.symbol, 'AAPL');
      expect(updated.displaySymbol, 'AAPL');
      expect(updated.description, 'Apple Inc.');
      expect(updated.id, 'sp-1');
      expect(updated.instrumentId, 'inst-1');
    });

    test('parses alternative split ratio keys and string expressions', () {
      final jsonColon = {
        'id': 'sp-colon',
        'symbol': 'NVDA',
        'ratio': '10:1',
      };
      final payColon = SplitPayment.fromJson(jsonColon);
      expect(payColon.multiplier, 10.0);
      expect(payColon.divisor, 1.0);
      expect(payColon.effectiveMultiplier, 10.0);
      expect(payColon.shortRatioBadge, '10:1 Split');
      expect(payColon.formattedSplitRatio, '10:1');

      final jsonSlash = {
        'id': 'sp-slash',
        'symbol': 'BIOR',
        'split_ratio': '1/25',
      };
      final paySlash = SplitPayment.fromJson(jsonSlash);
      expect(paySlash.multiplier, 1.0);
      expect(paySlash.divisor, 25.0);
      expect(paySlash.effectiveMultiplier, 0.04);
      expect(paySlash.shortRatioBadge, '1:25 Rev Split');
      expect(paySlash.formattedSplitRatio, '1:25');

      final jsonFactors = {
        'id': 'sp-factors',
        'symbol': 'TSLA',
        'to_factor': '3.0',
        'from_factor': '1.0',
      };
      final payFactors = SplitPayment.fromJson(jsonFactors);
      expect(payFactors.multiplier, 3.0);
      expect(payFactors.divisor, 1.0);
      expect(payFactors.formattedSplitRatio, '3:1');
    });

    test('derives split ratio from pre/post split share counts when multiplier/divisor missing', () {
      final jsonForward = {
        'id': 'sp-shares-forward',
        'symbol': 'NVDA',
        'pre_split_shares': '15.5',
        'post_split_shares': '155.0',
      };
      final payForward = SplitPayment.fromJson(jsonForward);
      expect(payForward.effectiveMultiplier, 10.0);
      expect(payForward.shortRatioBadge, '10:1 Split');
      expect(payForward.formattedSplitRatio, '10:1');
      expect(payForward.isForwardSplit, isTrue);

      final jsonReverse = {
        'id': 'sp-shares-reverse',
        'symbol': 'BIOR',
        'shares_held': '50.0',
        'resulting_shares': '2.0',
      };
      final payReverse = SplitPayment.fromJson(jsonReverse);
      expect(payReverse.effectiveMultiplier, closeTo(0.04, 0.0001));
      expect(payReverse.shortRatioBadge, '1:25 Rev Split');
      expect(payReverse.formattedSplitRatio, '1:25');
      expect(payReverse.isReverseSplit, isTrue);
    });

    test('parses nested split object correctly', () {
      final jsonNested = {
        'id': 'sp-nested',
        'symbol': 'AAPL',
        'split': {
          'multiplier': '4.0',
          'divisor': '1.0',
        },
      };
      final payNested = SplitPayment.fromJson(jsonNested);
      expect(payNested.multiplier, 4.0);
      expect(payNested.divisor, 1.0);
      expect(payNested.formattedSplitRatio, '4:1');
      expect(payNested.shortRatioBadge, '4:1 Split');
    });

    test('parses Robinhood corporate action nested split object with old_instrument_id (AMZN 20:1)', () {
      final json = {
        'id': 'sp-amzn-2022',
        'account_number': '5Q12345678',
        'split': {
          'id': 'd592308d-2f8a-4066-854b-02cbb689db85',
          'old_instrument_id': 'c0bb3aec-bd1e-471e-a4f0-ca011cbec711',
          'new_instrument_id': 'c0bb3aec-bd1e-471e-a4f0-ca011cbec711',
          'effective_date': '2022-06-06',
          'multiplier': 20.00000000000000,
          'divisor': 1.00000000000000,
          'direction': 'forward',
          'updated_at': '2022-06-08T13:52:03.811354Z',
        },
        'state': 'settled',
        'execution_date': '2022-06-06T13:30:00Z',
      };

      final payment = SplitPayment.fromJson(json);

      expect(payment.id, 'sp-amzn-2022');
      expect(payment.oldInstrumentId, 'c0bb3aec-bd1e-471e-a4f0-ca011cbec711');
      expect(payment.newInstrumentId, 'c0bb3aec-bd1e-471e-a4f0-ca011cbec711');
      expect(payment.instrumentId, 'c0bb3aec-bd1e-471e-a4f0-ca011cbec711');
      expect(payment.multiplier, 20.0);
      expect(payment.divisor, 1.0);
      expect(payment.effectiveMultiplier, 20.0);
      expect(payment.isForwardSplit, isTrue);
      expect(payment.formattedRatio, '20 for 1 Split');
      expect(payment.shortRatioBadge, '20:1 Split');
      expect(payment.split, isNotNull);
      expect(payment.split!.id, 'd592308d-2f8a-4066-854b-02cbb689db85');
      expect(payment.split!.direction, 'forward');
      expect(payment.split!.effectiveDate, DateTime.parse('2022-06-06'));
      // Backwards compatible equality with string ID
      expect(payment.split == 'd592308d-2f8a-4066-854b-02cbb689db85', isTrue);

      final roundtrip = SplitPayment.fromJson(payment.toJson());
      expect(roundtrip.oldInstrumentId, 'c0bb3aec-bd1e-471e-a4f0-ca011cbec711');
      expect(roundtrip.multiplier, 20.0);
      expect(roundtrip.divisor, 1.0);
    });
  });

  group('CorporateActionSplitsSummary Tests', () {
    test('computes totals, counts, and symbols accurately', () {
      final payments = [
        const SplitPayment(
          id: '1',
          accountNumber: 'ACC1',
          instrumentId: 'INST1',
          symbol: 'NVDA',
          actionType: 'forward_split',
          multiplier: 10.0,
          divisor: 1.0,
          oldShares: 10.0,
          newShares: 100.0,
          cashInLieu: 14.25,
        ),
        const SplitPayment(
          id: '2',
          accountNumber: 'ACC1',
          instrumentId: 'INST2',
          symbol: 'TSLA',
          actionType: 'forward_split',
          multiplier: 3.0,
          divisor: 1.0,
          oldShares: 10.0,
          newShares: 30.0,
          cashInLieu: 0.0,
        ),
        const SplitPayment(
          id: '3',
          accountNumber: 'ACC1',
          instrumentId: 'INST3',
          symbol: 'BIOR',
          actionType: 'reverse_split',
          multiplier: 1.0,
          divisor: 25.0,
          oldShares: 55.0,
          newShares: 2.0,
          cashInLieu: 18.40,
        ),
      ];

      final summary = CorporateActionSplitsSummary.fromPayments(payments);

      expect(summary.totalSplitsCount, 3);
      expect(summary.forwardSplitsCount, 2);
      expect(summary.reverseSplitsCount, 1);
      expect(summary.totalCashInLieu, closeTo(32.65, 0.001));
      expect(summary.formattedTotalCashInLieu, '\$32.65');
      expect(summary.symbolsAffected, ['BIOR', 'NVDA', 'TSLA']);
    });
  });

  group('DemoService Split Payments Integration Tests', () {
    final demoService = DemoService();
    final testUser = BrokerageUser(
      BrokerageSource.demo,
      'trader_alex',
      null,
      null,
    );

    test('returns demo corporate action split payments', () async {
      final payments = await demoService.getSplitPaymentsModel(testUser);

      expect(payments.isNotEmpty, isTrue);
      expect(payments.length, 5);

      final nvda = payments.firstWhere((p) => p.symbol == 'NVDA');
      expect(nvda.isForwardSplit, isTrue);
      expect(nvda.multiplier, 10.0);
      expect(nvda.cashInLieu, 14.25);
      expect(nvda.hasCashInLieu, isTrue);

      final bior = payments.firstWhere((p) => p.symbol == 'BIOR');
      expect(bior.isReverseSplit, isTrue);
      expect(bior.divisor, 25.0);
      expect(bior.cashInLieu, 18.40);

      final amzn = payments.firstWhere((p) => p.symbol == 'AMZN');
      expect(amzn.isForwardSplit, isTrue);
      expect(amzn.multiplier, 20.0);
      expect(amzn.oldInstrumentId, 'c0bb3aec-bd1e-471e-a4f0-ca011cbec711');
      expect(amzn.split, isNotNull);
      expect(amzn.split!.direction, 'forward');
    });

    test('filters split payments by instrumentId / symbol', () async {
      final nvdaOnly = await demoService.getSplitPaymentsModel(
        testUser,
        instrumentId: 'NVDA',
      );
      expect(nvdaOnly.length, 1);
      expect(nvdaOnly.first.symbol, 'NVDA');

      final biorOnly = await demoService.getSplitPaymentsModel(
        testUser,
        instrumentId: 'inst_bior_04',
      );
      expect(biorOnly.length, 1);
      expect(biorOnly.first.symbol, 'BIOR');

      final amznByOldId = await demoService.getSplitPaymentsModel(
        testUser,
        instrumentId: 'c0bb3aec-bd1e-471e-a4f0-ca011cbec711',
      );
      expect(amznByOldId.length, 1);
      expect(amznByOldId.first.symbol, 'AMZN');
    });

    test('aggregates summary metrics from DemoService', () async {
      final summary = await demoService.getCorporateActionSplitsSummary(testUser);

      expect(summary.totalSplitsCount, 5);
      expect(summary.forwardSplitsCount, 4);
      expect(summary.reverseSplitsCount, 1);
      expect(summary.totalCashInLieu, closeTo(32.65, 0.001));
      expect(summary.symbolsAffected, containsAll(['AAPL', 'AMZN', 'BIOR', 'NVDA', 'TSLA']));
    });
  });

  group('getSplits Integration Tests', () {
    final demoService = DemoService();
    final testUser = BrokerageUser(
      BrokerageSource.demo,
      'trader_alex',
      null,
      null,
    );

    test('DemoService.getSplits returns splits for NVDA matching symbol/id', () async {
      final instrument = Instrument.forSymbol(
        'NVDA',
        instrumentUrl: 'https://api.robinhood.com/instruments/inst_nvda_01/',
      );

      final splits = await demoService.getSplits(testUser, instrument);
      expect(splits, isNotEmpty);
      expect(splits.length, 1);
      final split = Split.fromJson(splits.first);
      expect(split.multiplier, 10.0);
      expect(split.divisor, 1.0);
      expect(split.formattedRatio, '10 for 1 Split');
    });

    test('DemoService.getSplits returns reverse split for BIOR matching symbol', () async {
      final instrument = Instrument.forSymbol(
        'BIOR',
        instrumentUrl: 'https://api.robinhood.com/instruments/different_id_bior/',
      );

      final splits = await demoService.getSplits(testUser, instrument);
      expect(splits, isNotEmpty);
      expect(splits.length, 1);
      final split = Split.fromJson(splits.first);
      expect(split.multiplier, 1.0);
      expect(split.divisor, 25.0);
      expect(split.isReverseSplit, isTrue);
      expect(split.formattedRatio, '1 for 25 Reverse Split');
    });

    test('DemoService.getSplits returns 20:1 forward split for AMZN matching old instrument id', () async {
      final instrument = Instrument.forSymbol(
        'AMZN',
        instrumentUrl: 'https://api.robinhood.com/instruments/c0bb3aec-bd1e-471e-a4f0-ca011cbec711/',
      );

      final splits = await demoService.getSplits(testUser, instrument);
      expect(splits, isNotEmpty);
      expect(splits.length, 1);
      final split = Split.fromJson(splits.first);
      expect(split.multiplier, 20.0);
      expect(split.divisor, 1.0);
      expect(split.isForwardSplit, isTrue);
      expect(split.formattedRatio, '20 for 1 Split');
    });

    test('DemoService.getSplits returns empty list for ticker with no splits', () async {
      final instrument = Instrument.forSymbol('XYZUNKNOWN');

      final splits = await demoService.getSplits(testUser, instrument);
      expect(splits, isEmpty);
    });
  });
}

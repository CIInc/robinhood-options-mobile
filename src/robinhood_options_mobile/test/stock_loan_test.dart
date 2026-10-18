import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/stock_loan.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('StockLoanPosition Model Tests', () {
    test('parses normal stock loan position correctly', () {
      final json = {
        'symbol': 'tsla',
        'quantity': '50.0000',
        'rate': 0.065,
        'collateral_amount': 12500.0,
        'interest_earned': 10.25,
      };

      final pos = StockLoanPosition.fromJson(json);
      expect(pos.symbol, 'TSLA');
      expect(pos.quantity, 50.0);
      expect(pos.borrowRate, 0.065);
      expect(pos.collateralAmount, 12500.0);
      expect(pos.interestEarned, 10.25);
      expect(pos.formattedQuantity, '50');
      expect(pos.formattedBorrowRate, contains('6.5'));
      expect(pos.formattedCollateralAmount, contains('12,500'));
      expect(pos.formattedInterestEarned, contains('10.25'));
    });

    test('handles fallback keys and null values gracefully', () {
      final json = {
        'ticker': 'gme',
        'shares_loaned': 120,
        'rebate_rate': '0.14',
        'cash_collateral': '3000',
        'earnings': '8.50',
      };

      final pos = StockLoanPosition.fromJson(json);
      expect(pos.symbol, 'GME');
      expect(pos.quantity, 120.0);
      expect(pos.borrowRate, 0.14);
      expect(pos.collateralAmount, 3000.0);
      expect(pos.interestEarned, 8.50);
    });

    test('roundtrips to and from json', () {
      const original = StockLoanPosition(
        symbol: 'NVDA',
        quantity: 25.5,
        borrowRate: 0.038,
        collateralAmount: 3100.0,
        interestEarned: 7.60,
      );

      final json = original.toJson();
      final parsed = StockLoanPosition.fromJson(json);
      expect(parsed.symbol, original.symbol);
      expect(parsed.quantity, original.quantity);
      expect(parsed.borrowRate, original.borrowRate);
      expect(parsed.collateralAmount, original.collateralAmount);
      expect(parsed.interestEarned, original.interestEarned);
    });
  });

  group('StockLoanPayment Model Tests', () {
    test('parses full payment record with line-item positions', () {
      final json = {
        'id': 'slp_1001',
        'account_number': 'ACCT12345',
        'payment_date': '2026-08-15T00:00:00Z',
        'amount': '28.50',
        'currency_code': 'USD',
        'status': 'paid',
        'description': 'Securities Lending Monthly Income',
        'gross_rate': 0.08,
        'net_rate': 0.04,
        'positions': [
          {
            'symbol': 'TSLA',
            'quantity': 50,
            'rate': 0.065,
            'collateral_amount': 12500,
            'interest_earned': 18.25,
          },
          {
            'symbol': 'GME',
            'quantity': 100,
            'rate': 0.12,
            'collateral_amount': 2500,
            'interest_earned': 10.25,
          },
        ],
      };

      final payment = StockLoanPayment.fromJson(json);
      expect(payment.id, 'slp_1001');
      expect(payment.accountNumber, 'ACCT12345');
      expect(payment.amount, 28.50);
      expect(payment.status, 'paid');
      expect(payment.isPaid, isTrue);
      expect(payment.isPending, isFalse);
      expect(payment.grossRate, 0.08);
      expect(payment.netRate, 0.04);
      expect(payment.positions.length, 2);
      expect(payment.positions.first.symbol, 'TSLA');
      expect(payment.formattedAmount, contains('28.50'));
      expect(payment.formattedStatus, 'Paid');
    });

    test('handles pending or settled statuses properly', () {
      final pending = StockLoanPayment.fromJson({
        'id': 'slp_pending',
        'amount': '12.00',
        'status': 'pending',
      });
      expect(pending.isPending, isTrue);
      expect(pending.isPaid, isFalse);

      final settled = StockLoanPayment.fromJson({
        'id': 'slp_settled',
        'amount': '15.00',
        'status': 'settled',
      });
      expect(settled.isPaid, isTrue);
      expect(settled.isPending, isFalse);
    });

    test('handles empty or invalid payment json gracefully', () {
      final payment = StockLoanPayment.fromJson(null);
      expect(payment.id, 'unknown');
      expect(payment.amount, 0.0);
      expect(payment.positions, isEmpty);
    });
  });

  group('SlipEligibility Model Tests', () {
    test('parses enrolled account with all metrics', () {
      final json = {
        'enrolled': true,
        'is_enrolled': true,
        'eligible': true,
        'status': 'enrolled',
        'agreement_signed': true,
        'agreement_signed_date': '2026-01-10T12:00:00Z',
        'total_interest_earned_ytd': 142.85,
        'total_interest_earned_all_time': 318.40,
        'estimated_annualized_yield': 0.052,
        'loaned_securities_count': 3,
        'total_loaned_value': 17600.0,
      };

      final slip = SlipEligibility.fromJson(json);
      expect(slip.isEnrolled, isTrue);
      expect(slip.isEligible, isTrue);
      expect(slip.status, SlipEnrollmentStatus.enrolled);
      expect(slip.agreementSigned, isTrue);
      expect(slip.totalInterestEarnedYtd, 142.85);
      expect(slip.totalInterestEarnedAllTime, 318.40);
      expect(slip.estimatedAnnualizedYield, 0.052);
      expect(slip.loanedSecuritiesCount, 3);
      expect(slip.totalLoanedValue, 17600.0);
      expect(slip.formattedStatus, contains('Enrolled'));
      expect(slip.formattedTotalYtd, contains('142.85'));
      expect(slip.formattedTotalAllTime, contains('318.40'));
      expect(slip.formattedEstimatedYield, contains('5.2'));
    });

    test('parses ineligible account with disqualification reasons', () {
      final json = {
        'enrolled': false,
        'eligible': false,
        'status': 'ineligible',
        'agreement_signed': false,
        'ineligibility_reasons': [
          'Account must be active for at least 30 days',
          'Minimum equity requirement not met',
        ],
      };

      final slip = SlipEligibility.fromJson(json);
      expect(slip.isEnrolled, isFalse);
      expect(slip.isEligible, isFalse);
      expect(slip.status, SlipEnrollmentStatus.ineligible);
      expect(slip.ineligibilityReasons.length, 2);
      expect(slip.formattedStatus, 'Ineligible');
    });

    test('generates sensible defaults when json is null', () {
      final slip = SlipEligibility.fromJson(null);
      expect(slip.isEnrolled, isFalse);
      expect(slip.isEligible, isTrue);
      expect(slip.status, SlipEnrollmentStatus.eligible);
      expect(slip.ineligibilityReasons, isEmpty);
    });
  });

  group('SweepsInterest Model Tests', () {
    test('parses cash sweeps with Gold rate and balances', () {
      final json = {
        'account_number': 'ACCT555',
        'is_enrolled': true,
        'gold_rate': 0.050,
        'standard_rate': 0.015,
        'boosted_rate': 0.055,
        'rate': 0.050,
        'fdic_insurance_limit': 2250000.0,
        'sweep_balance': 15000.0,
        'partner_banks': [
          'Citibank, N.A.',
          'Goldman Sachs Bank USA',
          'Wells Fargo Bank, N.A.',
        ],
      };

      final sweeps = SweepsInterest.fromJson(json);
      expect(sweeps.accountNumber, 'ACCT555');
      expect(sweeps.isEnrolled, isTrue);
      expect(sweeps.goldApy, 0.050);
      expect(sweeps.standardApy, 0.015);
      expect(sweeps.boostedApy, 0.055);
      expect(sweeps.currentEffectiveApy, 0.050);
      expect(sweeps.fdicInsuranceLimit, 2250000.0);
      expect(sweeps.sweepBalance, 15000.0);
      expect(sweeps.partnerBanks.length, 3);

      // Calculations: $15,000 * 5% = $750/yr, $62.50/mo
      expect(sweeps.estimatedAnnualInterest, 750.0);
      expect(sweeps.estimatedMonthlyInterest, 62.5);
      expect(sweeps.formattedGoldApy, contains('5.00%'));
      expect(sweeps.formattedStandardApy, contains('1.50%'));
      expect(sweeps.formattedSweepBalance, contains('15,000'));
      expect(sweeps.formattedEstimatedAnnualInterest, contains('750.00'));
      expect(sweeps.formattedEstimatedMonthlyInterest, contains('62.50'));
      expect(sweeps.formattedFdicInsuranceLimit, contains('2,250,000'));
      expect(sweeps.formattedCompactFdicLimit, contains('2.25M'));
    });

    test('falls back to provided uninvested cash when balance is missing', () {
      final sweeps = SweepsInterest.fromJson(null, uninvestedCash: 8000.0);
      expect(sweeps.sweepBalance, 8000.0);
      expect(sweeps.currentEffectiveApy, 0.015);
      expect(sweeps.estimatedAnnualInterest, 8000.0 * 0.015);
      expect(sweeps.partnerBanks, isNotEmpty);
    });
  });

  group('DemoService Stock Loan & Sweeps Integration Tests', () {
    final testUser = BrokerageUser(
      BrokerageSource.demo,
      'trader_alpha',
      null,
      null,
    );
    final demoService = DemoService();

    test('returns demo stock loan payments with valid positions', () async {
      final paymentsRaw = await demoService.getStockLoanPayments(testUser);
      expect(paymentsRaw, isNotEmpty);

      final payments =
          paymentsRaw.map((p) => StockLoanPayment.fromJson(p)).toList();
      expect(payments.length, 3);
      expect(payments.first.amount, greaterThan(0));
      expect(payments.first.positions, isNotEmpty);
      expect(payments.first.positions.any((p) => p.symbol == 'TSLA'), isTrue);
    });

    test('returns demo SLIP eligibility and status', () async {
      final rawEligibility = await demoService.getSlipEligibility(testUser);
      expect(rawEligibility, isNotNull);

      final slip = SlipEligibility.fromJson(rawEligibility);
      expect(slip.isEnrolled, isTrue);
      expect(slip.agreementSigned, isTrue);
      expect(slip.totalInterestEarnedYtd, greaterThan(0));
    });

    test('returns demo cash sweeps with partner banks and 5% gold rate',
        () async {
      final rawSweeps = await demoService.getSweepsInterest(testUser);
      expect(rawSweeps, isNotNull);

      final sweeps = SweepsInterest.fromJson(rawSweeps);
      expect(sweeps.isEnrolled, isTrue);
      expect(sweeps.goldApy, 0.050);
      expect(sweeps.partnerBanks.length, greaterThanOrEqualTo(5));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/retirement.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  group('RetirementContribution Model Tests', () {
    test('parses 2026 Roth IRA contribution correctly', () {
      final json = {
        'year': 2026,
        'account_type': 'ira_roth',
        'contribution_amount': '5500.00',
        'match_amount': '165.00',
        'match_rate': '0.03',
        'direct_contributions': '5500.00',
        'rollover_contributions': '0.00',
        'conversions': '0.00',
        'limit': '7000.00',
        'catch_up_limit': '8000.00',
        'created_at': '2026-01-15T09:00:00Z',
        'status': 'active',
      };

      final contrib = RetirementContribution.fromJson(json);

      expect(contrib.year, 2026);
      expect(contrib.accountType, 'ira_roth');
      expect(contrib.contributionAmount, 5500.0);
      expect(contrib.matchAmount, 165.0);
      expect(contrib.matchRate, 0.03);
      expect(contrib.limit, 7000.0);
      expect(contrib.catchUpLimit, 8000.0);
      expect(contrib.remainingLimit, 1500.0);
      expect(contrib.remainingCatchUpLimit, 2500.0);
      expect(contrib.isRoth, isTrue);
      expect(contrib.isTraditional, isFalse);
      expect(contrib.isMaxedOut, isFalse);
      expect(contrib.displayAccountType, 'Roth IRA');
      expect(contrib.formattedContribution, '\$5,500.00');
      expect(contrib.formattedLimit, '\$7,000.00');
      expect(contrib.formattedRemaining, '\$1,500.00');
      expect(contrib.formattedMatch, '\$165.00');
      expect(contrib.progressPercentage, closeTo(5500.0 / 7000.0, 0.001));
    });

    test('detects maxed out contribution', () {
      final json = {
        'year': 2025,
        'account_type': 'ira_traditional',
        'contribution_amount': 7000.0,
        'limit': 7000.0,
      };

      final contrib = RetirementContribution.fromJson(json);
      expect(contrib.isMaxedOut, isTrue);
      expect(contrib.remainingLimit, 0.0);
      expect(contrib.progressPercentage, 1.0);
      expect(contrib.isTraditional, isTrue);
      expect(contrib.displayAccountType, 'Traditional IRA');
    });

    test('uses known IRS limits when limit not supplied', () {
      final json = {
        'year': 2024,
        'amount': '4000.00',
      };

      final contrib = RetirementContribution.fromJson(json);
      expect(contrib.limit, 7000.0);
      expect(contrib.catchUpLimit, 8000.0);
      expect(contrib.remainingLimit, 3000.0);
    });

    test('roundtrips to and from json', () {
      const original = RetirementContribution(
        year: 2026,
        accountType: 'ira_roth',
        contributionAmount: 6500.0,
        matchAmount: 195.0,
        matchRate: 0.03,
        limit: 7000.0,
        catchUpLimit: 8000.0,
        status: 'active',
      );

      final json = original.toJson();
      final parsed = RetirementContribution.fromJson(json);

      expect(parsed.year, original.year);
      expect(parsed.accountType, original.accountType);
      expect(parsed.contributionAmount, original.contributionAmount);
      expect(parsed.matchAmount, original.matchAmount);
      expect(parsed.matchRate, original.matchRate);
      expect(parsed.limit, original.limit);
      expect(parsed.catchUpLimit, original.catchUpLimit);
    });

    test('handles empty and null json gracefully', () {
      final contrib = RetirementContribution.fromJson(null);
      expect(contrib.year, isNotNull);
      expect(contrib.contributionAmount, 0.0);
      expect(contrib.limit, greaterThan(0));
    });
  });

  group('RetirementHistory Model Tests', () {
    test('parses history with multiple years', () {
      final json = {
        'account_number': 'ROTH1234',
        'total_contributions': '12500.00',
        'total_match': '375.00',
        'results': [
          {
            'year': 2026,
            'contribution_amount': '5500.00',
            'match_amount': '165.00',
            'limit': '7000.00',
          },
          {
            'year': 2025,
            'contribution_amount': '7000.00',
            'match_amount': '210.00',
            'limit': '7000.00',
          },
        ],
      };

      final history = RetirementHistory.fromJson(json);

      expect(history.accountNumber, 'ROTH1234');
      expect(history.totalContributions, 12500.0);
      expect(history.totalMatch, 375.0);
      expect(history.contributions.length, 2);

      final c2026 = history.contributionForYear(2026);
      expect(c2026, isNotNull);
      expect(c2026!.contributionAmount, 5500.0);

      final c2025 = history.contributionForYear(2025);
      expect(c2025, isNotNull);
      expect(c2025!.contributionAmount, 7000.0);

      expect(history.contributionForYear(2020), isNull);
    });

    test('integrates with DemoService', () async {
      final service = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
      );

      final history = await service.getRetirementHistoryModel(user);

      expect(history.contributions, isNotEmpty);
      expect(history.totalContributions, greaterThan(0));
      expect(history.totalMatch, greaterThan(0));
      expect(history.accountNumber, 'ROTH7890');
    });
  });
}

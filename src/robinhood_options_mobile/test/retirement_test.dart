import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/retirement.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';
import 'package:robinhood_options_mobile/widgets/retirement_widget.dart';

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

    test('DemoService fetches Traditional IRA history with TRAD1234', () async {
      final service = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
      );

      final history = await service.getRetirementHistoryModel(user,
          accountNumber: 'TRAD1234');

      expect(history.accountNumber, 'TRAD1234');
      expect(history.contributions, isNotEmpty);
      final c2026 = history.contributionForYear(2026, accountType: 'ira_traditional');
      expect(c2026, isNotNull);
      expect(c2026!.isTraditional, isTrue);
      expect(c2026.contributionAmount, 0.0);
      expect(c2026.rolloverContributions, 12500.0);
    });

    test('parses Traditional IRA with direct contributions fallback when contribution_amount is 0', () {
      final json = {
        'year': 2026,
        'brokerage_account_type': 'ira_traditional',
        'account_number': 'TRAD1234',
        'contribution_amount': '0.00',
        'direct_contributions': '6500.00',
        'rollover_contributions': '0.00',
      };

      final contrib = RetirementContribution.fromJson(json);

      expect(contrib.isTraditional, isTrue);
      expect(contrib.accountNumber, 'TRAD1234');
      expect(contrib.contributionAmount, 6500.0);
      expect(contrib.directContributions, 6500.0);
    });

    test('parses Traditional IRA with rollover contributions and distinguishes from annual limit', () {
      final json = {
        'year': 2026,
        'account_type': 'ira_traditional',
        'contribution_amount': '0.00',
        'direct_contributions': '0.00',
        'rollover_contributions': '45000.00',
        'limit': '7000.00',
      };

      final contrib = RetirementContribution.fromJson(json);

      expect(contrib.isTraditional, isTrue);
      expect(contrib.contributionAmount, 0.0);
      expect(contrib.rolloverContributions, 45000.0);
      expect(contrib.remainingLimit, 7000.0);
      expect(contrib.isMaxedOut, isFalse);
    });

    test('filters multi-account history by accountType and accountNumber correctly', () {
      final json = {
        'results': [
          {
            'year': 2026,
            'account_type': 'ira_roth',
            'account_number': 'ROTH7890',
            'contribution_amount': '0.00',
          },
          {
            'year': 2026,
            'account_type': 'ira_traditional',
            'account_number': 'TRAD1234',
            'contribution_amount': '7000.00',
          },
        ],
      };

      final history = RetirementHistory.fromJson(json);

      // Filtering by traditional IRA returns the $7,000 contribution
      final tradContrib = history.contributionForYear(2026,
          accountType: 'ira_traditional', accountNumber: 'TRAD1234');
      expect(tradContrib, isNotNull);
      expect(tradContrib!.contributionAmount, 7000.0);
      expect(tradContrib.isTraditional, isTrue);

      // Filtering by roth returns the $0 contribution
      final rothContrib = history.contributionForYear(2026,
          accountType: 'ira_roth', accountNumber: 'ROTH7890');
      expect(rothContrib, isNotNull);
      expect(rothContrib!.contributionAmount, 0.0);
      expect(rothContrib.isRoth, isTrue);
    });

    test('sums contributions across multiple years when top-level total is missing', () {
      final json = {
        'results': [
          {'year': 2026, 'contribution_amount': '3000.00', 'match_amount': '90.00'},
          {'year': 2025, 'contribution_amount': '7000.00', 'match_amount': '210.00'},
          {'year': 2024, 'contribution_amount': '6500.00', 'match_amount': '195.00'},
        ],
      };

      final history = RetirementHistory.fromJson(json);
      expect(history.totalContributions, 16500.0);
      expect(history.totalMatch, 495.0);
    });

    test('parses ACATS incoming settled transfer into rollover contributions and sets sourceDescription', () {
      final json = {
        'account_number': '741902639',
        'account_type': 'ira_traditional',
        'total_value': '25334.93',
        'match_rate': '1',
        'results': [],
        'acats': [
          {
            'id': '33455e38-973c-4dfd-8208-0037343ff77a',
            'rhs_account_number': '741902639',
            'contra_broker_name': 'Merrill Lynch',
            'settlement_date': '2025-05-02',
            'phase': 'settled',
            'market_value': '25334.93',
          }
        ],
      };

      final history = RetirementHistory.fromJson(json);

      expect(history.accountNumber, '741902639');
      // Should contain 2026 (current year active) and 2025 (settled rollover)
      expect(history.contributions.length, 2);

      final c2025 = history.contributionForYear(2025);
      expect(c2025, isNotNull);
      expect(c2025!.rolloverContributions, 25334.93);
      expect(c2025.sourceDescription, 'Rollover from Merrill Lynch');
      expect(c2025.isTraditional, isTrue);

      final cCurrent = history.contributionForYear(DateTime.now().year);
      expect(cCurrent, isNotNull);
      expect(cCurrent!.contributionAmount, 0.0);
      expect(cCurrent.remainingLimit, 7000.0);
    });
  });

  group('RetirementWidget Widget Tests', () {
    testWidgets('renders Traditional IRA with balance, year selector, and rollover details', (tester) async {
      final service = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
      );

      final traditionalAccount = Account.fromJson({
        'account_number': 'TRAD1234',
        'type': 'cash',
        'brokerage_account_type': 'ira_traditional',
        'portfolio_cash': '12500.00',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: RetirementWidget(
            brokerageUser: user,
            service: service,
            account: traditionalAccount,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header displays Traditional IRA and account number
      expect(find.text('Traditional IRA'), findsWidgets);
      expect(find.text('Account: TRAD1234'), findsOneWidget);
      expect(find.text('Total Account Value'), findsOneWidget);
      expect(find.text('\$12,500.00'), findsWidgets);

      // Tax year selector chips are present
      expect(find.text('2026 (Current)'), findsOneWidget);
      expect(find.text('2025'), findsWidgets);

      // Tax-advantaged badge in Wrap row
      expect(find.text('TAX-ADVANTAGED'), findsOneWidget);

      // Rollover explanation is displayed for 2026 Traditional IRA fixture
      expect(find.text('Rollovers & Transfers: '), findsOneWidget);
    });

    testWidgets('displays Total Account Value distinctly from Cash / Buying Power when different', (tester) async {
      final service = DemoService();
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
      );

      final traditionalAccount = Account.fromJson({
        'account_number': '741902639',
        'type': 'cash',
        'brokerage_account_type': 'ira_traditional',
        'total_value': '25326.80',
        'portfolio_cash': '450.21',
      });

      await tester.pumpWidget(
        MaterialApp(
          home: RetirementWidget(
            brokerageUser: user,
            service: service,
            account: traditionalAccount,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Total Account Value displays total_value ($25,326.80)
      expect(find.text('Total Account Value'), findsOneWidget);
      expect(find.text('\$25,326.80'), findsOneWidget);

      // Cash / Buying Power displays portfolio_cash ($450.21)
      expect(find.text('Cash / Buying Power'), findsOneWidget);
      expect(find.text('\$450.21'), findsOneWidget);
    });

    testWidgets('renders Transfers & Contributions when retirement history includes unified transfers', (tester) async {
      final user = BrokerageUser(
        BrokerageSource.demo,
        'demo_user',
        null,
        null,
      );

      final traditionalAccount = Account.fromJson({
        'account_number': '741902639',
        'type': 'cash',
        'brokerage_account_type': 'ira_traditional',
        'total_value': '25326.80',
        'portfolio_cash': '450.21',
      });

      final mockHistory = RetirementHistory.fromJson({
        'account_number': '741902639',
        'account_type': 'ira_traditional',
        'total_value': 25326.80,
        'match_rate': 0.03,
        'unified_transfers': [
          {
            'id': '57d18679-7ed7-4bd5-a61e-7cdb46a7ac7b',
            'amount': '1000.00',
            'direction': 'pull',
            'state': 'completed',
            'created_at': '2026-09-25T23:14:45Z',
            'contribution_details': {
              'payment_transfer_id': '57d18679-7ed7-4bd5-a61e-7cdb46a7ac7b',
              'rows': [
                {'label': 'Contribution type', 'value': 'New IRA Contribution'},
                {'label': 'Tax year', 'value': '2026'},
                {'label': 'Match percentage', 'value': '3%'},
                {'label': 'Total match amount', 'value': '\$30.00'},
              ],
            },
          },
          {
            'id': '5c5a298e-eee1-43a8-8bef-bf74c1fd83c7',
            'amount': '2000.00',
            'direction': 'pull',
            'state': 'completed',
            'created_at': '2026-09-15T01:08:46Z',
            'contribution_details': {
              'payment_transfer_id': '5c5a298e-eee1-43a8-8bef-bf74c1fd83c7',
              'rows': [
                {'label': 'Contribution type', 'value': 'New IRA Contribution'},
                {'label': 'Tax year', 'value': '2026'},
                {'label': 'Match percentage', 'value': '3%'},
                {'label': 'Total match amount', 'value': '\$60.00'},
              ],
            },
          },
        ],
        'acats': [
          {
            'id': 'acat_2025_01',
            'phase': 'settled',
            'rhs_account_number': '741902639',
            'settlement_date': '2025-06-15T12:00:00Z',
            'contra_broker_name': 'Merrill Lynch',
            'market_value': '25334.93',
          },
        ],
      });

      final service = DemoService();

      await tester.pumpWidget(
        MaterialApp(
          home: RetirementWidget(
            brokerageUser: user,
            service: service,
            account: traditionalAccount,
            futureHistory: Future.value(mockHistory),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Total contributed shows $3,000.00
      expect(find.text('\$3,000.00'), findsWidgets);

      // Remaining shows $4,000.00
      expect(find.text('\$4,000.00'), findsOneWidget);

      // Transfers & Contributions header is displayed
      expect(find.text('Transfers & Contributions'), findsOneWidget);
      expect(find.text('2 records'), findsOneWidget);

      // Both individual transfer entries are rendered
      expect(find.text('New IRA Contribution'), findsNWidgets(2));
      expect(find.text('\$1,000.00'), findsOneWidget);
      expect(find.text('\$2,000.00'), findsOneWidget);

      // Robinhood Gold Match is rendered
      expect(find.text('Robinhood Match Earned: '), findsOneWidget);
      expect(find.text('\$90.00'), findsWidgets);
      expect(find.text(' (3% Gold Match)'), findsOneWidget);
    });
  });

  group('RetirementTransaction & Unified Transfers Model Tests', () {
    test('parses SDUI contribution rows from paymenthub contribution endpoint', () {
      final sduiJson = {
        'id': '57d18679-7ed7-4bd5-a61e-7cdb46a7ac7b',
        'amount': '1000.00',
        'direction': 'pull',
        'state': 'completed',
        'created_at': '2026-09-25T23:14:45.406284-04:00',
        'originating_account_type': 'rhs_traditional_ira',
        'contribution_details': {
          'payment_transfer_id': '57d18679-7ed7-4bd5-a61e-7cdb46a7ac7b',
          'rows': [
            {
              'sdui_component_type': 'DATA_ROW_STACKED',
              'label': 'Contribution type',
              'value': 'New IRA Contribution',
            },
            {
              'sdui_component_type': 'DATA_ROW_STACKED',
              'label': 'Tax year',
              'value': '2026',
            },
            {
              'sdui_component_type': 'DATA_ROW_STACKED',
              'label': 'Match percentage',
              'value': '3%',
            },
            {
              'sdui_component_type': 'DATA_ROW_STACKED',
              'label': 'Total match amount',
              'value': '\$30.00',
            },
          ],
        },
      };

      final tx = RetirementTransaction.fromJson(sduiJson);

      expect(tx.id, '57d18679-7ed7-4bd5-a61e-7cdb46a7ac7b');
      expect(tx.title, 'New IRA Contribution');
      expect(tx.amount, 1000.0);
      expect(tx.matchAmount, 30.0);
      expect(tx.matchRate, 0.03);
      expect(tx.taxYear, 2026);
      expect(tx.status, 'completed');
      expect(tx.formattedAmount, '\$1,000.00');
      expect(tx.formattedMatchAmount, '\$30.00');
    });

    test('falls back to details.enoki_amount when contribution_details absent', () {
      final transferJson = {
        'id': '5c5a298e-eee1-43a8-8bef-bf74c1fd83c7',
        'amount': '2000.00',
        'created_at': '2026-09-15T01:08:46Z',
        'details': {
          'enoki_amount': {
            'amount': '60',
            'currency_code': 'USD',
          },
        },
      };

      final tx = RetirementTransaction.fromJson(transferJson);

      expect(tx.id, '5c5a298e-eee1-43a8-8bef-bf74c1fd83c7');
      expect(tx.amount, 2000.0);
      expect(tx.matchAmount, 60.0);
      expect(tx.matchRate, 0.03); // 60 / 2000 = 0.03
      expect(tx.taxYear, 2026);
    });

    test('synthesizes multiple unified transfers into RetirementHistory', () {
      final historyJson = {
        'account_number': '741902639',
        'account_type': 'ira_traditional',
        'match_rate': 0.03,
        'results': [], // empty legacy endpoint
        'unified_transfers': [
          {
            'id': '57d18679-7ed7-4bd5-a61e-7cdb46a7ac7b',
            'amount': '1000.00',
            'created_at': '2026-09-25T23:14:45Z',
            'contribution_details': {
              'rows': [
                {'label': 'Contribution type', 'value': 'New IRA Contribution'},
                {'label': 'Tax year', 'value': '2026'},
                {'label': 'Match percentage', 'value': '3%'},
                {'label': 'Total match amount', 'value': '\$30.00'},
              ],
            },
          },
          {
            'id': '5c5a298e-eee1-43a8-8bef-bf74c1fd83c7',
            'amount': '2000.00',
            'created_at': '2026-09-15T01:08:46Z',
            'contribution_details': {
              'rows': [
                {'label': 'Contribution type', 'value': 'New IRA Contribution'},
                {'label': 'Tax year', 'value': '2026'},
                {'label': 'Match percentage', 'value': '3%'},
                {'label': 'Total match amount', 'value': '\$60.00'},
              ],
            },
          },
        ],
        'acats': [
          {
            'phase': 'settled',
            'settlement_date': '2025-06-01T00:00:00Z',
            'contra_broker_name': 'Chase',
            'market_value': '25334.93',
          },
        ],
      };

      final history = RetirementHistory.fromJson(historyJson);

      expect(history.totalContributions, 3000.0);
      expect(history.totalMatch, 90.0);

      final c2026 = history.contributionForYear(2026);
      expect(c2026, isNotNull);
      expect(c2026!.contributionAmount, 3000.0);
      expect(c2026.matchAmount, 90.0);
      expect(c2026.matchRate, 0.03);
      expect(c2026.remainingLimit, 4000.0);
      expect(c2026.transactions.length, 2);

      final c2025 = history.contributionForYear(2025);
      expect(c2025, isNotNull);
      expect(c2025!.rolloverContributions, 25334.93);
      expect(c2025.sourceDescription, 'Rollover from Chase');
    });
  });
}

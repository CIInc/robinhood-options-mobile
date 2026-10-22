import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/retirement.dart';
import 'package:robinhood_options_mobile/model/retirement_projection.dart';
import 'package:robinhood_options_mobile/widgets/retirement_projection_card.dart';

void main() {
  group('RetirementProjectionCalculator Math Tests', () {
    test('calculates 1-year compounding accurately', () {
      const params = RetirementProjectionParams(
        startingBalance: 10000.0,
        annualContribution: 7000.0,
        yearsToRetirement: 1,
        expectedAnnualReturn: 0.10, // 10%
        matchRate: 0.03, // 3%
        taxableAccountTaxDrag: 0.02,
        annualGoldFee: 50.0,
      );

      final result = RetirementProjectionCalculator.calculate(params);

      // Beginning of year:
      // deposits = 7000, match = 7000 * 0.03 = 210
      // balanceWithMatch = (10000 + 7000 + 210) * 1.10 = 17210 * 1.10 = 18931.0
      // balanceWithoutMatch = (10000 + 7000) * 1.10 = 17000 * 1.10 = 18700.0
      expect(result.finalBalance, closeTo(18931.0, 0.01));
      expect(result.finalBalanceWithoutMatch, closeTo(18700.0, 0.01));
      expect(result.compoundedMatchAddedWealth, closeTo(231.0, 0.01));
      expect(result.totalUserContributions, 17000.0);
      expect(result.totalMatchBonusesEarned, 210.0);
      expect(result.yearOneNetGoldBonus, 160.0); // 210 - 50
      expect(result.goldBreakEvenAnnualContribution, closeTo(1666.67, 0.01));
      expect(result.yearlyBreakdown.length, 1);
    });

    test('calculates 25-year compounding with Robinhood Gold 3% match', () {
      const params = RetirementProjectionParams(
        startingBalance: 10000.0,
        annualContribution: 7000.0,
        yearsToRetirement: 25,
        expectedAnnualReturn: 0.08,
        matchRate: 0.03,
      );

      final result = RetirementProjectionCalculator.calculate(params);

      expect(result.yearlyBreakdown.length, 25);
      expect(result.totalUserContributions, 10000.0 + 25 * 7000.0); // 185,000
      expect(result.totalMatchBonusesEarned, 25 * (7000.0 * 0.03)); // 5,250
      expect(result.finalBalance, greaterThan(result.finalBalanceWithoutMatch));
      expect(result.finalBalance,
          greaterThan(result.finalBalanceWithStandardMatch));
      expect(result.compoundedMatchAddedWealth, greaterThan(15000.0));
      expect(result.lifetimeTaxAdvantage, greaterThan(0));
      expect(result.userContributionShare, inInclusiveRange(0.0, 1.0));
      expect(result.investmentGrowthShare, inInclusiveRange(0.0, 1.0));
      expect(result.matchShare, inInclusiveRange(0.0, 1.0));
    });

    test('handles 0% return gracefully', () {
      const params = RetirementProjectionParams(
        startingBalance: 0.0,
        annualContribution: 6000.0,
        yearsToRetirement: 5,
        expectedAnnualReturn: 0.0,
        matchRate: 0.03,
      );

      final result = RetirementProjectionCalculator.calculate(params);

      // Total contributed: 5 * 6000 = 30000
      // Total match: 5 * 180 = 900
      // Final: 30900
      expect(result.finalBalance, closeTo(30900.0, 0.01));
      expect(result.finalBalanceWithoutMatch, closeTo(30000.0, 0.01));
      expect(result.compoundedMatchAddedWealth, closeTo(900.0, 0.01));
      expect(result.totalInvestmentGrowth, closeTo(0.0, 0.01));
    });

    test('handles negative returns without crashing', () {
      const params = RetirementProjectionParams(
        startingBalance: 10000.0,
        annualContribution: 5000.0,
        yearsToRetirement: 3,
        expectedAnnualReturn: -0.05,
        matchRate: 0.01,
      );

      final result = RetirementProjectionCalculator.calculate(params);
      expect(result.finalBalance, greaterThan(0));
      expect(result.yearlyBreakdown.length, 3);
    });

    test('roundtrips params and yearly data to and from json', () {
      const params = RetirementProjectionParams(
        startingBalance: 15000.0,
        annualContribution: 8000.0,
        yearsToRetirement: 30,
        expectedAnnualReturn: 0.09,
        matchRate: 0.03,
      );

      final json = params.toJson();
      final parsed = RetirementProjectionParams.fromJson(json);

      expect(parsed.startingBalance, params.startingBalance);
      expect(parsed.annualContribution, params.annualContribution);
      expect(parsed.yearsToRetirement, params.yearsToRetirement);
      expect(parsed.expectedAnnualReturn, params.expectedAnnualReturn);
      expect(parsed.matchRate, params.matchRate);

      final result = RetirementProjectionCalculator.calculate(params);
      final resultJson = result.toJson();
      expect(resultJson['final_balance'], isNotNull);
      expect(resultJson['yearly_breakdown'], isList);
    });
  });

  group('RetirementProjectionCard Widget Tests', () {
    testWidgets('renders hero balance, progress bar, and Gold maximizer card',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RetirementProjectionCard(
                initialBalance: 10000.0,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Retirement Planner & Gold Maximizer'), findsOneWidget);
      expect(
          find.textContaining('PROJECTED RETIREMENT BALANCE'), findsOneWidget);
      expect(find.text('Robinhood Gold 3% Match Optimizer'), findsOneWidget);
      expect(find.text('Customize Projection Parameters'), findsOneWidget);
      expect(find.text('Tax-Advantaged Growth vs. Taxable Account'),
          findsOneWidget);
      expect(find.text('5-Year Forecast Milestones'), findsOneWidget);
    });

    testWidgets('updates projection when tapping return and match choice chips',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RetirementProjectionCard(
                initialBalance: 5000.0,
              ),
            ),
          ),
        ),
      );

      // Verify default shows 8.0% return
      expect(find.textContaining('at 8.0% return'), findsOneWidget);

      // Tap Aggressive (10%) chip
      await tester.ensureVisible(find.text('Aggressive (10%)'));
      await tester.tap(find.text('Aggressive (10%)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('at 10.0% return'), findsOneWidget);

      // Tap Standard (1%) match chip
      await tester.ensureVisible(find.text('Standard (1%)'));
      await tester.tap(find.text('Standard (1%)'));
      await tester.pumpAndSettle();

      expect(find.text('1% Match'), findsOneWidget);
    });

    testWidgets('expands and collapses tax comparison and milestones',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RetirementProjectionCard(
                initialBalance: 5000.0,
              ),
            ),
          ),
        ),
      );

      // Expand tax comparison
      final taxTile = find.text('Tax-Advantaged Growth vs. Taxable Account');
      await tester.ensureVisible(taxTile);
      await tester.tap(taxTile);
      await tester.pumpAndSettle();

      expect(find.text('Why Tax Shelters Win:'), findsOneWidget);
      expect(find.text('IRA Account'), findsOneWidget);
      expect(find.text('Taxable Account'), findsOneWidget);

      // Expand milestones
      final milestonesTile = find.text('5-Year Forecast Milestones');
      await tester.ensureVisible(milestonesTile);
      await tester.tap(milestonesTile);
      await tester.pumpAndSettle();

      expect(find.text('Year 5'), findsOneWidget);
      expect(find.text('Year 10'), findsOneWidget);
      expect(find.text('Year 25'), findsOneWidget);
    });

    testWidgets('initializes with current contribution and catch-up limits',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const contrib = RetirementContribution(
        year: 2026,
        contributionAmount: 3000.0,
        matchAmount: 90.0,
        matchRate: 0.03,
        limit: 7000.0,
        catchUpLimit: 8000.0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RetirementProjectionCard(
                currentContribution: contrib,
                initialCatchUp: true,
              ),
            ),
          ),
        ),
      );

      // Should initialize to $8,000 with catch up
      expect(find.text('\$8,000.00/yr'), findsOneWidget);
      expect(find.text('3% Match'), findsOneWidget);
    });

    testWidgets(
        'renders correct semantics labels for mini metrics and progress bar',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RetirementProjectionCard(
                initialBalance: 10000.0,
              ),
            ),
          ),
        ),
      );

      final handle = tester.ensureSemantics();

      // Check mini metric semantics
      expect(
        find.bySemanticsLabel(RegExp(r'You Deposit: \$[0-9,]+')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Market Growth: \$[0-9,]+')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Match Added: \$[0-9,]+')),
        findsOneWidget,
      );

      // Check stacked progress bar semantics
      expect(
        find.bySemanticsLabel(RegExp(
            r'Retirement balance breakdown: .* principal.* compounding growth')),
        findsOneWidget,
      );

      // Check Gold stat box semantics
      expect(
        find.bySemanticsLabel(
            RegExp(r'Year 1 Match Bonus: \$[0-9,]+\.[0-9]{2}\..*')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
            RegExp(r'Gold Fee Break-Even: \$[0-9,]+\.[0-9]{2}\..*')),
        findsOneWidget,
      );

      // Expand tax comparison and check semantics
      final taxTile = find.text('Tax-Advantaged Growth vs. Taxable Account');
      await tester.ensureVisible(taxTile);
      await tester.tap(taxTile);
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'IRA Account: \$[0-9,]+\.[0-9]{2}\..*')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
            RegExp(r'Taxable Account: \$[0-9,]+\.[0-9]{2}\..*')),
        findsOneWidget,
      );

      // Expand milestones and check semantics
      final milestonesTile = find.text('5-Year Forecast Milestones');
      await tester.ensureVisible(milestonesTile);
      await tester.tap(milestonesTile);
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'Year 5: \$[0-9,]+\.[0-9]{2}.*')),
        findsOneWidget,
      );

      handle.dispose();
    });
  });
}

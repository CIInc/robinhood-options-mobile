import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/retirement.dart';
import 'package:robinhood_options_mobile/model/retirement_projection.dart';

final _currencyFormat = NumberFormat.simpleCurrency();

/// Interactive widget providing IRA compounding projections, tax advantage comparisons,
/// and Robinhood Gold 3% match optimization analysis.
class RetirementProjectionCard extends StatefulWidget {
  final RetirementContribution? currentContribution;
  final double initialBalance;
  final bool initialCatchUp;

  const RetirementProjectionCard({
    super.key,
    this.currentContribution,
    this.initialBalance = 10000.0,
    this.initialCatchUp = false,
  });

  @override
  State<RetirementProjectionCard> createState() =>
      _RetirementProjectionCardState();
}

class _RetirementProjectionCardState extends State<RetirementProjectionCard> {
  late double _startingBalance;
  late double _annualContribution;
  int _yearsToRetirement = 25;
  double _expectedAnnualReturn = 0.08;
  double _matchRate = 0.03; // Default to Robinhood Gold 3% match
  bool _showMilestones = false;
  bool _showTaxComparison = false;

  @override
  void initState() {
    super.initState();
    _startingBalance = widget.initialBalance;

    // Use current tax year limit or catch-up limit as starting point
    final defaultLimit = widget.initialCatchUp
        ? (widget.currentContribution?.catchUpLimit ?? 8000.0)
        : (widget.currentContribution?.limit ?? 7000.0);
    _annualContribution = defaultLimit;

    if (widget.currentContribution != null &&
        widget.currentContribution!.matchRate > 0) {
      _matchRate = widget.currentContribution!.matchRate;
    }
  }

  RetirementProjectionResult get _result {
    final params = RetirementProjectionParams(
      startingBalance: _startingBalance,
      annualContribution: _annualContribution,
      yearsToRetirement: _yearsToRetirement,
      expectedAnnualReturn: _expectedAnnualReturn,
      matchRate: _matchRate,
    );
    return RetirementProjectionCalculator.calculate(params);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final res = _result;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildHeroBalance(context, res),
            const SizedBox(height: 16),
            _buildStackedProgressBar(context, res),
            const SizedBox(height: 20),
            _buildGoldMaximizerCard(context, res),
            const SizedBox(height: 20),
            _buildInteractiveControls(context),
            const SizedBox(height: 16),
            _buildTaxAdvantageToggle(context, res),
            const SizedBox(height: 12),
            _buildMilestonesToggle(context, res),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.auto_graph, color: Colors.amber, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Retirement Planner & Gold Maximizer',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'IRA Compounding, Tax Advantages & 3% Match',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBalance(
      BuildContext context, RetirementProjectionResult res) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROJECTED RETIREMENT BALANCE ($_yearsToRetirement YEARS)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                res.formattedFinalBalance,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'at ${(_expectedAnnualReturn * 100).toStringAsFixed(1)}% return',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniMetric(
                context,
                'You Deposit',
                res.formattedUserContributions,
                colorScheme.primary,
              ),
              _buildMiniMetric(
                context,
                'Market Growth',
                res.formattedInvestmentGrowth,
                Colors.green,
              ),
              _buildMiniMetric(
                context,
                'Match Added',
                res.formattedCompoundedMatchAddedWealth,
                Colors.amber,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(
      BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedProgressBar(
      BuildContext context, RetirementProjectionResult res) {
    final colorScheme = Theme.of(context).colorScheme;
    final total = res.finalBalance;
    if (total <= 0) return const SizedBox.shrink();

    final contribRatio = res.userContributionShare;
    final growthRatio = res.investmentGrowthShare;
    final matchRatio = res.matchShare;

    final contribPct = (contribRatio * 100).toStringAsFixed(0);
    final matchPct = (matchRatio * 100).toStringAsFixed(1);
    final growthPct = (growthRatio * 100).toStringAsFixed(0);

    final semanticLabel = matchRatio > 0
        ? 'Retirement balance breakdown: $contribPct% principal, $matchPct% match wealth, $growthPct% compounding growth'
        : 'Retirement balance breakdown: $contribPct% principal, $growthPct% compounding growth';

    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (contribRatio > 0)
                    Expanded(
                      flex: (contribRatio * 1000).toInt(),
                      child: Container(color: colorScheme.primary),
                    ),
                  if (matchRatio > 0)
                    Expanded(
                      flex: (matchRatio * 1000).toInt(),
                      child: Container(color: Colors.amber),
                    ),
                  if (growthRatio > 0)
                    Expanded(
                      flex: (growthRatio * 1000).toInt(),
                      child: Container(color: Colors.green),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$contribPct% Principal',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (matchRatio > 0)
                Text(
                  '$matchPct% Match Wealth',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.amber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                '$growthPct% Compounding',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoldMaximizerCard(
      BuildContext context, RetirementProjectionResult res) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isGold = _matchRate >= 0.03;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isGold
            ? Colors.amber.withValues(alpha: 0.08)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGold
              ? Colors.amber.withValues(alpha: 0.4)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star,
                size: 18,
                color: isGold ? Colors.amber : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Robinhood Gold 3% Match Optimizer',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isGold ? Colors.amber.shade900 : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isGold
                      ? Colors.amber.withValues(alpha: 0.2)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(_matchRate * 100).toStringAsFixed(0)}% Match',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isGold ? Colors.amber.shade900 : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isGold
                ? 'With Robinhood Gold, your \$${_annualContribution.toStringAsFixed(0)} annual contribution generates ${res.formattedTotalMatch} in cash bonuses over $_yearsToRetirement years, compounding to ${res.formattedCompoundedMatchAddedWealth} in extra retirement wealth.'
                : 'Standard Robinhood accounts earn a 1% match. Upgrading to Robinhood Gold unlocks a 3% match, tripling your annual bonus payments.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildGoldStatBox(
                  context,
                  'Year 1 Match Bonus',
                  _currencyFormat.format(_annualContribution * _matchRate),
                  'Net +${res.formattedYearOneNetGoldBonus} after \$50 Gold fee',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildGoldStatBox(
                  context,
                  'Gold Fee Break-Even',
                  res.formattedGoldBreakEven,
                  'Annual contribution needed',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined,
                    size: 14, color: colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Robinhood Gold 3% IRA matches must be retained in your account for 5 years to keep the match bonus.',
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoldStatBox(
      BuildContext context, String title, String value, String subtitle) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveControls(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Customize Projection Parameters',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        // 1. Annual Contribution Slider & Chips
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Annual Contribution',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${_currencyFormat.format(_annualContribution)}/yr',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        Slider(
          value: _annualContribution.clamp(1000.0, 8000.0),
          min: 1000.0,
          max: 8000.0,
          divisions: 14,
          label: _currencyFormat.format(_annualContribution),
          onChanged: (val) {
            setState(() {
              _annualContribution = val;
            });
          },
        ),
        Wrap(
          spacing: 6,
          children: [
            _buildChoiceChip('Max 2026 (\$7,000)', _annualContribution == 7000.0,
                () {
              setState(() => _annualContribution = 7000.0);
            }),
            _buildChoiceChip(
                'Catch-Up (\$8,000)', _annualContribution == 8000.0, () {
              setState(() => _annualContribution = 8000.0);
            }),
            _buildChoiceChip('\$500/mo (\$6,000)', _annualContribution == 6000.0,
                () {
              setState(() => _annualContribution = 6000.0);
            }),
            _buildChoiceChip('\$250/mo (\$3,000)', _annualContribution == 3000.0,
                () {
              setState(() => _annualContribution = 3000.0);
            }),
          ],
        ),

        const SizedBox(height: 16),

        // 2. Horizon Slider & Chips
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Years to Retirement',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$_yearsToRetirement Years',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        Slider(
          value: _yearsToRetirement.toDouble().clamp(5.0, 40.0),
          min: 5.0,
          max: 40.0,
          divisions: 35,
          label: '$_yearsToRetirement Years',
          onChanged: (val) {
            setState(() {
              _yearsToRetirement = val.round();
            });
          },
        ),
        Wrap(
          spacing: 6,
          children: [
            _buildChoiceChip('10 Yrs', _yearsToRetirement == 10,
                () => setState(() => _yearsToRetirement = 10)),
            _buildChoiceChip('20 Yrs', _yearsToRetirement == 20,
                () => setState(() => _yearsToRetirement = 20)),
            _buildChoiceChip('25 Yrs', _yearsToRetirement == 25,
                () => setState(() => _yearsToRetirement = 25)),
            _buildChoiceChip('30 Yrs', _yearsToRetirement == 30,
                () => setState(() => _yearsToRetirement = 30)),
            _buildChoiceChip('40 Yrs', _yearsToRetirement == 40,
                () => setState(() => _yearsToRetirement = 40)),
          ],
        ),

        const SizedBox(height: 16),

        // 3. Expected Annual Return Chips & Slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Expected Annual Return',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(_expectedAnnualReturn * 100).toStringAsFixed(1)}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        Slider(
          value: _expectedAnnualReturn.clamp(0.04, 0.12),
          min: 0.04,
          max: 0.12,
          divisions: 16,
          label: '${(_expectedAnnualReturn * 100).toStringAsFixed(1)}%',
          onChanged: (val) {
            setState(() {
              _expectedAnnualReturn = val;
            });
          },
        ),
        Wrap(
          spacing: 6,
          children: [
            _buildChoiceChip(
                'Conservative (6%)',
                (_expectedAnnualReturn - 0.06).abs() < 0.005,
                () => setState(() => _expectedAnnualReturn = 0.06)),
            _buildChoiceChip(
                'Moderate (8%)',
                (_expectedAnnualReturn - 0.08).abs() < 0.005,
                () => setState(() => _expectedAnnualReturn = 0.08)),
            _buildChoiceChip(
                'Aggressive (10%)',
                (_expectedAnnualReturn - 0.10).abs() < 0.005,
                () => setState(() => _expectedAnnualReturn = 0.10)),
          ],
        ),

        const SizedBox(height: 16),

        // 4. Match Rate Selector
        Text(
          'Robinhood Match Tier',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            _buildChoiceChip(
                'Robinhood Gold (3%)',
                _matchRate == 0.03,
                () => setState(() => _matchRate = 0.03)),
            _buildChoiceChip(
                'Standard (1%)',
                _matchRate == 0.01,
                () => setState(() => _matchRate = 0.01)),
            _buildChoiceChip(
                'Other Brokerage (0%)',
                _matchRate == 0.0,
                () => setState(() => _matchRate = 0.0)),
          ],
        ),
      ],
    );
  }

  Widget _buildChoiceChip(String label, bool selected, VoidCallback onSelected) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }

  Widget _buildTaxAdvantageToggle(
      BuildContext context, RetirementProjectionResult res) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.account_balance, color: Colors.green, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Tax-Advantaged Growth vs. Taxable Account',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          'Tax savings estimate: +${res.formattedLifetimeTaxAdvantage}',
          style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
        ),
        initiallyExpanded: _showTaxComparison,
        onExpansionChanged: (val) => setState(() => _showTaxComparison = val),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildComparisonColumn(
                        context,
                        'IRA Account',
                        res.formattedFinalBalance,
                        '100% Tax-Free Compounding',
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildComparisonColumn(
                        context,
                        'Taxable Account',
                        _currencyFormat.format(res.finalTaxableBalance),
                        'Subject to annual tax drag (~1.5%)',
                        colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  'Why Tax Shelters Win:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '• In a Roth IRA, you pay no tax on capital gains, dividends, or withdrawals in retirement.\n'
                  '• In a Traditional IRA, contributions are tax-deductible today, deferring taxes until distribution.\n'
                  '• In a standard taxable brokerage account, yearly dividend taxes and turnover drag reduce effective returns by 1.0%–2.0% annually, compounding into ${res.formattedLifetimeTaxAdvantage} in lost growth over $_yearsToRetirement years.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonColumn(BuildContext context, String title,
      String amount, String note, Color amountColor) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(
          amount,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: amountColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          note,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildMilestonesToggle(
      BuildContext context, RetirementProjectionResult res) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final milestones = res.yearlyBreakdown
        .where((y) => y.year % 5 == 0 || y.year == _yearsToRetirement)
        .toList();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            const Icon(Icons.table_chart_outlined, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '5-Year Forecast Milestones',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        initiallyExpanded: _showMilestones,
        onExpansionChanged: (val) => setState(() => _showMilestones = val),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: milestones.map((m) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Year ${m.year}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _currencyFormat.format(m.balanceWithMatch),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      if (m.cumulativeMatch > 0)
                        Text(
                          '+${_currencyFormat.format(m.matchWealthGenerated)} match',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.amber,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

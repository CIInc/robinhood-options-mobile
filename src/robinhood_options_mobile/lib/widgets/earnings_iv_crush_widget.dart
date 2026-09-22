import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/earnings_iv_crush_model.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/earnings_iv_crush_service.dart';

/// Interactive UI Dashboard for Earnings Implied Volatility (IV) Crush analysis,
/// 12-quarter empirical implied vs. actual moves, and ATM Straddle EV estimation.
class EarningsIvCrushWidget extends StatefulWidget {
  final String symbol;
  final double? spotPrice;
  final User? user;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final Instrument? instrument;
  final List<dynamic>? rawEarnings;
  final List<Map<String, dynamic>>? optionsChains;
  final EarningsIvCrushAnalysis? precomputedAnalysis;
  final VoidCallback? onTradeOptions;

  const EarningsIvCrushWidget({
    super.key,
    required this.symbol,
    this.spotPrice,
    this.user,
    this.brokerageUser,
    this.service,
    this.instrument,
    this.rawEarnings,
    this.optionsChains,
    this.precomputedAnalysis,
    this.onTradeOptions,
  });

  @override
  State<EarningsIvCrushWidget> createState() => _EarningsIvCrushWidgetState();
}

class _EarningsIvCrushWidgetState extends State<EarningsIvCrushWidget> {
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_US', symbol: '\$');
  final NumberFormat _percentFormat =
      NumberFormat.percentPattern('en_US')..maximumFractionDigits = 1;

  late EarningsIvCrushAnalysis _analysis;
  bool _isLoading = false;
  String? _errorMessage;
  int _viewModeIndex = 0; // 0: Chart View, 1: Details Table
  bool _isEducationExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.precomputedAnalysis != null) {
      _analysis = widget.precomputedAnalysis!;
    } else {
      _loadAnalysis();
    }
  }

  @override
  void didUpdateWidget(EarningsIvCrushWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.precomputedAnalysis != null &&
        widget.precomputedAnalysis != oldWidget.precomputedAnalysis) {
      setState(() {
        _analysis = widget.precomputedAnalysis!;
      });
    } else if (widget.symbol != oldWidget.symbol ||
        widget.spotPrice != oldWidget.spotPrice) {
      _loadAnalysis();
    }
  }

  Future<void> _loadAnalysis() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<dynamic>? earningsData = widget.rawEarnings;

      if (earningsData == null &&
          widget.service != null &&
          widget.brokerageUser != null &&
          widget.instrument != null) {
        try {
          earningsData = await widget.service!
              .getEarnings(widget.brokerageUser!, widget.instrument!.id);
        } catch (_) {
          // Fall back to calibrated data if network request fails
        }
      }

      final spot = widget.spotPrice ??
          widget.instrument?.quoteObj?.lastTradePrice ??
          150.0;

      final analysis = EarningsIvCrushService.computeAnalysis(
        symbol: widget.symbol,
        spotPrice: spot,
        rawEarnings: earningsData,
        optionsChains: widget.optionsChains,
      );

      if (mounted) {
        setState(() {
          _analysis = analysis;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to calculate earnings IV crush analysis: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.symbol} Earnings IV Crush'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('${widget.symbol} Earnings IV Crush'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadAnalysis,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${_analysis.symbol} Earnings IV Crush'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Analysis',
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadAnalysis();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalysis,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildCountdownHeader(theme),
            const SizedBox(height: 16.0),
            _buildProbabilityHeroCard(theme),
            const SizedBox(height: 16.0),
            if (_analysis.straddleEstimate != null) ...[
              _buildStraddlePricingCard(theme, _analysis.straddleEstimate!),
              const SizedBox(height: 16.0),
            ],
            _buildHistoricalMoveCard(theme),
            const SizedBox(height: 16.0),
            _buildEducationCard(theme),
            const SizedBox(height: 24.0),
            if (widget.onTradeOptions != null)
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onTradeOptions!();
                },
                icon: const Icon(Icons.trending_up),
                label: const Text('Trade Options for Earnings'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            const SizedBox(height: 32.0),
          ],
        ),
      ),
    );
  }

  /// Top header with symbol, spot price, and next earnings countdown
  Widget _buildCountdownHeader(ThemeData theme) {
    final nextDate = _analysis.nextEarningsDate;
    final days = _analysis.daysToEarnings;

    String dateText = 'Upcoming Date Pending';
    if (nextDate != null) {
      dateText = DateFormat('EEE, MMM d, yyyy').format(nextDate);
    }

    String countdownBadge = 'Date Unconfirmed';
    Color badgeColor = Colors.grey.shade700;
    if (days != null) {
      if (days == 0) {
        countdownBadge = 'Reports Today!';
        badgeColor = theme.colorScheme.error;
      } else if (days == 1) {
        countdownBadge = 'Reports Tomorrow';
        badgeColor = Colors.deepOrange;
      } else if (days <= 7) {
        countdownBadge = 'In $days Days';
        badgeColor = Colors.amber.shade800;
      } else {
        countdownBadge = 'In $days Days';
        badgeColor = theme.colorScheme.primary;
      }
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _analysis.symbol,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _currencyFormat.format(_analysis.spotPrice),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          dateText,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                countdownBadge,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Radial / Gauge Hero Card visualizing the IV Crush Probability
  Widget _buildProbabilityHeroCard(ThemeData theme) {
    final summary = _analysis.summary;
    final tier = summary.riskTier;
    final tierColor = tier.color(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: tierColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(tier.icon, color: tierColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: tierColor,
                        ),
                      ),
                      Text(
                        'Based on ${summary.quartersAnalyzed} Historical Quarters',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Circular mini-gauge
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: CircularProgressIndicator(
                        value: summary.crushProbabilityScore / 100.0,
                        backgroundColor:
                            theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        color: tierColor,
                        strokeWidth: 6.0,
                      ),
                    ),
                    Text(
                      '${summary.crushProbabilityScore.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              tier.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // IV comparison metrics chips
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Current Pre-IV',
                    value: _percentFormat.format(_analysis.currentIv),
                    sublabel: 'Front Expiration',
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Expected Post-IV',
                    value:
                        _percentFormat.format(_analysis.postEarningsEstimatedIv),
                    sublabel: 'Estimated Base',
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Avg. IV Crush',
                    value: '-${summary.averageIvCrushPct.toStringAsFixed(1)}%',
                    sublabel: 'Post-Report Drop',
                    valueColor: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Front-month ATM straddle pricing and Expected Value (EV) evaluation
  Widget _buildStraddlePricingCard(
      ThemeData theme, StraddlePricingEstimate straddle) {
    final rec = straddle.recommendedStrategy;
    final recColor = rec.color(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calculate_outlined,
                      color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'ATM Straddle Pricing & EV',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Strike: \$${straddle.atmStrike.toStringAsFixed(straddle.atmStrike % 1 == 0 ? 0 : 2)}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Straddle metrics grid
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Straddle Cost',
                    value: _currencyFormat.format(straddle.straddleCost),
                    sublabel: '${straddle.straddleCostPct.toStringAsFixed(1)}% of Spot',
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Implied Move',
                    value: '±${straddle.impliedMovePct.toStringAsFixed(1)}%',
                    sublabel:
                        '±${_currencyFormat.format(straddle.straddleCost)}',
                    valueColor: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    theme,
                    label: 'Breakevens',
                    value:
                        '${_currencyFormat.format(straddle.lowerBreakeven)} - ${_currencyFormat.format(straddle.upperBreakeven)}',
                    sublabel: 'Upper & Lower',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // Expected Value (EV) comparisons
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (straddle.shortStraddleEv >= 0
                              ? Colors.green
                              : theme.colorScheme.error)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (straddle.shortStraddleEv >= 0
                                ? Colors.green
                                : theme.colorScheme.error)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sell_outlined,
                                size: 16, color: Colors.purple),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Straddle Seller EV',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${straddle.shortStraddleEv >= 0 ? '+' : ''}${_currencyFormat.format(straddle.shortStraddleEv)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: straddle.shortStraddleEv >= 0
                                ? Colors.green
                                : theme.colorScheme.error,
                          ),
                        ),
                        Text(
                          'Win Rate: ${straddle.sellerWinProbability.toStringAsFixed(0)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (straddle.longStraddleEv >= 0
                              ? Colors.green
                              : theme.colorScheme.error)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (straddle.longStraddleEv >= 0
                                ? Colors.green
                                : theme.colorScheme.error)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.shopping_bag_outlined,
                                size: 16, color: Colors.teal),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Straddle Buyer EV',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${straddle.longStraddleEv >= 0 ? '+' : ''}${_currencyFormat.format(straddle.longStraddleEv)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: straddle.longStraddleEv >= 0
                                ? Colors.green
                                : theme.colorScheme.error,
                          ),
                        ),
                        Text(
                          'Win Rate: ${straddle.buyerWinProbability.toStringAsFixed(0)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Tactical Recommendation banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: recColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: recColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(rec.icon, color: recColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recommendation: ${rec.label}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: recColor,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          straddle.recommendationReason,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 12-Quarter Historical Move & Crush Matrix Card
  Widget _buildHistoricalMoveCard(ThemeData theme) {
    final quarters = _analysis.quarters;
    final summary = _analysis.summary;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.history_edu_rounded,
                      color: Colors.amber.shade800, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '12-Quarter Move History',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Implied vs. Actual Moves & IV Collapse',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                        value: 0,
                        icon: Icon(Icons.bar_chart_rounded, size: 16)),
                    ButtonSegment(
                        value: 1, icon: Icon(Icons.table_rows_rounded, size: 16)),
                  ],
                  selected: {_viewModeIndex},
                  onSelectionChanged: (val) {
                    setState(() {
                      _viewModeIndex = val.first;
                    });
                  },
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Summary chips
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Avg. Implied: ±${summary.averageImpliedMovePct.toStringAsFixed(1)}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(
                  'Avg. Actual: ±${summary.averageActualMovePct.toStringAsFixed(1)}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(
                  'Overpriced: ${summary.overpricingRatePct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: summary.overpricingRatePct >= 60
                        ? Colors.green
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            // View Mode 0: Comparison Bars; View Mode 1: Detailed Table
            if (_viewModeIndex == 0)
              ...quarters.map((q) => _buildQuarterComparisonBar(theme, q))
            else
              ...quarters.map((q) => _buildQuarterDetailTile(theme, q)),
          ],
        ),
      ),
    );
  }

  /// Comparison bar for a single quarter
  Widget _buildQuarterComparisonBar(ThemeData theme, EarningsQuarterRecord q) {
    final maxScale = 15.0;
    final impliedWidth = (q.impliedMovePct / maxScale).clamp(0.05, 1.0);
    final actualWidth = (q.actualMovePct / maxScale).clamp(0.05, 1.0);
    final isUp = q.moveDirection >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 75,
                child: Text(
                  q.quarterLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: q.beatMiss.color(context).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  q.beatMiss.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: q.beatMiss.color(context),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${isUp ? '+' : ''}${q.moveDirection.toStringAsFixed(1)}% move',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isUp ? Colors.green : theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (q.impliedOverpriced
                          ? Colors.purple
                          : theme.colorScheme.primary)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  q.impliedOverpriced ? 'Seller Won' : 'Buyer Won',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: q.impliedOverpriced
                        ? Colors.purple
                        : theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Implied move bar
          Row(
            children: [
              SizedBox(
                width: 55,
                child: Text(
                  'Implied:',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 8,
                          width: constraints.maxWidth * impliedWidth,
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 45,
                child: Text(
                  '±${q.impliedMovePct.toStringAsFixed(1)}%',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Actual move bar
          Row(
            children: [
              SizedBox(
                width: 55,
                child: Text(
                  'Actual:',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 8,
                          width: constraints.maxWidth * actualWidth,
                          decoration: BoxDecoration(
                            color: (isUp ? Colors.green : theme.colorScheme.error)
                                .withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 45,
                child: Text(
                  '${isUp ? '+' : ''}${q.actualMovePct.toStringAsFixed(1)}%',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isUp ? Colors.green : theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'IV Crush: -${q.ivCrushPct.toStringAsFixed(0)}% (pre: ${(q.preEarningsIv * 100).toStringAsFixed(0)}% → post: ${(q.postEarningsIv * 100).toStringAsFixed(0)}%)',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Detail tile for a single quarter (table mode)
  Widget _buildQuarterDetailTile(ThemeData theme, EarningsQuarterRecord q) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                q.quarterLabel,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('MM/dd/yy').format(q.reportDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (q.epsActual != null && q.epsEstimate != null)
                Text(
                  'EPS: \$${q.epsActual!.toStringAsFixed(2)} vs \$${q.epsEstimate!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: q.beatMiss.color(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Implied: ±${q.impliedMovePct.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                'Actual: ${q.moveDirection >= 0 ? '+' : ''}${q.moveDirection.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: q.moveDirection >= 0
                      ? Colors.green
                      : theme.colorScheme.error,
                ),
              ),
              Text(
                'Crush: -${q.ivCrushPct.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Educational card explaining IV crush and tactics
  Widget _buildEducationCard(ThemeData theme) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _isEducationExpanded = !_isEducationExpanded;
                });
              },
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'What is Earnings IV Crush?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isEducationExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            if (_isEducationExpanded) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Implied Volatility (IV) measures the market\'s expectation of price movement. '
                'Ahead of quarterly earnings, uncertainty spikes, driving option extrinsic value higher. '
                'The instant earnings numbers cross the tape, that uncertainty vanishes, causing IV to plummet—often by 40% to 60% within minutes.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 8),
              Text(
                '• The Retail Trap: Buying out-of-the-money (OTM) calls or puts before earnings is dangerous. Even if the stock moves in your direction, the IV collapse can easily erase the entire option value.\n'
                '• Defined-Risk Selling: Credit spreads, iron condors, and covered strangles benefit from IV crush because high premium collapses into your favor post-earnings.\n'
                '• Calendar Spreads: Selling the front-month elevated IV option while buying a farther-dated option captures the front IV collapse while protecting delta.',
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Metric display tile helper
  Widget _buildMetricTile(
    ThemeData theme, {
    required String label,
    required String value,
    required String sublabel,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          sublabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

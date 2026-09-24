import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/top_portfolio_entry.dart';
import 'package:robinhood_options_mobile/model/trader_comparison_model.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/trader_profile_widget.dart';
import 'package:share_plus/share_plus.dart';

/// Side-by-side comparison screen for evaluating 2 to 4 potential copy-trading leaders
/// or top-performing portfolios across normalized periods and risk-adjusted metrics.
class TraderComparisonWidget extends StatefulWidget {
  final List<TopPortfolioEntry> initialTraders;
  final LeaderboardTimePeriod initialPeriod;
  final firebase_auth.FirebaseAuth auth;
  final FirestoreService firestoreService;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;

  const TraderComparisonWidget({
    super.key,
    required this.initialTraders,
    this.initialPeriod = LeaderboardTimePeriod.allTime,
    required this.auth,
    required this.firestoreService,
    required this.analytics,
    required this.observer,
    this.brokerageUser,
    this.service,
  });

  @override
  State<TraderComparisonWidget> createState() => _TraderComparisonWidgetState();
}

class _TraderComparisonWidgetState extends State<TraderComparisonWidget> {
  late LeaderboardTimePeriod _selectedPeriod;
  late List<TopPortfolioEntry> _traders;
  late TraderComparisonSummary _summary;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = widget.initialPeriod;
    _traders = List<TopPortfolioEntry>.from(widget.initialTraders);
    _recalculateSummary();

    widget.analytics.logScreenView(
      screenName: 'trader_comparison',
      screenClass: 'TraderComparisonWidget',
    );
  }

  void _recalculateSummary() {
    setState(() {
      _summary = TraderComparisonSummary.build(
        traders: _traders,
        period: _selectedPeriod,
      );
    });
  }

  void _removeTrader(int index) {
    if (_traders.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least 2 traders are required for comparison.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _traders.removeAt(index);
      _recalculateSummary();
    });
  }

  void _shareComparison() {
    final buffer = StringBuffer();
    buffer.writeln('Trader Comparison (${_selectedPeriod.label} Period):');
    for (int i = 0; i < _traders.length; i++) {
      final t = _traders[i];
      final ret = t.returnForPeriod(_selectedPeriod);
      buffer.writeln(
          '• ${t.userName}: ${ret >= 0 ? '+' : ''}${ret.toStringAsFixed(1)}% Return, ${t.winRate.toStringAsFixed(1)}% Win Rate, Sharpe: ${t.sharpeRatio.toStringAsFixed(2)}');
    }
    buffer.writeln('\nCompared via Robinhood Options Mobile');

    SharePlus.instance.share(ShareParams(
      text: buffer.toString(),
      subject: 'Trader Comparison Report',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? theme.colorScheme.surface
          : theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trader Comparison',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Comparing ${_traders.length} Potential Leaders',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Comparison',
            onPressed: _shareComparison,
          ),
        ],
      ),
      body: _traders.isEmpty
          ? const Center(child: Text('No traders selected for comparison.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Period Selection Chips
                  _buildPeriodSelector(theme),

                  // Privacy Safeguards Banner
                  _buildPrivacyBanner(theme),

                  const SizedBox(height: 8),

                  // Trader Profiles Header Row
                  _buildTraderHeaderColumns(theme),

                  const SizedBox(height: 12),

                  // Relative Strengths Dimension Bars
                  _buildRelativeStrengthCard(theme),

                  const SizedBox(height: 12),

                  // Metric Categories
                  ..._buildCategorySections(theme),
                ],
              ),
            ),
    );
  }

  /// Horizontal timeframe filter chips
  Widget _buildPeriodSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Timeframe:',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: LeaderboardTimePeriod.values.map((period) {
                  final isSelected = _selectedPeriod == period;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(period.label),
                      selected: isSelected,
                      visualDensity: VisualDensity.compact,
                      onSelected: (selected) {
                        if (selected && _selectedPeriod != period) {
                          setState(() {
                            _selectedPeriod = period;
                            _recalculateSummary();
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Informative banner highlighting privacy and normalized percentages
  Widget _buildPrivacyBanner(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.shield_outlined,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Side-by-side metrics use audited percentages and risk ratios to protect dollar portfolio privacy.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Header cards showcasing trader identity, rank, win count, and copy actions
  Widget _buildTraderHeaderColumns(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_traders.length, (index) {
          final trader = _traders[index];
          final winCount = _summary.categoryWinCounts.isNotEmpty
              ? _summary.categoryWinCounts[index]
              : 0;

          return Expanded(
            child: Container(
              margin: EdgeInsets.only(
                left: index == 0 ? 0 : 6,
                right: index == _traders.length - 1 ? 0 : 6,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: winCount >= 4
                      ? theme.colorScheme.primary.withValues(alpha: 0.6)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: winCount >= 4 ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                children: [
                  // Close/remove trader action (if > 2)
                  if (_traders.length > 2)
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => _removeTrader(index),
                        child: Icon(Icons.close,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),

                  // Avatar
                  GestureDetector(
                    onTap: () => _navigateToProfile(trader.userId),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: trader.userPhotoUrl != null
                          ? CachedNetworkImageProvider(trader.userPhotoUrl!)
                          : const CachedNetworkImageProvider(
                              Constants.placeholderImage),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Name & Verified Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          trader.userName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (trader.isVerified) ...[
                        const SizedBox(width: 3),
                        Icon(
                          trader.verifiedTrackRecord?.tier.icon ??
                              Icons.verified,
                          size: 14,
                          color: trader.verifiedTrackRecord?.tier.color ??
                              Colors.blue,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Reputation Tier Chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          trader.reputation.tier.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      trader.reputation.tier.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: trader.reputation.tier.color,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Category Win Count Badge
                  if (winCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.emoji_events,
                              size: 12, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            '$winCount Best',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.amber.shade900,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),

                  // 1-Tap Copy Action
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _openCopySettings(trader),
                      child: const Text('Copy', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Visual Relative Strength comparison card
  Widget _buildRelativeStrengthCard(ThemeData theme) {
    final dimensions = [
      'Returns',
      'Win Consistency',
      'Sharpe Quality',
      'Capital Preservation',
      'Reputation',
    ];

    final colors = [
      Colors.blue,
      Colors.purple,
      Colors.teal,
      Colors.orange,
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Multi-Factor Relative Strengths',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Comparative score (0 - 100) across 5 core quantitative dimensions:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Legend
            Row(
              children: List.generate(_traders.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: colors[i % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _traders[i].userName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Dimension Bars
            ...List.generate(dimensions.length, (dimIdx) {
              final dimName = dimensions[dimIdx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dimName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Column(
                      children: List.generate(_traders.length, (traderIdx) {
                        final rs = _summary.relativeStrengths[traderIdx];
                        double score = 0.0;
                        switch (dimIdx) {
                          case 0:
                            score = rs.returnScore;
                            break;
                          case 1:
                            score = rs.consistencyScore;
                            break;
                          case 2:
                            score = rs.riskAdjustedScore;
                            break;
                          case 3:
                            score = rs.preservationScore;
                            break;
                          case 4:
                            score = rs.reputationScore;
                            break;
                        }

                        final color = colors[traderIdx % colors.length];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: Text(
                                  _traders[traderIdx].userName,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 9.5,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (score / 100.0).clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: theme
                                        .colorScheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation(color),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  score.toInt().toString(),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Metric categories (Performance, Risk, Activity, Reputation)
  List<Widget> _buildCategorySections(ThemeData theme) {
    final categorized = _summary.metricsByCategory;

    return categorized.entries.map((entry) {
      final category = entry.key;
      final metrics = entry.value;

      IconData catIcon;
      switch (category) {
        case TraderComparisonCategory.performance:
          catIcon = Icons.trending_up;
          break;
        case TraderComparisonCategory.risk:
          catIcon = Icons.security;
          break;
        case TraderComparisonCategory.activity:
          catIcon = Icons.swap_horiz;
          break;
        case TraderComparisonCategory.reputation:
          catIcon = Icons.verified_user_outlined;
          break;
      }

      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 0,
        color: theme.colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(catIcon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    category.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),

              // Metric rows
              ...metrics.map((m) => _buildMetricRow(theme, m)),
            ],
          ),
        ),
      );
    }).toList();
  }

  /// Individual row comparing values of a single metric across all traders
  Widget _buildMetricRow(ThemeData theme, TraderComparisonMetric metric) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metric label & description
          Row(
            children: [
              Text(
                metric.label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: metric.description,
                child: Icon(
                  Icons.info_outline,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Values side-by-side
          Row(
            children: List.generate(_traders.length, (idx) {
              final isBest = metric.bestTraderIndex == idx;
              final valStr = metric.formattedValues[idx];

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                    left: idx == 0 ? 0 : 4,
                    right: idx == _traders.length - 1 ? 0 : 4,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isBest
                        ? Colors.green.withValues(alpha: 0.12)
                        : theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isBest
                          ? Colors.green.withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isBest) ...[
                        const Icon(Icons.check_circle,
                            size: 12, color: Colors.green),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          valStr,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                isBest ? FontWeight.bold : FontWeight.normal,
                            color: isBest
                                ? Colors.green.shade800
                                : theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TraderProfileWidget(
          auth: widget.auth,
          userId: userId,
          analytics: widget.analytics,
          observer: widget.observer,
          brokerageUser: widget.brokerageUser,
          service: widget.service,
        ),
      ),
    );
  }

  void _openCopySettings(TopPortfolioEntry trader) {
    _navigateToProfile(trader.userId);
  }
}

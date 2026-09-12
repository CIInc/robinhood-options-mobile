import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/short_interest.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

class ShortInterestWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final Instrument instrument;
  final ShortInterestSummary? preloadedSummary;

  const ShortInterestWidget({
    super.key,
    required this.brokerageUser,
    required this.service,
    required this.instrument,
    this.preloadedSummary,
  });

  @override
  State<ShortInterestWidget> createState() => _ShortInterestWidgetState();
}

class _ShortInterestWidgetState extends State<ShortInterestWidget> {
  Future<ShortInterestSummary?>? _future;
  bool _isExpanded = false;

  final NumberFormat _compactNumberFormat = NumberFormat.compact();
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    if (widget.preloadedSummary != null) {
      _future = Future.value(widget.preloadedSummary);
    } else {
      _loadData();
    }
  }

  @override
  void didUpdateWidget(covariant ShortInterestWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.instrument.id != widget.instrument.id ||
        oldWidget.preloadedSummary != widget.preloadedSummary) {
      if (widget.preloadedSummary != null) {
        _future = Future.value(widget.preloadedSummary);
      } else {
        _loadData();
      }
    }
  }

  void _loadData() {
    setState(() {
      _future = _fetchShortInterestSummary();
    });
  }

  Future<ShortInterestSummary?> _fetchShortInterestSummary() async {
    try {
      final results = await Future.wait([
        widget.service
            .getShortInterest(
          widget.brokerageUser,
          widget.instrument.id,
        )
            .catchError((e) {
          debugPrint('getShortInterest error: $e');
          return null;
        }),
        widget.service
            .getShortingAvailability(
          widget.brokerageUser,
          widget.instrument.id,
        )
            .catchError((e) {
          debugPrint('getShortingAvailability error: $e');
          return null;
        }),
      ]);

      final adv = widget.instrument.fundamentalsObj?.averageVolume ??
          widget.instrument.fundamentalsObj?.averageVolume30Days ??
          widget.instrument.fundamentalsObj?.averageVolume2Weeks;
      final floatShares = widget.instrument.fundamentalsObj?.float;

      return ShortInterestSummary.fromResponses(
        shortInterestResponse: results[0],
        shortingAvailabilityResponse: results[1],
        instrumentId: widget.instrument.id,
        symbol: widget.instrument.symbol,
        fallbackAverageDailyVolume: adv,
        fallbackFreeFloat: floatShares,
      );
    } catch (e) {
      debugPrint('Error fetching short interest data: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ShortInterestSummary?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Card(
              child: ListTile(
                leading: Icon(Icons.error_outline,
                    color: Theme.of(context).colorScheme.error),
                title: const Text('Short interest data unavailable'),
                subtitle: Text('${snapshot.error}'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                ),
              ),
            ),
          );
        }

        final summary = snapshot.data;
        if (summary == null || !summary.hasData) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              context: context,
              title: 'Short Float',
              icon: Icons.trending_down,
              trailing: IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                tooltip: 'Refresh short data',
                onPressed: _loadData,
              ),
            ),
            Card(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              elevation: 0,
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBadges(context, summary),
                    const SizedBox(height: 16),
                    _buildPrimaryMetricsGrid(context, summary),
                    const SizedBox(height: 16),
                    _buildSqueezeBanner(context, summary),
                    if (_isExpanded) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      _buildDetailedTable(context, summary),
                      const SizedBox(height: 12),
                      _buildEducationalNotes(context, summary),
                    ],
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        },
                        icon: Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                        ),
                        label: Text(
                          _isExpanded
                              ? 'Hide Short Details'
                              : 'View Full Short & Borrow Breakdown',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    Widget? trailing,
    String? subtitle,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 2.0),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildBadges(BuildContext context, ShortInterestSummary summary) {
    final squeezeRisk = summary.squeezeRisk;
    final borrowLevel = summary.borrowCostLevel;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: squeezeRisk.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: squeezeRisk.color.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 14, color: squeezeRisk.color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  squeezeRisk.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: squeezeRisk.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: borrowLevel.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: borrowLevel.color.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_clock, size: 14, color: borrowLevel.color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  borrowLevel.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: borrowLevel.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (summary.availability?.borrowFeeRatePercentage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.percent,
                    size: 14, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 4),
                Text(
                  'Fee: ${summary.availability!.borrowFeeRatePercentage!.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPrimaryMetricsGrid(
      BuildContext context, ShortInterestSummary summary) {
    final floatPct = summary.shortInterest?.freeFloatPercentage;
    final dtc = summary.shortInterest?.daysToCover;
    final feeRatePct = summary.availability?.borrowFeeRatePercentage;
    final inventory = summary.availability?.inventory ?? 'HIGH';

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 280
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                context,
                title: 'Short % of Float',
                value: floatPct != null
                    ? '${floatPct.toStringAsFixed(2)}%'
                    : 'N/A',
                subtitle: 'Free Float Shorted',
                valueColor: _getFloatPercentageColor(floatPct),
                progressValue:
                    floatPct != null ? (floatPct / 40.0).clamp(0.0, 1.0) : null,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                context,
                title: 'Days to Cover',
                value: dtc != null ? '${dtc.toStringAsFixed(1)} d' : 'N/A',
                subtitle: 'Short Ratio',
                valueColor: _getDaysToCoverColor(dtc),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                context,
                title: 'Borrow Fee Rate',
                value: feeRatePct != null
                    ? '${feeRatePct.toStringAsFixed(2)}%'
                    : 'N/A',
                subtitle: 'Annualized Cost',
                valueColor: _getBorrowFeeColor(feeRatePct),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                context,
                title: 'Borrow Inventory',
                value: inventory,
                subtitle: 'Broker Availability',
                valueColor: _getInventoryColor(inventory),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    Color? valueColor,
    double? progressValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
          ),
          if (progressValue != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 4,
                backgroundColor:
                    Theme.of(context).dividerColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  valueColor ?? Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.color
                      ?.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSqueezeBanner(
      BuildContext context, ShortInterestSummary summary) {
    final risk = summary.squeezeRisk;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: risk.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: risk.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: risk.color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              risk.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 12,
                    height: 1.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedTable(
      BuildContext context, ShortInterestSummary summary) {
    final si = summary.shortInterest;
    final avail = summary.availability;

    final rows = <Widget>[];

    if (si?.sharesShort != null) {
      rows.add(_buildDetailRow(
        context,
        'Current Shares Short',
        '${_compactNumberFormat.format(si!.sharesShort)} shares',
      ));
    }

    if (si?.sharesShortPrior != null) {
      final change = si?.shortInterestChange;
      final changePct = si?.shortInterestChangePct;
      String changeText = '';
      Color? changeColor;

      if (change != null) {
        final sign = change > 0 ? '+' : '';
        changeText = '$sign${_compactNumberFormat.format(change)}';
        if (changePct != null) {
          changeText += ' ($sign${(changePct * 100).toStringAsFixed(1)}%)';
        }
        changeColor = change > 0 ? Colors.red : Colors.green;
      }

      rows.add(_buildDetailRow(
        context,
        'Prior Shares Short',
        '${_compactNumberFormat.format(si!.sharesShortPrior)} shares',
        extraWidget: changeText.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: changeColor?.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  changeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: changeColor,
                  ),
                ),
              )
            : null,
      ));
    }

    if (si?.sharesShortUpperBound != null &&
        si?.sharesShortLowerBound != null) {
      rows.add(_buildDetailRow(
        context,
        'Short Range Est.',
        '${_compactNumberFormat.format(si!.sharesShortLowerBound)} – ${_compactNumberFormat.format(si.sharesShortUpperBound)}',
      ));
    }

    if (si?.pcFreeFloatUpperBound != null &&
        si?.pcFreeFloatLowerBound != null) {
      rows.add(_buildDetailRow(
        context,
        'Short Float Range',
        '${si!.pcFreeFloatLowerBound!.toStringAsFixed(2)}% – ${si.pcFreeFloatUpperBound!.toStringAsFixed(2)}%',
      ));
    }

    if (si?.freeFloat != null) {
      rows.add(_buildDetailRow(
        context,
        'Total Free Float',
        '${_compactNumberFormat.format(si!.freeFloat)} shares',
      ));
    }

    if (si?.averageDailyVolume != null) {
      rows.add(_buildDetailRow(
        context,
        'Average Daily Volume',
        '${_compactNumberFormat.format(si!.averageDailyVolume)} shares',
      ));
    }

    if (avail?.marginRequirement != null) {
      final reqPct = avail!.marginRequirement! > 1.0
          ? avail.marginRequirement! * 100.0
          : avail.marginRequirement! * 100.0;
      rows.add(_buildDetailRow(
        context,
        'Margin Requirement',
        '${reqPct.toStringAsFixed(0)}%',
      ));
    }

    if (avail != null) {
      rows.add(_buildDetailRow(
        context,
        'Locate Required',
        avail.locateRequired ? 'Yes (Strict Borrow)' : 'No (Automated Borrow)',
      ));
    }

    if (si?.settlementDate != null) {
      rows.add(_buildDetailRow(
        context,
        'FINRA Settlement Date',
        _dateFormat.format(si!.settlementDate!),
      ));
    }

    if (avail?.hardToBorrowReason != null &&
        avail!.hardToBorrowReason!.isNotEmpty) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Borrow Note: ${avail.hardToBorrowReason}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    Widget? extraWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.8),
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 2,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (extraWidget != null) extraWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationalNotes(
      BuildContext context, ShortInterestSummary summary) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Understanding Short Squeeze & Borrow Dynamics',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '• Short % of Float: Float shorted above 10% is elevated; above 20% indicates severe short congestion and squeeze susceptibility.\n'
            '• Days to Cover: The ratio of shares short to average daily volume. Values over 4-5 days signal that short sellers will face illiquidity if forced to buy back shares simultaneously.\n'
            '• Borrow Fee Rate: The annualized interest paid to lenders to short the equity. Spikes above 10-15% signal Hard to Borrow conditions and scarce share availability.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  height: 1.4,
                  color: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  Color _getFloatPercentageColor(double? pct) {
    if (pct == null) return Colors.grey;
    if (pct >= 25.0) return Colors.red;
    if (pct >= 15.0) return Colors.deepOrange;
    if (pct >= 10.0) return Colors.orange;
    if (pct >= 5.0) return Colors.blue;
    return Colors.green;
  }

  Color _getDaysToCoverColor(double? dtc) {
    if (dtc == null) return Colors.grey;
    if (dtc >= 8.0) return Colors.red;
    if (dtc >= 4.0) return Colors.orange;
    if (dtc >= 2.0) return Colors.blue;
    return Colors.green;
  }

  Color _getBorrowFeeColor(double? feePct) {
    if (feePct == null) return Colors.grey;
    if (feePct >= 15.0) return Colors.red;
    if (feePct >= 5.0) return Colors.orange;
    if (feePct >= 1.0) return Colors.blue;
    return Colors.green;
  }

  Color _getInventoryColor(String inventory) {
    final inv = inventory.toUpperCase();
    if (inv == 'HIGH' || inv.startsWith('>')) {
      return Colors.green;
    } else if (inv == 'MEDIUM' || inv.contains('K-') || inv.contains('M')) {
      return Colors.blue;
    } else if (inv == 'LOW' || inv.startsWith('<')) {
      return Colors.orange;
    } else if (inv == 'NONE' || inv == '0') {
      return Colors.red;
    }
    return Colors.grey;
  }
}

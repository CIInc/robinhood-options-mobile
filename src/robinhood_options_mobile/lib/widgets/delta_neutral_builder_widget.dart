import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/delta_neutral_model.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/delta_neutral_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

/// Full-screen interactive Delta-Neutral Strategy Builder and Dynamic Hedging Tool.
///
/// Computes multi-leg portfolio delta, gamma, theta, and vega sensitivities,
/// detects delta drift against user-configured tolerance bands, suggests
/// optimal share and option rebalancing offsets, and renders an interactive
/// spot-shift scenario simulation curve.
class DeltaNeutralBuilderWidget extends StatefulWidget {
  final String symbol;
  final double? spotPrice;
  final User? user;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final Instrument? instrument;
  final List<dynamic>? optionsChains;
  final double? existingStockQuantity;
  final List<OptionAggregatePosition>? existingOptionPositions;
  final List<OptionInstrument>? optionInstruments;
  final double initialToleranceBand;
  final double initialTargetDelta;

  const DeltaNeutralBuilderWidget({
    super.key,
    required this.symbol,
    this.spotPrice,
    this.user,
    this.brokerageUser,
    this.service,
    this.instrument,
    this.optionsChains,
    this.existingStockQuantity,
    this.existingOptionPositions,
    this.optionInstruments,
    this.initialToleranceBand = 10.0,
    this.initialTargetDelta = 0.0,
  });

  @override
  State<DeltaNeutralBuilderWidget> createState() =>
      _DeltaNeutralBuilderWidgetState();
}

class _DeltaNeutralBuilderWidgetState extends State<DeltaNeutralBuilderWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late double _spotPrice;
  late double _targetDelta;
  late double _toleranceBand;

  List<DeltaPositionLeg> _legs = [];
  DeltaNeutralAnalysis? _analysis;
  int? _hoveredScenarioIndex;
  bool _showPnLCurve = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _spotPrice = widget.spotPrice ??
        widget.instrument?.quoteObj?.lastTradePrice ??
        100.0;
    _targetDelta = widget.initialTargetDelta;
    _toleranceBand = widget.initialToleranceBand;

    _initializeLegs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeLegs() {
    // If existing positions exist, import them; otherwise create default delta-neutral straddle template
    if ((widget.existingStockQuantity != null &&
            widget.existingStockQuantity!.abs() > 0.001) ||
        (widget.existingOptionPositions != null &&
            widget.existingOptionPositions!.isNotEmpty)) {
      _legs = DeltaNeutralService.importExistingPositions(
        symbol: widget.symbol,
        spotPrice: _spotPrice,
        existingStockQuantity: widget.existingStockQuantity,
        existingOptionPositions: widget.existingOptionPositions,
        optionInstruments: widget.optionInstruments,
      );
    }

    if (_legs.isEmpty) {
      _legs = DeltaNeutralService.buildTemplate(
        templateType: DeltaNeutralHedgingType.straddleStrangle,
        symbol: widget.symbol,
        spotPrice: _spotPrice,
      );
    }

    _recomputeAnalysis();
  }

  void _recomputeAnalysis() {
    setState(() {
      _analysis = DeltaNeutralService.computeAnalysis(
        symbol: widget.symbol,
        spotPrice: _spotPrice,
        legs: _legs,
        targetDelta: _targetDelta,
        toleranceBand: _toleranceBand,
        optionsChains: widget.optionsChains,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final analysis = _analysis;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.symbol} Delta Neutral',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Spot: \$${_spotPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Delta Hedging Theory',
            onPressed: () => _showTheoryModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset to Template',
            onPressed: () {
              HapticFeedback.lightImpact();
              _initializeLegs();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.layers_outlined, size: 18), text: 'Legs & Builder'),
            Tab(icon: Icon(Icons.tune_rounded, size: 18), text: 'Rebalance & Offsets'),
            Tab(icon: Icon(Icons.show_chart_rounded, size: 18), text: 'Scenario Curve'),
            Tab(icon: Icon(Icons.auto_awesome_outlined, size: 18), text: 'Templates'),
          ],
        ),
      ),
      body: analysis == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeroOverview(analysis, colorScheme),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildLegsTab(analysis, colorScheme),
                      _buildRebalanceTab(analysis, colorScheme),
                      _buildScenarioTab(analysis, colorScheme),
                      _buildTemplatesTab(colorScheme),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // --------------------------------------------------------------------------
  // Hero Overview Section
  // --------------------------------------------------------------------------

  Widget _buildHeroOverview(
      DeltaNeutralAnalysis analysis, ColorScheme colorScheme) {
    final status = analysis.driftStatus;
    final netDelta = analysis.netDelta;
    final statusColor = status.color(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Net Position Delta',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${netDelta >= 0 ? "+" : ""}${netDelta.toStringAsFixed(1)} Δ',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(status.icon, size: 13, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              status.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '1% Move Risk',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${analysis.dollarDeltaPerOnePercent >= 0 ? "+" : ""}\$${analysis.dollarDeltaPerOnePercent.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: analysis.dollarDeltaPerOnePercent >= 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Greeks Row
          Row(
            children: [
              Expanded(
                child: _buildGreekChip(
                  'Delta (Δ)',
                  '${analysis.netDelta >= 0 ? "+" : ""}${analysis.netDelta.toStringAsFixed(1)}',
                  'Share eq.',
                  colorScheme,
                ),
              ),
              Expanded(
                child: _buildGreekChip(
                  'Gamma (Γ)',
                  '${analysis.netGamma >= 0 ? "+" : ""}${analysis.netGamma.toStringAsFixed(2)}',
                  'Δ / \$1 spot',
                  colorScheme,
                ),
              ),
              Expanded(
                child: _buildGreekChip(
                  'Theta (Θ)',
                  '${analysis.netTheta >= 0 ? "+" : ""}\$${analysis.netTheta.toStringAsFixed(2)}',
                  '/ day',
                  colorScheme,
                ),
              ),
              Expanded(
                child: _buildGreekChip(
                  'Vega (V)',
                  '${analysis.netVega >= 0 ? "+" : ""}\$${analysis.netVega.toStringAsFixed(2)}',
                  '/ 1% IV',
                  colorScheme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGreekChip(
      String label, String value, String unit, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          unit,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            color: colorScheme.outline,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Tab 1: Legs & Strategy Builder
  // --------------------------------------------------------------------------

  Widget _buildLegsTab(
      DeltaNeutralAnalysis analysis, ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(
              'Active Legs (${_legs.length})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Leg'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: () => _showAddLegDialog(context),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_legs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.layers_clear_outlined,
                    size: 48, color: colorScheme.outline),
                const SizedBox(height: 12),
                const Text(
                  'No Legs Added',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add shares or options or select a pre-configured template.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
                ),
              ],
            ),
          )
        else
          ..._legs.asMap().entries.map((entry) {
            final idx = entry.key;
            final leg = entry.value;
            return _buildLegCard(leg, idx, colorScheme);
          }),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          spacing: 12,
          runSpacing: 8,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Clear All'),
              onPressed: () {
                setState(() {
                  _legs.clear();
                  _recomputeAnalysis();
                });
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Load My Positions'),
              onPressed: () {
                HapticFeedback.lightImpact();
                _initializeLegs();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegCard(
      DeltaPositionLeg leg, int index, ColorScheme colorScheme) {
    final sideColor = leg.side.color(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(leg.legType.icon, size: 20, color: sideColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leg.description,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Mark: \$${leg.markPrice.toStringAsFixed(2)} • Value: \$${leg.marketValue.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sideColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${leg.totalDelta >= 0 ? "+" : ""}${leg.totalDelta.toStringAsFixed(1)} Δ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: sideColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Side toggle
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _legs[index] = leg.copyWith(
                        side: leg.side == PositionSide.long
                            ? PositionSide.short
                            : PositionSide.long,
                      );
                      _recomputeAnalysis();
                    });
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.swap_horiz, size: 14, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Side: ${leg.side.label}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Quantity adjuster
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        if (leg.quantity <= 1) {
                          setState(() {
                            _legs.removeAt(index);
                            _recomputeAnalysis();
                          });
                        } else {
                          setState(() {
                            _legs[index] = leg.copyWith(
                              quantity: leg.quantity - 1,
                            );
                            _recomputeAnalysis();
                          });
                        }
                      },
                    ),
                    Text(
                      '${leg.quantity.toInt()}x',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 16),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _legs[index] = leg.copyWith(
                            quantity: leg.quantity + 1,
                          );
                          _recomputeAnalysis();
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      visualDensity: VisualDensity.compact,
                      color: colorScheme.error,
                      onPressed: () {
                        setState(() {
                          _legs.removeAt(index);
                          _recomputeAnalysis();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Tab 2: Rebalancing & Offsets
  // --------------------------------------------------------------------------

  Widget _buildRebalanceTab(
      DeltaNeutralAnalysis analysis, ColorScheme colorScheme) {
    final rebalance = analysis.rebalanceSuggestion;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Tolerance Band Adjuster
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Neutrality Tolerance Band',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '±${_toleranceBand.toStringAsFixed(1)} Δ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _toleranceBand,
                  min: 2.0,
                  max: 50.0,
                  divisions: 24,
                  label: '±${_toleranceBand.toStringAsFixed(1)} Δ',
                  onChanged: (val) {
                    setState(() {
                      _toleranceBand = val;
                      _recomputeAnalysis();
                    });
                  },
                ),
                Text(
                  'Triggers rebalance alert when net delta drifts past ±${_toleranceBand.toStringAsFixed(0)} share equivalents.',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Suggestion summary banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: analysis.driftStatus.color(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: analysis.driftStatus.color(context).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(analysis.driftStatus.icon,
                  color: analysis.driftStatus.color(context), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  rebalance.summaryText,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Automated Rebalancing Suggestions',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (rebalance.primaryShareHedge != null)
          _buildOffsetCard(rebalance.primaryShareHedge!, colorScheme, isPrimary: true),
        if (rebalance.primaryOptionHedge != null)
          _buildOffsetCard(rebalance.primaryOptionHedge!, colorScheme),
        ...rebalance.alternativeHedges.map((alt) => _buildOffsetCard(alt, colorScheme)),
        const SizedBox(height: 16),
        // Advisory note
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: colorScheme.outline),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rebalancing frequency depends on volatility and transaction costs. '
                    'Share hedging provides linear delta neutralization with zero added gamma, '
                    'while option hedging modifies both gamma curvature and theta decay.',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOffsetCard(
      DeltaOffsetRecommendation hedge, ColorScheme colorScheme,
      {bool isPrimary = false}) {
    final isBuy = hedge.action == 'buy';
    final actionColor = isBuy ? Colors.green : Colors.red;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isPrimary
              ? colorScheme.primary.withValues(alpha: 0.5)
              : colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isPrimary ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: actionColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hedge.action.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: actionColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hedge.hedgingType.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (isPrimary)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'RECOMMENDED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              hedge.description,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              hedge.rationale,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post-Hedge Net Delta',
                      style: TextStyle(
                          fontSize: 10, color: colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      '${hedge.resultingNetDelta >= 0 ? "+" : ""}${hedge.resultingNetDelta.toStringAsFixed(1)} Δ',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      hedge.estimatedCashFlow >= 0 ? 'Est. Capital' : 'Est. Credit',
                      style: TextStyle(
                          fontSize: 10, color: colorScheme.onSurfaceVariant),
                    ),
                    Text(
                      '\$${hedge.estimatedCashFlow.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: hedge.estimatedCashFlow >= 0
                            ? colorScheme.onSurface
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _applyHedgeToLegs(hedge);
                  },
                  child: const Text('Add to Model'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applyHedgeToLegs(DeltaOffsetRecommendation hedge) {
    if (hedge.instrumentType == 'shares') {
      _legs.add(
        DeltaPositionLeg(
          id: 'hedge_shares_${DateTime.now().millisecondsSinceEpoch}',
          symbol: widget.symbol,
          legType: DeltaLegType.stock,
          side: hedge.action == 'buy' ? PositionSide.long : PositionSide.short,
          quantity: hedge.quantity,
          unitDelta: 1.0,
          markPrice: _spotPrice,
        ),
      );
    } else {
      final isCall = hedge.instrumentType == 'call';
      _legs.add(
        DeltaPositionLeg(
          id: 'hedge_opt_${DateTime.now().millisecondsSinceEpoch}',
          symbol: widget.symbol,
          legType: isCall ? DeltaLegType.call : DeltaLegType.put,
          side: hedge.action == 'buy' ? PositionSide.long : PositionSide.short,
          quantity: hedge.quantity,
          strike: hedge.strike,
          expirationDate: hedge.expirationDate,
          unitDelta: hedge.contractUnitDelta ?? (isCall ? 0.50 : -0.50),
          unitGamma: 0.02,
          unitTheta: -0.05,
          unitVega: 0.15,
          markPrice: _spotPrice * 0.03,
        ),
      );
    }
    _recomputeAnalysis();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${hedge.description} to active model.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Tab 3: Spot Shift Scenario Curve
  // --------------------------------------------------------------------------

  Widget _buildScenarioTab(
      DeltaNeutralAnalysis analysis, ColorScheme colorScheme) {
    final points = analysis.scenarioPoints;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Spot Price Shift Curve',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  _showPnLCurve
                      ? 'Simulated P&L across spot moves'
                      : 'Projected Net Delta vs Underlying Spot',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            // Toggle between Delta curve and PnL curve
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Delta (Δ)')),
                ButtonSegment(value: true, label: Text('P&L (\$)')),
              ],
              selected: {_showPnLCurve},
              onSelectionChanged: (set) {
                setState(() {
                  _showPnLCurve = set.first;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Live Inspection Card (when scrubbing or tapping a point)
        if (_hoveredScenarioIndex != null &&
            _hoveredScenarioIndex! >= 0 &&
            _hoveredScenarioIndex! < points.length) ...[
          Builder(builder: (context) {
            final hp = points[_hoveredScenarioIndex!];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        hp.isInTolerance
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        size: 16,
                        color: hp.isInTolerance ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Spot: \$${hp.spotPrice.toStringAsFixed(2)} (${hp.percentageShift >= 0 ? "+" : ""}${(hp.percentageShift * 100).toStringAsFixed(1)}%)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        _showPnLCurve
                            ? '${hp.projectedPnL >= 0 ? "+" : ""}\$${hp.projectedPnL.toStringAsFixed(0)} P&L'
                            : '${hp.projectedNetDelta >= 0 ? "+" : ""}${hp.projectedNetDelta.toStringAsFixed(1)} Δ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: _showPnLCurve
                              ? (hp.projectedPnL >= 0 ? Colors.green : Colors.red)
                              : (hp.isInTolerance ? Colors.green : Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _hoveredScenarioIndex = null;
                          });
                        },
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
        // Interactive Canvas Container with Scrubbing GestureDetector
        LayoutBuilder(
          builder: (context, constraints) {
            final chartWidth = constraints.maxWidth;
            void handleChartTouch(double localX) {
              if (points.isEmpty) return;
              final double minX = points.first.spotPrice;
              final double maxX = points.last.spotPrice;
              if (maxX <= minX) return;

              // Account for padding (12px each side)
              final innerWidth = (chartWidth - 24.0).clamp(1.0, double.infinity);
              final innerX = (localX - 12.0).clamp(0.0, innerWidth);
              final targetSpot = minX + (innerX / innerWidth) * (maxX - minX);

              int closestIdx = 0;
              double minDiff = (points[0].spotPrice - targetSpot).abs();
              for (int i = 1; i < points.length; i++) {
                final diff = (points[i].spotPrice - targetSpot).abs();
                if (diff < minDiff) {
                  minDiff = diff;
                  closestIdx = i;
                }
              }

              if (_hoveredScenarioIndex != closestIdx) {
                HapticFeedback.selectionClick();
                setState(() {
                  _hoveredScenarioIndex = closestIdx;
                });
              }
            }

            return GestureDetector(
              key: const ValueKey('scenario_chart_gesture'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => handleChartTouch(d.localPosition.dx),
              onPanStart: (d) => handleChartTouch(d.localPosition.dx),
              onPanUpdate: (d) => handleChartTouch(d.localPosition.dx),
              child: Container(
                height: 240,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: CustomPaint(
                  painter: _DeltaScenarioChartPainter(
                    points: points,
                    showPnL: _showPnLCurve,
                    toleranceBand: _toleranceBand,
                    targetDelta: _targetDelta,
                    currentSpot: _spotPrice,
                    colorScheme: colorScheme,
                    hoveredIndex: _hoveredScenarioIndex,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // Scenario Points Grid / Table
        const Text(
          'Scenario Breakdown Matrix',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Table(
          border: TableBorder(
            horizontalInside: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              ),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Text('Spot Move', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Text('Underlying', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Text('Net Delta', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Text('Est. P&L', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            ...points.asMap().entries.map((entry) {
              final idx = entry.key;
              final pt = entry.value;
              final isHovered = _hoveredScenarioIndex == idx;
              final pctStr = '${pt.percentageShift >= 0 ? "+" : ""}${(pt.percentageShift * 100).toStringAsFixed(1)}%';
              final pnlColor = pt.projectedPnL >= 0 ? Colors.green : Colors.red;
              return TableRow(
                decoration: isHovered
                    ? BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                children: [
                  TableCell(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _hoveredScenarioIndex = isHovered ? null : idx;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Text(pctStr, style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                  ),
                  TableCell(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _hoveredScenarioIndex = isHovered ? null : idx;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Text('\$${pt.spotPrice.toStringAsFixed(1)}', style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                  ),
                  TableCell(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _hoveredScenarioIndex = isHovered ? null : idx;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Text(
                          '${pt.projectedNetDelta >= 0 ? "+" : ""}${pt.projectedNetDelta.toStringAsFixed(1)} Δ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: pt.isInTolerance ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ),
                  ),
                  TableCell(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _hoveredScenarioIndex = isHovered ? null : idx;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Text(
                          '${pt.projectedPnL >= 0 ? "+" : ""}\$${pt.projectedPnL.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 11, color: pnlColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  TableCell(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _hoveredScenarioIndex = isHovered ? null : idx;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Icon(
                          pt.isInTolerance ? Icons.check_circle : Icons.warning_amber_rounded,
                          size: 14,
                          color: pt.isInTolerance ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Tab 4: Pre-configured Strategy Templates
  // --------------------------------------------------------------------------

  Widget _buildTemplatesTab(ColorScheme colorScheme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        const Text(
          'Delta-Neutral Strategy Presets',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Select a template to automatically generate a pre-hedged delta-neutral options structure.',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        _buildTemplateCard(
          title: 'ATM Long Straddle',
          description:
              'Long 1 ATM Call + Long 1 ATM Put. Delta neutralized with exact share offset. High-gamma volatility expansion play.',
          icon: Icons.compare_arrows_rounded,
          type: DeltaNeutralHedgingType.straddleStrangle,
          colorScheme: colorScheme,
        ),
        _buildTemplateCard(
          title: 'Delta-Neutral Covered Collar',
          description:
              'Long 100 Shares + Short 1 OTM Call + Long 1 OTM Put sized to eliminate net delta while capping downside.',
          icon: Icons.shield_outlined,
          type: DeltaNeutralHedgingType.collarSpread,
          colorScheme: colorScheme,
        ),
        _buildTemplateCard(
          title: 'Delta-Neutral Call Ratio Backspread',
          description:
              'Short 1 ATM Call (-50 Δ) + Long 2 OTM Calls (+25 Δ each). Net zero delta with uncapped upside volatility explosion.',
          icon: Icons.trending_up_rounded,
          type: DeltaNeutralHedgingType.ratioSpread,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _buildTemplateCard({
    required String title,
    required String description,
    required IconData icon,
    required DeltaNeutralHedgingType type,
    required ColorScheme colorScheme,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _legs = DeltaNeutralService.buildTemplate(
              templateType: type,
              symbol: widget.symbol,
              spotPrice: _spotPrice,
            );
            _recomputeAnalysis();
            _tabController.animateTo(0);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loaded $title template.'),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Dialogs & Modals
  // --------------------------------------------------------------------------

  void _showAddLegDialog(BuildContext context) {
    DeltaLegType selectedType = DeltaLegType.call;
    PositionSide selectedSide = PositionSide.long;
    double qty = 1.0;
    double strike = (_spotPrice / 5).round() * 5.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Custom Leg',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Leg Type Segmented
                  SegmentedButton<DeltaLegType>(
                    segments: const [
                      ButtonSegment(
                          value: DeltaLegType.stock, label: Text('Stock')),
                      ButtonSegment(
                          value: DeltaLegType.call, label: Text('Call')),
                      ButtonSegment(
                          value: DeltaLegType.put, label: Text('Put')),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (s) {
                      setModalState(() {
                        selectedType = s.first;
                        if (selectedType == DeltaLegType.stock && qty < 10) {
                          qty = 50.0;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  // Side Segmented
                  SegmentedButton<PositionSide>(
                    segments: const [
                      ButtonSegment(
                          value: PositionSide.long, label: Text('Long (+)')),
                      ButtonSegment(
                          value: PositionSide.short, label: Text('Short (-)')),
                    ],
                    selected: {selectedSide},
                    onSelectionChanged: (s) =>
                        setModalState(() => selectedSide = s.first),
                  ),
                  const SizedBox(height: 14),
                  if (selectedType != DeltaLegType.stock) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Strike Price:'),
                        Text(
                          '\$${strike.toStringAsFixed(1)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Slider(
                      value: strike,
                      min: _spotPrice * 0.7,
                      max: _spotPrice * 1.3,
                      divisions: 24,
                      onChanged: (v) => setModalState(() => strike = v),
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(selectedType == DeltaLegType.stock
                          ? 'Number of Shares:'
                          : 'Number of Contracts:'),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              if (qty > 1) {
                                setModalState(() => qty -= 1);
                              }
                            },
                          ),
                          Text('${qty.toInt()}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => setModalState(() => qty += 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (selectedType == DeltaLegType.stock) {
                          _legs.add(
                            DeltaPositionLeg(
                              id: 'leg_${DateTime.now().millisecondsSinceEpoch}',
                              symbol: widget.symbol,
                              legType: DeltaLegType.stock,
                              side: selectedSide,
                              quantity: qty,
                              unitDelta: 1.0,
                              markPrice: _spotPrice,
                            ),
                          );
                        } else {
                          final isCall = selectedType == DeltaLegType.call;
                          final g = DeltaNeutralService.calculateBlackScholesGreeks(
                            spotPrice: _spotPrice,
                            strikePrice: strike,
                            timeToExpirationYears: 30 / 365,
                            volatility: 0.30,
                            isCall: isCall,
                          );
                          _legs.add(
                            DeltaPositionLeg(
                              id: 'leg_${DateTime.now().millisecondsSinceEpoch}',
                              symbol: widget.symbol,
                              legType: selectedType,
                              side: selectedSide,
                              quantity: qty,
                              strike: strike,
                              expirationDate:
                                  DateTime.now().add(const Duration(days: 30)),
                              unitDelta: g['delta']!,
                              unitGamma: g['gamma']!,
                              unitTheta: g['theta']!,
                              unitVega: g['vega']!,
                              markPrice: g['price']!,
                            ),
                          );
                        }
                        _recomputeAnalysis();
                      },
                      child: const Text('Add Leg to Builder'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTheoryModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scroll) {
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delta Neutrality & Dynamic Hedging',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  '1. What is Delta Neutrality?',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'A position is delta-neutral when its aggregate delta equals zero (Δ_net = 0). '
                  'In this state, immediate small fluctuations in the underlying asset price do not produce '
                  'directional profit or loss. This isolates non-directional profit streams, such as theta decay '
                  '(time decay) and vega (implied volatility swings).',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                const Text(
                  '2. Why Does Delta Drift Occur?',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Because options possess gamma (Γ), option delta shifts continuously as the underlying spot moves: '
                  'Δ(S) ≈ Δ_0 + Γ · ΔS. When the stock rises or falls, the position accumulates unwanted directional '
                  'exposure ("delta drift"), requiring systematic rebalancing.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                const Text(
                  '3. Shares vs. Option Hedging',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  '• Share Rebalancing: Buying or selling underlying shares provides pure linear delta offset with zero added gamma. '
                  'It instantly restores Δ_net = 0 without altering your theta or volatility profile.\n\n'
                  '• Option Rebalancing: Adding or rolling option legs adjusts both delta and gamma curvature, '
                  'allowing you to collect credit (selling puts/calls) or acquire volatility protection (buying puts/calls).',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got It'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ----------------------------------------------------------------------------
// Custom Painter for Delta & PnL Scenario Curve
// ----------------------------------------------------------------------------

class _DeltaScenarioChartPainter extends CustomPainter {
  final List<DeltaScenarioPoint> points;
  final bool showPnL;
  final double toleranceBand;
  final double targetDelta;
  final double currentSpot;
  final ColorScheme colorScheme;
  final int? hoveredIndex;

  _DeltaScenarioChartPainter({
    required this.points,
    required this.showPnL,
    required this.toleranceBand,
    required this.targetDelta,
    required this.currentSpot,
    required this.colorScheme,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final double minX = points.first.spotPrice;
    final double maxX = points.last.spotPrice;
    if (maxX <= minX) return;

    // Determine Y range
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (final p in points) {
      final yVal = showPnL ? p.projectedPnL : p.projectedNetDelta;
      if (yVal < minY) minY = yVal;
      if (yVal > maxY) maxY = yVal;
    }

    if (!showPnL) {
      // Include tolerance band in Y range
      minY = math.min(minY, targetDelta - toleranceBand * 1.5);
      maxY = math.max(maxY, targetDelta + toleranceBand * 1.5);
    } else {
      minY = math.min(minY, -100.0);
      maxY = math.max(maxY, 100.0);
    }

    final double rangeY = (maxY - minY).abs() < 0.001 ? 1.0 : (maxY - minY);

    double toScreenX(double spot) =>
        ((spot - minX) / (maxX - minX)) * size.width;
    double toScreenY(double yVal) =>
        size.height - (((yVal - minY) / rangeY) * size.height);

    // 1. Shaded Tolerance Band (for Delta curve)
    if (!showPnL) {
      final topBandY = toScreenY(targetDelta + toleranceBand);
      final bottomBandY = toScreenY(targetDelta - toleranceBand);
      final bandPaint = Paint()
        ..color = Colors.green.withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTRB(0, topBandY, size.width, bottomBandY),
        bandPaint,
      );
    }

    // 2. Zero baseline line
    final zeroY = toScreenY(0.0);
    final zeroLinePaint = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), zeroLinePaint);

    // 3. Current spot vertical marker
    final currentSpotX = toScreenX(currentSpot);
    final spotLinePaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.5)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
        Offset(currentSpotX, 0), Offset(currentSpotX, size.height), spotLinePaint);

    // 4. Plot Curve Path
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = toScreenX(p.spotPrice);
      final yVal = showPnL ? p.projectedPnL : p.projectedNetDelta;
      final y = toScreenY(yVal);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final curvePaint = Paint()
      ..color = showPnL
          ? Colors.teal
          : (colorScheme.primary)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, curvePaint);

    // 5. Draw node dots
    final dotPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = toScreenX(p.spotPrice);
      final yVal = showPnL ? p.projectedPnL : p.projectedNetDelta;
      final y = toScreenY(yVal);

      final isTol = p.isInTolerance;
      dotPaint.color = showPnL
          ? (p.projectedPnL >= 0 ? Colors.green : Colors.red)
          : (isTol ? Colors.green : Colors.orange);

      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }

    // 6. Draw Active Hover / Scrub Indicator
    if (hoveredIndex != null &&
        hoveredIndex! >= 0 &&
        hoveredIndex! < points.length) {
      final hp = points[hoveredIndex!];
      final hx = toScreenX(hp.spotPrice);
      final hyVal = showPnL ? hp.projectedPnL : hp.projectedNetDelta;
      final hy = toScreenY(hyVal);

      // Vertical crosshair indicator
      final crosshairPaint = Paint()
        ..color = colorScheme.primary.withValues(alpha: 0.65)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(hx, 0), Offset(hx, size.height), crosshairPaint);

      // Outer halo ring
      final haloPaint = Paint()
        ..color = colorScheme.primary.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(hx, hy), 10.0, haloPaint);

      // Core point
      final corePaint = Paint()
        ..color = colorScheme.primary
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(hx, hy), 5.5, corePaint);

      // Center white dot
      final innerWhitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(hx, hy), 2.0, innerWhitePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DeltaScenarioChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.showPnL != showPnL ||
        oldDelegate.toleranceBand != toleranceBand ||
        oldDelegate.currentSpot != currentSpot ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}

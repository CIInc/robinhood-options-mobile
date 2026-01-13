import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';

class RebalancingWidget extends StatefulWidget {
  final User user;
  final DocumentReference<User> userDocRef;
  final Account account;

  const RebalancingWidget(
      {super.key,
      required this.user,
      required this.userDocRef,
      required this.account});

  @override
  State<RebalancingWidget> createState() => _RebalancingWidgetState();
}

class _RebalancingWidgetState extends State<RebalancingWidget> {
  final Map<String, double> _assetTargets = {
    'Stocks': 0,
    'Options': 0,
    'Crypto': 0,
    'Cash': 0,
  };
  final Map<String, double> _sectorTargets = {};
  bool _isEditing = false;
  int _viewMode = 0; // 0: Asset Class, 1: Sector
  final NumberFormat formatCurrency =
      NumberFormat.simpleCurrency(locale: "en_US");
  final NumberFormat formatPercentage =
      NumberFormat.decimalPercentPattern(decimalDigits: 1);
  double _driftThreshold = 100.0;

  static const List<String> _standardSectors = [
    'Technology',
    'Financial Services',
    'Consumer Cyclical',
    'Healthcare',
    'Communication Services',
    'Industrials',
    'Consumer Defensive',
    'Energy',
    'Real Estate',
    'Basic Materials',
    'Utilities',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.user.assetAllocationTargets != null) {
      _assetTargets.addAll(widget.user.assetAllocationTargets!);
    }
    if (widget.user.sectorAllocationTargets != null) {
      _sectorTargets.addAll(widget.user.sectorAllocationTargets!);
    }
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveTargets() async {
    final targets = _viewMode == 0 ? _assetTargets : _sectorTargets;
    final sum = targets.values.fold(0.0, (a, b) => a + b);
    if ((sum - 1.0).abs() > 0.01 && targets.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Total allocation must be 100%. Current: ${formatPercentage.format(sum)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_viewMode == 0) {
      await widget.userDocRef.update({'assetAllocationTargets': _assetTargets});
      widget.user.assetAllocationTargets = Map.from(_assetTargets);
    } else {
      await widget.userDocRef
          .update({'sectorAllocationTargets': _sectorTargets});
      widget.user.sectorAllocationTargets = Map.from(_sectorTargets);
    }

    setState(() {
      _isEditing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Allocation targets saved')));
    }
  }

  void _normalizeTargets() {
    final targets = _viewMode == 0 ? _assetTargets : _sectorTargets;
    final sum = targets.values.fold(0.0, (a, b) => a + b);
    if (sum == 0) return;

    setState(() {
      targets.updateAll((key, value) => value / sum);
    });
  }

  void _applyPreset(String name) {
    setState(() {
      if (_viewMode == 0) {
        // Asset Class Presets
        switch (name) {
          case 'Aggressive':
            _assetTargets['Stocks'] = 0.8;
            _assetTargets['Options'] = 0.1;
            _assetTargets['Crypto'] = 0.1;
            _assetTargets['Cash'] = 0.0;
            break;
          case 'Moderate':
            _assetTargets['Stocks'] = 0.6;
            _assetTargets['Options'] = 0.05;
            _assetTargets['Crypto'] = 0.05;
            _assetTargets['Cash'] = 0.3;
            break;
          case 'Conservative':
            _assetTargets['Stocks'] = 0.4;
            _assetTargets['Options'] = 0.0;
            _assetTargets['Crypto'] = 0.0;
            _assetTargets['Cash'] = 0.6;
            break;
          case 'All Equity':
            _assetTargets['Stocks'] = 1.0;
            _assetTargets['Options'] = 0.0;
            _assetTargets['Crypto'] = 0.0;
            _assetTargets['Cash'] = 0.0;
            break;
        }
      } else {
        // Sector Presets
        _sectorTargets.clear(); // Clear existing to avoid mixing
        switch (name) {
          case 'Tech Heavy':
            _sectorTargets['Technology'] = 0.5;
            _sectorTargets['Consumer Cyclical'] = 0.2;
            _sectorTargets['Communication Services'] = 0.2;
            _sectorTargets['Financial Services'] = 0.1;
            break;
          case 'Balanced':
            _sectorTargets['Technology'] = 0.2;
            _sectorTargets['Healthcare'] = 0.15;
            _sectorTargets['Financial Services'] = 0.15;
            _sectorTargets['Consumer Cyclical'] = 0.1;
            _sectorTargets['Industrials'] = 0.1;
            _sectorTargets['Consumer Defensive'] = 0.1;
            _sectorTargets['Energy'] = 0.05;
            _sectorTargets['Utilities'] = 0.05;
            _sectorTargets['Real Estate'] = 0.05;
            _sectorTargets['Basic Materials'] = 0.05;
            break;
          case 'Defensive':
            _sectorTargets['Healthcare'] = 0.3;
            _sectorTargets['Consumer Defensive'] = 0.3;
            _sectorTargets['Utilities'] = 0.2;
            _sectorTargets['Energy'] = 0.1;
            _sectorTargets['Real Estate'] = 0.1;
            break;
        }
      }
    });
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rebalancing Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text('Drift Threshold for Recommendations',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _driftThreshold,
                          min: 0,
                          max: 1000,
                          divisions: 20,
                          label: formatCurrency.format(_driftThreshold),
                          onChanged: (value) {
                            setModalState(() {
                              _driftThreshold = value;
                            });
                            setState(() {
                              _driftThreshold = value;
                            });
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(formatCurrency.format(_driftThreshold),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Text(
                      'Recommendations will be triggered if the drift exceeds this amount.',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio Rebalance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: _isEditing ? _saveTargets : _toggleEditing,
          ),
        ],
      ),
      bottomNavigationBar: _isEditing
          ? BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Total: ',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          formatPercentage.format(
                              (_viewMode == 0 ? _assetTargets : _sectorTargets)
                                  .values
                                  .fold(0.0, (a, b) => a + b)),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: ((_viewMode == 0
                                                    ? _assetTargets
                                                    : _sectorTargets)
                                                .values
                                                .fold(0.0, (a, b) => a + b) -
                                            1.0)
                                        .abs() >
                                    0.01
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: _normalizeTargets,
                      icon: const Icon(Icons.balance),
                      label: const Text('Normalize'),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: Consumer4<PortfolioStore, InstrumentPositionStore,
          OptionPositionStore, ForexHoldingStore>(
        builder: (context, portfolioStore, stockPositionStore,
            optionPositionStore, forexHoldingStore, child) {
          // Calculate current allocation
          double stockEquity = 0;
          final Map<String, double> sectorEquity = {};

          for (var item in stockPositionStore.items) {
            final equity = (item.quantity ?? 0) * (item.averageBuyPrice ?? 0);
            stockEquity += equity;

            final sector =
                item.instrumentObj?.fundamentalsObj?.sector ?? 'Unknown';
            sectorEquity[sector] = (sectorEquity[sector] ?? 0) + equity;
          }

          double optionEquity = 0;
          for (var item in optionPositionStore.items) {
            // Use averageOpenPrice as averagePrice is not available on OptionAggregatePosition
            optionEquity += (item.quantity ?? 0) * (item.averageOpenPrice ?? 0);
          }

          double cryptoEquity = 0;
          for (var item in forexHoldingStore.items) {
            if (item.quantity != null &&
                item.quoteObj != null &&
                item.quoteObj!.markPrice != null) {
              cryptoEquity += item.quantity! * item.quoteObj!.markPrice!;
            }
          }

          double cashEquity = widget.account.portfolioCash ?? 0;

          final totalEquity =
              stockEquity + optionEquity + cryptoEquity + cashEquity;

          if (totalEquity == 0) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pie_chart_outline,
                      size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No portfolio data available',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Add positions to see allocation analysis',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }

          final currentAssetAllocation = {
            'Stocks': stockEquity / totalEquity,
            'Options': optionEquity / totalEquity,
            'Crypto': cryptoEquity / totalEquity,
            'Cash': cashEquity / totalEquity,
          };

          final currentSectorAllocation = sectorEquity.map((key, value) =>
              MapEntry(key, value / totalEquity)); // Sector % of TOTAL equity

          // Ensure all sectors in current allocation are in targets (init with 0 if missing)
          if (_sectorTargets.isEmpty && currentSectorAllocation.isNotEmpty) {
            // Initialize targets with current if empty
            // Or just ensure keys exist
          }
          for (var key in currentSectorAllocation.keys) {
            if (!_sectorTargets.containsKey(key)) {
              _sectorTargets[key] = 0;
            }
          }

          final currentAllocation =
              _viewMode == 0 ? currentAssetAllocation : currentSectorAllocation;
          final targets = _viewMode == 0 ? _assetTargets : _sectorTargets;

          final allKeys = _viewMode == 0
              ? ['Stocks', 'Options', 'Crypto', 'Cash']
              : {
                  ...currentSectorAllocation.keys,
                  ..._sectorTargets.keys,
                  ..._standardSectors
                }.toList();
          if (_viewMode == 1) {
            allKeys.sort();
          }

          final isDark = Theme.of(context).brightness == Brightness.dark;
          final assetColors = {
            'Stocks': Colors.blue,
            'Options': isDark ? Colors.orange : Colors.orange[800]!,
            'Crypto': Colors.purple,
            'Cash': Colors.green,
          };

          // Distinct palette for sectors to ensure readability across themes
          final List<Color> sectorPalette = [
            Colors.blue,
            Colors.red,
            Colors.green,
            isDark ? Colors.orange : Colors.orange[800]!,
            Colors.purple,
            Colors.teal,
            Colors.pink,
            Colors.indigo,
            isDark ? Colors.cyan : Colors.cyan[700]!,
            isDark ? Colors.amber : Colors.amber[800]!,
            Colors.brown,
            isDark ? Colors.lime : Colors.lime[800]!,
            Colors.deepOrange,
            Colors.lightBlue,
            Colors.deepPurple,
          ];

          final sectorColors = <String, Color>{};
          if (_viewMode == 1) {
            for (int i = 0; i < allKeys.length; i++) {
              sectorColors[allKeys[i]] =
                  sectorPalette[i % sectorPalette.length];
            }
          }

          Color getColor(String key) {
            if (_viewMode == 0) {
              return assetColors[key] ?? Colors.grey;
            } else {
              return sectorColors[key] ?? Colors.grey;
            }
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Asset Class')),
                    ButtonSegment(value: 1, label: Text('Sector')),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (Set<int> newSelection) {
                    setState(() {
                      _viewMode = newSelection.first;
                      _isEditing = false; // Exit edit mode when switching views
                    });
                  },
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    if (_isEditing) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text('Presets: ',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            ...(_viewMode == 0
                                    ? [
                                        'Aggressive',
                                        'Moderate',
                                        'Conservative',
                                        'All Equity'
                                      ]
                                    : ['Tech Heavy', 'Balanced', 'Defensive'])
                                .map((preset) => Padding(
                                      padding:
                                          const EdgeInsets.only(right: 8.0),
                                      child: ActionChip(
                                        label: Text(preset),
                                        onPressed: () => _applyPreset(preset),
                                      ),
                                    )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!_isEditing) ...[
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SizedBox(
                            height: 220,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text('Current',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: PieChart(
                                          [
                                            charts.Series<PieChartData, String>(
                                              id: 'Current',
                                              domainFn:
                                                  (PieChartData sales, _) =>
                                                      sales.label,
                                              measureFn:
                                                  (PieChartData sales, _) =>
                                                      sales.value,
                                              colorFn: (PieChartData row, _) =>
                                                  charts.ColorUtil
                                                      .fromDartColor(
                                                          getColor(row.label)),
                                              data: currentAllocation.entries
                                                  .map((e) => PieChartData(
                                                      e.key, e.value))
                                                  .toList(),
                                              labelAccessorFn: (PieChartData
                                                          row,
                                                      _) =>
                                                  '${row.label}\n${formatPercentage.format(row.value)}',
                                            )
                                          ],
                                          animate: false,
                                          renderer: charts.ArcRendererConfig(
                                            arcWidth: 60,
                                            arcRendererDecorators: [
                                              charts.ArcLabelDecorator(
                                                  labelPosition: charts
                                                      .ArcLabelPosition.auto)
                                            ],
                                          ),
                                          onSelected: (p0) {},
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const VerticalDivider(width: 32),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Text('Target',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Expanded(
                                        child: PieChart(
                                          [
                                            charts.Series<PieChartData, String>(
                                              id: 'Target',
                                              domainFn:
                                                  (PieChartData sales, _) =>
                                                      sales.label,
                                              measureFn:
                                                  (PieChartData sales, _) =>
                                                      sales.value,
                                              colorFn: (PieChartData row, _) =>
                                                  charts.ColorUtil
                                                      .fromDartColor(
                                                          getColor(row.label)),
                                              data: targets.entries
                                                  .map((e) => PieChartData(
                                                      e.key, e.value))
                                                  .toList(),
                                              labelAccessorFn: (PieChartData
                                                          row,
                                                      _) =>
                                                  '${row.label}\n${formatPercentage.format(row.value)}',
                                            )
                                          ],
                                          animate: false,
                                          renderer: charts.ArcRendererConfig(
                                            arcWidth: 60,
                                            arcRendererDecorators: [
                                              charts.ArcLabelDecorator(
                                                  labelPosition: charts
                                                      .ArcLabelPosition.auto)
                                            ],
                                          ),
                                          onSelected: (p0) {},
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    ...allKeys.map((key) {
                      final currentPct = currentAllocation[key] ?? 0.0;
                      final targetPct = targets[key] ?? 0.0;
                      return _buildAllocationCard(
                          key,
                          currentPct * totalEquity,
                          currentPct,
                          targetPct,
                          totalEquity,
                          targets,
                          getColor(key));
                    }),
                    const SizedBox(height: 20),
                    if (!_isEditing)
                      _buildRecommendations(
                          currentAllocation, targets, totalEquity),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAllocationCard(
      String title,
      double currentAmount,
      double currentPct,
      double targetPct,
      double totalEquity,
      Map<String, double> targets,
      Color color) {
    final diff = currentPct - targetPct;
    final driftAmount = diff * totalEquity;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                Text(formatCurrency.format(currentAmount),
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            // Comparison Bars
            Column(
              children: [
                // Current Bar
                Row(
                  children: [
                    SizedBox(
                        width: 60,
                        child: Text('Current',
                            style: Theme.of(context).textTheme.bodySmall)),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: currentPct.clamp(0.0, 1.0),
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                        width: 50,
                        child: Text(formatPercentage.format(currentPct),
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
                const SizedBox(height: 8),
                // Target Bar
                Row(
                  children: [
                    SizedBox(
                        width: 60,
                        child: Text('Target',
                            style: Theme.of(context).textTheme.bodySmall)),
                    Expanded(
                      child: _isEditing
                          ? Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    setState(() {
                                      targets[title] =
                                          (targetPct - 0.01).clamp(0.0, 1.0);
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: targetPct,
                                    min: 0,
                                    max: 1,
                                    divisions: 100,
                                    label: formatPercentage.format(targetPct),
                                    activeColor: color,
                                    onChanged: (value) {
                                      setState(() {
                                        targets[title] = value;
                                      });
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    setState(() {
                                      targets[title] =
                                          (targetPct + 0.01).clamp(0.0, 1.0);
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            )
                          : Stack(
                              children: [
                                Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: targetPct.clamp(0.0, 1.0),
                                  child: Container(
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                        width: 50,
                        child: Text(formatPercentage.format(targetPct),
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
              ],
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Drift', style: Theme.of(context).textTheme.bodyMedium),
                  Row(
                    children: [
                      Text(
                        formatCurrency.format(driftAmount.abs()),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        diff.abs() < 0.05 ? Icons.check_circle : Icons.warning,
                        size: 16,
                        color: diff.abs() < 0.05 ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatPercentage.format(diff),
                        style: TextStyle(
                          color:
                              diff.abs() < 0.05 ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations(Map<String, double> currentAllocation,
      Map<String, double> targets, double totalEquity) {
    final recommendations = <Map<String, dynamic>>[];

    currentAllocation.forEach((key, currentPct) {
      final targetPct = targets[key] ?? 0;
      final diff = targetPct - currentPct;
      final amount = diff * totalEquity;

      if (amount.abs() > _driftThreshold) {
        recommendations.add({
          'key': key,
          'amount': amount,
          'targetPct': targetPct,
        });
      }
    });

    // Sort by absolute amount descending
    recommendations.sort((a, b) =>
        (b['amount'] as double).abs().compareTo((a['amount'] as double).abs()));

    if (recommendations.isEmpty) {
      return Card(
        elevation: 0,
        color: Colors.green.withOpacity(0.1),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Portfolio is balanced!',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Text('Rebalancing Recommendations',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer)),
          ),
          ...recommendations.map((rec) {
            final key = rec['key'] as String;
            final amount = rec['amount'] as double;
            final targetPct = rec['targetPct'] as double;
            final action = amount > 0
                ? (key == 'Cash' ? 'Raise' : 'Buy')
                : (key == 'Cash' ? 'Invest' : 'Sell');
            final color = amount > 0 ? Colors.green : Colors.red;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child:
                    Icon(amount > 0 ? Icons.add : Icons.remove, color: color),
              ),
              title: Text('$action $key',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Target: ${formatPercentage.format(targetPct)}'),
              trailing: Text(
                formatCurrency.format(amount.abs()),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            );
          }),
        ],
      ),
    );
  }
}

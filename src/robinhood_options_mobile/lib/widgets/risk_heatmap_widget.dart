import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

enum HeatmapMetric { dailyChange, totalReturn }

enum HeatmapView { sector, symbol }

class RiskHeatmapWidget extends StatefulWidget {
  const RiskHeatmapWidget({super.key});

  @override
  State<RiskHeatmapWidget> createState() => _RiskHeatmapWidgetState();
}

class _RiskHeatmapWidgetState extends State<RiskHeatmapWidget> {
  HeatmapMetric _selectedMetric = HeatmapMetric.dailyChange;
  HeatmapView _selectedView = HeatmapView.sector;

  @override
  Widget build(BuildContext context) {
    return Consumer5<PortfolioStore, InstrumentPositionStore,
            OptionPositionStore, ForexHoldingStore, InstrumentStore>(
        builder: (context, portfolioStore, stockPositionStore,
            optionPositionStore, forexHoldingStore, instrumentStore, child) {
      final heatmapData = _calculateHeatmapData(
          stockPositionStore, optionPositionStore, instrumentStore);

      if (heatmapData.isEmpty) {
        return const SizedBox(
          height: 100,
          child: Center(child: Text("No data available")),
        );
      }

      // Sort by Equity (Exposure) descending
      var sortedItems = heatmapData.entries.toList()
        ..sort((a, b) => b.value.equity.compareTo(a.value.equity));

      // Calculate Portfolio Totals
      double totalEquity = 0;
      double totalWeightedChangeSum = 0;
      for (var entry in heatmapData.entries) {
        totalEquity += entry.value.equity;
        totalWeightedChangeSum += entry.value.weightedChangeSum;
      }
      double totalWeightedChange =
          totalEquity > 0 ? totalWeightedChangeSum / totalEquity : 0;

      // Group small items if too many (keeps UI clean)
      const int maxItems = 17;
      if (sortedItems.length > maxItems + 1) {
        var topItems = sortedItems.take(maxItems).toList();
        var otherItems = sortedItems.skip(maxItems).toList();

        if (otherItems.isNotEmpty) {
          double othersEquity = 0;
          double othersWeightedChangeSum = 0;
          List<_PositionDetail> othersPositions = [];

          for (var item in otherItems) {
            othersEquity += item.value.equity;
            othersWeightedChangeSum += item.value.weightedChangeSum;
            othersPositions.addAll(item.value.positions);
          }

          var othersData = _SectorPerformance();
          othersData.equity = othersEquity;
          othersData.weightedChangeSum = othersWeightedChangeSum;
          othersData.positions = othersPositions;

          topItems.add(MapEntry("Others", othersData));
          sortedItems = topItems;
        }
      }

      // Max scale for legend
      double maxScale =
          _selectedMetric == HeatmapMetric.dailyChange ? 0.03 : 0.20;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Risk Heatmap",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat.compactSimpleCurrency()
                              .format(totalEquity),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          "${(totalWeightedChange * 100).toStringAsFixed(2)}%",
                          style: TextStyle(
                            color: totalWeightedChange >= 0
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SegmentedButton<HeatmapView>(
                        segments: const [
                          ButtonSegment(
                            value: HeatmapView.sector,
                            label: Text('Sector'),
                            icon: Icon(Icons.pie_chart, size: 16),
                          ),
                          ButtonSegment(
                            value: HeatmapView.symbol,
                            label: Text('Symbol'),
                            icon: Icon(Icons.show_chart, size: 16),
                          ),
                        ],
                        selected: {_selectedView},
                        onSelectionChanged: (Set<HeatmapView> newSelection) {
                          setState(() {
                            _selectedView = newSelection.first;
                          });
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          padding: MaterialStateProperty.all(EdgeInsets.zero),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<HeatmapMetric>(
                        segments: const [
                          ButtonSegment(
                            value: HeatmapMetric.dailyChange,
                            label: Text('Daily'),
                            icon: Icon(Icons.today, size: 16),
                          ),
                          ButtonSegment(
                            value: HeatmapMetric.totalReturn,
                            label: Text('Total'),
                            icon: Icon(Icons.history, size: 16),
                          ),
                        ],
                        selected: {_selectedMetric},
                        onSelectionChanged: (Set<HeatmapMetric> newSelection) {
                          setState(() {
                            _selectedMetric = newSelection.first;
                          });
                        },
                        style: ButtonStyle(
                          visualDensity: VisualDensity.compact,
                          padding: MaterialStateProperty.all(EdgeInsets.zero),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 350,
            child: _buildTreemap(sortedItems, totalEquity),
          ),
          // Legend
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Text("-${(maxScale * 100).toInt()}%",
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Expanded(
                  child: Container(
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.shade900,
                          Colors.red.shade300,
                          Colors.grey.shade800,
                          Colors.green.shade300,
                          Colors.green.shade900,
                        ],
                      ),
                    ),
                  ),
                ),
                Text("+${(maxScale * 100).toInt()}%",
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _buildTreemap(List<MapEntry<String, _SectorPerformance>> items,
      double portfolioEquity) {
    // Filter out zero equity items to avoid layout issues
    final activeItems = items.where((e) => e.value.equity > 0).toList();
    if (activeItems.isEmpty) {
      return const Center(child: Text("No active positions"));
    }

    double currentBranchEquity =
        activeItems.fold(0, (sum, item) => sum + item.value.equity);
    return _buildTreemapRecursive(
        activeItems, currentBranchEquity, true, portfolioEquity);
  }

  Widget _buildTreemapRecursive(
      List<MapEntry<String, _SectorPerformance>> items,
      double currentBranchEquity,
      bool isHorizontal,
      double portfolioEquity) {
    if (items.length == 1) {
      return _buildTile(items[0], portfolioEquity);
    }

    // Find split point to balance weights
    double currentSum = 0;
    double target = currentBranchEquity / 2;
    int splitIndex = 1;
    double minDiff = double.infinity;

    // Try to find best split
    for (int i = 0; i < items.length - 1; i++) {
      currentSum += items[i].value.equity;
      double diff = (currentSum - target).abs();
      if (diff < minDiff) {
        minDiff = diff;
        splitIndex = i + 1;
      }
    }

    var leftItems = items.sublist(0, splitIndex);
    var rightItems = items.sublist(splitIndex);

    double leftSum = leftItems.fold(0, (sum, item) => sum + item.value.equity);
    double rightSum =
        rightItems.fold(0, (sum, item) => sum + item.value.equity);

    int leftFlex = (leftSum / currentBranchEquity * 1000).round();
    int rightFlex = (rightSum / currentBranchEquity * 1000).round();

    // Ensure at least 1 flex
    if (leftFlex <= 0) leftFlex = 1;
    if (rightFlex <= 0) rightFlex = 1;

    return Flex(
      direction: isHorizontal ? Axis.horizontal : Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: leftFlex,
          child: _buildTreemapRecursive(
              leftItems, leftSum, !isHorizontal, portfolioEquity),
        ),
        Expanded(
          flex: rightFlex,
          child: _buildTreemapRecursive(
              rightItems, rightSum, !isHorizontal, portfolioEquity),
        ),
      ],
    );
  }

  Widget _buildTile(
      MapEntry<String, _SectorPerformance> entry, double portfolioEquity) {
    final sectorName = entry.key;
    final data = entry.value;
    final changePercent = data.weightedChangePercent;
    final equity = data.equity;

    // Determine color based on changePercent
    Color color;
    Color textColor = Colors.white;

    // Adjust intensity scaling based on metric
    double maxScale =
        _selectedMetric == HeatmapMetric.dailyChange ? 0.03 : 0.20;

    if (changePercent >= 0) {
      final intensity = (changePercent / maxScale).clamp(0.0, 1.0);
      color =
          Color.lerp(Colors.green.shade300, Colors.green.shade900, intensity)!;
    } else {
      final intensity = (changePercent.abs() / maxScale).clamp(0.0, 1.0);
      color = Color.lerp(Colors.red.shade300, Colors.red.shade900, intensity)!;
    }

    return InkWell(
      onTap: () =>
          _showSectorDetails(context, sectorName, data, portfolioEquity),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.all(2), // Small gap between tiles
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.8),
              color,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(builder: (context, constraints) {
          // Hide text if tile is too small
          if (constraints.maxWidth < 30 || constraints.maxHeight < 30) {
            return Container();
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                sectorName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: (constraints.maxWidth / 10).clamp(10.0, 14.0),
                  shadows: [
                    Shadow(
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (constraints.maxHeight > 50) ...[
                const SizedBox(height: 2),
                Text(
                  NumberFormat.compactSimpleCurrency().format(equity),
                  style: TextStyle(
                    color: textColor.withOpacity(0.9),
                    fontSize: (constraints.maxWidth / 12).clamp(9.0, 12.0),
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
                Text(
                  "${(changePercent * 100).toStringAsFixed(2)}%",
                  style: TextStyle(
                    color: textColor,
                    fontSize: (constraints.maxWidth / 10).clamp(10.0, 14.0),
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
                if (constraints.maxHeight > 70)
                  Text(
                    "(${(equity / portfolioEquity * 100).toStringAsFixed(1)}%)",
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: (constraints.maxWidth / 14).clamp(8.0, 10.0),
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
              ]
            ],
          );
        }),
      ),
    );
  }

  void _showSectorDetails(BuildContext context, String groupName,
      _SectorPerformance data, double portfolioEquity) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        // Sort positions by equity descending
        final sortedPositions = data.positions
          ..sort((a, b) => b.equity.compareTo(a.equity));

        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "$groupName Details",
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _selectedMetric == HeatmapMetric.dailyChange
                        ? "Daily Change"
                        : "Total Return",
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildDetailChip(
                    context,
                    "Equity",
                    NumberFormat.compactSimpleCurrency().format(data.equity),
                  ),
                  const SizedBox(width: 12),
                  _buildDetailChip(
                    context,
                    "Portfolio",
                    "${(data.equity / portfolioEquity * 100).toStringAsFixed(1)}%",
                  ),
                  const SizedBox(width: 12),
                  _buildDetailChip(
                    context,
                    "Positions",
                    "${data.positions.length}",
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: sortedPositions.length,
                  itemBuilder: (context, index) {
                    final pos = sortedPositions[index];
                    final changeColor =
                        pos.changePercent >= 0 ? Colors.green : Colors.red;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Text(pos.type == 'Option' ? 'Op' : 'St',
                            style: const TextStyle(fontSize: 10)),
                      ),
                      title: Text(pos.symbol),
                      subtitle: Text(pos.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            NumberFormat.simpleCurrency().format(pos.equity),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "${(pos.changePercent * 100).toStringAsFixed(2)}%",
                            style: TextStyle(color: changeColor),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailChip(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }

  Map<String, _SectorPerformance> _calculateHeatmapData(
      InstrumentPositionStore stockStore,
      OptionPositionStore optionStore,
      InstrumentStore instrumentStore) {
    final Map<String, _SectorPerformance> groups = {};

    // 1. Process Stocks
    for (var position in stockStore.items) {
      final instrument = position.instrumentObj;
      if (instrument == null) continue;

      final fundamentals = instrument.fundamentalsObj;
      final quote = instrument.quoteObj;

      final sector = fundamentals?.sector ?? 'Unknown';
      final symbol = instrument.symbol;
      final name = instrument.simpleName ?? instrument.name;

      // Determine grouping key
      final groupKey = _selectedView == HeatmapView.sector ? sector : symbol;

      final quantity = position.quantity ?? 0;
      final price = quote?.lastTradePrice ?? position.averageBuyPrice ?? 0;
      final prevClose = quote?.previousClose ?? price;
      final avgBuyPrice = position.averageBuyPrice ?? 0;

      final equity = quantity * price;

      double changePercent = 0;
      if (_selectedMetric == HeatmapMetric.dailyChange) {
        if (prevClose > 0) {
          changePercent = (price - prevClose) / prevClose;
        }
      } else {
        // Total Return
        if (avgBuyPrice > 0) {
          changePercent = (price - avgBuyPrice) / avgBuyPrice;
        }
      }

      if (!groups.containsKey(groupKey)) {
        groups[groupKey] = _SectorPerformance();
      }

      groups[groupKey]!
          .addPosition(symbol, name, equity, changePercent, 'Stock');
    }

    // 2. Process Options
    for (var position in optionStore.items) {
      final optionInstrument = position.optionInstrument;
      if (optionInstrument == null || optionInstrument.optionMarketData == null)
        continue;

      // Find underlying instrument for sector
      final chainSymbol = position.symbol;
      final instrument = instrumentStore.items
          .firstWhereOrNull((i) => i.symbol == chainSymbol);

      final sector = instrument?.fundamentalsObj?.sector ?? 'Unknown';
      final symbol = position.symbol;

      // Determine grouping key
      // For options, if view is 'symbol', we group by the underlying symbol (chainSymbol)
      // so all options for AAPL are grouped under AAPL.
      final groupKey = _selectedView == HeatmapView.sector ? sector : symbol;

      // Construct name
      String name = position.strategy;
      if (position.legs.isNotEmpty) {
        final leg = position.legs.first;
        final expDate = leg.expirationDate != null
            ? DateFormat('MM/dd').format(leg.expirationDate!)
            : '';
        final strike = leg.strikePrice != null ? "\$${leg.strikePrice}" : '';
        final type = leg.optionType.toUpperCase();
        name = "$type $expDate $strike";
      }

      final equity = position.marketValue;

      double changePercent = 0;
      if (_selectedMetric == HeatmapMetric.dailyChange) {
        changePercent = position.changePercentToday;
      } else {
        // Total Return
        changePercent = position.gainLossPercent;
      }

      if (!groups.containsKey(groupKey)) {
        groups[groupKey] = _SectorPerformance();
      }

      groups[groupKey]!
          .addPosition(symbol, name, equity, changePercent, 'Option');
    }

    return groups;
  }
}

class _SectorPerformance {
  double equity = 0;
  double weightedChangeSum = 0;
  List<_PositionDetail> positions = [];

  void addPosition(String symbol, String name, double positionEquity,
      double changePercent, String type) {
    equity += positionEquity;
    weightedChangeSum += positionEquity * changePercent;
    positions.add(
        _PositionDetail(symbol, name, positionEquity, changePercent, type));
  }

  double get weightedChangePercent {
    if (equity == 0) return 0;
    return weightedChangeSum / equity;
  }
}

class _PositionDetail {
  final String symbol;
  final String name;
  final double equity;
  final double changePercent;
  final String type;

  _PositionDetail(
      this.symbol, this.name, this.equity, this.changePercent, this.type);
}

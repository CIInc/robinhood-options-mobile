import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/tax_lot.dart';

/// Modal bottom sheet allowing granular per-lot share allocation for specified-lot selling.
class TaxLotSelectionSheet extends StatefulWidget {
  final String symbol;
  final double orderQuantity;
  final double currentPrice;
  final List<TaxLot> taxLots;
  final Map<String, double> initialAllocations;
  final ValueChanged<Map<String, double>> onAllocationsSaved;

  const TaxLotSelectionSheet({
    super.key,
    required this.symbol,
    required this.orderQuantity,
    required this.currentPrice,
    required this.taxLots,
    required this.initialAllocations,
    required this.onAllocationsSaved,
  });

  static Future<void> show(
    BuildContext context, {
    required String symbol,
    required double orderQuantity,
    required double currentPrice,
    required List<TaxLot> taxLots,
    required Map<String, double> initialAllocations,
    required ValueChanged<Map<String, double>> onAllocationsSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaxLotSelectionSheet(
        symbol: symbol,
        orderQuantity: orderQuantity,
        currentPrice: currentPrice,
        taxLots: taxLots,
        initialAllocations: initialAllocations,
        onAllocationsSaved: onAllocationsSaved,
      ),
    );
  }

  @override
  State<TaxLotSelectionSheet> createState() => _TaxLotSelectionSheetState();
}

class _TaxLotSelectionSheetState extends State<TaxLotSelectionSheet> {
  late Map<String, double> _allocations;
  final formatCurrency = NumberFormat.simpleCurrency();
  final formatDate = DateFormat.yMMMd();

  @override
  void initState() {
    super.initState();
    _allocations = Map<String, double>.from(widget.initialAllocations);
  }

  double get _totalAllocated =>
      _allocations.values.fold(0.0, (sum, val) => sum + val);

  double get _remainingToAllocate =>
      max(0.0, widget.orderQuantity - _totalAllocated);

  bool get _isAllocationComplete =>
      (_totalAllocated - widget.orderQuantity).abs() < 0.0001;

  void _applyQuickSort(TaxLotStrategy strategy) {
    setState(() {
      _allocations.clear();
      final sorted = List<TaxLot>.from(widget.taxLots.where((l) => l.isSelectable && l.quantityAvailable > 0));
      if (strategy == TaxLotStrategy.hifo) {
        sorted.sort((a, b) => b.costPerShare.compareTo(a.costPerShare));
      } else if (strategy == TaxLotStrategy.fifo) {
        sorted.sort((a, b) => a.openDate.compareTo(b.openDate));
      } else if (strategy == TaxLotStrategy.lifo) {
        sorted.sort((a, b) => b.openDate.compareTo(a.openDate));
      }

      double remaining = widget.orderQuantity;
      for (final lot in sorted) {
        if (remaining <= 0) break;
        final toAssign = min(remaining, lot.quantityAvailable);
        if (toAssign > 0) {
          _allocations[lot.openLotId] = toAssign;
          remaining -= toAssign;
        }
      }
    });
  }

  void _setMaxForLot(TaxLot lot) {
    setState(() {
      final current = _allocations[lot.openLotId] ?? 0.0;
      final remaining = widget.orderQuantity - (_totalAllocated - current);
      final toAssign = min(lot.quantityAvailable, max(0.0, remaining));
      if (toAssign > 0) {
        _allocations[lot.openLotId] = toAssign;
      } else {
        _allocations.remove(lot.openLotId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);

    final progress = widget.orderQuantity > 0
        ? min(1.0, _totalAllocated / widget.orderQuantity)
        : 0.0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Specific Tax Lot Matching',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Target: ${widget.orderQuantity % 1 == 0 ? widget.orderQuantity.toInt() : widget.orderQuantity.toStringAsFixed(4)} shares of ${widget.symbol}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Allocation Progress Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Card(
              elevation: 0,
              color: _isAllocationComplete
                  ? Colors.green.withValues(alpha: 0.12)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _isAllocationComplete
                      ? Colors.green.withValues(alpha: 0.4)
                      : theme.dividerColor.withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isAllocationComplete
                                  ? Icons.check_circle
                                  : Icons.pie_chart_outline,
                              size: 18,
                              color: _isAllocationComplete
                                  ? Colors.green
                                  : theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Allocated Shares',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${_totalAllocated % 1 == 0 ? _totalAllocated.toInt() : _totalAllocated.toStringAsFixed(4)} / ${widget.orderQuantity % 1 == 0 ? widget.orderQuantity.toInt() : widget.orderQuantity.toStringAsFixed(4)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _isAllocationComplete
                                ? Colors.green
                                : _totalAllocated > widget.orderQuantity
                                    ? Colors.red
                                    : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _isAllocationComplete
                            ? Colors.green
                            : _totalAllocated > widget.orderQuantity
                                ? Colors.red
                                : theme.colorScheme.primary,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    if (!_isAllocationComplete) ...[
                      const SizedBox(height: 6),
                      Text(
                        _totalAllocated > widget.orderQuantity
                            ? 'Over-allocated by ${(_totalAllocated - widget.orderQuantity).toStringAsFixed(2)} shares'
                            : 'Need ${_remainingToAllocate % 1 == 0 ? _remainingToAllocate.toInt() : _remainingToAllocate.toStringAsFixed(4)} more shares',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _totalAllocated > widget.orderQuantity
                              ? Colors.red
                              : theme.colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Quick Presets Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  'Quick Fill:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.trending_down, size: 14),
                  label: const Text('Max Loss (HIFO)', style: TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _applyQuickSort(TaxLotStrategy.hifo),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.history, size: 14),
                  label: const Text('FIFO', style: TextStyle(fontSize: 12)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _applyQuickSort(TaxLotStrategy.fifo),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _allocations.clear()),
                  child: const Text('Reset', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Lots List
          Expanded(
            child: widget.taxLots.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'No tax lots available for ${widget.symbol}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: widget.taxLots.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final lot = widget.taxLots[index];
                      final allocated = _allocations[lot.openLotId] ?? 0.0;
                      final gainLossPerShare = widget.currentPrice - lot.costPerShare;
                      final isLoss = gainLossPerShare < 0;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: allocated > 0
                                ? theme.colorScheme.primary
                                : theme.dividerColor.withValues(alpha: 0.2),
                            width: allocated > 0 ? 1.5 : 1.0,
                          ),
                        ),
                        color: allocated > 0
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                            : theme.colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Acquisition Date & Term
                                  Text(
                                    formatDate.format(lot.openDate),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: lot.isLongTerm
                                          ? Colors.blue.withValues(alpha: 0.15)
                                          : Colors.orange.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      lot.isLongTerm ? 'Long-Term' : 'Short-Term',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: lot.isLongTerm ? Colors.blue : Colors.orange,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  // Available shares indicator
                                  Text(
                                    'Avail: ${lot.quantityAvailable % 1 == 0 ? lot.quantityAvailable.toInt() : lot.quantityAvailable.toStringAsFixed(2)} sh',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  // Cost Basis
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Cost / Share',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          formatCurrency.format(lot.costPerShare),
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Unrealized Gain/Loss
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Gain / Loss',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          '${isLoss ? '' : '+'}${formatCurrency.format(gainLossPerShare)}/sh',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: isLoss ? Colors.red : Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Allocated Control
                                  Row(
                                    children: [
                                      if (allocated > 0)
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () {
                                            setState(() {
                                              if (allocated <= 1) {
                                                _allocations.remove(lot.openLotId);
                                              } else {
                                                _allocations[lot.openLotId] = allocated - 1;
                                              }
                                            });
                                          },
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          allocated % 1 == 0
                                              ? allocated.toInt().toString()
                                              : allocated.toStringAsFixed(2),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: allocated > 0
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, size: 20),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          setState(() {
                                            final next = min(lot.quantityAvailable, allocated + 1);
                                            _allocations[lot.openLotId] = next;
                                          });
                                        },
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 6),
                                          minimumSize: const Size(36, 28),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () => _setMaxForLot(lot),
                                        child: const Text('Max', style: TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Confirm Button
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + mediaQuery.padding.bottom),
            child: FilledButton(
              onPressed: _isAllocationComplete
                  ? () {
                      widget.onAllocationsSaved(_allocations);
                      Navigator.pop(context);
                    }
                  : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                _isAllocationComplete
                    ? 'Confirm Specified Lots'
                    : 'Allocate ${widget.orderQuantity % 1 == 0 ? widget.orderQuantity.toInt() : widget.orderQuantity.toStringAsFixed(2)} Shares to Confirm',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

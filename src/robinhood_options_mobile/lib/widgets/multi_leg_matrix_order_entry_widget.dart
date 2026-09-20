import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/multi_leg_order_entry.dart';
import 'package:robinhood_options_mobile/model/option_strategy.dart';

/// A multi-column matrix order entry widget designed for widescreen, landscape,
/// and tablet layouts, allowing options traders to construct and execute multi-leg strategies
/// side-by-side with full-width interactive charts.
class MultiLegMatrixOrderEntryWidget extends StatefulWidget {
  final Instrument instrument;
  final MultiLegOrderEntry? initialOrder;
  final VoidCallback? onCollapse;
  final Function(MultiLegOrderEntry)? onOrderSubmitted;
  final bool isCollapsible;

  const MultiLegMatrixOrderEntryWidget({
    super.key,
    required this.instrument,
    this.initialOrder,
    this.onCollapse,
    this.onOrderSubmitted,
    this.isCollapsible = true,
  });

  @override
  State<MultiLegMatrixOrderEntryWidget> createState() =>
      _MultiLegMatrixOrderEntryWidgetState();
}

class _MultiLegMatrixOrderEntryWidgetState
    extends State<MultiLegMatrixOrderEntryWidget> {
  late MultiLegOrderEntry _order;
  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency();
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');
  final TextEditingController _limitPriceController = TextEditingController();

  final List<String> _strategyPresets = [
    'Bull Call Spread',
    'Bear Put Spread',
    'Bull Put Spread',
    'Bear Call Spread',
    'Long Straddle',
    'Long Strangle',
    'Iron Condor',
    'Single Option',
    'Custom Multi-Leg',
  ];

  @override
  void initState() {
    super.initState();
    final spotPrice = widget.instrument.quoteObj?.lastTradePrice ??
        widget.instrument.quoteObj?.lastExtendedHoursTradePrice ??
        widget.instrument.quoteObj?.previousClose ??
        150.0;

    _order = widget.initialOrder ??
        MultiLegOrderEntry.bullCallSpread(
          symbol: widget.instrument.symbol,
          spotPrice: spotPrice,
        );

    _limitPriceController.text = _order.absNetPremium.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _limitPriceController.dispose();
    super.dispose();
  }

  double get _spotPrice =>
      widget.instrument.quoteObj?.lastTradePrice ??
      widget.instrument.quoteObj?.lastExtendedHoursTradePrice ??
      widget.instrument.quoteObj?.previousClose ??
      150.0;

  void _onStrategySelected(String strategy) {
    setState(() {
      switch (strategy) {
        case 'Bull Call Spread':
          _order = MultiLegOrderEntry.bullCallSpread(
            symbol: widget.instrument.symbol,
            spotPrice: _spotPrice,
          );
          break;
        case 'Bear Put Spread':
          _order = MultiLegOrderEntry.bearPutSpread(
            symbol: widget.instrument.symbol,
            spotPrice: _spotPrice,
          );
          break;
        case 'Bull Put Spread':
          _order = MultiLegOrderEntry.bullPutSpread(
            symbol: widget.instrument.symbol,
            spotPrice: _spotPrice,
          );
          break;
        case 'Bear Call Spread':
          _order = MultiLegOrderEntry.bearCallSpread(
            symbol: widget.instrument.symbol,
            spotPrice: _spotPrice,
          );
          break;
        case 'Long Straddle':
          _order = MultiLegOrderEntry.straddle(
            symbol: widget.instrument.symbol,
            spotPrice: _spotPrice,
          );
          break;
        case 'Long Strangle':
          _order = MultiLegOrderEntry.strangle(
            symbol: widget.instrument.symbol,
            spotPrice: _spotPrice,
          );
          break;
        case 'Iron Condor':
          _order = MultiLegOrderEntry.ironCondor(
            symbol: widget.instrument.symbol,
            spotPrice: _spotPrice,
          );
          break;
        case 'Single Option':
          _order = MultiLegOrderEntry.singleLeg(
            symbol: widget.instrument.symbol,
            spotPrice: _spotPrice,
          );
          break;
        case 'Custom Multi-Leg':
          _order.strategyType = StrategyType.custom;
          _order.strategyName = 'Custom Multi-Leg';
          break;
      }
      _limitPriceController.text = _order.absNetPremium.toStringAsFixed(2);
      _order.limitPrice = _order.absNetPremium;
    });
  }

  void _addLeg() {
    if (_order.legs.length >= 4) return;
    setState(() {
      final exp = _order.legs.isNotEmpty
          ? _order.legs.first.expirationDate
          : DateTime.now().add(const Duration(days: 30));
      _order.legs.add(
        MultiLegOrderLeg(
          id: 'leg_${DateTime.now().millisecondsSinceEpoch}',
          action: LegAction.buy,
          type: LegType.call,
          strike: _spotPrice,
          expirationDate: exp,
          premium: _spotPrice * 0.02,
        ),
      );
      _order.strategyType = StrategyType.custom;
      _order.strategyName = 'Custom Multi-Leg';
      _limitPriceController.text = _order.absNetPremium.toStringAsFixed(2);
      _order.limitPrice = _order.absNetPremium;
    });
  }

  void _removeLeg(int index) {
    if (_order.legs.length <= 1) return;
    setState(() {
      _order.legs.removeAt(index);
      _order.strategyType = StrategyType.custom;
      _order.strategyName = 'Custom Multi-Leg';
      _limitPriceController.text = _order.absNetPremium.toStringAsFixed(2);
      _order.limitPrice = _order.absNetPremium;
    });
  }

  void _updateStrike(int index, double delta) {
    setState(() {
      final newStrike = (_order.legs[index].strike + delta).clamp(0.5, 9999.0);
      _order.legs[index].strike = (newStrike * 100).round() / 100.0;
      _limitPriceController.text = _order.absNetPremium.toStringAsFixed(2);
      _order.limitPrice = _order.absNetPremium;
    });
  }

  Future<void> _pickExpirationDate(int index) async {
    final initialDate = _order.legs[index].expirationDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(DateTime.now())
          ? initialDate
          : DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() {
        _order.legs[index].expirationDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.grey.shade50,
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(theme),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _buildStrategySelector(),
                const SizedBox(height: 8),
                _buildLegsMatrix(theme),
                const SizedBox(height: 8),
                _buildAnalyticsCard(theme),
                const SizedBox(height: 8),
                _buildOrderControls(theme),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildBottomAction(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.table_chart, size: 20, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Multi-Leg Matrix Order',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${widget.instrument.symbol} • Spot: ${_currencyFormat.format(_spotPrice)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (widget.isCollapsible && widget.onCollapse != null)
            IconButton(
              icon: const Icon(Icons.close_fullscreen, size: 18),
              tooltip: 'Collapse Order Entry',
              onPressed: widget.onCollapse,
            ),
        ],
      ),
    );
  }

  Widget _buildStrategySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _strategyPresets.contains(_order.strategyName)
              ? _order.strategyName
              : 'Custom Multi-Leg',
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          items: _strategyPresets.map((strategy) {
            return DropdownMenuItem<String>(
              value: strategy,
              child: Text(
                strategy,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) _onStrategySelected(val);
          },
        ),
      ),
    );
  }

  Widget _buildLegsMatrix(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Strategy Legs (${_order.legs.length})',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_order.legs.length < 4)
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Leg', style: TextStyle(fontSize: 12)),
                onPressed: _addLeg,
              ),
          ],
        ),
        const SizedBox(height: 4),
        ..._order.legs.asMap().entries.map((entry) {
          final index = entry.key;
          final leg = entry.value;
          return _buildLegCard(theme, index, leg);
        }),
      ],
    );
  }

  Widget _buildLegCard(ThemeData theme, int index, MultiLegOrderLeg leg) {
    final isBuy = leg.action == LegAction.buy;
    final isCall = leg.type == LegType.call;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isBuy
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Buy / Sell Selector
              InkWell(
                onTap: () {
                  setState(() {
                    leg.action = isBuy ? LegAction.sell : LegAction.buy;
                    _order.strategyType = StrategyType.custom;
                    _order.strategyName = 'Custom Multi-Leg';
                    _limitPriceController.text =
                        _order.absNetPremium.toStringAsFixed(2);
                    _order.limitPrice = _order.absNetPremium;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isBuy
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isBuy ? 'BUY' : 'SELL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isBuy ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Call / Put Selector
              InkWell(
                onTap: () {
                  setState(() {
                    leg.type = isCall ? LegType.put : LegType.call;
                    _order.strategyType = StrategyType.custom;
                    _order.strategyName = 'Custom Multi-Leg';
                    _limitPriceController.text =
                        _order.absNetPremium.toStringAsFixed(2);
                    _order.limitPrice = _order.absNetPremium;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCall ? 'CALL' : 'PUT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Strike Stepper
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _updateStrike(index, -1.0),
                    ),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _currencyFormat.format(leg.strike),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _updateStrike(index, 1.0),
                    ),
                  ],
                ),
              ),
              // Remove Leg
              if (_order.legs.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Remove Leg',
                  onPressed: () => _removeLeg(index),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Expiration Chip
              Flexible(
                child: InkWell(
                  onTap: () => _pickExpirationDate(index),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _dateFormat.format(leg.expirationDate),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.blueAccent),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Premium
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Mark: ',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    _currencyFormat.format(leg.premium),
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(ThemeData theme) {
    final netCredit = _order.isCredit;
    final netDebit = _order.isDebit;
    final netLabel =
        netCredit ? 'NET CREDIT' : (netDebit ? 'NET DEBIT' : 'EVEN');
    final netColor = netCredit
        ? Colors.green
        : (netDebit ? Colors.amber.shade800 : Colors.grey);

    final maxProfit = _order.totalMaxProfit;
    final maxLoss = _order.totalMaxLoss;
    final breakevens = _order.breakevens;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: netColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$netLabel: ${_currencyFormat.format(_order.absNetPremium)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: netColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Total: ${_currencyFormat.format(_order.estimatedTotal)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Max Profit',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      maxProfit != null
                          ? _currencyFormat.format(maxProfit)
                          : 'Unlimited',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Max Loss',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      maxLoss != null
                          ? _currencyFormat.format(maxLoss)
                          : 'Unlimited',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Risk / Reward',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      _order.riskRewardRatio,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (breakevens.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Text('Breakeven: ',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text(
                  breakevens.map((b) => _currencyFormat.format(b)).join(' & '),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderControls(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Contracts Quantity
              Expanded(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        if (_order.quantity > 1) {
                          setState(() {
                            _order.quantity--;
                          });
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${_order.quantity} cntr',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() {
                          _order.quantity++;
                        });
                      },
                    ),
                  ],
                ),
              ),
              // Order Type
              DropdownButton<String>(
                value: _order.orderType,
                underline: const SizedBox(),
                isDense: true,
                items: const [
                  DropdownMenuItem(
                      value: 'Limit',
                      child: Text('Limit', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(
                      value: 'Market',
                      child: Text('Market', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _order.orderType = val);
                },
              ),
              const SizedBox(width: 8),
              // TIF
              DropdownButton<String>(
                value: _order.timeInForce,
                underline: const SizedBox(),
                isDense: true,
                items: const [
                  DropdownMenuItem(
                      value: 'gtc',
                      child: Text('GTC', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(
                      value: 'day',
                      child: Text('Day', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _order.timeInForce = val);
                },
              ),
            ],
          ),
          if (_order.orderType == 'Limit') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _limitPriceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Net Limit Price',
                      isDense: true,
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null) {
                        setState(() => _order.limitPrice = parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    setState(() {
                      _limitPriceController.text =
                          _order.absNetPremium.toStringAsFixed(2);
                      _order.limitPrice = _order.absNetPremium;
                    });
                  },
                  child: const Text('Mid', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomAction(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: _order.isCredit
                ? Colors.green.shade700
                : theme.colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          icon: const Icon(Icons.flash_on, size: 16),
          label: Text(
            'Review ${_order.strategyName} (${_currencyFormat.format(_order.estimatedTotal)})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          onPressed: _showOrderReviewDialog,
        ),
      ),
    );
  }

  void _showOrderReviewDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Review ${_order.strategyName}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.instrument.symbol} • ${_order.quantity} Contract(s)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                    'Order Type: ${_order.orderType} (${_order.timeInForce.toUpperCase()})'),
                Text(
                  'Net Price: ${_currencyFormat.format(_order.limitPrice ?? _order.absNetPremium)} '
                  '(${_order.isCredit ? "Credit" : "Debit"})',
                ),
                Text(
                  'Estimated Total: ${_currencyFormat.format(_order.estimatedTotal)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Divider(height: 16),
                const Text('Leg Breakdown:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                ..._order.legs.map((leg) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${leg.action.name.toUpperCase()} 1 '
                        '${widget.instrument.symbol} '
                        '${_dateFormat.format(leg.expirationDate)} '
                        '${_currencyFormat.format(leg.strike)} '
                        '${leg.type.name.toUpperCase()} @ ${_currencyFormat.format(leg.premium)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                widget.onOrderSubmitted?.call(_order);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Multi-leg ${_order.strategyName} simulated order submitted!',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text('Confirm Order'),
            ),
          ],
        );
      },
    );
  }
}

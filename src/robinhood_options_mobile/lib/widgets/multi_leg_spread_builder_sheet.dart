import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/multi_leg_order_entry.dart';
import 'package:robinhood_options_mobile/model/option_strategy.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

/// A modal bottom sheet / order pad providing quick-entry templates for complex spreads
/// (Vertical Spreads, Straddles, Strangles, Iron Condors, Calendar Spreads)
/// with real-time net credit/debit calculation across Schwab, Robinhood, and Paper trading.
class MultiLegSpreadBuilderSheet extends StatefulWidget {
  final Instrument instrument;
  final IBrokerageService service;
  final BrokerageUser user;
  final Account? account;
  final MultiLegOrderEntry? initialOrder;
  final Function(MultiLegOrderEntry)? onOrderPlaced;

  const MultiLegSpreadBuilderSheet({
    super.key,
    required this.instrument,
    required this.service,
    required this.user,
    this.account,
    this.initialOrder,
    this.onOrderPlaced,
  });

  @override
  State<MultiLegSpreadBuilderSheet> createState() =>
      _MultiLegSpreadBuilderSheetState();
}

class _MultiLegSpreadBuilderSheetState
    extends State<MultiLegSpreadBuilderSheet> {
  late MultiLegOrderEntry _order;
  final NumberFormat _currencyFormat = NumberFormat.simpleCurrency();
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');
  final TextEditingController _limitPriceController = TextEditingController();
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> _strategyTemplates = [
    'Bull Call Spread',
    'Bear Put Spread',
    'Bull Put Spread',
    'Bear Call Spread',
    'Long Straddle',
    'Short Straddle',
    'Long Strangle',
    'Short Strangle',
    'Iron Condor',
    'Call Calendar Spread',
    'Put Calendar Spread',
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
    _quantityController.text = _order.quantity.toString();
  }

  @override
  void dispose() {
    _limitPriceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  double get _spotPrice =>
      widget.instrument.quoteObj?.lastTradePrice ??
      widget.instrument.quoteObj?.lastExtendedHoursTradePrice ??
      widget.instrument.quoteObj?.previousClose ??
      150.0;

  double get _strikeStep {
    if (_spotPrice < 25) return 0.5;
    if (_spotPrice < 50) return 1.0;
    if (_spotPrice < 150) return 2.5;
    if (_spotPrice < 300) return 5.0;
    return 10.0;
  }

  void _onTemplateSelected(String template) {
    setState(() {
      _errorMessage = null;
      switch (template) {
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
        case 'Short Straddle':
          _order = MultiLegOrderEntry.shortStraddle(
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
        case 'Short Strangle':
          _order = MultiLegOrderEntry.shortStrangle(
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
        case 'Call Calendar Spread':
          _order = MultiLegOrderEntry.calendarSpread(
            symbol: widget.instrument.symbol,
            spotPrice: _spotPrice,
            type: LegType.call,
          );
          break;
        case 'Put Calendar Spread':
          _order = MultiLegOrderEntry.calendarSpread(
            symbol: widget.instrument.symbol,
            spotPrice: _spotPrice,
            type: LegType.put,
          );
          break;
        case 'Custom Multi-Leg':
          _order = MultiLegOrderEntry.custom(
            symbol: widget.instrument.symbol,
            spotPrice: _spotPrice,
            legs: List.from(_order.legs),
          );
          break;
      }
      _limitPriceController.text = _order.absNetPremium.toStringAsFixed(2);
      _order.limitPrice = _order.absNetPremium;
    });
  }

  void _addCustomLeg() {
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

  Account _resolveAccount(BuildContext context) {
    if (widget.account != null) return widget.account!;
    try {
      final accountStore = Provider.of<AccountStore>(context, listen: false);
      if (accountStore.selectedAccount != null) {
        return accountStore.selectedAccount!;
      }
      if (accountStore.items.isNotEmpty) {
        return accountStore.items.first;
      }
    } catch (_) {}
    return Account(
      '',
      0,
      widget.user.userName ?? 'default',
      'margin',
      0,
      'option_level_2',
      0,
      0,
      0,
    );
  }

  Future<void> _showConfirmationDialog(BuildContext context) async {
    final account = _resolveAccount(context);
    final limitPrice = double.tryParse(_limitPriceController.text.trim()) ??
        _order.absNetPremium;
    _order.limitPrice = limitPrice;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: Text('Confirm ${_order.strategyName}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.instrument.symbol,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Chip(
                      label: Text(
                        _order.isCredit ? 'NET CREDIT' : 'NET DEBIT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _order.isCredit ? Colors.green : Colors.blue,
                        ),
                      ),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Contracts: ${_order.quantity}'),
                Text('Order Type: ${_order.orderType} (${_order.timeInForce.toUpperCase()})'),
                Text(
                  'Limit Price: ${_currencyFormat.format(limitPrice)} per share',
                ),
                Text(
                  'Estimated Total: ${_currencyFormat.format(_order.estimatedTotal)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Divider(height: 20),
                const Text(
                  'Legs:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                ..._order.legs.map((leg) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '• ${leg.action.name.toUpperCase()} 1 '
                        '${widget.instrument.symbol} '
                        '${_dateFormat.format(leg.expirationDate)} '
                        '${_currencyFormat.format(leg.strike)} '
                        '${leg.type.name.toUpperCase()} @ ${_currencyFormat.format(leg.premium)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    )),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Routing via ${widget.user.source.name.toUpperCase()} • '
                          'Account: ${account.accountNumber.isNotEmpty ? account.accountNumber : "Active"}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('confirm-spread-order'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Confirm & Place Order'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _executeOrder(account);
    }
  }

  Future<void> _executeOrder(Account account) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final legs = _order.toBrokerageLegs();
      final price = _order.limitPrice ?? _order.absNetPremium;
      final direction = _order.isCredit ? 'credit' : 'debit';

      await widget.service.placeMultiLegOptionsOrder(
        widget.user,
        account,
        legs,
        direction,
        price,
        _order.quantity,
        type: _order.orderType.toLowerCase(),
        timeInForce: _order.timeInForce.toLowerCase(),
      );

      widget.onOrderPlaced?.call(_order);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_order.strategyName} order submitted successfully!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit spread order: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spread Builder • ${widget.instrument.symbol}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Spot: ${_currencyFormat.format(_spotPrice)}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About Spread Templates',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Multi-Leg Spreads'),
                  content: const Text(
                    'Select a pre-configured template (Vertical, Straddle, '
                    'Strangle, Iron Condor, or Calendar Spread) or build a custom multi-leg structure. '
                    'Real-time calculations show net debit or credit, max risk/reward, and breakevens.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                            color: theme.colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  _buildTemplateChips(theme),
                  const SizedBox(height: 12),
                  _buildMetricsSummaryCard(theme),
                  const SizedBox(height: 16),
                  _buildLegsSection(theme),
                  const SizedBox(height: 16),
                  _buildOrderParameters(theme),
                  const SizedBox(height: 24),
                ],
              ),
            ),
            _buildBottomBar(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateChips(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STRATEGY TEMPLATES',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _strategyTemplates.map((template) {
              final isSelected = _order.strategyName == template ||
                  (_order.strategyType == StrategyType.custom &&
                      template == 'Custom Multi-Leg');
              final keySlug = template.toLowerCase().replaceAll(' ', '-');
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  key: ValueKey('template-$keySlug'),
                  label: Text(template),
                  selected: isSelected,
                  onSelected: (_) => _onTemplateSelected(template),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsSummaryCard(ThemeData theme) {
    final netPrice = _order.limitPrice ?? _order.absNetPremium;
    final isCredit = _order.isCredit;
    final maxProfit = _order.totalMaxProfit;
    final maxLoss = _order.totalMaxLoss;
    final breakevens = _order.breakevens;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Net Order Price',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          _currencyFormat.format(netPrice),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isCredit ? Colors.green : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isCredit
                                ? Colors.green.withValues(alpha: 0.15)
                                : Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isCredit ? 'CREDIT' : 'DEBIT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isCredit ? Colors.green : Colors.blue,
                            ),
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
                      'Estimated Total',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _currencyFormat.format(_order.estimatedTotal),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _metricColumn(
                    theme,
                    label: 'Max Profit',
                    value: maxProfit != null
                        ? _currencyFormat.format(maxProfit)
                        : 'Unlimited',
                    valueColor: Colors.green,
                  ),
                ),
                Expanded(
                  child: _metricColumn(
                    theme,
                    label: 'Max Loss',
                    value: maxLoss != null
                        ? _currencyFormat.format(maxLoss)
                        : 'Undefined',
                    valueColor: Colors.redAccent,
                  ),
                ),
                Expanded(
                  child: _metricColumn(
                    theme,
                    label: 'Breakeven',
                    value: breakevens.isNotEmpty
                        ? breakevens
                            .map((b) => _currencyFormat.format(b))
                            .join(', ')
                        : '—',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricColumn(
    ThemeData theme, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildLegsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STRATEGY LEGS (${_order.legs.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
                letterSpacing: 0.8,
              ),
            ),
            if (_order.legs.length < 4)
              TextButton.icon(
                key: const ValueKey('add-leg-btn'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Leg'),
                onPressed: _addCustomLeg,
              ),
          ],
        ),
        const SizedBox(height: 8),
        ..._order.legs.asMap().entries.map((entry) {
          final index = entry.key;
          final leg = entry.value;
          return _buildLegCard(theme, index, leg);
        }),
      ],
    );
  }

  Widget _buildLegCard(ThemeData theme, int index, MultiLegOrderLeg leg) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: leg.isBuy
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // Buy / Sell Toggle
                SegmentedButton<LegAction>(
                  segments: const [
                    ButtonSegment(value: LegAction.buy, label: Text('Buy')),
                    ButtonSegment(value: LegAction.sell, label: Text('Sell')),
                  ],
                  selected: {leg.action},
                  onSelectionChanged: (val) {
                    setState(() {
                      leg.action = val.first;
                      _recalculate();
                    });
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                // Call / Put Toggle
                SegmentedButton<LegType>(
                  segments: const [
                    ButtonSegment(value: LegType.call, label: Text('Call')),
                    ButtonSegment(value: LegType.put, label: Text('Put')),
                  ],
                  selected: {leg.type},
                  onSelectionChanged: (val) {
                    setState(() {
                      leg.type = val.first;
                      _recalculate();
                    });
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const Spacer(),
                if (_order.legs.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Remove leg',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _removeLeg(index),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Strike editor
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Strike', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          IconButton.outlined(
                            icon: const Icon(Icons.remove, size: 14),
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              setState(() {
                                leg.strike = (leg.strike - _strikeStep)
                                    .clamp(0.5, double.infinity);
                                _recalculate();
                              });
                            },
                          ),
                          Expanded(
                            child: Text(
                              _currencyFormat.format(leg.strike),
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton.outlined(
                            icon: const Icon(Icons.add, size: 14),
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              setState(() {
                                leg.strike += _strikeStep;
                                _recalculate();
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Expiration picker
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Expiration', style: theme.textTheme.bodySmall),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: leg.expirationDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 730)),
                          );
                          if (picked != null) {
                            setState(() {
                              leg.expirationDate = picked;
                              _recalculate();
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: theme.colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _dateFormat.format(leg.expirationDate),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const Icon(Icons.calendar_today, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mark Premium: ${_currencyFormat.format(leg.premium)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  'Impact: ${_currencyFormat.format(leg.signedPremium)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: leg.isSell ? Colors.green : Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _recalculate() {
    _limitPriceController.text = _order.absNetPremium.toStringAsFixed(2);
    _order.limitPrice = _order.absNetPremium;
  }

  Widget _buildOrderParameters(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ORDER SETTINGS',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Order Type
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _order.orderType,
                decoration: const InputDecoration(
                  labelText: 'Order Type',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'Limit', child: Text('Limit')),
                  DropdownMenuItem(value: 'Market', child: Text('Market')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _order.orderType = val;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            // Quantity stepper
            Expanded(
              child: Row(
                children: [
                  IconButton.outlined(
                    icon: const Icon(Icons.remove, size: 16),
                    onPressed: () {
                      if (_order.quantity > 1) {
                        setState(() {
                          _order.quantity--;
                          _quantityController.text = _order.quantity.toString();
                        });
                      }
                    },
                  ),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('spread-quantity'),
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Qty',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null && parsed > 0) {
                          setState(() {
                            _order.quantity = parsed;
                          });
                        }
                      },
                    ),
                  ),
                  IconButton.outlined(
                    icon: const Icon(Icons.add, size: 16),
                    onPressed: () {
                      setState(() {
                        _order.quantity++;
                        _quantityController.text = _order.quantity.toString();
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_order.orderType == 'Limit') ...[
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('spread-limit-price'),
            controller: _limitPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Limit Price per Share',
              prefixText: '\$ ',
              border: const OutlineInputBorder(),
              helperText:
                  'Current Net ${_order.isCredit ? "Credit" : "Debit"}: ${_currencyFormat.format(_order.absNetPremium)}',
            ),
            onChanged: (val) {
              final parsed = double.tryParse(val);
              if (parsed != null) {
                _order.limitPrice = parsed;
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _order.strategyName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_currencyFormat.format(_order.limitPrice ?? _order.absNetPremium)} • ${_order.isCredit ? "Credit" : "Debit"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _order.isCredit ? Colors.green : Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            key: const ValueKey('review-spread-order'),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(_isSubmitting ? 'Submitting...' : 'Review Order'),
            onPressed: _isSubmitting
                ? null
                : () => _showConfirmationDialog(context),
          ),
        ],
      ),
    );
  }
}

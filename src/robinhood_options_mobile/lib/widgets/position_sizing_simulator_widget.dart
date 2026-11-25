import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/trade_strategy_config.dart';

/// Interactive Position Sizing Simulator & Pre-Flight RiskGuard Check Widget.
///
/// Allows users to test real-world trade calculations (Fixed, Target Dollar, Dynamic ATR)
/// across various tickers, prices, and volatilities to preview exact order quantities,
/// notional dollar exposure, and pre-flight RiskGuard ceiling approvals.
class PositionSizingSimulatorWidget extends StatefulWidget {
  final TradeStrategyConfig config;
  final bool isPaperTrading;

  const PositionSizingSimulatorWidget({
    super.key,
    required this.config,
    this.isPaperTrading = false,
  });

  @override
  State<PositionSizingSimulatorWidget> createState() =>
      _PositionSizingSimulatorWidgetState();
}

class _PositionSizingSimulatorWidgetState
    extends State<PositionSizingSimulatorWidget> {
  static const Map<String, ({double price, double atr})> _defaultPresets = {
    'SPY': (price: 585.0, atr: 4.80),
    'AAPL': (price: 225.0, atr: 3.20),
    'NVDA': (price: 140.0, atr: 4.50),
    'TSLA': (price: 340.0, atr: 12.50),
    'MSFT': (price: 420.0, atr: 5.10),
  };

  late String _selectedSymbol;
  late TextEditingController _priceController;
  late TextEditingController _atrController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _selectedSymbol = 'SPY';
    final preset = _defaultPresets[_selectedSymbol]!;
    _priceController =
        TextEditingController(text: preset.price.toStringAsFixed(2));
    _atrController = TextEditingController(text: preset.atr.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _priceController.dispose();
    _atrController.dispose();
    super.dispose();
  }

  void _onSymbolChanged(String? newSymbol) {
    if (newSymbol != null && _defaultPresets.containsKey(newSymbol)) {
      setState(() {
        _selectedSymbol = newSymbol;
        final preset = _defaultPresets[newSymbol]!;
        _priceController.text = preset.price.toStringAsFixed(2);
        _atrController.text = preset.atr.toStringAsFixed(2);
      });
    }
  }

  Widget _buildSymbolDropdown({bool isDense = true}) {
    return DropdownButtonFormField<String>(
      value: _selectedSymbol,
      isExpanded: true,
      isDense: isDense,
      icon: const Icon(Icons.arrow_drop_down, size: 20),
      decoration: const InputDecoration(
        labelText: 'Symbol',
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(),
      ),
      items: _defaultPresets.keys
          .map((s) => DropdownMenuItem(
                value: s,
                child: Text(s, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: _onSymbolChanged,
    );
  }

  Widget _buildPriceField() {
    return TextFormField(
      controller: _priceController,
      decoration: const InputDecoration(
        labelText: 'Price',
        prefixText: '\$',
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildAtrField() {
    return TextFormField(
      controller: _atrController,
      decoration: const InputDecoration(
        labelText: 'ATR (14)',
        prefixText: '\$',
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currencyFormat = NumberFormat.simpleCurrency(decimalDigits: 2);

    // Resolve Account Equity
    double equity = 25000.0;
    try {
      if (widget.isPaperTrading) {
        final paperStore =
            Provider.of<PaperTradingStore>(context, listen: false);
        if (paperStore.equity > 0) equity = paperStore.equity;
      } else {
        final accountStore = Provider.of<AccountStore>(context, listen: false);
        final accountValue = accountStore.selectedAccount?.totalValue ??
            accountStore.selectedAccount?.buyingPower ??
            accountStore.selectedAccount?.portfolioCash;
        if (accountValue != null && accountValue > 0) equity = accountValue;
      }
    } catch (_) {}

    final price = double.tryParse(_priceController.text) ?? 585.0;
    final atr = double.tryParse(_atrController.text) ?? 4.80;

    // Sizing Calculation
    int calculatedQuantity;
    final mode = widget.config.positionSizingMode;

    switch (mode) {
      case PositionSizingMode.targetDollar:
        final targetDollar = widget.config.targetDollarAllocation;
        calculatedQuantity = price > 0 ? (targetDollar / price).floor() : 1;
        if (calculatedQuantity < 1) calculatedQuantity = 1;
        break;
      case PositionSizingMode.dynamicRisk:
        final stopDistance = atr * widget.config.atrMultiplier;
        final riskBudget = equity * widget.config.riskPerTrade;
        calculatedQuantity =
            stopDistance > 0 ? (riskBudget / stopDistance).floor() : 1;
        if (calculatedQuantity < 1) calculatedQuantity = 1;
        break;
      case PositionSizingMode.fixedShares:
        calculatedQuantity = widget.config.tradeQuantity;
        if (calculatedQuantity < 1) calculatedQuantity = 1;
        break;
    }

    final notionalOrderValue = calculatedQuantity * price;
    final positionConcentration =
        equity > 0 ? (notionalOrderValue / equity) : 0.0;

    // Dollar risk at stop loss
    final stopLossDist = widget.config.isDynamicSizing
        ? atr * widget.config.atrMultiplier
        : price * (widget.config.stopLossPercent / 100.0);
    final dollarAtRisk = calculatedQuantity * stopLossDist;
    final riskPercentOfEquity =
        equity > 0 ? (dollarAtRisk / equity) * 100.0 : 0.0;

    // RiskGuard Pre-Flight Checks
    final checkShares =
        widget.config.positionLimitMode != PositionLimitMode.maxPercent;
    final checkPercent =
        widget.config.positionLimitMode != PositionLimitMode.maxShares;

    final exceedsMaxPositionSize =
        checkShares && calculatedQuantity > widget.config.maxPositionSize;
    final exceedsMaxConcentration = checkPercent &&
        positionConcentration > widget.config.maxPortfolioConcentration;
    final exceedsTotalCapitalBudget =
        positionConcentration > widget.config.totalCapitalBudgetPercent;

    final isApproved = !exceedsMaxPositionSize &&
        !exceedsMaxConcentration &&
        !exceedsTotalCapitalBudget;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      child: ExpansionTile(
        key: const ValueKey('position-sizing-simulator-tile'),
        initiallyExpanded: _isExpanded,
        onExpansionChanged: (expanded) =>
            setState(() => _isExpanded = expanded),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.calculate_outlined,
              color: colorScheme.primary, size: 20),
        ),
        title: const Text(
          'Position Sizing Simulator',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Simulate ${mode.label} on $_selectedSymbol ($calculatedQuantity sh • ${currencyFormat.format(notionalOrderValue)})',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Controls Row: Symbol, Price, ATR (Responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 360;
              if (widget.config.isDynamicSizing && isCompact) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildSymbolDropdown()),
                        const SizedBox(width: 8),
                        Expanded(child: _buildPriceField()),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildAtrField()),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 10),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    colorScheme.outline.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_outlined,
                                    size: 16, color: colorScheme.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Stop: \$${(atr * widget.config.atrMultiplier).toStringAsFixed(2)} (${widget.config.atrMultiplier}x)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildSymbolDropdown(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _buildPriceField(),
                  ),
                  if (widget.config.isDynamicSizing) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: _buildAtrField(),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          // Output Metrics Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              children: [
                _buildMetricRow(
                  'Order Quantity',
                  '$calculatedQuantity shares',
                  isBold: true,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 6),
                _buildMetricRow(
                  'Notional Value',
                  currencyFormat.format(notionalOrderValue),
                ),
                const SizedBox(height: 6),
                _buildMetricRow(
                  'Position Concentration',
                  '${(positionConcentration * 100).toStringAsFixed(1)}% of equity',
                ),
                const SizedBox(height: 6),
                _buildMetricRow(
                  'Dollar Risk at Stop',
                  '${currencyFormat.format(dollarAtRisk)} (${riskPercentOfEquity.toStringAsFixed(1)}% equity)',
                  color: Colors.redAccent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Pre-Flight RiskGuard Assessment Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isApproved ? Colors.green : Colors.red)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (isApproved ? Colors.green : Colors.red)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isApproved
                      ? Icons.check_circle_outline
                      : Icons.error_outline_rounded,
                  color: isApproved ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isApproved
                            ? 'RiskGuard Pre-Flight: APPROVED'
                            : 'RiskGuard Pre-Flight: DECLINED',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isApproved ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (isApproved)
                        Text(
                          widget.config.isMaxSharesPositionLimit
                              ? 'Order of $calculatedQuantity shares conforms with Max Position Size (${widget.config.maxPositionSize} sh max).'
                              : 'Order of $calculatedQuantity shares (${(positionConcentration * 100).toStringAsFixed(1)}% equity) conforms with Max Concentration (${(widget.config.maxPortfolioConcentration * 100).toInt()}% max).',
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      else ...[
                        if (exceedsMaxPositionSize)
                          Text(
                            '• Exceeds Max Position Size ceiling ($calculatedQuantity sh > ${widget.config.maxPositionSize} sh max).',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.red),
                          ),
                        if (exceedsMaxConcentration)
                          Text(
                            '• Exceeds Max Concentration (${(positionConcentration * 100).toStringAsFixed(1)}% > ${(widget.config.maxPortfolioConcentration * 100).toInt()}% max).',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.red),
                          ),
                        if (exceedsTotalCapitalBudget)
                          Text(
                            '• Exceeds Total Capital Budget (${(positionConcentration * 100).toStringAsFixed(1)}% > ${(widget.config.totalCapitalBudgetPercent * 100).toInt()}% max).',
                            style: const TextStyle(
                                fontSize: 11, color: Colors.red),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

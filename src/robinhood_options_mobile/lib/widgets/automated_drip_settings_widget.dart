import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/automated_drip_config.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/automated_drip_service.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';

/// Settings and Audit Log page for Automated DRIP with Price Thresholds.
class AutomatedDripSettingsWidget extends StatefulWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final FirestoreService? firestoreService;
  final AutomatedDripService? service;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? brokerageService;

  const AutomatedDripSettingsWidget({
    super.key,
    this.user,
    this.userDocRef,
    this.firestoreService,
    this.service,
    this.brokerageUser,
    this.brokerageService,
  });

  @override
  State<AutomatedDripSettingsWidget> createState() =>
      _AutomatedDripSettingsWidgetState();
}

class _AutomatedDripSettingsWidgetState
    extends State<AutomatedDripSettingsWidget> {
  late AutomatedDripService _service;
  late AutomatedDripConfig _config;

  final _currencyFormat = NumberFormat.simpleCurrency();
  final _dateFormat = DateFormat.yMMMd().add_jm();

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AutomatedDripService();
    _config = widget.user?.automatedDripConfig ?? _service.config;
    _initService();
  }

  Future<void> _initService() async {
    if (widget.service == null) {
      final loaded = await _service.loadConfig(user: widget.user);
      if (mounted) {
        setState(() {
          _config = loaded;
        });
      }
    }
  }

  Future<void> _saveConfig(AutomatedDripConfig updated) async {
    setState(() {
      _config = updated;
    });

    await _service.updateConfig(
      updated,
      user: widget.user,
      firestoreService: widget.firestoreService,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Automated DRIP settings saved'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddOrEditRuleDialog([InstrumentDripRule? existingRule]) {
    final symbolController =
        TextEditingController(text: existingRule?.symbol ?? '');
    final targetPriceController = TextEditingController(
        text: existingRule?.targetPrice?.toStringAsFixed(2) ?? '');
    final discountController = TextEditingController(
        text: existingRule?.discountPercent?.toStringAsFixed(1) ?? '5.0');
    final notesController =
        TextEditingController(text: existingRule?.notes ?? '');

    DripThresholdMode mode =
        existingRule?.thresholdMode ?? _config.defaultMode;
    String orderType = existingRule?.orderType ?? _config.defaultOrderType;
    bool isEnabled = existingRule?.enabled ?? true;
    bool isEditing = existingRule != null;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEditing ? 'Edit DRIP Rule' : 'Add Custom DRIP Rule'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isEditing) ...[
                      TextField(
                        controller: symbolController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Ticker Symbol',
                          hintText: 'e.g. AAPL, SCHD, O',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<DripThresholdMode>(
                      isExpanded: true,
                      initialValue: mode,
                      decoration: const InputDecoration(
                        labelText: 'Threshold Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: DripThresholdMode.belowCostBasis,
                          child: Text(
                            'Below Average Cost Basis',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: DripThresholdMode.belowFixedPrice,
                          child: Text(
                            'Below Fixed Target Price (\$)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: DripThresholdMode.discountFromCostBasis,
                          child: Text(
                            'Discount % Below Cost Basis',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => mode = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (mode == DripThresholdMode.belowFixedPrice) ...[
                      TextField(
                        controller: targetPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Target Maximum Buy Price (\$)',
                          hintText: 'e.g. 150.00',
                          border: OutlineInputBorder(),
                          prefixText: '\$ ',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (mode == DripThresholdMode.discountFromCostBasis) ...[
                      TextField(
                        controller: discountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Required Discount %',
                          hintText: 'e.g. 5.0',
                          border: OutlineInputBorder(),
                          suffixText: '%',
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: orderType,
                      decoration: const InputDecoration(
                        labelText: 'Order Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'market',
                          child: Text(
                            'Market Order',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'limit',
                          child: Text(
                            'Limit Order',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => orderType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'e.g. Only accumulate on dips',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Rule Enabled'),
                      value: isEnabled,
                      onChanged: (val) {
                        setDialogState(() => isEnabled = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final sym = symbolController.text.trim().toUpperCase();
                    if (sym.isEmpty) return;

                    final double? targetPrice =
                        double.tryParse(targetPriceController.text.trim());
                    final double? discountPercent =
                        double.tryParse(discountController.text.trim());

                    final newRule = InstrumentDripRule(
                      symbol: sym,
                      enabled: isEnabled,
                      thresholdMode: mode,
                      targetPrice: targetPrice,
                      discountPercent: discountPercent ?? 5.0,
                      orderType: orderType,
                      notes: notesController.text.trim().isEmpty
                          ? null
                          : notesController.text.trim(),
                    );

                    await _service.setInstrumentRule(
                      newRule,
                      user: widget.user,
                      firestoreService: widget.firestoreService,
                    );

                    setState(() {
                      _config = _service.config;
                    });

                    if (mounted && dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: Text(isEditing ? 'Save' : 'Add Rule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _simulateEvaluation() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    // Simulate testing AAPL dividend payout
    final testInstrument = Instrument.forSymbol('AAPL');
    final testAccount = Account.fromJson({
      'url': 'https://api.robinhood.com/accounts/sim_account/',
      'account_number': 'SIM123',
      'type': 'margin',
      'portfolio_cash': '1000',
      'buying_power': '1000',
      'option_level': '3',
      'cash_held_for_options_collateral': '0',
      'unsettled_debit': '0',
      'settled_amount_borrowed': '0',
    });
    final testBrokerageUser = widget.brokerageUser ??
        BrokerageUser.fromJson({
          'source': 'Robinhood',
          'userName': 'sim_user',
        });

    final mockDividend = {
      'id': 'sim_div_${DateTime.now().millisecondsSinceEpoch}',
      'amount': '35.50',
    };

    final costBasis = 180.00;
    // Current price is $172.00 (below cost basis, so it triggers reinvestment!)
    final currentPrice = 172.00;

    final tx = await _service.executeReinvestment(
      brokerageUser: testBrokerageUser,
      account: testAccount,
      instrument: testInstrument,
      dividend: mockDividend,
      currentPrice: currentPrice,
      costBasis: costBasis,
      user: widget.user,
      firestoreService: widget.firestoreService,
    );

    setState(() {
      _config = _service.config;
    });

    if (mounted) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            tx.status == 'executed'
                ? 'Simulation: DRIP Reinvested \$35.50 for AAPL at \$172.00!'
                : 'Simulation: DRIP evaluated - ${tx.notes}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final executedCount =
        _config.transactions.where((t) => t.status == 'executed').length;
    final totalReinvested = _config.transactions
        .where((t) => t.status == 'executed')
        .fold<double>(0.0, (total, t) => total + t.dividendAmount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Automated DRIP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Simulate DRIP Execution',
            onPressed: _simulateEvaluation,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Symbol Rule',
            onPressed: () => _showAddOrEditRuleDialog(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          // 1. MASTER STATUS CARD
          Card(
            elevation: 0,
            color: _config.enabled
                ? colorScheme.primaryContainer.withAlpha(128)
                : colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: _config.enabled
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _config.enabled
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        foregroundColor: colorScheme.onPrimary,
                        child: const Icon(Icons.autorenew),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Automated Threshold DRIP',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _config.enabled
                                  ? 'Active • Reinvesting below threshold'
                                  : 'Disabled • Dividends remain as cash',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _config.enabled,
                        onChanged: (val) {
                          _saveConfig(_config.copyWith(enabled: val));
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: _buildMetricStat(
                          'Total Reinvested',
                          _currencyFormat.format(totalReinvested),
                          context,
                        ),
                      ),
                      Expanded(
                        child: _buildMetricStat(
                          'Executions',
                          '$executedCount',
                          context,
                        ),
                      ),
                      Expanded(
                        child: _buildMetricStat(
                          'Custom Rules',
                          '${_config.instrumentRules.length}',
                          context,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. GLOBAL DEFAULT THRESHOLD CARD
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Global Reinvestment Strategy',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Default Threshold Rule'),
                    subtitle: Text(
                      _config.defaultMode == DripThresholdMode.belowCostBasis
                          ? 'Reinvest when Price ≤ Cost Basis'
                          : _config.defaultMode ==
                                  DripThresholdMode.discountFromCostBasis
                              ? 'Reinvest at ${_config.defaultDiscountPercent.toStringAsFixed(1)}% discount below Cost Basis'
                              : 'Reinvest when Price ≤ Fixed Target',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showDefaultModeSelector();
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Default Order Type'),
                    subtitle: Text(
                        _config.defaultOrderType == 'market'
                            ? 'Market Order (Best execution)'
                            : 'Limit Order (Capped at threshold)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _saveConfig(_config.copyWith(
                        defaultOrderType: _config.defaultOrderType == 'market'
                            ? 'limit'
                            : 'market',
                      ));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. INSTRUMENT SPECIFIC RULES
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Custom Symbol Thresholds (${_config.instrumentRules.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Ticker'),
                onPressed: () => _showAddOrEditRuleDialog(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (_config.instrumentRules.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'No custom symbol rules configured.\nAll dividend-paying holdings will use the global default threshold.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            ..._config.instrumentRules.values.map((rule) {
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: rule.enabled
                        ? colorScheme.secondaryContainer
                        : colorScheme.surfaceContainerHighest,
                    foregroundColor: rule.enabled
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurfaceVariant,
                    child: Text(
                      rule.symbol.length > 3
                          ? rule.symbol.substring(0, 3)
                          : rule.symbol,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        rule.symbol,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      if (!rule.enabled)
                        Chip(
                          label: const Text('PAUSED',
                              style: TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          backgroundColor: colorScheme.errorContainer,
                          labelStyle: TextStyle(
                              color: colorScheme.onErrorContainer),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    rule.thresholdMode == DripThresholdMode.belowFixedPrice
                        ? 'Target: ≤ \$${rule.targetPrice?.toStringAsFixed(2) ?? "N/A"} (${rule.orderType.toUpperCase()})'
                        : rule.thresholdMode ==
                                DripThresholdMode.discountFromCostBasis
                            ? '${rule.discountPercent?.toStringAsFixed(1)}% below Cost Basis (${rule.orderType.toUpperCase()})'
                            : 'Cost Basis (${rule.orderType.toUpperCase()})',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _showAddOrEditRuleDialog(rule),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () async {
                          await _service.removeInstrumentRule(
                            rule.symbol,
                            user: widget.user,
                            firestoreService: widget.firestoreService,
                          );
                          setState(() {
                            _config = _service.config;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),

          // 4. TRANSACTION AUDIT LOG
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'DRIP Transaction History (${_config.transactions.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_config.transactions.isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await _service.clearHistory(
                      user: widget.user,
                      firestoreService: widget.firestoreService,
                    );
                    setState(() {
                      _config = _service.config;
                    });
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (_config.transactions.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text(
                    'No DRIP transactions logged yet.\nReinvestments and threshold checks will appear here.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            ..._config.transactions.take(15).map((tx) {
              final isExecuted = tx.status == 'executed';
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                tx.symbol,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildStatusBadge(tx.status, context),
                            ],
                          ),
                          Text(
                            _currencyFormat.format(tx.dividendAmount),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isExecuted ? Colors.green : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _dateFormat.format(tx.timestamp),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (isExecuted)
                            Text(
                              '+${tx.sharesPurchased.toStringAsFixed(3)} shs @ \$${tx.executionPrice.toStringAsFixed(2)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else
                            Text(
                              'Price: \$${tx.executionPrice.toStringAsFixed(2)} (Thresh: \$${tx.thresholdPrice?.toStringAsFixed(2) ?? 'N/A'})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          tx.notes!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showDefaultModeSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select Default Threshold Strategy',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                title: const Text('Below Average Cost Basis'),
                subtitle: const Text(
                    'Reinvest only when current market price is at or below your average cost basis.'),
                selected: _config.defaultMode == DripThresholdMode.belowCostBasis,
                onTap: () {
                  Navigator.pop(context);
                  _saveConfig(_config.copyWith(
                      defaultMode: DripThresholdMode.belowCostBasis));
                },
              ),
              ListTile(
                title: const Text('Discount from Cost Basis'),
                subtitle: const Text(
                    'Reinvest only when market price is at least 5% below your cost basis.'),
                selected: _config.defaultMode ==
                    DripThresholdMode.discountFromCostBasis,
                onTap: () {
                  Navigator.pop(context);
                  _saveConfig(_config.copyWith(
                      defaultMode: DripThresholdMode.discountFromCostBasis));
                },
              ),
              ListTile(
                title: const Text('Fixed Target Price'),
                subtitle: const Text(
                    'Reinvest only when market price is at or below a specified dollar target.'),
                selected:
                    _config.defaultMode == DripThresholdMode.belowFixedPrice,
                onTap: () {
                  Navigator.pop(context);
                  _saveConfig(_config.copyWith(
                      defaultMode: DripThresholdMode.belowFixedPrice));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricStat(String label, String value, BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status, BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'executed':
        bg = Colors.green.withAlpha(40);
        fg = Colors.green;
        label = 'EXECUTED';
        break;
      case 'threshold_unmet':
        bg = Colors.orange.withAlpha(40);
        fg = Colors.orange;
        label = 'HELD IN CASH';
        break;
      case 'skipped':
        bg = Colors.grey.withAlpha(40);
        fg = Colors.grey;
        label = 'SKIPPED';
        break;
      default:
        bg = Colors.red.withAlpha(40);
        fg = Colors.red;
        label = status.toUpperCase();
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../model/custom_alert.dart';
import '../model/quote.dart';
import '../services/custom_alert_service.dart';
import '../services/yahoo_service.dart';

class CustomAlertsWidget extends StatefulWidget {
  final String? initialSymbol;

  const CustomAlertsWidget({super.key, this.initialSymbol});

  @override
  State<CustomAlertsWidget> createState() => _CustomAlertsWidgetState();
}

class _CustomAlertsWidgetState extends State<CustomAlertsWidget> {
  final CustomAlertService _service = CustomAlertService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialSymbol != null
            ? '${widget.initialSymbol} Alerts'
            : 'Custom Alerts'),
      ),
      body: StreamBuilder<List<CustomAlert>>(
        stream: _service.getAlerts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final alerts = snapshot.data!;
          final filteredAlerts = widget.initialSymbol != null
              ? alerts.where((a) => a.symbol == widget.initialSymbol).toList()
              : alerts;

          if (filteredAlerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_off,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    widget.initialSymbol != null
                        ? 'No alerts for ${widget.initialSymbol}'
                        : 'No custom alerts',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAlertEditor(context, null),
                    icon: const Icon(Icons.add_alert),
                    label: const Text('Create Alert'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: filteredAlerts.length,
            itemBuilder: (context, index) {
              final alert = filteredAlerts[index];
              final currencyFormatter = NumberFormat.simpleCurrency();
              final numberFormatter = NumberFormat.decimalPattern();

              final isMultiRule = alert.rules.length > 1;
              String valueText;
              if (isMultiRule) {
                valueText =
                    '${alert.rules.length} rules (${alert.logic == AlertLogic.all ? "ALL" : "ANY"})';
              } else if (alert.type == AlertType.price) {
                valueText = currencyFormatter.format(alert.value);
              } else if (alert.type == AlertType.moving_average) {
                valueText =
                    'SMA(${alert.period}): ${currencyFormatter.format(alert.value)}';
              } else if (alert.type == AlertType.rsi) {
                valueText =
                    'RSI(${alert.period}): ${numberFormatter.format(alert.value)}';
              } else {
                valueText = numberFormatter.format(alert.value);
              }

              return Dismissible(
                key: Key(alert.id),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Confirm"),
                        content: const Text(
                            "Are you sure you want to delete this alert?"),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text("Delete",
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (_) {
                  _service.deleteAlert(alert.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alert deleted')),
                  );
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: _buildIcon(alert.type),
                  ),
                  title: RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        TextSpan(
                          text: '${alert.symbol} ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (!isMultiRule)
                          TextSpan(
                            text:
                                '${alert.condition.name.replaceAll('_', ' ').toUpperCase()} ',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.secondary),
                          ),
                        TextSpan(
                          text: valueText,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isMultiRule)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 2),
                          child: Text(
                            alert.rules
                                .map((r) =>
                                    '${r.type.name.toUpperCase()} ${r.condition.name.replaceAll('_', ' ')} ${r.type == AlertType.price ? currencyFormatter.format(r.value) : (r.type == AlertType.volatility || r.condition == AlertCondition.percent_change || r.condition == AlertCondition.spike || r.condition == AlertCondition.drop ? '${r.value}%' : r.value)}')
                                .join(' • '),
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Text(
                        alert.lastTriggered != null
                            ? 'Last triggered: ${DateFormat.yMMMd().add_jm().format(alert.lastTriggered!)}'
                            : 'Never triggered',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  trailing: Switch(
                    value: alert.active,
                    onChanged: (val) {
                      _service.updateAlert(CustomAlert(
                          id: alert.id,
                          userId: alert.userId,
                          symbol: alert.symbol,
                          type: alert.type,
                          condition: alert.condition,
                          value: alert.value,
                          period: alert.period,
                          logic: alert.logic,
                          rules: alert.rules,
                          active: val,
                          lastTriggered: alert.lastTriggered,
                          createdAt: alert.createdAt,
                          deviceToken: alert.deviceToken));
                    },
                  ),
                  onTap: () => _showAlertEditor(context, alert),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAlertEditor(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Icon _buildIcon(AlertType type) {
    switch (type) {
      case AlertType.price:
        return const Icon(Icons.attach_money);
      case AlertType.volume:
        return const Icon(Icons.bar_chart);
      case AlertType.volatility:
        return const Icon(Icons.show_chart);
      case AlertType.moving_average:
        return const Icon(Icons.trending_up);
      case AlertType.rsi:
        return const Icon(Icons.speed);
      default:
        return const Icon(Icons.notifications);
    }
  }

  void _showAlertEditor(BuildContext context, CustomAlert? alert) async {
    final result = await showDialog<CustomAlert>(
      context: context,
      builder: (context) => _AlertEditorDialog(
        alert: alert,
        initialSymbol: widget.initialSymbol,
        userId: _auth.currentUser?.uid,
      ),
    );

    if (result != null && mounted) {
      if (alert != null) {
        _service.updateAlert(result);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Alert updated')));
      } else {
        _service.createAlert(result);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Alert created')));
      }
    }
  }
}

class _AlertEditorDialog extends StatefulWidget {
  final CustomAlert? alert;
  final String? initialSymbol;
  final String? userId;

  const _AlertEditorDialog({
    this.alert,
    this.initialSymbol,
    this.userId,
  });

  @override
  State<_AlertEditorDialog> createState() => _AlertEditorDialogState();
}

class _RuleEditState {
  AlertType type;
  AlertCondition condition;
  late final TextEditingController valueController;
  late final TextEditingController periodController;

  _RuleEditState({
    required this.type,
    required this.condition,
    double value = 0.0,
    int period = 14,
    bool isNew = false,
  }) {
    valueController = TextEditingController(
      text: (value == 0.0 && isNew)
          ? ''
          : (value == value.roundToDouble() && value != 0
              ? value.toInt().toString()
              : (value == 0.0 ? '' : value.toString())),
    );
    periodController = TextEditingController(text: period.toString());
  }

  void dispose() {
    valueController.dispose();
    periodController.dispose();
  }

  double get value => double.tryParse(valueController.text) ?? 0.0;
  int get period => int.tryParse(periodController.text) ?? 14;

  SmartAlertRule toRule() {
    return SmartAlertRule(
      type: type,
      condition: condition,
      value: value,
      period: (type == AlertType.moving_average || type == AlertType.rsi)
          ? period
          : null,
    );
  }
}

class _AlertEditorDialogState extends State<_AlertEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _symbol;
  late AlertLogic _logic;
  late List<_RuleEditState> _rules;
  late TextEditingController _symbolController;

  final YahooService _yahooService = YahooService();
  Quote? _currentQuote;
  bool _isLoadingQuote = false;

  @override
  void initState() {
    super.initState();
    final alert = widget.alert;
    _symbol = alert?.symbol ?? widget.initialSymbol ?? '';
    _logic = alert?.logic ?? AlertLogic.all;
    _symbolController = TextEditingController(text: _symbol);

    if (alert != null && alert.rules.isNotEmpty) {
      _rules = alert.rules
          .map((r) => _RuleEditState(
                type: r.type,
                condition: r.condition,
                value: r.value,
                period: r.period ?? 14,
              ))
          .toList();
    } else if (alert != null) {
      _rules = [
        _RuleEditState(
          type: alert.type,
          condition: alert.condition,
          value: alert.value,
          period: alert.period ?? 14,
        ),
      ];
    } else {
      _rules = [
        _RuleEditState(
          type: AlertType.price,
          condition: AlertCondition.above,
          value: 0.0,
          period: 14,
          isNew: true,
        ),
      ];
    }

    if (_symbol.isNotEmpty) {
      _fetchQuote(_symbol);
    }
  }

  @override
  void dispose() {
    _symbolController.dispose();
    for (final rule in _rules) {
      rule.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchQuote(String symbol) async {
    if (symbol.isEmpty) return;
    setState(() => _isLoadingQuote = true);
    try {
      final quote = await _yahooService.getQuote(symbol);
      if (mounted) {
        setState(() {
          _currentQuote = quote;
        });
      }
    } catch (e) {
      debugPrint('Error fetching quote: $e');
    } finally {
      if (mounted) setState(() => _isLoadingQuote = false);
    }
  }

  void _addRule() {
    setState(() {
      _rules.add(_RuleEditState(
        type: AlertType.price,
        condition: AlertCondition.above,
        value: 0.0,
        period: 14,
        isNew: true,
      ));
    });
  }

  void _removeRule(int index) {
    if (_rules.length > 1) {
      setState(() {
        final removed = _rules.removeAt(index);
        removed.dispose();
      });
    }
  }

  void _useCurrentPrice(_RuleEditState rule) {
    if (_currentQuote?.lastTradePrice != null) {
      setState(() {
        rule.valueController.text = _currentQuote!.lastTradePrice!.toString();
      });
    }
  }

  List<AlertCondition> _getConditionsForType(AlertType type) {
    switch (type) {
      case AlertType.price:
        return [
          AlertCondition.above,
          AlertCondition.below,
          AlertCondition.percent_change,
        ];
      case AlertType.volume:
        return [
          AlertCondition.above,
          AlertCondition.below,
          AlertCondition.spike,
        ];
      case AlertType.volatility:
        return [
          AlertCondition.above,
          AlertCondition.spike,
        ];
      case AlertType.moving_average:
      case AlertType.rsi:
        return [
          AlertCondition.above,
          AlertCondition.below,
        ];
      default:
        return AlertCondition.values;
    }
  }

  InputDecoration _getValueDecoration(_RuleEditState rule) {
    String? suffixText;
    String? prefixText;
    if (rule.type == AlertType.price || rule.type == AlertType.moving_average) {
      prefixText = '\$';
    } else if (rule.type == AlertType.volatility ||
        rule.condition == AlertCondition.percent_change ||
        rule.condition == AlertCondition.spike ||
        rule.condition == AlertCondition.drop) {
      suffixText = '%';
    }
    return InputDecoration(
      labelText: 'Value',
      prefixText: prefixText,
      suffixText: suffixText,
    );
  }

  Widget _buildRuleCard(BuildContext context, int index, _RuleEditState rule) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rule ${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_rules.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Remove rule',
                  onPressed: () => _removeRule(index),
                ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<AlertType>(
            initialValue: rule.type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Type'),
            items: AlertType.values
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(
                        t.name.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  rule.type = val;
                  final validConditions = _getConditionsForType(rule.type);
                  if (!validConditions.contains(rule.condition)) {
                    rule.condition = validConditions.first;
                  }
                });
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<AlertCondition>(
            initialValue: rule.condition,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Condition'),
            items: _getConditionsForType(rule.type)
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c.name.replaceAll('_', ' ').toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => rule.condition = val);
            },
          ),
          if (rule.type == AlertType.moving_average ||
              rule.type == AlertType.rsi) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: rule.periodController,
              decoration: const InputDecoration(labelText: 'Period'),
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.isEmpty) return 'Required';
                final numVal = int.tryParse(val);
                if (numVal == null) return 'Invalid number';
                if (numVal <= 0) return 'Must be positive';
                return null;
              },
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: rule.valueController,
                  decoration: _getValueDecoration(rule),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Required';
                    final numVal = double.tryParse(val);
                    if (numVal == null) return 'Invalid number';
                    if (numVal < 0) return 'Must be non-negative';
                    return null;
                  },
                ),
              ),
              if (rule.type == AlertType.price &&
                  _currentQuote?.lastTradePrice != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _useCurrentPrice(rule),
                  child: const Text('Use Current'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.alert != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Alert' : 'Add Alert'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.initialSymbol == null)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _symbolController,
                          decoration:
                              const InputDecoration(labelText: 'Symbol'),
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (val) {
                            _symbol = val.toUpperCase();
                          },
                          validator: (val) =>
                              val == null || val.isEmpty ? 'Required' : null,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => _fetchQuote(_symbolController.text),
                        tooltip: 'Refresh Quote',
                      ),
                    ],
                  ),
                if (_isLoadingQuote)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: LinearProgressIndicator(),
                  ),
                if (_currentQuote != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Price:',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          _currentQuote?.lastTradePrice != null
                              ? NumberFormat.simpleCurrency()
                                  .format(_currentQuote!.lastTradePrice)
                              : '--',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (_rules.length > 1) ...[
                  DropdownButtonFormField<AlertLogic>(
                    initialValue: _logic,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Smart Trigger Logic',
                      helperText: 'How conditions should be combined',
                    ),
                    items: AlertLogic.values
                        .map((logic) => DropdownMenuItem(
                              value: logic,
                              child: Text(
                                logic == AlertLogic.all
                                    ? 'Trigger when ALL rules match (AND)'
                                    : 'Trigger when ANY rule matches (OR)',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _logic = val);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  _rules.length > 1 ? 'Rules' : 'Rule',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                for (int i = 0; i < _rules.length; i++) ...[
                  _buildRuleCard(context, i, _rules[i]),
                  const SizedBox(height: 12),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _addRule,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Rule'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final userId = widget.userId;
              // Ensure symbol is updated
              _symbol = _symbolController.text.toUpperCase();

              if (userId != null && _symbol.isNotEmpty && _rules.isNotEmpty) {
                // Get device token if new or missing
                String? token = widget.alert?.deviceToken;
                if (token == null) {
                  try {
                    token = await FirebaseMessaging.instance.getToken();
                  } catch (e) {
                    debugPrint('Error getting FCM token: $e');
                  }
                }

                final smartRules = _rules.map((r) => r.toRule()).toList();
                final primaryRule = smartRules.first;

                final newAlert = CustomAlert(
                  id: widget.alert?.id ?? '',
                  userId: userId,
                  symbol: _symbol,
                  type: primaryRule.type,
                  condition: primaryRule.condition,
                  value: primaryRule.value,
                  period: primaryRule.period,
                  logic: _logic,
                  rules: smartRules,
                  active: widget.alert?.active ?? true,
                  lastTriggered: widget.alert?.lastTriggered,
                  createdAt: widget.alert?.createdAt ?? DateTime.now(),
                  deviceToken: token,
                );
                if (context.mounted) Navigator.pop(context, newAlert);
              }
            }
          },
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

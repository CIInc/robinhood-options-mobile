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

              String valueText;
              if (alert.type == AlertType.price) {
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
                  subtitle: Text(
                    alert.lastTriggered != null
                        ? 'Last triggered: ${DateFormat.yMMMd().add_jm().format(alert.lastTriggered!)}'
                        : 'Never triggered',
                    style: Theme.of(context).textTheme.bodySmall,
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

class _AlertEditorDialogState extends State<_AlertEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _symbol;
  late AlertType _type;
  late AlertCondition _condition;
  late double _value;
  late int _period;
  late TextEditingController _symbolController;
  late TextEditingController _valueController;
  late TextEditingController _periodController;

  final YahooService _yahooService = YahooService();
  Quote? _currentQuote;
  bool _isLoadingQuote = false;

  @override
  void initState() {
    super.initState();
    final alert = widget.alert;
    _symbol = alert?.symbol ?? widget.initialSymbol ?? '';
    _type = alert?.type ?? AlertType.price;
    _condition = alert?.condition ?? AlertCondition.above;
    _value = alert?.value ?? 0.0;
    _period = alert?.period ?? 14;

    _symbolController = TextEditingController(text: _symbol);
    _valueController = TextEditingController(
        text: _value == 0.0 && widget.alert == null ? '' : _value.toString());
    _periodController = TextEditingController(text: _period.toString());

    if (_symbol.isNotEmpty) {
      _fetchQuote(_symbol);
    }
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _valueController.dispose();
    _periodController.dispose();
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

  void _useCurrentPrice() {
    if (_currentQuote?.lastTradePrice != null) {
      setState(() {
        _value = _currentQuote!.lastTradePrice!;
        _valueController.text = _value.toString();
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.alert != null;

    InputDecoration getValueDecoration() {
      String? suffixText;
      String? prefixText;
      if (_type == AlertType.price || _type == AlertType.moving_average) {
        prefixText = '\$';
      } else if (_type == AlertType.volatility ||
          _condition == AlertCondition.percent_change ||
          _condition == AlertCondition.spike ||
          _condition == AlertCondition.drop) {
        suffixText = '%';
      }
      return InputDecoration(
        labelText: 'Value',
        prefixText: prefixText,
        suffixText: suffixText,
      );
    }

    return AlertDialog(
      title: Text(isEditing ? 'Edit Alert' : 'Add Alert'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.initialSymbol == null)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _symbolController,
                        decoration: const InputDecoration(labelText: 'Symbol'),
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
              DropdownButtonFormField<AlertType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: AlertType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.name.toUpperCase()),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _type = val;
                      // Reset condition if not valid for new type
                      final validConditions = _getConditionsForType(_type);
                      if (!validConditions.contains(_condition)) {
                        _condition = validConditions.first;
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AlertCondition>(
                value: _condition,
                decoration: const InputDecoration(labelText: 'Condition'),
                items: _getConditionsForType(_type)
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child:
                              Text(c.name.replaceAll('_', ' ').toUpperCase()),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _condition = val);
                },
              ),
              if (_type == AlertType.moving_average ||
                  _type == AlertType.rsi) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _periodController,
                  decoration: const InputDecoration(labelText: 'Period'),
                  keyboardType: TextInputType.number,
                  onChanged: (val) => _period = int.tryParse(val) ?? 14,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Required';
                    final numVal = int.tryParse(val);
                    if (numVal == null) return 'Invalid number';
                    if (numVal <= 0) return 'Must be positive';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _valueController,
                      decoration: getValueDecoration(),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => _value = double.tryParse(val) ?? 0.0,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Required';
                        final numVal = double.tryParse(val);
                        if (numVal == null) return 'Invalid number';
                        if (numVal < 0) return 'Must be non-negative';
                        return null;
                      },
                    ),
                  ),
                  if (_type == AlertType.price &&
                      _currentQuote?.lastTradePrice != null)
                    TextButton(
                      onPressed: _useCurrentPrice,
                      child: const Text('Use Current'),
                    ),
                ],
              ),
            ],
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

              if (userId != null && _symbol.isNotEmpty) {
                // Get device token if new or missing
                String? token = widget.alert?.deviceToken;
                if (token == null) {
                  try {
                    token = await FirebaseMessaging.instance.getToken();
                  } catch (e) {
                    debugPrint('Error getting FCM token: $e');
                  }
                }

                final newAlert = CustomAlert(
                  id: widget.alert?.id ?? '',
                  userId: userId,
                  symbol: _symbol,
                  type: _type,
                  condition: _condition,
                  value: _value,
                  period: (_type == AlertType.moving_average ||
                          _type == AlertType.rsi)
                      ? _period
                      : null,
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

import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/custom_indicator_config.dart';
import 'package:uuid/uuid.dart';

class CustomIndicatorPage extends StatefulWidget {
  final CustomIndicatorConfig? indicator;

  const CustomIndicatorPage({super.key, this.indicator});

  @override
  State<CustomIndicatorPage> createState() => _CustomIndicatorPageState();
}

class _CustomIndicatorPageState extends State<CustomIndicatorPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late IndicatorType _type;
  late Map<String, dynamic> _parameters;
  late SignalCondition _condition;
  late TextEditingController _thresholdController;
  bool _compareToPrice = false;
  SignalType _signalType = SignalType.BUY;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.indicator?.name ?? '');
    _type = widget.indicator?.type ?? IndicatorType.SMA;
    _parameters = Map.from(widget.indicator?.parameters ?? {});
    _condition = widget.indicator?.condition ?? SignalCondition.GreaterThan;
    _thresholdController = TextEditingController(
        text: widget.indicator?.threshold?.toString() ?? '');
    _compareToPrice = widget.indicator?.compareToPrice ?? false;
    _signalType = widget.indicator?.signalType ?? SignalType.BUY;

    if (_parameters.isEmpty) {
      _setDefaultParameters();
    }
  }

  void _setDefaultParameters() {
    switch (_type) {
      case IndicatorType.SMA:
      case IndicatorType.EMA:
      case IndicatorType.RSI:
      case IndicatorType.ATR:
      case IndicatorType.WilliamsR:
      case IndicatorType.MFI:
      case IndicatorType.ROC:
      case IndicatorType.CCI:
        _parameters['period'] = 14;
        break;
      case IndicatorType.ADX:
        _parameters['period'] = 14;
        _parameters['component'] = 'adx';
        break;
      case IndicatorType.CMF:
        _parameters['period'] = 20;
        break;
      case IndicatorType.Bollinger:
      case IndicatorType.BBW:
        _parameters['period'] = 20;
        _parameters['stdDev'] = 2.0;
        _parameters['component'] = 'middle';
        break;
      case IndicatorType.MACD:
        _parameters['fastPeriod'] = 12;
        _parameters['slowPeriod'] = 26;
        _parameters['signalPeriod'] = 9;
        _parameters['component'] = 'histogram';
        break;
      case IndicatorType.Stochastic:
        _parameters['kPeriod'] = 14;
        _parameters['dPeriod'] = 3;
        _parameters['component'] = 'k';
        break;
      case IndicatorType.OBV:
      case IndicatorType.VWAP:
        break;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.indicator == null
            ? 'Add Custom Indicator'
            : 'Edit Custom Indicator'),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'General Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Indicator Name',
                          hintText: 'e.g. RSI Overbought',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.label),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'Required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.tune,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Configuration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<IndicatorType>(
                        initialValue: _type,
                        decoration: InputDecoration(
                          labelText: 'Indicator Type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.show_chart),
                        ),
                        items: IndicatorType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.toString().split('.').last),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _type = value;
                              _parameters.clear();
                              _setDefaultParameters();
                            });
                          }
                        },
                      ),
                      if (_parameters.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parameters',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildParametersFields(),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    Icons.compare_arrows,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Signal Logic',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<SignalType>(
                        initialValue: _signalType,
                        decoration: InputDecoration(
                          labelText: 'Signal Type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.traffic),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        items: SignalType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.toString().split('.').last),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _signalType = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<SignalCondition>(
                        initialValue: _condition,
                        decoration: InputDecoration(
                          labelText: 'Condition',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.rule),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                        ),
                        items: SignalCondition.values.map((condition) {
                          return DropdownMenuItem(
                            value: condition,
                            child: Text(condition.toString().split('.').last),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _condition = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      _compareToPrice
                          ? InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Threshold Value',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.attach_money),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                              ),
                              child: Text(
                                'Current Price',
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : TextFormField(
                              controller: _thresholdController,
                              decoration: InputDecoration(
                                labelText: 'Threshold Value',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.numbers),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) =>
                                  value?.isEmpty ?? true ? 'Required' : null,
                            ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Compare to Current Price'),
                        subtitle: const Text(
                            'Use current market price instead of a fixed value'),
                        value: _compareToPrice,
                        onChanged: (value) {
                          setState(() {
                            _compareToPrice = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParametersFields() {
    List<Widget> fields = [];
    _parameters.forEach((key, value) {
      if (key == 'component') {
        List<String> items = [];
        if (_type == IndicatorType.MACD) {
          items = ['histogram', 'macd', 'signal'];
        } else if (_type == IndicatorType.Bollinger ||
            _type == IndicatorType.BBW) {
          items = ['middle', 'upper', 'lower'];
        } else if (_type == IndicatorType.Stochastic) {
          items = ['k', 'd'];
        } else if (_type == IndicatorType.ADX) {
          items = ['adx', 'plusDI', 'minusDI'];
        } else {
          // Default fallbacks just in case
          items = ['default'];
        }

        fields.add(DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : items.first,
          decoration: InputDecoration(
            labelText: 'Component',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.layers),
            isDense: true,
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _parameters[key] = val;
              });
            }
          },
        ));
      } else {
        // Capitalize first letter of key for label
        final label = key.substring(0, 1).toUpperCase() + key.substring(1);

        fields.add(TextFormField(
          initialValue: value.toString(),
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.input),
            isDense: true,
          ),
          keyboardType: TextInputType.number,
          validator: (val) {
            if (val == null || val.isEmpty) return 'Required';
            if (num.tryParse(val) == null) return 'Invalid number';
            return null;
          },
          onChanged: (val) {
            if (val.isNotEmpty) {
              final numVal = num.tryParse(val);
              if (numVal != null) {
                _parameters[key] = numVal;
              }
            }
          },
        ));
      }
      fields.add(const SizedBox(height: 12));
    });
    // Remove last SizedBox
    if (fields.isNotEmpty) fields.removeLast();
    return Column(children: fields);
  }

  void _save() {
    if (_formKey.currentState?.validate() ?? false) {
      // Validate threshold if not comparing to price
      if (!_compareToPrice && _thresholdController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a threshold value')),
        );
        return;
      }

      final indicator = CustomIndicatorConfig(
        id: widget.indicator?.id ?? const Uuid().v4(),
        name: _nameController.text,
        type: _type,
        parameters: _parameters,
        condition: _condition,
        threshold:
            _compareToPrice ? null : double.tryParse(_thresholdController.text),
        compareToPrice: _compareToPrice,
        signalType: _signalType,
      );
      Navigator.pop(context, indicator);
    }
  }
}

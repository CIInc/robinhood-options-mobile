import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/forex_holding.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/order_template.dart';
import 'package:robinhood_options_mobile/model/order_template_store.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/widgets/animated_price_text.dart';
import 'package:robinhood_options_mobile/widgets/slide_to_confirm_widget.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';

class TradeForexWidget extends StatefulWidget {
  const TradeForexWidget(this.brokerageUser, this.service,
      {super.key,
      required this.analytics,
      required this.observer,
      required this.holding,
      this.positionType = "Buy"});

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final ForexHolding holding;
  final String? positionType;

  @override
  State<TradeForexWidget> createState() => _TradeForexWidgetState();
}

class _TradeForexWidgetState extends State<TradeForexWidget> {
  final _formKey = GlobalKey<FormState>();
  String? positionType;
  String orderType = "Market"; // Market, Limit
  String timeInForce = "gtc";

  var quantityCtl = TextEditingController(text: '1');
  var priceCtl = TextEditingController();
  var stopPriceCtl = TextEditingController();

  bool placingOrder = false;
  bool _isPreviewing = false;
  double estimatedTotal = 0.0;
  String? _riskGuardWarning;

  @override
  void initState() {
    super.initState();
    positionType = widget.positionType;
    widget.analytics.logScreenView(screenName: 'Trade Forex');

    double price = widget.holding.quoteObj?.markPrice ?? 0.0;
    priceCtl.text = price.toString();
    stopPriceCtl.text = price.toString();

    quantityCtl.addListener(_updateEstimates);
    priceCtl.addListener(_updateEstimates);
    stopPriceCtl.addListener(_updateEstimates);
    _updateEstimates();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        context.read<OrderTemplateStore>().loadTemplates(user.uid);
      }
    });
  }

  @override
  void dispose() {
    quantityCtl.dispose();
    priceCtl.dispose();
    stopPriceCtl.dispose();
    super.dispose();
  }

  void _updateEstimates() {
    if (!mounted) return;
    setState(() {
      double qty = double.tryParse(quantityCtl.text) ?? 0;
      double price = 0;
      if (orderType == 'Limit') {
        price = double.tryParse(priceCtl.text) ?? 0;
      } else {
        // Market
        price = widget.holding.quoteObj?.markPrice ?? 0;
      }
      estimatedTotal = qty * price;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quote = widget.holding.quoteObj;
    final currentPrice = quote?.markPrice ?? 0.0;

    return Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.holding.currencyCode} Crypto'),
              AnimatedPriceText(
                  price: currentPrice,
                  format: formatCurrency,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: Colors.white70)),
            ],
          ),
          actions: [
            if (!_isPreviewing)
              IconButton(
                icon: const Icon(Icons.save_as),
                onPressed: _showTemplatesDialog,
                tooltip: 'Order Templates',
              )
          ],
        ),
        body: _isPreviewing ? _buildPreview(context) : _buildForm(context));
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Balance Info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Consumer<AccountStore>(
                  builder: (context, accountStore, child) {
                    final buyingPower = accountStore.items.isNotEmpty
                        ? accountStore.items.first.buyingPower
                        : null;
                    return Text(
                      buyingPower != null
                          ? "Buying Power: ${formatCurrency.format(buyingPower)}"
                          : "",
                      style: theme.textTheme.bodySmall,
                    );
                  },
                ),
                Text(
                  "Available: ${formatNumber.format(widget.holding.quantity ?? 0)} ${widget.holding.currencyCode}",
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Order Side (Buy/Sell)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: "Buy",
                  label: Text("Buy"),
                  icon: Icon(Icons.add),
                ),
                ButtonSegment(
                  value: "Sell",
                  label: Text("Sell"),
                  icon: Icon(Icons.remove),
                ),
              ],
              selected: {positionType ?? "Buy"},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  positionType = newSelection.first;
                });
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return positionType == "Buy"
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2);
                    }
                    return null;
                  },
                ),
                foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (Set<WidgetState> states) {
                    if (states.contains(WidgetState.selected)) {
                      return positionType == "Buy" ? Colors.green : Colors.red;
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Order Type
            DropdownButtonFormField<String>(
              initialValue: orderType,
              decoration: const InputDecoration(
                labelText: "Order Type",
                border: OutlineInputBorder(),
                filled: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onChanged: (String? newValue) {
                setState(() {
                  orderType = newValue!;
                  _updateEstimates();
                });
              },
              items: <String>[
                'Market',
                'Limit',
              ].map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Units
            TextFormField(
              controller: quantityCtl,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter quantity';
                }
                final qty = double.tryParse(value);
                if (qty == null || qty <= 0) {
                  return 'Invalid quantity';
                }
                if (positionType == 'Sell') {
                  if (qty > (widget.holding.quantity ?? 0)) {
                    return 'Not enough units to sell';
                  }
                } else {
                  // Check buying power
                  final accountStore =
                      Provider.of<AccountStore>(context, listen: false);
                  if (accountStore.items.isNotEmpty) {
                    final buyingPower = accountStore.items.first.buyingPower;
                    if (buyingPower != null && estimatedTotal > buyingPower) {
                      return 'Not enough buying power';
                    }
                  }
                }
                return null;
              },
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,8}'))
              ],
              decoration: const InputDecoration(
                labelText: "Units",
                border: OutlineInputBorder(),
                filled: true,
                suffixText: "units",
              ),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),

            // Limit Price (Conditional)
            if (orderType == 'Limit') ...[
              TextFormField(
                controller: priceCtl,
                validator: (value) {
                  if (orderType == 'Limit') {
                    if (value == null || value.isEmpty) {
                      return 'Please enter limit price';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return 'Invalid price';
                    }
                  }
                  return null;
                },
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                ],
                decoration: const InputDecoration(
                  labelText: "Limit Price",
                  border: OutlineInputBorder(),
                  filled: true,
                  prefixText: "\$",
                ),
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
            ],

            // Time in Force
            DropdownButtonFormField<String>(
              initialValue: timeInForce,
              decoration: const InputDecoration(
                labelText: "Time in Force",
                border: OutlineInputBorder(),
                filled: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onChanged: (String? newValue) {
                setState(() {
                  timeInForce = newValue!;
                });
              },
              items: <String>['gtc', 'gfd', 'ioc', 'opg']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value.toUpperCase()),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Summary Section
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Estimated Total",
                            style: theme.textTheme.bodyLarge),
                        Text(
                          formatCurrency.format(estimatedTotal),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Consumer<AccountStore>(
                      builder: (context, accountStore, child) {
                        final buyingPower = accountStore.items.isNotEmpty
                            ? accountStore.items[0].buyingPower
                            : 0.0;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Buying Power",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant)),
                            Text(formatCurrency.format(buyingPower),
                                style: theme.textTheme.bodyMedium),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Button
            SizedBox(
              height: 50,
              child: FilledButton.icon(
                label: const Text(
                  "Preview Order",
                  style: TextStyle(fontSize: 18),
                ),
                icon: placingOrder
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ))
                    : const Icon(Icons.visibility),
                onPressed: placingOrder || estimatedTotal <= 0
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          _runRiskGuard();
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            "Review Order",
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          if (_riskGuardWarning != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "RiskGuard Warning: $_riskGuardWarning",
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "RiskGuard Check Passed",
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Text(
                    "$positionType ${quantityCtl.text} units",
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.holding.currencyCode,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  const SizedBox(height: 24),
                  _buildPreviewRow("Order Type", orderType),
                  if (orderType == 'Limit')
                    _buildPreviewRow("Limit Price",
                        formatCurrency.format(double.parse(priceCtl.text))),
                  _buildPreviewRow("Time in Force", timeInForce.toUpperCase()),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Estimated Total", style: theme.textTheme.bodyLarge),
                      Text(
                        formatCurrency.format(estimatedTotal),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Consumer<AccountStore>(
                    builder: (context, accountStore, child) {
                      final buyingPower = accountStore.items.isNotEmpty
                          ? accountStore.items[0].buyingPower
                          : 0.0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Buying Power",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                          Text(formatCurrency.format(buyingPower),
                              style: theme.textTheme.bodyMedium),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          SlideToConfirm(
            onConfirmed: () {
              _placeOrder();
            },
            text: "Slide to $positionType",
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            sliderColor: positionType == "Buy" ? Colors.green : Colors.red,
            iconColor: Colors.white,
            textColor: theme.colorScheme.onSurface,
          ),
          const SizedBox(height: 16),
          TextButton(
            child: const Text("Edit Order"),
            onPressed: () {
              setState(() {
                _isPreviewing = false;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewRow(String label, String value, {bool isBold = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value,
              style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  Future<void> _runRiskGuard() async {
    setState(() {
      placingOrder = true;
    });

    try {
      double? price;
      if (orderType == 'Limit') {
        price = double.tryParse(priceCtl.text);
      } else {
        price = widget.holding.quoteObj?.markPrice;
      }

      var accountStore = Provider.of<AccountStore>(context, listen: false);
      var agenticProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      final portfolioState = <String, dynamic>{};
      if (accountStore.items.isNotEmpty) {
        portfolioState['cash'] = accountStore.items[0].portfolioCash;
        if (widget.holding.quantity != null && widget.holding.quantity! > 0) {
          portfolioState[widget.holding.currencyCode] = {
            'quantity': widget.holding.quantity,
            'price': widget.holding.averageCost
          };
        }
      }

      final riskResult =
          await FirebaseFunctions.instance.httpsCallable('riskguardTask').call({
        'proposal': {
          'symbol': widget.holding.currencyCode,
          'quantity': double.tryParse(quantityCtl.text) ?? 0,
          'price': price ?? 0,
          'action': positionType == 'Buy' ? 'BUY' : 'SELL',
          'orderType': orderType,
        },
        'portfolioState': portfolioState,
        'config': agenticProvider.config,
      });

      if (riskResult.data['approved'] == false) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('RiskGuard Warning'),
            content: Text(
                riskResult.data['reason'] ?? 'Trade rejected by RiskGuard.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Proceed Anyway'),
              ),
            ],
          ),
        );

        if (proceed == true) {
          setState(() {
            _isPreviewing = true;
            _riskGuardWarning = riskResult.data['reason'];
          });
        }
      } else {
        setState(() {
          _isPreviewing = true;
          _riskGuardWarning = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("RiskGuard Error: $e"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          placingOrder = false;
        });
      }
    }
  }

  Future<void> _placeOrder() async {
    setState(() {
      placingOrder = true;
    });

    if (_riskGuardWarning != null) {
      await widget.analytics.logEvent(
        name: 'risk_guard_override',
        parameters: {
          'symbol': widget.holding.currencyCode,
          'reason': _riskGuardWarning!,
          'order_type': orderType,
        },
      );
    }

    try {
      String type = 'market';
      double? price;

      if (orderType == 'Limit') {
        type = 'limit';
        price = double.parse(priceCtl.text);
      } else {
        // Market
        price = null;
      }

      var orderJson = await widget.service.placeForexOrder(
        widget.brokerageUser,
        widget.holding.quoteObj!.id, // pairId
        positionType == "Buy" ? "buy" : "sell",
        price,
        double.parse(quantityCtl.text),
        type: type,
        timeInForce: timeInForce,
      );

      debugPrint(orderJson.body);

      if (!mounted) return;

      if (orderJson.statusCode != 200 && orderJson.statusCode != 201) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: ${jsonEncode(orderJson.body)}"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
      } else {
        // var newOrder = InstrumentOrder.fromJson(jsonDecode(orderJson.body));
        // Crypto orders might have different structure.
        // For now just show success.

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Order placed successfully!"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: $e"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) {
        setState(() {
          placingOrder = false;
        });
      }
    }
  }

  void _showTemplatesDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<OrderTemplateStore>(
          builder: (context, store, child) {
            return Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Save current as template'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSaveTemplateDialog();
                  },
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: store.templates.length,
                    itemBuilder: (context, index) {
                      final template = store.templates[index];
                      return ListTile(
                        title: Text(template.name),
                        subtitle: Text(
                            '${template.symbol != null ? "${template.symbol} " : ""}${template.positionType} ${template.orderType} ${template.quantity != null ? "${template.quantity} units" : ""}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            store.deleteTemplate(template.id);
                          },
                        ),
                        onTap: () {
                          _applyTemplate(template);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSaveTemplateDialog() {
    final nameCtl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save Template'),
          content: TextField(
            controller: nameCtl,
            decoration: const InputDecoration(labelText: 'Template Name'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (nameCtl.text.isNotEmpty) {
                  _saveTemplate(nameCtl.text);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _saveTemplate(String name) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final store = context.read<OrderTemplateStore>();
    final existing = store.getTemplateByName(name);

    if (existing != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Overwrite Template?'),
          content: Text(
              'A template named "$name" already exists. Do you want to overwrite it?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _performSave(name, existing.id);
              },
              child: const Text('Overwrite'),
            ),
          ],
        ),
      );
    } else {
      _performSave(name, DateTime.now().millisecondsSinceEpoch.toString());
    }
  }

  void _performSave(String name, String id) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final template = OrderTemplate(
      id: id,
      userId: user.uid,
      name: name,
      symbol: widget.holding.currencyCode,
      positionType: positionType ?? 'Buy',
      orderType: orderType,
      timeInForce: timeInForce,
      quantity: double.tryParse(quantityCtl.text),
      price: double.tryParse(priceCtl.text),
      stopPrice: double.tryParse(stopPriceCtl.text),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    context.read<OrderTemplateStore>().addTemplate(template);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Template saved')));
  }

  void _applyTemplate(OrderTemplate template) {
    setState(() {
      positionType = template.positionType;
      orderType = template.orderType;
      timeInForce = template.timeInForce;

      if (template.quantity != null) {
        quantityCtl.text = template.quantity.toString();
      }
      if (template.price != null) priceCtl.text = template.price.toString();
      if (template.stopPrice != null) {
        stopPriceCtl.text = template.stopPrice.toString();
      }

      _updateEstimates();
    });
  }
}

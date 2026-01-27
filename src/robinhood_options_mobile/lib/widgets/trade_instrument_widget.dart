import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_order.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/order_template.dart';
import 'package:robinhood_options_mobile/model/order_template_store.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/widgets/slide_to_confirm_widget.dart';

class TradeInstrumentWidget extends StatefulWidget {
  const TradeInstrumentWidget(this.brokerageUser, this.service,
      //this.account,
      {super.key,
      required this.analytics,
      required this.observer,
      this.stockPosition,
      this.instrument,
      this.positionType = "Buy"});

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  //final Account account;
  final InstrumentPosition? stockPosition;
  final Instrument? instrument;
  final String? positionType;

  @override
  State<TradeInstrumentWidget> createState() => _TradeInstrumentWidgetState();
}

class _TradeInstrumentWidgetState extends State<TradeInstrumentWidget> {
  String? positionType;
  String orderType = "Market"; // Market, Limit, Stop, Stop Limit, Trailing Stop
  String timeInForce = "gtc";
  String trailingType = "Percentage"; // Percentage, Amount

  var quantityCtl = TextEditingController(text: '1');
  var priceCtl = TextEditingController();
  var stopPriceCtl = TextEditingController();
  var trailingAmountCtl = TextEditingController();

  bool placingOrder = false;
  bool _isPreviewing = false;
  double estimatedTotal = 0.0;
  String? _riskGuardWarning;

  @override
  void initState() {
    super.initState();
    positionType = widget.positionType;
    widget.analytics.logScreenView(screenName: 'Trade Instrument');

    double price = widget.instrument?.quoteObj?.lastExtendedHoursTradePrice ??
        widget.instrument?.quoteObj?.lastTradePrice ??
        0.0;
    priceCtl.text = price.toString();
    stopPriceCtl.text = price.toString();
    trailingAmountCtl.text = "5"; // Default 5%

    quantityCtl.addListener(_updateEstimates);
    priceCtl.addListener(_updateEstimates);
    stopPriceCtl.addListener(_updateEstimates);
    trailingAmountCtl.addListener(_updateEstimates);
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
    trailingAmountCtl.dispose();
    super.dispose();
  }

  void _updateEstimates() {
    if (!mounted) return;
    setState(() {
      double qty = double.tryParse(quantityCtl.text) ?? 0;
      double price = 0;
      if (orderType == 'Limit') {
        price = double.tryParse(priceCtl.text) ?? 0;
      } else if (orderType == 'Stop') {
        // For stop orders, we estimate based on the stop price as a proxy for execution
        price = double.tryParse(stopPriceCtl.text) ?? 0;
      } else if (orderType == 'Stop Limit') {
        price = double.tryParse(priceCtl.text) ?? 0;
      } else if (orderType == 'Trailing Stop') {
        // Estimate based on current price
        price = widget.instrument?.quoteObj?.lastTradePrice ?? 0;
      } else {
        // Market
        price = widget.instrument?.quoteObj?.lastTradePrice ?? 0;
      }
      estimatedTotal = qty * price;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quote = widget.instrument?.quoteObj;
    final currentPrice = quote?.lastTradePrice ?? 0.0;

    return Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.instrument!.symbol} Stock'),
              Text(formatCurrency.format(currentPrice),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              'Stop',
              'Stop Limit',
              'Trailing Stop'
            ].map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Shares
          TextFormField(
            controller: quantityCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: "Shares",
              border: const OutlineInputBorder(),
              filled: true,
              suffixText: "shares",
              suffixIcon: IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: "Calculate Dynamic Size",
                onPressed: _calculateDynamicSize,
              ),
            ),
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),

          // Limit Price (Conditional)
          if (orderType == 'Limit' || orderType == 'Stop Limit') ...[
            TextFormField(
              controller: priceCtl,
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

          // Stop Price (Conditional)
          if (orderType == 'Stop' || orderType == 'Stop Limit') ...[
            TextFormField(
              controller: stopPriceCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              decoration: const InputDecoration(
                labelText: "Stop Price",
                border: OutlineInputBorder(),
                filled: true,
                prefixText: "\$",
              ),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
          ],

          // Trailing Stop Fields
          if (orderType == 'Trailing Stop') ...[
            DropdownButtonFormField<String>(
              initialValue: trailingType,
              decoration: const InputDecoration(
                labelText: "Trail Type",
                border: OutlineInputBorder(),
                filled: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              onChanged: (String? newValue) {
                setState(() {
                  trailingType = newValue!;
                });
              },
              items: <String>['Percentage', 'Amount']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: trailingAmountCtl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              decoration: InputDecoration(
                labelText: trailingType == 'Percentage'
                    ? "Trail Percent"
                    : "Trail Amount",
                border: const OutlineInputBorder(),
                filled: true,
                prefixText: trailingType == 'Amount' ? "\$" : null,
                suffixText: trailingType == 'Percentage' ? "%" : null,
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Estimated Total", style: theme.textTheme.bodyLarge),
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
                      _runRiskGuard();
                    },
            ),
          ),
        ],
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
                    "$positionType ${quantityCtl.text} shares",
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.instrument!.symbol,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  const SizedBox(height: 24),
                  _buildPreviewRow("Order Type", orderType),
                  if (orderType == 'Limit' || orderType == 'Stop Limit')
                    _buildPreviewRow("Limit Price",
                        formatCurrency.format(double.parse(priceCtl.text))),
                  if (orderType == 'Stop' || orderType == 'Stop Limit')
                    _buildPreviewRow("Stop Price",
                        formatCurrency.format(double.parse(stopPriceCtl.text))),
                  if (orderType == 'Trailing Stop') ...[
                    _buildPreviewRow("Trail Type", trailingType),
                    _buildPreviewRow(
                        trailingType == 'Percentage'
                            ? "Trail Percent"
                            : "Trail Amount",
                        trailingType == 'Percentage'
                            ? "${trailingAmountCtl.text}%"
                            : formatCurrency
                                .format(double.parse(trailingAmountCtl.text))),
                  ],
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
      var accountStore = Provider.of<AccountStore>(context, listen: false);
      var agenticProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);

      final portfolioState = <String, dynamic>{};
      if (accountStore.items.isNotEmpty) {
        portfolioState['buyingPower'] = accountStore.items[0].buyingPower ??
            accountStore.items[0].portfolioCash;
        portfolioState['cashAvailable'] = accountStore.items[0].portfolioCash;
        if (widget.stockPosition != null) {
          portfolioState[widget.instrument!.symbol] = {
            'quantity': widget.stockPosition!.quantity,
            'price': widget.stockPosition!.averageBuyPrice
          };
        }
      }

      double qty = double.tryParse(quantityCtl.text) ?? 0;
      double price = 0;
      if (orderType == 'Limit') {
        price = double.tryParse(priceCtl.text) ?? 0;
      } else if (orderType == 'Stop') {
        price = double.tryParse(stopPriceCtl.text) ?? 0;
      } else if (orderType == 'Stop Limit') {
        price = double.tryParse(priceCtl.text) ?? 0;
      } else {
        price = widget.instrument?.quoteObj?.lastTradePrice ?? 0;
      }

      final proposal = {
        'symbol': widget.instrument?.symbol,
        'quantity': qty,
        'price': price,
        'action': positionType?.toUpperCase() ?? 'BUY',
        'orderType': orderType,
      };

      final result =
          await FirebaseFunctions.instance.httpsCallable('riskguardTask').call({
        'proposal': proposal,
        'portfolioState': portfolioState,
        'config': agenticProvider.config,
      });

      final data = result.data;
      if (data['approved'] == true) {
        setState(() {
          _isPreviewing = true;
          _riskGuardWarning = null;
        });
      } else {
        if (mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('RiskGuard Warning'),
              content: Text(data['reason'] ?? 'Trade rejected by RiskGuard.'),
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
              _riskGuardWarning = data['reason'];
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('RiskGuard check failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          placingOrder = false;
        });
      }
    }
  }

  Future<void> _calculateDynamicSize() async {
    setState(() {
      placingOrder = true;
    });

    try {
      var accountStore = Provider.of<AccountStore>(context, listen: false);
      var agenticProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      final portfolioState = <String, dynamic>{};
      if (accountStore.items.isNotEmpty) {
        portfolioState['cash'] =
            accountStore.items[0].portfolioCash; // .buyingPower;
        if (widget.stockPosition != null) {
          portfolioState[widget.instrument!.symbol] = {
            'quantity': widget.stockPosition!.quantity,
            'price': widget.stockPosition!.averageBuyPrice
          };
        }
      }

      final result = await FirebaseFunctions.instance
          .httpsCallable('calculatePositionSize')
          .call({
        'symbol': widget.instrument?.symbol,
        'portfolioState': portfolioState,
        'config': agenticProvider.config,
      });

      final data = result.data;
      if (data['status'] == 'success') {
        final qty = data['quantity'];
        final details = data['details'];

        if (qty < 0) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "Trade Disallowed: Calculated size is negative ($qty). ${details['reason'] ?? ''}"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ));
        } else {
          setState(() {
            quantityCtl.text = qty.toString();
          });

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                "Dynamic Size: $qty (ATR: ${details['atr'].toStringAsFixed(2)})"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ));
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error: ${data['message']}"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
      }
    } catch (e) {
      debugPrint('Dynamic size calculation failed: $e');
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

  Future<void> _placeOrder() async {
    setState(() {
      placingOrder = true;
    });
    var accountStore = Provider.of<AccountStore>(context, listen: false);

    if (_riskGuardWarning != null) {
      await widget.analytics.logEvent(
        name: 'risk_guard_override',
        parameters: {
          'symbol': widget.instrument!.symbol,
          'reason': _riskGuardWarning!,
          'order_type': orderType,
        },
      );
    }

    try {
      String type = 'market';
      String trigger = 'immediate';
      double? price;
      double? stopPrice;
      Map<String, dynamic>? trailingPeg;

      if (orderType == 'Limit') {
        type = 'limit';
        price = double.parse(priceCtl.text);
      } else if (orderType == 'Stop') {
        type = 'market';
        trigger = 'stop';
        stopPrice = double.parse(stopPriceCtl.text);
        price = null;
      } else if (orderType == 'Stop Limit') {
        type = 'limit';
        trigger = 'stop';
        stopPrice = double.parse(stopPriceCtl.text);
        price = double.parse(priceCtl.text);
      } else if (orderType == 'Trailing Stop') {
        type = 'market';
        trigger = 'stop';
        trailingPeg = {
          'type': trailingType.toLowerCase(),
          'value': double.parse(trailingAmountCtl.text)
        };
        price = null;
      } else {
        // Market
        price = null;
      }

      var orderJson = await widget.service.placeInstrumentOrder(
        widget.brokerageUser,
        accountStore.items[0],
        widget.instrument!,
        widget.instrument!.symbol,
        positionType == "Buy" ? "buy" : "sell",
        price,
        int.parse(quantityCtl.text),
        type: type,
        trigger: trigger,
        stopPrice: stopPrice,
        timeInForce: timeInForce,
        trailingPeg: trailingPeg,
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
        var newOrder = InstrumentOrder.fromJson(jsonDecode(orderJson.body));

        if (newOrder.state == "confirmed" ||
            newOrder.state == "queued" ||
            newOrder.state == "unconfirmed") {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Order placed successfully!"),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Order state: ${newOrder.state}"),
            behavior: SnackBarBehavior.floating,
          ));
        }
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
                            '${template.positionType} ${template.orderType} ${template.quantity != null ? "${template.quantity} shares" : ""}'),
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
      symbol: widget.instrument?.symbol,
      positionType: positionType ?? 'Buy',
      orderType: orderType,
      timeInForce: timeInForce,
      trailingType: trailingType,
      quantity: double.tryParse(quantityCtl.text),
      price: double.tryParse(priceCtl.text),
      stopPrice: double.tryParse(stopPriceCtl.text),
      trailingAmount: double.tryParse(trailingAmountCtl.text),
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
      if (template.trailingType != null) trailingType = template.trailingType!;

      if (template.quantity != null) {
        quantityCtl.text = template.quantity.toString();
      }
      if (template.price != null) priceCtl.text = template.price.toString();
      if (template.stopPrice != null) {
        stopPriceCtl.text = template.stopPrice.toString();
      }
      if (template.trailingAmount != null) {
        trailingAmountCtl.text = template.trailingAmount.toString();
      }

      _updateEstimates();
    });
  }
}

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/constants.dart';

import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_order.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/slide_to_confirm_widget.dart';

class TradeOptionWidget extends StatefulWidget {
  const TradeOptionWidget(this.user, this.service,
      //this.account,
      {super.key,
      required this.analytics,
      required this.observer,
      this.optionPosition,
      this.optionInstrument,
      this.positionType = "Buy"});

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser user;
  final IBrokerageService service;
  //final Account account;
  final OptionAggregatePosition? optionPosition;
  final OptionInstrument? optionInstrument;
  final String? positionType;

  @override
  State<TradeOptionWidget> createState() => _TradeOptionWidgetState();
}

class _TradeOptionWidgetState extends State<TradeOptionWidget> {
  String? positionType;
  String orderType = "Limit"; // Market, Limit, Stop, Stop Limit, Trailing Stop
  String timeInForce = "gtc";
  String trailingType = "Percentage"; // Percentage, Amount

  var quantityCtl = TextEditingController(text: '1');
  var priceCtl = TextEditingController();
  var stopPriceCtl = TextEditingController();
  var trailingAmountCtl = TextEditingController();

  bool placingOrder = false;
  double estimatedTotal = 0.0;
  bool _isPreviewing = false;

  @override
  void initState() {
    super.initState();
    positionType = widget.positionType;
    widget.analytics.logScreenView(screenName: 'Trade Option');

    double price = widget.optionInstrument?.optionMarketData?.markPrice ?? 0.0;
    priceCtl.text = price.toString();
    stopPriceCtl.text = price.toString();
    trailingAmountCtl.text = "5"; // Default 5%

    quantityCtl.addListener(_updateEstimates);
    priceCtl.addListener(_updateEstimates);
    stopPriceCtl.addListener(_updateEstimates);
    trailingAmountCtl.addListener(_updateEstimates);
    _updateEstimates();
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
        price = double.tryParse(stopPriceCtl.text) ?? 0;
      } else if (orderType == 'Stop Limit') {
        price = double.tryParse(priceCtl.text) ?? 0;
      } else if (orderType == 'Trailing Stop') {
        price = widget.optionInstrument?.optionMarketData?.markPrice ?? 0;
      } else {
        // Market
        price = widget.optionInstrument?.optionMarketData?.markPrice ?? 0;
      }
      estimatedTotal = qty * price * 100; // Options multiplier
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final option = widget.optionInstrument!;
    final currentPrice = option.optionMarketData?.markPrice ?? 0.0;

    return Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${option.chainSymbol} \$${option.strikePrice} ${option.type}'),
              Text(
                '${formatDate.format(option.expirationDate!)} • ${formatCurrency.format(currentPrice)}',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: Colors.white70),
              ),
            ],
          ),
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

          // Contracts
          TextFormField(
            controller: quantityCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: "Contracts",
              border: OutlineInputBorder(),
              filled: true,
              suffixText: "contracts",
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
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
                      setState(() {
                        _isPreviewing = true;
                      });
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
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Text(
                    "$positionType ${quantityCtl.text} contracts",
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${widget.optionInstrument!.chainSymbol} \$${widget.optionInstrument!.strikePrice} ${widget.optionInstrument!.type}",
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  const SizedBox(height: 24),
                  _buildPreviewRow("Order Type", orderType),
                  if (orderType == 'Limit' || orderType == 'Stop Limit')
                    _buildPreviewRow("Limit Price", "\$${priceCtl.text}"),
                  if (orderType == 'Stop' || orderType == 'Stop Limit')
                    _buildPreviewRow("Stop Price", "\$${stopPriceCtl.text}"),
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

  Future<void> _placeOrder() async {
    setState(() {
      placingOrder = true;
    });
    var accountStore = Provider.of<AccountStore>(context, listen: false);

    try {
      String type = 'market';
      String trigger = 'immediate';
      double price = 0;
      double? stopPrice;
      Map<String, dynamic>? trailingPeg;

      if (orderType == 'Limit') {
        type = 'limit';
        price = double.parse(priceCtl.text);
      } else if (orderType == 'Stop') {
        type = 'market';
        trigger = 'stop';
        stopPrice = double.parse(stopPriceCtl.text);
        price = double.parse(stopPriceCtl.text);
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
        price = widget.optionInstrument?.optionMarketData?.markPrice ?? 0;
      } else {
        // Market
        price = double.parse(priceCtl.text);
      }

      var orderJson = await widget.service.placeOptionsOrder(
        widget.user,
        accountStore.items[0],
        widget.optionInstrument!,
        positionType == "Buy" ? "buy" : "sell", // side
        "open", //positionEffect
        "debit", //creditOrDebit
        price,
        int.parse(quantityCtl.text),
        type: type,
        trigger: trigger,
        stopPrice: stopPrice,
        timeInForce: timeInForce,
        trailingPeg: trailingPeg,
      );

      var newOrder = OptionOrder.fromJson(orderJson);

      if (!mounted) return;

      if (newOrder.state == "confirmed" || newOrder.state == "unconfirmed") {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              "Order to $positionType ${widget.optionInstrument!.chainSymbol} \$${widget.optionInstrument!.strikePrice} ${widget.optionInstrument!.type} placed."),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error placing order. State: ${newOrder.state}"),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
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
}

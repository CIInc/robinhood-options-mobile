import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/option_chain.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';
import 'package:robinhood_options_mobile/model/option_strategy.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/instrument_option_chain_widget.dart';
import 'package:robinhood_options_mobile/widgets/slide_to_confirm_widget.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';

class StrategyBuilderWidget extends StatefulWidget {
  final BrokerageUser user;
  final IBrokerageService service;
  final Instrument instrument;
  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final GenerativeService generativeService;
  final User? appUser;
  final DocumentReference<User>? userDocRef;

  const StrategyBuilderWidget({
    super.key,
    required this.user,
    required this.service,
    required this.instrument,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.appUser,
    required this.userDocRef,
  });

  @override
  State<StrategyBuilderWidget> createState() => _StrategyBuilderWidgetState();
}

class _StrategyBuilderWidgetState extends State<StrategyBuilderWidget> {
  OptionStrategy? selectedStrategy;
  List<OptionInstrument?> selectedLegs = [];
  List<String?> selectedLegActions = [];
  Future<OptionChain>? futureOptionChain;
  final TextEditingController _quantityController =
      TextEditingController(text: '1');
  final TextEditingController _priceController = TextEditingController();
  bool _isPreviewing = false;
  bool placingOrder = false;

  final Set<String> _selectedTags = {};
  late final List<String> _sortedTags;
  final ScrollController _previewScrollController = ScrollController();
  final ValueNotifier<PnLPoint?> _selectedPnL = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _sortedTags = OptionStrategy.strategies
        .expand((s) => s.tags)
        .toSet()
        .toList()
      ..sort();
    selectedStrategy = OptionStrategy.strategies.first;
    _resetLegs();
    futureOptionChain =
        widget.service.getOptionChains(widget.user, widget.instrument.id);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    _previewScrollController.dispose();
    _selectedPnL.dispose();
    super.dispose();
  }

  void _resetLegs() {
    if (selectedStrategy != null) {
      selectedLegs = List<OptionInstrument?>.filled(
          selectedStrategy!.legTemplates.length, null);
      selectedLegActions =
          List<String?>.filled(selectedStrategy!.legTemplates.length, null);
    }
    _selectedPnL.value = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isPreviewing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Review Order'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                _isPreviewing = false;
              });
            },
          ),
        ),
        body: _buildPreview(context),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Strategy Builder'),
        actions: [
          if (selectedLegs.any((leg) => leg != null))
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _resetLegs();
                });
              },
              tooltip: 'Reset Legs',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              // padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 0,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                            color:
                                Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: InkWell(
                        onTap: _showStrategyPicker,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (selectedStrategy != null) ...[
                                    Builder(builder: (context) {
                                      final icon =
                                          _getStrategyIcon(selectedStrategy!);
                                      final color = _getStrategyColor(
                                          selectedStrategy!, context);
                                      return Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child:
                                            Icon(icon, color: color, size: 24),
                                      );
                                    }),
                                    const SizedBox(width: 16),
                                  ],
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Strategy',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelMedium
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          selectedStrategy?.name ??
                                              'Select Strategy',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Change',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (selectedStrategy != null &&
                                  selectedStrategy!.description.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  selectedStrategy!.description,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                              if (selectedStrategy != null &&
                                  selectedStrategy!.tags.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: selectedStrategy!.tags.map((tag) {
                                    Color color = Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest;
                                    if (tag == 'Bullish') {
                                      color = Colors.green.withOpacity(0.1);
                                    } else if (tag == 'Bearish') {
                                      color = Colors.red.withOpacity(0.1);
                                    }

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        tag,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (selectedStrategy != null) ...[
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: selectedStrategy!.legTemplates.length,
                      itemBuilder: (context, index) {
                        final template = selectedStrategy!.legTemplates[index];
                        final selectedLeg = selectedLegs[index];
                        return _buildLegCard(
                            context, index, template, selectedLeg);
                      },
                    ),
                    if (_canReview()) ...[
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: () {
                                      int current = int.tryParse(
                                              _quantityController.text) ??
                                          1;
                                      if (current > 1) {
                                        _quantityController.text =
                                            (current - 1).toString();
                                        setState(() {});
                                      }
                                    },
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _quantityController,
                                      decoration: const InputDecoration(
                                        labelText: 'Quantity',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 16),
                                      ),
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      onChanged: (value) => setState(() {}),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: () {
                                      int current = int.tryParse(
                                              _quantityController.text) ??
                                          1;
                                      _quantityController.text =
                                          (current + 1).toString();
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _priceController,
                                decoration: const InputDecoration(
                                  labelText: 'Limit Price',
                                  border: OutlineInputBorder(),
                                  prefixText: '\$',
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 16),
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                onChanged: (value) {
                                  setState(() {});
                                  _selectedPnL.value = null;
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildMetricsCard(),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.show_chart,
                                    size: 20,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                const Text(
                                  "Profit & Loss",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            ValueListenableBuilder<PnLPoint?>(
                              valueListenable: _selectedPnL,
                              builder: (context, selectedPnL, child) {
                                PnLPoint displayPnL;
                                if (selectedPnL != null) {
                                  displayPnL = selectedPnL;
                                } else {
                                  final currentPrice = widget.instrument
                                          .quoteObj?.lastTradePrice ??
                                      0.0;
                                  final pnl = _calculatePnL(currentPrice);
                                  displayPnL = PnLPoint(currentPrice, pnl);
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      formatCurrency.format(displayPnL.pnl),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: displayPnL.pnl >= 0
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                    Text(
                                      'at ${formatCurrency.format(displayPnL.price)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 250,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: charts.LineChart(
                            _generatePnLData(),
                            animate: true,
                            defaultRenderer: charts.LineRendererConfig(
                              includePoints: false,
                              strokeWidthPx: 3.0,
                              includeArea: true,
                            ),
                            selectionModels: [
                              charts.SelectionModelConfig(
                                type: charts.SelectionModelType.info,
                                changedListener: (charts.SelectionModel model) {
                                  if (model.hasDatumSelection) {
                                    _selectedPnL.value = model
                                        .selectedDatum.first.datum as PnLPoint;
                                  } else {
                                    _selectedPnL.value = null;
                                  }
                                },
                              ),
                            ],
                            behaviors: [
                              charts.InitialSelection(
                                selectedDataConfig: [
                                  charts.SeriesDatumConfig<num>(
                                      'Profit & Loss',
                                      widget.instrument.quoteObj
                                              ?.lastTradePrice ??
                                          0)
                                ],
                                shouldPreserveSelectionOnDraw: true,
                              ),
                              charts.RangeAnnotation([
                                if (widget
                                        .instrument.quoteObj?.lastTradePrice !=
                                    null)
                                  charts.LineAnnotationSegment(
                                    widget.instrument.quoteObj!.lastTradePrice!,
                                    charts.RangeAnnotationAxisType.domain,
                                    startLabel: 'Current',
                                    color: charts.MaterialPalette.gray.shade400,
                                    dashPattern: [4, 4],
                                  ),
                                charts.LineAnnotationSegment(
                                  0,
                                  charts.RangeAnnotationAxisType.measure,
                                  startLabel: 'Breakeven',
                                  color: charts.MaterialPalette.gray.shade300,
                                  dashPattern: [4, 4],
                                ),
                                ...(_calculateMetrics()['breakevens']
                                            as List<double>? ??
                                        [])
                                    .map((be) => charts.LineAnnotationSegment(
                                          be,
                                          charts.RangeAnnotationAxisType.domain,
                                          startLabel: 'BE',
                                          color: charts
                                              .MaterialPalette.gray.shade400,
                                          dashPattern: [2, 2],
                                        )),
                              ]),
                              charts.SelectNearest(
                                  eventTrigger:
                                      charts.SelectionTrigger.tapAndDrag),
                              charts.LinePointHighlighter(
                                  symbolRenderer:
                                      charts.CircleSymbolRenderer()),
                            ],
                            domainAxis: charts.NumericAxisSpec(
                              tickProviderSpec:
                                  const charts.BasicNumericTickProviderSpec(
                                      zeroBound: false),
                              renderSpec: charts.SmallTickRendererSpec(
                                labelStyle: charts.TextStyleSpec(
                                  fontSize: 10,
                                  color: charts.MaterialPalette.gray.shade500,
                                ),
                              ),
                            ),
                            primaryMeasureAxis: charts.NumericAxisSpec(
                              tickProviderSpec:
                                  const charts.BasicNumericTickProviderSpec(
                                      zeroBound: false),
                              renderSpec: charts.GridlineRendererSpec(
                                labelStyle: charts.TextStyleSpec(
                                  fontSize: 10,
                                  color: charts.MaterialPalette.gray.shade500,
                                ),
                                lineStyle: const charts.LineStyleSpec(
                                  dashPattern: [4, 4],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildGreeksCard(),
                    ],
                  ],
                ],
              ),
            ),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    if (selectedStrategy == null || !_canReview())
      return const SizedBox.shrink();

    final price = _calculateEstimatedPrice();
    String text = '-';
    Color? color;
    if (price != null) {
      if (price > 0) {
        text = '\$${price.toStringAsFixed(2)} Debit';
      } else if (price < 0) {
        text = '\$${price.abs().toStringAsFixed(2)} Credit';
        color = Colors.green;
      } else {
        text = '\$0.00';
      }
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Estimated Price:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Text(
                  text,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _canReview() ? _reviewOrder : null,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Review Order',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegCard(BuildContext context, int index,
      StrategyLegTemplate template, OptionInstrument? selectedLeg) {
    final theme = Theme.of(context);
    final isAny = template.action == LegAction.any && selectedLeg == null;
    final isBuy = template.action == LegAction.any
        ? selectedLegActions[index]?.toLowerCase() == 'buy'
        : template.action == LegAction.buy;
    final actionColor =
        isAny ? Colors.grey : (isBuy ? Colors.green : Colors.red);

    final backgroundColor =
        selectedLeg != null ? actionColor.withOpacity(0.05) : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // 8
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _selectLeg(context, index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0), // 16.0
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: actionColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: actionColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isAny ? 'ANY' : (isBuy ? 'BUY' : 'SELL'),
                            style: TextStyle(
                              color: actionColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          template.ratio > 1
                              ? '${template.ratio}x ${template.name}'
                              : template.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (selectedLeg != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '\$${selectedLeg.strikePrice} ${selectedLeg.type.toUpperCase()}',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  selectedLeg.expirationDate != null
                                      ? DateFormat('MMM d')
                                          .format(selectedLeg.expirationDate!)
                                      : '-',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                          if (selectedLeg.optionMarketData != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  children: [
                                    _buildLegDetail(theme, 'Mark',
                                        '\$${selectedLeg.optionMarketData!.markPrice?.toStringAsFixed(2)}'),
                                    const SizedBox(width: 6),
                                    _buildLegDetail(
                                        theme,
                                        'Δ',
                                        selectedLeg.optionMarketData!.delta
                                                ?.toStringAsFixed(2) ??
                                            '-'),
                                    const SizedBox(width: 6),
                                    _buildLegDetail(
                                        theme,
                                        'IV',
                                        selectedLeg.optionMarketData!
                                                    .impliedVolatility !=
                                                null
                                            ? "${(selectedLeg.optionMarketData!.impliedVolatility! * 100).toStringAsFixed(1)}%"
                                            : "-"),
                                    const SizedBox(width: 6),
                                    _buildLegDetail(
                                        theme,
                                        'OI',
                                        formatCompactNumber.format(selectedLeg
                                            .optionMarketData!.openInterest)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      )
                    else
                      Text(
                        'Tap to select option',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              if (selectedLeg != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      selectedLegs[index] = null;
                    });
                  },
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegDetail(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label: $value',
        style: theme.textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildGreeksCard() {
    final greeks = _calculateGreeks();
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.functions,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Greeks',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6,
                children: greeks.entries.map((e) {
                  Color? valueColor;
                  if (e.key == 'Delta') {
                    if (e.value > 0) valueColor = Colors.green;
                    if (e.value < 0) valueColor = Colors.red;
                  }
                  return _buildMetricItem(
                      e.key, e.value.toStringAsFixed(4), valueColor);
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsCard() {
    final metrics = _calculateMetrics();
    if (metrics.isEmpty) return const SizedBox.shrink();

    final maxProfit = metrics['maxProfit'];
    final maxLoss = metrics['maxLoss'];
    final breakevens = metrics['breakevens'] as List<double>;
    final chanceOfProfit = metrics['chanceOfProfit'] as double?;
    final iv = metrics['iv'] as double?;
    final volume = metrics['volume'] as double?;
    final openInterest = metrics['openInterest'] as double?;
    final currentPrice = widget.instrument.quoteObj?.lastTradePrice;

    String formatValue(double? value) {
      if (value == null) return '-';
      if (value.isInfinite) return 'Unlimited';
      return formatCurrency.format(value);
    }

    String? returnOnRisk;
    if (maxProfit != null &&
        maxLoss != null &&
        !maxLoss.isInfinite &&
        maxLoss != 0) {
      if (maxProfit.isInfinite) {
        returnOnRisk = "Unlimited";
      } else {
        double risk = maxLoss.abs();
        double ret = (maxProfit / risk) * 100;
        returnOnRisk = "${ret.toStringAsFixed(1)}%";
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics_outlined,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Analysis',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.6, // 2.0
                children: [
                  _buildMetricItem(
                    'Max Profit',
                    formatValue(maxProfit),
                    Colors.green,
                  ),
                  _buildMetricItem(
                    'Max Loss',
                    formatValue(maxLoss),
                    Colors.red,
                  ),
                  if (returnOnRisk != null)
                    _buildMetricItem(
                      'Return on Risk',
                      returnOnRisk,
                      Colors.blue,
                    ),
                  if (chanceOfProfit != null)
                    _buildMetricItem(
                      'Chance of Profit',
                      '${(chanceOfProfit * 100).toStringAsFixed(1)}%',
                      null,
                    ),
                  if (iv != null && iv > 0)
                    _buildMetricItem(
                      'IV',
                      '${(iv * 100).toStringAsFixed(1)}%',
                      null,
                    ),
                  if (volume != null)
                    _buildMetricItem(
                      'Volume',
                      formatCompactNumber.format(volume),
                      null,
                    ),
                  if (openInterest != null)
                    _buildMetricItem(
                      'Open Interest',
                      formatCompactNumber.format(openInterest),
                      null,
                    ),
                  _buildMetricItem(
                    'Breakeven',
                    breakevens.isEmpty
                        ? '-'
                        : breakevens.map((e) {
                            String s = '\$${e.toStringAsFixed(2)}';
                            if (currentPrice != null && currentPrice > 0) {
                              double pct =
                                  ((e - currentPrice) / currentPrice) * 100;
                              String sign = pct >= 0 ? '+' : '';
                              s += ' ($sign${pct.toStringAsFixed(1)}%)';
                            }
                            return s;
                          }).join('\n'),
                    null,
                  ),
                  if (currentPrice != null)
                    _buildMetricItem(
                      'Current Price',
                      '\$${currentPrice.toStringAsFixed(2)}',
                      null,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, Color? valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: valueColor)),
      ],
    );
  }

  double _calculateEntryCost() {
    double estimatedPrice = _calculateEstimatedPrice() ?? 0.0;
    double manualPrice = double.tryParse(_priceController.text) ?? 0.0;

    double entryCost = manualPrice.abs();
    if (estimatedPrice < 0) {
      entryCost = -entryCost;
    } else if (estimatedPrice == 0 && selectedLegs.length == 1) {
      if (selectedStrategy!.legTemplates[0].action == LegAction.sell) {
        entryCost = -entryCost;
      }
    }
    return entryCost;
  }

  Map<String, dynamic> _calculateMetrics() {
    if (selectedStrategy?.type != StrategyType.custom &&
        !selectedLegs.every((leg) => leg != null)) {
      return {};
    }
    if (selectedStrategy?.type == StrategyType.custom &&
        !selectedLegs.any((leg) => leg != null)) {
      return {};
    }

    double entryCost = _calculateEntryCost();

    Set<double> strikes = {};
    for (var leg in selectedLegs) {
      if (leg?.strikePrice != null) {
        strikes.add(leg!.strikePrice!);
      }
    }
    List<double> sortedPoints = [0.0, ...strikes.toList()..sort()];

    double calculatePayoff(double price) {
      double payoff = 0.0;
      for (int i = 0; i < selectedLegs.length; i++) {
        var leg = selectedLegs[i];
        if (leg == null) continue;
        var template = selectedStrategy!.legTemplates[i];
        double strike = leg.strikePrice ?? 0;
        double value = 0;
        if (leg.type == 'call') {
          value = max(0.0, price - strike);
        } else {
          value = max(0.0, strike - price);
        }
        final isBuy = template.action == LegAction.any
            ? selectedLegActions[i]?.toLowerCase() == 'buy'
            : template.action == LegAction.buy;
        if (isBuy) {
          payoff += value * template.ratio;
        } else {
          payoff -= value * template.ratio;
        }
      }
      return payoff * 100; // Contract multiplier
    }

    double netCost = entryCost * 100;

    List<double> pnls =
        sortedPoints.map((p) => calculatePayoff(p) - netCost).toList();

    // Calculate Slope at Infinity
    double slope = 0.0;
    for (int i = 0; i < selectedLegs.length; i++) {
      var leg = selectedLegs[i];
      if (leg == null) continue;
      var template = selectedStrategy!.legTemplates[i];
      if (leg.type == 'call') {
        final isBuy = template.action == LegAction.any
            ? selectedLegActions[i]?.toLowerCase() == 'buy'
            : template.action == LegAction.buy;
        if (isBuy) {
          slope += template.ratio;
        } else {
          slope -= template.ratio;
        }
      }
    }
    slope *= 100;

    double? maxProfit;
    double? maxLoss;

    // Check points
    double maxPnlInPoints = pnls.reduce(max);
    double minPnlInPoints = pnls.reduce(min);

    if (slope > 0) {
      maxProfit = double.infinity;
    } else {
      maxProfit = maxPnlInPoints;
    }

    if (slope < 0) {
      maxLoss = double.infinity; // Represents infinite loss
    } else {
      maxLoss = minPnlInPoints;
    }

    // Breakevens
    List<double> breakevens = [];
    for (int i = 0; i < sortedPoints.length - 1; i++) {
      double p1 = sortedPoints[i];
      double p2 = sortedPoints[i + 1];
      double val1 = pnls[i];
      double val2 = pnls[i + 1];

      if ((val1 > 0 && val2 < 0) || (val1 < 0 && val2 > 0)) {
        double m = (val2 - val1) / (p2 - p1);
        double be = p1 - val1 / m;
        breakevens.add(be);
      } else if (val1 == 0) {
        if (!breakevens.contains(p1)) breakevens.add(p1);
      } else if (val2 == 0) {
        if (!breakevens.contains(p2)) breakevens.add(p2);
      }
    }

    // Check infinity segment
    double lastPoint = sortedPoints.last;
    double lastVal = pnls.last;
    if (slope != 0) {
      double be = lastPoint - lastVal / slope;
      if (be > lastPoint) {
        breakevens.add(be);
      }
    }

    // Calculate IV, Vol, OI
    double totalVol = 0;
    double totalOI = 0;
    double totalIV = 0;
    int ivCount = 0;

    for (var leg in selectedLegs) {
      if (leg?.optionMarketData != null) {
        totalVol += leg!.optionMarketData!.volume;
        totalOI += leg.optionMarketData!.openInterest;
        if (leg.optionMarketData!.impliedVolatility != null) {
          totalIV += leg.optionMarketData!.impliedVolatility!;
          ivCount++;
        }
      }
    }
    double avgIV = ivCount > 0 ? totalIV / ivCount : 0;

    // Calculate Chance of Profit
    double? chanceOfProfit;
    double totalChanceOfProfit = 0;
    int chanceOfProfitCount = 0;

    for (int i = 0; i < selectedLegs.length; i++) {
      final leg = selectedLegs[i];
      if (leg?.optionMarketData != null) {
        final template = selectedStrategy!.legTemplates[i];
        final isBuy = template.action == LegAction.any
            ? selectedLegActions[i]?.toLowerCase() == 'buy'
            : template.action == LegAction.buy;

        double? legChance = isBuy
            ? leg!.optionMarketData!.chanceOfProfitLong
            : leg!.optionMarketData!.chanceOfProfitShort;

        if (legChance != null) {
          totalChanceOfProfit += legChance;
          chanceOfProfitCount++;
        }
      }
    }

    if (chanceOfProfitCount > 0) {
      chanceOfProfit = totalChanceOfProfit / chanceOfProfitCount;
    }

    return {
      'maxProfit': maxProfit,
      'maxLoss': maxLoss,
      'breakevens': breakevens,
      'chanceOfProfit': chanceOfProfit,
      'iv': avgIV,
      'volume': totalVol,
      'openInterest': totalOI,
    };
  }

  Map<String, double> _calculateGreeks() {
    double delta = 0;
    double gamma = 0;
    double theta = 0;
    double vega = 0;
    double rho = 0;

    for (int i = 0; i < selectedLegs.length; i++) {
      final leg = selectedLegs[i];
      if (leg == null || leg.optionMarketData == null) continue;

      final template = selectedStrategy!.legTemplates[i];
      final ratio = template.ratio;
      final isBuy = template.action == LegAction.any
          ? selectedLegActions[i]?.toLowerCase() == 'buy'
          : template.action == LegAction.buy;
      final direction = isBuy ? 1 : -1;

      final data = leg.optionMarketData!;

      delta += (data.delta ?? 0) * ratio * direction;
      gamma += (data.gamma ?? 0) * ratio * direction;
      theta += (data.theta ?? 0) * ratio * direction;
      vega += (data.vega ?? 0) * ratio * direction;
      rho += (data.rho ?? 0) * ratio * direction;
    }

    return {
      'Delta': delta,
      'Gamma': gamma,
      'Theta': theta,
      'Vega': vega,
      'Rho': rho,
    };
  }

  double? _calculateEstimatedPrice() {
    if (selectedStrategy?.type != StrategyType.custom &&
        !selectedLegs
            .every((leg) => leg != null && leg.optionMarketData != null)) {
      return null;
    }
    if (selectedStrategy?.type == StrategyType.custom &&
        !selectedLegs
            .any((leg) => leg != null && leg.optionMarketData != null)) {
      return null;
    }

    double total = 0;
    for (int i = 0; i < selectedLegs.length; i++) {
      final leg = selectedLegs[i];
      if (leg == null || leg.optionMarketData == null) continue;
      final template = selectedStrategy!.legTemplates[i];
      final double price = leg.optionMarketData!.markPrice ?? 0.0;

      final isBuy = template.action == LegAction.any
          ? selectedLegActions[i]?.toLowerCase() == 'buy'
          : template.action == LegAction.buy;

      if (isBuy) {
        total += price * template.ratio;
      } else {
        total -= price * template.ratio;
      }
    }
    return total;
  }

  bool _canReview() {
    if (selectedStrategy?.type == StrategyType.custom) {
      return selectedLegs.any((leg) => leg != null);
    }
    return selectedLegs.every((leg) => leg != null);
  }

  void _reviewOrder() {
    setState(() {
      _isPreviewing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_previewScrollController.hasClients) {
        _previewScrollController.jumpTo(0);
      }
    });
  }

  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final estimatedPrice = _calculateEstimatedPrice() ?? 0.0;
    final creditOrDebit = estimatedPrice < 0 ? 'credit' : 'debit';
    final estimatedTotal = price * quantity * 100;

    return SingleChildScrollView(
      controller: _previewScrollController,
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
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Text(
                    "${selectedStrategy!.name} Strategy",
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${quantity}x Contracts",
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                  const SizedBox(height: 24),
                  _buildPreviewRow("Underlying",
                      "${widget.instrument.symbol} \$${widget.instrument.quoteObj?.lastTradePrice?.toStringAsFixed(2) ?? '-'}"),
                  _buildPreviewRow("Order Type", "Limit"),
                  _buildPreviewRow("Price", "\$${price.toStringAsFixed(2)}"),
                  _buildPreviewRow("Effect", creditOrDebit.toUpperCase()),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(),
                  ),
                  const Text('Legs',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...selectedLegs.asMap().entries.map((entry) {
                    final index = entry.key;
                    final leg = entry.value!;
                    final template = selectedStrategy!.legTemplates[index];
                    final isBuy = template.action == LegAction.any
                        ? selectedLegActions[index]?.toLowerCase() == 'buy'
                        : template.action == LegAction.buy;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isBuy
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: isBuy
                                      ? Colors.green.withOpacity(0.5)
                                      : Colors.red.withOpacity(0.5)),
                            ),
                            child: Text(
                              isBuy ? 'BUY' : 'SELL',
                              style: TextStyle(
                                color: isBuy ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${template.ratio}x',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${leg.expirationDate.toString().split(' ')[0]} \$${leg.strikePrice} ${leg.type.toUpperCase()}',
                              style: theme.textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '\$${leg.optionMarketData?.markPrice?.toStringAsFixed(2) ?? '-'}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Divider(),
                  ),
                  Builder(builder: (context) {
                    final metrics = _calculateMetrics();
                    final maxProfit = metrics['maxProfit'] as double?;
                    final maxLoss = metrics['maxLoss'] as double?;
                    final breakevens = metrics['breakevens'] as List<double>?;

                    String formatVal(double? val) {
                      if (val == null) return '-';
                      if (val.isInfinite) return 'Unlimited';
                      return formatCurrency.format(val);
                    }

                    return Column(
                      children: [
                        _buildPreviewRow("Max Profit", formatVal(maxProfit),
                            valueColor: Colors.green),
                        _buildPreviewRow("Max Loss", formatVal(maxLoss),
                            valueColor: Colors.red),
                        if (breakevens != null && breakevens.isNotEmpty)
                          _buildPreviewRow(
                              "Breakeven",
                              breakevens
                                  .map((e) => formatCurrency.format(e))
                                  .join(', ')),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Divider(),
                        ),
                      ],
                    );
                  }),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Estimated Total", style: theme.textTheme.bodyLarge),
                      Text(
                        formatCurrency.format(estimatedTotal.abs()),
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
            text: "Slide to Submit",
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            sliderColor: theme.colorScheme.primary,
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

  Widget _buildPreviewRow(String label, String value,
      {bool isBold = false, Color? valueColor}) {
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
                  color: valueColor ?? theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    setState(() {
      placingOrder = true;
    });
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final estimatedPrice = _calculateEstimatedPrice() ?? 0.0;
    final creditOrDebit = estimatedPrice < 0 ? 'credit' : 'debit';

    try {
      // RiskGuard Check
      var accountStore = Provider.of<AccountStore>(context, listen: false);
      var agenticProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      final portfolioState = <String, dynamic>{};
      if (accountStore.items.isNotEmpty) {
        portfolioState['cash'] =
            accountStore.items[0].portfolioCash; // .buyingPower
      }

      final riskResult =
          await FirebaseFunctions.instance.httpsCallable('riskguardTask').call({
        'proposal': {
          'symbol': widget.instrument.symbol,
          'quantity': quantity,
          'price': price.abs(),
          'action': creditOrDebit == 'debit' ? 'BUY' : 'SELL',
          'multiplier': 100,
          'strategy': selectedStrategy?.name,
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

        if (proceed != true) {
          return;
        }
      }

      final legs = selectedLegs
          .asMap()
          .entries
          .where((entry) => entry.value != null)
          .map((entry) {
        final index = entry.key;
        final leg = entry.value!;
        final template = selectedStrategy!.legTemplates[index];
        final isBuy = template.action == LegAction.any
            ? selectedLegActions[index]?.toLowerCase() == 'buy'
            : template.action == LegAction.buy;
        return {
          'position_effect': 'open', // Assuming opening a new position
          'side': isBuy ? 'buy' : 'sell',
          'ratio_quantity': template.ratio,
          'option': leg.url,
        };
      }).toList();

      await widget.service.placeMultiLegOptionsOrder(
        widget.user,
        Provider.of<AccountStore>(context, listen: false)
            .items
            .first, // Assuming first account
        legs,
        creditOrDebit,
        price,
        quantity,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully')),
        );
        Navigator.pop(context); // Go back
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error placing order: $e')),
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

  void _selectLeg(BuildContext context, int index) {
    final leg = selectedStrategy!.legTemplates[index];
    String? initialActionFilter;
    if (leg.action == LegAction.buy) {
      initialActionFilter = "Buy";
    } else if (leg.action == LegAction.sell) {
      initialActionFilter = "Sell";
    } else {
      initialActionFilter = selectedLegActions[index];
    }

    String? initialTypeFilter;
    if (leg.type == LegType.call) {
      initialTypeFilter = "Call";
    } else if (leg.type == LegType.put) {
      initialTypeFilter = "Put";
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InstrumentOptionChainWidget(
          widget.user,
          widget.service,
          widget.instrument,
          analytics: widget.analytics,
          observer: widget.observer,
          generativeService: widget.generativeService,
          user: widget.appUser,
          userDocRef: widget.userDocRef,
          initialActionFilter: initialActionFilter,
          initialTypeFilter: initialTypeFilter,
          selectedOption: selectedLegs[index],
          title: 'Select Leg ${index + 1}: ${leg.name}',
          isOptionEnabled: (option) => _isOptionValid(option, index),
          subtitleBuilder: (option) {
            final reason = _getOptionInvalidReason(option, index);
            if (reason != null) {
              return Text(
                reason,
                style: const TextStyle(color: Colors.red),
              );
            }
            return null;
          },
          onOptionSelected: (option, actionFilter) {
            setState(() {
              selectedLegs[index] = option;
              selectedLegActions[index] = actionFilter;
              if (_canReview()) {
                final price = _calculateEstimatedPrice();
                if (price != null) {
                  _priceController.text = price.abs().toStringAsFixed(2);
                }
              }
              _selectedPnL.value = null;
            });
          },
        ),
      ),
    );
  }

  String? _getOptionInvalidReason(OptionInstrument option, int currentIndex) {
    final template = selectedStrategy!.legTemplates[currentIndex];
    if (template.type != LegType.any) {
      if (template.type == LegType.call && option.type != 'call') {
        return "Must be a Call";
      }
      if (template.type == LegType.put && option.type != 'put') {
        return "Must be a Put";
      }
    }

    for (int i = 0; i < selectedLegs.length; i++) {
      if (i == currentIndex) continue;
      final otherLeg = selectedLegs[i];
      if (otherLeg == null) continue;

      if (selectedStrategy!.type == StrategyType.vertical ||
          selectedStrategy!.type == StrategyType.ironCondor ||
          selectedStrategy!.type == StrategyType.ironButterfly ||
          selectedStrategy!.type == StrategyType.condor ||
          selectedStrategy!.type == StrategyType.butterfly) {
        if (option.expirationDate != otherLeg.expirationDate) {
          return "Must have same expiration";
        }
      }

      if (selectedStrategy!.type == StrategyType.vertical) {
        if (option.type != otherLeg.type) {
          return "Must be same type (${otherLeg.type})";
        }
        if (option.strikePrice == otherLeg.strikePrice) {
          return "Must have different strike";
        }
        if (option.strikePrice != null && otherLeg.strikePrice != null) {
          if (currentIndex == 0 &&
              option.strikePrice! >= otherLeg.strikePrice!) {
            return "Must be lower strike than Leg 2";
          }
          if (currentIndex == 1 &&
              option.strikePrice! <= otherLeg.strikePrice!) {
            return "Must be higher strike than Leg 1";
          }
        }
      }

      if (selectedStrategy!.type == StrategyType.calendar) {
        if (option.strikePrice != otherLeg.strikePrice) {
          return "Must have same strike";
        }
        if (option.expirationDate == otherLeg.expirationDate) {
          return "Must have different expiration";
        }
        if (option.type != otherLeg.type) {
          return "Must be same type (${otherLeg.type})";
        }
      }

      if (selectedStrategy!.type == StrategyType.diagonal) {
        if (option.strikePrice == otherLeg.strikePrice) {
          return "Must have different strike";
        }
        if (option.expirationDate == otherLeg.expirationDate) {
          return "Must have different expiration";
        }
        if (option.type != otherLeg.type) {
          return "Must be same type (${otherLeg.type})";
        }
      }

      if (selectedStrategy!.type == StrategyType.butterfly) {
        if (option.strikePrice != null && otherLeg.strikePrice != null) {
          if (currentIndex == 0) {
            if (option.strikePrice! >= otherLeg.strikePrice!) {
              return "Must be lower strike";
            }
          } else if (currentIndex == 1) {
            if (i == 0 && option.strikePrice! <= otherLeg.strikePrice!) {
              return "Must be higher strike than Low";
            }
            if (i == 2 && option.strikePrice! >= otherLeg.strikePrice!) {
              return "Must be lower strike than High";
            }
          } else if (currentIndex == 2) {
            if (option.strikePrice! <= otherLeg.strikePrice!) {
              return "Must be higher strike";
            }
          }
        }
      }

      if (selectedStrategy!.type == StrategyType.condor) {
        if (option.strikePrice != null && otherLeg.strikePrice != null) {
          if (currentIndex == 0) {
            if (option.strikePrice! >= otherLeg.strikePrice!) {
              return "Must be lower strike";
            }
          } else if (currentIndex == 1) {
            if (i == 0 && option.strikePrice! <= otherLeg.strikePrice!) {
              return "Must be higher strike than Low";
            }
            if (i > 1 && option.strikePrice! >= otherLeg.strikePrice!) {
              return "Must be lower strike than higher legs";
            }
          } else if (currentIndex == 2) {
            if (i < 2 && option.strikePrice! <= otherLeg.strikePrice!) {
              return "Must be higher strike than lower legs";
            }
            if (i == 3 && option.strikePrice! >= otherLeg.strikePrice!) {
              return "Must be lower strike than High";
            }
          } else if (currentIndex == 3) {
            if (option.strikePrice! <= otherLeg.strikePrice!) {
              return "Must be higher strike";
            }
          }
        }
      }

      if (selectedStrategy!.type == StrategyType.straddle ||
          selectedStrategy!.type == StrategyType.shortStraddle) {
        if (option.expirationDate != otherLeg.expirationDate) {
          return "Must have same expiration";
        }
        if (option.strikePrice != otherLeg.strikePrice) {
          return "Must have same strike";
        }
      }

      if (selectedStrategy!.type == StrategyType.strangle ||
          selectedStrategy!.type == StrategyType.shortStrangle) {
        if (option.expirationDate != otherLeg.expirationDate) {
          return "Must have same expiration";
        }
      }
    }
    return null;
  }

  bool _isOptionValid(OptionInstrument option, int currentIndex) {
    return _getOptionInvalidReason(option, currentIndex) == null;
  }

  double _calculatePnL(double price) {
    double pnl = 0;
    for (int i = 0; i < selectedLegs.length; i++) {
      var leg = selectedLegs[i];
      if (leg == null) continue;
      var template = selectedStrategy!.legTemplates[i];
      double strike = leg.strikePrice ?? 0;

      double valueAtExpiration = 0;
      if (leg.type == 'call') {
        valueAtExpiration = max(0.0, price - strike);
      } else {
        valueAtExpiration = max(0.0, strike - price);
      }

      final isBuy = template.action == LegAction.any
          ? selectedLegActions[i]?.toLowerCase() == 'buy'
          : template.action == LegAction.buy;

      if (isBuy) {
        pnl += (valueAtExpiration * template.ratio) * 100;
      } else {
        pnl -= (valueAtExpiration * template.ratio) * 100;
      }
    }
    double entryCost = _calculateEntryCost();
    pnl -= entryCost * 100;
    return pnl;
  }

  List<charts.Series<PnLPoint, num>> _generatePnLData() {
    if (selectedStrategy?.type != StrategyType.custom &&
        !selectedLegs.every((leg) => leg != null)) return [];
    if (selectedStrategy?.type == StrategyType.custom &&
        !selectedLegs.any((leg) => leg != null)) return [];

    double currentPrice = widget.instrument.quoteObj?.lastTradePrice ?? 0;

    // Collect key points to determine zoom range
    Set<double> keyPoints = {};
    if (currentPrice > 0) keyPoints.add(currentPrice);

    for (var leg in selectedLegs) {
      if (leg != null && leg.strikePrice != null) {
        keyPoints.add(leg.strikePrice!);
      }
    }

    // Add breakevens to key points
    final metrics = _calculateMetrics();
    final breakevens = metrics['breakevens'] as List<double>? ?? [];
    keyPoints.addAll(breakevens);

    // Filter valid points
    final validPoints = keyPoints.where((p) => p > 0).toList();

    double start;
    double end;

    if (validPoints.isEmpty) {
      start = currentPrice * 0.8;
      end = currentPrice * 1.2;
    } else {
      double minPoint = validPoints.reduce(min);
      double maxPoint = validPoints.reduce(max);

      // Calculate span and add buffer
      double span = maxPoint - minPoint;
      if (span == 0) span = maxPoint * 0.1;

      // Use a wider buffer (50% of span) to show more context
      double buffer = span * 0.5;
      // Ensure minimum buffer of 5% of price
      buffer = max(buffer, currentPrice * 0.05);

      start = max(0, minPoint - buffer);
      end = maxPoint + buffer;
    }

    double step = (end - start) / 200; // Increased resolution

    List<PnLPoint> data = [];
    double entryCost = _calculateEntryCost();

    for (double price = start; price <= end; price += step) {
      double pnl = 0;
      for (int i = 0; i < selectedLegs.length; i++) {
        var leg = selectedLegs[i];
        if (leg == null) continue;
        var template = selectedStrategy!.legTemplates[i];
        double strike = leg.strikePrice ?? 0;

        double valueAtExpiration = 0;
        if (leg.type == 'call') {
          valueAtExpiration = max(0.0, price - strike);
        } else {
          valueAtExpiration = max(0.0, strike - price);
        }

        final isBuy = template.action == LegAction.any
            ? selectedLegActions[i]?.toLowerCase() == 'buy'
            : template.action == LegAction.buy;

        if (isBuy) {
          pnl += (valueAtExpiration * template.ratio) * 100;
        } else {
          pnl -= (valueAtExpiration * template.ratio) * 100;
        }
      }
      pnl -= entryCost * 100;

      data.add(PnLPoint(price, pnl));
    }

    // Ensure current price is in the data for initial selection
    if (currentPrice > 0 &&
        !data.any((p) => (p.price - currentPrice).abs() < 0.01)) {
      data.add(PnLPoint(currentPrice, _calculatePnL(currentPrice)));
      data.sort((a, b) => a.price.compareTo(b.price));
    }

    return [
      charts.Series<PnLPoint, num>(
        id: 'Profit & Loss',
        colorFn: (PnLPoint point, _) => point.pnl >= 0
            ? charts.MaterialPalette.green.shadeDefault
            : charts.MaterialPalette.red.shadeDefault,
        areaColorFn: (PnLPoint point, _) => point.pnl >= 0
            ? charts.MaterialPalette.green.shadeDefault.lighter
            : charts.MaterialPalette.red.shadeDefault.lighter,
        domainFn: (PnLPoint point, _) => point.price,
        measureFn: (PnLPoint point, _) => point.pnl,
        data: data,
      )
    ];
  }

  void _showStrategyPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              final filteredStrategies = OptionStrategy.strategies.where((s) {
                if (_selectedTags.isEmpty) return true;
                return _selectedTags.every((t) => s.tags.contains(t));
              }).toList();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Strategy',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _sortedTags.map((tag) {
                              final isSelected = _selectedTags.contains(tag);
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: FilterChip(
                                  label: Text(tag),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      _selectedTags.clear();
                                      if (selected) {
                                        _selectedTags.add(tag);
                                      }
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: filteredStrategies.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final strategy = filteredStrategies[index];
                        final isSelected = strategy == selectedStrategy;

                        final icon = _getStrategyIcon(strategy);
                        final iconColor = _getStrategyColor(strategy, context);

                        return Card(
                          elevation: isSelected ? 4 : 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isSelected
                                ? BorderSide(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    width: 2)
                                : BorderSide.none,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                selectedStrategy = strategy;
                                _resetLegs();
                              });
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            iconColor.withOpacity(0.1),
                                        child: Icon(icon, color: iconColor),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              strategy.name,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              children:
                                                  strategy.tags.map((tag) {
                                                Color color = Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest;
                                                if (tag == 'Bullish') {
                                                  color = Colors.green
                                                      .withOpacity(0.1);
                                                } else if (tag == 'Bearish') {
                                                  color = Colors.red
                                                      .withOpacity(0.1);
                                                }
                                                return Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: color,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    tag,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        Icon(Icons.check_circle,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    strategy.description,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children:
                                          strategy.legTemplates.map((leg) {
                                        final isBuy =
                                            leg.action == LegAction.buy;
                                        final isSell =
                                            leg.action == LegAction.sell;
                                        final color = isBuy
                                            ? Colors.green
                                            : (isSell
                                                ? Colors.red
                                                : Colors.grey);
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 2),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isBuy
                                                    ? Icons.add_circle_outline
                                                    : (isSell
                                                        ? Icons
                                                            .remove_circle_outline
                                                        : Icons.help_outline),
                                                size: 14,
                                                color: color,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                leg.name,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  IconData _getStrategyIcon(OptionStrategy strategy) {
    if (strategy.tags.contains('Bullish')) return Icons.trending_up;
    if (strategy.tags.contains('Bearish')) return Icons.trending_down;
    if (strategy.tags.contains('Neutral')) return Icons.swap_horiz;
    if (strategy.tags.contains('Volatility')) return Icons.waves;
    if (strategy.tags.contains('Income')) return Icons.attach_money;
    if (strategy.tags.contains('Calendar')) return Icons.calendar_month;
    if (strategy.tags.contains('Directional')) return Icons.explore;
    return Icons.show_chart;
  }

  Color _getStrategyColor(OptionStrategy strategy, BuildContext context) {
    if (strategy.tags.contains('Bullish')) return Colors.green;
    if (strategy.tags.contains('Bearish')) return Colors.red;
    if (strategy.tags.contains('Neutral')) return Colors.blue;
    if (strategy.tags.contains('Volatility')) return Colors.purple;
    if (strategy.tags.contains('Income')) return Colors.amber.shade700;
    if (strategy.tags.contains('Calendar')) return Colors.teal;
    if (strategy.tags.contains('Directional')) return Colors.orange;
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }
}

class PnLPoint {
  final double price;
  final double pnl;

  PnLPoint(this.price, this.pnl);
}

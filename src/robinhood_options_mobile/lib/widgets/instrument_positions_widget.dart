import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'dart:math' as math;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_bar_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_positions_page_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/pnl_badge.dart';
import 'package:robinhood_options_mobile/widgets/animated_price_text.dart';
import 'package:robinhood_options_mobile/widgets/synchronized_scroll_controller.dart';
import 'package:robinhood_options_mobile/widgets/web_promotion_banner_widget.dart';

class InstrumentPositionsWidget extends StatefulWidget {
  const InstrumentPositionsWidget(
    this.brokerageUser,
    this.service,
    //this.account,
    this.filteredPositions, {
    this.showList = true,
    this.disableNavigation = false,
    this.chartRowLimit,
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.user,
    required this.userDocRef,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  final bool showList;
  final bool disableNavigation;

  /// Caps how many bars the chart draws, so a summary card's height is bounded
  /// by the limit rather than by the position count. Null draws every position.
  ///
  /// The cap keeps the user's own sort — it takes the first rows of the list
  /// they asked for, not the largest ones — and the full page shows the rest.
  final int? chartRowLimit;
  final User? user;
  final DocumentReference<User>? userDocRef;
  //final Account account;
  final List<InstrumentPosition> filteredPositions;

  @override
  State<InstrumentPositionsWidget> createState() =>
      _InstrumentPositionsWidgetState();
}

class _InstrumentPositionsWidgetState extends State<InstrumentPositionsWidget> {
  final SynchronizedScrollControllerGroup _scrollGroup =
      SynchronizedScrollControllerGroup();
  final ValueNotifier<dynamic> _selectedPositionDatumNotifier =
      ValueNotifier<dynamic>(null);
  // final FirestoreService _firestoreService = FirestoreService();

  @override
  void dispose() {
    _selectedPositionDatumNotifier.dispose();
    super.dispose();
  }

  void _showAggregateTradeDisabled(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
              'Trading actions are disabled in Aggregate View. Switch to a single account to trade.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _handleNavigation(BuildContext context, VoidCallback action) {
    if (widget.disableNavigation) {
      _showAggregateTradeDisabled(context);
      return;
    }
    action();
  }

  @override
  Widget build(BuildContext context) {
    var sortedFilteredPositions = widget.filteredPositions.sortedBy<num>((i) =>
        widget.brokerageUser.getDisplayValueInstrumentPosition(i,
            displayValue: widget.brokerageUser.sortOptions));
    if (widget.brokerageUser.sortDirection == SortDirection.desc) {
      sortedFilteredPositions = sortedFilteredPositions.reversed.toList();
    }
    final chartPositions = _capForChart(sortedFilteredPositions);
    final isChartCapped =
        chartPositions.length < sortedFilteredPositions.length;

    List<charts.Series<dynamic, String>> barChartSeriesList = [];
    var data = [];

    DisplayValue? secondaryDisplayValue;
    if (widget.brokerageUser.displayValue == DisplayValue.marketValue) {
      secondaryDisplayValue = DisplayValue.totalCost;
    } else if (widget.brokerageUser.displayValue == DisplayValue.totalCost) {
      secondaryDisplayValue = DisplayValue.marketValue;
    } else if (widget.brokerageUser.displayValue == DisplayValue.totalReturn) {
      secondaryDisplayValue = DisplayValue.totalReturnPercent;
    } else if (widget.brokerageUser.displayValue ==
        DisplayValue.totalReturnPercent) {
      secondaryDisplayValue = DisplayValue.totalReturn;
    } else if (widget.brokerageUser.displayValue == DisplayValue.todayReturn) {
      secondaryDisplayValue = DisplayValue.todayReturnPercent;
    } else if (widget.brokerageUser.displayValue ==
        DisplayValue.todayReturnPercent) {
      secondaryDisplayValue = DisplayValue.todayReturn;
    }

    for (var position in chartPositions) {
      if (position.instrumentObj != null) {
        double? value =
            widget.brokerageUser.getDisplayValueInstrumentPosition(position);
        String? valueLabel = widget.brokerageUser.getDisplayText(value);
        double? secondaryValue;
        String? secondaryLabel;
        if (secondaryDisplayValue != null) {
          secondaryValue = widget.brokerageUser
              .getDisplayValueInstrumentPosition(position,
                  displayValue: secondaryDisplayValue);
          secondaryLabel = widget.brokerageUser.getDisplayText(secondaryValue,
              displayValue: secondaryDisplayValue);
        }

        String combinedLabel = valueLabel;
        if (secondaryLabel != null && secondaryLabel.isNotEmpty) {
          if (secondaryDisplayValue != DisplayValue.totalCost &&
              secondaryDisplayValue != DisplayValue.marketValue) {
            combinedLabel = '$valueLabel ($secondaryLabel)';
          }
        }

        data.add({
          'domain': position.instrumentObj!.symbol,
          'measure': value,
          'label': combinedLabel,
          'primaryLabel': valueLabel,
          'secondaryMeasure': secondaryValue,
          'secondaryLabel': secondaryLabel,
          'position': position,
        });
      }
    }
    var shades = PieChart.makeShades(
        charts.ColorUtil.fromDartColor(
            Theme.of(context).brightness == Brightness.light
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.primaryContainer),
        2);
    barChartSeriesList.add(charts.Series<dynamic, String>(
        id: BrokerageUser.displayValueText(widget.brokerageUser.displayValue!),
        data: data,
        seriesColor: shades[0],
        domainFn: (var d, _) => d['domain'],
        measureFn: (var d, _) => d['measure'],
        labelAccessorFn: (d, _) => d['label'],
        insideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
            fontSize: 13,
            color: charts.ColorUtil.fromDartColor(
              Theme.of(context).brightness == Brightness.light
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context).colorScheme.inverseSurface,
            )),
        outsideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
            fontSize: 13,
            color: charts.ColorUtil.fromDartColor(
                Theme.of(context).textTheme.labelSmall!.color!))));

    final bool isDualAxis = secondaryDisplayValue != null &&
        ((widget.brokerageUser.displayValue == DisplayValue.totalReturn &&
                secondaryDisplayValue == DisplayValue.totalReturnPercent) ||
            (widget.brokerageUser.displayValue ==
                    DisplayValue.totalReturnPercent &&
                secondaryDisplayValue == DisplayValue.totalReturn) ||
            (widget.brokerageUser.displayValue == DisplayValue.todayReturn &&
                secondaryDisplayValue == DisplayValue.todayReturnPercent) ||
            (widget.brokerageUser.displayValue ==
                    DisplayValue.todayReturnPercent &&
                secondaryDisplayValue == DisplayValue.todayReturn));

    if (secondaryDisplayValue != null) {
      var seriesData = charts.Series<dynamic, String>(
        id: BrokerageUser.displayValueText(secondaryDisplayValue),
        colorFn: (_, __) => shades[1],
        domainFn: (var d, _) => d['domain'],
        measureFn: (var d, _) => d['secondaryMeasure'],
        labelAccessorFn: (d, _) => d['secondaryLabel'],
        data: data,
      )..setAttribute(charts.rendererIdKey, 'customLine');

      if (isDualAxis) {
        seriesData.setAttribute(
            charts.measureAxisIdKey, charts.Axis.secondaryMeasureAxisId);
      }

      if (seriesData.data.isNotEmpty &&
          seriesData.data[0]['secondaryMeasure'] != null) {
        barChartSeriesList.add(seriesData);
      }
    }

    var brightness = MediaQuery.of(context).platformBrightness;
    var axisLabelColor = charts.MaterialPalette.gray.shade500;
    if (brightness == Brightness.light) {
      axisLabelColor = charts.MaterialPalette.gray.shade700;
    }

    var primaryValues = chartPositions
        .map((e) => widget.brokerageUser.getDisplayValueInstrumentPosition(e))
        .toList();
    charts.NumericExtents extents;
    charts.NumericExtents? secondaryExtents;
    List<charts.TickSpec<num>>? secondaryTicks;

    if (isDualAxis) {
      final secondaryValues = chartPositions
          .map((e) => widget.brokerageUser.getDisplayValueInstrumentPosition(e,
              displayValue: secondaryDisplayValue))
          .toList();
      final aligned = AlignedAxisExtents.compute(
        primaryValues: primaryValues,
        secondaryValues: secondaryValues,
      );
      extents = aligned.primaryExtents;
      secondaryExtents = aligned.secondaryExtents;

      final isSecondaryPercent =
          secondaryDisplayValue == DisplayValue.totalReturnPercent ||
              secondaryDisplayValue == DisplayValue.todayReturnPercent;

      secondaryTicks = <charts.TickSpec<num>>[];
      if (secondaryExtents.min < 0 && secondaryExtents.max > 0) {
        secondaryTicks.add(charts.TickSpec<num>(secondaryExtents.min));
        secondaryTicks.add(charts.TickSpec<num>(0.0,
            label: isSecondaryPercent ? '0%' : '\$0'));
        secondaryTicks.add(charts.TickSpec<num>(secondaryExtents.max));
      } else if (secondaryExtents.min >= 0) {
        secondaryTicks.add(charts.TickSpec<num>(0.0,
            label: isSecondaryPercent ? '0%' : '\$0'));
        secondaryTicks.add(charts.TickSpec<num>(secondaryExtents.max));
      } else {
        secondaryTicks.add(charts.TickSpec<num>(secondaryExtents.min));
        secondaryTicks.add(charts.TickSpec<num>(0.0,
            label: isSecondaryPercent ? '0%' : '\$0'));
      }
    } else {
      if (secondaryDisplayValue != null) {
        final secondaryValues = chartPositions
            .map((e) => widget.brokerageUser.getDisplayValueInstrumentPosition(
                e,
                displayValue: secondaryDisplayValue))
            .toList();
        primaryValues.addAll(secondaryValues);
      }
      final primaryNumericValues = primaryValues.whereType<double>().toList();
      extents = primaryNumericValues.isNotEmpty
          ? charts.NumericExtents.fromValues(primaryNumericValues)
          : const charts.NumericExtents(0, 1);
      double primaryPad = extents.width > 0 ? extents.width * 0.1 : 0.05;
      final bool startsAtZero =
          widget.brokerageUser.displayValue == DisplayValue.marketValue ||
              widget.brokerageUser.displayValue == DisplayValue.totalCost;
      final double minVal = startsAtZero ? 0.0 : extents.min - primaryPad;
      extents = charts.NumericExtents(minVal, extents.max + primaryPad);
    }

    var primaryMeasureAxis = widget.brokerageUser.displayValue ==
                DisplayValue.todayReturnPercent ||
            widget.brokerageUser.displayValue == DisplayValue.totalReturnPercent
        ? charts.PercentAxisSpec(
            viewport: extents,
            tickProviderSpec:
                const charts.BasicNumericTickProviderSpec(zeroBound: true),
            renderSpec: charts.GridlineRendererSpec(
                labelStyle: charts.TextStyleSpec(color: axisLabelColor)))
        : charts.NumericAxisSpec(
            viewport: extents,
            tickProviderSpec:
                const charts.BasicNumericTickProviderSpec(zeroBound: true),
            renderSpec: charts.GridlineRendererSpec(
                labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
            tickFormatterSpec:
                charts.BasicNumericTickFormatterSpec.fromNumberFormat(
                    NumberFormat.compactSimpleCurrency()),
          );

    charts.NumericAxisSpec? secondaryMeasureAxis;
    if (isDualAxis && secondaryExtents != null && secondaryTicks != null) {
      if (secondaryDisplayValue == DisplayValue.totalReturnPercent ||
          secondaryDisplayValue == DisplayValue.todayReturnPercent) {
        secondaryMeasureAxis = charts.PercentAxisSpec(
          viewport: secondaryExtents,
          renderSpec: charts.SmallTickRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
          tickProviderSpec:
              charts.StaticNumericTickProviderSpec(secondaryTicks),
        );
      } else {
        secondaryMeasureAxis = charts.NumericAxisSpec(
          viewport: secondaryExtents,
          renderSpec: charts.SmallTickRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
          tickFormatterSpec:
              charts.BasicNumericTickFormatterSpec.fromNumberFormat(
                  NumberFormat.compactSimpleCurrency()),
          tickProviderSpec:
              charts.StaticNumericTickProviderSpec(secondaryTicks),
        );
      }
    }

    var positionChart = BarChart(barChartSeriesList,
        renderer: charts.BarRendererConfig(
            groupingType: charts.BarGroupingType.stacked,
            barRendererDecorator: charts.BarLabelDecorator<String>(),
            cornerStrategy: const charts.ConstCornerStrategy(10)),
        primaryMeasureAxis: primaryMeasureAxis,
        secondaryMeasureAxis: (barChartSeriesList.length > 1 && isDualAxis)
            ? secondaryMeasureAxis
            : null,
        customSeriesRenderers: [
          charts.BarTargetLineRendererConfig<String>(
              customRendererId: 'customLine',
              groupingType: charts.BarGroupingType.grouped)
        ],
        barGroupingType: null,
        domainAxis: charts.OrdinalAxisSpec(
            renderSpec: charts.SmallTickRendererSpec(
                labelStyle: charts.TextStyleSpec(color: axisLabelColor))),
        behaviors: [
          charts.SeriesLegend(),
        ], onSelected: (dynamic datum) {
      _selectedPositionDatumNotifier.value = datum;
    });

    double? marketValue = widget.brokerageUser
        .getDisplayValueInstrumentPositions(sortedFilteredPositions,
            displayValue: DisplayValue.marketValue);

    double? totalReturn = widget.brokerageUser
        .getDisplayValueInstrumentPositions(sortedFilteredPositions,
            displayValue: DisplayValue.totalReturn);
    String? totalReturnText = widget.brokerageUser
        .getDisplayText(totalReturn!, displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = widget.brokerageUser
        .getDisplayValueInstrumentPositions(sortedFilteredPositions,
            displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = widget.brokerageUser.getDisplayText(
        totalReturnPercent!,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = widget.brokerageUser
        .getDisplayValueInstrumentPositions(sortedFilteredPositions,
            displayValue: DisplayValue.todayReturn);
    String? todayReturnText = widget.brokerageUser
        .getDisplayText(todayReturn!, displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = widget.brokerageUser
        .getDisplayValueInstrumentPositions(sortedFilteredPositions,
            displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = widget.brokerageUser.getDisplayText(
        todayReturnPercent!,
        displayValue: DisplayValue.todayReturnPercent);

    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(offset: ViewportOffset.zero(), slivers: [
      SliverToBoxAdapter(
          child: Column(children: [
        InkWell(
          onTap: widget.showList
              ? null
              : () {
                  navigateToFullPage(context);
                },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 6.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.bar_chart_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Stocks & ETFs",
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    fontSize: 19, fontWeight: FontWeight.bold),
                          ),
                          if (!widget.showList)
                            SizedBox(
                              height: 28,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.chevron_right),
                                onPressed: () => navigateToFullPage(context),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        "${formatCompactNumber.format(sortedFilteredPositions.length)} positions"
                        "${isChartCapped ? ", charting top ${chartPositions.length}" : ""}",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      widget.brokerageUser.displayValue =
                          DisplayValue.marketValue;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 8.0),
                    child: AnimatedPriceText(
                      price: marketValue ?? 0,
                      format: formatCurrency,
                      style: const TextStyle(fontSize: assetValueFontSize),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        /*
        if (user.displayValue != DisplayValue.lastPrice) ...[
          SizedBox(
              height: barChartSeriesList.first.data.length == 1
                  ? 75
                  : barChartSeriesList.first.data.length * 50,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    10.0, 0, 10, 10), //EdgeInsets.zero
                child: positionChart,
              )),
        ],
        */
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 0,
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: _buildDetailScrollRow(
                todayReturnText,
                todayReturnPercentText,
                totalReturnText,
                totalReturnPercentText,
                todayReturn,
                todayReturnPercent,
                totalReturn,
                totalReturnPercent),
          ),
        )
      ])),
      if (barChartSeriesList.isNotEmpty &&
          barChartSeriesList.first.data.isNotEmpty) ...[
        SliverToBoxAdapter(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
                height: math.max(
                    140.0, barChartSeriesList.first.data.length * 28.0 + 80.0),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      10.0, 0, 10, 0), //EdgeInsets.zero
                  child: positionChart,
                )),
            ValueListenableBuilder<dynamic>(
              valueListenable: _selectedPositionDatumNotifier,
              builder: (context, selectedDatum, child) {
                if (selectedDatum == null) return const SizedBox.shrink();
                return _buildInteractiveTooltip(context, selectedDatum);
              },
            ),
            _buildChartControls(context),
          ],
        ))
      ],
      /*
      SliverToBoxAdapter(
          child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Primary Measure Chip
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => MoreMenuBottomSheet(
                                widget.brokerageUser,
                                analytics: widget.analytics,
                                observer: widget.observer,
                                showOnlyPrimaryMeasure: true,
                                onSettingsChanged: (value) {
                              setState(() {});
                            }));
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bar_chart_rounded,
                          size: 18,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Measure',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer
                                          .withOpacity(0.7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      height: 1.2,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                BrokerageUser.displayValueText(
                                    widget.brokerageUser.displayValue!),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Sort Chip
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => MoreMenuBottomSheet(
                                widget.brokerageUser,
                                analytics: widget.analytics,
                                observer: widget.observer,
                                showOnlySort: true, onSettingsChanged: (value) {
                              setState(() {});
                            }));
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondaryContainer
                          .withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondary
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Icon(
                            widget.brokerageUser.sortDirection ==
                                    SortDirection.desc
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            size: 14,
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Sort by',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer
                                          .withOpacity(0.7),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      height: 1.2,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                BrokerageUser.displayValueText(
                                    widget.brokerageUser.sortOptions!),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSecondaryContainer,
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      )),
      */

      if (widget.showList) ...[
        SliverList(
          // delegate: SliverChildListDelegate(widgets),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return _buildPositionRow(context, sortedFilteredPositions, index);
            },
            // Or, uncomment the following line:
            childCount: sortedFilteredPositions.length,
          ),
        ),
        if (kIsWeb) const WebPromotionBannerSliver(),
        if (!kIsWeb) ...[
          const SliverToBoxAdapter(
              child: SizedBox(
            height: 25.0,
          )),
          SliverToBoxAdapter(
              child: AdBannerWidget(
            size: AdSize.mediumRectangle,
            // searchBanner: true,
          )),
        ],
        const SliverToBoxAdapter(
            child: SizedBox(
          height: 25.0,
        )),
        const SliverToBoxAdapter(child: DisclaimerWidget()),
        const SliverToBoxAdapter(
            child: SizedBox(
          height: 25.0,
        )),
      ]
    ]));
  }

  /// Trims chart rows to [InstrumentPositionsWidget.chartRowLimit].
  List<InstrumentPosition> _capForChart(List<InstrumentPosition> rows) {
    final limit = widget.chartRowLimit;
    if (limit == null || rows.length <= limit) return rows;
    return rows.take(limit).toList();
  }

  /// Opens the full ledger.
  ///
  /// Deliberately not routed through [_handleNavigation]: reading the position
  /// list is not a trade action, and blocking it would leave aggregate users
  /// with no way to see holdings the summary chart caps off. The page carries
  /// [InstrumentPositionsWidget.disableNavigation] forward instead, so the
  /// trade-bearing rows inside it stay disabled.
  void navigateToFullPage(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => InstrumentPositionsPageWidget(
                  widget.brokerageUser,
                  widget.service,
                  widget.filteredPositions,
                  analytics: widget.analytics,
                  observer: widget.observer,
                  generativeService: widget.generativeService,
                  user: widget.user,
                  userDocRef: widget.userDocRef,
                  disableNavigation: widget.disableNavigation,
                )));
  }

  Widget _buildPositionRow(
      BuildContext context, List<InstrumentPosition> positions, int index) {
    var instrument = positions[index].instrumentObj;

    double value = widget.brokerageUser
        .getDisplayValueInstrumentPosition(positions[index]);
    String trailingText = widget.brokerageUser.getDisplayText(value);
    Icon? icon = (widget.brokerageUser.displayValue == DisplayValue.lastPrice ||
            widget.brokerageUser.displayValue == DisplayValue.marketValue)
        ? null
        : widget.brokerageUser.getDisplayIcon(value, size: 31);

    double? totalReturn = widget.brokerageUser
        .getDisplayValueInstrumentPosition(positions[index],
            displayValue: DisplayValue.totalReturn);
    String? totalReturnText = widget.brokerageUser
        .getDisplayText(totalReturn, displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = widget.brokerageUser
        .getDisplayValueInstrumentPosition(positions[index],
            displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = widget.brokerageUser.getDisplayText(
        totalReturnPercent,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = widget.brokerageUser
        .getDisplayValueInstrumentPosition(positions[index],
            displayValue: DisplayValue.todayReturn);
    String? todayReturnText = widget.brokerageUser
        .getDisplayText(todayReturn, displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = widget.brokerageUser
        .getDisplayValueInstrumentPosition(positions[index],
            displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = widget.brokerageUser.getDisplayText(
        todayReturnPercent,
        displayValue: DisplayValue.todayReturnPercent);

    return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            /*
        leading: CircleAvatar(
            child: Text(formatCompactNumber.format(positions[index].quantity!),
                style: const TextStyle(fontSize: 17))),
                */
            leading: instrument != null
                ? Hero(
                    tag: 'logo_${instrument.symbol}${instrument.id}',
                    child: instrument.logoUrl != null
                        ? Image.network(
                            instrument.logoUrl!,
                            width: 50,
                            height: 50,
                            errorBuilder: (BuildContext context,
                                Object exception, StackTrace? stackTrace) {
                              RobinhoodService.removeLogo(instrument);
                              return CircleAvatar(
                                  radius: 25,
                                  // foregroundColor: Theme.of(context).colorScheme.primary, //.onBackground,
                                  //backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  child: Text(instrument.symbol,
                                      overflow: TextOverflow.fade,
                                      softWrap: false));
                            },
                          )
                        : CircleAvatar(
                            radius: 25,
                            // foregroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(instrument.symbol,
                                overflow: TextOverflow.fade, softWrap: false)))
                : null,
            title: Text(
              instrument != null
                  ? instrument.simpleName ?? instrument.name
                  : "",
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text("${positions[index].quantity} shares"),
            //'Average cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
            /*
        subtitle: Text(
            '${positions[index].quantity} shares\navg cost ${formatCurrency.format(positions[index].averageBuyPrice)}'),
            */
            trailing: //GestureDetector(child:
                Wrap(spacing: 8, children: [
              if (icon != null) ...[
                icon,
              ],
              Text(
                trailingText,
                style: const TextStyle(fontSize: positionValueFontSize),
                textAlign: TextAlign.right,
              )
            ]),
            //, onTap: () => showSettings()),
            // isThreeLine: true,
            onTap: () {
              /* For navigation within this tab, uncomment
          navigatorKey!.currentState!.push(MaterialPageRoute(
              builder: (context) => InstrumentWidget(ru, accounts!.first,
                  positions[index].instrumentObj as Instrument,
                  position: positions[index])));
                  */
              _handleNavigation(context, () {
                // var futureFromInstrument =
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => InstrumentWidget(
                              widget.brokerageUser,
                              widget.service,
                              instrument!,
                              heroTag:
                                  'logo_${instrument.symbol}${instrument.id}',
                              analytics: widget.analytics,
                              observer: widget.observer,
                              generativeService: widget.generativeService,
                              user: widget.user,
                              userDocRef: widget.userDocRef,
                            )));
              });
              // Refresh in case settings were updated.
              // futureFromInstrument.then((value) => setState(() {}));
            },
          ),
          // Compact color-coded badges
          // Padding(
          //   padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          //   child: Row(
          //     children: [
          //       _pnlBadge(context, todayReturnText, todayReturn),
          //       const SizedBox(width: 8),
          //       _pnlBadge(context, totalReturnText, totalReturn),
          //     ],
          //   ),
          // ),
          if (widget.brokerageUser.showPositionDetails) ...[
            _buildDetailScrollRow(
                todayReturnText,
                todayReturnPercentText,
                totalReturnText,
                totalReturnPercentText,
                todayReturn,
                todayReturnPercent,
                totalReturn,
                totalReturnPercent,
                volume: instrument?.fundamentalsObj?.volume)
          ]
        ]));
  }

  Widget _buildDetailScrollRow(
      String? todayReturnText,
      String? todayReturnPercentText,
      String? totalReturnText,
      String? totalReturnPercentText,
      double? todayReturn,
      double? todayReturnPercent,
      double? totalReturn,
      double? totalReturnPercent,
      {double? volume}) {
    Widget buildTile(String label, String valueText, double? value,
        {bool neutral = false}) {
      return InkWell(
        onTap: () {
          if (label == "Return Today") {
            setState(() {
              widget.brokerageUser.displayValue = DisplayValue.todayReturn;
            });
          } else if (label == "Return Today %") {
            setState(() {
              widget.brokerageUser.displayValue =
                  DisplayValue.todayReturnPercent;
            });
          } else if (label == "Total Return") {
            setState(() {
              widget.brokerageUser.displayValue = DisplayValue.totalReturn;
            });
          } else if (label == "Total Return %") {
            setState(() {
              widget.brokerageUser.displayValue =
                  DisplayValue.totalReturnPercent;
            });
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            PnlBadge(
                text: valueText,
                value: neutral ? null : value,
                neutral: neutral),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: summaryLabelFontSize,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      );
    }

    List<Widget> tiles = [
      buildTile("Return Today", todayReturnText ?? "", todayReturn),
      buildTile(
          "Return Today %", todayReturnPercentText ?? "", todayReturnPercent),
      buildTile("Total Return", totalReturnText ?? "", totalReturn),
      buildTile(
          "Total Return %", totalReturnPercentText ?? "", totalReturnPercent),
    ];
    if (volume != null) {
      tiles.add(buildTile("Volume", formatCompactNumber.format(volume), volume,
          neutral: true));
    }

    return SynchronizedDetailScrollRow(
      scrollGroup: _scrollGroup,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tiles,
      ),
    );
  }

  Widget _buildInteractiveTooltip(BuildContext context, dynamic selectedDatum) {
    if (selectedDatum == null) return const SizedBox.shrink();
    final datum = selectedDatum;
    final symbol = datum['domain'] as String? ?? '';
    final InstrumentPosition? position =
        datum['position'] as InstrumentPosition?;
    final String name = position?.instrumentObj?.simpleName ??
        position?.instrumentObj?.name ??
        '';
    final primaryLabel =
        datum['primaryLabel'] as String? ?? datum['label'] as String? ?? '';
    final secondaryLabel = datum['secondaryLabel'] as String?;
    final primaryName =
        BrokerageUser.displayValueText(widget.brokerageUser.displayValue!);

    DisplayValue? secondaryDisplayValue;
    if (widget.brokerageUser.displayValue == DisplayValue.marketValue) {
      secondaryDisplayValue = DisplayValue.totalCost;
    } else if (widget.brokerageUser.displayValue == DisplayValue.totalCost) {
      secondaryDisplayValue = DisplayValue.marketValue;
    } else if (widget.brokerageUser.displayValue == DisplayValue.totalReturn) {
      secondaryDisplayValue = DisplayValue.totalReturnPercent;
    } else if (widget.brokerageUser.displayValue ==
        DisplayValue.totalReturnPercent) {
      secondaryDisplayValue = DisplayValue.totalReturn;
    } else if (widget.brokerageUser.displayValue == DisplayValue.todayReturn) {
      secondaryDisplayValue = DisplayValue.todayReturnPercent;
    } else if (widget.brokerageUser.displayValue ==
        DisplayValue.todayReturnPercent) {
      secondaryDisplayValue = DisplayValue.todayReturn;
    }
    final secondaryName = secondaryDisplayValue != null
        ? BrokerageUser.displayValueText(secondaryDisplayValue)
        : '';

    final num? measureVal = datum['measure'] as num?;
    final isPositive = (measureVal ?? 0) >= 0;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  symbol,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Dismiss',
                onPressed: () {
                  _selectedPositionDatumNotifier.value = null;
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    primaryName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    primaryLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: (widget.brokerageUser.displayValue ==
                                  DisplayValue.totalReturn ||
                              widget.brokerageUser.displayValue ==
                                  DisplayValue.totalReturnPercent ||
                              widget.brokerageUser.displayValue ==
                                  DisplayValue.todayReturn ||
                              widget.brokerageUser.displayValue ==
                                  DisplayValue.todayReturnPercent)
                          ? (isPositive ? Colors.green : Colors.red)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              if (secondaryLabel != null && secondaryLabel.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      secondaryName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      secondaryLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: (secondaryDisplayValue ==
                                    DisplayValue.totalReturn ||
                                secondaryDisplayValue ==
                                    DisplayValue.totalReturnPercent ||
                                secondaryDisplayValue ==
                                    DisplayValue.todayReturn ||
                                secondaryDisplayValue ==
                                    DisplayValue.todayReturnPercent)
                            ? (isPositive ? Colors.green : Colors.red)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              if (position != null && position.quantity != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Shares',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      formatCompactNumber.format(position.quantity),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View Details'),
                onPressed: () {
                  if (position != null && position.instrumentObj != null) {
                    _handleNavigation(context, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InstrumentWidget(
                            widget.brokerageUser,
                            widget.service,
                            position.instrumentObj!,
                            heroTag:
                                'logo_${position.instrumentObj!.symbol}${position.instrumentObj!.id}',
                            analytics: widget.analytics,
                            observer: widget.observer,
                            generativeService: widget.generativeService,
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                          ),
                        ),
                      );
                    });
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartControls(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
      child: Align(
        alignment: Alignment.centerRight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outlineVariant
                    .withValues(alpha: 0.5),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToolbarButton(
                    context,
                    label: BrokerageUser.displayValueText(
                        widget.brokerageUser.displayValue!),
                    icon: Icons.bar_chart_rounded,
                    onTap: () {
                      showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          builder: (_) => MoreMenuBottomSheet(
                                  widget.brokerageUser,
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                  showOnlyPrimaryMeasure: true,
                                  onSettingsChanged: (value) {
                                setState(() {});
                              }));
                    },
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    indent: 8,
                    endIndent: 8,
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                  _buildToolbarButton(
                    context,
                    label: BrokerageUser.displayValueText(
                        widget.brokerageUser.sortOptions!),
                    icon:
                        widget.brokerageUser.sortDirection == SortDirection.desc
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                    onTap: () {
                      showModalBottomSheet<void>(
                          context: context,
                          showDragHandle: true,
                          builder: (_) => MoreMenuBottomSheet(
                                  widget.brokerageUser,
                                  analytics: widget.analytics,
                                  observer: widget.observer,
                                  showOnlySort: true,
                                  onSettingsChanged: (value) {
                                setState(() {});
                              }));
                    },
                    iconColor: Theme.of(context).colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarButton(BuildContext context,
      {required String label,
      required IconData icon,
      required VoidCallback onTap,
      Color? iconColor}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: iconColor ?? Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down,
                size: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

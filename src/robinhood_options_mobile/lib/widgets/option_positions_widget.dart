import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:collection/collection.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:robinhood_options_mobile/constants.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/widgets/ad_banner_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_bar_widget.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';
import 'package:robinhood_options_mobile/widgets/disclaimer_widget.dart';
import 'package:robinhood_options_mobile/widgets/instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/more_menu_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_instrument_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_positions_page_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_defense_playbook_widget.dart';
import 'package:robinhood_options_mobile/widgets/option_roll_assistant_widget.dart';
import 'package:robinhood_options_mobile/widgets/pnl_badge.dart';
import 'package:robinhood_options_mobile/widgets/animated_price_text.dart';
import 'package:robinhood_options_mobile/services/live_activity_service.dart';
import 'package:robinhood_options_mobile/widgets/option_live_activity_sheet.dart';
import 'package:robinhood_options_mobile/widgets/synchronized_scroll_controller.dart';
//import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

/*
final ItemScrollController itemScrollController = ItemScrollController();
final ItemPositionsListener itemPositionListener =
    ItemPositionsListener.create();
    */

class OptionPositionsWidget extends StatefulWidget {
  const OptionPositionsWidget(
    this.brokerageUser,
    this.service,
    //this.account,
    this.filteredOptionPositions, {
    this.showList = true,
    this.showGroupHeader = true,
    this.showFooter = true,
    this.disableNavigation = false,
    this.chartRowLimit,
    super.key,
    required this.analytics,
    required this.observer,
    required this.generativeService,
    required this.user,
    this.userDocRef,
  });

  final FirebaseAnalytics analytics;
  final FirebaseAnalyticsObserver observer;
  final BrokerageUser brokerageUser;
  final IBrokerageService service;
  final GenerativeService generativeService;
  final bool showList;
  final bool showGroupHeader;
  final bool showFooter;
  final bool disableNavigation;

  /// Caps how many bars the chart draws, so a summary card's height is bounded
  /// by the limit rather than by the position count. Null draws every row.
  ///
  /// Applies to whichever rows the chart is showing: contracts when a single
  /// underlying is held, underlyings otherwise.
  final int? chartRowLimit;
  //final Account account;
  final List<OptionAggregatePosition> filteredOptionPositions;
  final User? user;
  final DocumentReference<User>? userDocRef;

  @override
  State<OptionPositionsWidget> createState() => _OptionPositionsWidgetState();
}

class _OptionPositionsWidgetState extends State<OptionPositionsWidget> {
  final SynchronizedScrollControllerGroup _scrollGroup =
      SynchronizedScrollControllerGroup();
  final ValueNotifier<dynamic> _selectedOptionDatumNotifier =
      ValueNotifier<dynamic>(null);

  @override
  void dispose() {
    _selectedOptionDatumNotifier.dispose();
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
    var groupedOptionAggregatePositions = {};
    var contracts = 0;
    if (widget.filteredOptionPositions.isNotEmpty) {
      groupedOptionAggregatePositions = widget.filteredOptionPositions
          .groupListsBy((element) => element.symbol);
      contracts = widget.filteredOptionPositions
          .map((e) => e.quantity!.toInt())
          .reduce((a, b) => a + b);
    }

    List<dynamic> sortedGroupedOptionAggregatePositions =
        groupedOptionAggregatePositions.values.sortedBy<num>((i) =>
            widget.brokerageUser.getDisplayValueOptionAggregatePosition(i,
                displayValue: widget.brokerageUser.sortOptions)!);
    if (widget.brokerageUser.sortDirection == SortDirection.desc) {
      sortedGroupedOptionAggregatePositions =
          sortedGroupedOptionAggregatePositions.reversed.toList();
    }

    double? marketValue = widget.brokerageUser
        .getDisplayValueOptionAggregatePosition(widget.filteredOptionPositions,
            displayValue: DisplayValue.marketValue);

    GreekAggregates? greeks;
    if (widget.brokerageUser.showPositionDetails) {
      greeks = _calculateGreekAggregates(widget.filteredOptionPositions);
    }

    var brightness = MediaQuery.of(context).platformBrightness;

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

    var chartRowsOmitted = 0;
    if (groupedOptionAggregatePositions.length == 1) {
      final List<OptionAggregatePosition> legs =
          groupedOptionAggregatePositions.values.first;
      final chartLegs = _capForChart(legs);
      chartRowsOmitted = legs.length - chartLegs.length;
      for (var op in chartLegs) {
        double value = widget.brokerageUser.getDisplayValue(op);
        String trailingText = widget.brokerageUser.getDisplayText(value);
        double? secondaryValue;
        String? secondaryLabel;
        if (secondaryDisplayValue != null) {
          secondaryValue = widget.brokerageUser
              .getDisplayValue(op, displayValue: secondaryDisplayValue);
          secondaryLabel = widget.brokerageUser.getDisplayText(secondaryValue,
              displayValue: secondaryDisplayValue);
        }
        String combinedLabel = trailingText;
        if (secondaryLabel != null && secondaryLabel.isNotEmpty) {
          if (secondaryDisplayValue != DisplayValue.totalCost &&
              secondaryDisplayValue != DisplayValue.marketValue) {
            combinedLabel = '$trailingText ($secondaryLabel)';
          }
        }
        if (op.legs.isNotEmpty) {
          data.add({
            'domain':
                '${op.legs.first.expirationDate != null ? formatCompactDate.format(op.legs.first.expirationDate!) : ''} \$${op.legs.first.strikePrice != null ? formatCompactNumber.format(op.legs.first.strikePrice) : ''} ${op.legs.first.optionType}',
            'measure': value,
            'label': combinedLabel,
            'primaryLabel': trailingText,
            'secondaryMeasure': secondaryValue,
            'secondaryLabel': secondaryLabel,
            'op': op,
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
          id: BrokerageUser.displayValueText(
              widget.brokerageUser.displayValue!),
          data: data,
          seriesColor: shades[0],
          domainFn: (var d, _) => d['domain'],
          measureFn: (var d, _) => d['measure'],
          labelAccessorFn: (d, _) => d['label'],
          insideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
              fontSize: 13,
              color: charts.ColorUtil.fromDartColor(
                brightness == Brightness.light
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context).colorScheme.inverseSurface,
              )),
          outsideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
              fontSize: 13,
              color: charts.ColorUtil.fromDartColor(
                  Theme.of(context).textTheme.labelSmall!.color!))));
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
    } else if (groupedOptionAggregatePositions.length > 1) {
      final chartGroups = _capForChart(sortedGroupedOptionAggregatePositions);
      chartRowsOmitted =
          sortedGroupedOptionAggregatePositions.length - chartGroups.length;
      for (var position in chartGroups) {
        double? value = widget.brokerageUser
            .getDisplayValueOptionAggregatePosition(position);
        String trailingText =
            value != null ? widget.brokerageUser.getDisplayText(value) : '';
        double? secondaryValue;
        String? secondaryLabel;
        if (secondaryDisplayValue != null) {
          secondaryValue = widget.brokerageUser
              .getDisplayValueOptionAggregatePosition(position,
                  displayValue: secondaryDisplayValue);
          if (secondaryValue != null) {
            secondaryLabel = widget.brokerageUser.getDisplayText(secondaryValue,
                displayValue: secondaryDisplayValue);
          }
        }
        String combinedLabel = trailingText;
        if (secondaryLabel != null && secondaryLabel.isNotEmpty) {
          if (secondaryDisplayValue != DisplayValue.totalCost &&
              secondaryDisplayValue != DisplayValue.marketValue) {
            combinedLabel = '$trailingText ($secondaryLabel)';
          }
        }
        data.add({
          'domain': position.first.symbol,
          'measure': value != null && value.isNaN ? null : value,
          'label': combinedLabel,
          'primaryLabel': trailingText,
          'secondaryMeasure': secondaryValue,
          'secondaryLabel': secondaryLabel,
          'group': position,
        });
      }
      var shades = PieChart.makeShades(
          charts.ColorUtil.fromDartColor(
              Theme.of(context).brightness == Brightness.light
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.primaryContainer),
          2);
      barChartSeriesList.add(charts.Series<dynamic, String>(
          id: BrokerageUser.displayValueText(
              widget.brokerageUser.displayValue!),
          data: data,
          seriesColor: shades[0],
          domainFn: (var d, _) => d['domain'],
          measureFn: (var d, _) => d['measure'],
          labelAccessorFn: (d, _) => d['label'],
          insideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
              fontSize: 13,
              color: charts.ColorUtil.fromDartColor(
                brightness == Brightness.light
                    ? Theme.of(context).colorScheme.surface
                    : Theme.of(context).colorScheme.inverseSurface,
              )),
          outsideLabelStyleAccessorFn: (datum, index) => charts.TextStyleSpec(
              fontSize: 13,
              color: charts.ColorUtil.fromDartColor(
                  Theme.of(context).textTheme.labelSmall!.color!))));
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
    }

    var axisLabelColor = charts.MaterialPalette.gray.shade500;
    if (brightness == Brightness.light) {
      axisLabelColor = charts.MaterialPalette.gray.shade700;
    }

    final primaryNumericValues = data
        .map((d) => (d['measure'] as num?)?.toDouble())
        .whereType<double>()
        .toList();

    charts.NumericExtents primaryExtents;
    charts.NumericExtents? secondaryExtents;
    List<charts.TickSpec<num>>? secondaryTicks;

    if (isDualAxis) {
      final secondaryNumericValues = data
          .map((d) => (d['secondaryMeasure'] as num?)?.toDouble())
          .whereType<double>()
          .toList();
      final aligned = AlignedAxisExtents.compute(
        primaryValues: primaryNumericValues,
        secondaryValues: secondaryNumericValues,
      );
      primaryExtents = aligned.primaryExtents;
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
        final secondaryNumericValues = data
            .map((d) => (d['secondaryMeasure'] as num?)?.toDouble())
            .whereType<double>()
            .toList();
        primaryNumericValues.addAll(secondaryNumericValues);
      }
      primaryExtents = primaryNumericValues.isNotEmpty
          ? charts.NumericExtents.fromValues(primaryNumericValues)
          : const charts.NumericExtents(0, 1);
      double primaryPad =
          primaryExtents.width > 0 ? primaryExtents.width * 0.1 : 0.05;
      final bool startsAtZero =
          widget.brokerageUser.displayValue == DisplayValue.marketValue ||
          widget.brokerageUser.displayValue == DisplayValue.totalCost;
      final double minVal =
          startsAtZero ? 0.0 : primaryExtents.min - primaryPad;
      primaryExtents = charts.NumericExtents(
          minVal, primaryExtents.max + primaryPad);
    }

    var primaryMeasureAxis = widget.brokerageUser.displayValue ==
                DisplayValue.todayReturnPercent ||
            widget.brokerageUser.displayValue == DisplayValue.totalReturnPercent
        ? charts.PercentAxisSpec(
            viewport: primaryExtents,
            tickProviderSpec:
                const charts.BasicNumericTickProviderSpec(zeroBound: true),
            renderSpec: charts.GridlineRendererSpec(
                labelStyle: charts.TextStyleSpec(color: axisLabelColor)))
        : charts.NumericAxisSpec(
            viewport: primaryExtents,
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
          tickProviderSpec: charts.StaticNumericTickProviderSpec(secondaryTicks),
        );
      } else {
        secondaryMeasureAxis = charts.NumericAxisSpec(
          viewport: secondaryExtents,
          renderSpec: charts.SmallTickRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
          tickFormatterSpec:
              charts.BasicNumericTickFormatterSpec.fromNumberFormat(
                  NumberFormat.compactSimpleCurrency()),
          tickProviderSpec: charts.StaticNumericTickProviderSpec(secondaryTicks),
        );
      }
    }

    var optionChart = BarChart(barChartSeriesList,
        renderer: charts.BarRendererConfig(
            groupingType: charts.BarGroupingType.stacked,
            barRendererDecorator: charts.BarLabelDecorator<String>(),
            cornerStrategy: const charts.ConstCornerStrategy(10)),
        primaryMeasureAxis: primaryMeasureAxis,
        secondaryMeasureAxis:
            (barChartSeriesList.length > 1 && isDualAxis)
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
      _selectedOptionDatumNotifier.value = datum;
    });

    return SliverToBoxAdapter(
        child: ShrinkWrappingViewport(
      offset: ViewportOffset.zero(),
      slivers: [
        SliverToBoxAdapter(
            child: Column(
                //height: 208.0, //60.0,
                //padding: EdgeInsets.symmetric(horizontal: 16.0),
                //alignment: Alignment.centerLeft,
                children: [
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
                          Icons.account_balance_wallet_outlined,
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
                            Wrap(children: [
                              Text(
                                "Options",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold),
                              ),
                              if (!widget.showList) ...[
                                SizedBox(
                                  height: 28,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: () =>
                                        navigateToFullPage(context),
                                  ),
                                )
                              ]
                            ]),
                            Text(
                              "${formatCompactNumber.format(widget.filteredOptionPositions.length)} positions, ${formatCompactNumber.format(contracts)} contracts${groupedOptionAggregatePositions.length > 1 ? ", ${formatCompactNumber.format(groupedOptionAggregatePositions.length)} underlying" : ""}"
                              // Say so rather than letting the missing bars read as
                              // missing positions; the full page has all of them.
                              "${chartRowsOmitted > 0 ? ", charting top ${widget.chartRowLimit}" : ""}",
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
                          padding:
                              const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 8.0),
                          child: AnimatedPriceText(
                            price: marketValue ?? 0,
                            format: formatCurrency,
                            style:
                                const TextStyle(fontSize: assetValueFontSize),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                    widget.filteredOptionPositions,
                    greeks,
                    summaryValueFontSize,
                    summaryLabelFontSize,
                    iconSize: 27.0,
                  ),
                ),
              ),
            ]
                //)
                )),
        if (barChartSeriesList.isNotEmpty &&
            barChartSeriesList.first.data.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                    height: math.max(140.0,
                        barChartSeriesList.first.data.length * 28.0 + 80.0),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          10.0, 0, 10, 0), //EdgeInsets.zero
                      child: optionChart,
                    )),
                ValueListenableBuilder<dynamic>(
                  valueListenable: _selectedOptionDatumNotifier,
                  builder: (context, selectedDatum, child) {
                    if (selectedDatum == null) return const SizedBox.shrink();
                    return _buildInteractiveTooltip(context, selectedDatum);
                  },
                ),
                _buildChartControls(context),
              ],
            ),
          ),
        ],
        if (widget.showList) ...[
          widget.brokerageUser.optionsView == OptionsView.list
              ? SliverList(
                  // delegate: SliverChildListDelegate(widgets),
                  delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                    return _buildOptionPositionRow(
                        widget.filteredOptionPositions[index], context);
                  }, childCount: widget.filteredOptionPositions.length),
                )
              : /*ScrollablePositionedList.builder(
                itemCount: groupedOptionAggregatePositions.length,
                itemBuilder: (context, index) => Text('Item $index'),
                itemScrollController: itemScrollController,
                itemPositionsListener: itemPositionListener,
              )*/

              SliverList(
                  // delegate: SliverChildListDelegate(widgets),
                  delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                    return _buildOptionPositionSymbolRow(
                        sortedGroupedOptionAggregatePositions.elementAt(index),
                        context,
                        excludeGroupRow: !widget
                            .showGroupHeader); // Disabled this logic as it was not showing the option positions: sortedGroupedOptionAggregatePositions.length == 1
                  }, childCount: sortedGroupedOptionAggregatePositions.length),
                ),
          if (widget.showFooter) ...[
            // TODO: Introduce web banner
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
            ))
          ],
        ]
      ],
    ));
  }

  /// Trims chart rows to [OptionPositionsWidget.chartRowLimit].
  List<T> _capForChart<T>(List<T> rows) {
    final limit = widget.chartRowLimit;
    if (limit == null || rows.length <= limit) return rows;
    return rows.take(limit).toList();
  }

  /// Opens the full ledger.
  ///
  /// Deliberately not routed through [_handleNavigation]: reading the position
  /// list is not a trade action, and blocking it would leave aggregate users
  /// with no way to see holdings the summary chart caps off. The page carries
  /// [OptionPositionsWidget.disableNavigation] forward instead, so the
  /// trade-bearing rows inside it stay disabled.
  void navigateToFullPage(BuildContext pageContext) {
    Navigator.push(
        pageContext,
        MaterialPageRoute(
            builder: (context) => OptionPositionsPageWidget(
                  widget.brokerageUser,
                  widget.service,
                  widget.filteredOptionPositions,
                  analytics: widget.analytics,
                  observer: widget.observer,
                  generativeService: widget.generativeService,
                  user: widget.user,
                  userDocRef: widget.userDocRef,
                  disableNavigation: widget.disableNavigation,
                )));
  }

  GreekAggregates _calculateGreekAggregates(
      List<OptionAggregatePosition> filteredOptionPositions) {
    double deltaSum = 0;
    double gammaSum = 0;
    double thetaSum = 0;
    double vegaSum = 0;
    double rhoSum = 0;
    double ivSum = 0;
    double chanceSum = 0;
    double openInterestSum = 0;
    double volumeSum = 0;
    double marketValueSum = 0;

    for (var position in filteredOptionPositions) {
      double marketValue = position.marketValue;
      marketValueSum += marketValue;

      if (position.optionInstrument?.optionMarketData != null) {
        var data = position.optionInstrument!.optionMarketData!;
        deltaSum += (data.delta ?? 0) * marketValue;
        gammaSum += (data.gamma ?? 0) * marketValue;
        thetaSum += (data.theta ?? 0) * marketValue;
        vegaSum += (data.vega ?? 0) * marketValue;
        rhoSum += (data.rho ?? 0) * marketValue;
        ivSum += (data.impliedVolatility ?? 0) * marketValue;
        openInterestSum += data.openInterest * marketValue;
        volumeSum += data.volume * marketValue;

        if (position.direction == 'debit') {
          chanceSum += (data.chanceOfProfitLong ?? 0) * marketValue;
        } else {
          chanceSum += (data.chanceOfProfitShort ?? 0) * marketValue;
        }
      }
    }

    if (marketValueSum == 0) {
      return GreekAggregates();
    }

    return GreekAggregates(
      delta: deltaSum / marketValueSum,
      gamma: gammaSum / marketValueSum,
      theta: thetaSum / marketValueSum,
      vega: vegaSum / marketValueSum,
      rho: rhoSum / marketValueSum,
      iv: ivSum / marketValueSum,
      chance: chanceSum / marketValueSum,
      openInterest: openInterestSum / marketValueSum,
      volume: volumeSum / marketValueSum,
    );
  }

  Widget _buildOptionPositionRow(
      OptionAggregatePosition op, BuildContext context) {
    double value = widget.brokerageUser
        .getDisplayValue(op, displayValue: DisplayValue.marketValue);
    String opTrailingText = widget.brokerageUser
        .getDisplayText(value, displayValue: DisplayValue.marketValue);
    Icon? icon = (widget.brokerageUser.showPositionDetails ||
            widget.brokerageUser.displayValue == DisplayValue.lastPrice ||
            widget.brokerageUser.displayValue == DisplayValue.marketValue)
        ? null
        : widget.brokerageUser.getDisplayIcon(value, size: 31);

    return Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Hero(
                  tag: 'logo_${op.symbol}${op.id}',
                  child: op.logoUrl != null
                      ? CircleAvatar(
                          radius: 25,
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Image.network(
                            op.logoUrl!,
                            width: 32,
                            height: 32,
                            errorBuilder: (BuildContext context,
                                Object exception, StackTrace? stackTrace) {
                              return Text(
                                op.symbol,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: const TextStyle(fontSize: 11),
                              );
                            },
                          ),
                        )
                      : CircleAvatar(
                          radius: 25,
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          child: Text(
                            op.symbol,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: const TextStyle(fontSize: 11),
                          ))),
              title: RichText(
                text: TextSpan(
                  style:
                      DefaultTextStyle.of(context).style.copyWith(fontSize: 16),
                  children: [
                    TextSpan(
                        text: '${op.symbol} ',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (op.legs.isNotEmpty) ...[
                      TextSpan(
                          text:
                              '\$${formatCompactNumber.format(op.legs.first.strikePrice)} '),
                      TextSpan(
                          text: '${op.legs.first.optionType} ',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                      TextSpan(
                          text: 'x ${formatCompactNumber.format(op.quantity!)}',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline)),
                    ],
                  ],
                ),
              ),
              subtitle: Row(
                children: [
                  Text(
                    '${op.legs.isNotEmpty ? op.legs.first.expirationDate!.compareTo(DateTime.now()) < 0 ? "Expired" : "Expires" : ''} ${op.legs.isNotEmpty ? formatDate.format(op.legs.first.expirationDate!) : ''}',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  if (LiveActivityService.instance.isPositionTracked(op.id)) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.sensors,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
              trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (icon != null) ...[
                      icon,
                    ],
                    Text(
                      opTrailingText,
                      style: const TextStyle(
                          fontSize: summaryValueFontSize,
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.right,
                    )
                  ]),
              onTap: () {
                _handleNavigation(context, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => OptionInstrumentWidget(
                                widget.brokerageUser,
                                widget.service,
                                op.optionInstrument!,
                                optionPosition: op,
                                heroTag: 'logo_${op.symbol}${op.id}',
                                analytics: widget.analytics,
                                observer: widget.observer,
                                generativeService: widget.generativeService,
                                user: widget.user,
                                userDocRef: widget.userDocRef,
                              )));
                });
              },
              onLongPress: op.optionInstrument != null && op.instrumentObj != null
                  ? () {
                      showModalBottomSheet(
                        context: context,
                        builder: (sheetContext) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.shield_outlined),
                                title: const Text('Defense Playbook'),
                                subtitle: const Text(
                                    'Threat analysis and tactical defense maneuvers'),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _handleNavigation(context, () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            OptionDefensePlaybookWidget(
                                          user: widget.brokerageUser,
                                          service: widget.service,
                                          instrument: op.instrumentObj!,
                                          optionPosition: op,
                                          optionInstrument: op.optionInstrument!,
                                          analytics: widget.analytics,
                                          observer: widget.observer,
                                          generativeService:
                                              widget.generativeService,
                                          appUser: widget.user,
                                          userDocRef: widget.userDocRef,
                                          initialIsPaperTrade:
                                              widget.brokerageUser.source ==
                                                  BrokerageSource.paper,
                                        ),
                                      ),
                                    );
                                  });
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.sync_alt),
                                title: const Text('Roll Assistant'),
                                subtitle: const Text(
                                    '1-tap roll wizard for credit, strikes, and DTE extension'),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _handleNavigation(context, () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            OptionRollAssistantWidget(
                                          user: widget.brokerageUser,
                                          service: widget.service,
                                          instrument: op.instrumentObj!,
                                          optionPosition: op,
                                          optionInstrument: op.optionInstrument!,
                                          analytics: widget.analytics,
                                          observer: widget.observer,
                                          generativeService:
                                              widget.generativeService,
                                          appUser: widget.user,
                                          userDocRef: widget.userDocRef,
                                          initialIsPaperTrade:
                                              widget.brokerageUser.source ==
                                                  BrokerageSource.paper,
                                        ),
                                      ),
                                    );
                                  });
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.sensors),
                                title: const Text('Live Activity & Dynamic Island'),
                                subtitle: const Text(
                                    'Real-time lock screen position tracking & 0DTE trailing stop'),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  showModalBottomSheet(
                                    context: context,
                                    showDragHandle: true,
                                    isScrollControlled: true,
                                    builder: (context) =>
                                        OptionLiveActivitySheet(
                                      position: op,
                                      onSessionChanged: () {
                                        setState(() {});
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  : null,
            ),
            if (widget.brokerageUser.showPositionDetails) ...[
              _buildDetailScrollRow(
                  [op],
                  op.optionInstrument?.optionMarketData != null
                      ? GreekAggregates(
                          delta: op.optionInstrument!.optionMarketData!.delta,
                          gamma: op.optionInstrument!.optionMarketData!.gamma,
                          theta: op.optionInstrument!.optionMarketData!.theta,
                          vega: op.optionInstrument!.optionMarketData!.vega,
                          rho: op.optionInstrument!.optionMarketData!.rho,
                          iv: op.optionInstrument!.optionMarketData!
                              .impliedVolatility,
                          chance: op.direction == 'debit'
                              ? op.optionInstrument!.optionMarketData!
                                  .chanceOfProfitLong
                              : op.optionInstrument!.optionMarketData!
                                  .chanceOfProfitShort,
                          openInterest: op
                              .optionInstrument!.optionMarketData!.openInterest
                              .toDouble(),
                          volume: op.optionInstrument!.optionMarketData!.volume
                              .toDouble(),
                        )
                      : null,
                  greekValueFontSize,
                  greekLabelFontSize,
                  clickable: false)
            ]
          ],
        ));
  }

  Widget _buildDetailScrollRow(List<OptionAggregatePosition> ops,
      GreekAggregates? greeks, double valueFontSize, double labelFontSize,
      {double iconSize = 23.0, bool clickable = true}) {
    /*
    double? marketValue = user.getAggregateDisplayValue(ops,
        displayValue: DisplayValue.marketValue);
    String? marketValueText = user.getDisplayText(marketValue!,
        displayValue: DisplayValue.marketValue);
        */

    double? totalReturn = widget.brokerageUser
        .getDisplayValueOptionAggregatePosition(ops,
            displayValue: DisplayValue.totalReturn);
    String? totalReturnText = widget.brokerageUser
        .getDisplayText(totalReturn!, displayValue: DisplayValue.totalReturn);

    double? totalReturnPercent = widget.brokerageUser
        .getDisplayValueOptionAggregatePosition(ops,
            displayValue: DisplayValue.totalReturnPercent);
    String? totalReturnPercentText = widget.brokerageUser.getDisplayText(
        totalReturnPercent!,
        displayValue: DisplayValue.totalReturnPercent);

    double? todayReturn = widget.brokerageUser
        .getDisplayValueOptionAggregatePosition(ops,
            displayValue: DisplayValue.todayReturn);
    String? todayReturnText = widget.brokerageUser
        .getDisplayText(todayReturn!, displayValue: DisplayValue.todayReturn);

    double? todayReturnPercent = widget.brokerageUser
        .getDisplayValueOptionAggregatePosition(ops,
            displayValue: DisplayValue.todayReturnPercent);
    String? todayReturnPercentText = widget.brokerageUser.getDisplayText(
        todayReturnPercent!,
        displayValue: DisplayValue.todayReturnPercent);

    Widget buildTile(String label, String valueText, double? value,
        {bool neutral = false, bool clickable = true}) {
      return InkWell(
        onTap: clickable
            ? () {
                if (label == "Return Today") {
                  setState(() {
                    widget.brokerageUser.displayValue =
                        DisplayValue.todayReturn;
                  });
                } else if (label == "Return Today %") {
                  setState(() {
                    widget.brokerageUser.displayValue =
                        DisplayValue.todayReturnPercent;
                  });
                } else if (label == "Total Return") {
                  setState(() {
                    widget.brokerageUser.displayValue =
                        DisplayValue.totalReturn;
                  });
                } else if (label == "Total Return %") {
                  setState(() {
                    widget.brokerageUser.displayValue =
                        DisplayValue.totalReturnPercent;
                  });
                }
              }
            : null,
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
                    fontSize: labelFontSize,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
        ),
      );
    }

    List<Widget> tiles = [
      buildTile("Return Today", todayReturnText, todayReturn,
          clickable: clickable),
      buildTile("Return Today %", todayReturnPercentText, todayReturnPercent,
          clickable: clickable),
      buildTile("Total Return", totalReturnText, totalReturn,
          clickable: clickable),
      buildTile("Total Return %", totalReturnPercentText, totalReturnPercent,
          clickable: clickable),
    ];

    if (greeks != null) {
      if (greeks.delta != null) {
        tiles.add(buildTile(
            "Delta Δ", formatNumber.format(greeks.delta), greeks.delta,
            neutral: true));
      }
      if (greeks.gamma != null) {
        tiles.add(buildTile(
            "Gamma Γ", formatNumber.format(greeks.gamma), greeks.gamma,
            neutral: true));
      }
      if (greeks.theta != null) {
        tiles.add(buildTile(
            "Theta Θ", formatNumber.format(greeks.theta), greeks.theta,
            neutral: true));
      }
      if (greeks.vega != null) {
        tiles.add(buildTile(
            "Vega v", formatNumber.format(greeks.vega), greeks.vega,
            neutral: true));
      }
      if (greeks.rho != null) {
        tiles.add(buildTile(
            "Rho p", formatNumber.format(greeks.rho), greeks.rho,
            neutral: true));
      }
      if (greeks.iv != null) {
        tiles.add(buildTile(
            "Impl. Vol.", formatPercentage.format(greeks.iv), greeks.iv,
            neutral: true));
      }
      if (greeks.chance != null) {
        tiles.add(buildTile(
            "Chance", formatPercentage.format(greeks.chance), greeks.chance,
            neutral: true));
      }
      if (greeks.openInterest != null) {
        tiles.add(buildTile(
            "Open Interest",
            formatCompactNumber.format(greeks.openInterest),
            greeks.openInterest,
            neutral: true));
      }
      if (greeks.volume != null) {
        tiles.add(buildTile(
            "Volume", formatCompactNumber.format(greeks.volume), greeks.volume,
            neutral: true));
      }
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

  Widget _buildOptionPositionSymbolRow(
      List<OptionAggregatePosition> ops, BuildContext context,
      {bool excludeGroupRow = false}) {
    var contracts = ops.map((e) => e.quantity!.toInt()).reduce((a, b) => a + b);
    // var filteredOptionReturn = ops.map((e) => e.gainLoss).reduce((a, b) => a + b);

    List<Widget> cards = [];

    double? value = widget.brokerageUser.getDisplayValueOptionAggregatePosition(
        ops,
        displayValue: DisplayValue.marketValue);
    String? trailingText;
    Icon? icon;
    if (value != null) {
      trailingText = widget.brokerageUser
          .getDisplayText(value, displayValue: DisplayValue.marketValue);
      icon = (widget.brokerageUser.showPositionDetails ||
              widget.brokerageUser.displayValue == DisplayValue.lastPrice ||
              widget.brokerageUser.displayValue == DisplayValue.marketValue)
          ? null
          : widget.brokerageUser.getDisplayIcon(value, size: 31);
    }

    GreekAggregates? greeks;
    if (widget.brokerageUser.showPositionDetails) {
      greeks = _calculateGreekAggregates(ops);
    }

    if (!excludeGroupRow) {
      cards.add(Column(children: [
        ListTile(
          leading: Hero(
              tag: 'logo_${ops.first.symbol}',
              child: ops.first.logoUrl != null
                  ? Image.network(
                      ops.first.logoUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.contain,
                      errorBuilder: (BuildContext context, Object exception,
                          StackTrace? stackTrace) {
                        return CircleAvatar(
                            radius: 25,
                            // backgroundColor: Colors.transparent,
                            // foregroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(ops.first.symbol));
                      },
                    )
                  : CircleAvatar(
                      radius: 25,
                      // foregroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        ops.first.symbol,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                      ))),
          // title: Text(ops.first.symbol),
          title: Text(ops.first.instrumentObj != null
              ? ops.first.instrumentObj!.simpleName ??
                  ops.first.instrumentObj!.name
              : ops.first.symbol),
          subtitle: Text("${ops.length} positions, $contracts contracts"),
          trailing: Wrap(spacing: 8, children: [
            if (icon != null) ...[
              icon,
            ],
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: const TextStyle(fontSize: positionValueFontSize),
                textAlign: TextAlign.right,
              )
            ]
          ]),
          onTap: () async {
            /*
                _navKey.currentState!.push(
                  MaterialPageRoute(
                    builder: (_) => SubSecondPage(),
                  ),
                );
                */
            /*
            var instrument = await widget.service.getInstrumentBySymbol(
                user, ops.first.symbol);
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        InstrumentWidget(user, account, instrument!)));
                        */
            _handleNavigation(context, () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => InstrumentWidget(
                            widget.brokerageUser,
                            widget.service,
                            ops.first.instrumentObj!,
                            analytics: widget.analytics,
                            observer: widget.observer,
                            generativeService: widget.generativeService,
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                          )));
            });
            // Refresh in case settings were updated.
            //futureFromInstrument.then((value) => setState(() {}));
          },
        ),
        if (widget.brokerageUser.showPositionDetails && ops.length > 1) ...[
          _buildDetailScrollRow(
              ops, greeks, summaryValueFontSize, summaryLabelFontSize,
              iconSize: 27.0, clickable: false)
        ]
      ]));
      /*
      cards.add(
        const Divider(
          height: 10,
          color: Colors.transparent,
        ),
      );
      */
    }
    for (OptionAggregatePosition op in ops) {
      double value = widget.brokerageUser
          .getDisplayValue(op, displayValue: DisplayValue.marketValue);
      String trailingText = widget.brokerageUser
          .getDisplayText(value, displayValue: DisplayValue.marketValue);
      Icon? icon = (widget.brokerageUser.showPositionDetails ||
              widget.brokerageUser.displayValue == DisplayValue.lastPrice ||
              widget.brokerageUser.displayValue == DisplayValue.marketValue)
          ? null
          : widget.brokerageUser.getDisplayIcon(value, size: 31);

      cards.add(
          //Card(child:
          Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            title: Text(
                '\$${op.legs.isNotEmpty && op.legs.first.strikePrice != null ? formatCompactNumber.format(op.legs.first.strikePrice) : ""} ${op.legs.isNotEmpty && op.legs.first.optionType != '' ? op.legs.first.optionType.capitalize() : ""} ${op.legs.isNotEmpty ? (op.legs.first.positionType == 'long' ? '+' : '-') : ""}${formatCompactNumber.format(op.quantity!)}'),
            subtitle: Text(
                '${op.legs.isNotEmpty && op.legs.first.expirationDate != null ? op.legs.first.expirationDate!.compareTo(DateTime.now()) < 0 ? "Expired" : "Expires" : ""} ${op.legs.isNotEmpty && op.legs.first.expirationDate != null ? formatDate.format(op.legs.first.expirationDate!) : ""}'),
            trailing: Wrap(spacing: 8, children: [
              if (icon != null) ...[
                icon,
              ],
              Text(
                trailingText,
                style: const TextStyle(fontSize: summaryValueFontSize),
                textAlign: TextAlign.right,
              )
            ]),

            /*Wrap(
            spacing: 12,
            children: [
              Column(children: [
                Text(
                  "${formatCurrency.format(gainLoss)}\n${formatPercentage.format(gainLossPercent)}",
                  style: const TextStyle(fontSize: 15.0),
                  textAlign: TextAlign.right,
                ),
                Icon(
                    gainLossPerContract > 0
                        ? Icons.trending_up
                        : (gainLossPerContract < 0
                            ? Icons.trending_down
                            : Icons.trending_flat),
                    color: (gainLossPerContract > 0
                        ? Colors.green
                        : (gainLossPerContract < 0 ? Colors.red : Colors.grey)))
              ]),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "${formatCurrency.format(marketValue)}",
                    style: const TextStyle(fontSize: 18.0),
                    textAlign: TextAlign.right,
                  ),
                ],
              )
            ],
          ),*/
            //isThreeLine: true,
            onTap: () {
              /* For navigation within this tab, uncomment
            widget.navigatorKey!.currentState!.push(MaterialPageRoute(
                builder: (context) => OptionInstrumentWidget(
                    ru, accounts!.first, op.optionInstrument!,
                    optionPosition: op)));
                    */
              _handleNavigation(context, () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => OptionInstrumentWidget(
                              widget.brokerageUser,
                              widget.service,
                              op.optionInstrument!,
                              optionPosition: op,
                              analytics: widget.analytics,
                              observer: widget.observer,
                              generativeService: widget.generativeService,
                              user: widget.user,
                              userDocRef: widget.userDocRef,
                            )));
              });
            },
          ),
          if (widget.brokerageUser.showPositionDetails &&
              op.optionInstrument != null &&
              op.optionInstrument!.optionMarketData != null) ...[
            _buildDetailScrollRow(
                [op],
                GreekAggregates(
                  delta: op.optionInstrument!.optionMarketData!.delta,
                  gamma: op.optionInstrument!.optionMarketData!.gamma,
                  theta: op.optionInstrument!.optionMarketData!.theta,
                  vega: op.optionInstrument!.optionMarketData!.vega,
                  rho: op.optionInstrument!.optionMarketData!.rho,
                  iv: op.optionInstrument!.optionMarketData!.impliedVolatility,
                  chance: op.direction == 'debit'
                      ? op.optionInstrument!.optionMarketData!
                          .chanceOfProfitLong
                      : op.optionInstrument!.optionMarketData!
                          .chanceOfProfitShort,
                  openInterest: op
                      .optionInstrument!.optionMarketData!.openInterest
                      .toDouble(),
                  volume:
                      op.optionInstrument!.optionMarketData!.volume.toDouble(),
                ),
                greekValueFontSize,
                greekLabelFontSize,
                clickable: false),
            /*
            const Divider(
              height: 10,
              color: Colors.transparent,
            ),
            */
          ],
        ],
      ));
    }
    return Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: cards,
        ));
  }

  Widget _buildInteractiveTooltip(
      BuildContext context, dynamic selectedDatum) {
    if (selectedDatum == null) return const SizedBox.shrink();
    final datum = selectedDatum;
    final symbol = datum['domain'] as String? ?? '';
    final OptionAggregatePosition? op = datum['op'] as OptionAggregatePosition?;
    final List<OptionAggregatePosition>? group =
        datum['group'] as List<OptionAggregatePosition>?;

    final primaryLabel = datum['primaryLabel'] as String? ??
        datum['label'] as String? ??
        '';
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
                  op != null ? op.symbol : symbol,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (op != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    symbol,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else if (group != null && group.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${group.length} contract types',
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
                  _selectedOptionDatumNotifier.value = null;
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
              if (op != null && op.quantity != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Contracts',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      formatCompactNumber.format(op.quantity),
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
                  if (op != null) {
                    _handleNavigation(context, () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OptionInstrumentWidget(
                            widget.brokerageUser,
                            widget.service,
                            op.optionInstrument!,
                            optionPosition: op,
                            analytics: widget.analytics,
                            observer: widget.observer,
                            generativeService: widget.generativeService,
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                          ),
                        ),
                      );
                    });
                  } else if (group != null && group.isNotEmpty) {
                    final targetOp = group.first;
                    if (targetOp.instrumentObj != null) {
                      _handleNavigation(context, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InstrumentWidget(
                              widget.brokerageUser,
                              widget.service,
                              targetOp.instrumentObj!,
                              heroTag:
                                  'logo_${targetOp.symbol}${targetOp.instrumentObj!.id}',
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
                    icon: widget.brokerageUser.sortDirection ==
                            SortDirection.desc
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

class GreekAggregates {
  final double? delta;
  final double? gamma;
  final double? theta;
  final double? vega;
  final double? rho;
  final double? iv;
  final double? chance;
  final double? openInterest;
  final double? volume;

  GreekAggregates({
    this.delta,
    this.gamma,
    this.theta,
    this.vega,
    this.rho,
    this.iv,
    this.chance,
    this.openInterest,
    this.volume,
  });
}

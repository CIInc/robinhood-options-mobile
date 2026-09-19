import 'dart:math' as math;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;

import 'package:flutter/material.dart';

class AlignedAxisExtents {
  final charts.NumericExtents primaryExtents;
  final charts.NumericExtents secondaryExtents;
  final double zeroFraction;

  const AlignedAxisExtents({
    required this.primaryExtents,
    required this.secondaryExtents,
    required this.zeroFraction,
  });

  /// Computes viewports for primary and secondary axes such that the 0 point on both
  /// axes aligns at the exact same horizontal position (fraction) across the chart.
  static AlignedAxisExtents compute({
    required Iterable<num?> primaryValues,
    required Iterable<num?> secondaryValues,
    bool primaryStartsAtZero = false,
  }) {
    final pVals = primaryValues
        .map((v) => v?.toDouble())
        .where((v) => v != null && !v.isNaN && !v.isInfinite)
        .cast<double>()
        .toList();
    final sVals = secondaryValues
        .map((v) => v?.toDouble())
        .where((v) => v != null && !v.isNaN && !v.isInfinite)
        .cast<double>()
        .toList();

    if (pVals.isEmpty && sVals.isEmpty) {
      return const AlignedAxisExtents(
        primaryExtents: charts.NumericExtents(-1.0, 1.0),
        secondaryExtents: charts.NumericExtents(-1.0, 1.0),
        zeroFraction: 0.5,
      );
    }

    final pMin = pVals.isNotEmpty ? pVals.reduce(math.min) : 0.0;
    final pMax = pVals.isNotEmpty ? pVals.reduce(math.max) : 1.0;
    final sMin = sVals.isNotEmpty ? sVals.reduce(math.min) : 0.0;
    final sMax = sVals.isNotEmpty ? sVals.reduce(math.max) : 1.0;

    double pNeg = math.max(0.0, -pMin);
    double pPos = math.max(0.0, pMax);
    double sNeg = math.max(0.0, -sMin);
    double sPos = math.max(0.0, sMax);

    if (primaryStartsAtZero) {
      pNeg = 0.0;
    }

    final pPad = math.max(math.max(pNeg, pPos) * 0.1, 5.0);
    final sPad = math.max(math.max(sNeg, sPos) * 0.1, 0.05);

    double pReqNeg = pNeg > 0 ? pNeg + pPad : 0.0;
    double pReqPos = pPos > 0 ? pPos + pPad : 0.0;
    double sReqNeg = sNeg > 0 ? sNeg + sPad : 0.0;
    double sReqPos = sPos > 0 ? sPos + sPad : 0.0;

    if (pReqNeg == 0.0 && pReqPos == 0.0) {
      pReqPos = pPad;
    }
    if (sReqNeg == 0.0 && sReqPos == 0.0) {
      sReqPos = sPad;
    }

    // Both all non-negative
    if (pReqNeg == 0.0 && sReqNeg == 0.0) {
      return AlignedAxisExtents(
        primaryExtents: charts.NumericExtents(0.0, pReqPos),
        secondaryExtents: charts.NumericExtents(0.0, sReqPos),
        zeroFraction: 0.0,
      );
    }

    // Both all non-positive
    if (pReqPos == 0.0 && sReqPos == 0.0) {
      return AlignedAxisExtents(
        primaryExtents: charts.NumericExtents(-pReqNeg, 0.0),
        secondaryExtents: charts.NumericExtents(-sReqNeg, 0.0),
        zeroFraction: 1.0,
      );
    }

    // Mixed positive and negative across axes
    if (pReqNeg == 0.0) pReqNeg = pReqPos * 0.05;
    if (pReqPos == 0.0) pReqPos = pReqNeg * 0.05;
    if (sReqNeg == 0.0) sReqNeg = sReqPos * 0.05;
    if (sReqPos == 0.0) sReqPos = sReqNeg * 0.05;

    final fP = pReqNeg / (pReqNeg + pReqPos);
    final fS = sReqNeg / (sReqNeg + sReqPos);
    final t0 = math.max(fP, fS).clamp(0.05, 0.95);

    final pSpan = math.max(pReqNeg / t0, pReqPos / (1.0 - t0));
    final sSpan = math.max(sReqNeg / t0, sReqPos / (1.0 - t0));

    return AlignedAxisExtents(
      primaryExtents: charts.NumericExtents(-t0 * pSpan, (1.0 - t0) * pSpan),
      secondaryExtents: charts.NumericExtents(-t0 * sSpan, (1.0 - t0) * sSpan),
      zeroFraction: t0,
    );
  }
}

class BarChart extends StatefulWidget {
  final List<charts.Series<dynamic, String>> seriesList;
  final bool animate;
  final bool vertical;
  final charts.BarGroupingType? barGroupingType;
  final charts.BarRendererConfig<String>? renderer;
  final List<charts.SeriesRendererConfig<String>>? customSeriesRenderers;
  final List<charts.ChartBehavior<String>>? behaviors;
  final charts.AxisSpec<dynamic>? domainAxis;
  final charts.NumericAxisSpec? primaryMeasureAxis;
  final charts.NumericAxisSpec? secondaryMeasureAxis;
  //final List<charts.TickSpec<num>>? staticNumericTicks;
  final List<String>? hiddenSeries;
  final void Function(dynamic) onSelected;

  const BarChart(this.seriesList,
      {super.key,
      this.animate = true,
      this.vertical = false,
      this.barGroupingType = charts.BarGroupingType.grouped,
      this.renderer,
      this.customSeriesRenderers,
      this.behaviors,
      this.domainAxis,
      this.primaryMeasureAxis,
      this.secondaryMeasureAxis,
      required this.onSelected,
      //this.staticNumericTicks,
      this.hiddenSeries});

  // We need a Stateful widget to build the selection details with the current
  // selection as the state.
  @override
  State<StatefulWidget> createState() => BarChartState();
}

class BarChartState extends State<BarChart> {
  bool _hasRendered = false;

  @override
  void didUpdateWidget(BarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.seriesList.isEmpty || widget.seriesList.isEmpty) {
      _hasRendered = false;
    } else if (oldWidget.seriesList.first.id != widget.seriesList.first.id ||
        oldWidget.seriesList.first.data.length !=
            widget.seriesList.first.data.length) {
      _hasRendered = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shouldAnimate = widget.animate && !_hasRendered;
    _hasRendered = true;
    return charts.BarChart(
      widget.seriesList,
      defaultRenderer: widget.renderer,
      animate: shouldAnimate,
      vertical: widget.vertical,
      barGroupingType: widget.barGroupingType,
      //barRendererDecorator: charts.BarLabelDecorator<String>(),
      primaryMeasureAxis: widget.primaryMeasureAxis,
      secondaryMeasureAxis: widget.secondaryMeasureAxis,
      domainAxis: widget.domainAxis,
      customSeriesRenderers: widget.customSeriesRenderers ?? [],
      selectionModels: [
        charts.SelectionModelConfig(
            type: charts.SelectionModelType.info,
            changedListener: _onSelectionChanged)
      ],
      behaviors: widget.behaviors ??
          [
            // charts.SelectNearest(eventTrigger: charts.SelectionTrigger.tap),
            // charts.LinePointHighlighter(
            //     showHorizontalFollowLine:
            //         charts.LinePointHighlighterFollowLineType.none,
            //     showVerticalFollowLine:
            //         charts.LinePointHighlighterFollowLineType.nearest,
            //     dashPattern: const []),
            //charts.InitialSelection(selectedDataConfig: [
            //  charts.SeriesDatumConfig<DateTime>(
            //      'Adjusted Equity', widget.closeDate)
            //]),
            // charts.SeriesLegend(),
          ],
    );
  }

  void _onSelectionChanged(charts.SelectionModel model) {
    if (model.hasDatumSelection) {
      var selected = model.selectedDatum[0].datum;
      widget.onSelected(selected);
    } else {
      widget.onSelected(null);
    }
  }
}

//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;

import 'package:flutter/material.dart';

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
  @override
  Widget build(BuildContext context) {
    return charts.BarChart(
      widget.seriesList,
      defaultRenderer: widget.renderer,
      animate: widget.animate,
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

/// Example of a stacked area chart.
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';

class BarChart extends StatefulWidget {
  final List<charts.Series<dynamic, String>> seriesList;
  final bool animate;
  final bool vertical;
  final charts.BarGroupingType? barGroupingType;
  final String? customRendererId;
  final charts.BarRendererConfig<String>? renderer;
  final charts.AxisSpec<dynamic>? domainAxis;
  final charts.NumericAxisSpec? primaryMeasureAxis;
  //final List<charts.TickSpec<num>>? staticNumericTicks;
  final List<String>? hiddenSeries;
  final void Function(dynamic) onSelected;

  const BarChart(this.seriesList,
      {Key? key,
      this.animate = true,
      this.vertical = false,
      this.barGroupingType = charts.BarGroupingType.grouped,
      this.renderer,
      this.domainAxis,
      this.primaryMeasureAxis,
      this.customRendererId,
      required this.onSelected,
      //this.staticNumericTicks,
      this.hiddenSeries})
      : super(key: key);

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
      domainAxis: widget.domainAxis,
      customSeriesRenderers: [
        if (widget.customRendererId != null) ...[
          charts.BarTargetLineRendererConfig<String>(
              //overDrawOuterPx: 10,
              //overDrawPx: 10,
              strokeWidthPx: 5,
              customRendererId: widget.customRendererId,
              groupingType: charts.BarGroupingType.grouped)
        ]
      ],
      /*
      selectionModels: [
        charts.SelectionModelConfig(
            type: charts.SelectionModelType.info,
            changedListener: _onSelectionChanged)
      ],
      behaviors: [
        charts.SelectNearest(
            eventTrigger: charts.SelectionTrigger.tapAndDrag,
            selectAcrossAllDrawAreaComponents: true),
        charts.LinePointHighlighter(
            showHorizontalFollowLine:
                charts.LinePointHighlighterFollowLineType.none,
            showVerticalFollowLine:
                charts.LinePointHighlighterFollowLineType.nearest,
            dashPattern: const []),
        //charts.InitialSelection(selectedDataConfig: [
        //  charts.SeriesDatumConfig<DateTime>(
        //      'Adjusted Equity', widget.closeDate)
        //]),
        charts.SeriesLegend(
          position: charts.BehaviorPosition.top,
          defaultHiddenSeries: widget.hiddenSeries,
        ),
        if (widget.open != null && widget.close != null) ...[
          charts.RangeAnnotation([
            charts.RangeAnnotationSegment(
                widget.open! <= widget.close! ? widget.open! : widget.close!,
                widget.open! <= widget.close! ? widget.close! : widget.open!,
                charts.RangeAnnotationAxisType.measure,
                startLabel: widget.open! <= widget.close! ? 'Open' : 'Close',
                endLabel: widget.open! <= widget.close! ? 'Close' : 'Open',
                color: rangeAnnotationColor // gray.shade200
                ),
          ])
        ]
      ],
      */
    );
  }

  /*
  _onSelectionChanged(charts.SelectionModel model) {
    if (model.hasDatumSelection) {
      var selected = model.selectedDatum[0].datum;
      widget.onSelected(selected);
    } else {
      widget.onSelected(null);
    }
  }
  */
}

/// Example of a stacked area chart.
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';

class TimeSeriesChart extends StatefulWidget {
  final List<charts.Series<dynamic, DateTime>> seriesList;
  final bool animate;
  final double? open;
  final double? close;
  final List<String>? hiddenSeries;
  final void Function(dynamic) onSelected;

  const TimeSeriesChart(this.seriesList,
      {Key? key,
      this.animate = true,
      required this.onSelected,
      this.open,
      this.close,
      this.hiddenSeries})
      : super(key: key);

  // We need a Stateful widget to build the selection details with the current
  // selection as the state.
  @override
  State<StatefulWidget> createState() => _TimeSeriesChartState();
}

class _TimeSeriesChartState extends State<TimeSeriesChart> {
  @override
  Widget build(BuildContext context) {
    var brightness = MediaQuery.of(context).platformBrightness;
    var rangeAnnotationColor = charts.MaterialPalette.gray.shade800;
    var axisLabelColor = charts.MaterialPalette.gray.shade500;
    if (brightness == Brightness.light) {
      rangeAnnotationColor = charts.MaterialPalette.gray.shade100;
      axisLabelColor = charts.MaterialPalette.gray.shade700;
    }

    return charts.TimeSeriesChart(
      widget.seriesList,
      defaultRenderer:
          charts.LineRendererConfig(includeArea: true, stacked: false),
      animate: widget.animate,
      primaryMeasureAxis: charts.NumericAxisSpec(
          //showAxisLine: true,
          //renderSpec: charts.GridlineRendererSpec(),
          renderSpec: charts.SmallTickRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
          //renderSpec: charts.NoneRenderSpec(),
          tickProviderSpec:
              const charts.BasicNumericTickProviderSpec(zeroBound: false)),
      domainAxis: charts.DateTimeAxisSpec(
          //showAxisLine: true,
          renderSpec: charts.SmallTickRendererSpec(
              labelStyle: charts.TextStyleSpec(color: axisLabelColor))
          //tickProviderSpec:
          //    charts.AutoDateTimeTickProviderSpec(includeTime: true)
          //tickProviderSpec: charts.DayTickProviderSpec()
          //tickProviderSpec: charts.DateTimeEndPointsTickProviderSpec()
          ),
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
        /*
        charts.InitialSelection(selectedDataConfig: [
          charts.SeriesDatumConfig<DateTime>(
              'Adjusted Equity', widget.closeDate)
        ]),
        */
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
    );
    /*
    return charts.TimeSeriesChart(
      seriesList,
      defaultRenderer: charts.BarRendererConfig<DateTime>(),
      animate: animate,
      behaviors: [new charts.SeriesLegend()],
    );
    */
  }

  _onSelectionChanged(charts.SelectionModel model) {
    if (model.hasDatumSelection) {
      var selected = model.selectedDatum[0].datum;
      widget.onSelected(selected);
    } else {
      widget.onSelected(null);
    }
  }
}

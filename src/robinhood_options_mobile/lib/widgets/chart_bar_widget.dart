/// Example of a stacked area chart.
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';

class BarChart extends StatefulWidget {
  final List<charts.Series<dynamic, String>> seriesList;
  final bool animate;
  //final List<charts.TickSpec<num>>? staticNumericTicks;
  final List<String>? hiddenSeries;
  final void Function(dynamic) onSelected;

  const BarChart(this.seriesList,
      {Key? key,
      this.animate = true,
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
    var brightness = MediaQuery.of(context).platformBrightness;
    var axisLabelColor = charts.MaterialPalette.gray.shade500;
    if (brightness == Brightness.light) {
      axisLabelColor = charts.MaterialPalette.gray.shade700;
    }

    return charts.BarChart(
      widget.seriesList,
      defaultRenderer: charts.BarRendererConfig(
          barRendererDecorator: charts.BarLabelDecorator<String>(),
          cornerStrategy: const charts.ConstCornerStrategy(10)),
      animate: widget.animate,
      vertical: false,
      barGroupingType: charts.BarGroupingType.grouped,
      //barRendererDecorator: charts.BarLabelDecorator<String>(),
      primaryMeasureAxis: charts.NumericAxisSpec(
        //showAxisLine: true,
        //renderSpec: charts.GridlineRendererSpec(),
        renderSpec: charts.GridlineRendererSpec(
            labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
        //renderSpec: charts.NoneRenderSpec(),
        //tickProviderSpec: charts.BasicNumericTickProviderSpec(),
        //tickProviderSpec: charts.NumericEndPointsTickProviderSpec(),
        //tickProviderSpec:
        //    charts.StaticNumericTickProviderSpec(widget.staticNumericTicks!),
        //viewport: charts.NumericExtents(0, widget.staticNumericTicks![widget.staticNumericTicks!.length - 1].value + 1)
      ),
      domainAxis:
          const charts.OrdinalAxisSpec(renderSpec: charts.NoneRenderSpec()),
      customSeriesRenderers: [
        charts.BarTargetLineRendererConfig<String>(
            //overDrawOuterPx: 10,
            //overDrawPx: 10,
            strokeWidthPx: 5,
            customRendererId: 'customTargetLine',
            groupingType: charts.BarGroupingType.grouped)
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

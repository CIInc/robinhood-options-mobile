/// Example of a stacked area chart.
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/equity_historical.dart';

class Chart extends StatefulWidget {
  final List<charts.Series<dynamic, DateTime>> seriesList;
  final bool animate;
  final double open;
  final double close;
  final void Function(EquityHistorical) onSelected;

  const Chart(this.seriesList, this.open, this.close,
      {Key? key, this.animate = true, required this.onSelected})
      : super(key: key);

  // We need a Stateful widget to build the selection details with the current
  // selection as the state.
  @override
  State<StatefulWidget> createState() => _ChartState();
}

class _ChartState extends State<Chart> {
  @override
  Widget build(BuildContext context) {
    var brightness = MediaQuery.of(context).platformBrightness;
    var rangeAnnotationColor = charts.MaterialPalette.gray.shade800;
    if (brightness == Brightness.light) {
      rangeAnnotationColor = charts.MaterialPalette.gray.shade100;
    }

    return charts.TimeSeriesChart(
      widget.seriesList,
      defaultRenderer:
          charts.LineRendererConfig(includeArea: true, stacked: false),
      animate: widget.animate,
      primaryMeasureAxis: const charts.NumericAxisSpec(
          tickProviderSpec:
              charts.BasicNumericTickProviderSpec(zeroBound: false)),
      selectionModels: [
        charts.SelectionModelConfig(
          type: charts.SelectionModelType.info,
          changedListener: _onSelectionChanged,
        )
      ],
      behaviors: [
        charts.SelectNearest(eventTrigger: charts.SelectionTrigger.tapAndDrag),
        charts.LinePointHighlighter(
            showHorizontalFollowLine:
                charts.LinePointHighlighterFollowLineType.none,
            showVerticalFollowLine:
                charts.LinePointHighlighterFollowLineType.nearest),
        /*
        charts.InitialSelection(selectedDataConfig: [
          charts.SeriesDatumConfig<DateTime>(
              'Adjusted Equity', widget.closeDate)
        ]),
        */
        charts.SeriesLegend(
          defaultHiddenSeries: const ['Equity', 'Market Value'],
        ),
        charts.RangeAnnotation([
          charts.RangeAnnotationSegment(
              widget.open <= widget.close ? widget.open : widget.close,
              widget.open <= widget.close ? widget.close : widget.open,
              charts.RangeAnnotationAxisType.measure,
              startLabel: widget.open <= widget.close ? 'Open' : 'Close',
              endLabel: widget.open <= widget.close ? 'Close' : 'Open',
              color: rangeAnnotationColor // gray.shade200
              ),
        ])
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
      var selected = model.selectedDatum[0].datum as EquityHistorical;
      widget.onSelected(selected);
    }
  }
}

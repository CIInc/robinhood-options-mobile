/// Example of a stacked area chart.
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/equity_historical.dart';

class Chart extends StatelessWidget {
  final List<charts.Series<dynamic, DateTime>> seriesList;
  final bool animate;
  final void Function(EquityHistorical?) onSelected;

  const Chart(this.seriesList,
      {Key? key, this.animate = true, required this.onSelected})
      : super(key: key);

  /*
  /// Creates a [LineChart] with sample data and no transition.
  factory StackedAreaLineChart.withSampleData() {
    return new StackedAreaLineChart(
      _createSampleData(),
    );
  }
  */

  @override
  Widget build(BuildContext context) {
    /*
    return charts.LineChart(
      seriesList,
      defaultRenderer:
          charts.LineRendererConfig(includeArea: true, stacked: false),
      animate: animate,
      behaviors: [new charts.SeriesLegend()],
    );
    */
    return charts.TimeSeriesChart(
      seriesList,
      defaultRenderer:
          charts.LineRendererConfig(includeArea: true, stacked: false),
      animate: animate,
      selectionModels: [
        charts.SelectionModelConfig(
          type: charts.SelectionModelType.info,
          changedListener: _onSelectionChanged,
          //changedListener: (charts.SelectionModel model) {

          //},
        )
      ],
      behaviors: [charts.SeriesLegend()],
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
      onSelected(selected);
    } else {
      onSelected(null);
    }
  }
}

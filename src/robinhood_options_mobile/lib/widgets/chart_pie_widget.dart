/// Example of a stacked area chart.
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';

class PieChartData {
  final String label;
  final double value;
  PieChartData(this.label, this.value);
}

class PieChart extends StatefulWidget {
  final List<charts.Series<PieChartData, String>> seriesList;
  final bool animate;
  final charts.ArcRendererConfig<String>? renderer;
  final List<String>? hiddenSeries;
  final void Function(dynamic) onSelected;

  const PieChart(this.seriesList,
      {Key? key,
      this.animate = true,
      this.renderer,
      required this.onSelected,
      //this.staticNumericTicks,
      this.hiddenSeries})
      : super(key: key);

  // We need a Stateful widget to build the selection details with the current
  // selection as the state.
  @override
  State<StatefulWidget> createState() => PieChartState();
}

class PieChartState extends State<PieChart> {
  @override
  Widget build(BuildContext context) {
    return charts.PieChart<String>(
      widget.seriesList,
      defaultRenderer: widget.renderer,
      animate: widget.animate,
      selectionModels: [
        charts.SelectionModelConfig(
            type: charts.SelectionModelType.info,
            changedListener: _onSelectionChanged)
      ],
    );
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

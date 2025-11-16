//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
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
  final List<charts.ChartBehavior<String>>? behaviors;
  final void Function(dynamic) onSelected;

  const PieChart(this.seriesList,
      {super.key,
      this.animate = true,
      this.renderer,
      required this.onSelected,
      this.behaviors,
      //this.staticNumericTicks,
      this.hiddenSeries});

  // We need a Stateful widget to build the selection details with the current
  // selection as the state.
  @override
  State<StatefulWidget> createState() => PieChartState();

  static List<charts.Color> makeShades(
      charts.Color shadeDefault, int colorCnt) {
    final colors = <charts.Color>[shadeDefault];

    // If we need more than 2 colors, then [unselected] collides with one of the
    // generated colors. Otherwise divide the space between the top color
    // and white in half.
    final lighterColor = colorCnt < 3
        ? shadeDefault.lighter
        : _getSteppedColor(shadeDefault, (colorCnt * 2) - 1, colorCnt * 2);

    // Divide the space between 255 and c500 evenly according to the colorCnt.
    for (var i = 1; i < colorCnt; i++) {
      colors.add(_getSteppedColor(shadeDefault, i, colorCnt,
          darker: shadeDefault.darker, lighter: lighterColor));
    }

    colors.add(
        charts.Color.fromOther(color: shadeDefault, lighter: lighterColor));
    return colors;
  }

  static charts.Color _getSteppedColor(charts.Color color, int index, int steps,
      {charts.Color? darker, charts.Color? lighter}) {
    final fraction = index / steps;
    return charts.Color(
      r: color.r + ((255 - color.r) * fraction).round(),
      g: color.g + ((255 - color.g) * fraction).round(),
      b: color.b + ((255 - color.b) * fraction).round(),
      a: color.a + ((255 - color.a) * fraction).round(),
      darker: darker,
      lighter: lighter,
    );
  }
}

class PieChartState extends State<PieChart> {
  @override
  Widget build(BuildContext context) {
    return widget.seriesList.isEmpty || widget.seriesList[0].data.isEmpty
        ? Container()
        : charts.PieChart<String>(widget.seriesList,
            defaultRenderer: widget.renderer,
            animate: widget.animate,
            selectionModels: [
              charts.SelectionModelConfig(
                  type: charts.SelectionModelType.info,
                  changedListener: _onSelectionChanged)
            ],
            behaviors: widget.behaviors ?? []);
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

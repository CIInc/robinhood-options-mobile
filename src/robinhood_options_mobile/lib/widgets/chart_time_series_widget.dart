//import 'package:charts_flutter/flutter.dart' as charts;
import 'package:community_charts_flutter/community_charts_flutter.dart' as charts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final formatCurrency = NumberFormat.simpleCurrency();

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
  /*
  num? _sliderDomainValue;
  String? _sliderDragState;
  Point<int>? _sliderPosition;
  // Handles callbacks when the user drags the slider.
  _onSliderChange(Point<int> point, dynamic domain, String roleId,
      charts.SliderListenerDragState dragState) {
    // Request a build.
    void rebuild(_) {
      setState(() {
        _sliderDomainValue = (domain * 10).round() / 10;
        _sliderDragState = dragState.toString();
        _sliderPosition = point;
      });
    }

    SchedulerBinding.instance!.addPostFrameCallback(rebuild);
  }
  */

  @override
  Widget build(BuildContext context) {
    var brightness = MediaQuery.of(context).platformBrightness;
    var rangeAnnotationColor = charts.MaterialPalette.gray.shade800;
    var rangeAnnotationLabelColor = charts.MaterialPalette.gray.shade500;
    var axisLabelColor = charts.MaterialPalette.gray.shade200;
    if (brightness == Brightness.light) {
      rangeAnnotationColor = charts.MaterialPalette.gray.shade200;
      rangeAnnotationLabelColor = charts.MaterialPalette.gray.shade500;
      axisLabelColor = charts.MaterialPalette.gray.shade800;
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
      domainAxis: charts.DateTimeAxisSpec( // EndPointsTimeAxisSpec
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
        /*
        charts.Slider(
            initialDomainValue:
                (widget.seriesList[0].data[0] as EquityHistorical).beginsAt,
            snapToDatum: true,
            eventTrigger: charts.SelectionTrigger.tapAndDrag,
            onChangeCallback: _onSliderChange),
            */
        charts.SelectNearest(eventTrigger: charts.SelectionTrigger.tapAndDrag), // pressHold
        charts.LinePointHighlighter(
            showHorizontalFollowLine:
                charts.LinePointHighlighterFollowLineType.all, // .none
            showVerticalFollowLine:
                charts.LinePointHighlighterFollowLineType.all,
            dashPattern: const [], // const [10],
            defaultRadiusPx: 5),
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
                startLabel: widget.open! <= widget.close!
                    ? 'Previous ${formatCurrency.format(widget.open!)}'
                    : 'Current ${formatCurrency.format(widget.close!)}',
                endLabel: widget.open! <= widget.close!
                    ? 'Current ${formatCurrency.format(widget.close!)}'
                    : 'Previous ${formatCurrency.format(widget.open!)}',
                labelStyleSpec: charts.TextStyleSpec(
                    color: rangeAnnotationLabelColor), //axisLabelColor
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
  /*
  _onSliderChange(Point<int> point, dynamic domain, String roleId,
      charts.SliderListenerDragState dragState) {
    //widget.onSelected(selected);
  }
  */
}

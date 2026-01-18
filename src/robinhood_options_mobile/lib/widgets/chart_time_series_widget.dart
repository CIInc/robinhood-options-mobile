//import 'package:charts_flutter/flutter.dart' as charts;
import 'dart:math';

import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:community_charts_flutter/src/text_style.dart' as style;
import 'package:community_charts_flutter/src/text_element.dart' as element;
import 'package:community_charts_common/community_charts_common.dart' as common;
import 'package:robinhood_options_mobile/constants.dart';

class TimeSeriesChart extends StatefulWidget {
  final List<charts.Series<dynamic, DateTime>> seriesList;
  final bool animate;
  final double? open;
  final double? close;
  final charts.SeriesRendererConfig<DateTime>? seriesRendererConfig;
  final List<charts.SeriesRendererConfig<DateTime>>? customSeriesRenderers;
  final charts.NumericExtents? viewport;
  final bool zeroBound;
  final bool dataIsInWholeNumbers;
  final common.SelectionMode selectionMode;
  final List<charts.ChartBehavior<DateTime>>? behaviors;
  final charts.ChartBehavior<DateTime>? seriesLegend;
  final charts.ChartBehavior<DateTime>? initialSelection;

  final charts.AxisSpec<dynamic>? domainAxis;
  final charts.NumericAxisSpec? primaryMeasureAxis;
  final charts.NumericAxisSpec? secondaryMeasureAxis;
  final charts.CircleSymbolRenderer? symbolRenderer;
  // final String Function()? getTextForTextSymbolRenderer;
  final void Function(charts.SelectionModel<DateTime>?) onSelected;
  final charts.LinePointHighlighterFollowLineType showVerticalFollowLine;
  final bool? drawFollowLinesAcrossChart;

  const TimeSeriesChart(this.seriesList,
      {super.key,
      this.animate = true,
      required this.onSelected,
      this.symbolRenderer,
      // this.getTextForTextSymbolRenderer,
      this.open,
      this.close,
      this.seriesRendererConfig,
      this.customSeriesRenderers,
      this.selectionMode = common.SelectionMode.expandToDomain,
      this.behaviors,
      this.seriesLegend,
      this.initialSelection,
      this.domainAxis,
      this.primaryMeasureAxis,
      this.secondaryMeasureAxis,
      this.viewport,
      this.zeroBound = true,
      this.dataIsInWholeNumbers = true,
      this.showVerticalFollowLine =
          charts.LinePointHighlighterFollowLineType.all,
      this.drawFollowLinesAcrossChart});

  // We need a Stateful widget to build the selection details with the current
  // selection as the state.
  @override
  State<StatefulWidget> createState() => _TimeSeriesChartState();
}

class _TimeSeriesChartState extends State<TimeSeriesChart> {
  @override
  Widget build(BuildContext context) {
    var brightness = MediaQuery.of(context).platformBrightness;
    var rangeAnnotationColor = charts.MaterialPalette.gray.shade900;
    var rangeAnnotationLabelColor = charts.MaterialPalette.gray.shade500;
    var axisLabelColor = charts.MaterialPalette.gray.shade200;
    if (brightness == Brightness.light) {
      rangeAnnotationColor = charts.MaterialPalette.gray.shade100;
      rangeAnnotationLabelColor = charts.MaterialPalette.gray.shade500;
      axisLabelColor = charts.MaterialPalette.gray.shade800;
    }

    return charts.TimeSeriesChart(
      widget.seriesList,
      defaultRenderer: widget.seriesRendererConfig ??
          charts.LineRendererConfig(
              includeArea: true,
              stacked: false,
              strokeWidthPx: 1.0,
              symbolRenderer: CustomLineSymbolRenderer()),
      customSeriesRenderers: widget.customSeriesRenderers ?? [],
      // defaultInteractions:
      //     widget.seriesRendererConfig is charts.LineRendererConfig
      //         ? true
      //         : false,
      animate: widget.animate,
      primaryMeasureAxis: widget.primaryMeasureAxis ??
          charts.NumericAxisSpec(
            viewport: widget.viewport,
            //showAxisLine: true,
            //renderSpec: charts.GridlineRendererSpec(),
            renderSpec: charts.SmallTickRendererSpec(
                labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
            //renderSpec: charts.NoneRenderSpec(),
            tickProviderSpec: charts.BasicNumericTickProviderSpec(
                zeroBound: widget.zeroBound,
                dataIsInWholeNumbers: widget.dataIsInWholeNumbers,
                desiredMinTickCount: 6),
            tickFormatterSpec:
                charts.BasicNumericTickFormatterSpec.fromNumberFormat(
                    NumberFormat.compactSimpleCurrency()),
          ),
      secondaryMeasureAxis: widget.secondaryMeasureAxis,
      domainAxis: widget.domainAxis ??
          charts.DateTimeAxisSpec(
            // EndPointsTimeAxisSpec
            //showAxisLine: true,
            renderSpec: charts.SmallTickRendererSpec(
                labelStyle: charts.TextStyleSpec(color: axisLabelColor)),
            //tickProviderSpec:
            //    charts.AutoDateTimeTickProviderSpec(includeTime: true)
            // tickProviderSpec: charts.DayTickProviderSpec(increments: [364])
            //tickProviderSpec: charts.DateTimeEndPointsTickProviderSpec()
          ),
      selectionModels: [
        charts.SelectionModelConfig(
            type: charts.SelectionModelType.info,
            changedListener: (charts.SelectionModel<DateTime> model) {
              if (model.hasDatumSelection) {
                // var selected = model
                //     .selectedDatum[0].datum; //  as MapEntry<DateTime, double>
                // var selected = model.selectedDatum
                //     .map((s) => s.datum); //  as MapEntry<DateTime, double>
                // widget.onSelected(selected.first);
                widget.onSelected(model);
              } else {
                widget.onSelected(null);
              }
            })
      ],
      behaviors: widget.behaviors ??
          [
            /*
        charts.Slider(
            initialDomainValue:
                (widget.seriesList[0].data[0] as EquityHistorical).beginsAt,
            snapToDatum: true,
            eventTrigger: charts.SelectionTrigger.tapAndDrag,
            onChangeCallback: _onSliderChange),
            */
            charts.SelectNearest(
                eventTrigger: charts.SelectionTrigger.tapAndDrag,
                selectionMode: widget.selectionMode), // pressHold
            charts.LinePointHighlighter(
                // showHorizontalFollowLine:
                //     charts.LinePointHighlighterFollowLineType.all, // .none
                showVerticalFollowLine: widget.showVerticalFollowLine,
                dashPattern: const [1], // const [10],
                defaultRadiusPx: 3,
                // radiusPaddingPx: 6,
                drawFollowLinesAcrossChart: widget.drawFollowLinesAcrossChart,
                // symbolRenderer: TextSymbolRenderer(() => 'rtest')),
                symbolRenderer: widget.symbolRenderer),
            // symbolRenderer: widget.getTextForTextSymbolRenderer != null
            // ? TextSymbolRenderer(widget.getTextForTextSymbolRenderer!, marginBottom: 16)
            //     : null),

            if (widget.initialSelection != null) ...[widget.initialSelection!],
            if (widget.seriesLegend != null) ...[widget.seriesLegend!],
            if (widget.open != null && widget.close != null) ...[
              charts.RangeAnnotation([
                charts.RangeAnnotationSegment(
                    widget.open! <= widget.close!
                        ? widget.open!
                        : widget.close!,
                    widget.open! <= widget.close!
                        ? widget.close!
                        : widget.open!,
                    charts.RangeAnnotationAxisType.measure,
                    startLabel: widget.open! <= widget.close!
                        ? 'open ${formatCurrency.format(widget.open!)}'
                        : 'close ${formatCurrency.format(widget.close!)}',
                    endLabel: widget.open! <= widget.close!
                        ? 'close ${formatCurrency.format(widget.close!)}'
                        : 'open ${formatCurrency.format(widget.open!)}',
                    labelStyleSpec: charts.TextStyleSpec(
                        fontSize: 14,
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

  /*
  _onSliderChange(Point<int> point, dynamic domain, String roleId,
      charts.SliderListenerDragState dragState) {
    //widget.onSelected(selected);
  }
  */
}

// import 'package:charts_flutter/flutter.dart';
// import 'package:charts_flutter/src/text_style.dart' as style;
// import 'package:charts_flutter/src/text_element.dart' as element;
// import 'package:flutter/material.dart';

typedef GetText = String Function();

class TextSymbolRenderer extends CustomCircleSymbolRenderer {
  TextSymbolRenderer(this.getText,
      {this.marginBottom = 8,
      this.padding = const EdgeInsets.all(8),
      this.placeAbovePoint = false,
      this.textColor = Colors.black,
      this.backgroundColor = Colors.white,
      this.fontSize = 12});

  final GetText getText;
  final double marginBottom;
  final EdgeInsets padding;
  final bool placeAbovePoint;
  final Color textColor;
  final Color backgroundColor;
  final int fontSize;

  @override
  void paint(charts.ChartCanvas canvas, Rectangle<num> bounds,
      {List<int>? dashPattern,
      charts.Color? fillColor,
      charts.FillPatternType? fillPattern,
      charts.Color? strokeColor,
      double? strokeWidthPx}) {
    super.paint(canvas, bounds,
        dashPattern: dashPattern,
        fillColor: fillColor,
        fillPattern: fillPattern,
        strokeColor: strokeColor,
        strokeWidthPx: strokeWidthPx);

    style.TextStyle textStyle = style.TextStyle();
    textStyle.color = charts.ColorUtil.fromDartColor(textColor);
    textStyle.fontSize = fontSize;

    element.TextElement textElement =
        element.TextElement(getText.call(), style: textStyle);
    double width = textElement.measurement.horizontalSliceWidth;
    double height = textElement.measurement.verticalSliceWidth;

    double centerX = bounds.left + bounds.width / 2;
    double centerY = marginBottom + padding.bottom;
    if (placeAbovePoint) {
      centerY = bounds.top +
          bounds.height / 2 -
          marginBottom -
          (padding.top + padding.bottom);
    }

    canvas.drawRRect(
      Rectangle(
        centerX - (width / 2) - padding.left,
        centerY - (height / 2) - padding.top,
        width + (padding.left + padding.right),
        height + (padding.top + padding.bottom),
      ),
      fill: charts.ColorUtil.fromDartColor(backgroundColor),
      radius: 16,
      roundTopLeft: true,
      roundTopRight: true,
      roundBottomRight: true,
      roundBottomLeft: true,
    );
    canvas.drawText(
      textElement,
      (centerX - (width / 2)).round(),
      (centerY - (height / 2)).round(),
    );
  }
}

/// A line symbol renderer that accepts any old renderer in [shouldRepaint]
/// to prevent type errors when switching between series types (e.g. Bar to Line).
class CustomLineSymbolRenderer extends common.LineSymbolRenderer {
  @override
  bool shouldRepaint(covariant common.SymbolRenderer oldRenderer) {
    return this != oldRenderer;
  }
}

class CustomCircleSymbolRenderer extends common.CircleSymbolRenderer {
  @override
  bool shouldRepaint(covariant common.SymbolRenderer oldRenderer) {
    return this != oldRenderer;
  }
}

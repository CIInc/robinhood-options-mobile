import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/widgets/instrument_chart_widget.dart';

class FullScreenInstrumentChartWidget extends StatefulWidget {
  final Instrument instrument;
  final ChartDateSpan chartDateSpanFilter;
  final Bounds chartBoundsFilter;
  final Function(ChartDateSpan, Bounds) onFilterChanged;

  const FullScreenInstrumentChartWidget({
    super.key,
    required this.instrument,
    required this.chartDateSpanFilter,
    required this.chartBoundsFilter,
    required this.onFilterChanged,
  });

  @override
  State<FullScreenInstrumentChartWidget> createState() =>
      _FullScreenInstrumentChartWidgetState();
}

class _FullScreenInstrumentChartWidgetState
    extends State<FullScreenInstrumentChartWidget> {
  // Local state for filters in full screen mode
  late ChartDateSpan _chartDateSpanFilter;
  late Bounds _chartBoundsFilter;

  @override
  void initState() {
    super.initState();
    _chartDateSpanFilter = widget.chartDateSpanFilter;
    _chartBoundsFilter = widget.chartBoundsFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.instrument.symbol} Chart'),
      ),
      body: InstrumentChartWidget(
        instrument: widget.instrument,
        chartDateSpanFilter: _chartDateSpanFilter,
        chartBoundsFilter: _chartBoundsFilter,
        onFilterChanged: (span, bounds) {
          setState(() {
            _chartDateSpanFilter = span;
            _chartBoundsFilter = bounds;
          });
          widget.onFilterChanged(span, bounds);
        },
        isFullScreen: true,
      ),
    );
  }
}

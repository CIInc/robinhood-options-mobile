import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/multi_leg_order_entry.dart';
import 'package:robinhood_options_mobile/widgets/instrument_chart_widget.dart';
import 'package:robinhood_options_mobile/widgets/multi_leg_matrix_order_entry_widget.dart';

/// Full-width widescreen and landscape charting widget with integrated
/// collapsible multi-column matrix order entry for tablet and mobile devices.
class FullScreenInstrumentChartWidget extends StatefulWidget {
  final Instrument instrument;
  final ChartDateSpan chartDateSpanFilter;
  final Bounds chartBoundsFilter;
  final Function(ChartDateSpan, Bounds) onFilterChanged;
  final bool initialMatrixOpen;

  const FullScreenInstrumentChartWidget({
    super.key,
    required this.instrument,
    required this.chartDateSpanFilter,
    required this.chartBoundsFilter,
    required this.onFilterChanged,
    this.initialMatrixOpen = true,
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
  late bool _isMatrixOpen;
  bool _isManualLandscape = false;

  @override
  void initState() {
    super.initState();
    _chartDateSpanFilter = widget.chartDateSpanFilter;
    _chartBoundsFilter = widget.chartBoundsFilter;
    _isMatrixOpen = widget.initialMatrixOpen;

    // Enable landscape and portrait rotations for widescreen chart mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    // Restore default portrait-locked orientation on exit
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _toggleOrientation(Orientation currentOrientation) {
    setState(() {
      if (currentOrientation == Orientation.landscape || _isManualLandscape) {
        _isManualLandscape = false;
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } else {
        _isManualLandscape = true;
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  void _toggleMatrix() {
    setState(() {
      _isMatrixOpen = !_isMatrixOpen;
    });
  }

  void _openMatrixBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: MultiLegMatrixOrderEntryWidget(
                instrument: widget.instrument,
                isCollapsible: false,
                onOrderSubmitted: (order) {
                  Navigator.of(ctx).pop();
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = orientation == Orientation.landscape ||
                constraints.maxWidth >= 720;
            final sidePanelWidth =
                (constraints.maxWidth * 0.40).clamp(320.0, 440.0);

            return Scaffold(
              appBar: AppBar(
                title: Text('${widget.instrument.symbol} Chart'),
                actions: [
                  IconButton(
                    icon: Icon(
                      orientation == Orientation.landscape
                          ? Icons.stay_current_portrait
                          : Icons.stay_current_landscape,
                    ),
                    tooltip: orientation == Orientation.landscape
                        ? 'Switch to Portrait'
                        : 'Switch to Landscape',
                    onPressed: () => _toggleOrientation(orientation),
                  ),
                  if (isWide)
                    IconButton(
                      icon: Icon(
                        _isMatrixOpen
                            ? Icons.view_sidebar
                            : Icons.view_sidebar_outlined,
                        color: _isMatrixOpen
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      tooltip: _isMatrixOpen
                          ? 'Hide Strategy Matrix'
                          : 'Show Strategy Matrix',
                      onPressed: _toggleMatrix,
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.table_chart),
                      tooltip: 'Multi-Leg Matrix Order Entry',
                      onPressed: _openMatrixBottomSheet,
                    ),
                ],
              ),
              body: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Column: Full-width widescreen interactive chart
                        Expanded(
                          child: _buildChart(),
                        ),
                        // Right Column: Collapsible multi-leg order entry matrix panel
                        if (_isMatrixOpen)
                          SizedBox(
                            width: sidePanelWidth,
                            child: MultiLegMatrixOrderEntryWidget(
                              instrument: widget.instrument,
                              isCollapsible: true,
                              onCollapse: () =>
                                  setState(() => _isMatrixOpen = false),
                              onOrderSubmitted: (MultiLegOrderEntry order) {
                                // Order submitted notification
                              },
                            ),
                          ),
                      ],
                    )
                  : _buildChart(),
              floatingActionButton: !isWide
                  ? FloatingActionButton.extended(
                      icon: const Icon(Icons.table_chart, size: 18),
                      label: const Text('Multi-Leg Matrix',
                          style: TextStyle(fontSize: 12)),
                      onPressed: _openMatrixBottomSheet,
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildChart() {
    return InstrumentChartWidget(
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
    );
  }
}

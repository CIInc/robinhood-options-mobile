import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/widgets/home/portfolio_chart_widget.dart';

class FullScreenPortfolioChartWidget extends StatefulWidget {
  final BrokerageUser brokerageUser;
  final ChartDateSpan chartDateSpanFilter;
  final Bounds chartBoundsFilter;
  final Function(ChartDateSpan, Bounds) onFilterChanged;

  const FullScreenPortfolioChartWidget({
    super.key,
    required this.brokerageUser,
    required this.chartDateSpanFilter,
    required this.chartBoundsFilter,
    required this.onFilterChanged,
  });

  @override
  State<FullScreenPortfolioChartWidget> createState() =>
      _FullScreenPortfolioChartWidgetState();
}

class _FullScreenPortfolioChartWidgetState
    extends State<FullScreenPortfolioChartWidget> {
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
        title: const Text('Portfolio Chart'),
      ),
      body: PortfolioChartWidget(
        brokerageUser: widget.brokerageUser,
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

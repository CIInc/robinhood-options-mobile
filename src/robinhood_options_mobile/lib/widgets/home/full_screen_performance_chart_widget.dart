import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/widgets/home/performance_chart_widget.dart';

class FullScreenPerformanceChartWidget extends StatefulWidget {
  final Future<dynamic>? futureMarketIndexHistoricalsSp500;
  final Future<dynamic>? futureMarketIndexHistoricalsNasdaq;
  final Future<dynamic>? futureMarketIndexHistoricalsDow;
  final Future<dynamic>? futureMarketIndexHistoricalsRussell2000;
  final Future<PortfolioHistoricals>? futurePortfolioHistoricalsYear;
  final ChartDateSpan benchmarkChartDateSpanFilter;
  final Function(ChartDateSpan) onFilterChanged;

  const FullScreenPerformanceChartWidget({
    super.key,
    required this.futureMarketIndexHistoricalsSp500,
    required this.futureMarketIndexHistoricalsNasdaq,
    required this.futureMarketIndexHistoricalsDow,
    this.futureMarketIndexHistoricalsRussell2000,
    required this.futurePortfolioHistoricalsYear,
    required this.benchmarkChartDateSpanFilter,
    required this.onFilterChanged,
  });

  @override
  State<FullScreenPerformanceChartWidget> createState() =>
      _FullScreenPerformanceChartWidgetState();
}

class _FullScreenPerformanceChartWidgetState
    extends State<FullScreenPerformanceChartWidget> {
  late ChartDateSpan _benchmarkChartDateSpanFilter;

  @override
  void initState() {
    super.initState();
    _benchmarkChartDateSpanFilter = widget.benchmarkChartDateSpanFilter;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Chart'),
      ),
      body: PerformanceChartWidget(
        futureMarketIndexHistoricalsSp500:
            widget.futureMarketIndexHistoricalsSp500,
        futureMarketIndexHistoricalsNasdaq:
            widget.futureMarketIndexHistoricalsNasdaq,
        futureMarketIndexHistoricalsDow: widget.futureMarketIndexHistoricalsDow,
        futureMarketIndexHistoricalsRussell2000:
            widget.futureMarketIndexHistoricalsRussell2000,
        futurePortfolioHistoricalsYear: widget.futurePortfolioHistoricalsYear,
        benchmarkChartDateSpanFilter: _benchmarkChartDateSpanFilter,
        onFilterChanged: (span) {
          setState(() {
            _benchmarkChartDateSpanFilter = span;
          });
          widget.onFilterChanged(span);
        },
        isFullScreen: true,
      ),
    );
  }
}

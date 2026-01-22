import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals.dart';
import 'package:robinhood_options_mobile/model/portfolio_historicals_store.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/yahoo_service.dart';
import 'package:robinhood_options_mobile/widgets/home/performance_chart_widget.dart';

class FullScreenPerformanceChartWidget extends StatefulWidget {
  final BrokerageUser user;
  final IBrokerageService service;
  final String? accountNumber;
  final Future<dynamic>? futureMarketIndexHistoricalsSp500;
  final Future<dynamic>? futureMarketIndexHistoricalsNasdaq;
  final Future<dynamic>? futureMarketIndexHistoricalsDow;
  final Future<dynamic>? futureMarketIndexHistoricalsRussell2000;
  final Future<PortfolioHistoricals>? futurePortfolioHistoricalsYear;
  final ChartDateSpan benchmarkChartDateSpanFilter;
  final Function(ChartDateSpan) onFilterChanged;
  final String? selectedBenchmark;
  final Future<dynamic>? futureCustomBenchmark;
  final String? customBenchmarkSymbol;
  final bool showAllBenchmarks;

  const FullScreenPerformanceChartWidget({
    super.key,
    required this.user,
    required this.service,
    this.accountNumber,
    required this.futureMarketIndexHistoricalsSp500,
    required this.futureMarketIndexHistoricalsNasdaq,
    required this.futureMarketIndexHistoricalsDow,
    this.futureMarketIndexHistoricalsRussell2000,
    required this.futurePortfolioHistoricalsYear,
    required this.benchmarkChartDateSpanFilter,
    required this.onFilterChanged,
    this.selectedBenchmark,
    this.futureCustomBenchmark,
    this.customBenchmarkSymbol,
    this.showAllBenchmarks = false,
  });

  @override
  State<FullScreenPerformanceChartWidget> createState() =>
      _FullScreenPerformanceChartWidgetState();
}

class _FullScreenPerformanceChartWidgetState
    extends State<FullScreenPerformanceChartWidget> {
  late ChartDateSpan _benchmarkChartDateSpanFilter;
  late bool _showAllBenchmarks;
  late String? _customBenchmarkSymbol;
  Future<dynamic>? _futureCustomBenchmark;
  String _selectedBenchmark = 'SPY';

  Future<PortfolioHistoricals>? _futurePortfolioHistoricals;
  Future<dynamic>? _futureMarketIndexHistoricalsSp500;
  Future<dynamic>? _futureMarketIndexHistoricalsNasdaq;
  Future<dynamic>? _futureMarketIndexHistoricalsDow;
  Future<dynamic>? _futureMarketIndexHistoricalsRussell2000;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _benchmarkChartDateSpanFilter = widget.benchmarkChartDateSpanFilter;
    _showAllBenchmarks = widget.showAllBenchmarks;
    _customBenchmarkSymbol = widget.customBenchmarkSymbol;
    _futureCustomBenchmark = widget.futureCustomBenchmark;
    if (widget.selectedBenchmark != null) {
      _selectedBenchmark = widget.selectedBenchmark!;
    }
    _futurePortfolioHistoricals = widget.futurePortfolioHistoricalsYear;
    _futureMarketIndexHistoricalsSp500 =
        widget.futureMarketIndexHistoricalsSp500;
    _futureMarketIndexHistoricalsNasdaq =
        widget.futureMarketIndexHistoricalsNasdaq;
    _futureMarketIndexHistoricalsDow = widget.futureMarketIndexHistoricalsDow;
    _futureMarketIndexHistoricalsRussell2000 =
        widget.futureMarketIndexHistoricalsRussell2000;
    _waitForFutures();
  }

  void _waitForFutures() {
    final futures = <Future>[];
    if (_futurePortfolioHistoricals != null) {
      futures.add(_futurePortfolioHistoricals!);
    }
    if (_futureMarketIndexHistoricalsSp500 != null) {
      futures.add(_futureMarketIndexHistoricalsSp500!);
    }
    if (_futureMarketIndexHistoricalsNasdaq != null) {
      futures.add(_futureMarketIndexHistoricalsNasdaq!);
    }
    if (_futureMarketIndexHistoricalsDow != null) {
      futures.add(_futureMarketIndexHistoricalsDow!);
    }
    if (_futureMarketIndexHistoricalsRussell2000 != null) {
      futures.add(_futureMarketIndexHistoricalsRussell2000!);
    }
    if (_futureCustomBenchmark != null) {
      futures.add(_futureCustomBenchmark!);
    }
    if (futures.isNotEmpty) {
      Future.wait(futures).whenComplete(() {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadData() {
    setState(() {
      _isLoading = true;
    });
    if (widget.accountNumber != null) {
      _futurePortfolioHistoricals = widget.service.getPortfolioPerformance(
          widget.user,
          Provider.of<PortfolioHistoricalsStore>(context, listen: false),
          widget.accountNumber!,
          chartBoundsFilter: Bounds.regular,
          chartDateSpanFilter: _benchmarkChartDateSpanFilter);
    }

    final yahooService = YahooService();
    String range = "ytd";
    switch (_benchmarkChartDateSpanFilter) {
      case ChartDateSpan.hour:
      case ChartDateSpan.day:
        range = "1d";
        break;
      case ChartDateSpan.week:
        range = "5d";
        break;
      case ChartDateSpan.month:
        range = "1mo";
        break;
      case ChartDateSpan.month_3:
        range = "3mo";
        break;
      case ChartDateSpan.ytd:
        range = "ytd";
        break;
      case ChartDateSpan.year:
        range = "1y";
        break;
      case ChartDateSpan.year_2:
        range = "2y";
        break;
      case ChartDateSpan.year_3:
        range = "5y"; // Yahoo doesn't support 3y
        break;
      case ChartDateSpan.year_5:
        range = "5y";
        break;
      case ChartDateSpan.all:
        range = "max";
        break;
    }
    _futureMarketIndexHistoricalsSp500 =
        yahooService.getMarketIndexHistoricals(symbol: '^GSPC', range: range);
    _futureMarketIndexHistoricalsNasdaq =
        yahooService.getMarketIndexHistoricals(symbol: '^IXIC', range: range);
    _futureMarketIndexHistoricalsDow =
        yahooService.getMarketIndexHistoricals(symbol: '^DJI', range: range);
    _futureMarketIndexHistoricalsRussell2000 =
        yahooService.getMarketIndexHistoricals(symbol: 'IWM', range: range);

    // Also reload custom benchmark if exists
    if (_customBenchmarkSymbol != null) {
      _futureCustomBenchmark = _fetchCustomBenchmark(_customBenchmarkSymbol!);
    }
    _waitForFutures();
  }

  Future<void> _addCustomBenchmark() async {
    final TextEditingController symbolController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Custom Benchmark'),
          content: TextField(
            controller: symbolController,
            decoration: const InputDecoration(
              labelText: 'Ticker Symbol (e.g., BTC-USD, AAPL)',
              hintText: 'Enter a valid Yahoo Finance ticker',
            ),
            textCapitalization: TextCapitalization.characters,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (symbolController.text.isNotEmpty) {
                  setState(() {
                    _isLoading = true;
                    _customBenchmarkSymbol =
                        symbolController.text.toUpperCase();
                    _selectedBenchmark = _customBenchmarkSymbol!;
                    _showAllBenchmarks = false; // Auto-focus on the new one
                    _futureCustomBenchmark =
                        _fetchCustomBenchmark(_customBenchmarkSymbol!);
                    _waitForFutures();
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<dynamic> _fetchCustomBenchmark(String symbol) {
    String range = '1y'; // Default max
    String interval = '1d';
    switch (_benchmarkChartDateSpanFilter) {
      case ChartDateSpan.hour: // Added hour
      case ChartDateSpan.day:
        range = '1d';
        interval = '5m';
        break;
      case ChartDateSpan.week:
        range = '5d';
        interval = '1h';
        break;
      case ChartDateSpan.month:
        range = '1mo';
        interval = '1d';
        break;
      case ChartDateSpan.month_3: // Fixed
        range = '3mo';
        interval = '1d';
        break;
      case ChartDateSpan.ytd:
        range = 'ytd';
        interval = '1d';
        break;
      case ChartDateSpan.year:
        range = '1y';
        interval = '1d';
        break;
      case ChartDateSpan.year_2:
        range = '2y';
        interval = '1wk';
        break;
      case ChartDateSpan.year_3:
      case ChartDateSpan.year_5: // Fixed
        range = '5y';
        interval = '1wk';
        break;
      case ChartDateSpan.all:
        range = '10y';
        interval = '1mo';
        break;
    }
    return YahooService().getMarketIndexHistoricals(
        symbol: symbol, range: range, interval: interval);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Chart'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'add_benchmark') {
                _addCustomBenchmark();
              } else if (value == 'toggle_show_all') {
                setState(() {
                  _showAllBenchmarks = !_showAllBenchmarks;
                });
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'add_benchmark',
                  child: Row(
                    children: [
                      Icon(Icons.add_chart, color: Colors.blueGrey),
                      SizedBox(width: 8),
                      Text('Add Custom Benchmark'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_show_all',
                  child: Row(
                    children: [
                      Icon(
                        _showAllBenchmarks
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.blueGrey,
                      ),
                      const SizedBox(width: 8),
                      Text(_showAllBenchmarks
                          ? 'Hide Other Indices'
                          : 'Show All Indices'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              padding: const EdgeInsets.all(5.0),
              scrollDirection: Axis.horizontal,
              children: [
                _buildChip('YTD', ChartDateSpan.ytd),
                _buildChip('1Y', ChartDateSpan.year),
                _buildChip('2Y', ChartDateSpan.year_2),
                _buildChip('3Y', ChartDateSpan.year_3),
                _buildChip('5Y', ChartDateSpan.year_5),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : PerformanceChartWidget(
                    futureMarketIndexHistoricalsSp500:
                        _futureMarketIndexHistoricalsSp500,
                    futureMarketIndexHistoricalsNasdaq:
                        _futureMarketIndexHistoricalsNasdaq,
                    futureMarketIndexHistoricalsDow:
                        _futureMarketIndexHistoricalsDow,
                    futureMarketIndexHistoricalsRussell2000:
                        _futureMarketIndexHistoricalsRussell2000,
                    futurePortfolioHistoricalsYear: _futurePortfolioHistoricals,
                    benchmarkChartDateSpanFilter: _benchmarkChartDateSpanFilter,
                    onFilterChanged: (span) {
                      setState(() {
                        _benchmarkChartDateSpanFilter = span;
                        _loadData();
                      });
                      widget.onFilterChanged(span);
                    },
                    isFullScreen: true,
                    selectedBenchmark:
                        _showAllBenchmarks ? null : _selectedBenchmark,
                    futureCustomBenchmark: _futureCustomBenchmark,
                    customBenchmarkSymbol: _customBenchmarkSymbol,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, ChartDateSpan span) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ChoiceChip(
        label: Text(label),
        selected: _benchmarkChartDateSpanFilter == span,
        onSelected: (bool value) {
          if (value) {
            setState(() {
              _benchmarkChartDateSpanFilter = span;
              _loadData();
            });
            widget.onFilterChanged(span);
          }
        },
      ),
    );
  }
}

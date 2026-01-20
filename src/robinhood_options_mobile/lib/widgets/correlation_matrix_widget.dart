import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals_store.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/utils/analytics_utils.dart';
import 'package:robinhood_options_mobile/model/instrument_historicals.dart';
import 'package:robinhood_options_mobile/enums.dart';

class CorrelationMatrixWidget extends StatefulWidget {
  final BrokerageUser user;
  final IBrokerageService service;
  final List<String> symbols;

  const CorrelationMatrixWidget({
    super.key,
    required this.user,
    required this.service,
    required this.symbols,
  });

  @override
  State<CorrelationMatrixWidget> createState() =>
      _CorrelationMatrixWidgetState();
}

class _CorrelationMatrixWidgetState extends State<CorrelationMatrixWidget> {
  late Future<Map<String, Map<String, double>>> _correlationFuture;
  // Store sample sizes for debugging
  final Map<String, Map<String, int>> _sampleSizes = {};
  // Cache historicals to avoid re-fetching on filter change
  final InstrumentHistoricalsStore _historicalsStore =
      InstrumentHistoricalsStore();

  List<String> _selectedSymbols = [];
  int _loadedSymbols = 0;
  int _totalSymbols = 0;
  String? _loadingStatus;

  @override
  void initState() {
    super.initState();
    // Default to top 12 symbols
    _selectedSymbols = widget.symbols.take(12).toList();
    _totalSymbols = _selectedSymbols.length;
    _correlationFuture = _calculateCorrelationMatrix();
  }

  Future<Map<String, Map<String, double>>> _calculateCorrelationMatrix() async {
    // 1. Fetch historicals for all symbols
    final Map<String, List<double>> symbolReturns = {};
    final Map<String, List<DateTime>> symbolDates = {};

    _sampleSizes.clear();

    final symbolsToProcess = _selectedSymbols;

    for (final symbol in symbolsToProcess) {
      // Check cache first to avoid re-fetching
      final cached = _historicalsStore.items.firstWhereOrNull((h) =>
          h.symbol == symbol &&
          h.span == 'year' &&
          h.bounds == 'regular' &&
          h.interval == 'day');

      if (cached != null) {
        if (cached.historicals.isNotEmpty) {
          List<double> prices = [];
          List<DateTime> dates = [];
          for (var h in cached.historicals) {
            if (h.beginsAt != null &&
                (h.closePrice != null || h.openPrice != null)) {
              prices.add(h.closePrice ?? h.openPrice!);
              dates.add(h.beginsAt!);
            }
          }
          if (prices.length >= 2) {
            symbolDates[symbol] = dates;
            symbolReturns[symbol] = prices;
          }
        }
        if (mounted) {
          setState(() {
            _loadedSymbols++;
          });
        }
        continue;
      }

      setState(() {
        _loadingStatus = 'Fetching data for $symbol...';
      });

      try {
        final historicals = await widget.service.getInstrumentHistoricals(
            widget.user, _historicalsStore, symbol,
            chartDateSpanFilter: ChartDateSpan.year,
            chartBoundsFilter: Bounds.regular,
            chartInterval: 'day');

        if (historicals.historicals.isNotEmpty) {
          List<double> prices = [];
          List<DateTime> dates = [];
          for (var h in historicals.historicals) {
            if (h.beginsAt != null &&
                (h.closePrice != null || h.openPrice != null)) {
              prices.add(h.closePrice ?? h.openPrice!);
              dates.add(h.beginsAt!);
            }
          }
          if (prices.length >= 2) {
            symbolDates[symbol] = dates;
            symbolReturns[symbol] = prices;
          }
        }
      } catch (e) {
        debugPrint('Error fetching historicals for $symbol: $e');
      }

      if (mounted) {
        setState(() {
          _loadedSymbols++;
        });
      }
    }

    // 2. Find common dates across all symbols
    if (mounted) {
      setState(() {
        _loadingStatus = 'Calculating correlations...';
      });
    }

    Map<String, Map<String, double>> matrix = {};

    for (var sym1 in symbolsToProcess) {
      matrix[sym1] = {};
      _sampleSizes[sym1] = {};

      for (var sym2 in symbolsToProcess) {
        if (sym1 == sym2) {
          matrix[sym1]![sym2] = 1.0;
          _sampleSizes[sym1]![sym2] = symbolReturns[sym1]?.length ?? 0;
          continue;
        }

        // Optimize: Symmetric matrix.
        if (matrix.containsKey(sym2) && matrix[sym2]!.containsKey(sym1)) {
          matrix[sym1]![sym2] = matrix[sym2]![sym1]!;
          _sampleSizes[sym1]![sym2] = _sampleSizes[sym2]![sym1]!;
          continue;
        }

        // Align sym1 and sym2
        List<double> p1 = [];
        List<double> p2 = [];

        final dates1 = symbolDates[sym1];
        final dates2 = symbolDates[sym2];
        final prices1 = symbolReturns[sym1];
        final prices2 = symbolReturns[sym2];

        if (dates1 != null &&
            dates2 != null &&
            prices1 != null &&
            prices2 != null) {
          // Use string keys for more robust date matching (ignoring time/timezone shifts)
          Map<String, double> map2 = {};
          for (int i = 0; i < dates2.length; i++) {
            // Use UTC for consistent date string generation
            DateTime d = dates2[i].toUtc();
            String key = "${d.year}-${d.month}-${d.day}";
            map2[key] = prices2[i];
          }

          for (int i = 0; i < dates1.length; i++) {
            DateTime d = dates1[i].toUtc();
            String key = "${d.year}-${d.month}-${d.day}";
            if (map2.containsKey(key)) {
              p1.add(prices1[i]);
              p2.add(map2[key]!);
            }
          }
        }

        _sampleSizes[sym1]![sym2] = p1.length;

        if (p1.length > 10) {
          List<double> r1 = AnalyticsUtils.calculateDailyReturns(p1);
          List<double> r2 = AnalyticsUtils.calculateDailyReturns(p2);
          double corr = AnalyticsUtils.calculateCorrelation(r1, r2);
          matrix[sym1]![sym2] = corr;
        } else {
          matrix[sym1]![sym2] = 0.0;
        }
      }
    }

    return matrix;
  }

  void _showFilterDialog(BuildContext context) async {
    final portfolioSymbols = List<String>.from(widget.symbols);
    final benchmarkSymbols = ['SPY', 'QQQ', 'DIA', 'IWM', 'GLD', 'TLT'];
    final currentlySelected = List<String>.from(_selectedSymbols);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Select Assets (Max 15)'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setStateDialog(() {
                                  currentlySelected.clear();
                                });
                              },
                              child: const Text('Deselect All'),
                            ),
                          ],
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Text("Benchmarks",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                      ),
                      ...benchmarkSymbols.map((sym) {
                        final isSelected = currentlySelected.contains(sym);
                        return CheckboxListTile(
                          title: Text(sym),
                          value: isSelected,
                          dense: true,
                          onChanged: (bool? value) {
                            setStateDialog(() {
                              if (value == true) {
                                if (currentlySelected.length < 15) {
                                  currentlySelected.add(sym);
                                }
                              } else {
                                currentlySelected.remove(sym);
                              }
                            });
                          },
                        );
                      }),
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Text("Portfolio",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                      ),
                      ...portfolioSymbols.map((sym) {
                        final isSelected = currentlySelected.contains(sym);
                        return CheckboxListTile(
                          title: Text(sym),
                          value: isSelected,
                          dense: true,
                          onChanged: (bool? value) {
                            setStateDialog(() {
                              if (value == true) {
                                if (currentlySelected.length < 15) {
                                  currentlySelected.add(sym);
                                }
                              } else {
                                currentlySelected.remove(sym);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    // Update main state
                    setState(() {
                      _selectedSymbols = currentlySelected;
                      _loadedSymbols = 0;
                      _totalSymbols = _selectedSymbols.length;
                      _correlationFuture = _calculateCorrelationMatrix();
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Correlation Matrix'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
            tooltip: 'Select Assets',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showLegendDialog(context),
          )
        ],
      ),
      body: FutureBuilder<Map<String, Map<String, double>>>(
        future: _correlationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(_loadingStatus ?? 'Initializing...'),
                if (_totalSymbols > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child:
                        Text('$_loadedSymbols / $_totalSymbols symbols loaded'),
                  )
              ],
            ));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
                child: Text('No sufficient data for correlation analysis.'));
          }

          final matrix = snapshot.data!;
          final symbols = matrix.keys.toList();

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 2,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 50,
                      headingRowHeight: 40,
                      columns: [
                        const DataColumn(label: Text('')), // Corner
                        ...symbols.map((s) => DataColumn(
                            label: SizedBox(
                                width: 40,
                                child: Center(
                                    child: Text(s,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)))))),
                      ],
                      rows: symbols.map((symRow) {
                        return DataRow(cells: [
                          DataCell(Text(symRow,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12))),
                          ...symbols.map((symCol) {
                            final corr = matrix[symRow]?[symCol] ?? 0.0;
                            final isSelf = symRow == symCol;
                            return DataCell(
                              InkWell(
                                onTap: () => _showDetailDialog(
                                    context, symRow, symCol, corr),
                                child: Container(
                                  width: 40,
                                  height: 50,
                                  alignment: Alignment.center,
                                  color: isSelf
                                      ? Colors.grey.withOpacity(0.2)
                                      : _getColorForCorrelation(corr),
                                  child: isSelf
                                      ? const Text("1",
                                          style: TextStyle(
                                              fontSize: 10, color: Colors.grey))
                                      : Text(
                                          corr.toStringAsFixed(2),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  _getTextColorForCorrelation(
                                                      corr),
                                              fontWeight: FontWeight.w500),
                                        ),
                                ),
                              ),
                            );
                          })
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
              _buildLegend(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Correlation Strength",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    setState(() {
                      _loadedSymbols = 0;
                      _correlationFuture = _calculateCorrelationMatrix();
                    });
                  },
                  tooltip: 'Refresh Data')
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.blue, Colors.white, Colors.red],
                stops: [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
          ),
          const SizedBox(height: 5),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("-1.0", style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text("0.0", style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text("+1.0", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Inverse",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Text("Uncorrelated",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Text("Positive",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  void _showDetailDialog(
      BuildContext context, String sym1, String sym2, double corr) {
    int sampleSize = _sampleSizes[sym1]?[sym2] ?? 0;
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('$sym1 ↔ $sym2'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(corr.toStringAsFixed(4),
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color:
                              _getColorForCorrelation(corr).withOpacity(1.0))),
                  const SizedBox(height: 10),
                  Text(_getCorrelationDescription(corr),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text("Based on $sampleSize overlapping trading days.",
                      style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close"))
              ],
            ));
  }

  void _showLegendDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Correlation Analysis'),
              content: const SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        "This matrix displays the correlation coefficient (Pearson) between asset returns over the last year."),
                    SizedBox(height: 10),
                    Text(
                        "• +1.0: Perfect positive correlation. Assets move together."),
                    Text("• 0.0: No linear correlation."),
                    Text(
                        "• -1.0: Perfect negative correlation. Assets move in opposite directions."),
                    SizedBox(height: 10),
                    Text(
                        "Use this to check portfolio diversification. Ideally, you want a mix of assets with low correlation to reduce overall risk.")
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Got it"))
              ],
            ));
  }

  String _getCorrelationDescription(double corr) {
    if (corr > 0.7) {
      return "Strong positive correlation. These assets likely move in the same direction.";
    }
    if (corr > 0.3) return "Moderate positive correlation.";
    if (corr > -0.3) return "Low correlation. These assets move independently.";
    if (corr > -0.7) return "Moderate negative correlation.";
    return "Strong negative correlation. These assets often move in opposite directions (hedging effect).";
  }

  Color _getColorForCorrelation(double correlation) {
    if (correlation > 0) {
      // 0 to 1 -> White to Red
      return Colors.red.withOpacity(correlation.clamp(0.1, 1.0));
    } else {
      // 0 to -1 -> White to Blue
      return Colors.blue.withOpacity(correlation.abs().clamp(0.1, 1.0));
    }
  }

  Color _getTextColorForCorrelation(double correlation) {
    if (correlation.abs() > 0.6) return Colors.white;
    return Colors.black87;
  }
}

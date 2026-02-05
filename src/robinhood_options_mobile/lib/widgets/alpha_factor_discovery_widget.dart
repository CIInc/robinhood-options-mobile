import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';

class AlphaFactorDiscoveryWidget extends StatefulWidget {
  const AlphaFactorDiscoveryWidget({super.key});

  @override
  State<AlphaFactorDiscoveryWidget> createState() =>
      _AlphaFactorDiscoveryWidgetState();
}

class _AlphaFactorDiscoveryWidgetState
    extends State<AlphaFactorDiscoveryWidget> {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final TextEditingController _customUniverseController =
      TextEditingController();
  bool _isLoading = false;
  int _forwardHorizon = 5;
  List<dynamic> _results = [];
  String? _error;
  String _selectedUniverse = "Big Tech + Indices";
  String _sortOption = "Highest IC"; // Default sort
  String _selectedCategory = "All";
  String _searchQuery = "";
  late Set<String> _selectedFactorIds;

  final List<String> _universeOptions = [
    "Big Tech + Indices",
    "Portfolio",
    "Banking & Finance",
    "Energy & Utilities",
    "Healthcare & Pharma",
    "High Growth Tech",
    "Mag 7",
    "Semiconductors",
    "Real Estate (REITs)",
    "Custom Watchlist"
  ];

  final List<String> _bigTech = [
    "SPY",
    "QQQ",
    "IWM",
    "AAPL",
    "MSFT",
    "NVDA",
    "TSLA",
    "AMZN",
    "GOOGL",
    "META"
  ];
  final List<String> _banking = [
    "JPM",
    "BAC",
    "WFC",
    "C",
    "GS",
    "MS",
    "BLK",
    "AXP",
    "USB",
    "KRE"
  ];
  final List<String> _energy = [
    "XLE",
    "XOM",
    "CVX",
    "COP",
    "SLB",
    "EOG",
    "MPC",
    "PSX",
    "VLO",
    "OXY"
  ];
  final List<String> _healthcare = [
    "XLV",
    "UNH",
    "JNJ",
    "LLY",
    "ABBV",
    "MRK",
    "TMO",
    "DHR",
    "PFE",
    "AMGN"
  ];
  final List<String> _growth = [
    "ARKK",
    "PLTR",
    "COIN",
    "ROKU",
    "SQ",
    "SHOP",
    "TTD",
    "U",
    "DKNG",
    "PATH"
  ];
  final List<String> _mag7 = [
    "AAPL",
    "MSFT",
    "GOOGL",
    "AMZN",
    "NVDA",
    "META",
    "TSLA"
  ];
  final List<String> _semis = [
    "SMH",
    "NVDA",
    "TSM",
    "AVGO",
    "AMD",
    "QCOM",
    "TXN",
    "INTC",
    "MU",
    "LRCX"
  ];
  final List<String> _reits = [
    "VNQ",
    "PLD",
    "AMT",
    "EQIX",
    "PSA",
    "O",
    "WELL",
    "CSGP",
    "CCI",
    "DLR"
  ];

  List<String> _getSymbolsFor(String universe) {
    switch (universe) {
      case "Portfolio":
        final instrumentStore =
            Provider.of<InstrumentPositionStore>(context, listen: false);
        final optionStore =
            Provider.of<OptionPositionStore>(context, listen: false);
        final symbols = <String>{};
        symbols.addAll(instrumentStore.symbols);
        symbols.addAll(optionStore.symbols);
        return symbols.toList();
      case "Banking & Finance":
        return _banking;
      case "Energy & Utilities":
        return _energy;
      case "Healthcare & Pharma":
        return _healthcare;
      case "High Growth Tech":
        return _growth;
      case "Mag 7":
        return _mag7;
      case "Semiconductors":
        return _semis;
      case "Real Estate (REITs)":
        return _reits;
      case "Custom Watchlist":
        return _customUniverseController.text
            .split(',')
            .map((e) => e.trim().toUpperCase())
            .where((e) => e.isNotEmpty)
            .toList();
      case "Big Tech + Indices":
      default:
        return _bigTech;
    }
  }

  List<String> get _currentSymbols => _getSymbolsFor(_selectedUniverse);

  @override
  void initState() {
    super.initState();
    _selectedFactorIds = _defaultFactors.map((e) => e['id'] as String).toSet();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _selectedUniverse =
          prefs.getString('alpha_discovery_universe') ?? "Big Tech + Indices";
      _customUniverseController.text =
          prefs.getString('alpha_discovery_custom_symbols') ?? "";
      _forwardHorizon = prefs.getInt('alpha_discovery_horizon') ?? 5;
      final savedFactorIds = prefs.getStringList('alpha_discovery_factors');
      if (savedFactorIds != null) {
        _selectedFactorIds = savedFactorIds.toSet();
      }

      _sortOption = prefs.getString('alpha_discovery_sort') ?? "Highest IC";
      _selectedCategory = prefs.getString('alpha_discovery_category') ?? "All";

      final startMillis = prefs.getInt('alpha_discovery_date_start');
      final endMillis = prefs.getInt('alpha_discovery_date_end');
      if (startMillis != null && endMillis != null) {
        _selectedDateRange = DateTimeRange(
            start: DateTime.fromMillisecondsSinceEpoch(startMillis),
            end: DateTime.fromMillisecondsSinceEpoch(endMillis));
      } else {
        _selectedDateRange = null;
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alpha_discovery_universe', _selectedUniverse);
    await prefs.setString(
        'alpha_discovery_custom_symbols', _customUniverseController.text);
    await prefs.setInt('alpha_discovery_horizon', _forwardHorizon);
    await prefs.setStringList(
        'alpha_discovery_factors', _selectedFactorIds.toList());
    await prefs.setString('alpha_discovery_sort', _sortOption);
    await prefs.setString('alpha_discovery_category', _selectedCategory);

    if (_selectedDateRange != null) {
      await prefs.setInt('alpha_discovery_date_start',
          _selectedDateRange!.start.millisecondsSinceEpoch);
      await prefs.setInt('alpha_discovery_date_end',
          _selectedDateRange!.end.millisecondsSinceEpoch);
    } else {
      await prefs.remove('alpha_discovery_date_start');
      await prefs.remove('alpha_discovery_date_end');
    }
  }

  @override
  void dispose() {
    _customUniverseController.dispose();
    super.dispose();
  }

  DateTimeRange? _selectedDateRange;

  final List<Map<String, dynamic>> _defaultFactors = [
    {
      "id": "rsi_14",
      "name": "RSI (14)",
      "type": "RSI",
      "parameters": {"period": 14},
      "description":
          "Relative Strength Index. A momentum oscillator measuring the speed and change of price movements. High values indicate overbought conditions, low values indicate oversold."
    },
    {
      "id": "sma_dist_50",
      "name": "SMA Distance (50)",
      "type": "SMA_DISTANCE",
      "parameters": {"period": 50},
      "description":
          "Percentage distance of the current price from its 50-day Simple Moving Average. Measures trend extension."
    },
    {
      "id": "sma_dist_200",
      "name": "SMA Distance (200)",
      "type": "SMA_DISTANCE",
      "parameters": {"period": 200},
      "description":
          "Percentage distance of the current price from its 200-day Simple Moving Average. Indicates long-term trend strength."
    },
    {
      "id": "momentum_10",
      "name": "Momentum (10d)",
      "type": "MOMENTUM",
      "parameters": {"period": 10},
      "description":
          "Rate of change in price over the last 10 days. Pure trend following indicator."
    },
    {
      "id": "momentum_21",
      "name": "Momentum (21d)",
      "type": "MOMENTUM",
      "parameters": {"period": 21},
      "description":
          "Rate of change in price over the last 21 days (approx. 1 month)."
    },
    {
      "id": "macd_signal",
      "name": "MACD Histogram (12,26,9)",
      "type": "MACD_SIGNAL",
      "parameters": {"fast": 12, "slow": 26, "signal": 9},
      "description":
          "Difference between MACD line and Signal line. Represents the strength of the trend's momentum."
    },
    {
      "id": "bb_width_20",
      "name": "Bollinger Band Width (20,2)",
      "type": "BB_WIDTH",
      "parameters": {"period": 20, "stdDev": 2},
      "description":
          "Width of Bollinger Bands normalized by price. Measures market volatility; low width often precedes a breakout."
    },
    {
      "id": "stoch_k_14_3",
      "name": "Stochastic %K (14,3)",
      "type": "STOCHASTIC_K",
      "parameters": {"kPeriod": 14, "dPeriod": 3},
      "description":
          "Location of the close relative to the high-low range over 14 days. 0-100 oscillator."
    },
    {
      "id": "atr_14",
      "name": "ATR (14)",
      "type": "ATR",
      "parameters": {"period": 14},
      "description":
          "Average True Range. Measures market volatility irrespective of direction."
    },
    {
      "id": "adx_14",
      "name": "ADX (14)",
      "type": "ADX",
      "parameters": {"period": 14},
      "description":
          "Average Directional Index. Quantifies trend strength (0-100) regardless of trend direction. >25 suggests strong trend."
    },
    {
      "id": "cci_20",
      "name": "CCI (20)",
      "type": "CCI",
      "parameters": {"period": 20},
      "description":
          "Commodity Channel Index. Measures deviation from statistical average price. useful for finding cyclical reversals."
    },
    {
      "id": "obv_mom_5",
      "name": "OBV Momentum (5d)",
      "type": "OBV",
      "parameters": {"period": 5},
      "description":
          "On-Balance Volume rate of change. Uses volume flow to predict price changes before they happen."
    },
    {
      "id": "keltner_pos_20",
      "name": "Keltner Position (20, 1.5)",
      "type": "KELTNER_POSITION",
      "parameters": {"period": 20, "atrPeriod": 10, "multiplier": 1.5},
      "description":
          "Position of price relative to Keltner Channels (EMA +/- ATR). Identifies extreme deviations from the mean."
    },
    {
      "id": "williams_r_14",
      "name": "Williams %R (14)",
      "type": "WILLIAMS_R",
      "parameters": {"period": 14},
      "description":
          "Momentum oscillator measuring overbought/oversold levels. Similar to Stochastic Fast but inverted scale (0 to -100)."
    },
    {
      "id": "roc_9",
      "name": "Rate of Change (9)",
      "type": "ROC",
      "parameters": {"period": 9},
      "description":
          "Pure momentum oscillator processing the percentage change in price. Focuses on velocity of the trend."
    },
    {
      "id": "mfi_14",
      "name": "MFI (14)",
      "type": "MFI",
      "parameters": {"period": 14},
      "description":
          "Money Flow Index. Volume-weighted RSI. Identifies potential reversals when price and money flow diverge."
    }
  ];

  final Map<String, String> _factorCategories = {
    "RSI": "Oscillators",
    "STOCHASTIC_K": "Oscillators",
    "CCI": "Oscillators",
    "MACD_SIGNAL": "Oscillators",
    "WILLIAMS_R": "Oscillators",
    "MFI": "Oscillators",
    "SMA_DISTANCE": "Trend",
    "ADX": "Trend",
    "MOMENTUM": "Trend",
    "OBV": "Trend",
    "ROC": "Trend",
    "BB_WIDTH": "Volatility",
    "ATR": "Volatility",
    "KELTNER_POSITION": "Volatility"
  };

  Future<void> _runDiscovery() async {
    _savePreferences(); // Save state before running
    setState(() {
      _isLoading = true;
      _error = null;
      _results = [];
    });

    try {
      final activeFactors = _defaultFactors
          .where((f) => _selectedFactorIds.contains(f['id']))
          .toList();

      if (_currentSymbols.isEmpty) {
        setState(() {
          _error = "Please specify at least one symbol in the universe.";
          _isLoading = false;
        });
        return;
      }

      if (activeFactors.isEmpty) {
        setState(() {
          _error = "Please select at least one factor to analyze.";
          _isLoading = false;
        });
        return;
      }

      final callable = _functions.httpsCallable('discoverAlphaFactors');
      final result = await callable.call({
        "symbols": _currentSymbols,
        "factors": activeFactors,
        "forwardHorizon": _forwardHorizon,
        if (_selectedDateRange != null) ...{
          "startDate":
              _selectedDateRange!.start.toIso8601String().split('T')[0],
          "endDate": _selectedDateRange!.end.toIso8601String().split('T')[0],
        }
      });

      final data = result.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _results = data['results'] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showFactorFilterDialog() {
    showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(builder: (context, setState) {
            final grouped = <String, List<Map<String, dynamic>>>{};
            for (var f in _defaultFactors) {
              final cat = _factorCategories[f['type']] ?? "Other";
              grouped.putIfAbsent(cat, () => []).add(f);
            }
            final sortedKeys = grouped.keys.toList()..sort();

            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                      child: Text("Select Active Factors",
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                  TextButton(
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: () {
                        setState(() {
                          if (_selectedFactorIds.length ==
                              _defaultFactors.length) {
                            _selectedFactorIds.clear();
                          } else {
                            _selectedFactorIds = _defaultFactors
                                .map((e) => e['id'] as String)
                                .toSet();
                          }
                        });
                      },
                      child: Text(
                          _selectedFactorIds.length == _defaultFactors.length
                              ? "Deselect All"
                              : "Select All",
                          style: const TextStyle(fontSize: 13)))
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: sortedKeys.expand((cat) {
                    final factors = grouped[cat]!;
                    final bool isAllSelected = factors
                        .every((f) => _selectedFactorIds.contains(f['id']));

                    return [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(cat,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold)),
                            TextButton(
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 24),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap),
                              child: Text(
                                  isAllSelected ? "Deselect All" : "Select All",
                                  style: const TextStyle(fontSize: 11)),
                              onPressed: () {
                                setState(() {
                                  if (isAllSelected) {
                                    for (var f in factors) {
                                      _selectedFactorIds
                                          .remove(f['id'] as String);
                                    }
                                  } else {
                                    for (var f in factors) {
                                      _selectedFactorIds.add(f['id'] as String);
                                    }
                                  }
                                });
                              },
                            )
                          ],
                        ),
                      ),
                      ...factors.map((factor) {
                        final id = factor['id'] as String;
                        final isSelected = _selectedFactorIds.contains(id);
                        return CheckboxListTile(
                          title: Text(factor['name'],
                              style: const TextStyle(fontSize: 14)),
                          subtitle: Text(
                            factor['description'] ?? "",
                            style: const TextStyle(fontSize: 11),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          dense: true,
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedFactorIds.add(id);
                              } else {
                                _selectedFactorIds.remove(id);
                              }
                            });
                          },
                        );
                      })
                    ];
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () {
                      this.setState(() {}); // Update main widget
                      _savePreferences();
                      Navigator.pop(context);
                    },
                    child: const Text("Done"))
              ],
            );
          });
        });
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Metric Definitions"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpItem("IC (Information Coefficient)",
                  "The Pearson correlation between the factor value and future returns. Values close to 1.0 indicate strong positive predictive power (buy signal). Values close to -1.0 indicate strong inverse predictive power (sell signal). Values near 0 indicate no signal."),
              const SizedBox(height: 12),
              _buildHelpItem("ICIR (Information Ratio of IC)",
                  "IC divided by the standard deviation of IC across the universe. Measures the consistency of the factor's quality relative to its volatility. Higher absolute values are better."),
              const SizedBox(height: 12),
              _buildHelpItem("Volatility (StdDev)",
                  "Standard deviation of the IC across different symbols. Lower values mean the factor behaves similarly across all assets in the universe (spatially consistent)."),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(description, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          if (!_isLoading) {
            await _runDiscovery();
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              title: const Text('Alpha Factor Discovery'),
              floating: true,
              pinned: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: _showHelpDialog,
                  tooltip: "Metrics Info",
                )
              ],
            ),
            SliverToBoxAdapter(child: _buildHeader(theme)),
            if (_error != null) SliverToBoxAdapter(child: _buildError()),
            if (_isLoading)
              SliverFillRemaining(
                child: _buildLoadingState(theme),
              )
            else if (_results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(theme),
              )
            else
              ..._buildResultsSlivers(theme),
          ],
        ),
      ),
      floatingActionButton: (_results.isEmpty && !_isLoading)
          ? null
          : FloatingActionButton.extended(
              onPressed: _isLoading ? null : _runDiscovery,
              icon: const Icon(Icons.science),
              label: const Text('Run Analysis'),
            ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text("Crunching market data...", style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          "Analyzing correlations across ${_currentSymbols.length} instruments...",
          style: theme.textTheme.bodySmall,
        ),
      ],
    ));
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.primaryContainer.withOpacity(0.5)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                "Quantitative Research Workbench",
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Discover predictive alpha factors by analyzing correlation with future returns.",
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                  Icons.public,
                  "Universe: $_selectedUniverse (${_currentSymbols.length})",
                  theme,
                  onTap: _showUniverseSelector),
              _buildInfoChip(
                  Icons.timer, "Horizon: $_forwardHorizon Days", theme,
                  onTap: () async {
                final selected = await showModalBottomSheet<int>(
                    context: context,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(16))),
                    builder: (ctx) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text("Select Prediction Horizon",
                                    style: theme.textTheme.titleMedium),
                              ),
                              const Divider(height: 1),
                              ...[1, 3, 5, 10, 21].map((val) => ListTile(
                                    title: Text("$val Days"),
                                    trailing: _forwardHorizon == val
                                        ? Icon(Icons.check,
                                            color: theme.colorScheme.primary)
                                        : null,
                                    onTap: () => Navigator.pop(ctx, val),
                                  )),
                            ],
                          ),
                        ));
                if (selected != null) {
                  setState(() => _forwardHorizon = selected);
                  _savePreferences();
                }
              }),
              _buildInfoChip(
                  Icons.functions,
                  _selectedFactorIds.length == _defaultFactors.length
                      ? "Factors: All (${_defaultFactors.length})"
                      : "Factors: ${_selectedFactorIds.length}/${_defaultFactors.length}",
                  theme,
                  onTap: _showFactorFilterDialog,
                  highlight:
                      _selectedFactorIds.length != _defaultFactors.length),
            ],
          ),
          const SizedBox(height: 12),
          _buildDateSelector(theme),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, ThemeData theme,
      {VoidCallback? onTap, bool highlight = false}) {
    Widget container = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: highlight
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: onTap != null && !highlight
              ? Border.all(color: theme.colorScheme.onSurface.withOpacity(0.3))
              : null),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 14,
              color: highlight
                  ? theme.colorScheme.onTertiaryContainer
                  : theme.colorScheme.onSurface),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
                  color: highlight
                      ? theme.colorScheme.onTertiaryContainer
                      : theme.colorScheme.onSurface)),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                size: 16,
                color: highlight
                    ? theme.colorScheme.onTertiaryContainer
                    : theme.colorScheme.onSurface.withOpacity(0.8))
          ]
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: container,
      );
    }
    return container;
  }

  void _showUniverseSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final theme = Theme.of(context);
          return Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Select Universe",
                      style: theme.textTheme.titleMedium),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _universeOptions.map((option) {
                        final isSelected = _selectedUniverse == option;
                        String? subtitle;
                        if (option != "Custom Watchlist") {
                          final preview = _getSymbolsFor(option);
                          if (preview.isNotEmpty) {
                            subtitle = preview.take(5).join(", ");
                            if (preview.length > 5) {
                              subtitle += ", +${preview.length - 5}";
                            }
                          } else if (option == "Portfolio") {
                            subtitle = "No positions found";
                          }
                        }

                        if (option == "Custom Watchlist") {
                          return Column(children: [
                            ListTile(
                              title: Text(option),
                              subtitle: const Text("Enter symbols manually"),
                              trailing: isSelected
                                  ? Icon(Icons.check,
                                      color: theme.colorScheme.primary)
                                  : null,
                              onTap: () {
                                setModalState(() => _selectedUniverse = option);
                                setState(() {});
                                _savePreferences();
                              },
                            ),
                            if (isSelected)
                              Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: TextField(
                                      controller: _customUniverseController,
                                      decoration: const InputDecoration(
                                        labelText: "Symbols (comma separated)",
                                        hintText: "AAPL, MSFT, TSLA...",
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (_) {
                                        setState(() {});
                                        _savePreferences();
                                      }))
                          ]);
                        }
                        return ListTile(
                          title: Text(option),
                          subtitle: subtitle != null
                              ? Text(subtitle,
                                  maxLines: 1, overflow: TextOverflow.ellipsis)
                              : null,
                          trailing: isSelected
                              ? Icon(Icons.check,
                                  color: theme.colorScheme.primary)
                              : null,
                          onTap: () {
                            setModalState(() => _selectedUniverse = option);
                            setState(() {});
                            _savePreferences();
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSortSelector() {
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (context) {
          final theme = Theme.of(context);
          final options = [
            "Highest IC",
            "Lowest IC",
            "Highest ICIR",
            "Lowest Volatility"
          ];
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Sort Results By",
                      style: theme.textTheme.titleMedium),
                ),
                const Divider(height: 1),
                ...options.map((opt) => ListTile(
                      title: Text(opt),
                      trailing: _sortOption == opt
                          ? Icon(Icons.check, color: theme.colorScheme.primary)
                          : null,
                      onTap: () {
                        setState(() => _sortOption = opt);
                        _savePreferences();
                        Navigator.pop(context);
                      },
                    ))
              ],
            ),
          );
        });
  }

  Widget _buildDateSelector(ThemeData theme) {
    final now = DateTime.now();
    final presets = [
      {"label": "Default (2Y)", "start": null, "end": null},
      {
        "label": "Last 1 Month",
        "start": now.subtract(const Duration(days: 30)),
        "end": now
      },
      {
        "label": "Last 3 Months",
        "start": now.subtract(const Duration(days: 90)),
        "end": now
      },
      {
        "label": "Last 6 Months",
        "start": now.subtract(const Duration(days: 180)),
        "end": now
      },
      {"label": "YTD", "start": DateTime(now.year, 1, 1), "end": now},
      {
        "label": "Last 1 Year",
        "start": now.subtract(const Duration(days: 365)),
        "end": now
      },
      {
        "label": "2024 Bull Run",
        "start": DateTime(2024, 1, 1),
        "end": DateTime(2024, 12, 31)
      },
      {
        "label": "2022 Bear Market",
        "start": DateTime(2022, 1, 1),
        "end": DateTime(2022, 12, 31)
      },
    ];

    bool isCustom = true;
    for (final p in presets) {
      if (_isRangeMatch(p['start'] as DateTime?, p['end'] as DateTime?)) {
        isCustom = false;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...presets.map((p) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildDatePresetChip(p['label'] as String,
                        p['start'] as DateTime?, p['end'] as DateTime?, theme),
                  )),
              ActionChip(
                label: Text("Custom",
                    style: TextStyle(
                        fontSize: 11,
                        color: _isLoading
                            ? null
                            : (isCustom
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onPrimaryContainer),
                        fontWeight:
                            isCustom ? FontWeight.bold : FontWeight.normal)),
                backgroundColor: _isLoading
                    ? null
                    : (isCustom
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.5)),
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                side: isCustom ? BorderSide.none : null,
                onPressed: _isLoading
                    ? null
                    : () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2010),
                          lastDate: DateTime.now(),
                          initialDateRange: _selectedDateRange ??
                              DateTimeRange(
                                  start: DateTime.now()
                                      .subtract(const Duration(days: 365)),
                                  end: DateTime.now()),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDateRange = picked;
                          });
                          _savePreferences();
                        }
                      },
              ),
            ],
          ),
        ),
        if (isCustom)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: InkWell(
              onTap: _isLoading
                  ? null
                  : () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2010),
                        lastDate: DateTime.now(),
                        initialDateRange: _selectedDateRange ??
                            DateTimeRange(
                                start: DateTime.now()
                                    .subtract(const Duration(days: 365)),
                                end: DateTime.now()),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDateRange = picked;
                        });
                        _savePreferences();
                      }
                    },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: "Custom Range",
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                  filled: true,
                  fillColor: theme.colorScheme.surface.withValues(alpha: 0.7),
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    // Clear custom range -> Reverts to Default (null)
                    onPressed: () => setState(() => _selectedDateRange = null),
                  ),
                ),
                child: Text(
                  _selectedDateRange == null
                      ? "Select Dates"
                      : "${_selectedDateRange!.start.toLocal().toString().split(' ')[0]} - ${_selectedDateRange!.end.toLocal().toString().split(' ')[0]}",
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _isRangeMatch(DateTime? start, DateTime? end) {
    if (start == null && end == null) {
      return _selectedDateRange == null;
    }
    if (_selectedDateRange == null) return false;
    final s = _selectedDateRange!.start;
    final e = _selectedDateRange!.end;
    return s.year == start!.year &&
        s.month == start.month &&
        s.day == start.day &&
        e.year == end!.year &&
        e.month == end.month &&
        e.day == end.day;
  }

  Widget _buildDatePresetChip(
      String label, DateTime? start, DateTime? end, ThemeData theme) {
    bool isSelected = _isRangeMatch(start, end);

    return ActionChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: _isLoading
                  ? null
                  : (isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onPrimaryContainer),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      backgroundColor: _isLoading
          ? null
          : (isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.primaryContainer.withValues(alpha: 0.5)),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      side: isSelected ? BorderSide.none : null,
      onPressed: _isLoading
          ? null
          : () {
              setState(() {
                if (start == null || end == null) {
                  _selectedDateRange = null;
                } else {
                  _selectedDateRange = DateTimeRange(start: start, end: end);
                }
              });
              _savePreferences();
            },
    );
  }

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red, size: 20),
            onPressed: () => setState(() => _error = null),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_graph,
                  size: 48, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text("Discover Alpha Factors",
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              "Run a correlation analysis across your selected universe to find predictive indicators.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _isLoading ? null : _runDiscovery,
              icon: const Icon(Icons.play_arrow),
              label: const Text("Start Analysis"),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResultsSlivers(ThemeData theme) {
    // Filter Logic
    List<dynamic> filteredResults = _results.where((item) {
      final name = (item['config']['name'] as String).toLowerCase();
      final matchesSearch =
          _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      if (_selectedCategory == "All") return true;
      String type = item['config']['type'];
      String? cat = _factorCategories[type];
      return cat == _selectedCategory;
    }).toList();

    // Sorting logic
    List<dynamic> sortedResults = List.from(filteredResults);
    switch (_sortOption) {
      case "Highest IC":
        sortedResults.sort((a, b) => ((b['globalIC'] ?? 0) as num)
            .compareTo((a['globalIC'] ?? 0) as num));
        break;
      case "Lowest IC":
        sortedResults.sort((a, b) => ((a['globalIC'] ?? 0) as num)
            .compareTo((b['globalIC'] ?? 0) as num));
        break;
      case "Highest ICIR":
        sortedResults.sort((a, b) => ((b['icir'] ?? 0) as num)
            .abs()
            .compareTo(((a['icir'] ?? 0) as num).abs()));
        break;
      case "Lowest Volatility":
        sortedResults.sort((a, b) => ((a['icStdDev'] ?? 0) as num)
            .compareTo((b['icStdDev'] ?? 0) as num));
        break;
    }

    return [
      SliverToBoxAdapter(
        child: Column(
          children: [
            if (_results.isNotEmpty &&
                _searchQuery.isEmpty &&
                _selectedCategory == "All")
              _buildDiscoverySummary(theme),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Search factors (e.g. 'RSI', 'MACD')...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 0),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                      _savePreferences();
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Filter Chips
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              "All",
                              "Trend",
                              "Oscillators",
                              "Volatility"
                            ].map((cat) {
                              final isSelected = _selectedCategory == cat;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(cat),
                                  selected: isSelected,
                                  onSelected: (bool selected) {
                                    if (selected) {
                                      setState(() => _selectedCategory = cat);
                                      _savePreferences();
                                    }
                                  },
                                  selectedColor:
                                      theme.colorScheme.primaryContainer,
                                  labelStyle: TextStyle(
                                      color: isSelected
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.onSurfaceVariant,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Sort Selector
                      ActionChip(
                        avatar: Icon(Icons.sort,
                            size: 18, color: theme.colorScheme.primary),
                        label: Text(_sortOption),
                        onPressed: _showSortSelector,
                        backgroundColor: theme.colorScheme.surface,
                        side: BorderSide(
                            color: theme.colorScheme.outlineVariant
                                .withOpacity(0.5)),
                      )
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
          ],
        ),
      ),
      if (sortedResults.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_alt_off,
                    size: 48,
                    color: theme.colorScheme.onSurface.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text("No factors match your filters.",
                    style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6))),
                const SizedBox(height: 8),
                TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _searchQuery = "";
                        _selectedCategory = "All";
                      });
                      _savePreferences();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text("Clear Filters"))
              ],
            ),
          ),
        )
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = sortedResults[index];
              final factor = item['config'];
              final ic = (item['globalIC'] ?? 0) as num;
              final icir = (item['icir'] ?? 0) as num;
              final stdDev = (item['icStdDev'] ?? 0) as num;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ExpansionTile(
                  title: Row(
                    children: [
                      Expanded(
                          child: Text(factor['name'],
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                      IconButton(
                        icon: Icon(Icons.info_outline,
                            size: 20, color: theme.colorScheme.primary),
                        onPressed: () {
                          showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                    title: Text(factor['name']),
                                    content: Text(factor['description'] ??
                                        "No description available for this factor."),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text("Close"))
                                    ],
                                  ));
                        },
                      )
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ic.abs() > 0.05)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Icon(
                                    ic > 0
                                        ? Icons.trending_up
                                        : Icons.trending_down,
                                    size: 16,
                                    color: ic > 0 ? Colors.green : Colors.red),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                      ic > 0
                                          ? "Positive Correlation: High factor values predict price increases."
                                          : "Inverse Correlation: High factor values predict price drops.",
                                      style: TextStyle(
                                          color: ic > 0
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        _buildMetricBar(ic.toDouble(), theme),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatItem("IC", ic.toStringAsFixed(4), theme,
                                color: ic > 0.05
                                    ? Colors.green
                                    : (ic < -0.05 ? Colors.red : null)),
                            _buildStatItem(
                                "ICIR", icir.toStringAsFixed(2), theme,
                                suffix: _buildConsistencyBadge(icir, theme)),
                            _buildStatItem(
                                "Vol", stdDev.toStringAsFixed(3), theme),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Best Performer Summary
                        if (item['symbolBreakdown'] != null &&
                            (item['symbolBreakdown'] as List).isNotEmpty)
                          Builder(builder: (context) {
                            final breakdown = item['symbolBreakdown'] as List;
                            final sorted = List<dynamic>.from(breakdown);
                            sorted.sort((a, b) => (b['correlation'] as num)
                                .compareTo(a['correlation']));
                            final best = sorted.first;
                            final worst = sorted.last;

                            return Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: theme
                                      .colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.arrow_upward,
                                        size: 14, color: Colors.green),
                                    const SizedBox(width: 4),
                                    Text(best['symbol'],
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    Text(
                                        (best['correlation'] as num)
                                            .toStringAsFixed(2),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold))
                                  ]),
                                  Row(children: [
                                    Text(
                                        (worst['correlation'] as num)
                                            .toStringAsFixed(2),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    Text(worst['symbol'],
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.arrow_downward,
                                        size: 14, color: Colors.red),
                                  ])
                                ],
                              ),
                            );
                          })
                      ],
                    ),
                  ),
                  children: [
                    const Divider(),
                    _buildSymbolBreakdown(item['symbolBreakdown'], theme),
                  ],
                ),
              );
            },
            childCount: sortedResults.length,
          ),
        ),
      const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
    ];
  }

  Widget _buildMetricBar(double ic, ThemeData theme) {
    // IC is essentially -1 to 1.
    // We want a bar that starts in the middle.
    // Normalized to 0..1 where 0.5 is 0.
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("-1.0 (Inv)",
                style: TextStyle(
                    fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
            Text("0.0",
                style: TextStyle(
                    fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
            Text("1.0 (Corr)",
                style: TextStyle(
                    fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final center = width / 2;
              // Amplify magnitude for visibility since ICs are often small (0.1 is significant)
              // We'll scale it so 0.3 fills the half-bar.
              final scaledIC = (ic * 3.3).clamp(-1.0, 1.0);
              final magnitude =
                  (scaledIC.abs() * (width / 2)).clamp(0.0, width / 2);

              return Stack(
                children: [
                  // Center tick
                  Positioned(
                      left: center,
                      width: 1,
                      top: 0,
                      bottom: 0,
                      child: Container(
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5))),

                  Positioned(
                    left: ic < 0 ? center - magnitude : center,
                    width: magnitude,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                          color: ic > 0 ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(4)),
                    ),
                  )
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, ThemeData theme,
      {Color? color, Widget? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Row(
          children: [
            Text(value,
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color ?? theme.colorScheme.onSurface)),
            if (suffix != null) ...[const SizedBox(width: 4), suffix]
          ],
        ),
      ],
    );
  }

  Widget _buildConsistencyBadge(num icir, ThemeData theme) {
    final abs = icir.abs();
    Color color;
    String text;

    if (abs > 1.0) {
      color = Colors.amber;
      text = "★ High";
    } else if (abs > 0.5) {
      color = Colors.blue;
      text = "Med";
    } else {
      return const SizedBox.shrink();
    }

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4)),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: color)));
  }

  Widget _buildSymbolBreakdown(List<dynamic> breakdown, ThemeData theme) {
    if (breakdown.isEmpty) return const SizedBox.shrink();

    // Sort by correlation
    final sorted = List<dynamic>.from(breakdown);
    // Sort descending by correlation for the list logic,
    // but here we want to show a Heatmap of ALL symbols.
    sorted
        .sort((a, b) => (b['correlation'] as num).compareTo(a['correlation']));

    final topPositive =
        sorted.where((e) => (e['correlation'] as num) > 0.0).take(10).toList();
    final topNegative = sorted
        .where((e) => (e['correlation'] as num) < 0.0)
        .toList()
        .reversed
        .take(10)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topPositive.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Strongest Positive Correlations",
                    style: theme.textTheme.labelSmall),
                InkWell(
                  onTap: () async {
                    final text = topPositive.map((e) => e['symbol']).join(", ");
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Copied symbols to clipboard"),
                          duration: Duration(seconds: 1)));
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text("Copy",
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.primary)),
                  ),
                )
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
                spacing: 8,
                children: topPositive
                    .map((e) => ActionChip(
                          label: Text(
                              "${e['symbol']} ${(e['correlation'] as num).toStringAsFixed(2)}"),
                          padding: EdgeInsets.zero,
                          labelStyle: const TextStyle(fontSize: 11),
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                          side: BorderSide.none,
                          onPressed: () {
                            // No-op for now, but implies interactivity
                          },
                        ))
                    .toList()),
            const SizedBox(height: 12),
          ],
          if (topNegative.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Strongest Inverse Correlations",
                    style: theme.textTheme.labelSmall),
                InkWell(
                  onTap: () async {
                    final text = topNegative.map((e) => e['symbol']).join(", ");
                    await Clipboard.setData(ClipboardData(text: text));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Copied symbols to clipboard"),
                          duration: Duration(seconds: 1)));
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text("Copy",
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.primary)),
                  ),
                )
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
                spacing: 8,
                children: topNegative
                    .map((e) => ActionChip(
                          label: Text(
                              "${e['symbol']} ${(e['correlation'] as num).toStringAsFixed(2)}"),
                          padding: EdgeInsets.zero,
                          labelStyle: const TextStyle(fontSize: 11),
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          side: BorderSide.none,
                          onPressed: () {},
                        ))
                    .toList()),
            const SizedBox(height: 12),
          ],
          Text("Correlation Heatmap (${breakdown.length} symbols)",
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sorted.map((item) {
              final sym = item['symbol'];
              final corr = (item['correlation'] as num).toDouble();
              final isPositive = corr > 0;
              final intensity = corr.abs().clamp(0.0, 1.0); // 0 to 1

              // Scale color opacity by intensity
              final color = isPositive
                  ? Colors.green.withValues(alpha: 0.2 + (0.8 * intensity))
                  : Colors.red.withValues(alpha: 0.2 + (0.8 * intensity));

              return InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:
                        Text("$sym Correlation: ${corr.toStringAsFixed(4)}"),
                    duration: const Duration(seconds: 2),
                    action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
                  ));
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: color.withValues(alpha: 1.0), width: 1)),
                  child: Text(sym,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: intensity > 0.5
                              ? Colors.white
                              : theme.colorScheme.onSurface)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverySummary(ThemeData theme) {
    if (_results.isEmpty) return const SizedBox.shrink();

    // Calculate bests
    var bestIC = _results[0];
    var bestICIR = _results[0];

    for (var r in _results) {
      if (((r['globalIC'] ?? 0) as num).abs() >
          ((bestIC['globalIC'] ?? 0) as num).abs()) {
        bestIC = r;
      }
      if (((r['icir'] ?? 0) as num).abs() >
          ((bestICIR['icir'] ?? 0) as num).abs()) {
        bestICIR = r;
      }
    }

    // Category Analysis
    final Map<String, List<double>> catScores = {};
    for (var r in _results) {
      final type = r['config']['type'] as String;
      final cat = _factorCategories[type] ?? "Other";
      if (!catScores.containsKey(cat)) catScores[cat] = [];
      catScores[cat]!.add(((r['globalIC'] ?? 0) as num).abs().toDouble());
    }

    String bestCat = "None";
    double bestCatScore = 0.0;

    catScores.forEach((k, v) {
      if (v.isNotEmpty) {
        final avg = v.reduce((a, b) => a + b) / v.length;
        if (avg > bestCatScore) {
          bestCatScore = avg;
          bestCat = k;
        }
      }
    });

    return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.tertiaryContainer
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome, size: 16),
            const SizedBox(width: 8),
            Text("Discovery Highlights",
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _buildSummaryStat(
                    "Top Signal Strength",
                    bestIC['config']['name'],
                    "${(((bestIC['globalIC'] ?? 0) as num) * 100).toStringAsFixed(1)}% IC",
                    theme)),
            Container(
                width: 1,
                height: 40,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1)),
            const SizedBox(width: 16),
            Expanded(
                child: _buildSummaryStat(
                    "Most Consistent",
                    bestICIR['config']['name'],
                    "${((bestICIR['icir'] ?? 0) as num).toStringAsFixed(2)} Ratio",
                    theme)),
          ]),
          if (bestCatScore > 0.0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.trending_up,
                    size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  "Strongest Category: ",
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                Text(
                  "$bestCat (Avg IC: ${(bestCatScore * 100).toStringAsFixed(1)}%)",
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                )
              ],
            )
          ]
        ]));
  }

  Widget _buildSummaryStat(
      String label, String value, String sub, ThemeData theme) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      const SizedBox(height: 4),
      Text(value,
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      Text(sub,
          style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
    ]);
  }
}

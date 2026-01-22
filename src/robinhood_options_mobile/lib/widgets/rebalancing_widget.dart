import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:convert';
import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/forex_holding_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/investment_profile.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/model/portfolio_store.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/chart_pie_widget.dart';

class RebalancingWidget extends StatefulWidget {
  final User user;
  final DocumentReference<User> userDocRef;
  final Account account;

  const RebalancingWidget(
      {super.key,
      required this.user,
      required this.userDocRef,
      required this.account});

  @override
  State<RebalancingWidget> createState() => _RebalancingWidgetState();
}

class _RebalancingWidgetState extends State<RebalancingWidget> {
  final Map<String, double> _assetTargets = {
    'Stocks': 0,
    'Options': 0,
    'Crypto': 0,
    'Cash': 0,
  };
  final Map<String, double> _sectorTargets = {};
  Map<String, double>? _assetTargetsBackup;
  Map<String, double>? _sectorTargetsBackup;
  bool _isEditing = false;
  int _viewMode = 0; // 0: Asset Class, 1: Sector
  final NumberFormat formatCurrency =
      NumberFormat.simpleCurrency(locale: "en_US");
  final NumberFormat formatPercentage =
      NumberFormat.decimalPercentPattern(decimalDigits: 1);
  double _driftThreshold = 100.0;

  static const List<String> _standardSectors = [
    'Technology',
    'Financial Services',
    'Consumer Cyclical',
    'Healthcare',
    'Communication Services',
    'Industrials',
    'Consumer Defensive',
    'Energy',
    'Real Estate',
    'Basic Materials',
    'Utilities',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.user.assetAllocationTargets != null) {
      _assetTargets.addAll(widget.user.assetAllocationTargets!);
    }
    if (widget.user.sectorAllocationTargets != null) {
      _sectorTargets.addAll(widget.user.sectorAllocationTargets!);
    }
  }

  void _startEditing() {
    setState(() {
      _assetTargetsBackup = Map.from(_assetTargets);
      _sectorTargetsBackup = Map.from(_sectorTargets);
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      if (_assetTargetsBackup != null) {
        _assetTargets.clear();
        _assetTargets.addAll(_assetTargetsBackup!);
      }
      if (_sectorTargetsBackup != null) {
        _sectorTargets.clear();
        _sectorTargets.addAll(_sectorTargetsBackup!);
      }
      _isEditing = false;
    });
  }

  Future<void> _saveTargets() async {
    final targets = _viewMode == 0 ? _assetTargets : _sectorTargets;
    final sum = targets.values.fold(0.0, (a, b) => a + b);
    if ((sum - 1.0).abs() > 0.01 && targets.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Total allocation must be 100%. Current: ${formatPercentage.format(sum)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_viewMode == 0) {
      await widget.userDocRef.update({'assetAllocationTargets': _assetTargets});
      widget.user.assetAllocationTargets = Map.from(_assetTargets);
    } else {
      await widget.userDocRef
          .update({'sectorAllocationTargets': _sectorTargets});
      widget.user.sectorAllocationTargets = Map.from(_sectorTargets);
    }

    setState(() {
      _isEditing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Allocation targets saved')));
    }
  }

  void _normalizeTargets() {
    final targets = _viewMode == 0 ? _assetTargets : _sectorTargets;
    final sum = targets.values.fold(0.0, (a, b) => a + b);
    if (sum == 0) return;

    setState(() {
      targets.updateAll((key, value) => value / sum);
    });
  }

  void _applyPreset(String name) {
    setState(() {
      if (_viewMode == 0) {
        // Asset Class Presets
        switch (name) {
          case 'Aggressive':
            _assetTargets['Stocks'] = 0.8;
            _assetTargets['Options'] = 0.1;
            _assetTargets['Crypto'] = 0.1;
            _assetTargets['Cash'] = 0.0;
            break;
          case 'Moderate':
            _assetTargets['Stocks'] = 0.6;
            _assetTargets['Options'] = 0.05;
            _assetTargets['Crypto'] = 0.05;
            _assetTargets['Cash'] = 0.3;
            break;
          case 'Conservative':
            _assetTargets['Stocks'] = 0.4;
            _assetTargets['Options'] = 0.0;
            _assetTargets['Crypto'] = 0.0;
            _assetTargets['Cash'] = 0.6;
            break;
          case 'All Equity':
            _assetTargets['Stocks'] = 1.0;
            _assetTargets['Options'] = 0.0;
            _assetTargets['Crypto'] = 0.0;
            _assetTargets['Cash'] = 0.0;
            break;
        }
      } else {
        // Sector Presets
        _sectorTargets.clear(); // Clear existing to avoid mixing
        switch (name) {
          case 'Tech Heavy':
            _sectorTargets['Technology'] = 0.5;
            _sectorTargets['Consumer Cyclical'] = 0.2;
            _sectorTargets['Communication Services'] = 0.2;
            _sectorTargets['Financial Services'] = 0.1;
            break;
          case 'Balanced':
            _sectorTargets['Technology'] = 0.2;
            _sectorTargets['Healthcare'] = 0.15;
            _sectorTargets['Financial Services'] = 0.15;
            _sectorTargets['Consumer Cyclical'] = 0.1;
            _sectorTargets['Industrials'] = 0.1;
            _sectorTargets['Consumer Defensive'] = 0.1;
            _sectorTargets['Energy'] = 0.05;
            _sectorTargets['Utilities'] = 0.05;
            _sectorTargets['Real Estate'] = 0.05;
            _sectorTargets['Basic Materials'] = 0.05;
            break;
          case 'Defensive':
            _sectorTargets['Healthcare'] = 0.3;
            _sectorTargets['Consumer Defensive'] = 0.3;
            _sectorTargets['Utilities'] = 0.2;
            _sectorTargets['Energy'] = 0.1;
            _sectorTargets['Real Estate'] = 0.1;
            break;
        }
      }
    });
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rebalancing Settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text('Drift Threshold for Recommendations',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _driftThreshold,
                          min: 0,
                          max: 1000,
                          divisions: 20,
                          label: formatCurrency.format(_driftThreshold),
                          onChanged: (value) {
                            setModalState(() {
                              _driftThreshold = value;
                            });
                            setState(() {
                              _driftThreshold = value;
                            });
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(formatCurrency.format(_driftThreshold),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Text(
                      'Recommendations will be triggered if the drift exceeds this amount.',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _optimizeWithAI() async {
    final risks = InvestmentProfile.riskToleranceOptions;
    final horizons = InvestmentProfile.timeHorizonOptions;
    final goals = InvestmentProfile.investmentGoalOptions;

    // Defaults from user profile or fallbacks - ensure value is in list
    String selectedRisk =
        widget.user.investmentProfile?.riskTolerance ?? 'Moderate';
    if (!risks.contains(selectedRisk)) selectedRisk = 'Moderate';

    String selectedHorizon =
        widget.user.investmentProfile?.timeHorizon ?? 'Medium Term (3-7 yrs)';
    if (!horizons.contains(selectedHorizon)) {
      selectedHorizon = 'Medium Term (3-7 yrs)';
    }

    String selectedGoal =
        widget.user.investmentProfile?.investmentGoals ?? 'Growth';
    if (!goals.contains(selectedGoal)) selectedGoal = 'Growth';

    final bool? proceed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('AI Allocation Strategy'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'Define your investor profile to generate personalized allocation targets.'),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRisk,
                      decoration: const InputDecoration(
                        labelText: 'Risk Tolerance',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.speed),
                      ),
                      items: risks.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => selectedRisk = newValue);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedHorizon,
                      decoration: const InputDecoration(
                        labelText: 'Time Horizon',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      items: horizons.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => selectedHorizon = newValue);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGoal,
                      decoration: const InputDecoration(
                        labelText: 'Investment Goal',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag),
                      ),
                      items: goals.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => selectedGoal = newValue);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate Strategy'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        );
      },
    );

    if (proceed != true) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );
    }

    try {
      // 1. Update User Profile
      final profileData = widget.user.investmentProfile?.toJson() ?? {};
      profileData['riskTolerance'] = selectedRisk;
      profileData['timeHorizon'] = selectedHorizon;
      profileData['investmentGoals'] = selectedGoal;

      if (widget.user.investmentProfile == null) {
        widget.user.investmentProfile = InvestmentProfile(
          riskTolerance: selectedRisk,
          timeHorizon: selectedHorizon,
          investmentGoals: selectedGoal,
        );
      } else {
        widget.user.investmentProfile!.riskTolerance = selectedRisk;
        widget.user.investmentProfile!.timeHorizon = selectedHorizon;
        widget.user.investmentProfile!.investmentGoals = selectedGoal;
      }
      // Fire and forget update
      widget.userDocRef.update({'investmentProfile': profileData});

      // 2. Generate Content
      String portfolioContext = "";
      if (widget.user.investmentProfile?.totalPortfolioValue != null) {
        portfolioContext =
            "- Portfolio Value: ${formatCurrency.format(widget.user.investmentProfile!.totalPortfolioValue)}\n";
      }

      final prompt =
          "Acting as a senior portfolio manager, suggest a specific portfolio allocation (Stocks, Options, Crypto, Cash) and Sector allocation for an investor with the following profile:\n"
          "- Risk Tolerance: $selectedRisk\n"
          "- Time Horizon: $selectedHorizon\n"
          "- Primary Goal: $selectedGoal\n"
          "$portfolioContext\n"
          "Return ONLY a clean JSON object (no markdown formatting) with this structure:\n"
          "{\n"
          "  \"explanation\": \"A concise 2-3 sentence explanation of why this allocation fits the profile.\",\n"
          "  \"assets\": {\"Stocks\": 0.60, \"Options\": 0.10, \"Crypto\": 0.05, \"Cash\": 0.25},\n"
          "  \"sectors\": {\"Technology\": 0.30, \"Financial Services\": 0.20, ... (ensure covering major sectors, sum to 1.0)}\n"
          "}\n"
          "Ensure all percentages in 'assets' sum exactly to 1.0, and 'sectors' sum exactly to 1.0.";

      final result = await FirebaseFunctions.instance
          .httpsCallable('generateContent25')
          .call({'prompt': prompt});

      // 3. Process Result
      String responseText =
          result.data['candidates'][0]['content']['parts'][0]['text'];

      int startIndex = responseText.indexOf('{');
      int endIndex = responseText.lastIndexOf('}');
      if (startIndex == -1 || endIndex == -1) {
        throw const FormatException('No JSON object found in response');
      }
      final jsonStr = responseText.substring(startIndex, endIndex + 1);
      final data = jsonDecode(jsonStr);
      final String explanation =
          data['explanation'] ?? 'No explanation provided.';

      // Dismiss Loading Indicator
      if (mounted) Navigator.of(context).pop();

      // 4. Show Recommendation Dialog
      if (mounted) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('AI Recommendation'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lightbulb, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              explanation,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Asset Allocation',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ...(data['assets'] as Map<String, dynamic>)
                        .entries
                        .map((e) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key),
                                Text(
                                    '${((e.value as num).toDouble() * 100).toStringAsFixed(1)}%'),
                              ],
                            )),
                    const SizedBox(height: 16),
                    Text('Sector Allocation',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    ...(data['sectors'] as Map<String, dynamic>)
                        .entries
                        .take(5) // Just show top 5 for preview
                        .map((e) => Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key),
                                Text(
                                    '${((e.value as num).toDouble() * 100).toStringAsFixed(1)}%'),
                              ],
                            )),
                    if ((data['sectors'] as Map).length > 5)
                      Text('...and ${(data['sectors'] as Map).length - 5} more',
                          style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Dismiss'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                FilledButton(
                  child: const Text('Apply Strategy'),
                  onPressed: () {
                    setState(() {
                      if (!_isEditing) {
                        _assetTargetsBackup = Map.from(_assetTargets);
                        _sectorTargetsBackup = Map.from(_sectorTargets);
                        _isEditing = true;
                      }
                      if (data['assets'] != null) {
                        _assetTargets.clear();
                        Map<String, dynamic> assets = data['assets'];
                        assets.forEach(
                            (k, v) => _assetTargets[k] = (v as num).toDouble());
                      }
                      if (data['sectors'] != null) {
                        _sectorTargets.clear();
                        Map<String, dynamic> sectors = data['sectors'];
                        sectors.forEach((k, v) =>
                            _sectorTargets[k] = (v as num).toDouble());
                      }
                    });
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Targets updated. Review and Save.')),
                    );
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        // Dismiss Loading Dialog
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating strategy: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isEditing,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final bool? shouldPop = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard Changes?'),
            content: const Text(
                'You have unsaved changes. Are you sure you want to discard them?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (shouldPop == true) {
          _cancelEditing(); // Reset changes if discarding
          if (context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Portfolio Rebalance'),
          actions: [
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              onPressed: _optimizeWithAI,
              tooltip: "AI Optimization",
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showSettings,
            ),
            if (_isEditing)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _cancelEditing,
                tooltip: "Cancel",
              ),
            IconButton(
              icon: Icon(_isEditing ? Icons.save : Icons.edit),
              onPressed: _isEditing ? _saveTargets : _startEditing,
              tooltip: _isEditing ? "Save" : "Edit",
            ),
          ],
        ),
        bottomNavigationBar: _isEditing
            ? BottomAppBar(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Total: ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            formatPercentage.format((_viewMode == 0
                                    ? _assetTargets
                                    : _sectorTargets)
                                .values
                                .fold(0.0, (a, b) => a + b)),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: ((_viewMode == 0
                                                      ? _assetTargets
                                                      : _sectorTargets)
                                                  .values
                                                  .fold(0.0, (a, b) => a + b) -
                                              1.0)
                                          .abs() >
                                      0.01
                                  ? Colors.red
                                  : Colors.green,
                            ),
                          ),
                        ],
                      ),
                      FilledButton.icon(
                        onPressed: _normalizeTargets,
                        icon: const Icon(Icons.balance),
                        label: const Text('Normalize'),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        body: Consumer4<PortfolioStore, InstrumentPositionStore,
            OptionPositionStore, ForexHoldingStore>(
          builder: (context, portfolioStore, stockPositionStore,
              optionPositionStore, forexHoldingStore, child) {
            // Calculate current allocation
            double stockEquity = 0;
            final Map<String, double> sectorEquity = {};

            // Treat SGOV and other short-term treasury ETFs as Cash
            double cashEtfsValue = 0.0;
            final cashEtfSymbols = [
              'SGOV',
              'BIL',
              'SHV',
              'USFR',
              'TFLO',
              'TBIL',
              'BILS',
              'SHT',
              'GBIL',
              'CLTL',
              'VGSH',
              'SCHO'
            ];

            for (var item in stockPositionStore.items) {
              // Use marketValue for accurate allocation (was using cost basis before)
              final equity = item.marketValue;

              if (item.instrumentObj?.symbol != null &&
                  cashEtfSymbols.contains(item.instrumentObj!.symbol)) {
                cashEtfsValue += equity;
              } else {
                stockEquity += equity;

                final sector =
                    item.instrumentObj?.fundamentalsObj?.sector ?? 'Unknown';
                sectorEquity[sector] = (sectorEquity[sector] ?? 0) + equity;
              }
            }

            double optionEquity = 0;
            for (var item in optionPositionStore.items) {
              // Use marketValue for accurate allocation
              optionEquity += item.marketValue;
            }

            double cryptoEquity = 0;
            for (var item in forexHoldingStore.items) {
              if (item.quantity != null &&
                  item.quoteObj != null &&
                  item.quoteObj!.markPrice != null) {
                cryptoEquity += item.quantity! * item.quoteObj!.markPrice!;
              }
            }

            double cashEquity =
                (widget.account.portfolioCash ?? 0) + cashEtfsValue;

            final totalEquity =
                stockEquity + optionEquity + cryptoEquity + cashEquity;

            if (totalEquity == 0) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pie_chart_outline,
                        size: 64, color: Theme.of(context).colorScheme.outline),
                    const SizedBox(height: 16),
                    Text('No portfolio data available',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('Add positions to see allocation analysis',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              );
            }

            final currentAssetAllocation = {
              'Stocks': stockEquity / totalEquity,
              'Options': optionEquity / totalEquity,
              'Crypto': cryptoEquity / totalEquity,
              'Cash': cashEquity / totalEquity,
            };

            final currentSectorAllocation = sectorEquity.map((key, value) =>
                MapEntry(key, value / totalEquity)); // Sector % of TOTAL equity

            // Ensure all sectors in current allocation are in targets (init with 0 if missing)
            if (_sectorTargets.isEmpty && currentSectorAllocation.isNotEmpty) {
              // Initialize targets with current if empty
              // Or just ensure keys exist
            }
            for (var key in currentSectorAllocation.keys) {
              if (!_sectorTargets.containsKey(key)) {
                _sectorTargets[key] = 0;
              }
            }

            final currentAllocation = _viewMode == 0
                ? currentAssetAllocation
                : currentSectorAllocation;
            final targets = _viewMode == 0 ? _assetTargets : _sectorTargets;

            final allKeys = _viewMode == 0
                ? ['Stocks', 'Options', 'Crypto', 'Cash']
                : {
                    ...currentSectorAllocation.keys,
                    ..._sectorTargets.keys,
                    ..._standardSectors
                  }.toList();
            if (_viewMode == 1) {
              allKeys.sort();
            }

            final colorScheme = Theme.of(context).colorScheme;
            var brightness = MediaQuery.of(context).platformBrightness;

            // Helper function to get darker color in dark theme
            Color getDarkerColorForTheme(Color color) {
              if (brightness == Brightness.dark) {
                return Color.lerp(color, Colors.black, 0.2) ?? color;
              }
              return color;
            }

            // var assetPalette = [
            //   charts.ColorUtil.fromDartColor(
            //       getDarkerColorForTheme(colorScheme.primary)),
            //   charts.ColorUtil.fromDartColor(
            //       getDarkerColorForTheme(colorScheme.secondary)),
            //   charts.ColorUtil.fromDartColor(
            //       getDarkerColorForTheme(colorScheme.tertiary)),
            //   charts.ColorUtil.fromDartColor(
            //       getDarkerColorForTheme(colorScheme.primaryContainer)),
            // ];
            final assetPalette = [
              getDarkerColorForTheme(colorScheme.primary),
              getDarkerColorForTheme(colorScheme.secondary),
              getDarkerColorForTheme(colorScheme.tertiary),
              getDarkerColorForTheme(colorScheme.inversePrimary),
            ];

            final assetColors = {
              'Stocks': assetPalette[0],
              'Options': assetPalette[3],
              'Crypto': assetPalette[2],
              'Cash': assetPalette[1],
            };

            final sectorPalette = [
              Colors.teal.shade800,
              Colors.indigo.shade800,
              Colors.orange.shade900,
              Colors.pink.shade800,
              Colors.green.shade900,
              Colors.deepPurple.shade800,
              Colors.lightBlue.shade900,
              Colors.red.shade900,
              Colors.brown.shade800,
              Colors.cyan.shade900,
              Colors.deepOrange.shade900,
              Colors.blueGrey.shade800,
            ];
            // getDarkerColorForTheme(colorScheme.secondary),
            // getDarkerColorForTheme(colorScheme.primary),
            // getDarkerColorForTheme(colorScheme.tertiary),
            // getDarkerColorForTheme(colorScheme.secondaryContainer),
            // getDarkerColorForTheme(colorScheme.primaryContainer),
            // getDarkerColorForTheme(colorScheme.tertiaryContainer),
            // getDarkerColorForTheme(colorScheme.inversePrimary),
            // getDarkerColorForTheme(colorScheme.errorContainer),
            // getDarkerColorForTheme(colorScheme.surfaceTint),
            // getDarkerColorForTheme(colorScheme.outline),
            // getDarkerColorForTheme(colorScheme.outlineVariant),

            // var sectorPalette = PieChart.makeShades(
            //     charts.ColorUtil.fromDartColor(
            //         getDarkerColorForTheme(colorScheme.secondary)),
            //     sectorEquity.isNotEmpty ? sectorEquity.length : 1);

            final sectorColors = <String, Color>{};
            if (_viewMode == 1) {
              for (int i = 0; i < allKeys.length; i++) {
                sectorColors[allKeys[i]] =
                    sectorPalette[i % sectorPalette.length];
                // sectorColors[allKeys[i]] = charts.ColorUtil.toDartColor(
                //     sectorPalette[i % sectorPalette.length]);
              }
            }

            Color getColor(String key) {
              if (_viewMode == 0) {
                return assetColors[key] ?? Colors.grey;
              } else {
                return sectorColors[key] ?? Colors.grey;
              }
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Asset Class')),
                      ButtonSegment(value: 1, label: Text('Sector')),
                    ],
                    selected: {_viewMode},
                    onSelectionChanged: (Set<int> newSelection) {
                      setState(() {
                        _viewMode = newSelection.first;
                        _isEditing =
                            false; // Exit edit mode when switching views
                      });
                    },
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      if (_isEditing) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              const Text('Presets: ',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              ...(_viewMode == 0
                                      ? [
                                          'Aggressive',
                                          'Moderate',
                                          'Conservative',
                                          'All Equity'
                                        ]
                                      : ['Tech Heavy', 'Balanced', 'Defensive'])
                                  .map((preset) => Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8.0),
                                        child: ActionChip(
                                          label: Text(preset),
                                          onPressed: () => _applyPreset(preset),
                                        ),
                                      )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (!_isEditing) ...[
                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: SizedBox(
                              height: 220,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text('Current',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: PieChart(
                                            [
                                              charts.Series<PieChartData,
                                                  String>(
                                                id: 'Current',
                                                domainFn:
                                                    (PieChartData sales, _) =>
                                                        sales.label,
                                                measureFn:
                                                    (PieChartData sales, _) =>
                                                        sales.value,
                                                colorFn: (PieChartData row,
                                                        _) =>
                                                    charts.ColorUtil
                                                        .fromDartColor(getColor(
                                                            row.label)),
                                                data: allKeys
                                                    .where((k) =>
                                                        (currentAllocation[k] ??
                                                            0) >
                                                        0)
                                                    .map((k) => PieChartData(
                                                        k,
                                                        currentAllocation[k] ??
                                                            0))
                                                    .toList(),
                                                labelAccessorFn: (PieChartData
                                                            row,
                                                        _) =>
                                                    '${row.label}\n${formatPercentage.format(row.value)}',
                                              )
                                            ],
                                            animate: false,
                                            renderer: charts.ArcRendererConfig(
                                              arcWidth: 60,
                                              arcRendererDecorators: [
                                                charts.ArcLabelDecorator(
                                                    labelPosition: charts
                                                        .ArcLabelPosition.auto)
                                              ],
                                            ),
                                            onSelected: (p0) {},
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const VerticalDivider(width: 32),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text('Target',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        Expanded(
                                          child: PieChart(
                                            [
                                              charts.Series<PieChartData,
                                                  String>(
                                                id: 'Target',
                                                domainFn:
                                                    (PieChartData sales, _) =>
                                                        sales.label,
                                                measureFn:
                                                    (PieChartData sales, _) =>
                                                        sales.value,
                                                colorFn: (PieChartData row,
                                                        _) =>
                                                    charts.ColorUtil
                                                        .fromDartColor(getColor(
                                                            row.label)),
                                                data: allKeys
                                                    .where((k) =>
                                                        (targets[k] ?? 0) > 0)
                                                    .map((k) => PieChartData(
                                                        k, targets[k] ?? 0))
                                                    .toList(),
                                                labelAccessorFn: (PieChartData
                                                            row,
                                                        _) =>
                                                    '${row.label}\n${formatPercentage.format(row.value)}',
                                              )
                                            ],
                                            animate: false,
                                            renderer: charts.ArcRendererConfig(
                                              arcWidth: 60,
                                              arcRendererDecorators: [
                                                charts.ArcLabelDecorator(
                                                    labelPosition: charts
                                                        .ArcLabelPosition.auto)
                                              ],
                                            ),
                                            onSelected: (p0) {},
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      ...allKeys.map((key) {
                        final currentPct = currentAllocation[key] ?? 0.0;
                        final targetPct = targets[key] ?? 0.0;
                        return _buildAllocationCard(
                            key,
                            currentPct * totalEquity,
                            currentPct,
                            targetPct,
                            totalEquity,
                            targets,
                            getColor(key));
                      }),
                      const SizedBox(height: 20),
                      if (!_isEditing)
                        _buildRecommendations(
                            currentAllocation, targets, totalEquity),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAllocationCard(
      String title,
      double currentAmount,
      double currentPct,
      double targetPct,
      double totalEquity,
      Map<String, double> targets,
      Color color) {
    final diff = currentPct - targetPct;
    final driftAmount = diff * totalEquity;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
                Text(formatCurrency.format(currentAmount),
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            // Comparison Bars
            Column(
              children: [
                // Current Bar
                Row(
                  children: [
                    SizedBox(
                        width: 60,
                        child: Text('Current',
                            style: Theme.of(context).textTheme.bodySmall)),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: currentPct.clamp(0.0, 1.0),
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                        width: 50,
                        child: Text(formatPercentage.format(currentPct),
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
                const SizedBox(height: 8),
                // Target Bar
                Row(
                  children: [
                    SizedBox(
                        width: 60,
                        child: Text('Target',
                            style: Theme.of(context).textTheme.bodySmall)),
                    Expanded(
                      child: _isEditing
                          ? Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    setState(() {
                                      targets[title] =
                                          (targetPct - 0.01).clamp(0.0, 1.0);
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: targetPct,
                                    min: 0,
                                    max: 1,
                                    divisions: 100,
                                    label: formatPercentage.format(targetPct),
                                    activeColor: color,
                                    onChanged: (value) {
                                      setState(() {
                                        targets[title] = value;
                                      });
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    setState(() {
                                      targets[title] =
                                          (targetPct + 0.01).clamp(0.0, 1.0);
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            )
                          : Stack(
                              children: [
                                Container(
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: targetPct.clamp(0.0, 1.0),
                                  child: Container(
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                        width: 50,
                        child: Text(formatPercentage.format(targetPct),
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
              ],
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Drift', style: Theme.of(context).textTheme.bodyMedium),
                  Row(
                    children: [
                      Text(
                        formatCurrency.format(driftAmount.abs()),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        diff.abs() < 0.05 ? Icons.check_circle : Icons.warning,
                        size: 16,
                        color: diff.abs() < 0.05 ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatPercentage.format(diff),
                        style: TextStyle(
                          color:
                              diff.abs() < 0.05 ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendations(Map<String, double> currentAllocation,
      Map<String, double> targets, double totalEquity) {
    final recommendations = <Map<String, dynamic>>[];

    currentAllocation.forEach((key, currentPct) {
      final targetPct = targets[key] ?? 0;
      final diff = targetPct - currentPct;
      final amount = diff * totalEquity;

      if (amount.abs() > _driftThreshold) {
        recommendations.add({
          'key': key,
          'amount': amount,
          'targetPct': targetPct,
        });
      }
    });

    // Sort by absolute amount descending
    recommendations.sort((a, b) =>
        (b['amount'] as double).abs().compareTo((a['amount'] as double).abs()));

    if (recommendations.isEmpty) {
      return Card(
        elevation: 0,
        color: Colors.green.withValues(alpha: 0.1),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Portfolio is balanced!',
                  style: TextStyle(
                      color: Colors.green, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: Text('Rebalancing Recommendations',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer)),
          ),
          ...recommendations.map((rec) {
            final key = rec['key'] as String;
            final amount = rec['amount'] as double;
            final targetPct = rec['targetPct'] as double;
            final action = amount > 0
                ? (key == 'Cash' ? 'Raise' : 'Buy')
                : (key == 'Cash' ? 'Invest' : 'Sell');
            final color = amount > 0 ? Colors.green : Colors.red;

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.1),
                child:
                    Icon(amount > 0 ? Icons.add : Icons.remove, color: color),
              ),
              title: Text('$action $key',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Target: ${formatPercentage.format(targetPct)}'),
              trailing: Text(
                formatCurrency.format(amount.abs()),
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            );
          }),
        ],
      ),
    );
  }
}

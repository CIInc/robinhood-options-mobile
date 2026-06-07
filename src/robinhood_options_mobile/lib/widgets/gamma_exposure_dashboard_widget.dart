import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/gamma_exposure_model.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/gamma_exposure_widget.dart';

class GammaExposureDashboardWidget extends StatefulWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;
  final GenerativeService? generativeService;

  const GammaExposureDashboardWidget({
    super.key,
    this.user,
    this.userDocRef,
    this.brokerageUser,
    this.service,
    this.analytics,
    this.observer,
    this.generativeService,
  });

  @override
  State<GammaExposureDashboardWidget> createState() =>
      _GammaExposureDashboardWidgetState();
}

class _GammaExposureDashboardWidgetState
    extends State<GammaExposureDashboardWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _activeSymbol = 'SPY';
  final List<String> _recentSymbols = [];

  List<GammaExposureData>? _topGexData;
  bool _loadingTopGex = false;
  String? _topGexError;

  void _addRecentSymbol(String sym) {
    if (sym.isEmpty) return;
    final cleanSym = sym.toUpperCase();
    if (!['SPY', 'QQQ', 'IWM', 'TSLA', 'NVDA', 'AAPL'].contains(cleanSym)) {
      setState(() {
        _recentSymbols.remove(cleanSym);
        _recentSymbols.insert(0, cleanSym);
        if (_recentSymbols.length > 5) {
          _recentSymbols.removeLast();
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchTopGEX();
  }

  Future<void> _fetchTopGEX() async {
    setState(() {
      _loadingTopGex = true;
      _topGexError = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getTopGammaExposure');
      final result = await callable.call<Map<String, dynamic>>();
      final responseMap = Map<String, dynamic>.from(result.data as Map);

      if (responseMap['status'] == 'ok' && responseMap['data'] != null) {
        final List<dynamic> list = responseMap['data'] as List<dynamic>;
        final dataList = list.map((e) => GammaExposureData.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        if (mounted) {
          setState(() {
            _topGexData = dataList;
            _loadingTopGex = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _topGexError = responseMap['message'] ?? 'Failed to load top GEX';
            _loadingTopGex = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _topGexError = e.toString();
          _loadingTopGex = false;
        });
      }
    }
  }

  Widget _buildTopGexLeaders(BuildContext context) {
    final theme = Theme.of(context);
    if (_loadingTopGex) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Fetching live GEX leaders...', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );
    }
    if (_topGexError != null || _topGexData == null) {
      return Card(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
              const SizedBox(height: 8),
              Text('Failed to load GEX leaders', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error)),
              const SizedBox(height: 4),
              Text(_topGexError ?? 'Unknown error', style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _fetchTopGEX,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
        ),
      );
    }

    final leaders = _topGexData!;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.troubleshoot, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Gamma Exposure Leaders',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _fetchTopGEX,
                  tooltip: 'Refresh Leaders',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Market makers net dealer positioning for major indices & equities. Tap any row to load detail chart.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leaders.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            itemBuilder: (context, index) {
              final item = leaders[index];
              final isCurrent = item.symbol == _activeSymbol;
              final positioningColor = item.dealerPositioning == DealerPositioning.longGamma
                  ? Colors.green
                  : item.dealerPositioning == DealerPositioning.shortGamma
                      ? Colors.red
                      : theme.colorScheme.outline;

              return InkWell(
                onTap: () {
                  setState(() {
                    _activeSymbol = item.symbol;
                  });
                  FocusScope.of(context).unfocus();
                },
                child: Container(
                  color: isCurrent ? theme.colorScheme.primary.withValues(alpha: 0.05) : null,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.symbol,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isCurrent ? theme.colorScheme.primary : null,
                              ),
                            ),
                            Text(
                              '\$${item.spotPrice.toStringAsFixed(2)}',
                              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.formattedNetGEX,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: item.totalNetGEX >= 0 ? Colors.green : Colors.red,
                                  ),
                                ),
                                Text(
                                  'C/P: ${(item.gexRatio * 100).toStringAsFixed(0)}/${((1 - item.gexRatio) * 100).toStringAsFixed(0)}',
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.outline),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: SizedBox(
                                height: 4,
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: (item.gexRatio * 100).round().clamp(1, 99),
                                      child: Container(color: Colors.green.withValues(alpha: 0.8)),
                                    ),
                                    Expanded(
                                      flex: ((1 - item.gexRatio) * 100).round().clamp(1, 99),
                                      child: Container(color: Colors.red.withValues(alpha: 0.8)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: positioningColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: positioningColor.withValues(alpha: 0.2)),
                        ),
                        child: Text(
                          item.dealerPositioning.displayLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: positioningColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gamma Exposure Dashboard'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Enter symbol (e.g. TSLA, NVDA)',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () {
                      if (_searchController.text.isNotEmpty) {
                        final val = _searchController.text.toUpperCase();
                        setState(() {
                          _activeSymbol = val;
                        });
                        _addRecentSymbol(val);
                        _searchController.clear();
                        FocusScope.of(context).unfocus();
                      }
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    final val = value.toUpperCase();
                    setState(() {
                      _activeSymbol = val;
                    });
                    _addRecentSymbol(val);
                    _searchController.clear();
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8,
                children:
                    ['SPY', 'QQQ', 'IWM', 'TSLA', 'NVDA', 'AAPL'].map((sym) {
                  final isSelected = _activeSymbol == sym;
                  return ChoiceChip(
                    label: Text(sym),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _activeSymbol = sym;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
            ),
            if (_recentSymbols.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(Icons.history,
                        size: 16,
                        color: Theme.of(context).colorScheme.outline),
                    const SizedBox(width: 4),
                    ..._recentSymbols.map((sym) {
                      final isSelected = _activeSymbol == sym;
                      return ChoiceChip(
                        label: Text(sym, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _activeSymbol = sym;
                            });
                          }
                        },
                      );
                    }),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildTopGexLeaders(context),
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Analysis for $_activeSymbol',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: GammaExposureWidget(
                symbol: _activeSymbol,
                generativeService: widget.generativeService,
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Understanding GEX',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gamma Exposure (GEX) measures the net gamma held by option market makers. '
                      'It indicates how dealers will hedge their positions as price changes.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    _buildEduItem(
                      context,
                      Icons.compress,
                      Colors.green,
                      'Positive GEX (Long Gamma)',
                      'Dealers buy dips and sell rips to hedge. This creates a "pinning" effect, reducing volatility and supporting the price.',
                    ),
                    const SizedBox(height: 12),
                    _buildEduItem(
                      context,
                      Icons.expand,
                      Colors.red,
                      'Negative GEX (Short Gamma)',
                      'Dealers must sell as price falls and buy as price rises. This amplifies moves and increases volatility (trending environment).',
                    ),
                    const SizedBox(height: 12),
                    _buildEduItem(
                      context,
                      Icons.compare_arrows,
                      Colors.orange,
                      'Gamma Flip Level',
                      'The price level where net GEX transitions from positive to negative. Below this level, volatility tends to expand rapidly.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildEduItem(BuildContext context, IconData icon, Color color,
      String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(description, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

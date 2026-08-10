import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/gamma_exposure_model.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/option_position_store.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/widgets/gamma_exposure_widget.dart';
import 'package:robinhood_options_mobile/widgets/indicator_documentation_widget.dart';

enum _GexSortMode { magnitude, proximity }

class PortfolioGexDashboardWidget extends StatefulWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final FirebaseAnalytics? analytics;
  final FirebaseAnalyticsObserver? observer;
  final GenerativeService? generativeService;

  const PortfolioGexDashboardWidget({
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
  State<PortfolioGexDashboardWidget> createState() =>
      _PortfolioGexDashboardWidgetState();
}

class _PortfolioGexDashboardWidgetState
    extends State<PortfolioGexDashboardWidget> {
  List<GammaExposureData>? _portfolioGexData;
  bool _isLoading = true;
  bool _amplifyingOnly = false;
  _GexSortMode _sortMode = _GexSortMode.magnitude;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPortfolioGEX();
  }

  Future<void> _fetchPortfolioGEX() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<String> symbolsToFetch = [];

      if (mounted) {
        final instrumentPositionStore =
            Provider.of<InstrumentPositionStore>(context, listen: false);
        symbolsToFetch.addAll(instrumentPositionStore.symbols);
      }

      if (mounted) {
        final optionPositionStore =
            Provider.of<OptionPositionStore>(context, listen: false);
        symbolsToFetch.addAll(optionPositionStore.symbols);
      }

      final uniqueSymbols = symbolsToFetch
          .map((s) => s.trim().toUpperCase())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      if (uniqueSymbols.isEmpty) {
        setState(() {
          _portfolioGexData = [];
          _isLoading = false;
        });
        return;
      }

      final callable =
          FirebaseFunctions.instance.httpsCallable('getTopGammaExposure');
      final result = await callable.call<Map<String, dynamic>>({
        'symbols': uniqueSymbols,
        'includeDefaults': false,
      });
      final responseMap = Map<String, dynamic>.from(result.data as Map);

      if (responseMap['status'] == 'ok' && responseMap['data'] != null) {
        final List<dynamic> list = responseMap['data'] as List<dynamic>;
        final dataList = list
            .map((e) =>
                GammaExposureData.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (mounted) {
          setState(() {
            _portfolioGexData = dataList;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = responseMap['message'] ?? 'Failed to load portfolio GEX';
            _isLoading = false;
          });
        }
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

  void _navigateToGexDashboard(String symbol) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GammaExposurePage(
          symbol: symbol,
          generativeService: widget.generativeService,
        ),
      ),
    );
  }

  List<GammaExposureData> get _visibleGexData {
    final data = List<GammaExposureData>.from(_portfolioGexData ?? const []);
    if (_amplifyingOnly) {
      data.removeWhere(
        (item) => item.dealerPositioning != DealerPositioning.shortGamma,
      );
    }
    data.sort((a, b) {
      if (_sortMode == _GexSortMode.proximity) {
        final aDistance =
            a.nearestKeyLevel?.distanceFromSpotPercent.abs() ?? double.infinity;
        final bDistance =
            b.nearestKeyLevel?.distanceFromSpotPercent.abs() ?? double.infinity;
        return aDistance.compareTo(bDistance);
      }
      return b.totalNetGEX.abs().compareTo(a.totalNetGEX.abs());
    });
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Portfolio GEX Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPortfolioGEX,
            tooltip: 'Refresh portfolio GEX',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('GEX Documentation'),
                  content: const SingleChildScrollView(
                    child: IndicatorDocumentationWidget(
                      indicatorKey: 'gammaExposure',
                      showContainer: true,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
            tooltip: 'GEX Documentation',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _fetchPortfolioGEX,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _portfolioGexData == null || _portfolioGexData!.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_graph,
                                size: 64, color: theme.colorScheme.outline),
                            const SizedBox(height: 16),
                            Text(
                              'No Portfolio Positions Detected',
                              style: theme.textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add instruments or options to your portfolio to track their gamma exposure.',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: theme.colorScheme.outline),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchPortfolioGEX,
                      child: ListView(
                        padding: const EdgeInsets.all(16.0),
                        children: [
                          _buildPortfolioSummary(),
                          const SizedBox(height: 16),
                          _buildExposureBreakdown(),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Position GEX Profiles',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              PopupMenuButton<_GexSortMode>(
                                initialValue: _sortMode,
                                tooltip: 'Sort positions',
                                icon: const Icon(Icons.sort),
                                onSelected: (value) =>
                                    setState(() => _sortMode = value),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(
                                    value: _GexSortMode.magnitude,
                                    child: Text('Largest exposure'),
                                  ),
                                  PopupMenuItem(
                                    value: _GexSortMode.proximity,
                                    child: Text('Nearest key level'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilterChip(
                              selected: _amplifyingOnly,
                              avatar: const Icon(Icons.bolt, size: 18),
                              label: const Text('Amplifying risk only'),
                              onSelected: (value) =>
                                  setState(() => _amplifyingOnly = value),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_visibleGexData.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 32),
                              child: Center(
                                child: Text(
                                  'No short-gamma positions in this portfolio.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ),
                            ),
                          ..._visibleGexData.map((data) => Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: InkWell(
                                  onTap: () =>
                                      _navigateToGexDashboard(data.symbol),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              data.symbol,
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: data.dealerPositioning ==
                                                        DealerPositioning
                                                            .longGamma
                                                    ? Colors.green
                                                        .withValues(alpha: 0.1)
                                                    : data.dealerPositioning ==
                                                            DealerPositioning
                                                                .shortGamma
                                                        ? Colors.red.withValues(
                                                            alpha: 0.1)
                                                        : theme.colorScheme
                                                            .primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                data.dealerPositioning
                                                    .displayLabel,
                                                style: theme
                                                    .textTheme.labelSmall
                                                    ?.copyWith(
                                                  color: data.dealerPositioning ==
                                                          DealerPositioning
                                                              .longGamma
                                                      ? Colors.green
                                                      : data.dealerPositioning ==
                                                              DealerPositioning
                                                                  .shortGamma
                                                          ? Colors.red
                                                          : theme.colorScheme
                                                              .onPrimaryContainer,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildPositionMetric(
                                                theme,
                                                'Net GEX',
                                                data.formattedNetGEX,
                                                color: data.totalNetGEX >= 0
                                                    ? Colors.green
                                                    : Colors.red,
                                              ),
                                            ),
                                            Expanded(
                                              child: _buildPositionMetric(
                                                theme,
                                                'Spot',
                                                _formatPrice(data.spotPrice),
                                                alignEnd: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildPositionMetric(
                                                theme,
                                                'Zero Gamma',
                                                _formatPrice(data.gammaFlip),
                                              ),
                                            ),
                                            Expanded(
                                              child: _buildPositionMetric(
                                                theme,
                                                'Call Wall',
                                                _formatPrice(data.callWall),
                                                alignEnd: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildPositionMetric(
                                                theme,
                                                'Put Wall',
                                                _formatPrice(data.putWall),
                                              ),
                                            ),
                                            Expanded(
                                              child: _buildPositionMetric(
                                                theme,
                                                'Nearest Level',
                                                _formatNearestLevel(data),
                                                alignEnd: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: data.gexRatio,
                                            minHeight: 8,
                                            backgroundColor: Colors.red
                                                .withValues(alpha: 0.2),
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                    Color>(Colors.green),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                                'C: ${(data.gexRatio * 100).toStringAsFixed(0)}%',
                                                style:
                                                    theme.textTheme.labelSmall),
                                            Text(
                                                'P: ${((1 - data.gexRatio) * 100).toStringAsFixed(0)}%',
                                                style:
                                                    theme.textTheme.labelSmall),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _buildFreshnessLabel(theme, data),
                                      ],
                                    ),
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildPositionMetric(
    ThemeData theme,
    String label,
    String value, {
    Color? color,
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatPrice(double? price) {
    if (price == null || price <= 0) return 'N/A';
    return '\$${price.toStringAsFixed(2)}';
  }

  String _formatNearestLevel(GammaExposureData data) {
    final level = data.nearestKeyLevel;
    if (level == null) return 'N/A';
    final distance = level.distanceFromSpotPercent;
    final sign = distance > 0 ? '+' : '';
    return '${level.label} $sign${distance.toStringAsFixed(1)}%';
  }

  Widget _buildFreshnessLabel(
    ThemeData theme,
    GammaExposureData data,
  ) {
    final now = DateTime.now();
    final isStale = data.isStaleAt(now);
    final age = data.ageAt(now);
    final String label;
    if (data.updatedAt <= 0) {
      label = 'Update time unavailable';
    } else if (age.inMinutes < 1) {
      label = 'Updated now';
    } else if (age.inHours < 1) {
      label = 'Updated ${age.inMinutes}m ago';
    } else if (age.inDays < 1) {
      label = 'Updated ${age.inHours}h ago';
    } else {
      label = 'Updated ${age.inDays}d ago';
    }

    final color = isStale ? theme.colorScheme.error : theme.colorScheme.outline;
    return Row(
      children: [
        Icon(
          isStale ? Icons.schedule_outlined : Icons.check_circle_outline,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          isStale ? '$label · stale' : label,
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }

  Widget _buildPortfolioSummary() {
    final theme = Theme.of(context);
    final summary = PortfolioGexSummary.fromData(_portfolioGexData!);
    final totalNetGex = summary.netGEX;
    final portfolioPositioning = summary.positioning;
    final positioningColor = portfolioPositioning == DealerPositioning.longGamma
        ? Colors.green
        : portfolioPositioning == DealerPositioning.shortGamma
            ? Colors.red
            : theme.colorScheme.outline;
    final regimeLabel = portfolioPositioning == DealerPositioning.longGamma
        ? 'DAMPENING'
        : portfolioPositioning == DealerPositioning.shortGamma
            ? 'AMPLIFYING'
            : 'BALANCED';

    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.primaryContainer),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Aggregate Portfolio Gamma (GEX)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              totalNetGex >= 0
                  ? '+\$${(totalNetGex / 1e6).toStringAsFixed(2)}M'
                  : '-\$${(totalNetGex.abs() / 1e6).toStringAsFixed(2)}M',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: totalNetGex >= 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: totalNetGex >= 0
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    portfolioPositioning == DealerPositioning.longGamma
                        ? Icons.compress
                        : portfolioPositioning == DealerPositioning.shortGamma
                            ? Icons.expand
                            : Icons.balance,
                    size: 16,
                    color: positioningColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    regimeLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: positioningColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              portfolioPositioning == DealerPositioning.longGamma
                  ? 'Market makers are net long gamma on your holdings, which typically dampens volatility.'
                  : portfolioPositioning == DealerPositioning.shortGamma
                      ? 'Market makers are net short gamma on your holdings, which can amplify price swings.'
                      : 'Positive and negative gamma exposures are closely balanced, so the net figure can understate activity.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryMetric(
                    theme,
                    'Gross Exposure',
                    _formatCompactGex(summary.grossGEX),
                  ),
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    theme,
                    'Top Concentration',
                    '${(summary.topConcentration * 100).toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dampening ${summary.dampeningSymbols}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'EXPOSURE BREADTH',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Amplifying ${summary.amplifyingSymbols}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.dampeningShare,
                minHeight: 8,
                backgroundColor: Colors.red.withValues(alpha: 0.75),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(summary.dampeningShare * 100).toStringAsFixed(0)}% positive GEX',
                  style: theme.textTheme.labelSmall,
                ),
                Text(
                  '${((1 - summary.dampeningShare) * 100).toStringAsFixed(0)}% negative GEX',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            if (summary.hasMixedExposure) ...[
              const SizedBox(height: 12),
              Text(
                'Mixed regime: symbol-level exposures may offset in the aggregate.',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryMetric(ThemeData theme, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatCompactGex(double value) {
    final absoluteValue = value.abs();
    if (absoluteValue >= 1e9) {
      return '\$${(absoluteValue / 1e9).toStringAsFixed(2)}B';
    }
    if (absoluteValue >= 1e6) {
      return '\$${(absoluteValue / 1e6).toStringAsFixed(1)}M';
    }
    if (absoluteValue >= 1e3) {
      return '\$${(absoluteValue / 1e3).toStringAsFixed(0)}K';
    }
    return '\$${absoluteValue.toStringAsFixed(0)}';
  }

  Widget _buildExposureBreakdown() {
    final theme = Theme.of(context);
    final sortedByAbsGex = List<GammaExposureData>.from(_portfolioGexData!)
      ..sort((a, b) => b.totalNetGEX.abs().compareTo(a.totalNetGEX.abs()));

    final topHoldings = sortedByAbsGex.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top Gamma Drivers',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...topHoldings.map((data) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      data.symbol,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: sortedByAbsGex[0].totalNetGEX == 0
                              ? 0
                              : (data.totalNetGEX.abs() /
                                      sortedByAbsGex[0].totalNetGEX.abs())
                                  .clamp(0.05, 1.0),
                          child: Container(
                            height: 24,
                            decoration: BoxDecoration(
                              color: data.totalNetGEX >= 0
                                  ? Colors.green.withValues(alpha: 0.6)
                                  : Colors.red.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        Positioned.fill(
                            child: Center(
                                child: Text(
                          data.totalNetGEX >= 0 ? 'LONG' : 'SHORT',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '\$${(data.totalNetGEX / 1e6).toStringAsFixed(1)}M',
                      textAlign: TextAlign.right,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            data.totalNetGEX >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

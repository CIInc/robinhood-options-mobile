import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../model/gamma_exposure_model.dart';
import '../services/generative_service.dart';
import '../services/yahoo_service.dart';

/// Displays Gamma Exposure (GEX) analysis for a given symbol.
///
/// Shows a horizontal bar chart of net GEX by strike, dealer positioning
/// chip, gamma flip level, and max gamma strike markers.
class GammaExposureWidget extends StatefulWidget {
  final String symbol;
  final double? spotPrice;
  final GenerativeService? generativeService;

  const GammaExposureWidget({
    super.key,
    required this.symbol,
    this.spotPrice,
    this.generativeService,
  });

  @override
  State<GammaExposureWidget> createState() => _GammaExposureWidgetState();
}

class _GammaExposureWidgetState extends State<GammaExposureWidget> {
  GammaExposureData? _data;
  bool _loading = true;
  String? _error;
  bool _showChart = true;
  String _selectedFilter = 'all';
  bool _generatingCommentary = false;
  String? _aiCommentary;
  bool _isClientFallback = false;
  GexStrikeLevel? _selectedStrike;

  @override
  void initState() {
    super.initState();
    _fetchGEX();
  }

  @override
  void didUpdateWidget(GammaExposureWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.spotPrice != widget.spotPrice ||
        oldWidget.generativeService != widget.generativeService) {
      _fetchGEX();
    }
  }

  double _normalPDF(double x) {
    return exp(-0.5 * x * x) / sqrt(2 * pi);
  }

  double _computeBlackScholesGamma({
    required double S,
    required double K,
    required double T,
    required double r,
    required double sigma,
  }) {
    if (S <= 0 || K <= 0 || T <= 0 || sigma <= 0) return 0.0;
    final sqrtT = sqrt(T);
    final d1 = (log(S / K) + (r + 0.5 * sigma * sigma) * T) / (sigma * sqrtT);
    return _normalPDF(d1) / (S * sigma * sqrtT);
  }

  double _computeTotalNetGexAtSpot(
      List<Map<String, dynamic>> chains, double spotPrice) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    double netGex = 0.0;
    for (var chain in chains) {
      final optionsList = chain['options'] as List?;
      if (optionsList == null || optionsList.isEmpty) continue;

      final firstOpt = optionsList.first as Map<String, dynamic>;
      final calls = firstOpt['calls'] as List? ?? [];
      final puts = firstOpt['puts'] as List? ?? [];

      void processOption(Map<String, dynamic> opt, bool isCall) {
        final strike = (opt['strike'] as num?)?.toDouble();
        if (strike == null || strike <= 0) return;

        final expRaw = opt['expiration'];
        int? expMs;
        if (expRaw is DateTime) {
          expMs = expRaw.millisecondsSinceEpoch;
        } else if (expRaw is num) {
          expMs = expRaw.toInt() * 1000;
        }

        final t = expMs != null
            ? max((expMs - nowMs) / (365 * 24 * 60 * 60 * 1000), 0.001)
            : 0.05;

        final iv = (opt['impliedVolatility'] as num?)?.toDouble() ?? 0.3;
        final effectiveSigma = iv > 0 ? iv : 0.3;

        final gamma = _computeBlackScholesGamma(
          S: spotPrice,
          K: strike,
          T: t,
          r: 0.05,
          sigma: effectiveSigma,
        );
        final oi = (opt['openInterest'] as num?)?.toDouble() ?? 0.0;

        if (isCall) {
          netGex += (gamma * oi * 100 * spotPrice);
        } else {
          netGex -= (gamma * oi * 100 * spotPrice);
        }
      }

      for (var c in calls) {
        processOption(Map<String, dynamic>.from(c), true);
      }
      for (var p in puts) {
        processOption(Map<String, dynamic>.from(p), false);
      }
    }
    return netGex;
  }

  GammaExposureData _computeGexFromChains(
      String symbol, double spotPrice, List<Map<String, dynamic>> chains) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final Map<double, Map<String, double>> strikeMap = {};

    for (var chain in chains) {
      final optionsList = chain['options'] as List?;
      if (optionsList == null || optionsList.isEmpty) continue;

      final firstOpt = optionsList.first as Map<String, dynamic>;
      final calls = firstOpt['calls'] as List? ?? [];
      final puts = firstOpt['puts'] as List? ?? [];

      void processOption(Map<String, dynamic> opt, bool isCall) {
        final strike = (opt['strike'] as num?)?.toDouble();
        if (strike == null || strike <= 0) return;

        final expRaw = opt['expiration'];
        int? expMs;
        if (expRaw is DateTime) {
          expMs = expRaw.millisecondsSinceEpoch;
        } else if (expRaw is num) {
          expMs = expRaw.toInt() * 1000;
        }

        final t = expMs != null
            ? max((expMs - nowMs) / (365 * 24 * 60 * 60 * 1000), 0.001)
            : 0.05;

        final iv = (opt['impliedVolatility'] as num?)?.toDouble() ?? 0.3;
        final effectiveSigma = iv > 0 ? iv : 0.3;

        final gamma = _computeBlackScholesGamma(
          S: spotPrice,
          K: strike,
          T: t,
          r: 0.05,
          sigma: effectiveSigma,
        );
        final oi = (opt['openInterest'] as num?)?.toDouble() ?? 0.0;

        strikeMap.putIfAbsent(
            strike,
            () => {
                  'callGamma': 0.0,
                  'putGamma': 0.0,
                  'callOI': 0.0,
                  'putOI': 0.0,
                  'callGEX': 0.0,
                  'putGEX': 0.0,
                });

        final entry = strikeMap[strike]!;
        if (isCall) {
          entry['callGamma'] = entry['callGamma']! + gamma;
          entry['callOI'] = entry['callOI']! + oi;
          entry['callGEX'] = entry['callGEX']! + (gamma * oi * 100 * spotPrice);
        } else {
          entry['putGamma'] = entry['putGamma']! + gamma;
          entry['putOI'] = entry['putOI']! + oi;
          entry['putGEX'] = entry['putGEX']! + (gamma * oi * 100 * spotPrice);
        }
      }

      for (var c in calls) {
        processOption(Map<String, dynamic>.from(c), true);
      }
      for (var p in puts) {
        processOption(Map<String, dynamic>.from(p), false);
      }
    }

    final List<GexStrikeLevel> gexByStrike = [];
    double totalCallGEX = 0.0;
    double totalPutGEX = 0.0;

    strikeMap.forEach((strike, vals) {
      final callGexVal = vals['callGEX']!;
      final putGexVal = vals['putGEX']!;
      final netGexVal = callGexVal - putGexVal;

      gexByStrike.add(GexStrikeLevel(
        strike: strike,
        callGamma: vals['callGamma']!,
        putGamma: vals['putGamma']!,
        callOI: vals['callOI']!,
        putOI: vals['putOI']!,
        callGEX: callGexVal,
        putGEX: putGexVal,
        netGEX: netGexVal,
      ));

      totalCallGEX += callGexVal;
      totalPutGEX += putGexVal;
    });

    gexByStrike.sort((a, b) => a.strike.compareTo(b.strike));

    double totalNetGEX = totalCallGEX - totalPutGEX;

    // Calculate flip level
    double? gammaFlip;
    if (gexByStrike.length >= 2) {
      double closestDistance = double.infinity;
      for (int i = 1; i < gexByStrike.length; i++) {
        final prev = gexByStrike[i - 1];
        final curr = gexByStrike[i];

        if (prev.netGEX != 0 &&
            curr.netGEX != 0 &&
            (prev.netGEX.sign != curr.netGEX.sign)) {
          final crossingStrike = prev.strike +
              (curr.strike - prev.strike) *
                  prev.netGEX.abs() /
                  (prev.netGEX.abs() + curr.netGEX.abs());

          final dist = (crossingStrike - spotPrice).abs();
          if (dist < closestDistance) {
            closestDistance = dist;
            gammaFlip = (crossingStrike * 100).round() / 100.0;
          }
        }
      }
    }

    // Max absolute net GEX
    double? maxGammaStrike;
    if (gexByStrike.isNotEmpty) {
      double maxAbsVal = -1.0;
      for (var level in gexByStrike) {
        final absNet = level.netGEX.abs();
        if (absNet > maxAbsVal) {
          maxAbsVal = absNet;
          maxGammaStrike = level.strike;
        }
      }
    }

    // Call Wall & Put Wall
    double? callWall;
    double maxCallGEXVal = -1.0;
    double? putWall;
    double maxPutGEXVal = -1.0;

    for (var s in gexByStrike) {
      if (s.callGEX > maxCallGEXVal && s.callOI > 0) {
        maxCallGEXVal = s.callGEX;
        callWall = s.strike;
      }
      if (s.putGEX > maxPutGEXVal && s.putOI > 0) {
        maxPutGEXVal = s.putGEX;
        putWall = s.strike;
      }
    }

    double gexRatio = (totalCallGEX + totalPutGEX) > 0
        ? totalCallGEX / (totalCallGEX + totalPutGEX)
        : 0.5;

    DealerPositioning dealerPositioning = DealerPositioning.neutral;
    final absGexSum = totalNetGEX.abs();
    if (absGexSum >= 1e6) {
      dealerPositioning = totalNetGEX > 0
          ? DealerPositioning.longGamma
          : DealerPositioning.shortGamma;
    }

    final gexMagnitude = min(totalNetGEX.abs() / 1e9, 1.0);
    final signalStrength = (gexMagnitude * 100).round();

    final gexSensitivity = GexSensitivity(
      spotMinus2Pct: _computeTotalNetGexAtSpot(chains, spotPrice * 0.98),
      spotMinus1Pct: _computeTotalNetGexAtSpot(chains, spotPrice * 0.99),
      spotCurrent: totalNetGEX,
      spotPlus1Pct: _computeTotalNetGexAtSpot(chains, spotPrice * 1.01),
      spotPlus2Pct: _computeTotalNetGexAtSpot(chains, spotPrice * 1.02),
    );

    return GammaExposureData(
      symbol: symbol,
      spotPrice: spotPrice,
      totalCallGEX: totalCallGEX,
      totalPutGEX: totalPutGEX,
      totalNetGEX: totalNetGEX,
      gammaFlip: gammaFlip,
      maxGammaStrike: maxGammaStrike,
      gexByStrike: gexByStrike,
      dealerPositioning: dealerPositioning,
      signalStrength: signalStrength,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      expirationFilter: _selectedFilter,
      callWall: callWall,
      putWall: putWall,
      gexRatio: gexRatio,
      riskFreeRate: 0.05,
      gexSensitivity: gexSensitivity,
    );
  }

  Future<void> _fetchGEXClientSide() async {
    final yahooService = YahooService();
    // 1. Fetch initial options chain to get spotPrice & expiration dates
    final firstChain = await yahooService.getOptionChain(widget.symbol);
    if (firstChain == null || firstChain['quote'] == null) {
      throw Exception('Failed to retrieve client-side Yahoo options chain');
    }

    // Prioritize provided spot price, else regular market price
    final double spotPrice = widget.spotPrice ??
        (firstChain['quote']['regularMarketPrice'] as num?)?.toDouble() ??
        0.0;
    if (spotPrice <= 0) {
      throw Exception('No valid spot price for client GEX calculation');
    }

    final expirationDates =
        firstChain['expirationDates'] as List<dynamic>? ?? [];
    if (expirationDates.isEmpty) {
      throw Exception('No option expiration dates found on client');
    }

    final now = DateTime.now();
    final List<DateTime> filteredDates = expirationDates.map((d) {
      if (d is DateTime) return d;
      return DateTime.fromMillisecondsSinceEpoch((d as int) * 1000);
    }).where((date) {
      final days = date.difference(now).inDays;
      if (_selectedFilter == '0-7') return days >= -1 && days <= 7;
      if (_selectedFilter == '8-30') return days > 7 && days <= 30;
      if (_selectedFilter == '30+') return days > 30;
      return true;
    }).toList();

    if (filteredDates.isEmpty) {
      throw Exception('No expiration dates matching filter: $_selectedFilter');
    }

    // To prevent rate limiting and keep it speedy, fetch first 4 matching expirations
    final datesToFetch = filteredDates.take(4).toList();
    final List<Map<String, dynamic>> chains = [];

    final List<Future<dynamic>> futures = datesToFetch.map((date) {
      final epoch = date.millisecondsSinceEpoch ~/ 1000;
      return yahooService.getOptionChain(widget.symbol, date: epoch);
    }).toList();

    final results = await Future.wait(futures);
    for (var r in results) {
      if (r != null &&
          r['options'] != null &&
          (r['options'] as List).isNotEmpty) {
        chains.add(Map<String, dynamic>.from(r));
      }
    }

    if (chains.isEmpty) {
      throw Exception('Could not fetch any options chain data on client');
    }

    final gexData = _computeGexFromChains(widget.symbol, spotPrice, chains);
    if (mounted) {
      setState(() {
        _data = gexData;
        _isClientFallback = true;
        _loading = false;
      });
    }
  }

  Future<void> _fetchGEX() async {
    setState(() {
      _loading = true;
      _error = null;
      _aiCommentary = null;
      _generatingCommentary = false;
      _isClientFallback = false;
      _selectedStrike = null;
    });
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getGammaExposure');
      final result = await callable.call<Map<String, dynamic>>({
        'symbol': widget.symbol,
        if (widget.spotPrice != null) 'spotPrice': widget.spotPrice,
        'expirationFilter': _selectedFilter,
      });

      final responseMap = Map<String, dynamic>.from(result.data as Map);
      if (responseMap['status'] == 'ok' && responseMap['data'] != null) {
        final data = GammaExposureData.fromJson(
            Map<String, dynamic>.from(responseMap['data'] as Map));
        if (mounted) {
          setState(() {
            _data = data;
            _loading = false;
          });
        }
      } else {
        debugPrint(
            'Server GEX returned error status, try using client-side fallback...');
        await _fetchGEXClientSide();
      }
    } catch (e) {
      debugPrint(
          'Server GEX call failed: $e. Try using client-side fallback...');
      try {
        await _fetchGEXClientSide();
      } catch (clientErr) {
        if (mounted) {
          setState(() {
            _error = 'GEX Unavailable ($clientErr)';
            _loading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _data == null) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.adjust, color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              Text('GEX data unavailable',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.outline)),
              if (_error != null)
                Text(_error!,
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.error)),
            ],
          ),
        ),
      );
    }
    final gex = _data!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryRow(context, gex),
        const SizedBox(height: 12),
        _buildControlRow(context),
        _buildSelectedStrikeDetails(context, gex),
        const SizedBox(height: 12),
        _showChart
            ? _buildBarChart(context, gex)
            : _buildStrikeTable(context, gex),
        const SizedBox(height: 8),
        if (_showChart) _buildLegend(context, gex),
        const SizedBox(height: 16),
        _buildGexPinningGauge(context, gex),
        const SizedBox(height: 12),
        _buildGexSensitivityDashboard(context, gex),
        if (widget.generativeService != null) ...[
          const SizedBox(height: 16),
          _buildAICochCommentary(context, gex),
        ],
      ],
    );
  }

  Widget _buildGexPinningGauge(BuildContext context, GammaExposureData gex) {
    if (gex.callWall == null && gex.putWall == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final double lowerBound = gex.putWall ?? (gex.spotPrice * 0.95);
    final double upperBound = gex.callWall ?? (gex.spotPrice * 1.05);

    double progress = 0.5;
    if (upperBound > lowerBound) {
      progress = (gex.spotPrice - lowerBound) / (upperBound - lowerBound);
      progress = progress.clamp(0.0, 1.0);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pin_drop, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Market Maker Pinning Gauge',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Timeline Slider/Bar
          Stack(
            alignment: Alignment.center,
            children: [
              // Track
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Spot price indicator pin
              Align(
                alignment: Alignment(progress * 2 - 1, 0),
                child: Container(
                  height: 14,
                  width: 14,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                ),
              ),
              // Gamma flip indicator pin if visible
              if (gex.gammaFlip != null &&
                  gex.gammaFlip! >= lowerBound &&
                  gex.gammaFlip! <= upperBound)
                Align(
                  alignment: Alignment(
                      ((gex.gammaFlip! - lowerBound) /
                                  (upperBound - lowerBound)) *
                              2 -
                          1,
                      0),
                  child: Container(
                    height: 10,
                    width: 10,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Floor (Put Wall)',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline, fontSize: 10)),
                  Text('\$${lowerBound.toStringAsFixed(1)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Current Spot',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline, fontSize: 10)),
                  Text('\$${gex.spotPrice.toStringAsFixed(1)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Ceiling (Call Wall)',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline, fontSize: 10)),
                  Text('\$${upperBound.toStringAsFixed(1)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ],
          ),
          if (gex.gammaFlip != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Gamma Flip Threshold at \$${gex.gammaFlip!.toStringAsFixed(1)} (${((gex.spotPrice - gex.gammaFlip!) / gex.spotPrice * 100).toStringAsFixed(1)}% from spot)',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGexSensitivityDashboard(
      BuildContext context, GammaExposureData gex) {
    if (gex.gexSensitivity == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final sens = gex.gexSensitivity!;

    Widget sensitivityRow(String label, double value,
        {bool isCurrent = false}) {
      final sign = value >= 0 ? '+' : '';
      final valueColor = value >= 0 ? Colors.green : Colors.red;
      final valueStr = value.abs() >= 1e9
          ? '$sign\$${(value / 1e9).toStringAsFixed(2)}B'
          : value.abs() >= 1e6
              ? '$sign\$${(value / 1e6).toStringAsFixed(0)}M'
              : '$sign\$${value.toStringAsFixed(0)}';

      return Container(
        decoration: isCurrent
            ? BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              )
            : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color: isCurrent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
            Text(
              valueStr,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isCurrent ? theme.colorScheme.primary : valueColor,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Spot-Shift GEX Sensitivity (Stress Test)',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Simulates options dealer positioning and hedging regimes if spot price shifts dynamically.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            width: double.infinity,
            child: CustomPaint(
              painter: _GexSensitivityCurvePainter(
                values: [
                  sens.spotMinus2Pct,
                  sens.spotMinus1Pct,
                  sens.spotCurrent,
                  sens.spotPlus1Pct,
                  sens.spotPlus2Pct,
                ],
                positiveColor: Colors.green,
                negativeColor: Colors.red,
                zeroLineColor: theme.colorScheme.outline,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              sensitivityRow('-2.0% Price Shift', sens.spotMinus2Pct),
              const Divider(height: 4, indent: 8, endIndent: 8),
              sensitivityRow('-1.0% Price Shift', sens.spotMinus1Pct),
              const Divider(height: 4, indent: 8, endIndent: 8),
              sensitivityRow('Current Price (Spot)', sens.spotCurrent,
                  isCurrent: true),
              const Divider(height: 4, indent: 8, endIndent: 8),
              sensitivityRow('+1.0% Price Shift', sens.spotPlus1Pct),
              const Divider(height: 4, indent: 8, endIndent: 8),
              sensitivityRow('+2.0% Price Shift', sens.spotPlus2Pct),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedStrikeDetails(
      BuildContext context, GammaExposureData gex) {
    if (_selectedStrike == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Center(
          child: Text(
            'Tip: Tap any strike on the chart or row on the table to inspect details.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      );
    }

    final s = _selectedStrike!;
    final theme = Theme.of(context);
    final distancePct = ((s.strike - gex.spotPrice) / gex.spotPrice) * 100;
    final distanceLabel = (s.strike - gex.spotPrice).abs() < 0.1
        ? 'At-The-Money (ATM)'
        : '${distancePct > 0 ? '+' : ''}${distancePct.toStringAsFixed(1)}% ${distancePct > 0 ? 'Out-Of-The-Money (OTM)' : 'In-The-Money (ITM)'}';

    final netGexColor = s.netGEX >= 0 ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: theme.colorScheme.primary),
                    Text(
                      'Strike \$${s.strike.toStringAsFixed(1)}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        distanceLabel,
                        style: TextStyle(
                          fontSize: 9,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _selectedStrike = null;
                  });
                },
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Net GEX Volume',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 4),
                    Text(
                      _formatGEX(s.netGEX),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: netGexColor,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Call / Put Open Interest',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatOI(s.callOI)} / ${_formatOI(s.putOI)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Call GEX Contribution',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 4),
                    Text(
                      _formatGEX(s.callGEX),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Put GEX Contribution',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                    const SizedBox(height: 4),
                    Text(
                      _formatGEX(s.putGEX),
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAICochCommentary(BuildContext context, GammaExposureData gex) {
    if (widget.generativeService == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 16),
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'AI Market Maker Analysis',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_generatingCommentary)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Regenerate Analysis',
                    onPressed: () => _generateCommentary(gex),
                  ),
              ],
            ),
            const Divider(height: 24),
            if (_aiCommentary == null && !_generatingCommentary)
              Center(
                child: FilledButton.icon(
                  onPressed: () => _generateCommentary(gex),
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Generate AI Commentary'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              )
            else if (_generatingCommentary && _aiCommentary == null)
              Text(
                'Gemini is analyzing market-maker positioning, pinning risks, and wall levels for ${gex.symbol}...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.outline,
                ),
              )
            else if (_aiCommentary != null)
              Text(
                _aiCommentary!,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateCommentary(GammaExposureData gex) async {
    if (widget.generativeService == null) return;
    setState(() {
      _generatingCommentary = true;
      _aiCommentary = null;
    });

    final promptText =
        'Analyze the options market-maker Gamma Exposure (GEX) data for ticker ${gex.symbol}.'
        '\n- Current Spot Price: \$${gex.spotPrice.toStringAsFixed(2)}'
        '\n- Net GEX: ${gex.formattedNetGEX}'
        '\n- Dealer Positioning: ${gex.dealerPositioning.displayLabel}'
        '\n- Gamma Flip Level: ${gex.gammaFlip != null ? '\$${gex.gammaFlip!.toStringAsFixed(2)}' : 'N/A'}'
        '\n- Call Wall (Resistance): ${gex.callWall != null ? '\$${gex.callWall!.toStringAsFixed(2)}' : 'N/A'}'
        '\n- Put Wall (Support): ${gex.putWall != null ? '\$${gex.putWall!.toStringAsFixed(2)}' : 'N/A'}'
        '\n- Call vs Put GEX Ratio: ${(gex.gexRatio * 100).toStringAsFixed(0)}% Calls / ${((1 - gex.gexRatio) * 100).toStringAsFixed(0)}% Puts'
        '\n- Signal Strength Indicator: ${gex.signalStrength}/100'
        '\n\nProvide 2-3 concise paragraphs summarizing what this means for near-term price action, key resistance/support zones to watch, and overall trading volatility expectations. Keep your answer highly educational, concise, and professional.';

    try {
      final promptObj = Prompt(
        key: 'gex-commentary-${gex.symbol}',
        title: 'GEX Commentary',
        prompt: promptText,
      );
      final resp = await widget.generativeService!.generateContentFromServer(
        promptObj,
        null,
        null,
        null,
      );
      if (mounted) {
        setState(() {
          _aiCommentary = resp;
          _generatingCommentary = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiCommentary = 'Failed to generate analysis. Error: $e';
          _generatingCommentary = false;
        });
      }
    }
  }

  Widget _buildControlRow(BuildContext context) {
    final theme = Theme.of(context);
    final filterLabels = {
      'all': 'All Expirations',
      '0-7': '0-7 Days (0DTE/Weekly)',
      '8-30': '8-30 Days (Monthly)',
      '30+': '30+ Days (Leaps)',
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFilter,
              icon: const Icon(Icons.arrow_drop_down),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
              isExpanded: true,
              items: filterLabels.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(
                    entry.value,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (String? val) {
                if (val != null && val != _selectedFilter) {
                  setState(() {
                    _selectedFilter = val;
                  });
                  _fetchGEX();
                }
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment<bool>(
              value: true,
              label: Text('Chart'),
              icon: Icon(Icons.bar_chart),
            ),
            ButtonSegment<bool>(
              value: false,
              label: Text('Table'),
              icon: Icon(Icons.table_rows),
            ),
          ],
          selected: {_showChart},
          onSelectionChanged: (Set<bool> newSelection) {
            setState(() {
              _showChart = newSelection.first;
            });
          },
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  String _formatGEX(double value) {
    final abs = value.abs();
    final sign = value >= 0 ? '+' : '-';
    if (abs >= 1e9) return '$sign\$${(abs / 1e9).toStringAsFixed(2)}B';
    if (abs >= 1e6) return '$sign\$${(abs / 1e6).toStringAsFixed(1)}M';
    if (abs >= 1e3) return '$sign\$${(abs / 1e3).toStringAsFixed(0)}K';
    return '$sign\$${abs.toStringAsFixed(0)}';
  }

  String _formatOI(double value) {
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value.toStringAsFixed(0);
  }

  Widget _buildStrikeTable(BuildContext context, GammaExposureData gex) {
    final theme = Theme.of(context);
    final strikes = gex.getVisibleStrikes(count: 30);

    if (strikes.isEmpty) {
      return const Center(child: Text('No strike level data available.'));
    }

    final double strikeStep = strikes.length > 1
        ? (strikes[1].strike - strikes[0].strike).abs()
        : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 16,
          headingRowHeight: 40,
          dataRowMinHeight: 36,
          dataRowMaxHeight: 44,
          headingTextStyle: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          columns: const [
            DataColumn(label: Text('Strike')),
            DataColumn(label: Text('Call OI', textAlign: TextAlign.right)),
            DataColumn(label: Text('Put OI', textAlign: TextAlign.right)),
            DataColumn(label: Text('Net GEX', textAlign: TextAlign.right)),
          ],
          rows: strikes.map((s) {
            final isAtm = (s.strike - gex.spotPrice).abs() < (strikeStep / 2);
            final isMaxGamma = gex.maxGammaStrike != null &&
                (s.strike - gex.maxGammaStrike!).abs() < 0.01;
            final isFlip = gex.gammaFlip != null &&
                (s.strike - gex.gammaFlip!).abs() < 0.01;
            final isCallWall =
                gex.callWall != null && (s.strike - gex.callWall!).abs() < 0.01;
            final isPutWall =
                gex.putWall != null && (s.strike - gex.putWall!).abs() < 0.01;

            final isSelected = _selectedStrike != null &&
                (_selectedStrike!.strike - s.strike).abs() < 0.01;

            final netGexColor = s.netGEX >= 0 ? Colors.green : Colors.red;

            // Row decoration/background color if ATM, Max Gamma, Flip, Call Wall, or Put Wall
            Color? rowBg;
            if (isSelected) {
              rowBg = theme.colorScheme.primary.withValues(alpha: 0.18);
            } else if (isAtm) {
              rowBg = theme.colorScheme.primary.withValues(alpha: 0.08);
            } else if (isMaxGamma) {
              rowBg = Colors.amber.withValues(alpha: 0.08);
            } else if (isFlip) {
              rowBg = Colors.orange.withValues(alpha: 0.08);
            } else if (isCallWall) {
              rowBg = Colors.green.withValues(alpha: 0.05);
            } else if (isPutWall) {
              rowBg = Colors.red.withValues(alpha: 0.05);
            }

            return DataRow(
              selected: isSelected,
              onSelectChanged: (selected) {
                if (selected == true) {
                  setState(() {
                    _selectedStrike = s;
                  });
                }
              },
              color: WidgetStateProperty.resolveWith<Color?>((states) => rowBg),
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${s.strike.toStringAsFixed(1)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: (isAtm ||
                                  isMaxGamma ||
                                  isFlip ||
                                  isCallWall ||
                                  isPutWall)
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (isAtm)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('ATM',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ),
                      if (isMaxGamma)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('MAX',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ),
                      if (isFlip)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('FLIP',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ),
                      if (isCallWall)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('C-WALL',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ),
                      if (isPutWall)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('P-WALL',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                DataCell(Text(_formatOI(s.callOI))),
                DataCell(Text(_formatOI(s.putOI))),
                DataCell(
                  Text(
                    _formatGEX(s.netGEX),
                    style: TextStyle(
                      color: netGexColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, GammaExposureData gex) {
    final theme = Theme.of(context);
    final positioningColor =
        gex.dealerPositioning == DealerPositioning.longGamma
            ? Colors.green
            : gex.dealerPositioning == DealerPositioning.shortGamma
                ? Colors.red
                : theme.colorScheme.outline;
    final positioningIcon = gex.dealerPositioning == DealerPositioning.longGamma
        ? Icons.compress
        : gex.dealerPositioning == DealerPositioning.shortGamma
            ? Icons.expand
            : Icons.remove;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              avatar: Icon(positioningIcon, size: 16, color: positioningColor),
              label: Text(gex.dealerPositioning.displayLabel,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: positioningColor)),
              side: BorderSide(color: positioningColor.withValues(alpha: 0.3)),
              backgroundColor: positioningColor.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            if (_isClientFallback)
              Chip(
                avatar: Icon(Icons.flash_on,
                    size: 14, color: theme.colorScheme.secondary),
                label: Text('Local Calc',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.bold)),
                side: BorderSide(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.3)),
                backgroundColor:
                    theme.colorScheme.secondary.withValues(alpha: 0.08),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Net GEX',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                Text(gex.formattedNetGEX,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color:
                            gex.totalNetGEX >= 0 ? Colors.green : Colors.red)),
              ],
            ),
            if (gex.gammaFlip != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gamma Flip',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                  Text('\$${gex.gammaFlip!.toStringAsFixed(0)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: gex.spotPrice > gex.gammaFlip!
                              ? Colors.green
                              : Colors.orange)),
                ],
              ),
            if (gex.maxGammaStrike != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Max Gamma',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                  Text('\$${gex.maxGammaStrike!.toStringAsFixed(0)}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            if (gex.callWall != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Call Wall (Res)',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                  Text('\$${gex.callWall!.toStringAsFixed(0)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            if (gex.putWall != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Put Wall (Sup)',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                  Text('\$${gex.putWall!.toStringAsFixed(0)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(gex.dealerPositioning.description,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        // GEX Ratio Visual progress bar
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Calls: ${(gex.gexRatio * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'GEX Balance Ratio',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                Text(
                  'Puts: ${((1 - gex.gexRatio) * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: (gex.gexRatio * 100).round().clamp(1, 99),
                      child:
                          Container(color: Colors.green.withValues(alpha: 0.8)),
                    ),
                    Expanded(
                      flex: ((1 - gex.gexRatio) * 100).round().clamp(1, 99),
                      child:
                          Container(color: Colors.red.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBarChart(BuildContext context, GammaExposureData gex) {
    final theme = Theme.of(context);
    final strikes = gex.getVisibleStrikes(count: 20);
    if (strikes.isEmpty) return const SizedBox.shrink();

    final maxAbs = strikes.map((s) => s.netGEX.abs()).reduce(max);
    if (maxAbs == 0) return const SizedBox.shrink();

    final double chartHeight = max(strikes.length * 24.0, 100);

    return Container(
      height: chartHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTapUp: (details) {
          final double y = details.localPosition.dy;
          final double barHeight = chartHeight / strikes.length;
          final int index =
              (y / barHeight).floor().clamp(0, strikes.length - 1);
          setState(() {
            _selectedStrike = strikes[index];
          });
        },
        onVerticalDragStart: (details) {
          final double y = details.localPosition.dy;
          final double barHeight = chartHeight / strikes.length;
          final int index =
              (y / barHeight).floor().clamp(0, strikes.length - 1);
          setState(() {
            _selectedStrike = strikes[index];
          });
        },
        onVerticalDragUpdate: (details) {
          final double y = details.localPosition.dy;
          final double barHeight = chartHeight / strikes.length;
          final int index =
              (y / barHeight).floor().clamp(0, strikes.length - 1);
          setState(() {
            _selectedStrike = strikes[index];
          });
        },
        child: CustomPaint(
          painter: _GexBarChartPainter(
            strikes: strikes,
            maxAbs: maxAbs,
            spotPrice: gex.spotPrice,
            gammaFlip: gex.gammaFlip,
            maxGammaStrike: gex.maxGammaStrike,
            callWall: gex.callWall,
            putWall: gex.putWall,
            textColor: theme.colorScheme.onSurface,
            outlineColor: theme.colorScheme.outline,
            selectedStrike: _selectedStrike,
            selectedColor: theme.colorScheme.primary,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, GammaExposureData gex) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        _legendItem(context, Colors.green, 'Long (pinning)'),
        _legendItem(context, Colors.red, 'Short (trending)'),
        if (gex.gammaFlip != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 16, height: 2, color: Colors.orange),
              const SizedBox(width: 4),
              Text('Gamma Flip',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        if (gex.callWall != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 16, height: 2, color: Colors.green),
              const SizedBox(width: 4),
              Text('Call Wall',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        if (gex.putWall != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 16, height: 2, color: Colors.red),
              const SizedBox(width: 4),
              Text('Put Wall',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 2,
                height: 12,
                color: theme.colorScheme.primary.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text('Current Price',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline)),
      ],
    );
  }
}

/// Custom painter for the GEX bar chart.
class _GexBarChartPainter extends CustomPainter {
  final List<GexStrikeLevel> strikes;
  final double maxAbs;
  final double spotPrice;
  final double? gammaFlip;
  final double? maxGammaStrike;
  final double? callWall;
  final double? putWall;
  final Color textColor;
  final Color outlineColor;
  final GexStrikeLevel? selectedStrike;
  final Color selectedColor;

  _GexBarChartPainter({
    required this.strikes,
    required this.maxAbs,
    required this.spotPrice,
    required this.gammaFlip,
    required this.maxGammaStrike,
    required this.textColor,
    required this.outlineColor,
    required this.selectedColor,
    this.callWall,
    this.putWall,
    this.selectedStrike,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strikes.isEmpty) return;

    const labelWidth = 56.0;
    const barAreaStart = labelWidth + 4;
    final barAreaWidth = size.width - barAreaStart;
    final barHeight = size.height / strikes.length;
    final centerX = barAreaStart + barAreaWidth / 2;

    final positivePaint = Paint()..color = Colors.green.withValues(alpha: 0.7);
    final negativePaint = Paint()..color = Colors.red.withValues(alpha: 0.7);
    final maxGammaPaint = Paint()
      ..color = Colors.amber.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final callWallPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final putWallPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < strikes.length; i++) {
      final s = strikes[i];
      final y = i * barHeight;
      final barWidth = (s.netGEX.abs() / maxAbs) * (barAreaWidth / 2);
      final isPositive = s.netGEX >= 0;

      // Draw standard backgrounds
      if (maxGammaStrike != null && (s.strike - maxGammaStrike!).abs() < 0.01) {
        canvas.drawRect(
          Rect.fromLTWH(barAreaStart, y + 1, barAreaWidth, barHeight - 2),
          maxGammaPaint,
        );
      }

      if (callWall != null && (s.strike - callWall!).abs() < 0.01) {
        canvas.drawRect(
          Rect.fromLTWH(barAreaStart, y + 1, barAreaWidth, barHeight - 2),
          callWallPaint,
        );
      }

      if (putWall != null && (s.strike - putWall!).abs() < 0.01) {
        canvas.drawRect(
          Rect.fromLTWH(barAreaStart, y + 1, barAreaWidth, barHeight - 2),
          putWallPaint,
        );
      }

      // Highlight selected strike row over standard backgrounds
      if (selectedStrike != null &&
          (s.strike - selectedStrike!.strike).abs() < 0.01) {
        canvas.drawRect(
          Rect.fromLTWH(barAreaStart, y + 1, barAreaWidth, barHeight - 2),
          Paint()
            ..color = selectedColor.withValues(alpha: 0.18)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRect(
          Rect.fromLTWH(barAreaStart, y + 1, barAreaWidth, barHeight - 1),
          Paint()
            ..color = selectedColor.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }

      final barRect = isPositive
          ? Rect.fromLTWH(
              centerX, y + barHeight * 0.15, barWidth, barHeight * 0.7)
          : Rect.fromLTWH(centerX - barWidth, y + barHeight * 0.15, barWidth,
              barHeight * 0.7);

      canvas.drawRRect(
        RRect.fromRectAndRadius(barRect, const Radius.circular(2)),
        isPositive ? positivePaint : negativePaint,
      );

      // Strike label
      final tp = TextPainter(
        text: TextSpan(
            text: '\$${s.strike.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 9,
                color: (s.strike - spotPrice).abs() <
                        (strikes.isNotEmpty
                            ? (strikes[1].strike - strikes[0].strike).abs() / 2
                            : 1)
                    ? textColor
                    : outlineColor.withValues(alpha: 0.7))),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: labelWidth - 2);
      tp.paint(canvas, Offset(0, y + barHeight / 2 - tp.height / 2));
    }

    // Center divider line
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      Paint()
        ..color = outlineColor.withValues(alpha: 0.3)
        ..strokeWidth = 1,
    );

    // Spot price horizontal line
    _drawHorizontalLine(canvas, size, barAreaStart, barAreaWidth);

    // Gamma flip line
    if (gammaFlip != null) {
      _drawFlipLine(canvas, size, barAreaStart, barAreaWidth, barHeight);
    }

    // Call Wall line
    if (callWall != null) {
      _drawCallWallLine(canvas, size, barAreaStart, barAreaWidth, barHeight);
    }

    // Put Wall line
    if (putWall != null) {
      _drawPutWallLine(canvas, size, barAreaStart, barAreaWidth, barHeight);
    }
  }

  void _drawHorizontalLine(
      Canvas canvas, Size size, double barAreaStart, double barAreaWidth) {
    // Find the y position of the row closest to spot price
    final spotIdx = strikes.indexWhere((s) =>
        (s.strike - spotPrice).abs() ==
        strikes.map((s2) => (s2.strike - spotPrice).abs()).reduce(min));
    if (spotIdx < 0) return;
    final barHeight = size.height / strikes.length;
    final y = spotIdx * barHeight + barHeight / 2;
    canvas.drawLine(
      Offset(barAreaStart, y),
      Offset(barAreaStart + barAreaWidth, y),
      Paint()
        ..color = Colors.blue.withValues(alpha: 0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawFlipLine(Canvas canvas, Size size, double barAreaStart,
      double barAreaWidth, double barHeight) {
    if (gammaFlip == null) return;
    final flipIdx =
        strikes.indexWhere((s) => (s.strike - gammaFlip!).abs() < 0.02);
    if (flipIdx < 0) return;
    final y = flipIdx * barHeight + barHeight / 2;
    final dashPaint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    double x = barAreaStart;
    while (x < barAreaStart + barAreaWidth) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), dashPaint);
      x += 10;
    }
  }

  void _drawCallWallLine(Canvas canvas, Size size, double barAreaStart,
      double barAreaWidth, double barHeight) {
    if (callWall == null) return;
    final idx = strikes.indexWhere((s) => (s.strike - callWall!).abs() < 0.02);
    if (idx < 0) return;
    final y = idx * barHeight + barHeight / 2;
    final dashPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    double x = barAreaStart;
    while (x < barAreaStart + barAreaWidth) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), dashPaint);
      x += 10;
    }
  }

  void _drawPutWallLine(Canvas canvas, Size size, double barAreaStart,
      double barAreaWidth, double barHeight) {
    if (putWall == null) return;
    final idx = strikes.indexWhere((s) => (s.strike - putWall!).abs() < 0.02);
    if (idx < 0) return;
    final y = idx * barHeight + barHeight / 2;
    final dashPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    double x = barAreaStart;
    while (x < barAreaStart + barAreaWidth) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), dashPaint);
      x += 10;
    }
  }

  @override
  bool shouldRepaint(_GexBarChartPainter oldDelegate) =>
      oldDelegate.strikes != strikes ||
      oldDelegate.spotPrice != spotPrice ||
      oldDelegate.gammaFlip != gammaFlip ||
      oldDelegate.callWall != callWall ||
      oldDelegate.putWall != putWall ||
      oldDelegate.selectedStrike != selectedStrike;
}

/// Custom painter to draw a beautiful visual curve of spot-shifting GEX sensitivity stress test.
class _GexSensitivityCurvePainter extends CustomPainter {
  final List<double> values;
  final Color positiveColor;
  final Color negativeColor;
  final Color zeroLineColor;

  _GexSensitivityCurvePainter({
    required this.values,
    required this.positiveColor,
    required this.negativeColor,
    required this.zeroLineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final double width = size.width;
    final double height = size.height;

    // Find absolute max value to scale appropriately, default to 1.0 if all zero
    double maxAbs = values.map((v) => v.abs()).reduce(max);
    if (maxAbs == 0) maxAbs = 1.0;

    final double centerY = height / 2;

    // Draw Zero line
    final zeroLinePaint = Paint()
      ..color = zeroLineColor.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;
    _drawDashedLine(canvas, Offset(0, centerY), Offset(width, centerY), zeroLinePaint);

    final double stepX = width / (values.length - 1);
    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      // Map value on y-axis centering around centerY with 15% safety margin at top/bottom boundaries
      final y = centerY - (values[i] / maxAbs) * (centerY * 0.75);
      points.add(Offset(x, y));
    }

    // Draw gradient area fill under/over the zero line
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final v1 = values[i];
      final v2 = values[i + 1];

      final areaPath = Path()
        ..moveTo(p1.dx, centerY)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p2.dx, centerY)
        ..close();

      final isPositiveAvg = (v1 + v2) / 2 >= 0;
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = isPositiveAvg
            ? positiveColor.withValues(alpha: 0.12)
            : negativeColor.withValues(alpha: 0.12);
      canvas.drawPath(areaPath, fillPaint);
    }

    // Draw the continuous trend line with smooth quadratic Bezier links
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final pPrev = points[i - 1];
      final pCurr = points[i];
      final xc = (pPrev.dx + pCurr.dx) / 2;
      final yc = (pPrev.dy + pCurr.dy) / 2;
      linePath.quadraticBezierTo(pPrev.dx, pPrev.dy, xc, yc);
    }
    linePath.lineTo(points.last.dx, points.last.dy);

    final linePaint = Paint()
      ..color = values[2] >= 0 ? positiveColor : negativeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // Draw grid columns and tick marks
    final tickTextPaint = TextPainter(textDirection: TextDirection.ltr);
    final labels = ['-2%', '-1%', 'Spot', '+1%', '+2%'];

    for (int i = 0; i < points.length; i++) {
      final isCenter = i == 2;
      final dotPaint = Paint()
        ..color = isCenter ? Colors.blue : (values[i] >= 0 ? positiveColor : negativeColor)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(points[i], isCenter ? 4.5 : 3.0, dotPaint);

      final outlinePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawCircle(points[i], isCenter ? 4.5 : 3.0, outlinePaint);

      // Draw thin helper alignment line for each interval
      canvas.drawLine(
        Offset(points[i].dx, centerY - 6),
        Offset(points[i].dx, centerY + 6),
        Paint()
          ..color = zeroLineColor.withValues(alpha: 0.15)
          ..strokeWidth = 1.0,
      );

      // Label below charts
      tickTextPaint.text = TextSpan(
        text: labels[i],
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: isCenter ? FontWeight.bold : FontWeight.normal,
          color: isCenter ? Colors.blue : zeroLineColor.withValues(alpha: 0.6),
        ),
      );
      tickTextPaint.layout();
      tickTextPaint.paint(
        canvas,
        Offset(
          points[i].dx - tickTextPaint.width / 2,
          height - tickTextPaint.height,
        ),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const double dashWidth = 5.0;
    const double dashSpace = 4.0;
    double currentX = p1.dx;
    while (currentX < p2.dx) {
      canvas.drawLine(
        Offset(currentX, p1.dy),
        Offset(min(currentX + dashWidth, p2.dx), p2.dy),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_GexSensitivityCurvePainter oldDelegate) =>
      oldDelegate.values != values;
}

/// Full-page wrapper for GEX widget.
class GammaExposurePage extends StatelessWidget {
  final String symbol;
  final double? spotPrice;
  final GenerativeService? generativeService;

  const GammaExposurePage({
    super.key,
    required this.symbol,
    this.spotPrice,
    this.generativeService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gamma Exposure — $symbol'),
        actions: [
          Tooltip(
            message: 'GEX = net gamma held by market makers.\n'
                'Positive GEX → dealers buy dips / sell rips (price pinning).\n'
                'Negative GEX → dealers amplify moves (trending).',
            child: const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.help_outline, size: 20),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: GammaExposureWidget(
          symbol: symbol,
          spotPrice: spotPrice,
          generativeService: generativeService,
        ),
      ),
    );
  }
}

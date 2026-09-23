import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/iv_surface_model.dart';
import 'package:robinhood_options_mobile/model/option_marketdata.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/iv_surface_service.dart';

/// Full-screen interactive 3D Implied Volatility Surface visualizer with touch
/// rotation (yaw/pitch), pinch zoom, strike interpolation, 2D cross-section slices,
/// Dupire local volatility heatmap, and arbitrage anomaly diagnostics.
class IvSurface3dWidget extends StatefulWidget {
  final String symbol;
  final double? spotPrice;
  final User? user;
  final BrokerageUser? brokerageUser;
  final IBrokerageService? service;
  final Instrument? instrument;
  final List<Map<String, dynamic>>? optionsChains;
  final List<OptionMarketData>? optionQuotes;
  final double? overrideCurrentIv;

  const IvSurface3dWidget({
    super.key,
    required this.symbol,
    this.spotPrice,
    this.user,
    this.brokerageUser,
    this.service,
    this.instrument,
    this.optionsChains,
    this.optionQuotes,
    this.overrideCurrentIv,
  });

  @override
  State<IvSurface3dWidget> createState() => _IvSurface3dWidgetState();
}

class _IvSurface3dWidgetState extends State<IvSurface3dWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  IvSurfaceAnalysis? _analysis;
  bool _isLoading = false;
  String? _errorMessage;

  // 3D Interactive camera parameters
  double _yaw = -0.55; // Horizontal rotation angle in radians
  double _pitch = 0.50; // Vertical tilt angle in radians (clamped 0.1 to 1.3)
  double _scale = 1.0;
  Offset _panOffset = Offset.zero;

  // Touch tracking
  Offset? _lastFocalPoint;
  double _baseScale = 1.0;

  // Inspection
  int? _inspectedStrikeIdx;
  int? _inspectedDteIdx;

  // Slices selection
  int _selectedSmileIndex = 1; // Default ~30D
  int _selectedTermIndex = 2; // Default ATM

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _computeOrFetchAnalysis();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _resetCamera() {
    setState(() {
      _yaw = -0.55;
      _pitch = 0.50;
      _scale = 1.0;
      _panOffset = Offset.zero;
      _inspectedStrikeIdx = null;
      _inspectedDteIdx = null;
    });
  }

  Future<void> _computeOrFetchAnalysis() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final double effectiveSpot = widget.spotPrice ??
          widget.instrument?.quoteObj?.lastTradePrice ??
          150.0;

      final analysis = IvSurfaceService.computeAnalysis(
        symbol: widget.symbol,
        spotPrice: effectiveSpot,
        optionsChains: widget.optionsChains,
        optionQuotes: widget.optionQuotes,
        overrideIv: widget.overrideCurrentIv,
      );

      setState(() {
        _analysis = analysis;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to compute IV surface: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.symbol} 3D Volatility Surface',
              style:
                  const TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold),
            ),
            if (widget.spotPrice != null ||
                widget.instrument?.quoteObj?.lastTradePrice != null)
              Text(
                'Spot: \$${(widget.spotPrice ?? widget.instrument!.quoteObj!.lastTradePrice!).toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12.0,
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset View',
            onPressed: () {
              HapticFeedback.lightImpact();
              _resetCamera();
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Surface Theory Guide',
            onPressed: () {
              HapticFeedback.lightImpact();
              _showEducationalDialog(context);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.view_in_ar_rounded), text: '3D Surface'),
            Tab(icon: Icon(Icons.show_chart_rounded), text: '2D Slices'),
            Tab(icon: Icon(Icons.analytics_outlined), text: 'Diagnostics'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _computeOrFetchAnalysis,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _analysis == null
                  ? const Center(child: Text('No surface data available.'))
                  : TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _build3dSurfaceTab(_analysis!),
                        _build2dSlicesTab(_analysis!),
                        _buildDiagnosticsTab(_analysis!),
                      ],
                    ),
    );
  }

  // ==========================================
  // TAB 1: 3D SURFACE TAB
  // ==========================================
  Widget _build3dSurfaceTab(IvSurfaceAnalysis analysis) {
    final theme = Theme.of(context);
    final metrics = analysis.metrics;

    return Column(
      children: [
        // Top Regime & Metrics Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: metrics.regime.badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: metrics.regime.badgeColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(metrics.regime.icon,
                          size: 14, color: metrics.regime.badgeColor),
                      const SizedBox(width: 6),
                      Text(
                        metrics.regime.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: metrics.regime.badgeColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildCompactMetricChip(
                  label: 'ATM IV',
                  value: '${(metrics.atmShortTermIv * 100).toStringAsFixed(1)}%',
                ),
                const SizedBox(width: 8),
                _buildCompactMetricChip(
                  label: '25Δ Skew',
                  value:
                      '${metrics.riskReversal25D >= 0 ? '+' : ''}${(metrics.riskReversal25D * 100).toStringAsFixed(1)}%',
                ),
              ],
            ),
          ),
        ),

        // Interactive 3D Canvas
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final canvasSize =
                  Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  _handleCanvasTap(
                      details.localPosition, canvasSize, analysis);
                },
                onScaleStart: (details) {
                  _lastFocalPoint = details.focalPoint;
                  _baseScale = _scale;
                },
                onScaleUpdate: (details) {
                  setState(() {
                    if (details.pointerCount == 1 && _lastFocalPoint != null) {
                      final delta = details.focalPoint - _lastFocalPoint!;
                      _yaw += delta.dx * 0.008;
                      _pitch -= delta.dy * 0.008;
                      _pitch = _pitch.clamp(0.1, 1.25);
                    } else if (details.pointerCount > 1) {
                      _scale = (_baseScale * details.scale).clamp(0.6, 2.5);
                    }
                    _lastFocalPoint = details.focalPoint;
                  });
                },
                onScaleEnd: (_) => _lastFocalPoint = null,
                child: Stack(
                  children: [
                    Container(
                      color: theme.colorScheme.surface,
                      width: double.infinity,
                      height: double.infinity,
                      child: CustomPaint(
                        painter: _IvSurface3dPainter(
                          grid: analysis.grid,
                          minIv: metrics.minIv,
                          maxIv: metrics.maxIv,
                          yaw: _yaw,
                          pitch: _pitch,
                          scale: _scale,
                          panOffset: _panOffset,
                          inspectedStrikeIdx: _inspectedStrikeIdx,
                          inspectedDteIdx: _inspectedDteIdx,
                          theme: theme,
                        ),
                      ),
                    ),
                    if (_inspectedStrikeIdx != null &&
                        _inspectedDteIdx != null)
                      Positioned(
                        top: 10,
                        left: 16,
                        right: 16,
                        child: _buildInspectedNodeCard(analysis, theme),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom Controls / Coordinate Inspector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.35),
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              // Heatmap legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(metrics.minIv * 100).toStringAsFixed(0)}% Min',
                          style: TextStyle(
                              fontSize: 10,
                              color: theme.textTheme.bodySmall?.color),
                        ),
                        Text(
                          '${(metrics.maxIv * 100).toStringAsFixed(0)}% Max',
                          style: TextStyle(
                              fontSize: 10,
                              color: theme.textTheme.bodySmall?.color),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF1E88E5), // Blue
                            Color(0xFF00ACC1), // Cyan
                            Color(0xFF43A047), // Green
                            Color(0xFFFB8C00), // Orange
                            Color(0xFFE53935), // Red
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Camera Reset Button
              OutlinedButton.icon(
                onPressed: _resetCamera,
                icon: const Icon(Icons.center_focus_strong_rounded, size: 14),
                label: const Text('Center', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleCanvasTap(
      Offset localPos, Size size, IvSurfaceAnalysis analysis) {
    final projected = _IvSurface3dPainter.projectPoints(
      grid: analysis.grid,
      minIv: analysis.metrics.minIv,
      maxIv: analysis.metrics.maxIv,
      yaw: _yaw,
      pitch: _pitch,
      scale: _scale,
      panOffset: _panOffset,
      size: size,
    );

    int? bestS;
    int? bestT;
    double bestDist = 36.0;

    for (int s = 0; s < projected.length; s++) {
      for (int t = 0; t < projected[s].length; t++) {
        final dist = (projected[s][t] - localPos).distance;
        if (dist < bestDist) {
          bestDist = dist;
          bestS = s;
          bestT = t;
        }
      }
    }

    setState(() {
      if (bestS != null && bestT != null) {
        if (_inspectedStrikeIdx == bestS && _inspectedDteIdx == bestT) {
          _inspectedStrikeIdx = null;
          _inspectedDteIdx = null;
        } else {
          _inspectedStrikeIdx = bestS;
          _inspectedDteIdx = bestT;
          HapticFeedback.selectionClick();
        }
      } else {
        _inspectedStrikeIdx = null;
        _inspectedDteIdx = null;
      }
    });
  }

  Widget _buildInspectedNodeCard(
      IvSurfaceAnalysis analysis, ThemeData theme) {
    if (_inspectedStrikeIdx == null || _inspectedDteIdx == null) {
      return const SizedBox.shrink();
    }
    final s = _inspectedStrikeIdx!;
    final t = _inspectedDteIdx!;
    if (s >= analysis.grid.strikes.length || t >= analysis.grid.dtes.length) {
      return const SizedBox.shrink();
    }
    final strike = analysis.grid.strikes[s];
    final moneyness = analysis.grid.moneynessValues[s];
    final dte = analysis.grid.dtes[t];
    final iv = analysis.grid.ivMatrix[s][t];
    final localVol = analysis.grid.localVolMatrix[s][t];

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.amberAccent.withValues(alpha: 0.7),
          width: 1.5,
        ),
      ),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 36,
              decoration: BoxDecoration(
                color: _getHeatmapColor(
                    iv, analysis.metrics.minIv, analysis.metrics.maxIv),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        '\$${strike.toStringAsFixed(1)} Strike',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${(moneyness * 100).toStringAsFixed(0)}% Mny)',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${dte}D DTE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        'IV: ${(iv * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Local Vol: ${(localVol * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Clear Selection',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  _inspectedStrikeIdx = null;
                  _inspectedDteIdx = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: 2D SLICES TAB (SMILE & TERM STRUCTURE)
  // ==========================================
  Widget _build2dSlicesTab(IvSurfaceAnalysis analysis) {
    final theme = Theme.of(context);
    final smiles = analysis.smileSlices;
    final terms = analysis.termSlices;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Section 1: Volatility Smile / Skew across Strikes
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Colors.blue, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Volatility Smile (Strike Skew)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Implied volatility across strikes for the chosen expiry tenor.',
                  style: TextStyle(
                      fontSize: 12, color: theme.textTheme.bodySmall?.color),
                ),
                const SizedBox(height: 12),

                // DTE Selector Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(smiles.length, (idx) {
                      final s = smiles[idx];
                      final isSelected = idx == _selectedSmileIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(s.paramLabel),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedSmileIndex = idx);
                            }
                          },
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                // 2D Curve Chart
                if (smiles.isNotEmpty && _selectedSmileIndex < smiles.length)
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _Iv2dSlicePainter(
                        slice: smiles[_selectedSmileIndex],
                        isSmile: true,
                        theme: theme,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Section 2: Term Structure across Expiries
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.timeline_rounded,
                          color: Colors.purple, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Term Structure (Moneyness)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'ATM vs. OTM volatility across expiration time horizons.',
                  style: TextStyle(
                      fontSize: 12, color: theme.textTheme.bodySmall?.color),
                ),
                const SizedBox(height: 12),

                // Moneyness Selector Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(terms.length, (idx) {
                      final t = terms[idx];
                      final isSelected = idx == _selectedTermIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(t.paramLabel),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedTermIndex = idx);
                            }
                          },
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                // 2D Curve Chart
                if (terms.isNotEmpty && _selectedTermIndex < terms.length)
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _Iv2dSlicePainter(
                        slice: terms[_selectedTermIndex],
                        isSmile: false,
                        theme: theme,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 3: DIAGNOSTICS & ARBITRAGE TAB
  // ==========================================
  Widget _buildDiagnosticsTab(IvSurfaceAnalysis analysis) {
    final theme = Theme.of(context);
    final metrics = analysis.metrics;
    final violations = analysis.arbitrageViolations;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Summary Card
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Surface Quantitative Breakdown',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  metrics.regimeDescription,
                  style: TextStyle(
                      fontSize: 13, color: theme.textTheme.bodyMedium?.color),
                ),
                const SizedBox(height: 16),
                _buildDiagnosticRow(
                  'Term Structure Slope',
                  '${metrics.termSlope >= 0 ? '+' : ''}${(metrics.termSlope * 100).toStringAsFixed(1)}% / yr',
                  metrics.termSlope >= 0
                      ? 'Contango (Normal)'
                      : 'Backwardation (Inverted)',
                  metrics.termSlope >= 0 ? Colors.green : Colors.red,
                ),
                const Divider(height: 20),
                _buildDiagnosticRow(
                  '25-Delta Risk Reversal',
                  '${metrics.riskReversal25D >= 0 ? '+' : ''}${(metrics.riskReversal25D * 100).toStringAsFixed(1)}% vol',
                  metrics.riskReversal25D > 0.05
                      ? 'Put Premium Skew'
                      : 'Balanced',
                  Colors.blue,
                ),
                const Divider(height: 20),
                _buildDiagnosticRow(
                  'Butterfly Smile Skew',
                  '${(metrics.butterflySkew * 100).toStringAsFixed(1)}% vol',
                  'Wing convexity',
                  Colors.purple,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Arbitrage Detection Section
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: violations.isEmpty
                  ? Colors.green.withValues(alpha: 0.4)
                  : Colors.orange.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      violations.isEmpty
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: violations.isEmpty ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        violations.isEmpty
                            ? 'Arbitrage-Free Surface Verified'
                            : '${violations.length} Pricing Discrepancies Detected',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  violations.isEmpty
                      ? 'Total implied variance increases monotonically across DTEs without calendar spread or butterfly strike arbitrage violations.'
                      : 'Potential calendar or strike spread mispricings identified on the surface.',
                  style: TextStyle(
                      fontSize: 12, color: theme.textTheme.bodySmall?.color),
                ),
                if (violations.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...violations.map((v) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.orange, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                v.description,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Dupire Local Volatility Heatmap Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.grid_view_rounded,
                          color: Colors.teal, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Dupire Local Volatility σ_loc(K, T)',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Instantaneous diffusion volatility implied by Black-Scholes strike and calendar differentials.',
                  style: TextStyle(
                      fontSize: 12, color: theme.textTheme.bodySmall?.color),
                ),
                const SizedBox(height: 16),
                _buildLocalVolMatrixView(analysis.grid, theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticRow(
      String label, String value, String subtitle, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: color)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildLocalVolMatrixView(IvSurfaceGrid grid, ThemeData theme) {
    // Show a 5x5 downsampled sample of local vol
    final sampleStrikes = [
      0,
      grid.strikes.length ~/ 4,
      grid.strikes.length ~/ 2,
      (grid.strikes.length * 3) ~/ 4,
      grid.strikes.length - 1
    ];
    final sampleDtes = [
      0,
      grid.dtes.length ~/ 4,
      grid.dtes.length ~/ 2,
      (grid.dtes.length * 3) ~/ 4,
      grid.dtes.length - 1
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(68.0),
        children: [
          // Header Row
          TableRow(
            children: [
              const Padding(
                padding: EdgeInsets.all(4.0),
                child: Text('K \\ DTE',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              ...sampleDtes.map((dIdx) => Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      '${grid.dtes[dIdx]}D',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  )),
            ],
          ),
          // Data Rows
          ...sampleStrikes.map((sIdx) {
            final m = grid.moneynessValues[sIdx];
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    '${(m * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                ...sampleDtes.map((dIdx) {
                  final lv = grid.localVolMatrix[sIdx][dIdx];
                  final color = _getHeatmapColor(lv, 0.15, 0.75);
                  return Container(
                    margin: const EdgeInsets.all(2.0),
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(lv * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  );
                }),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompactMetricChip({
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
                fontSize: 11, color: theme.textTheme.bodySmall?.color),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // EDUCATIONAL DIALOG
  // ==========================================
  void _showEducationalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.school_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Volatility Surface Guide'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildGuideSection(
                title: 'What is an Implied Volatility Surface?',
                content:
                    'Option contracts on the same stock trade at different implied volatilities depending on strike price (moneyness) and time to expiration (DTE). Plotted together in 3D, they form a surface σ(K, T).',
              ),
              const SizedBox(height: 12),
              _buildGuideSection(
                title: 'Volatility Smile & Skew',
                content:
                    'Equities typically feature "Put Skew" where OTM puts trade at higher IV than OTM calls, reflecting market demand for downside crash protection.',
              ),
              const SizedBox(height: 12),
              _buildGuideSection(
                title: 'Term Structure (Contango vs. Backwardation)',
                content:
                    '• Contango: Long-term IV > Short-term IV. Normal, calm regime.\n• Backwardation: Short-term IV > Long-term IV. Inverted surface indicating acute earnings catalyst or market panic.',
              ),
              const SizedBox(height: 12),
              _buildGuideSection(
                title: 'Dupire Local Volatility',
                content:
                    'The instantaneous volatility of the underlying asset diffusion at a specific price and time, derived mathematically from strike and calendar IV slopes.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideSection({required String title, required String content}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(content, style: const TextStyle(fontSize: 12, height: 1.4)),
      ],
    );
  }

  static Color _getHeatmapColor(double val, double minVal, double maxVal) {
    final range = max(0.01, maxVal - minVal);
    final norm = ((val - minVal) / range).clamp(0.0, 1.0);

    if (norm < 0.25) {
      return Color.lerp(const Color(0xFF1E88E5), const Color(0xFF00ACC1),
          norm / 0.25)!;
    } else if (norm < 0.5) {
      return Color.lerp(const Color(0xFF00ACC1), const Color(0xFF43A047),
          (norm - 0.25) / 0.25)!;
    } else if (norm < 0.75) {
      return Color.lerp(const Color(0xFF43A047), const Color(0xFFFB8C00),
          (norm - 0.5) / 0.25)!;
    } else {
      return Color.lerp(const Color(0xFFFB8C00), const Color(0xFFE53935),
          (norm - 0.75) / 0.25)!;
    }
  }
}

// ==========================================
// 3D SURFACE CUSTOM PAINTER
// ==========================================
class _IvSurface3dPainter extends CustomPainter {
  final IvSurfaceGrid grid;
  final double minIv;
  final double maxIv;
  final double yaw;
  final double pitch;
  final double scale;
  final Offset panOffset;
  final int? inspectedStrikeIdx;
  final int? inspectedDteIdx;
  final ThemeData theme;

  _IvSurface3dPainter({
    required this.grid,
    required this.minIv,
    required this.maxIv,
    required this.yaw,
    required this.pitch,
    required this.scale,
    required this.panOffset,
    required this.inspectedStrikeIdx,
    required this.inspectedDteIdx,
    required this.theme,
  });

  static List<List<Offset>> projectPoints({
    required IvSurfaceGrid grid,
    required double minIv,
    required double maxIv,
    required double yaw,
    required double pitch,
    required double scale,
    required Offset panOffset,
    required Size size,
  }) {
    final double centerX = size.width / 2.0 + panOffset.dx;
    final double centerY = size.height / 2.0 + panOffset.dy;
    final double viewRadius = min(size.width, size.height) * 0.42 * scale;

    final int sCount = grid.strikes.length;
    final int tCount = grid.dtes.length;
    if (sCount < 2 || tCount < 2) return [];

    final cosY = cos(yaw);
    final sinY = sin(yaw);
    final cosP = cos(pitch);
    final sinP = sin(pitch);
    const cameraDist = 4.2;

    final List<List<Offset>> projectedPoints = List.generate(
      sCount,
      (_) => List.filled(tCount, Offset.zero),
    );

    final ivRange = max(0.01, maxIv - minIv);

    for (int s = 0; s < sCount; s++) {
      final double normX = (s / (sCount - 1)) * 2.0 - 1.0;
      for (int t = 0; t < tCount; t++) {
        final double normY = (t / (tCount - 1)) * 2.0 - 1.0;
        final double iv = grid.ivMatrix[s][t];
        final double normZ = ((iv - minIv) / ivRange) * 1.4 - 0.7;

        final double x1 = normX * cosY + normY * sinY;
        final double y1 = -normX * sinY + normY * cosY;
        final double z1 = normZ;

        final double x2 = x1;
        final double y2 = y1 * cosP - z1 * sinP;
        final double z2 = y1 * sinP + z1 * cosP;

        final double pDist = max(0.1, y2 + cameraDist);
        final double projX = (x2 * cameraDist) / pDist;
        final double projY = (z2 * cameraDist) / pDist;

        projectedPoints[s][t] = Offset(
          centerX + projX * viewRadius,
          centerY - projY * viewRadius,
        );
      }
    }
    return projectedPoints;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2.0 + panOffset.dx;
    final double centerY = size.height / 2.0 + panOffset.dy;
    final double viewRadius = min(size.width, size.height) * 0.42 * scale;

    final int sCount = grid.strikes.length;
    final int tCount = grid.dtes.length;
    if (sCount < 2 || tCount < 2) return;

    // 1. Transform all (s, t) 3D coordinates
    final cosY = cos(yaw);
    final sinY = sin(yaw);
    final cosP = cos(pitch);
    final sinP = sin(pitch);
    const cameraDist = 4.2;

    final List<List<Offset>> projectedPoints = List.generate(
      sCount,
      (_) => List.filled(tCount, Offset.zero),
    );
    final List<List<double>> depths = List.generate(
      sCount,
      (_) => List.filled(tCount, 0.0),
    );

    final ivRange = max(0.01, maxIv - minIv);

    for (int s = 0; s < sCount; s++) {
      // Moneyness mapped to [-1, 1]
      final double normX = (s / (sCount - 1)) * 2.0 - 1.0;

      for (int t = 0; t < tCount; t++) {
        // DTE mapped to [-1, 1]
        final double normY = (t / (tCount - 1)) * 2.0 - 1.0;

        // IV height mapped to [-0.6, 0.8]
        final double iv = grid.ivMatrix[s][t];
        final double normZ = ((iv - minIv) / ivRange) * 1.4 - 0.7;

        // 3D Rotation: Yaw around Z/Y, Pitch around X
        final double x1 = normX * cosY + normY * sinY;
        final double y1 = -normX * sinY + normY * cosY;
        final double z1 = normZ;

        final double x2 = x1;
        final double y2 = y1 * cosP - z1 * sinP;
        final double z2 = y1 * sinP + z1 * cosP;

        // Perspective projection
        final double pDist = max(0.1, y2 + cameraDist);
        final double projX = (x2 * cameraDist) / pDist;
        final double projY = (z2 * cameraDist) / pDist;

        projectedPoints[s][t] = Offset(
          centerX + projX * viewRadius,
          centerY - projY * viewRadius,
        );
        depths[s][t] = y2;
      }
    }

    // 2. Build and depth-sort polygon quads (Painter's Algorithm)
    final List<_QuadFacet> quads = [];
    for (int s = 0; s < sCount - 1; s++) {
      for (int t = 0; t < tCount - 1; t++) {
        final avgDepth = (depths[s][t] +
                depths[s + 1][t] +
                depths[s + 1][t + 1] +
                depths[s][t + 1]) /
            4.0;

        final avgIv = (grid.ivMatrix[s][t] +
                grid.ivMatrix[s + 1][t] +
                grid.ivMatrix[s + 1][t + 1] +
                grid.ivMatrix[s][t + 1]) /
            4.0;

        quads.add(_QuadFacet(
          s: s,
          t: t,
          depth: avgDepth,
          avgIv: avgIv,
          p1: projectedPoints[s][t],
          p2: projectedPoints[s + 1][t],
          p3: projectedPoints[s + 1][t + 1],
          p4: projectedPoints[s][t + 1],
        ));
      }
    }

    // Sort from back to front (largest depth first)
    quads.sort((a, b) => b.depth.compareTo(a.depth));

    // 3. Render quads with color fill and wireframe edges
    final wirePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final fillPaint = Paint()..style = PaintingStyle.fill;

    for (final quad in quads) {
      final path = Path()
        ..moveTo(quad.p1.dx, quad.p1.dy)
        ..lineTo(quad.p2.dx, quad.p2.dy)
        ..lineTo(quad.p3.dx, quad.p3.dy)
        ..lineTo(quad.p4.dx, quad.p4.dy)
        ..close();

      final color =
          _IvSurface3dWidgetState._getHeatmapColor(quad.avgIv, minIv, maxIv);
      fillPaint.color = color.withValues(alpha: 0.72);

      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, wirePaint);
    }

    // 4. Draw ATM Ridge highlight (where moneyness ~ 1.0)
    int atmIdx = 0;
    double bestAtmDist = double.infinity;
    for (int i = 0; i < grid.moneynessValues.length; i++) {
      final dist = (grid.moneynessValues[i] - 1.0).abs();
      if (dist < bestAtmDist) {
        bestAtmDist = dist;
        atmIdx = i;
      }
    }

    final atmPath = Path();
    for (int t = 0; t < tCount; t++) {
      final pt = projectedPoints[atmIdx][t];
      if (t == 0) {
        atmPath.moveTo(pt.dx, pt.dy);
      } else {
        atmPath.lineTo(pt.dx, pt.dy);
      }
    }

    final atmPaint = Paint()
      ..color = Colors.yellowAccent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    canvas.drawPath(atmPath, atmPaint);

    // 5. Draw Axis Labels
    final textStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: theme.textTheme.bodySmall?.color ?? Colors.grey,
    );

    _drawLabel(canvas, 'OTM Puts', projectedPoints[0][0], textStyle);
    _drawLabel(
        canvas, 'OTM Calls', projectedPoints[sCount - 1][0], textStyle);
    _drawLabel(
        canvas, '${grid.dtes.last}D Back', projectedPoints[sCount ~/ 2][tCount - 1], textStyle);

    // 6. Highlight inspected node if selected
    if (inspectedStrikeIdx != null &&
        inspectedDteIdx != null &&
        inspectedStrikeIdx! >= 0 &&
        inspectedStrikeIdx! < sCount &&
        inspectedDteIdx! >= 0 &&
        inspectedDteIdx! < tCount) {
      final inspectPt = projectedPoints[inspectedStrikeIdx!][inspectedDteIdx!];
      final highlightRingPaint = Paint()
        ..color = Colors.amberAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawCircle(inspectPt, 9.0, highlightRingPaint);

      final highlightInnerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(inspectPt, 4.0, highlightInnerPaint);
    }
  }

  void _drawLabel(
      Canvas canvas, String text, Offset position, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
          position.dx - textPainter.width / 2, position.dy - textPainter.height),
    );
  }

  @override
  bool shouldRepaint(covariant _IvSurface3dPainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.scale != scale ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.inspectedStrikeIdx != inspectedStrikeIdx ||
        oldDelegate.inspectedDteIdx != inspectedDteIdx;
  }
}

class _QuadFacet {
  final int s;
  final int t;
  final double depth;
  final double avgIv;
  final Offset p1;
  final Offset p2;
  final Offset p3;
  final Offset p4;

  const _QuadFacet({
    required this.s,
    required this.t,
    required this.depth,
    required this.avgIv,
    required this.p1,
    required this.p2,
    required this.p3,
    required this.p4,
  });
}

// ==========================================
// 2D SLICE CUSTOM PAINTER
// ==========================================
class _Iv2dSlicePainter extends CustomPainter {
  final IvSurfaceSlice slice;
  final bool isSmile;
  final ThemeData theme;

  _Iv2dSlicePainter({
    required this.slice,
    required this.isSmile,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (slice.xValues.length < 2 || slice.ivValues.length < 2) return;

    final padding = const EdgeInsets.fromLTRB(36, 12, 16, 28);
    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;

    double minIv = double.infinity;
    double maxIv = double.negativeInfinity;
    for (final iv in slice.ivValues) {
      if (iv < minIv) minIv = iv;
      if (iv > maxIv) maxIv = iv;
    }
    final ivRange = max(0.02, maxIv - minIv);
    final minDisplayIv = max(0.0, minIv - ivRange * 0.1);
    final maxDisplayIv = maxIv + ivRange * 0.1;
    final displayRange = max(0.02, maxDisplayIv - minDisplayIv);

    final linePath = Path();
    final fillPath = Path();
    final List<Offset> points = [];

    final count = slice.xValues.length;
    for (int i = 0; i < count; i++) {
      final x = padding.left + (i / (count - 1)) * chartWidth;
      final yNorm = (slice.ivValues[i] - minDisplayIv) / displayRange;
      final y = padding.top + chartHeight * (1.0 - yNorm);

      points.add(Offset(x, y));
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, padding.top + chartHeight);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(points.last.dx, padding.top + chartHeight);
    fillPath.close();

    // Shaded Area Gradient
    final color = isSmile ? Colors.blue : Colors.purple;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(
          padding.left, padding.top, chartWidth, chartHeight));
    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawPath(linePath, strokePaint);

    // Draw Data Point Dots
    final dotPaint = Paint()..color = color;
    for (final pt in points) {
      canvas.drawCircle(pt, 3.0, dotPaint);
    }

    // Y Axis Labels (IV %)
    final textStyle = TextStyle(
      fontSize: 10,
      color: theme.textTheme.bodySmall?.color ?? Colors.grey,
    );
    _drawYAxisLabel(
        canvas,
        '${(maxDisplayIv * 100).toStringAsFixed(0)}%',
        Offset(2, padding.top),
        textStyle);
    _drawYAxisLabel(
        canvas,
        '${(minDisplayIv * 100).toStringAsFixed(0)}%',
        Offset(2, padding.top + chartHeight - 10),
        textStyle);

    // X Axis Labels (first, middle, last)
    _drawXAxisLabel(
        canvas, slice.xLabels.first, Offset(padding.left, size.height - 18), textStyle);
    _drawXAxisLabel(
        canvas, slice.xLabels[count ~/ 2], Offset(padding.left + chartWidth / 2 - 20, size.height - 18), textStyle);
    _drawXAxisLabel(
        canvas, slice.xLabels.last, Offset(padding.left + chartWidth - 30, size.height - 18), textStyle);
  }

  void _drawYAxisLabel(
      Canvas canvas, String text, Offset position, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, position);
  }

  void _drawXAxisLabel(
      Canvas canvas, String text, Offset position, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, position);
  }

  @override
  bool shouldRepaint(covariant _Iv2dSlicePainter oldDelegate) {
    return oldDelegate.slice != slice || oldDelegate.isSmile != isSmile;
  }
}

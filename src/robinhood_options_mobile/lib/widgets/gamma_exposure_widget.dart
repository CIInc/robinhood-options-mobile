import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../model/gamma_exposure_model.dart';

/// Displays Gamma Exposure (GEX) analysis for a given symbol.
///
/// Shows a horizontal bar chart of net GEX by strike, dealer positioning
/// chip, gamma flip level, and max gamma strike markers.
class GammaExposureWidget extends StatefulWidget {
  final String symbol;

  const GammaExposureWidget({super.key, required this.symbol});

  @override
  State<GammaExposureWidget> createState() => _GammaExposureWidgetState();
}

class _GammaExposureWidgetState extends State<GammaExposureWidget> {
  GammaExposureData? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchGEX();
  }

  @override
  void didUpdateWidget(GammaExposureWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol) _fetchGEX();
  }

  Future<void> _fetchGEX() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('getGammaExposure');
      final result = await callable.call<Map<String, dynamic>>({'symbol': widget.symbol});
      final data = GammaExposureData.fromJson(
          Map<String, dynamic>.from(result.data as Map));
      if (mounted) setState(() { _data = data; _loading = false; });
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() { _error = e.message ?? 'GEX unavailable'; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
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
                Text(_error!, style: theme.textTheme.labelSmall
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
        _buildBarChart(context, gex),
        const SizedBox(height: 8),
        _buildLegend(context, gex),
      ],
    );
  }

  Widget _buildSummaryRow(BuildContext context, GammaExposureData gex) {
    final theme = Theme.of(context);
    final positioningColor = gex.dealerPositioning == DealerPositioning.longGamma
        ? Colors.green
        : gex.dealerPositioning == DealerPositioning.shortGamma
            ? Colors.red
            : theme.colorScheme.outline;
    final positioningIcon =
        gex.dealerPositioning == DealerPositioning.longGamma
            ? Icons.compress
            : gex.dealerPositioning == DealerPositioning.shortGamma
                ? Icons.expand
                : Icons.remove;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Chip(
              avatar: Icon(positioningIcon, size: 16, color: positioningColor),
              label: Text(gex.dealerPositioning.displayLabel,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: positioningColor)),
              side: BorderSide(color: positioningColor.withValues(alpha: 0.3)),
              backgroundColor:
                  positioningColor.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Net GEX',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline)),
                Text(gex.formattedNetGEX,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: gex.totalNetGEX >= 0
                            ? Colors.green
                            : Colors.red)),
              ],
            ),
            const SizedBox(width: 16),
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
            if (gex.maxGammaStrike != null) ...[
              const SizedBox(width: 16),
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
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(gex.dealerPositioning.description,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildBarChart(BuildContext context, GammaExposureData gex) {
    final theme = Theme.of(context);
    final strikes = gex.nearMoneyStrikes;
    if (strikes.isEmpty) return const SizedBox.shrink();

    final maxAbs =
        strikes.map((s) => s.netGEX.abs()).reduce(max);
    if (maxAbs == 0) return const SizedBox.shrink();

    return Container(
      height: max(strikes.length * 24.0, 100),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CustomPaint(
        painter: _GexBarChartPainter(
          strikes: strikes,
          maxAbs: maxAbs,
          spotPrice: gex.spotPrice,
          gammaFlip: gex.gammaFlip,
          maxGammaStrike: gex.maxGammaStrike,
          textColor: theme.colorScheme.onSurface,
          outlineColor: theme.colorScheme.outline,
        ),
        size: Size.infinite,
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 2, height: 12,
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
        Container(width: 12, height: 12,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label,
            style: Theme.of(context).textTheme.labelSmall
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
  final Color textColor;
  final Color outlineColor;

  _GexBarChartPainter({
    required this.strikes,
    required this.maxAbs,
    required this.spotPrice,
    required this.gammaFlip,
    required this.maxGammaStrike,
    required this.textColor,
    required this.outlineColor,
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

    for (int i = 0; i < strikes.length; i++) {
      final s = strikes[i];
      final y = i * barHeight;
      final barWidth = (s.netGEX.abs() / maxAbs) * (barAreaWidth / 2);
      final isPositive = s.netGEX >= 0;

      // Highlight max gamma strike row
      if (maxGammaStrike != null && (s.strike - maxGammaStrike!).abs() < 0.01) {
        canvas.drawRect(
          Rect.fromLTWH(barAreaStart, y + 1, barAreaWidth, barHeight - 2),
          maxGammaPaint,
        );
      }

      final barRect = isPositive
          ? Rect.fromLTWH(centerX, y + barHeight * 0.15,
              barWidth, barHeight * 0.7)
          : Rect.fromLTWH(centerX - barWidth, y + barHeight * 0.15,
              barWidth, barHeight * 0.7);

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
  }

  void _drawHorizontalLine(
      Canvas canvas, Size size, double barAreaStart, double barAreaWidth) {
    // Find the y position of the row closest to spot price
    final spotIdx = strikes.indexWhere(
        (s) => (s.strike - spotPrice).abs() ==
            strikes
                .map((s2) => (s2.strike - spotPrice).abs())
                .reduce(min));
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
    final flipIdx = strikes.indexWhere(
        (s) => (s.strike - gammaFlip!).abs() ==
            strikes
                .map((s2) => (s2.strike - gammaFlip!).abs())
                .reduce(min));
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

  @override
  bool shouldRepaint(_GexBarChartPainter oldDelegate) =>
      oldDelegate.strikes != strikes ||
      oldDelegate.spotPrice != spotPrice ||
      oldDelegate.gammaFlip != gammaFlip;
}

/// Full-page wrapper for GEX widget.
class GammaExposurePage extends StatelessWidget {
  final String symbol;

  const GammaExposurePage({super.key, required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gamma Exposure — $symbol'),
        actions: [
          Tooltip(
            message:
                'GEX = net gamma held by market makers.\n'
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
        child: GammaExposureWidget(symbol: symbol),
      ),
    );
  }
}

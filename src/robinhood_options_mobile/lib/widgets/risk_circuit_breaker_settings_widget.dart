import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/risk_circuit_breaker_config.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:robinhood_options_mobile/services/risk_circuit_breaker_service.dart';

/// Interactive Settings and Monitoring page for Autonomous Account Risk Circuit Breakers & Tilt Guardrails.
class RiskCircuitBreakerSettingsWidget extends StatefulWidget {
  final User? user;
  final DocumentReference<User>? userDocRef;
  final FirestoreService? firestoreService;
  final RiskCircuitBreakerService? service;

  const RiskCircuitBreakerSettingsWidget({
    super.key,
    this.user,
    this.userDocRef,
    this.firestoreService,
    this.service,
  });

  @override
  State<RiskCircuitBreakerSettingsWidget> createState() =>
      _RiskCircuitBreakerSettingsWidgetState();
}

class _RiskCircuitBreakerSettingsWidgetState
    extends State<RiskCircuitBreakerSettingsWidget> {
  late RiskCircuitBreakerService _service;
  late RiskCircuitBreakerConfig _config;
  Timer? _countdownTimer;

  late TextEditingController _dollarLossController;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? RiskCircuitBreakerService();
    _config = widget.user?.riskCircuitBreakerConfig ?? _service.config;

    _dollarLossController = TextEditingController(
      text: _config.maxDailyLossAmount != null
          ? _config.maxDailyLossAmount!.toStringAsFixed(0)
          : '',
    );

    _initService();
    _startCountdownTimer();
  }

  Future<void> _initService() async {
    if (widget.service == null) {
      final loaded = await _service.loadConfig(user: widget.user);
      if (mounted) {
        setState(() {
          _config = loaded;
          _dollarLossController.text = _config.maxDailyLossAmount != null
              ? _config.maxDailyLossAmount!.toStringAsFixed(0)
              : '';
        });
      }
    }
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_config.isInCoolingOff) {
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _dollarLossController.dispose();
    super.dispose();
  }

  Future<void> _saveConfig(RiskCircuitBreakerConfig updated) async {
    setState(() {
      _config = updated;
    });

    await _service.updateConfig(
      updated,
      user: widget.user,
      firestoreService: widget.firestoreService,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Risk circuit breaker settings saved'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resetBreaker() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Circuit Breaker?'),
        content: const Text(
          'Resetting the circuit breaker immediately lifts trading suspensions and clears cooling-off timers. Ensure you are emotionally composed and disciplined before proceeding.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.resetCircuitBreaker(
        user: widget.user,
        firestoreService: widget.firestoreService,
      );
      setState(() {
        _config = _service.config;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Circuit breaker reset. Trading restored.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _simulateTrip() {
    _service.tripManually(
      reason: 'Simulation: Daily loss threshold exceeded. Mandatory 2-minute cooling off.',
      durationMinutes: 2,
    );
    setState(() {
      _config = _service.config;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulated 2-minute cooling off period activated.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Circuit Breakers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Breaker',
            onPressed: _config.isExecutionBlocked ? _resetBreaker : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        children: [
          _buildStatusHeaderCard(colorScheme),
          const SizedBox(height: 16),
          _buildMasterToggleCard(colorScheme),
          const SizedBox(height: 16),
          if (_config.enabled) ...[
            _buildDailyLossSection(colorScheme),
            const SizedBox(height: 16),
            _buildDrawdownSection(colorScheme),
            const SizedBox(height: 16),
            _buildConsecutiveLossSection(colorScheme),
            const SizedBox(height: 16),
            _buildMarginBufferSection(colorScheme),
            const SizedBox(height: 16),
            _buildCoolingOffSection(colorScheme),
            const SizedBox(height: 16),
            _buildSimulationCard(colorScheme),
            const SizedBox(height: 24),
          ],
          _buildInfoCard(colorScheme),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusHeaderCard(ColorScheme colorScheme) {
    final isBlocked = _config.isExecutionBlocked;
    final isCoolingOff = _config.isInCoolingOff;
    final remaining = _config.remainingCoolingOff;

    Color cardColor;
    Color textColor;
    IconData icon;
    String statusTitle;
    String statusSubtitle;

    if (!_config.enabled) {
      cardColor = colorScheme.surfaceContainerHighest;
      textColor = colorScheme.onSurfaceVariant;
      icon = Icons.shield_outlined;
      statusTitle = 'Guardrails Inactive';
      statusSubtitle = 'Enable circuit breakers below to guard capital against tilt and catastrophic drawdown.';
    } else if (isCoolingOff) {
      cardColor = colorScheme.errorContainer;
      textColor = colorScheme.onErrorContainer;
      icon = Icons.lock_clock;
      final minutes = remaining?.inMinutes ?? 0;
      final seconds = (remaining?.inSeconds ?? 0) % 60;
      final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
      statusTitle = 'Cooling Off Active ($timeStr)';
      statusSubtitle = _config.tripReason ?? 'Trading orders temporarily suspended to prevent emotional trading.';
    } else if (isBlocked) {
      cardColor = colorScheme.errorContainer;
      textColor = colorScheme.onErrorContainer;
      icon = Icons.block;
      statusTitle = 'Circuit Breaker Tripped';
      statusSubtitle = _config.tripReason ?? 'Trading execution suspended by risk guardrail.';
    } else {
      cardColor = colorScheme.primaryContainer;
      textColor = colorScheme.onPrimaryContainer;
      icon = Icons.shield;
      statusTitle = 'Guarded & Active';
      statusSubtitle = 'Autonomous circuit breakers are monitoring daily loss, drawdown, and margin health.';
    }

    return Card(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: textColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                if (isBlocked)
                  TextButton.icon(
                    onPressed: _resetBreaker,
                    icon: Icon(Icons.restart_alt, size: 18, color: textColor),
                    label: Text(
                      'Reset',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: textColor.withAlpha(30),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              statusSubtitle,
              style: TextStyle(color: textColor.withAlpha(220), fontSize: 13),
            ),
            if (_config.currentConsecutiveLosses > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.trending_down, size: 16, color: textColor),
                  const SizedBox(width: 6),
                  Text(
                    'Current streak: ${_config.currentConsecutiveLosses} consecutive loss${_config.currentConsecutiveLosses == 1 ? '' : 'es'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMasterToggleCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: SwitchListTile(
        title: const Text(
          'Enable Risk Circuit Breakers',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'Automatically halt trading when predefined risk thresholds are breached.',
        ),
        value: _config.enabled,
        onChanged: (val) {
          _saveConfig(_config.copyWith(enabled: val));
        },
      ),
    );
  }

  Widget _buildDailyLossSection(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.attach_money, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Daily Loss Limit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Suspend trading for the day if losses hit dollar or portfolio percentage limits.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dollarLossController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Max Dollar Loss (\$)',
                hintText: 'e.g. 500',
                prefixText: '\$ ',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _dollarLossController.clear();
                    _saveConfig(_config.copyWith(maxDailyLossAmount: null));
                  },
                ),
              ),
              onSubmitted: (val) {
                final amount = double.tryParse(val);
                _saveConfig(_config.copyWith(maxDailyLossAmount: amount));
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [100.0, 250.0, 500.0, 1000.0, 2500.0].map((amt) {
                final isSelected = _config.maxDailyLossAmount == amt;
                return ChoiceChip(
                  label: Text('\$${amt.toStringAsFixed(0)}'),
                  selected: isSelected,
                  onSelected: (selected) {
                    final newAmt = selected ? amt : null;
                    _dollarLossController.text = newAmt != null ? newAmt.toStringAsFixed(0) : '';
                    _saveConfig(_config.copyWith(maxDailyLossAmount: newAmt));
                  },
                );
              }).toList(),
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Max Daily Portfolio Loss (%)'),
                Text(
                  _config.maxDailyLossPercent != null
                      ? '${_config.maxDailyLossPercent!.toStringAsFixed(1)}%'
                      : 'Disabled',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _config.maxDailyLossPercent ?? 0.0,
              min: 0.0,
              max: 10.0,
              divisions: 20,
              label: _config.maxDailyLossPercent != null
                  ? '${_config.maxDailyLossPercent!.toStringAsFixed(1)}%'
                  : 'Off',
              onChanged: (val) {
                final p = val > 0 ? val : null;
                _saveConfig(_config.copyWith(maxDailyLossPercent: p));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawdownSection(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Max Peak Drawdown Limit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Blocks new opening positions if portfolio drops below a specified trailing drawdown from peak equity.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Trailing Drawdown Threshold'),
                Text(
                  _config.maxDrawdownPercent != null
                      ? '${_config.maxDrawdownPercent!.toStringAsFixed(1)}%'
                      : 'Disabled',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _config.maxDrawdownPercent ?? 0.0,
              min: 0.0,
              max: 25.0,
              divisions: 25,
              label: _config.maxDrawdownPercent != null
                  ? '${_config.maxDrawdownPercent!.toStringAsFixed(1)}%'
                  : 'Off',
              onChanged: (val) {
                final dd = val > 0 ? val : null;
                _saveConfig(_config.copyWith(maxDrawdownPercent: dd));
              },
            ),
            if (_config.peakPortfolioEquity != null) ...[
              const SizedBox(height: 4),
              Text(
                'Recorded Peak High-Water Mark: \$${_config.peakPortfolioEquity!.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConsecutiveLossSection(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sentiment_very_dissatisfied, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Consecutive Loss Lockout',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Triggers a mandatory cooling-off period after a losing streak to prevent revenge trading.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [2, 3, 5, 0].map((lossCount) {
                final isSelected = lossCount == 0
                    ? _config.maxConsecutiveLosses == null
                    : _config.maxConsecutiveLosses == lossCount;
                return ChoiceChip(
                  label: Text(lossCount == 0 ? 'Disabled' : '$lossCount Trades'),
                  selected: isSelected,
                  onSelected: (selected) {
                    final newCount = lossCount == 0 ? null : lossCount;
                    _saveConfig(_config.copyWith(maxConsecutiveLosses: newCount));
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarginBufferSection(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Minimum Margin Buffer',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Blocks leverage expansion when available margin cushion drops below this safety buffer.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Margin Buffer Cushion'),
                Text(
                  _config.minMarginBufferPercent != null
                      ? '${_config.minMarginBufferPercent!.toStringAsFixed(1)}%'
                      : 'Disabled',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _config.minMarginBufferPercent ?? 0.0,
              min: 0.0,
              max: 30.0,
              divisions: 30,
              label: _config.minMarginBufferPercent != null
                  ? '${_config.minMarginBufferPercent!.toStringAsFixed(1)}%'
                  : 'Off',
              onChanged: (val) {
                final mb = val > 0 ? val : null;
                _saveConfig(_config.copyWith(minMarginBufferPercent: mb));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoolingOffSection(ColorScheme colorScheme) {
    final durations = [
      {'label': '15 Min', 'val': 15},
      {'label': '30 Min', 'val': 30},
      {'label': '1 Hour', 'val': 60},
      {'label': '2 Hours', 'val': 120},
      {'label': '24 Hours', 'val': 1440},
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'Cooling-Off Period Duration',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Time length that orders remain suspended after a circuit breaker is triggered.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: durations.map((d) {
                final val = d['val'] as int;
                final isSelected = _config.coolingOffDurationMinutes == val;
                return ChoiceChip(
                  label: Text(d['label'] as String),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      _saveConfig(_config.copyWith(coolingOffDurationMinutes: val));
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulationCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(120),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined, color: colorScheme.secondary),
                const SizedBox(width: 8),
                const Text(
                  'Guardrail Test Mode',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Test the circuit breaker behavior and cooling-off alert dialogs safely without risking real capital.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _simulateTrip,
              icon: const Icon(Icons.flash_on, size: 18),
              label: const Text('Simulate 2-Min Circuit Breaker Trip'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              const Text(
                'About Institutional Risk Guardrails',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Autonomous Circuit Breakers replicate the risk controls used by proprietary trading desks and hedge funds. When market volatility or emotional stress induces consecutive losses or rapid drawdowns, trading execution is proactively paused to protect capital and enable a rational reset.',
            style: TextStyle(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

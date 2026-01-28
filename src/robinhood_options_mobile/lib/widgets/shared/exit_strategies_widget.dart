import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/exit_stage.dart';

class ExitStrategiesWidget extends StatefulWidget {
  final TextEditingController takeProfitController;
  final TextEditingController stopLossController;
  final TextEditingController trailingStopController;
  final TextEditingController timeBasedExitController;
  final TextEditingController marketCloseExitController;
  final TextEditingController rsiExitThresholdController;
  final TextEditingController signalStrengthExitThresholdController;

  final bool trailingStopEnabled;
  final bool timeBasedExitEnabled;
  final bool marketCloseExitEnabled;
  final bool partialExitsEnabled;
  final bool rsiExitEnabled;
  final bool signalStrengthExitEnabled;
  final List<ExitStage> exitStages;

  final ValueChanged<bool> onTrailingStopChanged;
  final ValueChanged<bool> onTimeBasedExitChanged;
  final ValueChanged<bool> onMarketCloseExitChanged;
  final ValueChanged<bool> onPartialExitsChanged;
  final ValueChanged<bool> onRsiExitChanged;
  final ValueChanged<bool> onSignalStrengthExitChanged;
  final ValueChanged<List<ExitStage>> onExitStagesChanged;
  final VoidCallback? onSettingsChanged;

  const ExitStrategiesWidget({
    super.key,
    required this.takeProfitController,
    required this.stopLossController,
    required this.trailingStopController,
    required this.timeBasedExitController,
    required this.marketCloseExitController,
    required this.rsiExitThresholdController,
    required this.signalStrengthExitThresholdController,
    required this.trailingStopEnabled,
    required this.timeBasedExitEnabled,
    required this.marketCloseExitEnabled,
    required this.partialExitsEnabled,
    required this.rsiExitEnabled,
    required this.signalStrengthExitEnabled,
    required this.exitStages,
    required this.onTrailingStopChanged,
    required this.onTimeBasedExitChanged,
    required this.onMarketCloseExitChanged,
    required this.onPartialExitsChanged,
    required this.onRsiExitChanged,
    required this.onSignalStrengthExitChanged,
    required this.onExitStagesChanged,
    this.onSettingsChanged,
  });

  @override
  State<ExitStrategiesWidget> createState() => _ExitStrategiesWidgetState();
}

class _ExitStrategiesWidgetState extends State<ExitStrategiesWidget> {
  late List<TextEditingController> _exitStageProfitControllers;
  late List<TextEditingController> _exitStageQuantityControllers;

  @override
  void initState() {
    super.initState();
    _initializeStageControllers();
  }

  @override
  void didUpdateWidget(ExitStrategiesWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.exitStages.length != _exitStageProfitControllers.length) {
      _initializeStageControllers();
    }
  }

  void _initializeStageControllers() {
    _exitStageProfitControllers = widget.exitStages
        .map((s) =>
            TextEditingController(text: s.profitTargetPercent.toString()))
        .toList();
    _exitStageQuantityControllers = widget.exitStages
        .map((s) =>
            TextEditingController(text: (s.quantityPercent * 100).toString()))
        .toList();
  }

  @override
  void dispose() {
    for (var c in _exitStageProfitControllers) {
      c.dispose();
    }
    for (var c in _exitStageQuantityControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _notifySettingsChanged() {
    widget.onSettingsChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_exitStageProfitControllers.length != widget.exitStages.length) {
      _initializeStageControllers();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary Targets Section
        _buildSubsectionTitle(context, 'Primary Targets'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                context,
                widget.takeProfitController,
                'Take Profit',
                suffixText: '%',
                prefixIcon: Icons.trending_up_rounded,
                onChanged: (_) => _notifySettingsChanged(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                context,
                widget.stopLossController,
                'Stop Loss',
                suffixText: '%',
                prefixIcon: Icons.trending_down_rounded,
                onChanged: (_) => _notifySettingsChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSubsectionTitle(context, 'Advanced Exits'),
        const SizedBox(height: 12),

        _buildStrategyCard(
          context,
          'Trailing Stop',
          'Dynamically adjust stop price',
          widget.trailingStopEnabled,
          widget.onTrailingStopChanged,
          icon: Icons.show_chart_rounded,
          extraContent: _buildTextField(
            context,
            widget.trailingStopController,
            'Trailing Distance',
            suffixText: '%',
            helperText: 'Distance from peak price',
            prefixIcon: Icons.space_bar_rounded,
            onChanged: (_) => _notifySettingsChanged(),
          ),
        ),
        const SizedBox(height: 12),

        _buildStrategyCard(
          context,
          'Time-Based Exit',
          'Close trade after a fixed duration',
          widget.timeBasedExitEnabled,
          widget.onTimeBasedExitChanged,
          icon: Icons.timer_outlined,
          extraContent: _buildTextField(
            context,
            widget.timeBasedExitController,
            'Max Hold Time',
            suffixText: 'min',
            prefixIcon: Icons.hourglass_top_rounded,
            onChanged: (_) => _notifySettingsChanged(),
          ),
        ),
        const SizedBox(height: 12),

        _buildStrategyCard(
          context,
          'Market Close Exit',
          'Close positions before market close',
          widget.marketCloseExitEnabled,
          widget.onMarketCloseExitChanged,
          icon: Icons.schedule_rounded,
          extraContent: _buildTextField(
            context,
            widget.marketCloseExitController,
            'Exits Before Close',
            suffixText: 'min',
            helperText: 'Minutes before session end',
            prefixIcon: Icons.alarm_rounded,
            onChanged: (_) => _notifySettingsChanged(),
          ),
        ),
        const SizedBox(height: 12),

        _buildStrategyCard(
          context,
          'RSI Exit',
          'Exit when asset becomes overbought',
          widget.rsiExitEnabled,
          widget.onRsiExitChanged,
          icon: Icons.speed_rounded,
          extraContent: _buildTextField(
            context,
            widget.rsiExitThresholdController,
            'RSI Threshold',
            helperText: 'Usually 70-80',
            prefixIcon: Icons.warning_amber_rounded,
            onChanged: (_) => _notifySettingsChanged(),
          ),
        ),
        const SizedBox(height: 12),

        _buildStrategyCard(
          context,
          'Signal Strength Exit',
          'Exit if signal strength drops',
          widget.signalStrengthExitEnabled,
          widget.onSignalStrengthExitChanged,
          icon: Icons.signal_cellular_alt_rounded,
          extraContent: _buildTextField(
            context,
            widget.signalStrengthExitThresholdController,
            'Min Signal Score',
            helperText: 'Exit if score drops below this',
            prefixIcon: Icons.low_priority_rounded,
            onChanged: (_) => _notifySettingsChanged(),
          ),
        ),
        const SizedBox(height: 16),
        _buildSubsectionTitle(context, 'Scaling Out'),
        const SizedBox(height: 12),
        _buildStrategyCard(
          context,
          'Partial Exits',
          'Scale out at defined profit levels',
          widget.partialExitsEnabled,
          widget.onPartialExitsChanged,
          icon: Icons.pie_chart_outline_rounded,
          extraContent: _buildPartialExitsContent(context),
        ),
      ],
    );
  }

  Widget _buildSubsectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }

  Widget _buildPartialExitsContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (widget.exitStages.isEmpty)
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'No exit stages configured.',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ...List.generate(widget.exitStages.length, (index) {
          final stage = widget.exitStages[index];
          if (index >= _exitStageProfitControllers.length) {
            return const SizedBox.shrink();
          }
          final profitController = _exitStageProfitControllers[index];
          final quantityController = _exitStageQuantityControllers[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.1),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Stage ${index + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        final newStages =
                            List<ExitStage>.from(widget.exitStages);
                        newStages.removeAt(index);
                        widget.onExitStagesChanged(newStages);
                        _notifySettingsChanged();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        context,
                        profitController,
                        'Profit Target',
                        suffixText: '%',
                        prefixIcon: Icons.trending_up,
                        onChanged: (value) {
                          final val = double.tryParse(value);
                          if (val != null) {
                            final newStages =
                                List<ExitStage>.from(widget.exitStages);
                            newStages[index] = ExitStage(
                              profitTargetPercent: val,
                              quantityPercent: stage.quantityPercent,
                            );
                            widget.onExitStagesChanged(newStages);
                            _notifySettingsChanged();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        context,
                        quantityController,
                        'Sell Amount',
                        suffixText: '%',
                        prefixIcon: Icons.pie_chart,
                        onChanged: (value) {
                          final val = double.tryParse(value);
                          if (val != null) {
                            final newStages =
                                List<ExitStage>.from(widget.exitStages);
                            newStages[index] = ExitStage(
                              profitTargetPercent: stage.profitTargetPercent,
                              quantityPercent: val / 100.0,
                            );
                            widget.onExitStagesChanged(newStages);
                            _notifySettingsChanged();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sell ${(stage.quantityPercent * 100).toStringAsFixed(0)}% of position when profit reaches ${stage.profitTargetPercent}%',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: TextButton.icon(
            onPressed: () {
              final newStage = ExitStage(
                profitTargetPercent: widget.exitStages.isEmpty ? 5.0 : 10.0,
                quantityPercent: 0.5,
              );
              final newStages = List<ExitStage>.from(widget.exitStages)
                ..add(newStage);
              widget.onExitStagesChanged(newStages);
              _notifySettingsChanged();
            },
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: const Text('Add Exit Stage'),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStrategyCard(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    required IconData icon,
    Widget? extraContent,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: value
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outline.withValues(alpha: 0.1),
          width: value ? 1.5 : 1,
        ),
      ),
      color: value
          ? colorScheme.primaryContainer.withValues(alpha: 0.05)
          : colorScheme.surface,
      child: Column(
        children: [
          SwitchListTile(
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
            value: value,
            onChanged: (val) {
              onChanged(val);
              _notifySettingsChanged();
            },
            activeColor: colorScheme.primary,
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: value
                    ? colorScheme.primary.withValues(alpha: 0.1)
                    : colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color:
                    value ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          if (value && extraContent != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Divider(
                    height: 24,
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  extraContent,
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller,
    String label, {
    String? helperText,
    String? suffixText,
    IconData? prefixIcon,
    ValueChanged<String>? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        helperText: helperText,
        helperStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
        suffixText: suffixText,
        suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon,
                size: 18, color: colorScheme.primary.withValues(alpha: 0.8))
            : null,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
    );
  }
}

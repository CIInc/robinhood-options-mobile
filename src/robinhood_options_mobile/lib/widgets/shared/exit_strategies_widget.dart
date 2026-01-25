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
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                widget.takeProfitController,
                'Take Profit',
                suffixText: '%',
                prefixIcon: Icons.trending_up,
                onChanged: (_) => _notifySettingsChanged(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                widget.stopLossController,
                'Stop Loss',
                suffixText: '%',
                prefixIcon: Icons.trending_down,
                onChanged: (_) => _notifySettingsChanged(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildSwitchListTile(
          context,
          'Trailing Stop',
          'Dynamically adjust stop price',
          widget.trailingStopEnabled,
          widget.onTrailingStopChanged,
          extraContent: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildTextField(
              widget.trailingStopController,
              'Trailing Stop Distance',
              suffixText: '%',
              prefixIcon: Icons.show_chart,
              onChanged: (_) => _notifySettingsChanged(),
            ),
          ),
        ),
        const Divider(height: 24),
        _buildSwitchListTile(
          context,
          'Time-Based Hard Stop',
          'Close trade after fixed duration',
          widget.timeBasedExitEnabled,
          widget.onTimeBasedExitChanged,
          extraContent: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildTextField(
              widget.timeBasedExitController,
              'Max Hold Time',
              suffixText: 'min',
              prefixIcon: Icons.timer,
              onChanged: (_) => _notifySettingsChanged(),
            ),
          ),
        ),
        _buildSwitchListTile(
          context,
          'Market Close Exit',
          'Close positions before market close',
          widget.marketCloseExitEnabled,
          widget.onMarketCloseExitChanged,
          extraContent: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildTextField(
              widget.marketCloseExitController,
              'Mins Before Close',
              suffixText: 'min',
              prefixIcon: Icons.schedule,
              onChanged: (_) => _notifySettingsChanged(),
            ),
          ),
        ),
        const Divider(height: 24),
        _buildSwitchListTile(
          context,
          'RSI Overbought Exit',
          'Exit if RSI crosses threshold',
          widget.rsiExitEnabled,
          widget.onRsiExitChanged,
          extraContent: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildTextField(
              widget.rsiExitThresholdController,
              'RSI Threshold',
              suffixText: '',
              prefixIcon: Icons.show_chart,
              onChanged: (_) => _notifySettingsChanged(),
            ),
          ),
        ),
        _buildSwitchListTile(
          context,
          'Weak Signal Exit',
          'Exit if signal strength drops',
          widget.signalStrengthExitEnabled,
          widget.onSignalStrengthExitChanged,
          extraContent: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildTextField(
              widget.signalStrengthExitThresholdController,
              'Min Signal Strength',
              suffixText: '',
              prefixIcon: Icons.signal_cellular_alt,
              onChanged: (_) => _notifySettingsChanged(),
            ),
          ),
        ),
        const Divider(height: 24),
        _buildSwitchListTile(
          context,
          'Partial Exits',
          'Scale out at defined profit levels',
          widget.partialExitsEnabled,
          widget.onPartialExitsChanged,
          extraContent: _buildPartialExitsContent(context),
        ),
      ],
    );
  }

  Widget _buildPartialExitsContent(BuildContext context) {
    return Column(
      children: [
        if (widget.exitStages.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'No exit stages configured.',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
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
              color: Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.1),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Stage ${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
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
                          Icons.close,
                          size: 18,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
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
                            // Avoid full rebuild loop if just text change, but for simplicity:
                            // We don't call onExitStagesChanged here immediately if it triggers rebuild of text field?
                            // Actually it's safer to only commit on save or debounce.
                            // But following parent pattern:
                            // We need to update the model.
                            // The controllers are local, so they won't lose focus/state if we don't rebuild the whole widget tree destructively.
                            widget.onExitStagesChanged(newStages);
                            _notifySettingsChanged();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
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
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: OutlinedButton.icon(
            onPressed: () {
              final newStage = ExitStage(
                profitTargetPercent: widget.exitStages.isEmpty ? 5.0 : 10.0,
                quantityPercent: 0.5,
              );
              final newStages = List<ExitStage>.from(widget.exitStages)
                ..add(newStage);

              // We need to add controllers locally too before rebuild?
              // uniqueKey or letting didUpdateWidget handle it.
              // If we callback, parent updates list, `didUpdateWidget` runs, adds controllers.
              widget.onExitStagesChanged(newStages);
              _notifySettingsChanged();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Exit Stage'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchListTile(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    Widget? extraContent,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          value: value,
          onChanged: (val) {
            onChanged(val);
            _notifySettingsChanged();
          },
          contentPadding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        if (value && extraContent != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: extraContent,
          ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    String? helperText,
    String? suffixText,
    IconData? prefixIcon,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        suffixText: suffixText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
    );
  }
}

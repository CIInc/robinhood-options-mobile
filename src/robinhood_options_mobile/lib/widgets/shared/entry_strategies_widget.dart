import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/custom_indicator_config.dart';
import 'package:robinhood_options_mobile/widgets/indicator_documentation_widget.dart';

class IndicatorMetadata {
  final String label;
  final String description;
  final IconData icon;
  const IndicatorMetadata(this.label, this.description, this.icon);
}

class EntryStrategiesWidget extends StatelessWidget {
  final bool requireAllIndicatorsGreen;
  final ValueChanged<bool> onRequireStrictEntryChanged;
  final TextEditingController minSignalStrengthController;
  final Map<String, bool> enabledIndicators;
  final Map<String, String> indicatorReasons;
  final Function(String key, bool value) onToggleIndicator;
  final VoidCallback onToggleAllIndicators;
  final TextEditingController rsiPeriodController;
  final TextEditingController rocPeriodController;
  final TextEditingController smaFastController;
  final TextEditingController smaSlowController;
  final TextEditingController marketIndexController;
  final List<CustomIndicatorConfig> customIndicators;
  final VoidCallback onAddCustomIndicator;
  final Function(CustomIndicatorConfig) onEditCustomIndicator;
  final Function(CustomIndicatorConfig) onRemoveCustomIndicator;

  static const Map<String, IndicatorMetadata> indicatorMetadata = {
    'priceMovement': IndicatorMetadata('Price Movement',
        'Chart patterns and trend analysis', Icons.show_chart),
    'momentum': IndicatorMetadata(
        'Momentum (RSI)',
        'Relative Strength Index - overbought/oversold conditions',
        Icons.speed),
    'marketDirection': IndicatorMetadata('Market Direction',
        'Moving averages on market index (SPY)', Icons.trending_up),
    'volume': IndicatorMetadata(
        'Volume', 'Volume confirmation with price movement', Icons.bar_chart),
    'macd': IndicatorMetadata(
        'MACD', 'Moving Average Convergence Divergence', Icons.compare_arrows),
    'bollingerBands': IndicatorMetadata(
        'Bollinger Bands', 'Volatility and price level analysis', Icons.waves),
    'stochastic': IndicatorMetadata(
        'Stochastic Oscillator',
        'Momentum indicator comparing closing price to price range',
        Icons.swap_vert),
    'atr': IndicatorMetadata(
        'ATR', 'Average True Range - volatility measurement', Icons.height),
    'obv': IndicatorMetadata('OBV', 'On-Balance Volume - volume flow indicator',
        Icons.waterfall_chart),
    'vwap': IndicatorMetadata(
        'VWAP',
        'Volume Weighted Average Price - institutional price level',
        Icons.money),
    'adx': IndicatorMetadata(
        'ADX',
        'Average Directional Index - trend strength measurement',
        Icons.directions),
    'williamsR': IndicatorMetadata('Williams %R',
        'Momentum oscillator - overbought/oversold conditions', Icons.percent),
    'ichimoku': IndicatorMetadata('Ichimoku Cloud',
        'Trend, support/resistance, and momentum', Icons.cloud),
    'cci': IndicatorMetadata('CCI',
        'Commodity Channel Index - identifies cyclical trends', Icons.cyclone),
    'parabolicSar': IndicatorMetadata('Parabolic SAR',
        'Price trends and reversals - stop and reverse', Icons.trending_up),
    'roc': IndicatorMetadata(
        'ROC', 'Rate of Change - price momentum', Icons.show_chart),
    'chaikinMoneyFlow': IndicatorMetadata('Chaikin Money Flow',
        'Buying/selling pressure based on Volume and Price', Icons.payments),
    'fibonacciRetracements': IndicatorMetadata('Fibonacci Retracements',
        'Support/Resistance levels based on Golden Ratio', Icons.table_rows),
    'pivotPoints': IndicatorMetadata('Pivot Points',
        'Support/Resistance based on previous day prices', Icons.pivot_table_chart),
  };

  static final TextEditingController _disabled100Controller =
      TextEditingController(text: '100');

  const EntryStrategiesWidget({
    super.key,
    required this.requireAllIndicatorsGreen,
    required this.onRequireStrictEntryChanged,
    required this.minSignalStrengthController,
    required this.enabledIndicators,
    this.indicatorReasons = const {},
    required this.onToggleIndicator,
    required this.onToggleAllIndicators,
    required this.rsiPeriodController,
    required this.rocPeriodController,
    required this.smaFastController,
    required this.smaSlowController,
    required this.marketIndexController,
    this.customIndicators = const [],
    required this.onAddCustomIndicator,
    required this.onEditCustomIndicator,
    required this.onRemoveCustomIndicator,
  });

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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
              child: Text(
                'Active Indicators',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
/*
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.dashboard_customize_outlined,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Active Indicators',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Indicator Documentation',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showDocumentationDialog(context),
                ),
              ],
            ),
*/
            Row(children: [
              IconButton(
                icon: Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                tooltip: 'Indicator Documentation',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showDocumentationDialog(context),
              ),
              TextButton.icon(
                onPressed: onToggleAllIndicators,
                icon: const Icon(Icons.select_all, size: 16),
                label: const Text('Toggle All'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 12),
        ...enabledIndicators.keys
            .map((key) => _buildIndicatorToggle(context, key)),
        // const SizedBox(height: 16),
        _buildSubsectionTitle(context, 'Configuration'),

        // Indicator Parameters Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          color: colorScheme.surface,
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              splashColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            child: ExpansionTile(
              backgroundColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
              collapsedBackgroundColor:
                  colorScheme.surfaceContainer.withValues(alpha: 0.3),
              shape: const Border.fromBorderSide(BorderSide.none),
              collapsedShape: const Border.fromBorderSide(BorderSide.none),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.tune_rounded,
                    size: 18, color: colorScheme.secondary),
              ),
              title: Text('Indicator Parameters',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface)),
              childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            context, rsiPeriodController, 'RSI Period',
                            prefixIcon: Icons.speed_rounded)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildTextField(
                            context, rocPeriodController, 'ROC Period',
                            prefixIcon: Icons.show_chart_rounded)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _buildTextField(
                            context, smaFastController, 'Fast SMA',
                            prefixIcon: Icons.trending_up_rounded)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildTextField(
                            context, smaSlowController, 'Slow SMA',
                            prefixIcon: Icons.timeline_rounded)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(context, marketIndexController, 'Market Index',
                    helperText: 'e.g. SPY, QQQ',
                    prefixIcon: Icons.bar_chart_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Strict Entry Mode Card
        _buildSwitchListTile(
          context,
          'Strict Entry Mode',
          'Require ALL enabled indicators to be green',
          requireAllIndicatorsGreen,
          onRequireStrictEntryChanged,
        ),
        const SizedBox(height: 12),

        // Signal Strength Section
        if (requireAllIndicatorsGreen)
          _buildTextField(
            context,
            _disabled100Controller,
            'Min Signal Strength',
            suffixText: '%',
            helperText: 'Required confidence score (Fixed)',
            enabled: false,
            prefixIcon: Icons.lock_outline,
          )
        else
          StatefulBuilder(builder: (context, setState) {
            final double currentValue =
                double.tryParse(minSignalStrengthController.text) ?? 75.0;
            return Container(
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.signal_cellular_alt_rounded,
                              size: 20, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Min Signal Strength',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${currentValue.toInt()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text('0',
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 20),
                          ),
                          child: Slider(
                            value: currentValue.clamp(0.0, 100.0),
                            min: 0,
                            max: 100,
                            divisions: 100,
                            label: currentValue.toInt().toString(),
                            onChanged: (val) {
                              setState(() {
                                minSignalStrengthController.text =
                                    val.toInt().toString();
                              });
                            },
                          ),
                        ),
                      ),
                      Text('100',
                          style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Minimum confidence score required for entry',
                    style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.8)),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 12),
        _buildCustomIndicatorsSection(context),
      ],
    );
  }

  Widget _buildCustomIndicatorsSection(BuildContext context) {
    var colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSubsectionTitle(context, 'Custom Indicators'),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: onAddCustomIndicator,
              tooltip: 'Add Custom Indicator',
              color: colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (customIndicators.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.1),
                style: BorderStyle.solid,
              ),
            ),
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_graph_rounded,
                      size: 32,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No custom indicators defined',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...customIndicators.map((indicator) {
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              color: colorScheme.surface,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.extension_rounded,
                      size: 20, color: colorScheme.primary),
                ),
                title: Text(
                  indicator.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${indicator.type.toString().split('.').last} • ${indicator.condition.toString().split('.').last} ${indicator.compareToPrice ? 'Price' : indicator.threshold}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit',
                        onPressed: () => onEditCustomIndicator(indicator)),
                    IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            size: 20, color: colorScheme.error),
                        tooltip: 'Remove',
                        onPressed: () => onRemoveCustomIndicator(indicator)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _showDocumentationDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.analytics,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            const Text('Technical Indicators'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: indicatorMetadata.keys
                  .map((key) => IndicatorDocumentationWidget(
                        indicatorKey: key,
                        showContainer: true,
                      ))
                  .toList(),
            ),
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
  }

  Widget _buildIndicatorToggle(BuildContext context, String key) {
    final isEnabled = enabledIndicators[key] ?? true;
    final colorScheme = Theme.of(context).colorScheme;
    final metadata = indicatorMetadata[key] ??
        IndicatorMetadata(key, 'Custom Indicator', Icons.extension);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isEnabled
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outline.withValues(alpha: 0.1),
          width: isEnabled ? 1.5 : 1,
        ),
      ),
      color: isEnabled
          ? colorScheme.primaryContainer.withValues(alpha: 0.05)
          : colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => onToggleIndicator(key, !isEnabled),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? colorScheme.primary.withValues(alpha: 0.1)
                      : colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  metadata.icon,
                  color: isEnabled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            metadata.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isEnabled
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurface
                                      .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        if (indicatorReasons[key] != null &&
                            indicatorReasons[key]!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: colorScheme.secondary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metadata.description,
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isEnabled) _getIndicatorSubtitle(context, key),
                  ],
                ),
              ),
              Switch(
                value: isEnabled,
                onChanged: (val) => onToggleIndicator(key, val),
                activeColor: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getIndicatorSubtitle(BuildContext context, String key) {
    String text = '';
    if (key == 'momentum') text = 'Period: ${rsiPeriodController.text}';
    if (key == 'priceMovement') {
      text = 'S: ${smaFastController.text} L: ${smaSlowController.text}';
    }
    if (key == 'marketDirection') {
      text = 'Index: ${marketIndexController.text}';
    }

    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w500)),
    );
  }

  // ... (keeping _buildSwitchListTile and _buildTextField same as before, simplified definition for replacement)
  Widget _buildSwitchListTile(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool isSecondary = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: value
            ? colorScheme.primaryContainer.withValues(alpha: 0.15)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? colorScheme.primary.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: SwitchListTile(
        title: Text(title,
            style: TextStyle(
                fontWeight: isSecondary ? FontWeight.normal : FontWeight.w600,
                fontSize: isSecondary ? 14 : 15,
                color: colorScheme.onSurface)),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8))),
        value: value,
        onChanged: onChanged,
        activeColor: colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    TextInputType keyboardType = TextInputType.number,
    bool enabled = true,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: enabled
              ? colorScheme.onSurface
              : colorScheme.onSurface.withValues(alpha: 0.5)),
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
        filled: true,
        fillColor: enabled
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      keyboardType: keyboardType,
      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
    );
  }
}

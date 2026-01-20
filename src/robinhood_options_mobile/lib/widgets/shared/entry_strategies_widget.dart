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
  final Function(String key, bool value) onToggleIndicator;
  final VoidCallback onToggleAllIndicators;
  final TextEditingController rsiPeriodController;
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
  };

  static final TextEditingController _disabled100Controller =
      TextEditingController(text: '100');

  const EntryStrategiesWidget({
    super.key,
    required this.requireAllIndicatorsGreen,
    required this.onRequireStrictEntryChanged,
    required this.minSignalStrengthController,
    required this.enabledIndicators,
    required this.onToggleIndicator,
    required this.onToggleAllIndicators,
    required this.rsiPeriodController,
    required this.smaFastController,
    required this.smaSlowController,
    required this.marketIndexController,
    this.customIndicators = const [],
    required this.onAddCustomIndicator,
    required this.onEditCustomIndicator,
    required this.onRemoveCustomIndicator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              icon: Icon(
                Icons.info_outline,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: const Text('Indicator Documentation'),
              onPressed: () => _showDocumentationDialog(context),
            ),
          ],
        ),
        _buildSwitchListTile(
          context,
          'Strict Entry Mode',
          'Require ALL enabled indicators to be green',
          requireAllIndicatorsGreen,
          onRequireStrictEntryChanged,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          context,
          requireAllIndicatorsGreen
              ? _disabled100Controller
              : minSignalStrengthController,
          'Min Signal Strength',
          suffixText: '%',
          helperText: 'Minimum confidence score required',
          enabled: !requireAllIndicatorsGreen,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Active Indicators',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            TextButton.icon(
              onPressed: onToggleAllIndicators,
              icon: const Icon(Icons.select_all, size: 16),
              label: const Text('Toggle All'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...enabledIndicators.keys
            .map((key) => _buildIndicatorToggle(context, key)),
        const SizedBox(height: 16),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: const Text('Indicator Parameters',
                style: TextStyle(fontSize: 14)),
            tilePadding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 8),
              _buildTextField(context, rsiPeriodController, 'RSI Period'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: _buildTextField(
                          context, smaFastController, 'Fast SMA')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildTextField(
                          context, smaSlowController, 'Slow SMA')),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(context, marketIndexController, 'Market Index',
                  helperText: 'SPY or QQQ'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(),
        const SizedBox(height: 8),
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
            Row(
              children: [
                Icon(
                  Icons.build,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Custom Indicators',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: onAddCustomIndicator,
              tooltip: 'Add Custom Indicator',
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (customIndicators.isEmpty)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('No custom indicators defined'),
              ),
            ),
          )
        else
          ...customIndicators.map((indicator) {
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: ListTile(
                title: Text(indicator.name),
                subtitle: Text(
                    '${indicator.type.toString().split('.').last} - ${indicator.condition.toString().split('.').last} ${indicator.compareToPrice ? 'Price' : indicator.threshold}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => onEditCustomIndicator(indicator)),
                    IconButton(
                        icon: const Icon(Icons.delete),
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
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isEnabled
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outline.withValues(alpha: 0.2),
          width: isEnabled ? 1.5 : 1,
        ),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isEnabled
                ? colorScheme.primary.withValues(alpha: 0.1)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            metadata.icon,
            color:
                isEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        title: Text(
          metadata.label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isEnabled
                ? colorScheme.onSurface
                : colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(metadata.description, style: const TextStyle(fontSize: 12)),
            if (isEnabled) _getIndicatorSubtitle(context, key),
          ],
        ),
        value: isEnabled,
        onChanged: (val) => onToggleIndicator(key, val),
        activeThumbColor: colorScheme.primary,
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isEnabled ? colorScheme.primary.withValues(alpha: 0.05) : null,
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
    return SwitchListTile(
      title: Text(title,
          style: TextStyle(
              fontWeight: isSecondary ? FontWeight.normal : FontWeight.w600,
              fontSize: isSecondary ? 14 : 16)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
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
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        suffixText: suffixText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      ),
      keyboardType: keyboardType,
      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
    );
  }
}

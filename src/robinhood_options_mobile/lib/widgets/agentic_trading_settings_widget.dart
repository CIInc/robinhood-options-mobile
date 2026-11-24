import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_provider.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/backtesting_provider.dart';
import 'package:robinhood_options_mobile/model/custom_indicator_config.dart';
import 'package:robinhood_options_mobile/model/trade_strategies.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/agentic_trading_performance_widget.dart';
import 'package:robinhood_options_mobile/widgets/backtesting_widget.dart';
import 'package:robinhood_options_mobile/widgets/custom_indicator_page.dart';
import 'package:robinhood_options_mobile/widgets/trading_strategies_page.dart';
import 'package:robinhood_options_mobile/widgets/shared/entry_strategies_widget.dart';
import 'package:robinhood_options_mobile/widgets/shared/exit_strategies_widget.dart';
import 'package:robinhood_options_mobile/widgets/shared/strategy_details_bottom_sheet.dart';
import 'package:robinhood_options_mobile/widgets/trade_signal_notification_settings_widget.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/agentic_trading_background_service.dart';
import 'package:robinhood_options_mobile/services/agentic_trading_run_journal.dart';
import 'package:robinhood_options_mobile/model/brokerage_user_store.dart';
import 'package:robinhood_options_mobile/model/account_store.dart';
import 'package:robinhood_options_mobile/model/paper_trading_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/services/generative_service.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/widgets/trade_signals_page.dart';
import 'package:robinhood_options_mobile/widgets/automated_trading_approvals_widget.dart';
import 'package:robinhood_options_mobile/widgets/strategy_archetype_card.dart';
import 'package:robinhood_options_mobile/widgets/strategy_archetype_detail_bottom_sheet.dart';
import 'package:robinhood_options_mobile/widgets/beta_labs_widget.dart';
import 'package:robinhood_options_mobile/services/feature_access_service.dart';
import 'package:robinhood_options_mobile/widgets/simplified_trading_controls_widget.dart';
import 'package:robinhood_options_mobile/widgets/quant_pro_settings_view.dart';

class AgenticTradingSettingsWidget extends StatefulWidget {
  final User user;
  final DocumentReference<User> userDocRef;
  final IBrokerageService? service;
  final String? initialSection;
  final FeatureAccessService? featureAccessService;

  const AgenticTradingSettingsWidget({
    super.key,
    required this.user,
    required this.userDocRef,
    this.service,
    this.initialSection,
    this.featureAccessService,
  });

  @override
  State<AgenticTradingSettingsWidget> createState() =>
      _AgenticTradingSettingsWidgetState();
}

class _BackgroundActivityPanel extends StatefulWidget {
  const _BackgroundActivityPanel();

  @override
  State<_BackgroundActivityPanel> createState() =>
      _BackgroundActivityPanelState();
}

class _BackgroundActivityPanelState extends State<_BackgroundActivityPanel> {
  late Future<List<Map<String, dynamic>>> _entries;
  late Future<BackgroundExecutionReadiness> _readiness;

  @override
  void initState() {
    super.initState();
    _entries = AgenticTradingRunJournal.recent(limit: 8);
    _readiness = AgenticTradingBackgroundService.inspectPlatformReadiness();
  }

  void _refresh() {
    setState(() {
      _entries = AgenticTradingRunJournal.recent(limit: 8);
      _readiness = AgenticTradingBackgroundService.inspectPlatformReadiness();
    });
  }

  Future<void> _openBackgroundSettings() async {
    await AgenticTradingBackgroundService.openPlatformBackgroundSettings();
    if (!mounted) return;
    _refresh();
  }

  Widget _buildReadinessBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<BackgroundExecutionReadiness>(
      future: _readiness,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        final readiness = snapshot.data;
        if (readiness == null) {
          return const SizedBox.shrink();
        }
        final isRestrictedPlatform = !readiness.isReady &&
            (readiness.platform == 'ios' || readiness.platform == 'android');
        final accentColor = readiness.isReady
            ? Colors.green
            : isRestrictedPlatform
                ? colorScheme.error
                : colorScheme.onSurfaceVariant;
        final bgColor = readiness.isReady
            ? Colors.green.withValues(alpha: 0.08)
            : isRestrictedPlatform
                ? colorScheme.errorContainer.withValues(alpha: 0.35)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35);
        final icon = readiness.isReady
            ? Icons.verified_user_outlined
            : isRestrictedPlatform
                ? Icons.warning_amber_rounded
                : Icons.info_outline;

        return Container(
          key: const ValueKey('background-platform-readiness-card'),
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      readiness.statusSummary,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                    ),
                  ),
                ],
              ),
              for (final warning in readiness.warnings) ...[
                const SizedBox(height: 6),
                Text(
                  warning,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
              if (readiness.remediationHint != null) ...[
                const SizedBox(height: 6),
                Text(
                  readiness.remediationHint!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
              if (!readiness.isReady && readiness.canOpenSettings) ...[
                const SizedBox(height: 6),
                TextButton.icon(
                  key: const ValueKey('open-background-settings-button'),
                  onPressed: _openBackgroundSettings,
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: const Text('Configure Background Settings'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
        leading: const Icon(Icons.history),
        title: const Text('Background activity'),
        subtitle: const Text('On-device task and cycle records'),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Refresh background activity',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ),
          _buildReadinessBanner(context),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _entries,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const ListTile(
                  title: Text('Loading local diagnostics...'),
                );
              }
              if (snapshot.hasError) {
                return const ListTile(
                  title: Text('Could not read local diagnostics.'),
                );
              }
              final entries = snapshot.data ?? const [];
              if (entries.isEmpty) {
                return const ListTile(
                  title: Text('No local diagnostic events recorded.'),
                );
              }
              return Column(
                children: entries.map((entry) {
                  final timestamp =
                      DateTime.tryParse(entry['at'] as String? ?? '')
                          ?.toLocal();
                  final cycleId = entry['cycleId'] as String?;
                  final sources = entry['brokerageSources'];
                  final details = [
                    if (entry['trigger'] case final String trigger) trigger,
                    if (entry['phase'] case final String phase) phase,
                    if (entry['reason'] case final String reason) reason,
                    if (sources is List && sources.isNotEmpty)
                      'sources ${sources.join(', ')}',
                    if (cycleId != null) 'cycle ${cycleId.substring(0, 8)}',
                    if (timestamp != null)
                      DateFormat('MMM d, h:mm:ss a').format(timestamp),
                  ];
                  return ListTile(
                    dense: true,
                    title: Text(entry['event'] as String? ?? 'unknown'),
                    subtitle: Text(details.join(' • ')),
                  );
                }).toList(),
              );
            },
          ),
        ],
      );
}

class _AgenticTradingSettingsWidgetState
    extends State<AgenticTradingSettingsWidget> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _entryStrategiesKey = GlobalKey();
  final GlobalKey _riskManagementKey = GlobalKey();
  // Pending orders currently being approved or rejected, keyed by symbol and action.
  final Set<String> _busyOrders = {};
  late TextEditingController _tradeQuantityController;
  late TextEditingController _maxPositionSizeController;
  late TextEditingController _maxPortfolioConcentrationController;
  late TextEditingController _dailyTradeLimitController;
  late TextEditingController _autoTradeCooldownController;
  late TextEditingController _checkIntervalController;
  late TextEditingController _takeProfitPercentController;
  late TextEditingController _stopLossPercentController;
  late TextEditingController _maxSectorExposureController;
  late TextEditingController _maxCorrelationController;
  late TextEditingController _minVolatilityController;
  late TextEditingController _maxVolatilityController;
  late TextEditingController _maxDrawdownController;
  late TextEditingController _minSignalStrengthController;
  late TextEditingController _rsiExitThresholdController;
  late TextEditingController _signalStrengthExitThresholdController;
  late TextEditingController _gexExitThresholdController;
  late TextEditingController _timeBasedExitMinutesController;
  late TextEditingController _marketCloseExitMinutesController;
  late TextEditingController _riskPerTradeController;
  late TextEditingController _atrMultiplierController;
  late TextEditingController _rsiPeriodController;
  late TextEditingController _rocPeriodController;
  late TextEditingController _smaFastController;
  late TextEditingController _smaSlowController;
  late TextEditingController _marketIndexController;
  late TextEditingController _trailingStopPercentController;
  late TextEditingController _trailingPeakStopPercentController;
  late TextEditingController _atrStopMultiplierController;
  late TextEditingController _atrProfitMultiplierController;
  late TextEditingController _minDteStopDaysController;
  late TextEditingController _stalledSessionsStopLimitController;
  late TextEditingController _catastrophicStopPercentController;
  late TextEditingController _riskOffSizeReductionController;
  // late bool _enableDynamicPositionSizing;
  // late Map<String, bool> _enabledIndicators;
  // late List<ExitStage> _exitStages;
  // late List<CustomIndicatorConfig> _customIndicators;
  String? _selectedTemplateId;
  late List<String> _symbolFilter;
  String _interval = '1d';
  final TextEditingController _newSymbolController = TextEditingController();
  final CarouselController _templateScrollController = CarouselController();
  final ScrollController _intervalScrollController = ScrollController();
  bool _hasScrolledToTemplate = false;
  // final Map<String, bool> _switchValues = {};
  AgenticTradingProvider? _configProvider;
  late final FeatureAccessService _featureAccessService;

  bool get _isAgenticTradingEnabled => _featureAccessService.isFeatureEnabled(
        FeatureBundle.agenticTrading,
        userRole: widget.user.role,
        user: widget.user,
      );

  // Most edits call updateConfig directly; reopening this screen reloads from
  // widget.user, so it must track the provider or the edits revert.
  void _syncUserConfig() {
    widget.user.agenticTradingConfig = _configProvider?.config;
  }

  @override
  void initState() {
    super.initState();
    _featureAccessService =
        widget.featureAccessService ?? FeatureAccessService.instance;

    final provider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    _configProvider = provider..addListener(_syncUserConfig);
    unawaited(provider.refreshEmergencyStopState(widget.userDocRef));
    unawaited(provider.loadLatestMarketCloseExitStatus(widget.userDocRef));
    // Other screens pass a possibly stale User; a loaded provider config is newer.
    final providerHasConfig = provider.hasLoadedConfig;
    final initialConfig =
        providerHasConfig ? provider.config : widget.user.agenticTradingConfig;

    if (widget.initialSection == 'entryStrategies') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await provider.setUiMode(AgenticTradingUiMode.quantPro);
        // Add a small delay to ensure the widget is fully built and expanded
        await Future.delayed(const Duration(milliseconds: 300));
        if (_entryStrategiesKey.currentContext != null) {
          Scrollable.ensureVisible(
            _entryStrategiesKey.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.0,
          );
        }
      });
    } else if (widget.initialSection == 'riskManagement') {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await provider.setUiMode(AgenticTradingUiMode.quantPro);
        await Future.delayed(const Duration(milliseconds: 300));
        if (_riskManagementKey.currentContext != null) {
          Scrollable.ensureVisible(
            _riskManagementKey.currentContext!,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
            alignment: 0.0,
          );
        }
      });
    }

    // Initialize BacktestingProvider to load saved templates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final backtestingProvider =
          Provider.of<BacktestingProvider>(context, listen: false);
      backtestingProvider.initialize(widget.userDocRef);
    });

    // Load config after frame to ensure provider has latest user config
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final agenticTradingProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      if (!providerHasConfig && widget.user.agenticTradingConfig != null) {
        agenticTradingProvider
            .loadConfigFromUser(widget.user.agenticTradingConfig);
      }
    });

    // Initialize controllers from the newest known config
    final config = initialConfig;
    final strategy = config?.strategyConfig;

    _selectedTemplateId = config?.tradeStrategyTemplateId;

    _symbolFilter =
        strategy?.symbolFilter != null ? List.from(strategy!.symbolFilter) : [];
    _interval = strategy?.interval ?? '1d';

    _tradeQuantityController =
        TextEditingController(text: strategy?.tradeQuantity.toString() ?? '1');
    _maxPositionSizeController = TextEditingController(
        text: strategy?.maxPositionSize.toString() ?? '100');

    double maxPortfolioConcentration =
        strategy?.maxPortfolioConcentration ?? 0.5;
    double maxConcentrationPercent = maxPortfolioConcentration * 100;
    _maxPortfolioConcentrationController = TextEditingController(
        text: maxConcentrationPercent % 1 == 0
            ? maxConcentrationPercent.toInt().toString()
            : maxConcentrationPercent.toString());

    _dailyTradeLimitController = TextEditingController(
        text: strategy?.dailyTradeLimit.toString() ?? '5');
    _autoTradeCooldownController = TextEditingController(
        text: config?.autoTradeCooldownMinutes.toString() ?? '60');
    _checkIntervalController = TextEditingController(
        text: config?.checkIntervalMinutes.toString() ?? '5');
    _takeProfitPercentController = TextEditingController(
        text: strategy?.takeProfitPercent.toString() ?? '10.0');
    _stopLossPercentController = TextEditingController(
        text: strategy?.stopLossPercent.toString() ?? '5.0');
    _trailingStopPercentController = TextEditingController(
        text: strategy?.trailingStopPercent.toString() ?? '3.0');
    _trailingPeakStopPercentController = TextEditingController(
        text: strategy?.trailingPeakStopPercent.toString() ?? '15.0');
    _atrStopMultiplierController = TextEditingController(
        text: strategy?.atrStopMultiplier.toString() ?? '1.5');
    _atrProfitMultiplierController = TextEditingController(
        text: strategy?.atrProfitMultiplier.toString() ?? '3.0');
    _minDteStopDaysController =
        TextEditingController(text: strategy?.minDteStopDays.toString() ?? '7');
    _stalledSessionsStopLimitController = TextEditingController(
        text: strategy?.stalledSessionsStopLimit.toString() ?? '3');
    _catastrophicStopPercentController = TextEditingController(
        text: strategy?.catastrophicStopPercent.toString() ?? '30.0');

    double maxSectorExposure = strategy?.maxSectorExposure ?? 0.2;
    double sectorPercent = maxSectorExposure * 100;
    _maxSectorExposureController = TextEditingController(
        text: sectorPercent % 1 == 0
            ? sectorPercent.toInt().toString()
            : sectorPercent.toString());

    double maxCorrelation = strategy?.maxCorrelation ?? 0.7;
    double maxCorrelationPercent = maxCorrelation * 100;
    _maxCorrelationController = TextEditingController(
        text: maxCorrelationPercent % 1 == 0
            ? maxCorrelationPercent.toInt().toString()
            : maxCorrelationPercent.toString());

    double minVolatility = strategy?.minVolatility ?? 0.0;
    double minVolPercent = minVolatility * 100;
    _minVolatilityController = TextEditingController(
        text: minVolPercent % 1 == 0
            ? minVolPercent.toInt().toString()
            : minVolPercent.toString());

    double maxVolatility = strategy?.maxVolatility ?? 1.0;
    double maxVolPercent = maxVolatility * 100;
    _maxVolatilityController = TextEditingController(
        text: maxVolPercent % 1 == 0
            ? maxVolPercent.toInt().toString()
            : maxVolPercent.toString());

    double maxDrawdown = strategy?.maxDrawdown ?? 0.05;
    double drawdownPercent = maxDrawdown * 100;
    _maxDrawdownController = TextEditingController(
        text: drawdownPercent % 1 == 0
            ? drawdownPercent.toInt().toString()
            : drawdownPercent.toString());

    _minSignalStrengthController = TextEditingController(
        text: strategy?.minSignalStrength.toString() ?? '50.0');
    _rsiExitThresholdController = TextEditingController(
        text: strategy?.rsiExitThreshold.toString() ?? '80.0');
    _signalStrengthExitThresholdController = TextEditingController(
        text: strategy?.signalStrengthExitThreshold.toString() ?? '40.0');
    _gexExitThresholdController = TextEditingController(
        text: ((strategy?.gexExitThreshold ?? 0.0) / 1e6).toString());

    double riskOffSizeReduction = strategy?.riskOffSizeReduction ?? 0.5;
    double riskOffSizeReductionPercent = riskOffSizeReduction * 100;
    _riskOffSizeReductionController = TextEditingController(
        text: riskOffSizeReductionPercent % 1 == 0
            ? riskOffSizeReductionPercent.toInt().toString()
            : riskOffSizeReductionPercent.toString());
    _timeBasedExitMinutesController = TextEditingController(
        text: strategy?.timeBasedExitMinutes.toString() ?? '0');
    _marketCloseExitMinutesController = TextEditingController(
        text: strategy?.marketCloseExitMinutes.toString() ?? '15');

    double riskPerTrade = strategy?.riskPerTrade ?? 0.01;
    _riskPerTradeController =
        TextEditingController(text: (riskPerTrade * 100).toString());

    _atrMultiplierController = TextEditingController(
        text: strategy?.atrMultiplier.toString() ?? '2.0');
    _rsiPeriodController =
        TextEditingController(text: strategy?.rsiPeriod.toString() ?? '14');
    _rocPeriodController =
        TextEditingController(text: strategy?.rocPeriod.toString() ?? '9');
    _smaFastController =
        TextEditingController(text: strategy?.smaPeriodFast.toString() ?? '10');
    _smaSlowController =
        TextEditingController(text: strategy?.smaPeriodSlow.toString() ?? '30');
    _marketIndexController =
        TextEditingController(text: strategy?.marketIndexSymbol ?? 'SPY');
  }

  @override
  void dispose() {
    _configProvider?.removeListener(_syncUserConfig);
    _tradeQuantityController.dispose();
    _maxPositionSizeController.dispose();
    _maxPortfolioConcentrationController.dispose();
    _dailyTradeLimitController.dispose();
    _autoTradeCooldownController.dispose();
    _checkIntervalController.dispose();
    _takeProfitPercentController.dispose();
    _stopLossPercentController.dispose();
    _trailingStopPercentController.dispose();
    _trailingPeakStopPercentController.dispose();
    _atrStopMultiplierController.dispose();
    _atrProfitMultiplierController.dispose();
    _minDteStopDaysController.dispose();
    _stalledSessionsStopLimitController.dispose();
    _catastrophicStopPercentController.dispose();
    _maxSectorExposureController.dispose();
    _maxCorrelationController.dispose();
    _minVolatilityController.dispose();
    _timeBasedExitMinutesController.dispose();
    _marketCloseExitMinutesController.dispose();
    _maxVolatilityController.dispose();
    _maxDrawdownController.dispose();
    _minSignalStrengthController.dispose();
    _rsiExitThresholdController.dispose();
    _signalStrengthExitThresholdController.dispose();
    _gexExitThresholdController.dispose();
    _riskPerTradeController.dispose();
    _rocPeriodController.dispose();
    _atrMultiplierController.dispose();
    _rsiPeriodController.dispose();
    _smaFastController.dispose();
    _smaSlowController.dispose();
    _marketIndexController.dispose();
    _newSymbolController.dispose();
    _templateScrollController.dispose();
    _intervalScrollController.dispose();
    super.dispose();
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String helperText,
    required IconData icon,
    bool isDecimal = false,
    double? min,
    double? max,
    String? suffixText,
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
        prefixIcon: Icon(icon,
            size: 18, color: colorScheme.primary.withValues(alpha: 0.8)),
        suffixText: suffixText,
        suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
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
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      onChanged: (_) => _saveSettings(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Required';
        }
        final parsed = double.tryParse(value);
        if (parsed == null) {
          return 'Invalid number';
        }
        if (min != null && parsed < min) {
          return 'Min: ${isDecimal ? min : min.toInt()}';
        }
        if (max != null && parsed > max) {
          return 'Max: ${isDecimal ? max : max.toInt()}';
        }
        return null;
      },
    );
  }

  Widget _buildSwitchListTile(
    String key,
    String title,
    String description,
    AgenticTradingProvider provider, {
    bool defaultValue = true,
    Widget? extraContent,
    double? titleFontSize,
    double? subtitleFontSize = 13,
    EdgeInsetsGeometry? contentPadding,
    required ValueChanged<bool>? onChanged,
    required bool value,
    Color? activeColor,
    Color? activeTrackColor,
    Widget? titleWidget,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEnabled = value;
    final effectiveActiveColor = activeColor ?? colorScheme.primary;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isEnabled
              ? effectiveActiveColor.withValues(alpha: 0.3)
              : colorScheme.outline.withValues(alpha: 0.1),
          width: isEnabled ? 1.5 : 1,
        ),
      ),
      color: isEnabled
          ? effectiveActiveColor.withValues(alpha: 0.05)
          : colorScheme.surface,
      child: Column(
        children: [
          SwitchListTile(
            key: ValueKey(key),
            title: titleWidget ??
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: titleFontSize ?? 15,
                    color: colorScheme.onSurface,
                  ),
                ),
            subtitle: description.isNotEmpty
                ? Text(
                    description,
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      color:
                          colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  )
                : null,
            value: isEnabled,
            onChanged: onChanged,
            activeThumbColor: effectiveActiveColor,
            activeTrackColor:
                activeTrackColor ?? effectiveActiveColor.withValues(alpha: 0.5),
            contentPadding: contentPadding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          if (isEnabled && extraContent != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Divider(
                      height: 24,
                      color: colorScheme.outline.withValues(alpha: 0.1)),
                  SizedBox(
                    width: double.infinity,
                    child: extraContent,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(time);
    }
  }

  Color _getMacroColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'BULLISH':
        return Colors.green;
      case 'BEARISH':
        return Colors.red;
      case 'NEUTRAL':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getMacroIcon(String? status) {
    switch (status?.toUpperCase()) {
      case 'BULLISH':
        return Icons.trending_up;
      case 'BEARISH':
        return Icons.trending_down;
      default:
        return Icons.trending_flat;
    }
  }

  Widget _buildGexMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBadge(BuildContext context, String label, bool passed) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: passed
            ? Colors.green.withValues(alpha: 0.1)
            : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: passed
              ? Colors.green.withValues(alpha: 0.5)
              : colorScheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: passed ? Colors.green : colorScheme.error,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 60) return Colors.blue;
    if (confidence >= 40) return Colors.orange;
    return Colors.red;
  }

  AgenticTradingConfig _createFullConfigFromSettings(
      AgenticTradingProvider provider,
      {AgenticTradingConfig? baseConfig}) {
    final configSource = baseConfig ?? provider.config;
    final strategySource = configSource.strategyConfig;

    final strategyConfig = TradeStrategyConfig(
      startDate: DateTime.now().subtract(const Duration(days: 30)),
      endDate: DateTime.now(),
      initialCapital: strategySource.initialCapital ?? 10000.0,
      interval: strategySource.interval,
      enabledIndicators:
          Map<String, bool>.from(strategySource.enabledIndicators),
      tradeQuantity: int.tryParse(_tradeQuantityController.text) ?? 1,
      takeProfitPercent:
          double.tryParse(_takeProfitPercentController.text) ?? 10.0,
      stopLossPercent: double.tryParse(_stopLossPercentController.text) ?? 5.0,
      trailingStopEnabled: strategySource.trailingStopEnabled,
      trailingStopPercent:
          double.tryParse(_trailingStopPercentController.text) ?? 3.0,
      rsiPeriod: int.tryParse(_rsiPeriodController.text) ?? 14,
      rocPeriod: int.tryParse(_rocPeriodController.text) ?? 9,
      smaPeriodFast: int.tryParse(_smaFastController.text) ?? 10,
      smaPeriodSlow: int.tryParse(_smaSlowController.text) ?? 30,
      marketIndexSymbol: _marketIndexController.text,
      maxPositionSize: int.tryParse(_maxPositionSizeController.text) ?? 100,
      maxPortfolioConcentration:
          (double.tryParse(_maxPortfolioConcentrationController.text) ?? 50.0) /
              100.0,
      dailyTradeLimit: int.tryParse(_dailyTradeLimitController.text) ?? 5,
      minSignalStrength: (strategySource.requireAllIndicatorsGreen)
          ? 100.0
          : (double.tryParse(_minSignalStrengthController.text) ?? 50.0),
      requireAllIndicatorsGreen: strategySource.requireAllIndicatorsGreen,
      timeBasedExitEnabled: strategySource.timeBasedExitEnabled,
      timeBasedExitMinutes:
          int.tryParse(_timeBasedExitMinutesController.text) ?? 30,
      marketCloseExitEnabled: strategySource.marketCloseExitEnabled,
      marketCloseExitMinutes:
          int.tryParse(_marketCloseExitMinutesController.text) ?? 15,
      enablePartialExits: strategySource.enablePartialExits,
      exitStages: List.from(strategySource.exitStages),
      enableDynamicPositionSizing: strategySource.enableDynamicPositionSizing,
      riskPerTrade:
          (double.tryParse(_riskPerTradeController.text) ?? 1.0) / 100.0,
      atrMultiplier: double.tryParse(_atrMultiplierController.text) ?? 2.0,
      customIndicators: List.from(strategySource.customIndicators),
      symbolFilter: List.from(strategySource.symbolFilter),
      enableSectorLimits: strategySource.enableSectorLimits,
      maxSectorExposure:
          (double.tryParse(_maxSectorExposureController.text) ?? 20.0) / 100.0,
      enableCorrelationChecks: strategySource.enableCorrelationChecks,
      maxCorrelation:
          (double.tryParse(_maxCorrelationController.text) ?? 70.0) / 100.0,
      enableVolatilityFilters: strategySource.enableVolatilityFilters,
      minVolatility:
          (double.tryParse(_minVolatilityController.text) ?? 0.0) / 100.0,
      maxVolatility:
          (double.tryParse(_maxVolatilityController.text) ?? 100.0) / 100.0,
      enableDrawdownProtection: strategySource.enableDrawdownProtection,
      maxDrawdown:
          (double.tryParse(_maxDrawdownController.text) ?? 10.0) / 100.0,
      reduceSizeOnRiskOff: strategySource.reduceSizeOnRiskOff,
      riskOffSizeReduction:
          (double.tryParse(_riskOffSizeReductionController.text) ?? 50.0) /
              100.0,
      rsiExitEnabled: strategySource.rsiExitEnabled,
      rsiExitThreshold:
          double.tryParse(_rsiExitThresholdController.text) ?? 80.0,
      signalStrengthExitEnabled: strategySource.signalStrengthExitEnabled,
      signalStrengthExitThreshold:
          double.tryParse(_signalStrengthExitThresholdController.text) ?? 40.0,
      gexExitEnabled: strategySource.gexExitEnabled,
      gexExitThreshold:
          (double.tryParse(_gexExitThresholdController.text) ?? 0.0) * 1e6,
      enableGexStructuralStops: strategySource.enableGexStructuralStops,
      enableTrailingPeakStop: strategySource.enableTrailingPeakStop,
      trailingPeakStopPercent:
          double.tryParse(_trailingPeakStopPercentController.text) ?? 15.0,
      enableTimeThetaStop: strategySource.enableTimeThetaStop,
      minDteStopDays: int.tryParse(_minDteStopDaysController.text) ?? 7,
      stalledSessionsStopLimit:
          int.tryParse(_stalledSessionsStopLimitController.text) ?? 3,
      enableMacroRegimeStop: strategySource.enableMacroRegimeStop,
      enableCatastrophicStop: strategySource.enableCatastrophicStop,
      catastrophicStopPercent:
          double.tryParse(_catastrophicStopPercentController.text) ?? 30.0,
      dynamicAtrStopsEnabled: strategySource.dynamicAtrStopsEnabled,
      atrStopMultiplier:
          double.tryParse(_atrStopMultiplierController.text) ?? 1.5,
      atrProfitMultiplier:
          double.tryParse(_atrProfitMultiplierController.text) ?? 3.0,
      atrRatchetEnabled: strategySource.atrRatchetEnabled,
    );

    return AgenticTradingConfig(
      strategyConfig: strategyConfig,
      autoTradeEnabled: configSource.autoTradeEnabled,
      tradingMode: configSource.tradingMode,
      autoTradeCooldownMinutes:
          int.tryParse(_autoTradeCooldownController.text) ?? 60,
      checkIntervalMinutes: int.tryParse(_checkIntervalController.text) ?? 5,
      allowPreMarketTrading: configSource.allowPreMarketTrading,
      allowAfterHoursTrading: configSource.allowAfterHoursTrading,
      notifyOnBuy: configSource.notifyOnBuy,
      notifyOnTakeProfit: configSource.notifyOnTakeProfit,
      notifyOnStopLoss: configSource.notifyOnStopLoss,
      notifyOnEmergencyStop: configSource.notifyOnEmergencyStop,
      notifyOnMissedExit: configSource.notifyOnMissedExit,
      notifyDailySummary: configSource.notifyDailySummary,
      paperTradingMode: configSource.paperTradingMode,
      paperQuoteSource: configSource.paperQuoteSource,
      requireApproval: configSource.requireApproval,
      tradeStrategyTemplateId: _selectedTemplateId,
    );
  }

  void _saveSettings() async {
    // Only validate, don't show snackbar for auto-saves
    if (!(_formKey.currentState?.validate() ?? true)) {
      debugPrint('Auto-trade settings not saved: a field failed validation');
      return;
    }

    try {
      final agenticTradingProvider =
          Provider.of<AgenticTradingProvider>(context, listen: false);

      // Force paper trading mode if no brokerage service is linked
      if (widget.service == null) {
        // _switchValues['paperTradingMode'] = true; // Use provider directly
      }

      final newConfig = _createFullConfigFromSettings(agenticTradingProvider);

      await agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);

      // Update local user object to ensure persistence when navigating back/forth
      // if the parent widget holds the User object
      if (widget.user.agenticTradingConfig != null) {
        // Can't easily update fields in place, so recreate.
        // Note: Using setState isn't strictly required for *this* widget since we already have the state,
        // but it's good for consistency if we used widget.user in build.
        widget.user.agenticTradingConfig = newConfig;
      } else {
        widget.user.agenticTradingConfig = newConfig;
      }
    } catch (e) {
      debugPrint('Error auto-saving settings: $e');
    }
  }

  String _orderKey(Map<String, dynamic> order) =>
      '${order['symbol']}_${order['action']}';

  Future<void> _rejectOrder(
      AgenticTradingProvider provider, Map<String, dynamic> order) async {
    final key = _orderKey(order);
    if (!_busyOrders.add(key)) return;
    setState(() {});
    try {
      await provider.rejectOrder(order, userDocRef: widget.userDocRef);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text('Rejected ${order['action']} ${order['symbol']}'),
          behavior: SnackBarBehavior.floating,
        ));
    } finally {
      _busyOrders.remove(key);
      if (mounted) setState(() {});
    }
  }

  Future<void> _approveOrder(BuildContext context,
      AgenticTradingProvider provider, Map<String, dynamic> order) async {
    final key = _orderKey(order);
    if (!_busyOrders.add(key)) return;
    setState(() {});
    try {
      await _placeApprovedOrder(context, provider, order);
    } finally {
      _busyOrders.remove(key);
      if (mounted) setState(() {});
    }
  }

  Future<void> _placeApprovedOrder(BuildContext context,
      AgenticTradingProvider provider, Map<String, dynamic> order) async {
    final brokerageUserStore =
        Provider.of<BrokerageUserStore>(context, listen: false);
    final accountStore = Provider.of<AccountStore>(context, listen: false);
    final paperTradingStore =
        Provider.of<PaperTradingStore>(context, listen: false);
    final isPaperMode = provider.config.paperTradingMode;

    if (!isPaperMode && brokerageUserStore.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to brokerage first')),
      );
      return;
    }
    final brokerageUser = brokerageUserStore.items.isNotEmpty
        ? brokerageUserStore.items[brokerageUserStore.currentUserIndex]
        : null;

    var account =
        accountStore.items.isNotEmpty ? accountStore.items.first : null;
    if (!isPaperMode && account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No brokerage account found')),
      );
      return;
    }

    final symbol = (order['symbol'] as String).toUpperCase();
    final heldQuantity = isPaperMode
        ? paperTradingStore.positions
            .where((p) => p.instrumentObj?.symbol.toUpperCase() == symbol)
            .fold<double>(0, (total, p) => total + (p.quantity ?? 0))
        : Provider.of<InstrumentPositionStore>(context, listen: false)
            .items
            .where((p) => p.instrumentObj?.symbol.toUpperCase() == symbol)
            .fold<double>(0, (total, p) => total + (p.quantity ?? 0));

    final messenger = ScaffoldMessenger.of(context);
    final approved = await provider.approveOrder(
      order,
      brokerageUser: brokerageUser,
      account: account,
      brokerageService: widget.service,
      userDocRef: widget.userDocRef,
      paperTradingStore: paperTradingStore,
      heldQuantity: heldQuantity,
      quoteStore: Provider.of<QuoteStore>(context, listen: false),
    );
    if (!mounted) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(approved
            ? 'Approved ${order['action']} ${order['symbol']}'
            : "Couldn't approve ${order['symbol']}. See the Activity Log."),
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _addCustomIndicator() async {
    final result = await Navigator.push<CustomIndicatorConfig>(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomIndicatorPage(),
      ),
    );

    if (result != null) {
      final provider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      final newIndicators = List<CustomIndicatorConfig>.from(
          provider.config.strategyConfig.customIndicators)
        ..add(result);

      final newConfig = _createFullConfigFromSettings(provider,
          baseConfig: provider.config.copyWith(
              strategyConfig: provider.config.strategyConfig
                  .copyWith(customIndicators: newIndicators)));
      provider.updateConfig(newConfig, widget.userDocRef);
    }
  }

  void _editCustomIndicator(CustomIndicatorConfig indicator) async {
    final result = await Navigator.push<CustomIndicatorConfig>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomIndicatorPage(indicator: indicator),
      ),
    );

    if (result != null) {
      final provider =
          Provider.of<AgenticTradingProvider>(context, listen: false);
      final newIndicators = List<CustomIndicatorConfig>.from(
          provider.config.strategyConfig.customIndicators);
      final index = newIndicators.indexWhere((i) => i.id == indicator.id);
      if (index != -1) {
        newIndicators[index] = result;
        final newConfig = _createFullConfigFromSettings(provider,
            baseConfig: provider.config.copyWith(
                strategyConfig: provider.config.strategyConfig
                    .copyWith(customIndicators: newIndicators)));
        provider.updateConfig(newConfig, widget.userDocRef);
      }
    }
  }

  void _removeCustomIndicator(CustomIndicatorConfig indicator) {
    final provider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    final newIndicators = List<CustomIndicatorConfig>.from(
        provider.config.strategyConfig.customIndicators)
      ..removeWhere((i) => i.id == indicator.id);

    final newConfig = _createFullConfigFromSettings(provider,
        baseConfig: provider.config.copyWith(
            strategyConfig: provider.config.strategyConfig
                .copyWith(customIndicators: newIndicators)));
    provider.updateConfig(newConfig, widget.userDocRef);
  }

  void _loadFromTemplate(TradeStrategyTemplate template) {
    setState(() {
      _selectedTemplateId = template.id;
      _hasScrolledToTemplate = false;
      _interval = template.config.interval;

      _takeProfitPercentController.text =
          template.config.takeProfitPercent.toString();
      _stopLossPercentController.text =
          template.config.stopLossPercent.toString();
      _trailingStopPercentController.text =
          template.config.trailingStopPercent.toString();

      _tradeQuantityController.text = template.config.tradeQuantity.toString();
      _maxPositionSizeController.text =
          template.config.maxPositionSize.toString();

      double maxPortfolioConcentration =
          template.config.maxPortfolioConcentration * 100;
      _maxPortfolioConcentrationController.text =
          maxPortfolioConcentration % 1 == 0
              ? maxPortfolioConcentration.toInt().toString()
              : maxPortfolioConcentration.toString();

      _dailyTradeLimitController.text =
          template.config.dailyTradeLimit.toString();

      _rsiPeriodController.text = template.config.rsiPeriod.toString();
      _smaFastController.text = template.config.smaPeriodFast.toString();
      _smaSlowController.text = template.config.smaPeriodSlow.toString();
      _marketIndexController.text = template.config.marketIndexSymbol;

      double maxSector = template.config.maxSectorExposure * 100;
      _maxSectorExposureController.text = maxSector % 1 == 0
          ? maxSector.toInt().toString()
          : maxSector.toString();

      double maxCorr = template.config.maxCorrelation * 100;
      _maxCorrelationController.text =
          maxCorr % 1 == 0 ? maxCorr.toInt().toString() : maxCorr.toString();

      double minVol = template.config.minVolatility * 100;
      _minVolatilityController.text =
          minVol % 1 == 0 ? minVol.toInt().toString() : minVol.toString();

      double maxVol = template.config.maxVolatility * 100;
      _maxVolatilityController.text =
          maxVol % 1 == 0 ? maxVol.toInt().toString() : maxVol.toString();

      double maxDrawdown = template.config.maxDrawdown * 100;
      _maxDrawdownController.text = maxDrawdown % 1 == 0
          ? maxDrawdown.toInt().toString()
          : maxDrawdown.toString();

      _rsiExitThresholdController.text =
          template.config.rsiExitThreshold.toString();
      _signalStrengthExitThresholdController.text =
          template.config.signalStrengthExitThreshold.toString();

      _minSignalStrengthController.text =
          template.config.requireAllIndicatorsGreen
              ? '100'
              : template.config.minSignalStrength.toString();

      _timeBasedExitMinutesController.text =
          template.config.timeBasedExitMinutes.toString();
      _marketCloseExitMinutesController.text =
          template.config.marketCloseExitMinutes.toString();

      _riskPerTradeController.text =
          (template.config.riskPerTrade * 100).toString();
      _atrMultiplierController.text = template.config.atrMultiplier.toString();
      _rocPeriodController.text = template.config.rocPeriod.toString();
      _trailingPeakStopPercentController.text =
          template.config.trailingPeakStopPercent.toString();
      _atrStopMultiplierController.text =
          template.config.atrStopMultiplier.toString();
      _atrProfitMultiplierController.text =
          template.config.atrProfitMultiplier.toString();
      _minDteStopDaysController.text =
          template.config.minDteStopDays.toString();
      _stalledSessionsStopLimitController.text =
          template.config.stalledSessionsStopLimit.toString();
      _catastrophicStopPercentController.text =
          template.config.catastrophicStopPercent.toString();
      final riskOffPct = template.config.riskOffSizeReduction * 100;
      _riskOffSizeReductionController.text = riskOffPct % 1 == 0
          ? riskOffPct.toInt().toString()
          : riskOffPct.toString();
      _gexExitThresholdController.text =
          (template.config.gexExitThreshold / 1e6).toString();

      _symbolFilter = List.from(template.config.symbolFilter);
    });

    final provider =
        Provider.of<AgenticTradingProvider>(context, listen: false);

    final baseStrategy = provider.config.strategyConfig.copyWith(
      initialCapital: template.config.initialCapital,
      enabledIndicators: template.config.enabledIndicators,
      customIndicators: template.config.customIndicators,
      exitStages: template.config.exitStages,
      trailingStopEnabled: template.config.trailingStopEnabled,
      requireAllIndicatorsGreen: template.config.requireAllIndicatorsGreen,
      timeBasedExitEnabled: template.config.timeBasedExitEnabled,
      marketCloseExitEnabled: template.config.marketCloseExitEnabled,
      enablePartialExits: template.config.enablePartialExits,
      enableDynamicPositionSizing: template.config.enableDynamicPositionSizing,
      enableSectorLimits: template.config.enableSectorLimits,
      enableCorrelationChecks: template.config.enableCorrelationChecks,
      enableVolatilityFilters: template.config.enableVolatilityFilters,
      enableDrawdownProtection: template.config.enableDrawdownProtection,
      rsiExitEnabled: template.config.rsiExitEnabled,
      signalStrengthExitEnabled: template.config.signalStrengthExitEnabled,
      interval: template.config.interval,
      symbolFilter: _symbolFilter,
    );

    final newConfig = _createFullConfigFromSettings(provider,
        baseConfig: provider.config.copyWith(
            strategyConfig: baseStrategy, selectedTemplateId: template.id));

    provider.updateConfig(newConfig, widget.userDocRef);
  }

  void _showSaveTemplateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final provider = Provider.of<BacktestingProvider>(context, listen: false);
    final agenticProvider =
        Provider.of<AgenticTradingProvider>(context, listen: false);

    bool isEditing = false;
    bool isDefault = false;
    TradeStrategyTemplate? existingTemplate;

    if (_selectedTemplateId != null) {
      try {
        existingTemplate =
            provider.templates.firstWhere((t) => t.id == _selectedTemplateId);
        nameController.text = existingTemplate.name;
        descriptionController.text = existingTemplate.description;
        isEditing = true;
        isDefault = existingTemplate.id.startsWith('default_');
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) {
          final colorScheme = Theme.of(context).colorScheme;
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isEditing && !isDefault ? Icons.edit : Icons.save,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(isEditing && !isDefault
                    ? 'Edit Strategy'
                    : 'Save Strategy'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDefault)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color:
                          colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 20, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Default templates cannot be modified directly. A copy will be created.',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Strategy Name',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) => dialogSetState(() {}),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              if (isEditing && !isDefault)
                TextButton(
                  onPressed: nameController.text.isEmpty
                      ? null
                      : () {
                          final currentConfig =
                              _createConfigFromCurrentSettings(agenticProvider);
                          final createdAt =
                              existingTemplate?.createdAt ?? DateTime.now();

                          final template = TradeStrategyTemplate(
                            id: _selectedTemplateId!,
                            name: nameController.text,
                            description: descriptionController.text,
                            config: currentConfig,
                            createdAt: createdAt,
                          );

                          provider.saveTemplate(template);
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Updated strategy "${template.name}"')),
                          );
                        },
                  child: const Text('Update'),
                ),
              FilledButton(
                onPressed: nameController.text.isEmpty
                    ? null
                    : () {
                        // Check for duplicate names if saving as new
                        final nameExists = provider.templates.any((t) =>
                            t.name.toLowerCase() ==
                                nameController.text.trim().toLowerCase() &&
                            t.id != _selectedTemplateId);

                        if (nameExists) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'A strategy with this name already exists. Please choose a different name.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        final currentConfig =
                            _createConfigFromCurrentSettings(agenticProvider);
                        final template = TradeStrategyTemplate(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          name: nameController.text,
                          description: descriptionController.text,
                          config: currentConfig,
                          createdAt: DateTime.now(),
                        );

                        provider.saveTemplate(template);
                        setState(() {
                          _selectedTemplateId = template.id;
                        });
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(
                                  'Saved new strategy "${template.name}"')),
                        );
                      },
                child: Text(isEditing && !isDefault ? 'Save as New' : 'Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  TradeStrategyConfig _createConfigFromCurrentSettings(
      AgenticTradingProvider provider) {
    // We use provider config + controllers
    final strategySource = provider.config.strategyConfig;
    return TradeStrategyConfig(
      startDate: strategySource.startDate ??
          DateTime.now().subtract(const Duration(days: 30)),
      endDate: strategySource.endDate ?? DateTime.now(),
      initialCapital: strategySource.initialCapital ?? 10000.0,
      interval: strategySource.interval, // ??_interval,
      enabledIndicators:
          Map<String, bool>.from(strategySource.enabledIndicators),
      takeProfitPercent:
          double.tryParse(_takeProfitPercentController.text) ?? 10.0,
      stopLossPercent: double.tryParse(_stopLossPercentController.text) ?? 5.0,
      trailingStopEnabled: strategySource.trailingStopEnabled,
      trailingStopPercent:
          double.tryParse(_trailingStopPercentController.text) ?? 3.0,
      rsiPeriod: int.tryParse(_rsiPeriodController.text) ?? 14,
      rocPeriod: int.tryParse(_rocPeriodController.text) ?? 9,
      smaPeriodFast: int.tryParse(_smaFastController.text) ?? 10,
      smaPeriodSlow: int.tryParse(_smaSlowController.text) ?? 30,
      marketIndexSymbol: _marketIndexController.text,
      maxPositionSize: int.tryParse(_maxPositionSizeController.text) ?? 100,
      maxPortfolioConcentration:
          (double.tryParse(_maxPortfolioConcentrationController.text) ?? 50.0) /
              100.0,
      dailyTradeLimit: int.tryParse(_dailyTradeLimitController.text) ?? 5,
      minSignalStrength:
          double.tryParse(_minSignalStrengthController.text) ?? 50.0,
      requireAllIndicatorsGreen: strategySource.requireAllIndicatorsGreen,
      timeBasedExitEnabled: strategySource.timeBasedExitEnabled,
      timeBasedExitMinutes:
          int.tryParse(_timeBasedExitMinutesController.text) ?? 0,
      marketCloseExitEnabled: strategySource.marketCloseExitEnabled,
      marketCloseExitMinutes:
          int.tryParse(_marketCloseExitMinutesController.text) ?? 15,
      enablePartialExits: strategySource.enablePartialExits,
      exitStages: List.from(strategySource.exitStages),
      enableDynamicPositionSizing: strategySource.enableDynamicPositionSizing,
      riskPerTrade: (double.tryParse(_riskPerTradeController.text) ?? 1.0) /
          100.0, // Convert % to decimal
      atrMultiplier: double.tryParse(_atrMultiplierController.text) ?? 2.0,
      customIndicators: List.from(strategySource.customIndicators),
      symbolFilter: List.from(_symbolFilter),
      tradeQuantity: int.tryParse(_tradeQuantityController.text) ?? 1,
      // Risk Controls
      enableSectorLimits: strategySource.enableSectorLimits,
      maxSectorExposure:
          (double.tryParse(_maxSectorExposureController.text) ?? 20.0) / 100.0,
      enableCorrelationChecks: strategySource.enableCorrelationChecks,
      maxCorrelation:
          (double.tryParse(_maxCorrelationController.text) ?? 70.0) / 100.0,
      enableVolatilityFilters: strategySource.enableVolatilityFilters,
      minVolatility:
          (double.tryParse(_minVolatilityController.text) ?? 0.0) / 100.0,
      maxVolatility:
          (double.tryParse(_maxVolatilityController.text) ?? 100.0) / 100.0,
      enableDrawdownProtection: strategySource.enableDrawdownProtection,
      maxDrawdown:
          (double.tryParse(_maxDrawdownController.text) ?? 10.0) / 100.0,
      // Technical Exits
      rsiExitEnabled: strategySource.rsiExitEnabled,
      rsiExitThreshold:
          double.tryParse(_rsiExitThresholdController.text) ?? 80.0,
      signalStrengthExitEnabled: strategySource.signalStrengthExitEnabled,
      signalStrengthExitThreshold:
          double.tryParse(_signalStrengthExitThresholdController.text) ?? 40.0,
      gexExitEnabled: strategySource.gexExitEnabled,
      gexExitThreshold:
          (double.tryParse(_gexExitThresholdController.text) ?? 0.0) * 1e6,
    );
  }

  String? _formattedCapitalBudgetCap(
    BuildContext context,
    AgenticTradingProvider provider,
  ) {
    AccountStore? accountStore;
    try {
      accountStore = Provider.of<AccountStore>(context);
    } on ProviderNotFoundException {
      return null;
    }
    if (!accountStore.showBalances) {
      return r'$••••••';
    }
    double? equity;
    if (provider.config.paperTradingMode) {
      try {
        final paperStore = Provider.of<PaperTradingStore>(context);
        if (paperStore.equity > 0) {
          equity = paperStore.equity;
        }
      } on ProviderNotFoundException {
        // PaperTradingStore optional in widget tests
      }
    }
    equity ??= accountStore.selectedAccount?.totalValue ??
        accountStore.selectedAccount?.buyingPower ??
        accountStore.selectedAccount?.portfolioCash;
    if (equity == null || equity <= 0) return null;
    final cap = equity *
        provider.config.strategyConfig.maxPortfolioConcentration
            .clamp(0.0, 1.0);
    return NumberFormat.simpleCurrency(decimalDigits: 0).format(cap);
  }

  Future<void> _handleCapitalAllocationChanged(
    AgenticTradingProvider provider,
    double concentrationFraction,
  ) async {
    final pct = (concentrationFraction.clamp(0.05, 1.0) * 100);
    setState(() {
      _maxPortfolioConcentrationController.text =
          pct % 1 == 0 ? pct.toInt().toString() : pct.toStringAsFixed(1);
    });
    await provider.applyCapitalAllocation(
        concentrationFraction, widget.userDocRef);
  }

  Future<void> _handleRiskComfortChanged(
    AgenticTradingProvider provider,
    RiskComfortLevel level,
  ) async {
    setState(() {
      _stopLossPercentController.text = level.stopLossPercent.toString();
      _takeProfitPercentController.text = level.takeProfitPercent.toString();
      _tradeQuantityController.text = level.tradeQuantity.toString();
      _riskPerTradeController.text = (level.riskPerTrade * 100).toString();
    });
    await provider.applyRiskComfortLevel(level, widget.userDocRef);
  }

  void _openBetaLabs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BetaLabsWidget(
          user: widget.user,
          userDocRef: widget.userDocRef,
          userRole: widget.user.role,
          featureAccessService: _featureAccessService,
          service: widget.service,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _buildUiModeSelector(
    BuildContext context,
    AgenticTradingProvider agenticTradingProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<AgenticTradingUiMode>(
          key: const ValueKey('agentic-ui-mode-selector'),
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
          ),
          segments: const [
            ButtonSegment<AgenticTradingUiMode>(
              value: AgenticTradingUiMode.simplified,
              icon: Icon(Icons.tune, size: 16),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Simplified'),
              ),
            ),
            ButtonSegment<AgenticTradingUiMode>(
              value: AgenticTradingUiMode.quantPro,
              icon: Icon(Icons.science_outlined, size: 16),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Quant Pro'),
              ),
            ),
          ],
          selected: {agenticTradingProvider.uiMode},
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            unawaited(agenticTradingProvider.setUiMode(selection.first));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Automated Trading'),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Consumer2<AgenticTradingProvider, BrokerageUserStore>(
          builder:
              (context, agenticTradingProvider, brokerageUserStore, child) {
            final selectedBrokerage = brokerageUserStore.currentUser;
            final hasBrokerage = selectedBrokerage != null;
            final hasSupportedBrokerage =
                AgenticTradingProvider.supportsAutoTradingBrokerage(
                    selectedBrokerage?.source);
            final hasPaperQuoteSource =
                AgenticTradingProvider.resolvePaperQuoteUser(
                      userStore: brokerageUserStore,
                      source: agenticTradingProvider.config.paperQuoteSource,
                    ) !=
                    null;
            final isSimplified = agenticTradingProvider.uiMode ==
                AgenticTradingUiMode.simplified;
            final statusHeader =
                _buildStatusHeader(context, agenticTradingProvider);
            final monitoringCard =
                _buildMonitoringCard(context, agenticTradingProvider);
            final entryReadiness =
                _buildEntryReadiness(context, agenticTradingProvider);

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildUiModeSelector(context, agenticTradingProvider),
                    if (!hasSupportedBrokerage)
                      _buildBrokeragePrerequisite(
                        context,
                        hasBrokerage: hasBrokerage,
                        hasPaperQuoteSource: hasPaperQuoteSource,
                      ),
                    if (isSimplified) ...[
                      SimplifiedTradingControlsWidget(
                        config: agenticTradingProvider.config,
                        selectedTemplateId: _selectedTemplateId,
                        emergencyStopActivated:
                            agenticTradingProvider.emergencyStopActivated,
                        isAgenticTradingEnabled: _isAgenticTradingEnabled,
                        formattedDollarCap: _formattedCapitalBudgetCap(
                          context,
                          agenticTradingProvider,
                        ),
                        masterControlCard: statusHeader,
                        onApplyArchetype: _applyArchetype,
                        onInspectArchetype: (archetype) {
                          final isSelected = _selectedTemplateId ==
                                  'default_${archetype.id}' ||
                              _selectedTemplateId == archetype.id;
                          final isLocked =
                              archetype.tradingMode == TradingMode.reasoning &&
                                  !_isAgenticTradingEnabled;
                          StrategyArchetypeDetailBottomSheet.show(
                            context: context,
                            archetype: archetype,
                            isCurrentlyActive: isSelected,
                            isLocked: isLocked,
                            onUnlock: _openBetaLabs,
                            onApply: _applyArchetype,
                            onClone: _cloneArchetypeToTemplate,
                          );
                        },
                        onCapitalAllocationChanged: (fraction) =>
                            _handleCapitalAllocationChanged(
                          agenticTradingProvider,
                          fraction,
                        ),
                        onRiskComfortChanged: (level) =>
                            _handleRiskComfortChanged(
                          agenticTradingProvider,
                          level,
                        ),
                        onActivateEmergencyStop: () async {
                          await agenticTradingProvider.activateEmergencyStop(
                            userDocRef: widget.userDocRef,
                          );
                        },
                        onSwitchToQuantPro: () {
                          unawaited(agenticTradingProvider
                              .setUiMode(AgenticTradingUiMode.quantPro));
                        },
                      ),
                      const SizedBox(height: 16),
                      monitoringCard,
                      entryReadiness,
                    ] else ...[
                      statusHeader,
                      monitoringCard,
                      entryReadiness,
                      const SizedBox(height: 16),
                      // _buildSignalQueue(context, agenticTradingProvider),
                      QuantProSettingsView(
                        templateListSection: _buildTemplateList(context),
                        executionSettingsSection: _buildExecutionSettings(
                            context, agenticTradingProvider),
                        riskManagementSection: _buildRiskManagement(
                            context, agenticTradingProvider,
                            key: _riskManagementKey),
                        entryStrategiesSection: _buildEntryStrategies(
                            context, agenticTradingProvider,
                            initiallyExpanded:
                                widget.initialSection == 'entryStrategies',
                            key: _entryStrategiesKey),
                        exitStrategiesSection: _buildExitStrategies(
                            context, agenticTradingProvider),
                        notificationSettingsSection: _buildNotificationSettings(
                            context, agenticTradingProvider),
                        backtestingSection:
                            _buildBacktesting(context, agenticTradingProvider),
                        onSwitchToSimplified: () {
                          unawaited(agenticTradingProvider
                              .setUiMode(AgenticTradingUiMode.simplified));
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrokeragePrerequisite(
    BuildContext context, {
    required bool hasBrokerage,
    required bool hasPaperQuoteSource,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.link, size: 18, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasPaperQuoteSource
                  ? 'Paper quotes use the configured source, independently of the account you are viewing. Live orders use the active account and require Robinhood or Schwab.'
                  : hasBrokerage
                      ? 'No supported Paper quote source is available in this device account list. Reconnect Robinhood or Schwab, or choose Automatic in Execution Settings.'
                      : 'Connect a Robinhood or Schwab account on this device to provide Paper quotes or enable automated Live execution. You can configure your strategy now.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryReadiness(
    BuildContext context,
    AgenticTradingProvider provider,
  ) {
    final config = provider.config;
    final strategy = config.strategyConfig;
    final activeIndicatorCount =
        strategy.enabledIndicators.values.where((enabled) => enabled).length +
            strategy.customIndicators.length;
    final isReasoningActive =
        config.tradingMode == TradingMode.reasoning && _isAgenticTradingEnabled;
    if (isReasoningActive || activeIndicatorCount > 0) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: colorScheme.tertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entry rules need setup',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onTertiaryContainer,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Systematic mode has no active indicators, so signals cannot pass. Start with three core indicators and a 50% minimum. Auto-trading stays off.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onTertiaryContainer,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () async {
              const starterIndicators = {
                'priceMovement',
                'marketDirection',
                'macd',
              };
              final enabledIndicators =
                  Map<String, bool>.from(strategy.enabledIndicators);
              for (final key in enabledIndicators.keys) {
                enabledIndicators[key] = starterIndicators.contains(key);
              }
              _minSignalStrengthController.text = '50';
              _selectedTemplateId = null;

              final updatedStrategy = strategy.copyWith(
                enabledIndicators: enabledIndicators,
                minSignalStrength: 50,
                requireAllIndicatorsGreen: false,
              );
              final updatedConfig = _createFullConfigFromSettings(
                provider,
                baseConfig: config.copyWith(strategyConfig: updatedStrategy),
              );
              await provider.updateConfig(updatedConfig, widget.userDocRef);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Balanced entry rules applied. Auto-trading remains off.'),
                ),
              );
            },
            icon: const Icon(Icons.tune),
            label: const Text('Apply balanced setup'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateList(BuildContext context) {
    return Consumer<BacktestingProvider>(
      builder: (context, backtestingProvider, child) {
        final agenticTradingProvider =
            Provider.of<AgenticTradingProvider>(context);
        var templates =
            List<TradeStrategyTemplate>.from(backtestingProvider.templates);
        final colorScheme = Theme.of(context).colorScheme;

        // Move selected template to the front
        if (_selectedTemplateId != null) {
          final selectedIndex =
              templates.indexWhere((t) => t.id == _selectedTemplateId);
          if (selectedIndex != -1) {
            final selectedTemplate = templates.removeAt(selectedIndex);
            templates.insert(0, selectedTemplate);
          }
        }

        if (!_hasScrolledToTemplate &&
            templates.isNotEmpty &&
            _selectedTemplateId != null) {
          final index =
              templates.indexWhere((t) => t.id == _selectedTemplateId);
          if (index != -1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_templateScrollController.hasClients) {
                // CarouselView items are 312 wide.
                // Index 0 is Save Strategy. Template index i matches children[i+1].
                // We scroll to position the selected template at the start of the view (or near it).
                final targetOffset = (index + 1) * 312.0;

                _templateScrollController.animateTo(
                  targetOffset,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              }
            });
            _hasScrolledToTemplate = true;
          }
        }

        final isCuratedActive = StrategyArchetypes.curated.any(
          (a) =>
              _selectedTemplateId == 'default_${a.id}' ||
              _selectedTemplateId == a.id,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Curated Strategy Archetypes Section
            _buildArchetypesSection(context),

            // 2. Strategy Execution Style (Moved from Auto-Trading primary card)
            _buildStrategyStyleSelector(context, agenticTradingProvider),
            const SizedBox(height: 12),

            // 3. Progressive Disclosure: Collapsible Custom & Advanced Strategy Templates
            Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              color: colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.12),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                initiallyExpanded: !isCuratedActive,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.tune_rounded,
                      size: 20, color: colorScheme.secondary),
                ),
                title: Text(
                  'Custom & Advanced Templates',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  '${templates.length} saved and backtested presets',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                trailing: TextButton.icon(
                  onPressed: () {
                    final brokerageUserStore =
                        Provider.of<BrokerageUserStore>(context, listen: false);
                    final brokerageUser = brokerageUserStore.items.isNotEmpty
                        ? brokerageUserStore
                            .items[brokerageUserStore.currentUserIndex]
                        : null;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TradingStrategiesPage(
                          currentConfig: _createConfigFromCurrentSettings(
                              agenticTradingProvider),
                          selectedStrategyId: _selectedTemplateId,
                          user: widget.user,
                          userDocRef: widget.userDocRef,
                          brokerageUser: brokerageUser,
                          service: widget.service,
                          onLoadStrategy: (TradeStrategyTemplate template) {
                            _loadFromTemplate(template);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Loaded strategy: ${template.name}')),
                            );
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const Text('View All'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                children: [
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: CarouselView(
                      controller: _templateScrollController,
                      itemExtent: 312,
                      shrinkExtent: 200,
                      itemSnapping: true,
                      onTap: (index) {
                        if (index == 0) {
                          _showSaveTemplateDialog(context);
                        } else if (index - 1 < templates.length) {
                          _showTemplateDetailsSheet(
                              context, templates[index - 1]);
                        }
                      },
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      children: [
                        _buildSaveStrategyCard(context, colorScheme),
                        ...templates.map((template) {
                          final isDefault = template.id.startsWith('default_');
                          final isSelected = template.id == _selectedTemplateId;

                          return _buildStrategyTemplateCard(
                              context, template, isSelected, isDefault);
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildStrategyStyleSelector(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isAgenticEnabled = _isAgenticTradingEnabled;
    final isReasoning =
        agenticTradingProvider.config.tradingMode == TradingMode.reasoning;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.12),
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
                  isReasoning ? Icons.psychology : Icons.functions,
                  size: 18,
                  color: isReasoning ? Colors.purple : Colors.teal,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Strategy Style',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isReasoning
                              ? (isAgenticEnabled
                                  ? Colors.purple
                                  : Colors.orange)
                              : Colors.teal)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (isReasoning
                                ? (isAgenticEnabled
                                    ? Colors.purple
                                    : Colors.orange)
                                : Colors.teal)
                            .withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      isReasoning
                          ? (isAgenticEnabled
                              ? 'Agentic AI Active'
                              : 'Agentic Disabled')
                          : 'Systematic Active',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isReasoning
                            ? (isAgenticEnabled ? Colors.purple : Colors.orange)
                            : Colors.teal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TradingMode>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: [
                  const ButtonSegment<TradingMode>(
                    value: TradingMode.systematic,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Systematic Rules'),
                    ),
                    icon: Icon(Icons.functions),
                  ),
                  ButtonSegment<TradingMode>(
                    value: TradingMode.reasoning,
                    enabled: isAgenticEnabled,
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Agentic Reasoning'),
                          if (!isAgenticEnabled) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.lock_outline, size: 14),
                          ],
                        ],
                      ),
                    ),
                    icon: const Icon(Icons.psychology),
                  ),
                ],
                selected: {
                  isAgenticEnabled
                      ? agenticTradingProvider.config.tradingMode
                      : TradingMode.systematic
                },
                onSelectionChanged: (Set<TradingMode> newSelection) {
                  if (newSelection.first == TradingMode.reasoning &&
                      !isAgenticEnabled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Enable Autonomous Agentic Trading in Beta Labs to use Agentic Reasoning.'),
                      ),
                    );
                    return;
                  }
                  final newConfig = _createFullConfigFromSettings(
                      agenticTradingProvider,
                      baseConfig: agenticTradingProvider.config
                          .copyWith(tradingMode: newSelection.first));
                  agenticTradingProvider.updateConfig(
                      newConfig, widget.userDocRef);
                },
              ),
            ),
            if (!isAgenticEnabled) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.purple.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 16, color: Colors.purple),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Autonomous Agentic Trading (AI) is disabled in Beta Labs. Enable it to activate Agentic Reasoning.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BetaLabsWidget(
                              user: widget.user,
                              userDocRef: widget.userDocRef,
                              userRole: widget.user.role,
                              featureAccessService: _featureAccessService,
                              service: widget.service,
                            ),
                          ),
                        ).then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      child: const Text('Beta Labs',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
            if (isReasoning && isAgenticEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cognitive Synthesis Engine',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildModeDetailItem(
                          Icons.psychology_outlined,
                          'Contextual Reasoning',
                          'Synthesizes indicators, macro regime, and GEX structural levels.'),
                      _buildModeDetailItem(Icons.rule, '11-Rule Discipline',
                          'Strictly enforces GEX mechanical checklists to eliminate bias.'),
                      _buildModeDetailItem(Icons.security, 'RiskGuard Overlay',
                          'All decisions filtered through portfolio concentration limits.'),
                    ],
                  ),
                ),
              ),
            if (!isReasoning)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.functions,
                              size: 16, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Deterministic Execution',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fixed-formula approach using direct indicator correlations and hard-coded thresholds for high-speed, repeatable execution.',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchetypesSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.auto_awesome_rounded,
                    size: 20, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Curated Strategy Archetypes',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '1-Tap Presets with Walk-Forward Validation',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 195,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: StrategyArchetypes.curated.length,
            itemBuilder: (context, index) {
              final archetype = StrategyArchetypes.curated[index];
              final isSelected =
                  _selectedTemplateId == 'default_${archetype.id}' ||
                      _selectedTemplateId == archetype.id;
              final isLocked = archetype.tradingMode == TradingMode.reasoning &&
                  !_isAgenticTradingEnabled;

              return SizedBox(
                width: 290,
                child: StrategyArchetypeCard(
                  archetype: archetype,
                  isSelected: isSelected,
                  isLocked: isLocked,
                  onTap: () {
                    StrategyArchetypeDetailBottomSheet.show(
                      context: context,
                      archetype: archetype,
                      isCurrentlyActive: isSelected,
                      isLocked: isLocked,
                      onUnlock: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BetaLabsWidget(
                              user: widget.user,
                              userDocRef: widget.userDocRef,
                              userRole: widget.user.role,
                              featureAccessService: _featureAccessService,
                              service: widget.service,
                            ),
                          ),
                        ).then((_) {
                          if (mounted) setState(() {});
                        });
                      },
                      onApply: (appliedArchetype) {
                        _applyArchetype(appliedArchetype);
                      },
                      onClone: (clonedArchetype, customName) {
                        _cloneArchetypeToTemplate(clonedArchetype, customName);
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _applyArchetype(StrategyArchetype archetype) {
    if (archetype.tradingMode == TradingMode.reasoning &&
        !_isAgenticTradingEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Enable Autonomous Agentic Trading in Beta Labs to use this archetype.'),
        ),
      );
      return;
    }

    final template = archetype.toTemplate();
    _loadFromTemplate(template);

    final provider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    final updatedConfig = provider.config.copyWith(
      tradingMode: archetype.tradingMode,
      selectedTemplateId: template.id,
      strategyConfig: archetype.config,
    );
    provider.updateConfig(updatedConfig, widget.userDocRef);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Applied "${archetype.name}" archetype (${archetype.walkForwardMetrics.winRate.toStringAsFixed(1)}% 1-Yr Win Rate).',
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _cloneArchetypeToTemplate(
      StrategyArchetype archetype, String customName) async {
    final backtestingProvider =
        Provider.of<BacktestingProvider>(context, listen: false);
    final newTemplate = archetype.toTemplate(
      customName: customName,
      customId: 'user_archetype_${DateTime.now().millisecondsSinceEpoch}',
    );
    await backtestingProvider.saveTemplate(newTemplate);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved custom preset "$customName".'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showTemplateDetailsSheet(
      BuildContext context, TradeStrategyTemplate template) {
    // Replacement start
    final agenticProvider =
        Provider.of<AgenticTradingProvider>(context, listen: false);
    final currentConfig = _createConfigFromCurrentSettings(agenticProvider);
    StrategyDetailsBottomSheet.showWithConfirmation(
      context: context,
      template: template,
      currentConfig: currentConfig,
      onConfirmLoad: (t) {
        _loadFromTemplate(t);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded strategy: ${t.name}')),
        );
      },
      onSearch: () {
        final brokerageUserStore =
            Provider.of<BrokerageUserStore>(context, listen: false);
        final brokerageUser = brokerageUserStore.items.isNotEmpty
            ? brokerageUserStore.items[brokerageUserStore.currentUserIndex]
            : null;

        if (brokerageUser == null) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in for signal search.')),
          );
          return;
        }

        final initialIndicators = template.config.enabledIndicators.entries
            .where((e) => e.value)
            .fold<Map<String, String>>({}, (prev, element) {
          prev[element.key] = "BUY";
          return prev;
        });

        Navigator.pop(context); // Close sheet
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => TradeSignalsPage(
                      user: widget.user,
                      userDocRef: widget.userDocRef,
                      brokerageUser: brokerageUser,
                      service: widget.service,
                      analytics: MyApp.analytics,
                      observer: MyApp.observer,
                      generativeService: GenerativeService(),
                      initialIndicators: initialIndicators,
                      strategyTemplate: template,
                    )));
      },
    );
  }

  Widget _buildSaveStrategyCard(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showSaveTemplateDialog(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded,
                    size: 28, color: colorScheme.primary),
              ),
              const SizedBox(height: 12),
              Text(
                "Save Current",
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "As New Template",
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStrategyTemplateCard(BuildContext context,
      TradeStrategyTemplate template, bool isSelected, bool isDefault) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 300,
        child: Card(
          elevation: isSelected ? 2 : 0,
          shadowColor: isSelected
              ? colorScheme.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          clipBehavior: Clip.antiAlias,
          color: isSelected
              ? colorScheme.primaryContainer.withValues(alpha: 0.15)
              : Theme.of(context).cardColor,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withValues(alpha: 0.1),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDefault
                            ? Colors.amber.withValues(alpha: 0.15)
                            : colorScheme.primaryContainer
                                .withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDefault ? Icons.verified : Icons.analytics_rounded,
                        color:
                            isDefault ? Colors.amber[800] : colorScheme.primary,
                        size: 22,
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
                                  template.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.check,
                                      size: 10, color: colorScheme.onPrimary),
                                ),
                            ],
                          ),
                          if (isDefault) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.5),
                                    width: 1),
                              ),
                              child: Text(
                                'SYSTEM',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  color: Colors.amber[900],
                                ),
                              ),
                            ),
                          ] else if (template.lastUsedAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Used ${_formatTime(template.lastUsedAt!)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  template.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 2,
                ),
                const Spacer(),
                // Stats Badge Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildStatBadge(
                        context,
                        '',
                        template.config.interval,
                        colorScheme.tertiary,
                        icon: Icons.timer_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildStatBadge(
                        context,
                        'TP',
                        '${template.config.takeProfitPercent.toStringAsFixed(1)}%',
                        Colors.green,
                        icon: Icons.trending_up_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildStatBadge(
                        context,
                        'SL',
                        '${template.config.stopLossPercent.toStringAsFixed(1)}%',
                        Colors.red,
                        icon: Icons.trending_down_rounded,
                      ),
                      const SizedBox(width: 8),
                      _buildStatBadge(
                        context,
                        'Risk',
                        '${(template.config.riskPerTrade * 100).toStringAsFixed(1)}%',
                        Colors.orange,
                        icon: Icons.shield_outlined,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Features Wrap/Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFeatureChip(
                          context,
                          Icons.show_chart_rounded,
                          template.config.symbolFilter.isEmpty
                              ? "All Symbols"
                              : (template.config.symbolFilter.length > 3
                                  ? "${template.config.symbolFilter.take(3).join(', ')} +${template.config.symbolFilter.length - 3}"
                                  : template.config.symbolFilter.join(', '))),
                      const SizedBox(width: 8),
                      _buildFeatureChip(context, Icons.layers_outlined,
                          _getIndicatorsSummary(template.config)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(
      BuildContext context, String label, String value, Color color,
      {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          if (label.isNotEmpty) ...[
            Text(
              '$label ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getIndicatorsSummary(TradeStrategyConfig config) {
    final Map<String, String> friendlyNames = {
      'priceMovement': 'Price',
      'momentum': 'RSI',
      'marketDirection': 'Market',
      'volume': 'Vol',
      'macd': 'MACD',
      'bollingerBands': 'BB',
      'stochastic': 'Stoch',
      'atr': 'ATR',
      'obv': 'OBV',
      'vwap': 'VWAP',
      'adx': 'ADX',
      'williamsR': 'WillR',
      'ichimoku': 'Ichi',
      'cci': 'CCI',
      'parabolicSar': 'SAR',
      'roc': 'ROC',
      'chaikinMoneyFlow': 'CMF',
      'fibonacciRetracements': 'Fib',
      'pivotPoints': 'Pivots',
      'gammaExposure': 'GEX',
    };

    final activeKeys = config.enabledIndicators.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    var names = activeKeys
        .map((k) => friendlyNames[k] ?? k)
        .toList(); // Map to friendly names

    if (config.customIndicators.isNotEmpty) {
      names.addAll(config.customIndicators.map((c) => c.name));
    }

    if (names.isEmpty) return 'No indicators';

    if (names.length <= 3) {
      return names.join(', ');
    }
    return '${names.take(3).join(", ")} +${names.length - 3}';
  }

  Widget _buildStatusHeader(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final brokerageUserStore =
        Provider.of<BrokerageUserStore>(context, listen: false);
    final selectedBrokerage = brokerageUserStore.currentUser;
    final hasBrokerage = selectedBrokerage != null;
    final hasSupportedBrokerage =
        AgenticTradingProvider.supportsAutoTradingBrokerage(
            selectedBrokerage?.source);
    final config = agenticTradingProvider.config;
    final hasPaperQuoteSource = AgenticTradingProvider.resolvePaperQuoteUser(
          userStore: brokerageUserStore,
          source: config.paperQuoteSource,
        ) !=
        null;
    final hasAlternativePaperQuoteSource = brokerageUserStore.items.any(
      (user) =>
          AgenticTradingProvider.supportsAutoTradingBrokerage(user.source),
    );
    final linkedQuoteSources = brokerageUserStore.items
        .map((user) => user.source)
        .where(AgenticTradingProvider.supportsAutoTradingBrokerage)
        .toSet();
    final automaticPaperQuoteSource =
        AgenticTradingProvider.resolvePaperQuoteUser(
      userStore: brokerageUserStore,
      source: PaperQuoteSource.selectedBrokerage,
    )?.source;
    final canChangePaperMode = hasSupportedBrokerage ||
        (hasBrokerage && widget.service != null && config.paperTradingMode);
    final strategy = config.strategyConfig;
    final isAgenticEnabled = _isAgenticTradingEnabled;
    final strategyStyle =
        config.tradingMode == TradingMode.reasoning ? 'Agentic' : 'Systematic';
    final hasEntryCriteria =
        (config.tradingMode == TradingMode.reasoning && isAgenticEnabled) ||
            strategy.enabledIndicators.values.any((enabled) => enabled) ||
            strategy.customIndicators.isNotEmpty;
    final canRunAutoTrading = hasEntryCriteria &&
        (config.paperTradingMode
            ? hasPaperQuoteSource
            : hasBrokerage &&
                (hasSupportedBrokerage || widget.service != null));
    final executionBlockReason = config.tradingMode == TradingMode.reasoning &&
            !isAgenticEnabled
        ? 'Enable Autonomous Agentic Trading in Beta Labs to activate Agentic Reasoning mode.'
        : config.paperTradingMode
            ? !hasPaperQuoteSource
                ? config.paperQuoteSource !=
                            PaperQuoteSource.selectedBrokerage &&
                        hasAlternativePaperQuoteSource
                    ? 'Pinned Paper quote source is unavailable in this device account list. Choose Automatic or reconnect the selected brokerage.'
                    : 'Connect a Robinhood or Schwab account on this device to provide Paper quotes.'
                : !hasEntryCriteria
                    ? 'Choose at least one entry indicator to enable Systematic mode.'
                    : null
            : !hasBrokerage
                ? 'Link a brokerage to enable automated execution.'
                : !hasEntryCriteria
                    ? 'Choose at least one entry indicator to enable Systematic mode.'
                    : !hasSupportedBrokerage && widget.service == null
                        ? 'Reconnect the selected brokerage to enable live execution.'
                        : null;
    final isEnabled = agenticTradingProvider.config.autoTradeEnabled;

    // Determine strategy display name
    String strategyDisplay =
        'Min Strength: ${_minSignalStrengthController.text}%';
    if (_selectedTemplateId != null) {
      final backtestingProvider =
          Provider.of<BacktestingProvider>(context, listen: false);
      final templateIndex = backtestingProvider.templates
          .indexWhere((t) => t.id == _selectedTemplateId);
      if (templateIndex != -1) {
        strategyDisplay = backtestingProvider.templates[templateIndex].name;
      } else {
        final archetype =
            StrategyArchetypes.curated.cast<StrategyArchetype?>().firstWhere(
                  (a) =>
                      _selectedTemplateId == 'default_${a!.id}' ||
                      _selectedTemplateId == a.id,
                  orElse: () => null,
                );
        if (archetype != null) {
          strategyDisplay = archetype.name;
        }
      }
    }

    return Column(
      children: [
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isEnabled
                  ? colorScheme.primary.withValues(alpha: 0.5)
                  : colorScheme.outline.withValues(alpha: 0.2),
              width: isEnabled ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Main Toggle Switch
              SwitchListTile(
                key: const ValueKey('auto-trading-toggle'),
                value: isEnabled,
                onChanged: !canRunAutoTrading && !isEnabled
                    ? null
                    : (bool value) async {
                        // Safety Check when Enabling
                        if (value && !isEnabled) {
                          final isPaperMode =
                              agenticTradingProvider.config.paperTradingMode;

                          if (!isPaperMode) {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Enable Real-Money Trading?'),
                                content: const Text(
                                    'WARNING: You are about to enable automated trading with REAL MONEY.\n\nEnsure you have tested your strategy in Paper Trading mode first.\n\nThe application is provided "as is" and assumes \nNO RESPONSIBILITY for financial losses.'),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false), // Cancel
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () =>
                                        Navigator.pop(context, true), // Confirm
                                    child: const Text('Enable Risks'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm != true) return;
                          }
                        }

                        if (!context.mounted) return;

                        // Confirm before stopping
                        if (!value && isEnabled) {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Stop Auto-Trading?'),
                              content: const Text(
                                  'This will stop all automated trading activities. Open positions will still need to be managed manually.'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false), // Cancel
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true), // Confirm
                                  child: const Text('Stop'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                        }

                        if (value) {
                          final checkInterval =
                              int.tryParse(_checkIntervalController.text) ?? 5;
                          final nextTradeTime = DateTime.now()
                              .add(Duration(minutes: checkInterval));
                          final countdownSeconds = checkInterval * 60;
                          agenticTradingProvider.updateAutoTradeCountdown(
                              nextTradeTime, countdownSeconds);
                        }

                        final newConfig = _createFullConfigFromSettings(
                            agenticTradingProvider,
                            baseConfig: agenticTradingProvider.config
                                .copyWith(autoTradeEnabled: value));
                        await agenticTradingProvider.updateConfig(
                            newConfig, widget.userDocRef);
                        await AgenticTradingBackgroundService.syncScheduling(
                          enabled: AgenticTradingBackgroundService
                              .shouldRegisterPeriodicTask(
                            hasUserDocument: true,
                            autoTradeEnabled: value,
                          ),
                        );
                      },
                title: Text(
                  'Auto-Trading',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  executionBlockReason ?? '$strategyDisplay • $strategyStyle',
                  // isEnabled ? 'Currently Active • $strategyDisplay' : 'Paused',
                  style: TextStyle(
                    fontSize: 13,
                    color: isEnabled
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.smart_toy,
                    color: isEnabled
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
                tileColor: isEnabled
                    ? colorScheme.primaryContainer.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              const Divider(height: 1),
              // Execution Controls: Paper Trading Mode & Require Approval
              _buildCardExecutionSettings(
                context,
                agenticTradingProvider,
                hasSupportedBrokerage,
                hasBrokerage,
                linkedQuoteSources,
                selectedBrokerage?.source,
                automaticPaperQuoteSource,
                canChangePaperMode,
              ),
              if (agenticTradingProvider.emergencyStopActivated) ...[
                const Divider(height: 1),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: colorScheme.errorContainer,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: colorScheme.error, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Emergency Stop Active',
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Trading halted manually.',
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer
                                        .withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () async {
                            await agenticTradingProvider
                                .deactivateEmergencyStop(
                              userDocRef: widget.userDocRef,
                            );
                          },
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Resume Trading'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colorScheme.error,
                            foregroundColor: colorScheme.onError,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isEnabled) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (agenticTradingProvider.isAutoTrading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Analyzing Market...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      'Checking 15+ indicators strategy...',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Next Run In',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Row(
                                              children: [
                                                Icon(Icons.info_outline,
                                                    size: 20),
                                                SizedBox(width: 8),
                                                Text('Execution Timing',
                                                    style: TextStyle(
                                                        fontSize: 16)),
                                              ],
                                            ),
                                            content: Text(
                                              'Foreground checks use the configured ${agenticTradingProvider.config.checkIntervalMinutes}-minute interval.\n\n'
                                              'Background checks are best-effort: Android requests about 15 minutes, while iOS timing is opportunistic.\n\n'
                                              'Force-quit, network loss, or stale quotes can prevent execution. Market-close exits are not guaranteed; manage open positions manually.',
                                              style: const TextStyle(
                                                  fontSize: 13, height: 1.4),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Got it'),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: Icon(
                                          Icons.info_outline,
                                          size: 15,
                                          color: colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  textBaseline: TextBaseline.alphabetic,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  children: [
                                    Text(
                                      '${agenticTradingProvider.autoTradeCountdownSeconds ~/ 60}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.primary,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'm ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${(agenticTradingProvider.autoTradeCountdownSeconds % 60).toString().padLeft(2, '0')}s',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.primary
                                            .withValues(alpha: 0.8),
                                        fontFeatures: const [
                                          FontFeature.tabularFigures()
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: 1.0 -
                                    (agenticTradingProvider
                                            .autoTradeCountdownSeconds /
                                        (agenticTradingProvider
                                                .config.checkIntervalMinutes *
                                            60)),
                                minHeight: 6,
                                backgroundColor: colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    colorScheme.primary),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                agenticTradingProvider.updateAutoTradeCountdown(
                                    DateTime.now(), 0);
                              },
                              icon: const Icon(Icons.play_arrow, size: 16),
                              label: const Text('Run Now'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () async {
                                await agenticTradingProvider
                                    .activateEmergencyStop(
                                  userDocRef: widget.userDocRef,
                                );
                              },
                              icon: const Icon(Icons.stop, size: 16),
                              label: const Text('Stop'),
                              style: FilledButton.styleFrom(
                                backgroundColor: colorScheme.error,
                                foregroundColor: colorScheme.onError,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonitoringCard(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    final exitStatus = agenticTradingProvider.latestMarketCloseExitStatus;
    final exitStatusValue = exitStatus?['status'] as String?;
    final exitStatusColor = exitStatusValue == 'missed'
        ? colorScheme.error
        : exitStatusValue == 'completed'
            ? Colors.green
            : Colors.orange;
    final exitStatusLabel = switch (exitStatusValue) {
      'completed' => 'Order submitted',
      'missed' => 'Missed',
      'attempted' => 'Attempted, not confirmed',
      _ => null,
    };

    // Pre-calculate Last Trade / Last Action
    String lastActionLabel = 'Last Trade';
    String lastActionValue = '--:--';
    Color? lastActionColor;
    IconData lastActionIcon = Icons.history;

    if (agenticTradingProvider.autoTradeHistory.isNotEmpty) {
      final last = agenticTradingProvider.autoTradeHistory.first;
      final isRejected =
          last['rejected'] == true || last['status'] == 'rejected';
      final symbol = last['symbol']?.toString() ?? '';

      if (isRejected) {
        lastActionLabel = 'Last Action';
        lastActionValue = 'REJ $symbol';
        lastActionColor = colorScheme.error;
        lastActionIcon = Icons.cancel_outlined;
      } else {
        final action = last['action']?.toString().toUpperCase() ?? 'TRADE';
        lastActionLabel = 'Last Trade';
        lastActionValue = '$action $symbol';
        if (action.contains('BUY')) {
          lastActionColor = Colors.green;
        } else if (action.contains('SELL')) {
          lastActionColor = Colors.orange;
        }
      }
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_heart_outlined,
                    size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Trading Monitoring',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Metrics Row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (agenticTradingProvider.lastAutoTradeResult != null) {
                        _showLastExecutionDetails(
                            context, agenticTradingProvider);
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AutomatedTradingApprovalsWidget(
                              user: widget.user,
                              userDocRef: widget.userDocRef,
                              service: widget.service,
                              initialTabIndex: 1,
                            ),
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: _buildSummaryItem(
                      context,
                      lastActionLabel,
                      lastActionValue,
                      lastActionIcon,
                      valueColor: lastActionColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AgenticTradingPerformanceWidget(
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                            service: widget.service,
                            initialTabIndex: 1,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: _buildSummaryItem(
                      context,
                      'Today',
                      '${AgenticTradingProvider.countTradesOn(agenticTradingProvider.autoTradeHistory, DateTime.now())} trades',
                      Icons.today,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AgenticTradingPerformanceWidget(
                            user: widget.user,
                            userDocRef: widget.userDocRef,
                            service: widget.service,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Builder(builder: (context) {
                      double totalPnl = 0;
                      int closedCount = 0;
                      for (var trade
                          in agenticTradingProvider.autoTradeHistory) {
                        if (trade['profitLoss'] != null) {
                          totalPnl += (trade['profitLoss'] as num).toDouble();
                          closedCount++;
                        }
                      }
                      final pnlColor = closedCount == 0
                          ? colorScheme.onSurfaceVariant
                          : totalPnl > 0
                              ? Colors.green
                              : totalPnl < 0
                                  ? colorScheme.error
                                  : colorScheme.onSurfaceVariant;
                      final pnlPrefix = totalPnl > 0 ? '+' : '';
                      final pnlText = closedCount == 0 && totalPnl == 0
                          ? '\$0.00'
                          : '$pnlPrefix\$${totalPnl.toStringAsFixed(2)}';
                      return _buildSummaryItem(
                        context,
                        'Performance',
                        pnlText,
                        Icons.analytics,
                        valueColor: pnlColor,
                      );
                    }),
                  ),
                ),
              ],
            ),

            if (exitStatus != null && exitStatusLabel != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: exitStatusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last market-close exit: $exitStatusLabel'
                      '${exitStatus['symbol'] == null ? '' : ' · ${exitStatus['symbol']}'}'
                      '${exitStatus['tradingDate'] == null ? '' : ' · ${exitStatus['tradingDate']}'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: exitStatusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),
            _buildPendingOrders(context, agenticTradingProvider),
            const SizedBox(height: 12),
            _buildActivityLog(context, agenticTradingProvider, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityLog(BuildContext context,
      AgenticTradingProvider agenticTradingProvider, ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: agenticTradingProvider.isAutoTrading,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          title: Text(
            'Activity Log',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: colorScheme.onSurface,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${agenticTradingProvider.activityLog.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 20),
            ],
          ),
          children: [
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              padding: const EdgeInsets.all(10),
              child: agenticTradingProvider.activityLog.isEmpty
                  ? Center(
                      child: Text(
                        'No activity recorded yet.',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: colorScheme.outline.withValues(alpha: 0.1),
                      ),
                      itemCount: agenticTradingProvider.activityLog.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            agenticTradingProvider.activityLog[index],
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'RobotoMono',
                              color: colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${agenticTradingProvider.activityLog.length} items',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear Log?'),
                        content: const Text(
                            'This will remove all activity log entries. This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      agenticTradingProvider.clearLog();
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingOrders(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    final colorScheme = Theme.of(context).colorScheme;

    if (agenticTradingProvider.pendingOrders.isEmpty) {
      final historyCount = agenticTradingProvider.autoTradeHistory.length;
      return Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          dense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.fact_check_outlined,
              color: colorScheme.primary,
              size: 20,
            ),
          ),
          title: const Text(
            'Trade Proposals & Audit Log',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            historyCount > 0
                ? 'Inspect $historyCount historical AI proposals, GEX levels & rejections'
                : 'Audit AI reasoning thesis, institutional GEX levels & rejections',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AutomatedTradingApprovalsWidget(
                  user: widget.user,
                  userDocRef: widget.userDocRef,
                  service: widget.service,
                  initialTabIndex: 1,
                ),
              ),
            );
          },
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.pending_actions,
              size: 16,
              color: colorScheme.tertiary,
            ),
            const SizedBox(width: 6),
            Text(
              'Pending Approvals',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${agenticTradingProvider.pendingOrders.length}',
                style: TextStyle(
                  color: colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                foregroundColor: colorScheme.primary,
              ),
              icon: const Icon(Icons.history, size: 14),
              label:
                  const Text('All & History', style: TextStyle(fontSize: 12)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AutomatedTradingApprovalsWidget(
                      user: widget.user,
                      userDocRef: widget.userDocRef,
                      service: widget.service,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (agenticTradingProvider.emergencyStopActivated)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Emergency stop is active. Pending orders cannot be approved.',
              style: TextStyle(
                color: colorScheme.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Builder(builder: (context) {
          final sortedPendingOrders = List<Map<String, dynamic>>.from(
              agenticTradingProvider.pendingOrders)
            ..sort((a, b) {
              final tA = DateTime.tryParse(a['timestamp'] as String? ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              final tB = DateTime.tryParse(b['timestamp'] as String? ?? '') ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              return tB.compareTo(tA);
            });
          final order = sortedPendingOrders.first;
          final symbol = order['symbol'] as String;
          final action = order['action'] as String;
          final quantity = order['quantity'] as int;
          final price = order['price'] as double;
          final timestamp =
              DateTime.tryParse(order['timestamp']?.toString() ?? '') ??
                  DateTime.now();
          final reason = order['reason'] as String?;
          final confidence = order['confidence'] as num?;
          final assessment = order['assessment'] as Map<String, dynamic>?;
          final proposal = order['proposal'] as Map<String, dynamic>?;

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
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
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: action.toUpperCase() == 'BUY'
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              action.toUpperCase(),
                              style: TextStyle(
                                color: action.toUpperCase() == 'BUY'
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            symbol,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (proposal?['qualification'] != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color:
                                    (proposal!['qualification'] == 'CONFIRMED'
                                            ? Colors.green
                                            : (proposal['qualification'] ==
                                                    'BLOCKED'
                                                ? Colors.red
                                                : Colors.amber))
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                proposal['qualification'].toString(),
                                style: TextStyle(
                                  color: proposal['qualification'] ==
                                          'CONFIRMED'
                                      ? Colors.green
                                      : (proposal['qualification'] == 'BLOCKED'
                                          ? Colors.red
                                          : Colors.amber),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _formatTime(timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$quantity shares @ \$${price.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          if (proposal?['rewardRiskRatio'] != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'R:R ${(proposal!['rewardRiskRatio'] as num).toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (confidence != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getConfidenceColor(confidence.toDouble())
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _getConfidenceColor(confidence.toDouble())
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt,
                                size: 12,
                                color:
                                    _getConfidenceColor(confidence.toDouble()),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${confidence.toString()}%',
                                style: TextStyle(
                                  color: _getConfidenceColor(
                                      confidence.toDouble()),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              reason,
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (assessment != null && assessment['metrics'] != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (assessment['metrics']['volatilityFilter'] != null)
                          _buildMetricBadge(
                            context,
                            'VOL',
                            assessment['metrics']['volatilityFilter'] == 'pass',
                          ),
                        if (assessment['metrics']['correlationFilter'] != null)
                          _buildMetricBadge(
                            context,
                            'CORR',
                            assessment['metrics']['correlationFilter'] ==
                                'pass',
                          ),
                        if (assessment['metrics']['sectorLimitFilter'] != null)
                          _buildMetricBadge(
                            context,
                            'SECTOR',
                            assessment['metrics']['sectorLimitFilter'] ==
                                'pass',
                          ),
                        if (proposal != null && proposal['interval'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              proposal['interval'].toString().toUpperCase(),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (proposal != null && proposal['gexData'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.analytics_outlined,
                                  size: 14, color: Colors.blue),
                              const SizedBox(width: 4),
                              Text(
                                'GEX Analysis',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildGexMetric(
                                  'pTrans',
                                  proposal['gexData']['pTrans'] != null
                                      ? '\$${proposal['gexData']['pTrans'].toStringAsFixed(2)}'
                                      : 'N/A'),
                              _buildGexMetric(
                                  'nTrans',
                                  proposal['gexData']['nTrans'] != null
                                      ? '\$${proposal['gexData']['nTrans'].toStringAsFixed(2)}'
                                      : 'N/A'),
                              _buildGexMetric(
                                  'Flip',
                                  proposal['gexData']['gammaFlip'] != null
                                      ? '\$${proposal['gexData']['gammaFlip'].toStringAsFixed(2)}'
                                      : 'N/A'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (proposal != null &&
                      proposal['macroAssessment'] != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getMacroColor(
                                proposal['macroAssessment']['status'])
                            .withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getMacroIcon(
                                proposal['macroAssessment']['status']),
                            size: 14,
                            color: _getMacroColor(
                                proposal['macroAssessment']['status']),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Macro: ${proposal['macroAssessment']['reason']}',
                              style: TextStyle(
                                fontSize: 11,
                                color: _getMacroColor(
                                    proposal['macroAssessment']['status']),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Approve places a ${agenticTradingProvider.config.paperTradingMode ? 'paper ' : ''}'
                    '${order['action']} order for ${order['quantity']} ${order['symbol']}'
                    '${order['price'] is num ? ' at about \$${(order['price'] as num).toStringAsFixed(2)}' : ''}.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _busyOrders.contains(_orderKey(order))
                            ? null
                            : () => _rejectOrder(agenticTradingProvider, order),
                        child: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _busyOrders.contains(_orderKey(order)) ||
                                agenticTradingProvider.emergencyStopActivated
                            ? null
                            : () => _approveOrder(
                                context, agenticTradingProvider, order),
                        child: _busyOrders.contains(_orderKey(order))
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Approve'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        if (agenticTradingProvider.pendingOrders.length > 1) ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AutomatedTradingApprovalsWidget(
                      user: widget.user,
                      userDocRef: widget.userDocRef,
                      service: widget.service,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+ ${agenticTradingProvider.pendingOrders.length - 1} more pending approval(s) in Full View',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 11,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ] else ...[
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AutomatedTradingApprovalsWidget(
                      user: widget.user,
                      userDocRef: widget.userDocRef,
                      service: widget.service,
                      initialTabIndex: 1,
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View proposal & trade history',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 11,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSymbolFilterInput(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: 'Symbol Filter',
            labelStyle:
                TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            helperText:
                'Only trade specific symbols (leave empty for all supported)',
            helperStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
            prefixIcon: Icon(Icons.filter_list,
                size: 18, color: colorScheme.primary.withValues(alpha: 0.8)),
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
            filled: true,
            fillColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: [
              if (_symbolFilter.isEmpty)
                Text(
                  'All Symbols',
                  style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.5)),
                ),
              ..._symbolFilter.map((symbol) => Chip(
                    label: Text(symbol, style: const TextStyle(fontSize: 12)),
                    onDeleted: () {
                      setState(() {
                        _symbolFilter.remove(symbol);
                      });
                      _saveSettings();
                    },
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                  )),
              ActionChip(
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                avatar: const Icon(Icons.add, size: 14),
                onPressed: () {
                  _showAddSymbolDialog(context);
                },
                visualDensity: VisualDensity.compact,
                backgroundColor: colorScheme.primaryContainer,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddSymbolDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Symbol'),
        content: TextField(
          controller: _newSymbolController,
          decoration: const InputDecoration(labelText: 'Symbol (e.g. AAPL)'),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final symbol = _newSymbolController.text.trim().toUpperCase();
              if (symbol.isNotEmpty && !_symbolFilter.contains(symbol)) {
                setState(() {
                  _symbolFilter.add(symbol);
                });
                _newSymbolController.clear();
                _saveSettings();
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildPaperQuoteSourceSelector(
    BuildContext context,
    AgenticTradingProvider provider,
    Set<BrokerageSource> linkedQuoteSources,
    BrokerageSource? activeSource,
    BrokerageSource? automaticSource,
  ) {
    final config = provider.config;
    final hasRobinhood = linkedQuoteSources.contains(BrokerageSource.robinhood);
    final hasSchwab = linkedQuoteSources.contains(BrokerageSource.schwab);
    final pinnedBrokerageSource = switch (config.paperQuoteSource) {
      PaperQuoteSource.selectedBrokerage => null,
      PaperQuoteSource.robinhood => BrokerageSource.robinhood,
      PaperQuoteSource.schwab => BrokerageSource.schwab,
    };
    final showPinSelector = linkedQuoteSources.length > 1 ||
        (pinnedBrokerageSource != null &&
            !linkedQuoteSources.contains(pinnedBrokerageSource));
    final activeLabel = switch (activeSource) {
      BrokerageSource.robinhood => 'Robinhood',
      BrokerageSource.schwab => 'Schwab',
      _ => 'unsupported brokerage',
    };
    final automaticLabel = switch (automaticSource) {
      BrokerageSource.robinhood => 'Robinhood',
      BrokerageSource.schwab => 'Schwab',
      _ => null,
    };
    final quoteSourceLabel = switch (config.paperQuoteSource) {
      PaperQuoteSource.robinhood => 'Robinhood',
      PaperQuoteSource.schwab => 'Schwab',
      PaperQuoteSource.selectedBrokerage => null,
    };
    if (!showPinSelector) {
      if (automaticLabel == null) return const SizedBox.shrink();
      final message = quoteSourceLabel == null
          ? 'Automatically uses $automaticLabel for Paper quotes. Paper fills stay in your separate Paper account.'
          : 'Uses $quoteSourceLabel quotes. Simulated trades stay in your separate Paper account.';
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final items = <DropdownMenuItem<PaperQuoteSource>>[
      const DropdownMenuItem(
        value: PaperQuoteSource.selectedBrokerage,
        child: Text('Automatic'),
      ),
      if (hasRobinhood || config.paperQuoteSource == PaperQuoteSource.robinhood)
        DropdownMenuItem(
          value: PaperQuoteSource.robinhood,
          enabled: hasRobinhood,
          child: Text(hasRobinhood ? 'Robinhood' : 'Robinhood (not linked)'),
        ),
      if (hasSchwab || config.paperQuoteSource == PaperQuoteSource.schwab)
        DropdownMenuItem(
          value: PaperQuoteSource.schwab,
          enabled: hasSchwab,
          child: Text(hasSchwab ? 'Schwab' : 'Schwab (not linked)'),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<PaperQuoteSource>(
            key: const ValueKey('paperQuoteSource'),
            initialValue: config.paperQuoteSource,
            decoration: const InputDecoration(labelText: 'Paper quote source'),
            items: items,
            onChanged: (source) async {
              if (source == null || source == config.paperQuoteSource) return;
              final newConfig = _createFullConfigFromSettings(
                provider,
                baseConfig: config.copyWith(paperQuoteSource: source),
              );
              await provider.updateConfig(newConfig, widget.userDocRef);
            },
          ),
          const SizedBox(height: 4),
          Text(
            quoteSourceLabel == null
                ? '${AgenticTradingProvider.supportsAutoTradingBrokerage(activeSource) ? 'Follows the active $activeLabel account' : 'Uses the first linked supported account'} for live quotes. Pin a source to keep Paper quotes independent.'
                : 'Pinned to $quoteSourceLabel quotes. Strategy simulations will use $quoteSourceLabel data regardless of which account you view.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCardExecutionSettings(
    BuildContext context,
    AgenticTradingProvider agenticTradingProvider,
    bool hasSupportedBrokerage,
    bool hasBrokerage,
    Set<BrokerageSource> linkedQuoteSources,
    BrokerageSource? activeSource,
    BrokerageSource? automaticPaperQuoteSource,
    bool canChangePaperMode,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (!hasSupportedBrokerage &&
            (!hasBrokerage || !agenticTradingProvider.config.paperTradingMode))
          ListTile(
            leading:
                Icon(Icons.lock_outline, color: colorScheme.onSurfaceVariant),
            title: const Text('Automated Paper Tests'),
            subtitle: Text(
              hasBrokerage
                  ? 'Link Robinhood or Schwab to provide Paper quotes. Live orders require the active account to be Robinhood or Schwab.'
                  : 'Link a Robinhood or Schwab account to provide Paper quotes and run automated Paper tests.',
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          )
        else
          SwitchListTile(
            key: const ValueKey('paperTradingMode'),
            value: agenticTradingProvider.config.paperTradingMode,
            onChanged: !canChangePaperMode
                ? null
                : (value) async {
                    if (value && !hasSupportedBrokerage) return;
                    if (!value &&
                        agenticTradingProvider.config.autoTradeEnabled) {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Switch to real-money trading?'),
                          content: const Text(
                            'Auto-trading is enabled. The next eligible cycle may submit real orders through your selected brokerage.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Switch to Live'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true) return;
                    }
                    final newConfig = _createFullConfigFromSettings(
                      agenticTradingProvider,
                      baseConfig: agenticTradingProvider.config
                          .copyWith(paperTradingMode: value),
                    );
                    await agenticTradingProvider.updateConfig(
                        newConfig, widget.userDocRef);
                  },
            activeColor: Colors.blue,
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Paper Trading Mode',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: colorScheme.onSurface,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: agenticTradingProvider.config.paperTradingMode
                        ? Colors.blue
                        : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    agenticTradingProvider.config.paperTradingMode
                        ? 'PAPER'
                        : 'LIVE',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              hasSupportedBrokerage
                  ? 'Simulate orders with real-time quotes. Paper cash, positions and fills stay separate — no real money is used.'
                  : 'Link Robinhood or Schwab to provide Paper quotes. Paper orders remain simulated.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
        if (agenticTradingProvider.config.paperTradingMode)
          _buildPaperQuoteSourceSelector(
            context,
            agenticTradingProvider,
            linkedQuoteSources,
            activeSource,
            automaticPaperQuoteSource,
          ),
        const Divider(height: 1),
        // Require Approval
        SwitchListTile(
          key: const ValueKey('requireApproval'),
          value: agenticTradingProvider.config.requireApproval,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config
                    .copyWith(requireApproval: value));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          activeColor: Colors.amber[800],
          title: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Require Approval',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: colorScheme.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: agenticTradingProvider.config.requireApproval
                      ? Colors.amber[800]
                      : Colors.teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  agenticTradingProvider.config.requireApproval
                      ? 'REVIEW'
                      : 'AUTO',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Text(
            agenticTradingProvider.config.requireApproval
                ? 'Orders wait for your review in the app and will not execute unattended.'
                : 'Orders execute automatically without manual confirmation.',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
      ],
    );
  }

  Widget _buildExecutionSettings(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    return _buildSection(
      context: context,
      title: 'Execution Settings',
      icon: Icons.settings,
      initiallyExpanded: false,
      children: [
        _buildSymbolFilterInput(context),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trading Interval',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 4),
            Text(
              'Determines the candle size used for indicator analysis.',
              style:
                  TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                segments: const [
                  ButtonSegment<String>(
                    value: '15m',
                    label: Text('15 Min'),
                    icon: Icon(Icons.timer_outlined, size: 16),
                  ),
                  ButtonSegment<String>(
                    value: '1h',
                    label: Text('1 Hour'),
                    icon: Icon(Icons.access_time, size: 16),
                  ),
                  ButtonSegment<String>(
                    value: '1d',
                    label: Text('1 Day'),
                    icon: Icon(Icons.calendar_today, size: 16),
                  ),
                ],
                selected: {_interval},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _interval = newSelection.first;
                  });
                  final provider = Provider.of<AgenticTradingProvider>(context,
                      listen: false);
                  final newConfig = _createFullConfigFromSettings(provider,
                      baseConfig: provider.config.copyWith(
                          strategyConfig: provider.config.strategyConfig
                              .copyWith(interval: _interval)));
                  provider.updateConfig(newConfig, widget.userDocRef);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          controller: _checkIntervalController,
          label: 'Foreground Check Frequency (minutes)',
          helperText:
              'Controls foreground checks only; background checks are OS scheduled about every 15 minutes.',
          icon: Icons.update,
          min: 1,
          suffixText: 'min',
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          controller: _autoTradeCooldownController,
          label: 'Cooldown Period (minutes)',
          helperText: 'Minimum time between trades',
          icon: Icons.timer,
          min: 1,
          suffixText: 'min',
        ),
        const SizedBox(height: 16),
        const _BackgroundActivityPanel(),
        const SizedBox(height: 16),
        // Extended Trading Hours Section
        _buildSubsectionTitle(context, 'Extended Hours'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              _buildSimpleSwitch(
                context,
                'Pre-Market',
                '4:00 AM - 9:30 AM ET',
                agenticTradingProvider.config.allowPreMarketTrading,
                (val) {
                  final newConfig = _createFullConfigFromSettings(
                      agenticTradingProvider,
                      baseConfig: agenticTradingProvider.config
                          .copyWith(allowPreMarketTrading: val));
                  agenticTradingProvider.updateConfig(
                      newConfig, widget.userDocRef);
                },
              ),
              Divider(
                  height: 1, color: colorScheme.outline.withValues(alpha: 0.1)),
              _buildSimpleSwitch(
                context,
                'After-Hours',
                'Regular close - 8:00 PM ET; starts earlier on early-close days',
                agenticTradingProvider.config.allowAfterHoursTrading,
                (val) {
                  final newConfig = _createFullConfigFromSettings(
                      agenticTradingProvider,
                      baseConfig: agenticTradingProvider.config
                          .copyWith(allowAfterHoursTrading: val));
                  agenticTradingProvider.updateConfig(
                      newConfig, widget.userDocRef);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Regular market: 9:30 AM - 4:00 PM ET on trading days; scheduled early closes apply',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleSwitch(BuildContext context, String title, String subtitle,
      bool value, ValueChanged<bool> onChanged) {
    return Material(
      color: Colors.transparent,
      child: SwitchListTile(
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildRiskManagement(
      BuildContext context, AgenticTradingProvider agenticTradingProvider,
      {Key? key}) {
    final dollarCap =
        _formattedCapitalBudgetCap(context, agenticTradingProvider);
    return _buildSection(
      key: key,
      context: context,
      title: 'Risk Management',
      icon: Icons.security,
      children: [
        _buildSubsectionTitle(context, 'Position Sizing'),
        const SizedBox(height: 12),
        _buildNumberField(
          controller: _tradeQuantityController,
          label: 'Trade Quantity',
          helperText: 'Number of shares per trade',
          icon: Icons.shopping_cart,
          min: 1,
        ),
        const SizedBox(height: 16),
        _buildSwitchListTile(
          'enableDynamicPositionSizing',
          'Enable Dynamic Sizing',
          'Adjust trade size based on ATR volatility',
          agenticTradingProvider,
          defaultValue: false,
          value: agenticTradingProvider
              .config.strategyConfig.enableDynamicPositionSizing,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableDynamicPositionSizing: value)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          extraContent: Column(
            children: [
              const SizedBox(height: 16),
              _buildNumberField(
                controller: _riskPerTradeController,
                label: 'Risk Per Trade %',
                helperText: '% of account to risk (e.g. 1.0 for 1%)',
                icon: Icons.percent,
                isDecimal: true,
                min: 0.01,
                max: 100,
                suffixText: '%',
              ),
              const SizedBox(height: 16),
              _buildNumberField(
                controller: _atrMultiplierController,
                label: 'ATR Multiplier',
                helperText: 'Multiplier for Stop Loss distance (e.g. 2.0)',
                icon: Icons.close,
                isDecimal: true,
                min: 0.1,
                suffixText: 'x',
              ),
            ],
          ),
        ),
        _buildSubsectionTitle(context, 'Safety Limits'),
        const SizedBox(height: 12),
        _buildNumberField(
          controller: _maxPositionSizeController,
          label: 'Max Position Size',
          helperText: 'Maximum shares for any position',
          icon: Icons.horizontal_rule,
          min: 1,
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          controller: _maxPortfolioConcentrationController,
          label: 'Capital Budget (Max Concentration %)',
          helperText: dollarCap != null
              ? 'Max portfolio equity allocated (≈ $dollarCap)'
              : 'Max percentage of portfolio equity allocated to auto-trading',
          icon: Icons.pie_chart,
          isDecimal: true,
          min: 0,
          max: 100,
          suffixText: '%',
        ),
        const SizedBox(height: 16),
        _buildNumberField(
          controller: _dailyTradeLimitController,
          label: 'Daily Trade Limit',
          helperText: 'Maximum trades per day',
          icon: Icons.calendar_today,
          min: 1,
        ),
        const SizedBox(height: 16),
        _buildSubsectionTitle(context, 'Advanced Controls'),
        const SizedBox(height: 12),
        _buildSwitchListTile(
          'enableSectorLimits',
          'Sector Limits',
          'Limit exposure to specific sectors',
          agenticTradingProvider,
          defaultValue: false,
          value:
              agenticTradingProvider.config.strategyConfig.enableSectorLimits,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableSectorLimits: value)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          extraContent: _buildNumberField(
            controller: _maxSectorExposureController,
            label: 'Max Sector Exposure %',
            helperText: 'Max allocation per sector (0-100)',
            icon: Icons.pie_chart,
            isDecimal: true,
            min: 0,
            max: 100,
            suffixText: '%',
          ),
        ),
        const SizedBox(height: 16),
        _buildSwitchListTile(
          'enableCorrelationChecks',
          'Correlation Checks',
          'Avoid highly correlated positions',
          agenticTradingProvider,
          defaultValue: false,
          value: agenticTradingProvider
              .config.strategyConfig.enableCorrelationChecks,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableCorrelationChecks: value)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          extraContent: _buildNumberField(
            controller: _maxCorrelationController,
            label: 'Max Correlation',
            helperText: 'Max correlation coefficient (0-100)',
            icon: Icons.compare_arrows,
            isDecimal: true,
            min: 0,
            max: 100,
            suffixText: '%',
          ),
        ),
        const SizedBox(height: 16),
        _buildSwitchListTile(
          'enableVolatilityFilters',
          'Volatility Filters',
          'Filter trades based on volatility (IV Rank)',
          agenticTradingProvider,
          defaultValue: false,
          value: agenticTradingProvider
              .config.strategyConfig.enableVolatilityFilters,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableVolatilityFilters: value)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          extraContent: Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _minVolatilityController,
                  label: 'Min Volatility',
                  helperText: 'Min IV Rank (0-100)',
                  icon: Icons.show_chart,
                  isDecimal: true,
                  min: 0,
                  max: 100,
                  suffixText: '%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberField(
                  controller: _maxVolatilityController,
                  label: 'Max Volatility',
                  helperText: 'Max IV Rank (0-100)',
                  icon: Icons.show_chart,
                  isDecimal: true,
                  min: 0,
                  max: 100,
                  suffixText: '%',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSwitchListTile(
          'enableDrawdownProtection',
          'Drawdown Protection',
          'Stop trading if drawdown exceeds limit',
          agenticTradingProvider,
          defaultValue: false,
          value: agenticTradingProvider
              .config.strategyConfig.enableDrawdownProtection,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableDrawdownProtection: value)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          extraContent: _buildNumberField(
            controller: _maxDrawdownController,
            label: 'Max Drawdown %',
            helperText: 'Stop trading at this drawdown',
            icon: Icons.trending_down,
            isDecimal: true,
            min: 0,
            max: 100,
            suffixText: '%',
          ),
        ),
        const SizedBox(height: 16),
        _buildSubsectionTitle(context, 'Macro Risk Control'),
        const SizedBox(height: 12),
        _buildSwitchListTile(
          'reduceSizeOnRiskOff',
          'Reduce Size on RISK_OFF',
          'Scale down position size during bearish market regimes',
          agenticTradingProvider,
          defaultValue: false,
          value:
              agenticTradingProvider.config.strategyConfig.reduceSizeOnRiskOff,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(reduceSizeOnRiskOff: value)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          extraContent: _buildNumberField(
            controller: _riskOffSizeReductionController,
            label: 'Reduction %',
            helperText: 'Percentage to cut position size (e.g. 50.0)',
            icon: Icons.cut,
            isDecimal: true,
            min: 0,
            max: 100,
            suffixText: '%',
          ),
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

  Widget _buildExitStrategies(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    return _buildSection(
      context: context,
      title: 'Exit Strategies',
      icon: Icons.logout, // exit_to_app,
      children: [
        ExitStrategiesWidget(
          takeProfitController: _takeProfitPercentController,
          stopLossController: _stopLossPercentController,
          trailingStopController: _trailingStopPercentController,
          timeBasedExitController: _timeBasedExitMinutesController,
          marketCloseExitController: _marketCloseExitMinutesController,
          rsiExitThresholdController: _rsiExitThresholdController,
          signalStrengthExitThresholdController:
              _signalStrengthExitThresholdController,
          gexExitThresholdController: _gexExitThresholdController,
          trailingStopEnabled:
              agenticTradingProvider.config.strategyConfig.trailingStopEnabled,
          timeBasedExitEnabled:
              agenticTradingProvider.config.strategyConfig.timeBasedExitEnabled,
          marketCloseExitEnabled: agenticTradingProvider
              .config.strategyConfig.marketCloseExitEnabled,
          partialExitsEnabled:
              agenticTradingProvider.config.strategyConfig.enablePartialExits,
          rsiExitEnabled:
              agenticTradingProvider.config.strategyConfig.rsiExitEnabled,
          signalStrengthExitEnabled: agenticTradingProvider
              .config.strategyConfig.signalStrengthExitEnabled,
          gexExitEnabled:
              agenticTradingProvider.config.strategyConfig.gexExitEnabled,
          exitStages: agenticTradingProvider.config.strategyConfig.exitStages,
          onTrailingStopChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(trailingStopEnabled: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onTimeBasedExitChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(timeBasedExitEnabled: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onMarketCloseExitChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(marketCloseExitEnabled: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onPartialExitsChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enablePartialExits: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onRsiExitChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(rsiExitEnabled: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onSignalStrengthExitChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(signalStrengthExitEnabled: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onGexExitChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(gexExitEnabled: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onExitStagesChanged: (stages) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(exitStages: stages)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          enableGexStructuralStops: agenticTradingProvider
              .config.strategyConfig.enableGexStructuralStops,
          enableTrailingPeakStop: agenticTradingProvider
              .config.strategyConfig.enableTrailingPeakStop,
          trailingPeakStopPercentController: _trailingPeakStopPercentController,
          enableTimeThetaStop:
              agenticTradingProvider.config.strategyConfig.enableTimeThetaStop,
          minDteStopDaysController: _minDteStopDaysController,
          stalledSessionsStopLimitController:
              _stalledSessionsStopLimitController,
          enableMacroRegimeStop: agenticTradingProvider
              .config.strategyConfig.enableMacroRegimeStop,
          enableCatastrophicStop: agenticTradingProvider
              .config.strategyConfig.enableCatastrophicStop,
          catastrophicStopPercentController: _catastrophicStopPercentController,
          onGexStructuralStopsChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableGexStructuralStops: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onTrailingPeakStopChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableTrailingPeakStop: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onTimeThetaStopChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableTimeThetaStop: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onMacroRegimeStopChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableMacroRegimeStop: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onCatastrophicStopChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enableCatastrophicStop: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          dynamicAtrStopsEnabled: agenticTradingProvider
              .config.strategyConfig.dynamicAtrStopsEnabled,
          atrStopMultiplierController: _atrStopMultiplierController,
          atrProfitMultiplierController: _atrProfitMultiplierController,
          atrRatchetEnabled:
              agenticTradingProvider.config.strategyConfig.atrRatchetEnabled,
          onDynamicAtrStopsChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(dynamicAtrStopsEnabled: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onAtrRatchetChanged: (val) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(atrRatchetEnabled: val)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onSettingsChanged: _saveSettings,
        ),
      ],
    );
  }

  Widget _buildEntryStrategies(
      BuildContext context, AgenticTradingProvider agenticTradingProvider,
      {bool initiallyExpanded = false, Key? key}) {
    return _buildSection(
      key: key,
      context: context,
      title: 'Entry Strategies',
      icon: Icons.show_chart,
      initiallyExpanded: initiallyExpanded,
      children: [
        EntryStrategiesWidget(
          requireAllIndicatorsGreen: agenticTradingProvider
              .config.strategyConfig.requireAllIndicatorsGreen,
          onRequireStrictEntryChanged: (value) {
            if (value) {
              _minSignalStrengthController.text = '100';
            }
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(requireAllIndicatorsGreen: value)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          minSignalStrengthController: _minSignalStrengthController,
          enabledIndicators:
              agenticTradingProvider.config.strategyConfig.enabledIndicators,
          indicatorReasons:
              agenticTradingProvider.config.strategyConfig.indicatorReasons,
          onToggleIndicator: (key, value) {
            final currentIndicators = Map<String, bool>.from(
                agenticTradingProvider.config.strategyConfig.enabledIndicators);
            currentIndicators[key] = value;
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enabledIndicators: currentIndicators)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          onToggleAllIndicators: () {
            final currentIndicators = Map<String, bool>.from(
                agenticTradingProvider.config.strategyConfig.enabledIndicators);
            final allEnabled = currentIndicators.values.every((e) => e);
            for (var key in currentIndicators.keys) {
              currentIndicators[key] = !allEnabled;
            }
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config.copyWith(
                    strategyConfig: agenticTradingProvider.config.strategyConfig
                        .copyWith(enabledIndicators: currentIndicators)));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          rocPeriodController: _rocPeriodController,
          rsiPeriodController: _rsiPeriodController,
          smaFastController: _smaFastController,
          smaSlowController: _smaSlowController,
          marketIndexController: _marketIndexController,
          customIndicators:
              agenticTradingProvider.config.strategyConfig.customIndicators,
          onAddCustomIndicator: _addCustomIndicator,
          onEditCustomIndicator: _editCustomIndicator,
          onRemoveCustomIndicator: _removeCustomIndicator,
        ),
      ],
    );
  }

  Widget _buildNotificationSettings(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    return _buildSection(
      context: context,
      title: 'Notifications',
      icon: Icons.notifications,
      children: [
        _buildSwitchListTile(
          'notifyOnBuy',
          'Notify on Buy Orders',
          'Get notified when auto-trade executes a buy',
          agenticTradingProvider,
          value: agenticTradingProvider.config.notifyOnBuy,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig:
                    agenticTradingProvider.config.copyWith(notifyOnBuy: value));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
        ),
        _buildSwitchListTile(
          'notifyOnTakeProfit',
          'Notify on Take Profit',
          'Get notified when take profit target is hit',
          agenticTradingProvider,
          value: agenticTradingProvider.config.notifyOnTakeProfit,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config
                    .copyWith(notifyOnTakeProfit: value));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
        ),
        _buildSwitchListTile(
          'notifyOnStopLoss',
          'Notify on Stop Loss',
          'Get notified when stop loss is triggered',
          agenticTradingProvider,
          value: agenticTradingProvider.config.notifyOnStopLoss,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config
                    .copyWith(notifyOnStopLoss: value));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
        ),
        _buildSwitchListTile(
          'notifyOnEmergencyStop',
          'Notify on Emergency Stop',
          'Get notified when emergency stop is activated',
          agenticTradingProvider,
          value: agenticTradingProvider.config.notifyOnEmergencyStop,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config
                    .copyWith(notifyOnEmergencyStop: value));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
        ),
        _buildSwitchListTile(
          'notifyOnMissedExit',
          'Notify on Missed Market-Close Exit',
          'Get notified when an exit was not confirmed before the market closed',
          agenticTradingProvider,
          value: agenticTradingProvider.config.notifyOnMissedExit,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config
                    .copyWith(notifyOnMissedExit: value));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
        ),
        _buildSwitchListTile(
          'notifyDailySummary',
          'Daily Summary',
          'Receive end-of-day trading summary',
          agenticTradingProvider,
          defaultValue: false,
          value: agenticTradingProvider.config.notifyDailySummary,
          onChanged: (value) {
            final newConfig = _createFullConfigFromSettings(
                agenticTradingProvider,
                baseConfig: agenticTradingProvider.config
                    .copyWith(notifyDailySummary: value));
            agenticTradingProvider.updateConfig(newConfig, widget.userDocRef);
          },
          extraContent: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  agenticTradingProvider.sendDailySummary(widget.userDocRef);
                },
                icon: const Icon(Icons.summarize, size: 18),
                label: const Text('Send Daily Summary Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              title: const Text('Trade Signal Alerts',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              subtitle: const Text('Configure push notifications for signals',
                  style: TextStyle(fontSize: 13)),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.notifications_active,
                    color: Theme.of(context).colorScheme.primary, size: 20),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TradeSignalNotificationSettingsWidget(
                      user: widget.user,
                      userDocRef: widget.userDocRef,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBacktesting(
      BuildContext context, AgenticTradingProvider agenticTradingProvider) {
    final colorScheme = Theme.of(context).colorScheme;
    return _buildSection(
      context: context,
      title: 'Backtesting',
      icon: Icons.history_edu_rounded,
      children: [
        Text(
          'Test your current configuration against historical data to verify strategy performance.',
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () {
              // Create config from current settings
              final config =
                  _createFullConfigFromSettings(agenticTradingProvider);
              final brokerageUserStore =
                  Provider.of<BrokerageUserStore>(context, listen: false);
              final brokerageUser = brokerageUserStore.items.isNotEmpty
                  ? brokerageUserStore
                      .items[brokerageUserStore.currentUserIndex]
                  : null;

              if (brokerageUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please log in for signal search.')),
                );
                return;
              }

              final initialIndicators = config
                  .strategyConfig.enabledIndicators.entries
                  .where((e) => e.value)
                  .fold<Map<String, String>>({}, (prev, element) {
                prev[element.key] = "BUY";
                return prev;
              });

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TradeSignalsPage(
                    user: widget.user,
                    userDocRef: widget.userDocRef,
                    brokerageUser: brokerageUser,
                    service: widget.service,
                    analytics: MyApp.analytics,
                    observer: MyApp.observer,
                    generativeService: GenerativeService(),
                    initialIndicators: initialIndicators,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.search, size: 20),
            label: const Text('Search Matching Signals'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              // Create config from current settings
              final config =
                  _createFullConfigFromSettings(agenticTradingProvider);
              final brokerageUserStore =
                  Provider.of<BrokerageUserStore>(context, listen: false);
              final brokerageUser = brokerageUserStore.items.isNotEmpty
                  ? brokerageUserStore
                      .items[brokerageUserStore.currentUserIndex]
                  : null;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BacktestingWidget(
                    user: widget.user,
                    userDocRef: widget.userDocRef,
                    brokerageUser: brokerageUser,
                    service: widget.service,
                    prefilledConfig: config,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Run Backtest with Current Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    Key? key,
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
    Widget? subtitle,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      key: key,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      color: colorScheme.surface,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          backgroundColor: colorScheme.surfaceContainer.withValues(alpha: 0.2),
          collapsedBackgroundColor:
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
          shape: const Border.fromBorderSide(BorderSide.none),
          collapsedShape: const Border.fromBorderSide(BorderSide.none),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: subtitle,
          childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: children,
        ),
      ),
    );
  }

  void _showLastExecutionDetails(
      BuildContext context, AgenticTradingProvider provider) {
    if (provider.lastAutoTradeResult == null) return;

    final result = provider.lastAutoTradeResult!;
    final isSuccess = result['success'] == true;
    final colorScheme = Theme.of(context).colorScheme;

    DateTime? executionTime;
    if (result.containsKey('timestamp')) {
      final ts = result['timestamp'];
      if (ts is String) {
        executionTime = DateTime.tryParse(ts);
      } else if (ts is int) {
        executionTime = DateTime.fromMillisecondsSinceEpoch(ts);
      }
    }
    executionTime ??= DateTime.now();
    final message = result['message']?.toString() ?? 'No message';
    final isNoAction = !isSuccess &&
        (message.contains('No trades executed') ||
            message.contains('No BUY signals') ||
            message.contains('No signals'));
    final trades = result['trades'] is List ? result['trades'] as List : [];
    final signals = (result['processedSignals'] is List &&
            (result['processedSignals'] as List).isNotEmpty)
        ? (result['processedSignals'] as List)
        : provider.signalProcessingHistory.take(20).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Last Execution',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSuccess
                    ? Colors.green.withValues(alpha: 0.1)
                    : (isNoAction
                        ? Colors.orange.withValues(alpha: 0.1)
                        : colorScheme.error.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSuccess
                      ? Colors.green.withValues(alpha: 0.3)
                      : (isNoAction
                          ? Colors.orange.withValues(alpha: 0.3)
                          : colorScheme.error.withValues(alpha: 0.3)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSuccess
                            ? Icons.check_circle
                            : (isNoAction
                                ? Icons.info_outline
                                : Icons.error_outline),
                        size: 20,
                        color: isSuccess
                            ? Colors.green
                            : (isNoAction ? Colors.orange : colorScheme.error),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isSuccess
                            ? 'Success'
                            : (isNoAction ? 'No Action' : 'Failed'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSuccess
                              ? Colors.green
                              : (isNoAction
                                  ? Colors.orange
                                  : colorScheme.error),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatTime(executionTime!),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (trades.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Executed Trades',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...trades.map((trade) {
                final symbol = trade['symbol'] ?? 'Unknown';
                final side = trade['side'] ?? 'Unknown';
                final quantity = trade['quantity'] ?? 0;
                final price = trade['price'];
                final reason = trade['reason'] as String?;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: colorScheme.surfaceContainer,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: side.toString().toLowerCase() == 'buy'
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        side.toString().substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: side.toString().toLowerCase() == 'buy'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                    title: Text('$quantity $symbol'),
                    subtitle: (price != null || reason != null)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (price != null)
                                Text('@ \$${price.toString()}'),
                              if (reason != null)
                                Text(
                                  reason,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          )
                        : null,
                  ),
                );
              }),
            ],
            if (trades.isEmpty && provider.autoTradeHistory.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Last Recorded Trade',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final trade = provider.autoTradeHistory.first;
                final symbol = trade['symbol'] ?? 'Unknown';
                final side = trade['action'] ?? 'Unknown';
                final quantity = trade['quantity'] ?? 0;
                final price = trade['price'];
                final reason = trade['rejectionReason'] as String? ??
                    (trade['paperMode'] == true ? 'Paper Trade' : null);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: colorScheme.surfaceContainer,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: side.toString().toLowerCase() == 'buy'
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        (side.toString().isNotEmpty
                                ? side.toString().substring(0, 1)
                                : '?')
                            .toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: side.toString().toLowerCase() == 'buy'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ),
                    title: Text('$quantity $symbol'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (price != null) Text('@ \$${price.toString()}'),
                        if (trade['timestamp'] != null)
                          Text(
                            _formatTime(DateTime.tryParse(trade['timestamp']) ??
                                DateTime.now()),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if (reason != null)
                          Text(
                            reason,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            if (signals.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Processed Signals',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...signals.map((s) {
                final symbol = s['symbol'] as String? ?? "Unknown";
                final strength =
                    s['multiIndicatorResult']?['signalStrength'] as int?;
                final isAccepted = s['processedStatus'] == 'Accepted';
                final isRetrying = s['processedStatus'] == 'Retry';
                final rejectionReason = s['rejectionReason'] as String?;
                final optimization = s['optimization'] as Map<String, dynamic>?;
                final price = s['currentPrice'];
                final timestamp = s['timestamp'] as int?;

                return Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isAccepted
                                  ? Icons.check_circle
                                  : isRetrying
                                      ? Icons.schedule
                                      : Icons.cancel,
                              color: isAccepted
                                  ? Colors.green
                                  : isRetrying
                                      ? Colors.orange
                                      : Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              symbol,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (price != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '\$${price.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (strength != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (strength >= 80
                                          ? Colors.green
                                          : (strength >= 60
                                              ? Colors.orange
                                              : Colors.red))
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '$strength%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: strength >= 80
                                        ? Colors.green
                                        : (strength >= 60
                                            ? Colors.orange
                                            : Colors.red),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (rejectionReason != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              rejectionReason,
                              style: TextStyle(
                                color: isRetrying
                                    ? Colors.orange
                                    : colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          )
                        else if (isAccepted)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Signal accepted',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        if (optimization != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer
                                    .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.auto_awesome,
                                          size: 12, color: colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'AI Optimization',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${optimization['refinedSignal']} (${optimization['confidenceScore']}%)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  if (optimization['reasoning'] != null)
                                    Text(
                                      optimization['reasoning'],
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (timestamp != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              DateFormat('MMM d, h:mm a').format(
                                  DateTime.fromMillisecondsSinceEpoch(
                                      timestamp)),
                              style: TextStyle(
                                fontSize: 10,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildModeDetailItem(IconData icon, String title, String description) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              size: 14, color: colorScheme.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/main.dart';
import 'package:robinhood_options_mobile/model/investor_group.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';

/// Widget for configuring copy trade settings for a member in an investor group
class CopyTradeSettingsWidget extends StatefulWidget {
  final InvestorGroup group;
  final FirestoreService firestoreService;

  const CopyTradeSettingsWidget({
    super.key,
    required this.group,
    required this.firestoreService,
  });

  @override
  State<CopyTradeSettingsWidget> createState() =>
      _CopyTradeSettingsWidgetState();
}

class _CopyTradeSettingsWidgetState extends State<CopyTradeSettingsWidget> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  CopyTradeSettings? _settings;
  String? _selectedTargetUserId;
  final _copyPercentageController = TextEditingController();
  final _maxQuantityController = TextEditingController();
  final _maxAmountController = TextEditingController();
  final _maxDailyAmountController = TextEditingController();
  final _symbolWhitelistController = TextEditingController();
  final _symbolBlacklistController = TextEditingController();
  // final _sectorWhitelistController = TextEditingController();
  final _minMarketCapController = TextEditingController();
  final _maxMarketCapController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _stopLossAdjustmentController = TextEditingController();
  final _takeProfitAdjustmentController = TextEditingController();

  final List<String> _availableSectors = [
    'Technology',
    'Health Care',
    'Financials',
    'Consumer Discretionary',
    'Communication Services',
    'Industrials',
    'Consumer Staples',
    'Energy',
    'Utilities',
    'Real Estate',
    'Materials',
  ];
  List<String> _selectedSectors = [];

  final List<String> _availableAssetClasses = ['equity', 'option', 'crypto'];
  List<String> _selectedAssetClasses = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _copyPercentageController.dispose();
    _maxQuantityController.dispose();
    _maxAmountController.dispose();
    _maxDailyAmountController.dispose();
    _symbolWhitelistController.dispose();
    _symbolBlacklistController.dispose();
    // _sectorWhitelistController.dispose();
    _minMarketCapController.dispose();
    _maxMarketCapController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _stopLossAdjustmentController.dispose();
    _takeProfitAdjustmentController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    if (auth.currentUser != null) {
      final settings = widget.group.getCopyTradeSettings(auth.currentUser!.uid);
      if (settings != null) {
        setState(() {
          _settings = settings;
          _selectedTargetUserId = settings.targetUserId;
          if (settings.copyPercentage != null) {
            _copyPercentageController.text = settings.copyPercentage.toString();
          }
          if (settings.maxQuantity != null) {
            _maxQuantityController.text = settings.maxQuantity.toString();
          }
          if (settings.maxAmount != null) {
            _maxAmountController.text = settings.maxAmount.toString();
          }
          if (settings.maxDailyAmount != null) {
            _maxDailyAmountController.text = settings.maxDailyAmount.toString();
          }
          if (settings.symbolWhitelist != null) {
            _symbolWhitelistController.text =
                settings.symbolWhitelist!.join(', ');
          }
          if (settings.symbolBlacklist != null) {
            _symbolBlacklistController.text =
                settings.symbolBlacklist!.join(', ');
          }
          if (settings.sectorWhitelist != null) {
            _selectedSectors = List.from(settings.sectorWhitelist!);
            // _sectorWhitelistController.text = _selectedSectors.join(', ');
          }
          if (settings.assetClassWhitelist != null) {
            _selectedAssetClasses = List.from(settings.assetClassWhitelist!);
          }
          if (settings.minMarketCap != null) {
            _minMarketCapController.text =
                (settings.minMarketCap! / 1000000).toStringAsFixed(2);
          }
          if (settings.maxMarketCap != null) {
            _maxMarketCapController.text =
                (settings.maxMarketCap! / 1000000).toStringAsFixed(2);
          }
          if (settings.startTime != null) {
            _startTimeController.text = settings.startTime!;
          }
          if (settings.endTime != null) {
            _endTimeController.text = settings.endTime!;
          }
          if (settings.stopLossAdjustment != null) {
            _stopLossAdjustmentController.text =
                settings.stopLossAdjustment.toString();
          }
          if (settings.takeProfitAdjustment != null) {
            _takeProfitAdjustmentController.text =
                settings.takeProfitAdjustment.toString();
          }
        });
      } else {
        setState(() {
          _settings = CopyTradeSettings();
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    if (auth.currentUser == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final settings = CopyTradeSettings(
        enabled: _settings!.enabled,
        targetUserId: _selectedTargetUserId,
        autoExecute: _settings!.autoExecute,
        copyPercentage: _copyPercentageController.text.isNotEmpty
            ? double.tryParse(_copyPercentageController.text)
            : null,
        maxQuantity: _maxQuantityController.text.isNotEmpty
            ? double.tryParse(_maxQuantityController.text)
            : null,
        maxAmount: _maxAmountController.text.isNotEmpty
            ? double.tryParse(_maxAmountController.text)
            : null,
        maxDailyAmount: _maxDailyAmountController.text.isNotEmpty
            ? double.tryParse(_maxDailyAmountController.text)
            : null,
        overridePrice: _settings!.overridePrice,
        symbolWhitelist: _symbolWhitelistController.text.isNotEmpty
            ? _symbolWhitelistController.text
                .split(',')
                .map((e) => e.trim().toUpperCase())
                .where((e) => e.isNotEmpty)
                .toList()
            : null,
        symbolBlacklist: _symbolBlacklistController.text.isNotEmpty
            ? _symbolBlacklistController.text
                .split(',')
                .map((e) => e.trim().toUpperCase())
                .where((e) => e.isNotEmpty)
                .toList()
            : null,
        sectorWhitelist: _selectedSectors.isNotEmpty ? _selectedSectors : null,
        assetClassWhitelist:
            _selectedAssetClasses.isNotEmpty ? _selectedAssetClasses : null,
        minMarketCap: _minMarketCapController.text.isNotEmpty
            ? double.tryParse(_minMarketCapController.text)! * 1000000
            : null,
        maxMarketCap: _maxMarketCapController.text.isNotEmpty
            ? double.tryParse(_maxMarketCapController.text)! * 1000000
            : null,
        startTime: _startTimeController.text.isNotEmpty
            ? _startTimeController.text
            : null,
        endTime:
            _endTimeController.text.isNotEmpty ? _endTimeController.text : null,
        copyStopLoss: _settings!.copyStopLoss,
        copyTakeProfit: _settings!.copyTakeProfit,
        copyTrailingStop: _settings!.copyTrailingStop,
        stopLossAdjustment: _stopLossAdjustmentController.text.isNotEmpty
            ? double.tryParse(_stopLossAdjustmentController.text)
            : null,
        takeProfitAdjustment: _takeProfitAdjustmentController.text.isNotEmpty
            ? double.tryParse(_takeProfitAdjustmentController.text)
            : null,
      );

      widget.group.setCopyTradeSettings(auth.currentUser!.uid, settings);
      await widget.firestoreService.updateInvestorGroup(widget.group);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copy trade settings saved!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_settings == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Copy Trade Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Get list of eligible members to copy from (exclude self)
    final eligibleMembers = widget.group.members
        .where((memberId) => memberId != auth.currentUser?.uid)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Copy Trade Settings'),
        actions: [
          if (_settings != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Revert Changes',
              onPressed: _loadSettings,
            ),
        ],
      ),
      floatingActionButton: _settings?.enabled == true
          ? FloatingActionButton.extended(
              onPressed: _isLoading || _selectedTargetUserId == null
                  ? null
                  : _saveSettings,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Settings'),
            )
          : null,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Copy Trading',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Automatically or manually copy trades from other members in this group.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Enable Copy Trading'),
                      subtitle: const Text('Copy trades from a group member'),
                      value: _settings!.enabled,
                      onChanged: (value) {
                        setState(() {
                          _settings!.enabled = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (_settings!.enabled) ...[
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Copy From',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      if (eligibleMembers.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 48,
                                  color: Theme.of(context).disabledColor,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No other members in this group',
                                  style: TextStyle(
                                    color: Theme.of(context).disabledColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...eligibleMembers.map((memberId) {
                          return FutureBuilder(
                            future: widget.firestoreService.userCollection
                                .doc(memberId)
                                .get(),
                            builder: (context, snapshot) {
                              String displayName = 'User';
                              Widget avatar = const CircleAvatar(
                                radius: 20,
                                child: Icon(Icons.account_circle),
                              );

                              if (snapshot.hasData && snapshot.data!.exists) {
                                final user = snapshot.data!.data();
                                displayName = user?.name ??
                                    // user?.providerId?.capitalize() ??
                                    'Guest';
                                if (user?.photoUrl != null) {
                                  avatar = CircleAvatar(
                                    radius: 20,
                                    backgroundImage: CachedNetworkImageProvider(
                                        user!.photoUrl!),
                                  );
                                }
                              }

                              return RadioListTile<String>(
                                title: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontWeight:
                                        _selectedTargetUserId == memberId
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                                value: memberId,
                                groupValue: _selectedTargetUserId,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedTargetUserId = value;
                                  });
                                },
                                secondary: avatar,
                                activeColor: Theme.of(context).primaryColor,
                                selected: _selectedTargetUserId == memberId,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: _selectedTargetUserId == memberId
                                      ? BorderSide(
                                          color: Theme.of(context).primaryColor,
                                          width: 2,
                                        )
                                      : BorderSide.none,
                                ),
                              );
                            },
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trade Execution',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Auto-Execute Trades'),
                        subtitle: const Text(
                            'Automatically execute trades without confirmation'),
                        value: _settings!.autoExecute,
                        onChanged: _selectedTargetUserId != null
                            ? (value) {
                                setState(() {
                                  _settings!.autoExecute = value;
                                });
                              }
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (time != null) {
                                  setState(() {
                                    _startTimeController.text =
                                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                                  });
                                }
                              },
                              child: IgnorePointer(
                                child: TextField(
                                  controller: _startTimeController,
                                  decoration: InputDecoration(
                                    labelText: 'Start Time',
                                    helperText:
                                        'Start time for trading (HH:mm)',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    prefixIcon: const Icon(Icons.access_time),
                                    suffixIcon: _startTimeController
                                            .text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {
                                              setState(() {
                                                _startTimeController.clear();
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.now(),
                                );
                                if (time != null) {
                                  setState(() {
                                    _endTimeController.text =
                                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                                  });
                                }
                              },
                              child: IgnorePointer(
                                child: TextField(
                                  controller: _endTimeController,
                                  decoration: InputDecoration(
                                    labelText: 'End Time',
                                    helperText: 'End time for trading (HH:mm)',
                                    border: const OutlineInputBorder(),
                                    filled: true,
                                    prefixIcon:
                                        const Icon(Icons.access_time_filled),
                                    suffixIcon:
                                        _endTimeController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear),
                                                onPressed: () {
                                                  setState(() {
                                                    _endTimeController.clear();
                                                  });
                                                },
                                              )
                                            : null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Exit Strategy',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Copy Stop Loss'),
                        subtitle:
                            const Text('Automatically copy stop loss orders'),
                        value: _settings!.copyStopLoss ?? false,
                        onChanged: (value) {
                          setState(() {
                            _settings!.copyStopLoss = value;
                          });
                        },
                      ),
                      if (_settings!.copyStopLoss ?? false)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextFormField(
                            controller: _stopLossAdjustmentController,
                            decoration: const InputDecoration(
                              labelText: 'Stop Loss Adjustment (%)',
                              helperText:
                                  'Negative to tighten, positive to loosen',
                              border: OutlineInputBorder(),
                              suffixText: '%',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true, decimal: true),
                          ),
                        ),
                      SwitchListTile(
                        title: const Text('Copy Take Profit'),
                        subtitle:
                            const Text('Automatically copy take profit orders'),
                        value: _settings!.copyTakeProfit ?? false,
                        onChanged: (value) {
                          setState(() {
                            _settings!.copyTakeProfit = value;
                          });
                        },
                      ),
                      if (_settings!.copyTakeProfit ?? false)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextFormField(
                            controller: _takeProfitAdjustmentController,
                            decoration: const InputDecoration(
                              labelText: 'Take Profit Adjustment (%)',
                              helperText:
                                  'Positive to increase, negative to decrease',
                              border: OutlineInputBorder(),
                              suffixText: '%',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                signed: true, decimal: true),
                          ),
                        ),
                      SwitchListTile(
                        title: const Text('Trailing Stop'),
                        subtitle: const Text('Copy trailing stop orders'),
                        value: _settings!.copyTrailingStop ?? false,
                        onChanged: (value) {
                          setState(() {
                            _settings!.copyTrailingStop = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trade Limits',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('copyPercentageField'),
                        controller: _copyPercentageController,
                        decoration: const InputDecoration(
                          labelText: 'Copy Percentage (optional)',
                          helperText:
                              'Percentage of original trade size to copy (e.g. 50 for 50%)',
                          border: OutlineInputBorder(),
                          filled: true,
                          prefixIcon: Icon(Icons.percent),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        onChanged: (value) {
                          setState(() {});
                        },
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final n = double.tryParse(value);
                            if (n == null) return 'Invalid number';
                            if (n < 0 || n > 100) {
                              return 'Percentage must be between 0 and 100';
                            }
                          }
                          return null;
                        },
                      ),
                      if (_copyPercentageController.text.isNotEmpty &&
                          double.tryParse(_copyPercentageController.text) !=
                              null)
                        Slider(
                          value: double.tryParse(_copyPercentageController.text)
                                  ?.clamp(0.0, 100.0) ??
                              0,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label: _copyPercentageController.text,
                          onChanged: (value) {
                            setState(() {
                              _copyPercentageController.text =
                                  value.toInt().toString();
                            });
                          },
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _maxQuantityController,
                        decoration: const InputDecoration(
                          labelText: 'Max Quantity (optional)',
                          helperText:
                              'Maximum quantity of shares/contracts to copy',
                          border: OutlineInputBorder(),
                          filled: true,
                          prefixIcon: Icon(Icons.numbers),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _maxAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Max Amount (optional)',
                          helperText: 'Maximum dollar amount per trade',
                          border: OutlineInputBorder(),
                          filled: true,
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _maxDailyAmountController,
                        decoration: const InputDecoration(
                          labelText: 'Max Daily Amount (optional)',
                          helperText: 'Maximum total dollar amount per day',
                          border: OutlineInputBorder(),
                          filled: true,
                          prefixIcon: Icon(Icons.attach_money),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: Row(
                          children: [
                            const Text('Override Price'),
                            const SizedBox(width: 8),
                            Tooltip(
                              message:
                                  'If enabled, trades will be executed at the current market price instead of the price specified in the original order.',
                              child: Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        subtitle: const Text(
                            'Use current market price instead of copied price'),
                        value: _settings!.overridePrice ?? false,
                        onChanged: (value) {
                          setState(() {
                            _settings!.overridePrice = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  title: Text(
                    'Advanced Filtering',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _symbolWhitelistController,
                            decoration: const InputDecoration(
                              labelText: 'Symbol Whitelist',
                              helperText:
                                  'Comma separated list of symbols to allow',
                              border: OutlineInputBorder(),
                              filled: true,
                              prefixIcon: Icon(Icons.check_circle_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _symbolBlacklistController,
                            decoration: const InputDecoration(
                              labelText: 'Symbol Blacklist',
                              helperText:
                                  'Comma separated list of symbols to block',
                              border: OutlineInputBorder(),
                              filled: true,
                              prefixIcon: Icon(Icons.block),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Asset Class Whitelist',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: _availableAssetClasses.map((assetClass) {
                              return FilterChip(
                                label: Text(assetClass.capitalize()),
                                selected:
                                    _selectedAssetClasses.contains(assetClass),
                                onSelected: (bool selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedAssetClasses.add(assetClass);
                                    } else {
                                      _selectedAssetClasses.remove(assetClass);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sector Whitelist',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 4.0,
                            children: _availableSectors.map((sector) {
                              return FilterChip(
                                label: Text(sector),
                                selected: _selectedSectors.contains(sector),
                                onSelected: (bool selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedSectors.add(sector);
                                    } else {
                                      _selectedSectors.remove(sector);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _minMarketCapController,
                                  decoration: const InputDecoration(
                                    labelText: 'Min Market Cap',
                                    helperText:
                                        'Minimum market cap (in millions)',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    prefixIcon: Icon(Icons.trending_up),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d+\.?\d{0,2}')),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _maxMarketCapController,
                                  decoration: const InputDecoration(
                                    labelText: 'Max Market Cap',
                                    helperText:
                                        'Maximum market cap (in millions)',
                                    border: OutlineInputBorder(),
                                    filled: true,
                                    prefixIcon: Icon(Icons.trending_down),
                                  ),
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d+\.?\d{0,2}')),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

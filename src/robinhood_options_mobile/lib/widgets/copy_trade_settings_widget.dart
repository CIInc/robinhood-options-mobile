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
  bool _isLoading = false;
  CopyTradeSettings? _settings;
  String? _selectedTargetUserId;
  final _copyPercentageController = TextEditingController();
  final _maxQuantityController = TextEditingController();
  final _maxAmountController = TextEditingController();
  final _maxDailyAmountController = TextEditingController();

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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Copy Trading',
                    style: Theme.of(context).textTheme.titleLarge,
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Copy From',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (eligibleMembers.isEmpty)
                      const Text('No other members in this group')
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
                                  user?.providerId?.capitalize() ??
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
                              title: Text(displayName),
                              value: memberId,
                              groupValue: _selectedTargetUserId,
                              onChanged: (value) {
                                setState(() {
                                  _selectedTargetUserId = value;
                                });
                              },
                              secondary: avatar,
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trade Execution',
                      style: Theme.of(context).textTheme.titleMedium,
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trade Limits',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _copyPercentageController,
                      decoration: const InputDecoration(
                        labelText: 'Copy Percentage (optional)',
                        helperText:
                            'Percentage of original trade size to copy (e.g. 50 for 50%)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.percent),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _maxQuantityController,
                      decoration: const InputDecoration(
                        labelText: 'Max Quantity (optional)',
                        helperText:
                            'Maximum quantity of shares/contracts to copy',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _maxAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Max Amount (optional)',
                        helperText: 'Maximum dollar amount per trade',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _maxDailyAmountController,
                      decoration: const InputDecoration(
                        labelText: 'Max Daily Amount (optional)',
                        helperText: 'Maximum total dollar amount per day',
                        border: OutlineInputBorder(),
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
                      title: const Text('Override Price'),
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading || _selectedTargetUserId == null
                    ? null
                    : _saveSettings,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Save Settings'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

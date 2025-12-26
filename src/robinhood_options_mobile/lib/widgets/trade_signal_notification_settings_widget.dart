import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/trade_signal_notification_settings.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Widget for configuring trade signal notification preferences
class TradeSignalNotificationSettingsWidget extends StatefulWidget {
  final User user;
  final DocumentReference<User> userDocRef;

  const TradeSignalNotificationSettingsWidget({
    super.key,
    required this.user,
    required this.userDocRef,
  });

  @override
  State<TradeSignalNotificationSettingsWidget> createState() =>
      _TradeSignalNotificationSettingsWidgetState();
}

class _TradeSignalNotificationSettingsWidgetState
    extends State<TradeSignalNotificationSettingsWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  late TradeSignalNotificationSettings _settings;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _settings = widget.user.tradeSignalNotificationSettings ??
          TradeSignalNotificationSettings();
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final updatedUser = widget.user;
      updatedUser.tradeSignalNotificationSettings = _settings;

      await _firestoreService.updateUser(widget.userDocRef, updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification settings saved successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trade Signal Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Revert Changes',
            onPressed: _loadSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveSettings,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.save),
        label: const Text('Save'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
        children: [
          // Enable/Disable notifications
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle:
                const Text('Receive push notifications for trade signals'),
            value: _settings.enabled,
            onChanged: (value) {
              setState(() {
                _settings = _settings.copyWith(enabled: value);
              });
            },
          ),
          const Divider(),

          // Signal types
          _buildSectionHeader('Signal Types'),
          _buildChipSelector(
            'Notify for signals:',
            ['BUY', 'SELL'],
            _settings.signalTypes,
            (selectedTypes) {
              setState(() {
                _settings = _settings.copyWith(signalTypes: selectedTypes);
              });
            },
          ),
          CheckboxListTile(
            title: const Text('Include HOLD signals'),
            value: _settings.includeHold,
            onChanged: _settings.enabled
                ? (value) {
                    setState(() {
                      _settings =
                          _settings.copyWith(includeHold: value ?? false);
                    });
                  }
                : null,
          ),
          const Divider(),

          // Intervals
          _buildSectionHeader('Intervals'),
          _buildChipSelector(
            'Notify for intervals (empty = all):',
            ['1d', '1h', '30m', '15m'],
            _settings.intervals,
            (selectedIntervals) {
              setState(() {
                _settings = _settings.copyWith(intervals: selectedIntervals);
              });
            },
            multiSelect: true,
          ),
          const Divider(),

          // Symbol filter
          _buildSectionHeader('Symbol Filter'),
          ListTile(
            title: const Text('Specific symbols'),
            subtitle: _settings.symbols.isEmpty
                ? const Text('All symbols (tap to add specific symbols)')
                : Wrap(
                    spacing: 8.0,
                    children: _settings.symbols
                        .map((symbol) => Chip(
                              label: Text(symbol),
                              onDeleted: _settings.enabled
                                  ? () {
                                      setState(() {
                                        final symbols = List<String>.from(
                                            _settings.symbols);
                                        symbols.remove(symbol);
                                        _settings = _settings.copyWith(
                                            symbols: symbols);
                                      });
                                    }
                                  : null,
                            ))
                        .toList(),
                  ),
            trailing: _settings.enabled
                ? IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _showAddSymbolDialog(),
                  )
                : null,
          ),
          const Divider(),

          // Confidence threshold
          _buildSectionHeader('Confidence Threshold'),
          ListTile(
            title: Text(
                'Minimum confidence: ${_settings.minConfidence != null ? "${(_settings.minConfidence! * 100).toInt()}%" : "None"}'),
            subtitle: Slider(
              value: _settings.minConfidence ?? 0.0,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              label: _settings.minConfidence != null
                  ? '${(_settings.minConfidence! * 100).toInt()}%'
                  : 'None',
              onChanged: _settings.enabled
                  ? (value) {
                      setState(() {
                        _settings = _settings.copyWith(
                            minConfidence: value > 0 ? value : null);
                      });
                    }
                  : null,
            ),
          ),
          if (_settings.minConfidence != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Only notify if signal confidence is above ${(_settings.minConfidence! * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
      ),
    );
  }

  Widget _buildChipSelector(
    String label,
    List<String> options,
    List<String> selected,
    Function(List<String>) onChanged, {
    bool multiSelect = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            children: options.map((option) {
              final isSelected = selected.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: _settings.enabled
                    ? (bool value) {
                        List<String> newSelected;
                        if (multiSelect) {
                          newSelected = List<String>.from(selected);
                          if (value) {
                            newSelected.add(option);
                          } else {
                            newSelected.remove(option);
                          }
                        } else {
                          if (value) {
                            newSelected = List<String>.from(selected);
                            if (!newSelected.contains(option)) {
                              newSelected.add(option);
                            }
                          } else {
                            newSelected = List<String>.from(selected);
                            newSelected.remove(option);
                          }
                        }
                        onChanged(newSelected);
                      }
                    : null,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddSymbolDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Symbol'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Symbol',
            hintText: 'e.g., AAPL',
          ),
          textCapitalization: TextCapitalization.characters,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        final symbols = List<String>.from(_settings.symbols);
        if (!symbols.contains(result.toUpperCase())) {
          symbols.add(result.toUpperCase());
          _settings = _settings.copyWith(symbols: symbols);
        }
      });
    }
  }
}

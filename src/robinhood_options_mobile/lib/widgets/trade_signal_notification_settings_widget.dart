import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:robinhood_options_mobile/model/trade_signal_notifications_store.dart';
import 'package:robinhood_options_mobile/widgets/trade_signal_notifications_page.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/model/trade_signal_notification_settings.dart';
import 'package:robinhood_options_mobile/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Widget for configuring trade signal notification preferences
class TradeSignalNotificationSettingsWidget extends StatefulWidget {
  final User user;
  final DocumentReference<User> userDocRef;
  final bool hideNotificationIcon;

  const TradeSignalNotificationSettingsWidget({
    super.key,
    required this.user,
    required this.userDocRef,
    this.hideNotificationIcon = false,
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
          if (!widget.hideNotificationIcon)
            Consumer<TradeSignalNotificationsStore>(
              builder: (context, store, child) {
                return IconButton(
                  icon: Badge(
                    label: Text(store.unreadCount > 99
                        ? '99+'
                        : store.unreadCount.toString()),
                    isLabelVisible: store.unreadCount > 0,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  tooltip: 'Notification History',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TradeSignalNotificationsPage(
                          user: widget.user,
                          userDocRef: widget.userDocRef,
                          fromSettings: true,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
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
            null,
            ['BUY', 'SELL', 'HOLD'],
            [
              ..._settings.signalTypes,
              if (_settings.includeHold) 'HOLD',
            ],
            (selectedTypes) {
              setState(() {
                _settings = _settings.copyWith(
                  signalTypes: selectedTypes.where((t) => t != 'HOLD').toList(),
                  includeHold: selectedTypes.contains('HOLD'),
                );
              });
            },
            multiSelect: true,
          ),
          const Divider(),

          // Intervals
          _buildSectionHeader('Intervals'),
          _buildChipSelector(
            '(Select none for all)',
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                ..._settings.symbols.map((symbol) => Chip(
                      label: Text(symbol),
                      onDeleted: _settings.enabled
                          ? () {
                              setState(() {
                                final symbols =
                                    List<String>.from(_settings.symbols);
                                symbols.remove(symbol);
                                _settings =
                                    _settings.copyWith(symbols: symbols);
                              });
                            }
                          : null,
                    )),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Add Symbol'),
                  onPressed: _settings.enabled ? _showAddSymbolDialog : null,
                ),
              ],
            ),
          ),
          if (_settings.symbols.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 16.0, top: 4.0, bottom: 8.0),
              child: Text('Not filtering by symbol (All symbols will notify)',
                  style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                      fontSize: 12)),
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
              divisions: 100,
              activeColor:
                  (_settings.minConfidence ?? 0) > 0.8 ? Colors.green : null,
              thumbColor:
                  (_settings.minConfidence ?? 0) > 0.8 ? Colors.green : null,
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
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.notifications_active),
              label: const Text('Send Test Notification'),
              onPressed: _sendTestNotification,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const String imageUrl =
        'https://charts2.finviz.com/chart.ashx?t=SPY&ty=c&ta=0&p=d&s=l';
    BigPictureStyleInformation? bigPictureStyleInformation;

    try {
      final http.Response response = await http.get(Uri.parse(imageUrl));
      final Directory directory = await getTemporaryDirectory();
      final String filePath = '${directory.path}/test_notification_img.jpg';
      final File file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      bigPictureStyleInformation = BigPictureStyleInformation(
          FilePathAndroidBitmap(filePath),
          largeIcon: FilePathAndroidBitmap(filePath),
          contentTitle: '🟢 BUY SPY @ \$450.00',
          summaryText: 'Daily • 95% Conf.\n🥵 RSI: 72 • 📉 MACD: 1.25',
          htmlFormatContentTitle: true,
          htmlFormatSummaryText: true);
    } catch (e) {
      debugPrint('Error loading test notification image: $e');
    }

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'trade_signals',
      'Trade Signals',
      channelDescription: 'Notifications for trade signals',
      styleInformation: bigPictureStyleInformation,
      importance: Importance.max,
      priority: Priority.high,
    );

    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      id: 999, // Test ID
      title: '🟢 BUY SPY @ \$450.00',
      body: 'Daily • 95% Conf.\n🥵 RSI: 72 • 📉 MACD: 1.25',
      notificationDetails: platformChannelSpecifics,
      payload: jsonEncode({
        'type': 'trade_signal',
        'symbol': 'SPY',
        'signal': 'BUY',
        'interval': '1d'
      }),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
    String? label,
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
          if (label != null && label.isNotEmpty) ...[
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 8.0,
            children: options.map((option) {
              final isSelected = selected.contains(option);

              // Custom styling for signal types
              Color? selectedColor;
              Color? labelColor;
              Widget? avatar;

              if (option == 'BUY') {
                selectedColor = Colors.green.withOpacity(0.2);
                labelColor = Colors.green;
                avatar = const Icon(Icons.arrow_upward,
                    size: 16, color: Colors.green);
              } else if (option == 'SELL') {
                selectedColor = Colors.red.withOpacity(0.2);
                labelColor = Colors.red;
                avatar = const Icon(Icons.arrow_downward,
                    size: 16, color: Colors.red);
              } else if (option == 'HOLD') {
                selectedColor = Colors.orange.withOpacity(0.2);
                labelColor = Colors.orange;
                avatar =
                    const Icon(Icons.pause, size: 16, color: Colors.orange);
              } else if (option == '1d') {
                avatar = const Icon(Icons.calendar_today, size: 16);
              } else if (['1h', '30m', '15m'].contains(option)) {
                avatar = const Icon(Icons.access_time, size: 16);
              }

              String labelText = option;
              if (option == '1d')
                labelText = 'Daily';
              else if (option == '1h')
                labelText = 'Hourly';
              else if (option == '30m')
                labelText = '30 Min';
              else if (option == '15m') labelText = '15 Min';

              return FilterChip(
                label: Text(
                  labelText,
                  style: isSelected && labelColor != null
                      ? TextStyle(
                          color: labelColor, fontWeight: FontWeight.bold)
                      : null,
                ),
                avatar: isSelected ? avatar : null,
                selected: isSelected,
                showCheckmark: avatar == null,
                selectedColor: selectedColor,
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

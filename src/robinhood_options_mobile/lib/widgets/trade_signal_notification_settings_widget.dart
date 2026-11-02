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
  final FirestoreService? firestoreService;

  const TradeSignalNotificationSettingsWidget({
    super.key,
    required this.user,
    required this.userDocRef,
    this.hideNotificationIcon = false,
    this.firestoreService,
  });

  @override
  State<TradeSignalNotificationSettingsWidget> createState() =>
      _TradeSignalNotificationSettingsWidgetState();
}

class _TradeSignalNotificationSettingsWidgetState
    extends State<TradeSignalNotificationSettingsWidget> {
  late final FirestoreService _firestoreService =
      widget.firestoreService ?? FirestoreService();
  late TradeSignalNotificationSettings _settings;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _webhookController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _webhookController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _webhookController.dispose();
    super.dispose();
  }

  void _loadSettings() {
    setState(() {
      _settings = widget.user.tradeSignalNotificationSettings ??
          TradeSignalNotificationSettings();
      _emailController.text = _settings.emailAddress ?? '';
      _phoneController.text = _settings.phoneNumber ?? '';
      _webhookController.text = _settings.webhookUrl ?? '';
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final emailTrimmed = _emailController.text.trim();
      final phoneTrimmed = _phoneController.text.trim();
      final webhookTrimmed = _webhookController.text.trim();
      _settings = _settings.copyWith(
        emailAddress: emailTrimmed.isEmpty ? null : emailTrimmed,
        phoneNumber: phoneTrimmed.isEmpty ? null : phoneTrimmed,
        webhookUrl: webhookTrimmed.isEmpty ? null : webhookTrimmed,
      );

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

  String _formatHour(int hour24) {
    final normalized = hour24 % 24;
    if (normalized == 0) return '12:00 AM';
    if (normalized == 12) return '12:00 PM';
    if (normalized < 12) return '$normalized:00 AM';
    return '${normalized - 12}:00 PM';
  }

  String _channelLabel(String channel) {
    switch (channel) {
      case 'push':
        return 'Push';
      case 'in_app':
        return 'In-App';
      case 'email':
        return 'Email';
      case 'sms':
        return 'SMS';
      case 'webhook':
        return 'Webhook';
      default:
        return channel.toUpperCase();
    }
  }

  IconData _channelIcon(String channel) {
    switch (channel) {
      case 'push':
        return Icons.notifications_active_outlined;
      case 'in_app':
        return Icons.inbox_outlined;
      case 'email':
        return Icons.email_outlined;
      case 'sms':
        return Icons.sms_outlined;
      case 'webhook':
        return Icons.webhook_outlined;
      default:
        return Icons.notifications;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'critical':
        return 'Critical (Time-Sensitive)';
      case 'high':
        return 'High Priority';
      case 'standard':
        return 'Standard';
      case 'low':
        return 'Low / Silent Digest';
      default:
        return priority;
    }
  }

  String _soundLabel(String sound) {
    switch (sound) {
      case 'default':
        return 'System Default';
      case 'chime':
        return 'Crystal Chime';
      case 'bell':
        return 'Trading Bell';
      case 'pulse':
        return 'Gamma Pulse';
      case 'radar':
        return 'Flow Radar';
      case 'silent':
        return 'Silent';
      default:
        return sound;
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
          SwitchListTile(
            title: const Text('Macro Assessment Alerts'),
            subtitle:
                const Text('Notify on Market Regime shifts & Macro changes'),
            value: _settings.macroAlerts,
            onChanged: _settings.enabled
                ? (value) {
                    setState(() {
                      _settings = _settings.copyWith(macroAlerts: value);
                    });
                  }
                : null,
          ),
          const Divider(),

          // Multi-Channel Delivery
          _buildSectionHeader('Delivery Channels'),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children:
                  TradeSignalNotificationSettings.availableChannels.map((ch) {
                final isSelected = _settings.deliveryChannels.contains(ch);
                return FilterChip(
                  avatar: Icon(_channelIcon(ch), size: 16),
                  label: Text(_channelLabel(ch)),
                  selected: isSelected,
                  showCheckmark: false,
                  onSelected: _settings.enabled
                      ? (selected) {
                          setState(() {
                            final updated =
                                List<String>.from(_settings.deliveryChannels);
                            if (selected) {
                              if (!updated.contains(ch)) updated.add(ch);
                            } else if (updated.length > 1) {
                              updated.remove(ch);
                            }
                            _settings =
                                _settings.copyWith(deliveryChannels: updated);
                          });
                        }
                      : null,
                );
              }).toList(),
            ),
          ),
          if (_settings.deliveryChannels.contains('email'))
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: TextField(
                controller: _emailController,
                enabled: _settings.enabled,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'alerts@example.com',
                  prefixIcon: Icon(Icons.email_outlined),
                  isDense: true,
                ),
                onChanged: (val) {
                  _settings = _settings.copyWith(
                    emailAddress: val.trim().isEmpty ? null : val.trim(),
                  );
                },
              ),
            ),
          if (_settings.deliveryChannels.contains('sms'))
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: TextField(
                controller: _phoneController,
                enabled: _settings.enabled,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'SMS Phone Number',
                  hintText: '+1 (555) 012-3456',
                  prefixIcon: Icon(Icons.sms_outlined),
                  isDense: true,
                ),
                onChanged: (val) {
                  _settings = _settings.copyWith(
                    phoneNumber: val.trim().isEmpty ? null : val.trim(),
                  );
                },
              ),
            ),
          if (_settings.deliveryChannels.contains('webhook'))
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: TextField(
                controller: _webhookController,
                enabled: _settings.enabled,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Webhook URL (Discord / Slack / Custom)',
                  hintText: 'https://hooks.example.com/services/...',
                  prefixIcon: Icon(Icons.webhook_outlined),
                  isDense: true,
                ),
                onChanged: (val) {
                  _settings = _settings.copyWith(
                    webhookUrl: val.trim().isEmpty ? null : val.trim(),
                  );
                },
              ),
            ),
          if (_settings.deliveryChannels.contains('email') ||
              _settings.deliveryChannels.contains('sms') ||
              _settings.deliveryChannels.contains('webhook'))
            SwitchListTile(
              title: const Text('Critical-Only External Routing'),
              subtitle: const Text(
                  'Only send Email/SMS/Webhook for Critical priority or >=80% confidence alerts'),
              value: _settings.criticalOnlyExternalChannels,
              onChanged: _settings.enabled
                  ? (value) {
                      setState(() {
                        _settings = _settings.copyWith(
                          criticalOnlyExternalChannels: value,
                        );
                      });
                    }
                  : null,
            ),
          const Divider(),

          // Sound, Priority & Quiet Hours
          _buildSectionHeader('Alert Customization & Priority'),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: DropdownButtonFormField<String>(
              initialValue: _settings.priorityChannel,
              decoration: const InputDecoration(
                labelText: 'Notification Priority Channel',
                prefixIcon: Icon(Icons.priority_high),
              ),
              items: TradeSignalNotificationSettings.availablePriorities
                  .map(
                    (p) => DropdownMenuItem(
                      value: p,
                      child: Text(_priorityLabel(p)),
                    ),
                  )
                  .toList(),
              onChanged: _settings.enabled
                  ? (val) {
                      if (val != null) {
                        setState(() {
                          _settings = _settings.copyWith(priorityChannel: val);
                        });
                      }
                    }
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: DropdownButtonFormField<String>(
              initialValue: _settings.alertSound,
              decoration: const InputDecoration(
                labelText: 'Default Alert Sound',
                prefixIcon: Icon(Icons.volume_up_outlined),
              ),
              items: TradeSignalNotificationSettings.availableSounds
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(_soundLabel(s)),
                    ),
                  )
                  .toList(),
              onChanged: _settings.enabled
                  ? (val) {
                      if (val != null) {
                        setState(() {
                          _settings = _settings.copyWith(alertSound: val);
                        });
                      }
                    }
                  : null,
            ),
          ),
          SwitchListTile(
            title: const Text('Vibrate on Alert'),
            subtitle: const Text('Haptic vibration for incoming notifications'),
            value: _settings.vibrate,
            onChanged: _settings.enabled
                ? (value) {
                    setState(() {
                      _settings = _settings.copyWith(vibrate: value);
                    });
                  }
                : null,
          ),
          ExpansionTile(
            title: const Text('Per-Signal Sound Overrides'),
            subtitle: const Text(
                'Assign distinct tones to BUY, SELL, GEX, and Options Flow'),
            childrenPadding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            children: ['BUY', 'SELL', 'GEX', 'FLOW'].map((category) {
              final currentOverride = _settings.signalSoundOverrides[category];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: DropdownButtonFormField<String>(
                  initialValue: currentOverride ?? '',
                  decoration: InputDecoration(
                    labelText: '$category Signal Sound',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('Use Default Sound'),
                    ),
                    ...TradeSignalNotificationSettings.availableSounds.map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(_soundLabel(s)),
                      ),
                    ),
                  ],
                  onChanged: _settings.enabled
                      ? (val) {
                          setState(() {
                            final overrides = Map<String, String>.from(
                              _settings.signalSoundOverrides,
                            );
                            if (val == null || val.isEmpty) {
                              overrides.remove(category);
                            } else {
                              overrides[category] = val;
                            }
                            _settings = _settings.copyWith(
                              signalSoundOverrides: overrides,
                            );
                          });
                        }
                      : null,
                ),
              );
            }).toList(),
          ),
          SwitchListTile(
            title: const Text('Quiet Hours (Do Not Disturb)'),
            subtitle: Text(
              _settings.quietHoursEnabled
                  ? 'Active from ${_formatHour(_settings.quietHoursStartHour)} to ${_formatHour(_settings.quietHoursEndHour)}'
                  : 'Suppress non-critical push and SMS alerts overnight',
            ),
            value: _settings.quietHoursEnabled,
            onChanged: _settings.enabled
                ? (value) {
                    setState(() {
                      _settings = _settings.copyWith(quietHoursEnabled: value);
                    });
                  }
                : null,
          ),
          if (_settings.quietHoursEnabled) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _settings.quietHoursStartHour,
                      decoration: const InputDecoration(
                        labelText: 'Start Hour',
                        isDense: true,
                      ),
                      items: List.generate(
                        24,
                        (h) => DropdownMenuItem(
                          value: h,
                          child: Text(_formatHour(h)),
                        ),
                      ),
                      onChanged: _settings.enabled
                          ? (val) {
                              if (val != null) {
                                setState(() {
                                  _settings = _settings.copyWith(
                                    quietHoursStartHour: val,
                                  );
                                });
                              }
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _settings.quietHoursEndHour,
                      decoration: const InputDecoration(
                        labelText: 'End Hour',
                        isDense: true,
                      ),
                      items: List.generate(
                        24,
                        (h) => DropdownMenuItem(
                          value: h,
                          child: Text(_formatHour(h)),
                        ),
                      ),
                      onChanged: _settings.enabled
                          ? (val) {
                              if (val != null) {
                                setState(() {
                                  _settings = _settings.copyWith(
                                    quietHoursEndHour: val,
                                  );
                                });
                              }
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('Bypass Quiet Hours for Critical Alerts'),
              subtitle: const Text(
                  'Deliver critical priority & emergency risk alerts immediately'),
              value: _settings.bypassQuietHoursForCritical,
              onChanged: _settings.enabled
                  ? (value) {
                      setState(() {
                        _settings = _settings.copyWith(
                          bypassQuietHoursForCritical: value,
                        );
                      });
                    }
                  : null,
            ),
          ],
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

          // Granular Per-Signal & Category Triggers
          _buildSectionHeader('Per-Signal & Category Triggers'),
          SwitchListTile(
            title: const Text('Price & Technical Breakout Triggers'),
            subtitle: const Text(
                'Notify on price action, moving average, and momentum breakouts'),
            value: _settings.priceTriggerEnabled,
            onChanged: _settings.enabled
                ? (value) {
                    setState(() {
                      _settings =
                          _settings.copyWith(priceTriggerEnabled: value);
                    });
                  }
                : null,
          ),
          SwitchListTile(
            title: const Text('GEX Regime & Wall Triggers'),
            subtitle: const Text(
                'Notify on Call/Put Wall breaches, Gamma Flips, and 0DTE Squeeze alerts'),
            value: _settings.gexTriggerEnabled,
            onChanged: _settings.enabled
                ? (value) {
                    setState(() {
                      _settings = _settings.copyWith(gexTriggerEnabled: value);
                    });
                  }
                : null,
          ),
          SwitchListTile(
            title: const Text('Options Flow Triggers'),
            subtitle: const Text(
                'Notify on Whale sweeps, Golden Sweeps, and unusual institutional flow'),
            value: _settings.optionsFlowTriggerEnabled,
            onChanged: _settings.enabled
                ? (value) {
                    setState(() {
                      _settings = _settings.copyWith(
                        optionsFlowTriggerEnabled: value,
                      );
                    });
                  }
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 4.0),
            child: Text(
              'Required Indicator Triggers (Select none to allow any indicator)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 6.0,
              children: TradeSignalNotificationSettings.availableIndicators
                  .map((ind) {
                final isSelected = _settings.requiredIndicators.contains(ind);
                final label = TradeSignalNotificationSettings
                        .indicatorDisplayNames[ind] ??
                    ind;
                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: _settings.enabled
                      ? (selected) {
                          setState(() {
                            final updated =
                                List<String>.from(_settings.requiredIndicators);
                            if (selected) {
                              if (!updated.contains(ind)) updated.add(ind);
                            } else {
                              updated.remove(ind);
                            }
                            _settings = _settings.copyWith(
                              requiredIndicators: updated,
                            );
                          });
                        }
                      : null,
                );
              }).toList(),
            ),
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

    final channelId = _settings.androidChannelId;
    final playSound = _settings.soundForCategory('BUY') != 'silent' &&
        _settings.priorityChannel != 'low';

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId,
      _priorityLabel(_settings.priorityChannel),
      channelDescription: 'Notifications for trade signals',
      styleInformation: bigPictureStyleInformation,
      importance:
          _settings.priorityChannel == 'low' ? Importance.low : Importance.max,
      priority:
          _settings.priorityChannel == 'low' ? Priority.low : Priority.high,
      playSound: playSound,
      enableVibration: _settings.vibrate,
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
        'interval': '1d',
        'channelId': channelId,
        'priority': _settings.priorityChannel,
        'sound': _settings.soundForCategory('BUY'),
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
              if (option == '1d') {
                labelText = 'Daily';
              } else if (option == '1h')
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

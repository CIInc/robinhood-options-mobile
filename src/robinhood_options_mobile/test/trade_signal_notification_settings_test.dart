import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/option_flow_alert.dart';
import 'package:robinhood_options_mobile/model/trade_signal_notification_settings.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/widgets/trade_signal_notification_settings_widget.dart';

void main() {
  group('TradeSignalNotificationSettings model tests', () {
    test('defaults and androidChannelId resolution', () {
      final settings = TradeSignalNotificationSettings();
      expect(settings.enabled, true);
      expect(settings.deliveryChannels, ['push', 'in_app']);
      expect(settings.priorityChannel, 'high');
      expect(settings.alertSound, 'default');
      expect(settings.vibrate, true);
      expect(settings.criticalOnlyExternalChannels, true);
      expect(settings.quietHoursEnabled, false);
      expect(settings.quietHoursStartHour, 22);
      expect(settings.quietHoursEndHour, 7);
      expect(settings.bypassQuietHoursForCritical, true);
      expect(settings.priceTriggerEnabled, true);
      expect(settings.gexTriggerEnabled, true);
      expect(settings.optionsFlowTriggerEnabled, true);
      expect(settings.requiredIndicators, isEmpty);
      expect(settings.androidChannelId, 'trade_signals');

      final criticalSettings = settings.copyWith(priorityChannel: 'critical');
      expect(criticalSettings.androidChannelId, 'critical_alerts');

      final silentSettings = settings.copyWith(alertSound: 'silent');
      expect(silentSettings.androidChannelId, 'silent_digest');
    });

    test('fromJson, toJson, and soundForCategory round-trip', () {
      final original = TradeSignalNotificationSettings(
        enabled: true,
        signalTypes: const ['BUY'],
        symbols: const ['AAPL', 'NVDA'],
        intervals: const ['1d', '1h'],
        includeHold: false,
        minConfidence: 0.75,
        deliveryChannels: const ['push', 'in_app', 'email', 'sms', 'webhook'],
        emailAddress: 'trader@example.com',
        phoneNumber: '+15551234567',
        webhookUrl: 'https://hooks.slack.com/services/T00/B00/X00',
        criticalOnlyExternalChannels: true,
        priorityChannel: 'critical',
        alertSound: 'chime',
        vibrate: false,
        signalSoundOverrides: const {'BUY': 'pulse', 'GEX': 'radar'},
        quietHoursEnabled: true,
        quietHoursStartHour: 23,
        quietHoursEndHour: 6,
        bypassQuietHoursForCritical: true,
        requiredIndicators: const ['rsi', 'macd', 'gex'],
        priceTriggerEnabled: true,
        gexTriggerEnabled: true,
        optionsFlowTriggerEnabled: false,
      );

      final json = original.toJson();
      final decoded = TradeSignalNotificationSettings.fromJson(json);

      expect(decoded.deliveryChannels,
          ['push', 'in_app', 'email', 'sms', 'webhook']);
      expect(decoded.emailAddress, 'trader@example.com');
      expect(decoded.phoneNumber, '+15551234567');
      expect(
          decoded.webhookUrl, 'https://hooks.slack.com/services/T00/B00/X00');
      expect(decoded.priorityChannel, 'critical');
      expect(decoded.alertSound, 'chime');
      expect(decoded.vibrate, false);
      expect(decoded.soundForCategory('BUY'), 'pulse');
      expect(decoded.soundForCategory('GEX'), 'radar');
      expect(decoded.soundForCategory('SELL'), 'chime');
      expect(decoded.quietHoursEnabled, true);
      expect(decoded.quietHoursStartHour, 23);
      expect(decoded.quietHoursEndHour, 6);
      expect(decoded.requiredIndicators, ['rsi', 'macd', 'gex']);
      expect(decoded.optionsFlowTriggerEnabled, false);
    });
  });

  group('OptionFlowAlert customization fields', () {
    test('serializes and deserializes priority, sound, and channels', () {
      final alert = OptionFlowAlert(
        id: 'flow-1',
        uid: 'u-1',
        symbol: 'TSLA',
        minPremium: 100000,
        sentiment: 'bullish',
        condition: 'above',
        expirationRange: '0-7',
        flags: const ['SWEEP', 'WHALE'],
        createdAt: DateTime(2026, 8, 27),
        isActive: true,
        priority: 'critical',
        sound: 'bell',
        channels: const ['push', 'in_app', 'sms'],
      );

      final map = alert.toMap();
      expect(map['priority'], 'critical');
      expect(map['sound'], 'bell');
      expect(map['channels'], ['push', 'in_app', 'sms']);

      final restored = OptionFlowAlert.fromMap('flow-1', map);
      expect(restored.priority, 'critical');
      expect(restored.sound, 'bell');
      expect(restored.channels, ['push', 'in_app', 'sms']);
    });
  });

  group('TradeSignalNotificationSettingsWidget UI tests', () {
    testWidgets(
        'renders multi-channel, priority, sound, and indicator controls',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firestore = FakeFirebaseFirestore();
      final userDocRef =
          firestore.collection('user').doc('test-user').withConverter<User>(
                fromFirestore: (snapshot, _) =>
                    User.fromJson(snapshot.data() ?? <String, Object?>{}),
                toFirestore: (user, _) => user.toJson(),
              );
      final user = User(
        name: 'Test Trader',
        email: 'trader@example.com',
        devices: [],
        dateCreated: DateTime(2026, 8, 27),
        brokerageUsers: [],
        tradeSignalNotificationSettings: TradeSignalNotificationSettings(
          enabled: true,
          deliveryChannels: const ['push', 'in_app', 'email'],
          emailAddress: 'trader@example.com',
          priorityChannel: 'critical',
          alertSound: 'radar',
          quietHoursEnabled: true,
          requiredIndicators: const ['rsi', 'gex'],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TradeSignalNotificationSettingsWidget(
            user: user,
            userDocRef: userDocRef,
            hideNotificationIcon: true,
          ),
        ),
      );

      expect(find.text('Delivery Channels'), findsOneWidget);
      expect(find.text('Push'), findsOneWidget);
      expect(find.text('In-App'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('SMS'), findsOneWidget);
      expect(find.text('Webhook'), findsOneWidget);
      expect(find.text('Critical-Only External Routing'), findsOneWidget);
      expect(find.text('Alert Customization & Priority'), findsOneWidget);
      expect(find.text('Quiet Hours (Do Not Disturb)'), findsOneWidget);
      expect(
          find.text('Bypass Quiet Hours for Critical Alerts'), findsOneWidget);
      expect(find.text('Per-Signal & Category Triggers'), findsOneWidget);
      expect(find.text('Price & Technical Breakout Triggers'), findsOneWidget);
      expect(find.text('GEX Regime & Wall Triggers'), findsOneWidget);
      expect(find.text('Options Flow Triggers'), findsOneWidget);
      expect(
        find.text(
            'Required Indicator Triggers (Select none to allow any indicator)'),
        findsOneWidget,
      );
      expect(find.text('GEX Regime'), findsOneWidget);
    });
  });
}

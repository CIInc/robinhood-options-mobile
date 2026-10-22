import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/user.dart';
import 'package:robinhood_options_mobile/services/feature_access_service.dart';
import 'package:robinhood_options_mobile/services/remote_config_service.dart';

import 'firebase_mocks.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseMocks();
  });

  group('FeatureAccessService Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('Loads default rollout modes correctly', () {
      final service = FeatureAccessService(
        prefs: prefs,
        remoteConfig: RemoteConfigService.instance,
      );

      expect(service.getRolloutMode(FeatureBundle.advancedResearch),
          FeatureRolloutMode.betaOptIn);
      expect(service.getRolloutMode(FeatureBundle.advancedTrading),
          FeatureRolloutMode.betaOptIn);
      expect(service.getRolloutMode(FeatureBundle.backtesting),
          FeatureRolloutMode.betaOptIn);
      expect(service.getRolloutMode(FeatureBundle.riskGuardrails),
          FeatureRolloutMode.betaOptIn);
      expect(service.getRolloutMode(FeatureBundle.socialCopy),
          FeatureRolloutMode.betaOptIn);
      expect(service.getRolloutMode(FeatureBundle.automatedTrading),
          FeatureRolloutMode.betaOptIn);
    });

    test('Public mode is enabled by default for all users', () {
      final service = FeatureAccessService(
        prefs: prefs,
        remoteConfig: RemoteConfigService.instance,
        overrideModes: {
          FeatureBundle.socialCopy: FeatureRolloutMode.public,
        },
      );

      expect(
          service.isFeatureEnabled(FeatureBundle.socialCopy,
              userRole: UserRole.user),
          isTrue);
      expect(service.isFeatureEnabled(FeatureBundle.socialCopy, userRole: null),
          isTrue);
    });

    test('Disabled mode acts as a remote kill switch for regular users', () {
      final service = FeatureAccessService(
        prefs: prefs,
        remoteConfig: RemoteConfigService.instance,
        overrideModes: {
          FeatureBundle.advancedTrading: FeatureRolloutMode.disabled,
        },
      );

      // Even if user opted in locally, remote kill switch takes precedence
      service.setUserOptIn(FeatureBundle.advancedTrading, true);
      expect(
          service.isFeatureEnabled(FeatureBundle.advancedTrading,
              userRole: UserRole.user),
          isFalse);
    });

    test('Beta features are disabled by default even for admins, only public enabled by default', () async {
      final service = FeatureAccessService(
        prefs: prefs,
        remoteConfig: RemoteConfigService.instance,
        overrideModes: {
          FeatureBundle.automatedTrading: FeatureRolloutMode.disabled,
          FeatureBundle.advancedTrading: FeatureRolloutMode.betaOptIn,
          FeatureBundle.investorGroups: FeatureRolloutMode.public,
          FeatureBundle.accountTools: FeatureRolloutMode.adminOnly,
        },
      );

      // Disabled mode is off for everyone including admins
      expect(
          service.isFeatureEnabled(FeatureBundle.automatedTrading,
              userRole: UserRole.admin),
          isFalse);

      // Beta features are disabled by default even for admins
      expect(
          service.isFeatureEnabled(FeatureBundle.advancedTrading,
              userRole: UserRole.admin),
          isFalse);

      // Public features are enabled by default
      expect(
          service.isFeatureEnabled(FeatureBundle.investorGroups,
              userRole: UserRole.admin),
          isTrue);

      // AdminOnly features: non-admins cannot access, admins can access when opted in
      expect(
          service.isFeatureEnabled(FeatureBundle.accountTools,
              userRole: UserRole.user),
          isFalse);
      expect(
          service.isFeatureEnabled(FeatureBundle.accountTools,
              userRole: UserRole.admin),
          isFalse); // disabled by default until opted in

      // When admin opts in, it is enabled
      await service.setUserPreference(FeatureBundle.accountTools, true);
      expect(
          service.isFeatureEnabled(FeatureBundle.accountTools,
              userRole: UserRole.admin),
          isTrue);
      await service.setUserPreference(FeatureBundle.accountTools, false);
    });

    test('Beta opt-in requires explicit user opt-in', () async {
      final service = FeatureAccessService(
        prefs: prefs,
        remoteConfig: RemoteConfigService.instance,
        overrideModes: {
          FeatureBundle.advancedTrading: FeatureRolloutMode.betaOptIn,
        },
      );

      // Initially not enabled
      expect(
          service.isFeatureEnabled(FeatureBundle.advancedTrading,
              userRole: UserRole.user),
          isFalse);

      // User opts in
      await service.setUserOptIn(FeatureBundle.advancedTrading, true);
      expect(service.isUserOptedIn(FeatureBundle.advancedTrading), isTrue);
      expect(
          service.isFeatureEnabled(FeatureBundle.advancedTrading,
              userRole: UserRole.user),
          isTrue);

      // User opts out
      await service.setUserOptIn(FeatureBundle.advancedTrading, false);
      expect(service.isUserOptedIn(FeatureBundle.advancedTrading), isFalse);
      expect(
          service.isFeatureEnabled(FeatureBundle.advancedTrading,
              userRole: UserRole.user),
          isFalse);
    });

    test('Disabling self-serve opt-in blocks user-toggled beta features',
        () async {
      final service = FeatureAccessService(
        prefs: prefs,
        remoteConfig: RemoteConfigService.instance,
        overrideModes: {
          FeatureBundle.advancedTrading: FeatureRolloutMode.betaOptIn,
        },
        overrideSelfOptIn: true,
      );

      await service.setUserOptIn(FeatureBundle.advancedTrading, true);
      expect(
          service.isFeatureEnabled(FeatureBundle.advancedTrading,
              userRole: UserRole.user),
          isTrue);

      // Administrator disables self opt-in remotely
      service.setOverrideSelfOptIn(false);
      expect(service.isSelfOptInEnabled, isFalse);
      expect(
          service.isFeatureEnabled(FeatureBundle.advancedTrading,
              userRole: UserRole.user),
          isFalse);
    });

    test('resetAllOptIns clears all persisted beta choices', () async {
      final service = FeatureAccessService(
        prefs: prefs,
        remoteConfig: RemoteConfigService.instance,
      );

      await service.setUserOptIn(FeatureBundle.advancedResearch, true);
      await service.setUserOptIn(FeatureBundle.advancedTrading, true);
      expect(service.isUserOptedIn(FeatureBundle.advancedResearch), isTrue);
      expect(service.isUserOptedIn(FeatureBundle.advancedTrading), isTrue);

      await service.resetAllOptIns();
      expect(service.isUserOptedIn(FeatureBundle.advancedResearch), isFalse);
      expect(service.isUserOptedIn(FeatureBundle.advancedTrading), isFalse);
    });

    test('Public mode allows user explicit opt-out and opt-back-in', () async {
      final service = FeatureAccessService(
        prefs: prefs,
        remoteConfig: RemoteConfigService.instance,
        overrideModes: {
          FeatureBundle.investorGroups: FeatureRolloutMode.public,
        },
      );

      // Initially enabled by default
      expect(
          service.isFeatureEnabled(FeatureBundle.investorGroups,
              userRole: UserRole.user),
          isTrue);
      expect(service.isUserOptedOut(FeatureBundle.investorGroups), isFalse);

      // User opts out
      await service.setUserPreference(FeatureBundle.investorGroups, false);
      expect(service.isUserOptedOut(FeatureBundle.investorGroups), isTrue);
      expect(
          service.isFeatureEnabled(FeatureBundle.investorGroups,
              userRole: UserRole.user),
          isFalse);

      // User opts back in
      await service.setUserPreference(FeatureBundle.investorGroups, true);
      expect(service.isUserOptedOut(FeatureBundle.investorGroups), isFalse);
      expect(
          service.isFeatureEnabled(FeatureBundle.investorGroups,
              userRole: UserRole.user),
          isTrue);
    });

    test('User document cloud featureFlags override takes precedence', () {
      final service = FeatureAccessService(
        prefs: prefs,
        remoteConfig: RemoteConfigService.instance,
        overrideModes: {
          FeatureBundle.investorGroups: FeatureRolloutMode.public,
          FeatureBundle.agenticTrading: FeatureRolloutMode.adminOnly,
        },
      );

      final testUser = User(
        email: 'w6mn6vvv5y@privaterelay.appleid.com',
        devices: const [],
        dateCreated: DateTime(2026, 1, 1),
        brokerageUsers: const [],
        featureFlags: {
          'investorGroups': false, // Explicit opt-out in Firestore
          'agenticTrading': true, // Granted in Firestore
        },
      );

      // Public feature turned off by cloud preference
      expect(
          service.isFeatureEnabled(FeatureBundle.investorGroups,
              userRole: UserRole.user, user: testUser),
          isFalse);

      // AdminOnly feature explicitly granted in user cloud doc
      expect(
          service.isFeatureEnabled(FeatureBundle.agenticTrading,
              userRole: UserRole.user, user: testUser),
          isTrue);
    });

    test(
        'setUserPreference and resetAllOptIns update in-memory User and Firestore across auth providers',
        () async {
      final firestore = FakeFirebaseFirestore();
      final usersCollection = firestore.collection('users').withConverter<User>(
            fromFirestore: (snapshot, _) => User.fromJson(snapshot.data()!),
            toFirestore: (user, _) => user.toJson(),
          );

      final authProviders = [
        {'id': 'phone_user', 'provider': 'phone', 'phone': '+15551234567'},
        {'id': 'google_user', 'provider': 'google.com', 'email': 'g@test.com'},
        {'id': 'apple_user', 'provider': 'apple.com', 'email': 'a@test.com'},
        {'id': 'email_user', 'provider': 'password', 'email': 'e@test.com'},
        {'id': 'anon_user', 'provider': 'anonymous'},
      ];

      for (final providerInfo in authProviders) {
        final userId = providerInfo['id']!;
        final docRef = usersCollection.doc(userId);

        final user = User(
          name: 'Test ${providerInfo['provider']}',
          phoneNumber: providerInfo['phone'],
          email: providerInfo['email'],
          providerId: providerInfo['provider'],
          devices: const [],
          dateCreated: DateTime(2026, 1, 1),
          brokerageUsers: const [],
          featureFlags: null, // Initially null
        );

        await docRef.set(user);

        final service = FeatureAccessService(
          prefs: prefs,
          remoteConfig: RemoteConfigService.instance,
          overrideModes: {
            FeatureBundle.advancedTrading: FeatureRolloutMode.betaOptIn,
          },
          overrideSelfOptIn: true,
        );

        // Initially disabled
        expect(
          service.isFeatureEnabled(FeatureBundle.advancedTrading,
              userRole: UserRole.user, user: user),
          isFalse,
        );

        // Opt in with user and docRef
        await service.setUserPreference(
          FeatureBundle.advancedTrading,
          true,
          user: user,
          userDocRef: docRef,
        );

        // Verify in-memory user is updated immediately
        expect(user.featureFlags, isNotNull);
        expect(user.featureFlags![FeatureBundle.advancedTrading.name], isTrue);
        expect(
          service.isFeatureEnabled(FeatureBundle.advancedTrading,
              userRole: UserRole.user, user: user),
          isTrue,
        );

        // Verify Firestore was updated
        final updatedDoc = await docRef.get();
        expect(updatedDoc.data()?.featureFlags?['advancedTrading'], isTrue);

        // Reset opt-ins
        await service.resetAllOptIns(user: user, userDocRef: docRef);

        expect(user.featureFlags, isEmpty);
        final resetDoc = await docRef.get();
        expect(resetDoc.data()?.featureFlags, isEmpty);
      }
    });
  });
}

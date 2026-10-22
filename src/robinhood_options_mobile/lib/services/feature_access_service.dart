import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../enums.dart';
import '../model/user.dart';
import 'remote_config_service.dart';

/// Central service managing feature flags, Remote Config rollout states,
/// admin overrides, and user self-serve beta opt-ins ("Beta Labs").
class FeatureAccessService extends ChangeNotifier {
  final SharedPreferences? _prefs;
  final RemoteConfigService? _remoteConfig;
  Map<FeatureBundle, FeatureRolloutMode>? _overrideModes;
  bool? _overrideSelfOptIn;

  FeatureAccessService({
    SharedPreferences? prefs,
    RemoteConfigService? remoteConfig,
    Map<FeatureBundle, FeatureRolloutMode>? overrideModes,
    bool? overrideSelfOptIn,
  })  : _prefs = prefs,
        _remoteConfig = remoteConfig,
        _overrideModes = overrideModes,
        _overrideSelfOptIn = overrideSelfOptIn;

  static FeatureAccessService? _instance;
  static FeatureAccessService get instance =>
      _instance ??= FeatureAccessService();

  @visibleForTesting
  static set mockInstance(FeatureAccessService service) => _instance = service;

  static Future<FeatureAccessService> initialize({
    SharedPreferences? prefs,
    RemoteConfigService? remoteConfig,
  }) async {
    final preferences = prefs ?? await SharedPreferences.getInstance();
    final service = FeatureAccessService(
      prefs: preferences,
      remoteConfig: remoteConfig ?? RemoteConfigService.instance,
    );
    _instance = service;
    return service;
  }

  RemoteConfigService get remoteConfig =>
      _remoteConfig ?? RemoteConfigService.instance;

  static const Map<FeatureBundle, FeatureRolloutMode> defaultModes = {
    FeatureBundle.advancedResearch: FeatureRolloutMode.betaOptIn,
    FeatureBundle.aiResearch: FeatureRolloutMode.betaOptIn,
    FeatureBundle.advancedTrading: FeatureRolloutMode.betaOptIn,
    FeatureBundle.backtesting: FeatureRolloutMode.betaOptIn,
    FeatureBundle.riskGuardrails: FeatureRolloutMode.betaOptIn,
    FeatureBundle.socialCopy: FeatureRolloutMode.betaOptIn,
    FeatureBundle.investorGroups: FeatureRolloutMode.public,
    FeatureBundle.accountTools: FeatureRolloutMode.betaOptIn,
    FeatureBundle.extendedBrokerages: FeatureRolloutMode.betaOptIn,
    FeatureBundle.automatedTrading: FeatureRolloutMode.betaOptIn,
    FeatureBundle.agenticTrading: FeatureRolloutMode.betaOptIn,
    FeatureBundle.macroIntelligence: FeatureRolloutMode.public,
  };

  /// Whether the user-facing "Beta Labs" opt-in panel is enabled.
  bool get isSelfOptInEnabled {
    final overrideSelf = _overrideSelfOptIn;
    if (overrideSelf != null) return overrideSelf;
    try {
      return remoteConfig.isBetaSelfOptInEnabled;
    } catch (_) {
      return true;
    }
  }

  /// Sets an override for whether self-serve beta opt-in is allowed (testing).
  @visibleForTesting
  void setOverrideSelfOptIn(bool? enabled) {
    _overrideSelfOptIn = enabled;
    notifyListeners();
  }

  /// Sets an override rollout mode for a bundle (testing).
  @visibleForTesting
  void overrideRolloutForTesting(
      FeatureBundle bundle, FeatureRolloutMode mode) {
    _overrideModes ??= {};
    _overrideModes![bundle] = mode;
    notifyListeners();
  }

  /// Clears test overrides.
  @visibleForTesting
  void clearOverridesForTesting() {
    _overrideModes = null;
    _overrideSelfOptIn = null;
    notifyListeners();
  }

  /// Returns the current Remote Config rollout mode for [bundle].
  FeatureRolloutMode getRolloutMode(FeatureBundle bundle) {
    final overrideModes = _overrideModes;
    if (overrideModes != null && overrideModes.containsKey(bundle)) {
      return overrideModes[bundle]!;
    }
    try {
      final raw = remoteConfig.getFeatureRollout(bundle.remoteConfigKey);
      if (raw.isEmpty) {
        return defaultModes[bundle] ?? FeatureRolloutMode.disabled;
      }
      return FeatureRolloutMode.fromString(raw);
    } catch (_) {
      return defaultModes[bundle] ?? FeatureRolloutMode.disabled;
    }
  }

  /// Checks if the current user has explicitly opted out of [bundle] locally.
  bool isUserOptedOut(FeatureBundle bundle) {
    final prefs = _prefs;
    if (prefs == null) return false;
    return prefs.getBool('beta_opt_out_${bundle.name}') ?? false;
  }

  /// Checks if the current user has opted into [bundle] locally.
  bool isUserOptedIn(FeatureBundle bundle) {
    final prefs = _prefs;
    if (prefs == null) return false;
    return prefs.getBool('beta_opt_in_${bundle.name}') ?? false;
  }

  /// Sets the user preference (opt-in or opt-out) for [bundle].
  /// Synchronizes to local SharedPreferences, in-memory [user], and optional Cloud Firestore [userDocRef].
  Future<void> setUserPreference(
    FeatureBundle bundle,
    bool enabled, {
    User? user,
    dynamic userDocRef,
  }) async {
    final prefs = _prefs;
    final mode = getRolloutMode(bundle);

    if (prefs != null) {
      if (mode == FeatureRolloutMode.public) {
        if (!enabled) {
          // User explicitly opts out of a public feature
          await prefs.setBool('beta_opt_out_${bundle.name}', true);
          await prefs.remove('beta_opt_in_${bundle.name}');
        } else {
          // User clears their opt-out
          await prefs.remove('beta_opt_out_${bundle.name}');
        }
      } else {
        if (enabled) {
          await prefs.setBool('beta_opt_in_${bundle.name}', true);
          await prefs.remove('beta_opt_out_${bundle.name}');
        } else {
          await prefs.remove('beta_opt_in_${bundle.name}');
        }
      }
    }

    if (user != null) {
      user.featureFlags ??= {};
      user.featureFlags![bundle.name] = enabled;
    }

    if (userDocRef != null) {
      try {
        if (userDocRef is DocumentReference) {
          await userDocRef.firestore.doc(userDocRef.path).set({
            'featureFlags': {bundle.name: enabled}
          }, SetOptions(merge: true));
        } else {
          await userDocRef.update({'featureFlags.${bundle.name}': enabled});
        }
      } catch (e) {
        debugPrint('Failed to sync feature flag to Firestore: $e');
      }
    }

    notifyListeners();
  }

  /// Alias for backward compatibility with existing callers and tests.
  Future<void> setUserOptIn(
    FeatureBundle bundle,
    bool enabled, {
    User? user,
    dynamic userDocRef,
  }) =>
      setUserPreference(bundle, enabled, user: user, userDocRef: userDocRef);

  /// Resets all local user beta opt-ins and opt-outs.
  Future<void> resetAllOptIns({User? user, dynamic userDocRef}) async {
    final prefs = _prefs;
    if (prefs != null) {
      for (final bundle in FeatureBundle.values) {
        await prefs.remove('beta_opt_in_${bundle.name}');
        await prefs.remove('beta_opt_out_${bundle.name}');
      }
    }
    if (user != null) {
      user.featureFlags?.clear();
    }
    if (userDocRef != null) {
      try {
        if (userDocRef is DocumentReference) {
          await userDocRef.firestore.doc(userDocRef.path).set(
              {'featureFlags': <String, dynamic>{}},
              SetOptions(mergeFields: ['featureFlags']));
        } else {
          await userDocRef.update({'featureFlags': {}});
        }
      } catch (e) {
        debugPrint('Failed to reset feature flags in Firestore: $e');
      }
    }
    notifyListeners();
  }

  /// Evaluates whether [bundle] is available based on:
  /// 1. Remote kill switch: "disabled" forces OFF for everyone.
  /// 2. Admin-only: forces OFF for non-admins. For admins, available via opt-in.
  /// 3. Firestore user document: explicit userDoc override (takes highest precedence for user & admin).
  /// 4. Rollout mode "public": ON by default unless user opted out.
  /// 5. Rollout mode "betaOptIn": OFF by default (even for admins); enabled only if user opted in.
  /// 6. Fail-closed: unhandled / unknown modes default to false.
  bool isFeatureEnabled(
    FeatureBundle bundle, {
    UserRole? userRole,
    User? user,
    bool isAnonymous = false,
  }) {
    // 1. Query Remote Config rollout state
    final mode = getRolloutMode(bundle);

    // Global kill switch
    if (mode == FeatureRolloutMode.disabled) {
      return false;
    }

    // 2. User document cloud override takes highest user-level precedence (including admins and explicit user grants)
    if (user?.featureFlags != null &&
        user!.featureFlags!.containsKey(bundle.name)) {
      return user.featureFlags![bundle.name]!;
    }

    // Admin-only features are inaccessible to non-admins without explicit cloud grant
    if (mode == FeatureRolloutMode.adminOnly && userRole != UserRole.admin) {
      return false;
    }

    // 3. Rollout mode evaluation (all beta features disabled by default; only public enabled by default)
    switch (mode) {
      case FeatureRolloutMode.disabled:
        return false;

      case FeatureRolloutMode.adminOnly:
        return isUserOptedIn(bundle);

      case FeatureRolloutMode.public:
        // Enabled by default unless user explicitly opted out
        return !isUserOptedOut(bundle);

      case FeatureRolloutMode.betaOptIn:
        if (!isSelfOptInEnabled && userRole != UserRole.admin) {
          return false;
        }
        return isUserOptedIn(bundle);
    }
  }
}

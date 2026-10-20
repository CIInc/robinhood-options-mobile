import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig;

  RemoteConfigService({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  static late final RemoteConfigService _instance;
  static RemoteConfigService get instance => _instance;

  @visibleForTesting
  static set mockInstance(RemoteConfigService service) => _instance = service;

  static Future<void> initialize() async {
    _instance = RemoteConfigService();
    await _instance._initConfig();
  }

  Future<void> _initConfig() async {
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(minutes: 1),
      minimumFetchInterval:
          kDebugMode ? const Duration(minutes: 5) : const Duration(hours: 12),
    ));

    await _remoteConfig.setDefaults(const {
      'min_app_version': '0.0.0',
      'ai_model_name': 'gemini-3.1-flash-lite',
      'show_personalized_ads': true,
      'experiment_group': 'default',
      'beta_self_opt_in_enabled': true,
      'beta_advanced_research': 'beta_opt_in',
      'beta_ai_research': 'beta_opt_in',
      'beta_advanced_trading': 'beta_opt_in',
      'beta_backtesting': 'beta_opt_in',
      'beta_risk_guardrails': 'beta_opt_in',
      'beta_automated_trading': 'beta_opt_in',
      'beta_social_copy': 'beta_opt_in',
      'beta_account_tools': 'beta_opt_in',
      'beta_extended_brokerages': 'beta_opt_in',
    });

    try {
      await _remoteConfig.fetchAndActivate();
    } catch (e) {
      debugPrint('Remote config fetch failed: $e');
    }
  }

  String get minAppVersion => _remoteConfig.getString('min_app_version');
  String get aiModelName => _remoteConfig.getString('ai_model_name');
  bool get showPersonalizedAds =>
      _remoteConfig.getBool('show_personalized_ads');
  String get experimentGroup => _remoteConfig.getString('experiment_group');
  bool get isBetaSelfOptInEnabled =>
      _remoteConfig.getBool('beta_self_opt_in_enabled');
  String getFeatureRollout(String key) => _remoteConfig.getString(key);

  bool isUpdateRequired(String currentVersion) {
    if (minAppVersion == '0.0.0') return false;

    // Use try-catch to avoid crashes on version parse errors
    try {
      List<String> current = currentVersion.split('+')[0].split('.');
      List<String> min = minAppVersion.split('.');

      // Pad with zeros if necessary
      while (current.length < 3) {
        current.add('0');
      }
      while (min.length < 3) {
        min.add('0');
      }

      for (int i = 0; i < 3; i++) {
        int currentParam = int.tryParse(current[i]) ?? 0;
        int minParam = int.tryParse(min[i]) ?? 0;
        if (minParam > currentParam) return true;
        if (minParam < currentParam) return false;
      }
    } catch (e) {
      debugPrint('Error parsing version: $e');
    }
    return false;
  }
}

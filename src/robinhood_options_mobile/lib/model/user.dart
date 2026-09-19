import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/extensions.dart';
import 'package:robinhood_options_mobile/model/account.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/device.dart';
import 'package:robinhood_options_mobile/model/investment_profile.dart';
import 'package:robinhood_options_mobile/model/trade_signal_notification_settings.dart';
import 'package:robinhood_options_mobile/model/agentic_trading_config.dart';
import 'package:robinhood_options_mobile/model/futures_strategy_config.dart';
import 'package:robinhood_options_mobile/model/portfolio_privacy_settings.dart';
import 'package:robinhood_options_mobile/model/rebalancing_config.dart';
import 'package:robinhood_options_mobile/model/risk_circuit_breaker_config.dart';

class User {
  String? name;
  String? nameLower;
  String? email;
  String? phoneNumber;
  String? photoUrl;
  String? providerId;
  String? location;
  UserRole role;
  List<Device> devices;
  DateTime dateCreated;
  DateTime? dateUpdated;
  DateTime? lastVisited;
  List<BrokerageUser> brokerageUsers = [];
  bool refreshQuotes;

  List<Account> get allAccounts =>
      brokerageUsers.expand((bu) => bu.accounts).toList();

  // Investment Profile (nested object)
  InvestmentProfile? investmentProfile;

  // Trade Signal Notification Settings
  TradeSignalNotificationSettings? tradeSignalNotificationSettings;

  // Agentic Trading Configuration
  AgenticTradingConfig? agenticTradingConfig;

  // Futures Trading Configuration
  FuturesTradingConfig? futuresTradingConfig;

  // Rebalancing Configuration
  RebalancingConfig? rebalancingConfig;

  // Option Filter Presets
  Map<String, Map<String, dynamic>>? optionFilterPresets;
  String? defaultOptionFilterPreset;

  // Portfolio Allocation Targets
  Map<String, double>? assetAllocationTargets;
  Map<String, double>? sectorAllocationTargets;

  // Portfolio & Social Privacy
  PortfolioPrivacySettings? portfolioPrivacy;
  int followersCount;
  int followingCount;

  // Autonomous Risk Circuit Breakers & Tilt Guardrails
  RiskCircuitBreakerConfig? riskCircuitBreakerConfig;

  // Subscription fields
  String? subscriptionStatus; // 'active', 'trial', 'none', 'expired'
  DateTime? trialStartDate;
  DateTime? subscriptionExpiryDate;
  String? referralCode;

  User(
      {this.name,
      this.nameLower,
      this.email,
      this.phoneNumber,
      this.photoUrl,
      this.providerId,
      this.location,
      this.role = UserRole.user,
      required this.devices,
      required this.dateCreated,
      this.dateUpdated,
      this.lastVisited,
      required this.brokerageUsers,
      this.refreshQuotes = false,
      this.investmentProfile,
      this.tradeSignalNotificationSettings,
      this.agenticTradingConfig,
      this.futuresTradingConfig,
      this.rebalancingConfig,
      this.optionFilterPresets,
      this.defaultOptionFilterPreset,
      this.assetAllocationTargets,
      this.sectorAllocationTargets,
      this.portfolioPrivacy,
      this.followersCount = 0,
      this.followingCount = 0,
      this.riskCircuitBreakerConfig,
      this.subscriptionStatus,
      this.trialStartDate,
      this.subscriptionExpiryDate,
      this.referralCode});

  User.fromJson(Map<String, Object?> json)
      : this(
            name: json['name'] as String?,
            nameLower: json['nameLower'] as String?,
            email: json['email'] as String?,
            phoneNumber: json['phoneNumber'] as String?,
            photoUrl: json['photoUrl'] as String?,
            providerId: json['providerId'] as String?,
            location: json['location'] as String?,
            role: (json['role'] != null ? json['role'] as String : '')
                .parseEnum(UserRole.values, UserRole.user),
            devices: json.keys.contains('devices')
                ? Device.fromJsonArray(json['devices'])
                : [],
            dateCreated: json['dateCreated'] != null
                ? (json['dateCreated'] is Timestamp
                    ? (json['dateCreated'] as Timestamp).toDate()
                    : DateTime.tryParse(json['dateCreated'].toString()) ??
                        DateTime.now())
                : DateTime.now(),
            dateUpdated: json['dateUpdated'] != null
                ? (json['dateUpdated'] is Timestamp
                    ? (json['dateUpdated'] as Timestamp).toDate()
                    : DateTime.tryParse(json['dateUpdated'].toString()))
                : null,
            lastVisited: json['lastVisited'] != null
                ? (json['lastVisited'] as Timestamp).toDate()
                : null,
            brokerageUsers: json['brokerageUsers'] != null
                ? BrokerageUser.fromJsonArray(json['brokerageUsers'])
                : [],
            refreshQuotes: json['refreshQuotes'] != null
                ? json['refreshQuotes'] as bool
                : true,
            investmentProfile: json['investmentProfile'] != null
                ? InvestmentProfile.fromJson(
                    json['investmentProfile'] as Map<String, Object?>)
                : null,
            tradeSignalNotificationSettings:
                json['tradeSignalNotificationSettings'] != null
                    ? TradeSignalNotificationSettings.fromJson(
                        json['tradeSignalNotificationSettings']
                            as Map<String, dynamic>)
                    : null,
            agenticTradingConfig: json['agenticTradingConfig'] != null
                ? AgenticTradingConfig.fromJson(
                    json['agenticTradingConfig'] as Map<String, dynamic>)
                : null,
            futuresTradingConfig: json['futuresTradingConfig'] != null
                ? FuturesTradingConfig.fromJson(
                    json['futuresTradingConfig'] as Map<String, dynamic>)
                : null,
            rebalancingConfig: json['rebalancingConfig'] != null ? RebalancingConfig.fromJson(json['rebalancingConfig'] as Map<String, dynamic>) : null,
            optionFilterPresets: json['optionFilterPresets'] != null ? (json['optionFilterPresets'] as Map<String, dynamic>).map((key, value) => MapEntry(key, Map<String, dynamic>.from(value as Map))) : null,
            defaultOptionFilterPreset: json['defaultOptionFilterPreset'] as String?,
            assetAllocationTargets: json['assetAllocationTargets'] != null ? (json['assetAllocationTargets'] as Map<String, dynamic>).map((key, value) => MapEntry(key, (value as num).toDouble())) : null,
            sectorAllocationTargets: json['sectorAllocationTargets'] != null ? (json['sectorAllocationTargets'] as Map<String, dynamic>).map((key, value) => MapEntry(key, (value as num).toDouble())) : null,
            portfolioPrivacy: json['portfolioPrivacy'] != null ? PortfolioPrivacySettings.fromJson(json['portfolioPrivacy'] as Map<String, dynamic>) : null,
            followersCount: (json['followersCount'] as num?)?.toInt() ?? 0,
            followingCount: (json['followingCount'] as num?)?.toInt() ?? 0,
            riskCircuitBreakerConfig: json['riskCircuitBreakerConfig'] != null
                ? RiskCircuitBreakerConfig.fromJson(
                    json['riskCircuitBreakerConfig'] as Map<String, dynamic>)
                : null,
            subscriptionStatus: json['subscriptionStatus'] as String?,
            trialStartDate: json['trialStartDate'] != null ? (json['trialStartDate'] as Timestamp).toDate() : null,
            subscriptionExpiryDate: json['subscriptionExpiryDate'] != null ? (json['subscriptionExpiryDate'] as Timestamp).toDate() : null,
            referralCode: json['referralCode'] as String?);

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'nameLower': nameLower,
      'email': email,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'providerId': providerId,
      'location': location,
      'role': role.enumValue(),
      'devices': devices.map((e) => e.toJson()).toList(),
      'dateCreated': dateCreated,
      'dateUpdated': dateUpdated,
      'lastVisited': lastVisited,
      'brokerageUsers': brokerageUsers.map((e) => e.toJson()).toList(),
      'refreshQuotes': refreshQuotes,
      'investmentProfile': investmentProfile?.toJson(),
      'subscriptionStatus': subscriptionStatus,
      'trialStartDate': trialStartDate,
      'subscriptionExpiryDate': subscriptionExpiryDate,
      'referralCode': referralCode,
      'tradeSignalNotificationSettings':
          tradeSignalNotificationSettings?.toJson(),
      'agenticTradingConfig': agenticTradingConfig?.toJson(),
      'futuresTradingConfig': futuresTradingConfig?.toJson(),
      'rebalancingConfig': rebalancingConfig?.toJson(),
      'optionFilterPresets': optionFilterPresets,
      'defaultOptionFilterPreset': defaultOptionFilterPreset,
      'assetAllocationTargets': assetAllocationTargets,
      'sectorAllocationTargets': sectorAllocationTargets,
      'portfolioPrivacy': portfolioPrivacy?.toJson(),
      'followersCount': followersCount,
      'followingCount': followingCount,
      'riskCircuitBreakerConfig': riskCircuitBreakerConfig?.toJson(),
    };
  }

  static List<User> fromJsonArray(dynamic json) {
    List<User> list = [];
    for (int i = 0; i < json.length; i++) {
      list.add(User.fromJson(json[i]));
    }
    return list;
  }
}

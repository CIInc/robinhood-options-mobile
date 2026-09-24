import 'package:flutter/foundation.dart';
import 'package:robinhood_options_mobile/model/schwab_streamer_info.dart';

/// Represents user preferences and linked accounts returned by Schwab Trader API:
/// `GET /trader/v1/userPreference`
@immutable
class SchwabUserPreference {
  final List<SchwabAccountPreference> accounts;
  final List<SchwabStreamerInfo> streamerInfo;
  final List<SchwabOfferPreference> offers;

  const SchwabUserPreference({
    this.accounts = const [],
    this.streamerInfo = const [],
    this.offers = const [],
  });

  factory SchwabUserPreference.fromJson(Map<String, dynamic> json) {
    var accountsList = <SchwabAccountPreference>[];
    if (json['accounts'] is List) {
      for (var acc in json['accounts']) {
        if (acc is Map<String, dynamic>) {
          accountsList.add(SchwabAccountPreference.fromJson(acc));
        }
      }
    }

    var streamerList = <SchwabStreamerInfo>[];
    if (json['streamerInfo'] is List) {
      for (var s in json['streamerInfo']) {
        if (s != null) {
          streamerList.add(SchwabStreamerInfo.fromUserPreference(s));
        }
      }
    } else if (json['streamerInfo'] is Map<String, dynamic>) {
      streamerList
          .add(SchwabStreamerInfo.fromUserPreference(json['streamerInfo']));
    }

    var offersList = <SchwabOfferPreference>[];
    if (json['offers'] is List) {
      for (var o in json['offers']) {
        if (o is Map<String, dynamic>) {
          offersList.add(SchwabOfferPreference.fromJson(o));
        }
      }
    }

    return SchwabUserPreference(
      accounts: accountsList,
      streamerInfo: streamerList,
      offers: offersList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accounts': accounts.map((a) => a.toJson()).toList(),
      'streamerInfo': streamerInfo.map((s) => s.toJson()).toList(),
      'offers': offers.map((o) => o.toJson()).toList(),
    };
  }

  /// Returns the primary account preference if designated, or the first account.
  SchwabAccountPreference? get primaryAccount =>
      accounts.firstWhere(
        (a) => a.primaryAccount,
        orElse: () => accounts.isNotEmpty
            ? accounts.first
            : const SchwabAccountPreference(
                accountNumber: '',
                primaryAccount: false,
                type: '',
              ),
      ).accountNumber.isNotEmpty
          ? accounts.firstWhere(
              (a) => a.primaryAccount,
              orElse: () => accounts.first,
            )
          : null;

  /// Looks up an account preference by account number or masked display ID.
  SchwabAccountPreference? findAccount(String accountNumber) {
    return accounts.cast<SchwabAccountPreference?>().firstWhere(
          (a) =>
              a?.accountNumber == accountNumber ||
              a?.displayAcctId == accountNumber,
          orElse: () => null,
        );
  }
}

/// Represents individual account settings within Schwab user preferences.
@immutable
class SchwabAccountPreference {
  final String accountNumber;
  final bool primaryAccount;
  final String type;
  final String? nickName;
  final String? displayAcctId;
  final bool autoPositionEffect;
  final String? accountColor;

  const SchwabAccountPreference({
    required this.accountNumber,
    required this.primaryAccount,
    required this.type,
    this.nickName,
    this.displayAcctId,
    this.autoPositionEffect = false,
    this.accountColor,
  });

  factory SchwabAccountPreference.fromJson(Map<String, dynamic> json) {
    return SchwabAccountPreference(
      accountNumber: (json['accountNumber'] ?? '').toString(),
      primaryAccount: json['primaryAccount'] == true,
      type: (json['type'] ?? '').toString(),
      nickName: json['nickName']?.toString(),
      displayAcctId: json['displayAcctId']?.toString(),
      autoPositionEffect: json['autoPositionEffect'] == true,
      accountColor: json['accountColor']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountNumber': accountNumber,
      'primaryAccount': primaryAccount,
      'type': type,
      if (nickName != null) 'nickName': nickName,
      if (displayAcctId != null) 'displayAcctId': displayAcctId,
      'autoPositionEffect': autoPositionEffect,
      if (accountColor != null) 'accountColor': accountColor,
    };
  }
}

/// Represents feature offer permissions within Schwab user preferences.
@immutable
class SchwabOfferPreference {
  final bool level2Permissions;
  final String? mktDataPermission;

  const SchwabOfferPreference({
    this.level2Permissions = false,
    this.mktDataPermission,
  });

  factory SchwabOfferPreference.fromJson(Map<String, dynamic> json) {
    return SchwabOfferPreference(
      level2Permissions: json['level2Permissions'] == true,
      mktDataPermission: json['mktDataPermission']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level2Permissions': level2Permissions,
      if (mktDataPermission != null) 'mktDataPermission': mktDataPermission,
    };
  }
}

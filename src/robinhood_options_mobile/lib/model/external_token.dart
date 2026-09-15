import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _dateFormat = DateFormat.yMMMd();
final _dateTimeFormat = DateFormat.yMMMd().add_jm();

/// Represents an external OAuth2 token or connected third-party agent application (`/oauth2/list_external_tokens/`).
class ExternalToken {
  final String id;
  final String? clientId;
  final String applicationName;
  final String? applicationDescription;
  final String? applicationUrl;
  final String? applicationIconUrl;

  /// Fourth-party application fields (aggregators, agentic tokens)
  final String? fourthPartyDisplayName;
  final String? fourthPartyLogoUrl;
  final String? agentId;
  final List<String> agenticAccounts;

  final List<String> scopes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? initialLoginTime;
  final DateTime? expiresAt;
  final DateTime? lastUsedAt;
  final bool isActive;
  final String tokenType;

  const ExternalToken({
    required this.id,
    this.clientId,
    required this.applicationName,
    this.applicationDescription,
    this.applicationUrl,
    this.applicationIconUrl,
    this.fourthPartyDisplayName,
    this.fourthPartyLogoUrl,
    this.agentId,
    this.agenticAccounts = const [],
    this.scopes = const [],
    this.createdAt,
    this.updatedAt,
    this.initialLoginTime,
    this.expiresAt,
    this.lastUsedAt,
    this.isActive = true,
    this.tokenType = 'Bearer',
  });

  factory ExternalToken.fromJson(dynamic json) {
    if (json is! Map) {
      return const ExternalToken(id: '', applicationName: 'Unknown App');
    }

    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      try {
        return DateTime.parse(value.toString());
      } catch (_) {
        return null;
      }
    }

    final id = (json['id'] ?? json['token_id'] ?? json['client_id'] ?? '')
        .toString();

    // 1. Check oauth_application or application or client
    final oauthApp = json['oauth_application'] is Map
        ? json['oauth_application'] as Map
        : (json['application'] is Map
              ? json['application'] as Map
              : (json['client'] is Map ? json['client'] as Map : null));

    final clientId =
        ((oauthApp != null && oauthApp['client_id'] != null)
                ? oauthApp['client_id']
                : json['client_id'])
            ?.toString();

    final appName =
        (oauthApp != null
                ? (oauthApp['name'] ?? oauthApp['application_name'])
                : (json['application_name'] ??
                      json['client_name'] ??
                      json['name'] ??
                      'Connected App'))
            .toString();

    final appDesc = oauthApp != null
        ? oauthApp['description']?.toString()
        : json['description']?.toString();
    final appUrl = oauthApp != null
        ? (oauthApp['url'] ?? oauthApp['website'])?.toString()
        : json['url']?.toString();
    final iconUrl =
        (oauthApp != null
            ? (oauthApp['icon'] ?? oauthApp['icon_url'])
            : null) ??
        json['icon_url']?.toString();

    // 2. Check fourth_party_application
    final fourthParty = json['fourth_party_application'] is Map
        ? json['fourth_party_application'] as Map
        : null;

    final fourthPartyDisplayName = fourthParty?['display_name']?.toString();
    final fourthPartyLogoUrl = fourthParty?['logo_url']?.toString();
    final agentId = fourthParty?['agent_id']?.toString();
    final rawAgenticAccounts = fourthParty?['agentic_accounts'];
    List<String> agenticAccounts = [];
    if (rawAgenticAccounts is List) {
      agenticAccounts = rawAgenticAccounts.map((a) => a.toString()).toList();
    }

    // 3. Scopes parsing
    List<String> parsedScopes = [];
    final rawScopes = json['scopes'] ?? json['scope'];
    if (rawScopes is List) {
      parsedScopes = rawScopes.map((s) => s.toString()).toList();
    } else if (rawScopes is String) {
      parsedScopes = rawScopes
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .toList();
    }

    // 4. Dates
    final createdAt = parseDate(
      json['created'] ?? json['created_at'] ?? json['issued_at'],
    );
    final updatedAt = parseDate(
      json['updated'] ?? json['updated_at'] ?? json['last_used_at'],
    );
    final initialLogin = parseDate(
      json['initial_login_time'] ?? json['initial_login'],
    );
    final expiresAt = parseDate(json['expires_at'] ?? json['expiration_date']);
    final lastUsed = updatedAt ?? parseDate(json['last_used_at']);

    // 5. Active status
    final active =
        json['is_active'] ??
        json['active'] ??
        (json['revoked'] == true
            ? false
            : (json['status'] == null ||
                  json['status'].toString().toLowerCase() == 'active'));

    return ExternalToken(
      id: id,
      clientId: clientId,
      applicationName: appName,
      applicationDescription: appDesc,
      applicationUrl: appUrl,
      applicationIconUrl: iconUrl,
      fourthPartyDisplayName: fourthPartyDisplayName,
      fourthPartyLogoUrl: fourthPartyLogoUrl,
      agentId: agentId,
      agenticAccounts: agenticAccounts,
      scopes: parsedScopes,
      createdAt: createdAt,
      updatedAt: updatedAt,
      initialLoginTime: initialLogin,
      expiresAt: expiresAt,
      lastUsedAt: lastUsed,
      isActive: active == true,
      tokenType: (json['token_type'] ?? 'Bearer').toString(),
    );
  }

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// True if this token represents an AI agent, trading bot, or MCP client
  bool get isAgent {
    if (agentId != null && agentId!.isNotEmpty) return true;
    if (agenticAccounts.isNotEmpty) return true;
    if (fourthPartyDisplayName != null &&
        fourthPartyDisplayName!.toLowerCase().contains('agent')) {
      return true;
    }
    final nameLower = applicationName.toLowerCase();
    return nameLower.contains('mcp') ||
        nameLower.contains('cursor') ||
        nameLower.contains('agent') ||
        nameLower.contains('bot');
  }

  /// True if this token connects via a financial aggregator (Yodlee, SnapTrade, Plaid)
  bool get isAggregator {
    if (isAgent) return false;
    return fourthPartyDisplayName != null && fourthPartyDisplayName!.isNotEmpty;
  }

  /// Primary display title for UI cards
  String get primaryTitle {
    if (isAgent) {
      if (applicationName.isNotEmpty && applicationName != 'Connected App') {
        return applicationName;
      }
      if (fourthPartyDisplayName != null &&
          fourthPartyDisplayName!.isNotEmpty) {
        return fourthPartyDisplayName!;
      }
    }
    if (fourthPartyDisplayName != null && fourthPartyDisplayName!.isNotEmpty) {
      return fourthPartyDisplayName!;
    }
    return applicationName;
  }

  /// Clean secondary subtitle explaining context
  String? get subtitle {
    if (isAgent) {
      if (fourthPartyDisplayName != null &&
          fourthPartyDisplayName!.isNotEmpty) {
        return 'Token: $fourthPartyDisplayName';
      }
      return 'Autonomous AI Trading Agent';
    }
    if (fourthPartyDisplayName != null && fourthPartyDisplayName!.isNotEmpty) {
      return 'Connected via $applicationName';
    }
    if (applicationDescription != null && applicationDescription!.isNotEmpty) {
      return applicationDescription;
    }
    if (clientId != null && clientId!.isNotEmpty) {
      return 'Client: $clientId';
    }
    return null;
  }

  /// Categorical label badge (AI Agent, Linked Service, OAuth App)
  String get typeLabel {
    if (isAgent) return 'AI Agent';
    if (isAggregator) return 'Linked Service';
    return 'OAuth App';
  }

  /// Themed color for the category badge
  Color get typeColor {
    if (isAgent) return const Color(0xFF7C4DFF); // Vibrant purple
    if (isAggregator) return const Color(0xFF00897B); // Teal
    return const Color(0xFF1E88E5); // Blue
  }

  /// Category icon
  IconData get typeIcon {
    if (isAgent) return Icons.psychology;
    if (isAggregator) return Icons.hub_outlined;
    return Icons.apps_outlined;
  }

  String get formattedCreatedAt =>
      createdAt != null ? _dateFormat.format(createdAt!) : 'Unknown';
  String get formattedUpdatedAt =>
      updatedAt != null ? _dateFormat.format(updatedAt!) : 'Unknown';
  String get formattedUpdated => formattedUpdatedAt;
  String get formattedInitialLogin => initialLoginTime != null
      ? _dateFormat.format(initialLoginTime!)
      : 'Unknown';
  String get formattedExpiresAt =>
      expiresAt != null ? _dateFormat.format(expiresAt!) : 'Never';
  String get formattedLastUsed =>
      lastUsedAt != null ? _dateTimeFormat.format(lastUsedAt!) : 'Never';

  String get statusLabel {
    if (!isActive) return 'Revoked';
    if (isExpired) return 'Expired';
    return 'Active';
  }

  Color get statusColor {
    if (!isActive) return Colors.red;
    if (isExpired) return Colors.orange;
    return Colors.green;
  }

  String get statusColorHex => isActive ? '#4CAF50' : '#F44336';

  /// Returns true if this token or agent is authorized to place trades or execute orders
  bool get hasTradePermission {
    if (isAgent) return true;
    return scopes.any((s) {
      final lower = s.toLowerCase();
      return lower.contains('trade') ||
          lower.contains('order') ||
          lower.contains('write');
    });
  }

  /// Brief human-readable summary of the token's granted authority
  String get permissionSummary {
    if (hasTradePermission) {
      return 'Trading & Data Access';
    }
    return 'Read Only Access';
  }

  /// Relative description for last active time (e.g. "Today", "3 days ago")
  String get relativeLastActive {
    final date = updatedAt ?? createdAt;
    if (date == null) return 'Unknown';
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  /// Relative description for when connection was first created
  String get relativeFirstLogin {
    final date = initialLoginTime ?? createdAt;
    if (date == null) return 'Unknown';
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (clientId != null) 'client_id': clientId,
      'application_name': applicationName,
      if (applicationDescription != null)
        'application_description': applicationDescription,
      if (applicationUrl != null) 'application_url': applicationUrl,
      if (applicationIconUrl != null)
        'application_icon_url': applicationIconUrl,
      if (fourthPartyDisplayName != null)
        'fourth_party_display_name': fourthPartyDisplayName,
      if (fourthPartyLogoUrl != null)
        'fourth_party_logo_url': fourthPartyLogoUrl,
      if (agentId != null) 'agent_id': agentId,
      if (agenticAccounts.isNotEmpty) 'agentic_accounts': agenticAccounts,
      'scopes': scopes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (initialLoginTime != null)
        'initial_login_time': initialLoginTime!.toIso8601String(),
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
      if (lastUsedAt != null) 'last_used_at': lastUsedAt!.toIso8601String(),
      'is_active': isActive,
      'token_type': tokenType,
    };
  }
}

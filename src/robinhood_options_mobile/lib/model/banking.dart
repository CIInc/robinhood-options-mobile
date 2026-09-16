import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

final _currencyFormat = NumberFormat.simpleCurrency();
final _compactCurrencyFormat = NumberFormat.compactSimpleCurrency();
final _dateFormat = DateFormat.yMMMd();
final _dateTimeFormat = DateFormat.yMMMd().add_jm();

/// Represents an ACH deposit or withdrawal transfer between a bank account and Robinhood.
class AchTransfer {
  final String id;
  final String? url;
  final String? account;
  final String? cancelUrl;
  final String direction; // 'deposit' or 'withdraw'
  final double amount;
  final String state; // 'completed', 'pending', 'cancelled', 'failed', 'reversed'
  final String? statusDescription;
  final bool scheduled;
  final DateTime? expectedLandingDate;
  final DateTime? expectedLandingDateTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? achRelationship;
  final double fees;
  final String? refId;
  final String? rhsState;

  const AchTransfer({
    required this.id,
    this.url,
    this.account,
    this.cancelUrl,
    this.direction = 'deposit',
    this.amount = 0.0,
    this.state = 'completed',
    this.statusDescription,
    this.scheduled = false,
    this.expectedLandingDate,
    this.expectedLandingDateTime,
    this.createdAt,
    this.updatedAt,
    this.achRelationship,
    this.fees = 0.0,
    this.refId,
    this.rhsState,
  });

  factory AchTransfer.fromJson(dynamic json) {
    if (json is! Map) {
      return const AchTransfer(id: '');
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

    final id = json['id']?.toString() ?? json['ref_id']?.toString() ?? '';
    final url = json['url']?.toString();
    final account = json['account']?.toString() ?? json['account_number']?.toString();
    final cancelUrl = json['cancel']?.toString() ?? json['cancel_url']?.toString();
    final direction = json['direction']?.toString().toLowerCase() ?? 'deposit';
    final amount = parseDouble(json['amount']) ?? 0.0;
    final state = json['state']?.toString().toLowerCase() ?? 'completed';
    final statusDescription = json['status_description']?.toString() ??
        json['description']?.toString();
    final scheduled = json['scheduled'] == true || json['is_scheduled'] == true;
    final expectedLandingDate = parseDate(json['expected_landing_date']);
    final expectedLandingDateTime = parseDate(json['expected_landing_datetime']);
    final createdAt = parseDate(json['created_at']);
    final updatedAt = parseDate(json['updated_at']);
    final achRelationship = json['ach_relationship']?.toString();
    final fees = parseDouble(json['fees']) ?? 0.0;
    final refId = json['ref_id']?.toString();
    final rhsState = json['rhs_state']?.toString();

    return AchTransfer(
      id: id,
      url: url,
      account: account,
      cancelUrl: cancelUrl,
      direction: direction,
      amount: amount,
      state: state,
      statusDescription: statusDescription,
      scheduled: scheduled,
      expectedLandingDate: expectedLandingDate,
      expectedLandingDateTime: expectedLandingDateTime,
      createdAt: createdAt,
      updatedAt: updatedAt,
      achRelationship: achRelationship,
      fees: fees,
      refId: refId,
      rhsState: rhsState,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (url != null) 'url': url,
      if (account != null) 'account': account,
      if (cancelUrl != null) 'cancel': cancelUrl,
      'direction': direction,
      'amount': amount,
      'state': state,
      if (statusDescription != null) 'status_description': statusDescription,
      'scheduled': scheduled,
      if (expectedLandingDate != null)
        'expected_landing_date': expectedLandingDate!.toIso8601String(),
      if (expectedLandingDateTime != null)
        'expected_landing_datetime': expectedLandingDateTime!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (achRelationship != null) 'ach_relationship': achRelationship,
      'fees': fees,
      if (refId != null) 'ref_id': refId,
      if (rhsState != null) 'rhs_state': rhsState,
    };
  }

  bool get isDeposit => direction.toLowerCase() == 'deposit';
  bool get isWithdrawal => direction.toLowerCase() == 'withdraw' || direction.toLowerCase() == 'withdrawal';

  bool get isPending => state == 'pending' || state == 'queued' || state == 'initiated' || state == 'new';
  bool get isCompleted => state == 'completed' || state == 'settled' || state == 'cleared';
  bool get isCancelled => state == 'cancelled' || state == 'canceled';
  bool get isFailed => state == 'failed' || state == 'reversed' || state == 'rejected';

  String get formattedAmount {
    final prefix = isDeposit ? '+' : '-';
    return '$prefix${_currencyFormat.format(amount)}';
  }

  String get formattedAmountPlain => _currencyFormat.format(amount);
  String get formattedCompactAmount => _compactCurrencyFormat.format(amount);

  String get formattedCreatedAt =>
      createdAt != null ? _dateFormat.format(createdAt!) : 'Recent';

  String get formattedCreatedDateTime =>
      createdAt != null ? _dateTimeFormat.format(createdAt!) : 'Recent';

  String? get formattedLandingDate {
    final target = expectedLandingDateTime ?? expectedLandingDate;
    if (target == null) return null;
    return _dateFormat.format(target);
  }

  String get statusTitle {
    switch (state) {
      case 'completed':
      case 'settled':
        return 'Completed';
      case 'pending':
      case 'queued':
      case 'initiated':
        return 'Pending';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      case 'failed':
      case 'rejected':
        return 'Failed';
      case 'reversed':
        return 'Reversed';
      default:
        return state.isEmpty ? 'Unknown' : '${state[0].toUpperCase()}${state.substring(1)}';
    }
  }

  Color get statusColor {
    if (isCompleted) return Colors.green;
    if (isPending) return Colors.amber;
    if (isCancelled) return Colors.grey;
    if (isFailed) return Colors.red;
    return Colors.blue;
  }

  IconData get statusIcon {
    if (isCompleted) return Icons.check_circle_outline;
    if (isPending) return Icons.schedule;
    if (isCancelled) return Icons.cancel_outlined;
    if (isFailed) return Icons.error_outline;
    return Icons.help_outline;
  }

  Color get directionColor => isDeposit ? Colors.green : Colors.blue;
  IconData get directionIcon => isDeposit ? Icons.south_west : Icons.north_east;
}

/// Represents a bank account linked to Robinhood via ACH for deposits and withdrawals.
class AchRelationship {
  final String id;
  final String? url;
  final String? bankAccountNickname;
  final String bankAccountType; // 'checking' or 'savings'
  final String? bankAccountHolderName;
  final String? bankRoutingNumber;
  final String bankAccountNumber; // Masked, e.g. '****1234'
  final String state; // 'approved', 'pending', 'unlinked', 'rejected'
  final bool verified;
  final String? verifyMicroDepositsUrl;
  final String? initialDeposit;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isDefault;

  const AchRelationship({
    required this.id,
    this.url,
    this.bankAccountNickname,
    this.bankAccountType = 'checking',
    this.bankAccountHolderName,
    this.bankRoutingNumber,
    this.bankAccountNumber = '',
    this.state = 'approved',
    this.verified = true,
    this.verifyMicroDepositsUrl,
    this.initialDeposit,
    this.createdAt,
    this.updatedAt,
    this.isDefault = false,
  });

  factory AchRelationship.fromJson(dynamic json) {
    if (json is! Map) {
      return const AchRelationship(id: '');
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

    final id = json['id']?.toString() ?? '';
    final url = json['url']?.toString();
    final bankAccountNickname = json['bank_account_nickname']?.toString() ??
        json['nickname']?.toString() ??
        json['bank_name']?.toString();
    final bankAccountType = json['bank_account_type']?.toString().toLowerCase() ?? 'checking';
    final bankAccountHolderName = json['bank_account_holder_name']?.toString() ??
        json['holder_name']?.toString();
    final bankRoutingNumber = json['bank_routing_number']?.toString() ??
        json['routing_number']?.toString();
    final bankAccountNumber = json['bank_account_number']?.toString() ??
        json['account_number']?.toString() ??
        '';
    final state = json['state']?.toString().toLowerCase() ?? 'approved';
    final verified = json['verified'] == true ||
        json['is_verified'] == true ||
        state == 'approved';
    final verifyMicroDepositsUrl = json['verify_micro_deposits']?.toString() ??
        json['verify_micro_deposits_url']?.toString();
    final initialDeposit = json['initial_deposit']?.toString();
    final createdAt = parseDate(json['created_at']);
    final updatedAt = parseDate(json['updated_at']);
    final isDefault = json['default'] == true || json['is_default'] == true;

    return AchRelationship(
      id: id,
      url: url,
      bankAccountNickname: bankAccountNickname,
      bankAccountType: bankAccountType,
      bankAccountHolderName: bankAccountHolderName,
      bankRoutingNumber: bankRoutingNumber,
      bankAccountNumber: bankAccountNumber,
      state: state,
      verified: verified,
      verifyMicroDepositsUrl: verifyMicroDepositsUrl,
      initialDeposit: initialDeposit,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isDefault: isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (url != null) 'url': url,
      if (bankAccountNickname != null) 'bank_account_nickname': bankAccountNickname,
      'bank_account_type': bankAccountType,
      if (bankAccountHolderName != null) 'bank_account_holder_name': bankAccountHolderName,
      if (bankRoutingNumber != null) 'bank_routing_number': bankRoutingNumber,
      'bank_account_number': bankAccountNumber,
      'state': state,
      'verified': verified,
      if (verifyMicroDepositsUrl != null) 'verify_micro_deposits': verifyMicroDepositsUrl,
      if (initialDeposit != null) 'initial_deposit': initialDeposit,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'default': isDefault,
    };
  }

  bool get isApproved => state == 'approved';
  bool get isPending => state == 'pending' || state == 'queued';
  bool get isUnlinked => state == 'unlinked' || state == 'removed';
  bool get isRejected => state == 'rejected' || state == 'failed';

  String get displayName {
    if (bankAccountNickname != null && bankAccountNickname!.isNotEmpty) {
      return bankAccountNickname!;
    }
    final typeCap = bankAccountType.isNotEmpty
        ? '${bankAccountType[0].toUpperCase()}${bankAccountType.substring(1)}'
        : 'Bank';
    final mask = maskedAccountNumber;
    return mask.isNotEmpty ? '$typeCap ($mask)' : typeCap;
  }

  String get maskedAccountNumber {
    if (bankAccountNumber.isEmpty) return '';
    if (bankAccountNumber.startsWith('*')) return bankAccountNumber;
    if (bankAccountNumber.length <= 4) return '****$bankAccountNumber';
    return '****${bankAccountNumber.substring(bankAccountNumber.length - 4)}';
  }

  String get formattedAccountType => bankAccountType.isNotEmpty
      ? '${bankAccountType[0].toUpperCase()}${bankAccountType.substring(1)}'
      : 'Checking';

  String get statusTitle {
    switch (state) {
      case 'approved':
        return 'Verified';
      case 'pending':
        return 'Pending';
      case 'unlinked':
        return 'Unlinked';
      case 'rejected':
        return 'Rejected';
      default:
        return state.isEmpty ? 'Unknown' : '${state[0].toUpperCase()}${state.substring(1)}';
    }
  }

  Color get statusColor {
    if (isApproved) return Colors.green;
    if (isPending) return Colors.amber;
    if (isUnlinked) return Colors.grey;
    return Colors.red;
  }

  IconData get statusIcon {
    if (isApproved) return Icons.verified_user_outlined;
    if (isPending) return Icons.hourglass_top_outlined;
    if (isUnlinked) return Icons.link_off;
    return Icons.error_outline;
  }

  String get formattedCreatedAt =>
      createdAt != null ? _dateFormat.format(createdAt!) : '';
}

/// Aggregated metrics for banking, ACH cash flow, and linked institutions.
class AchSummary {
  final double totalDeposited;
  final double totalWithdrawn;
  final double netCashFlow;
  final double pendingDeposits;
  final double pendingWithdrawals;
  final int completedTransfersCount;
  final int pendingTransfersCount;
  final int linkedAccountsCount;
  final int verifiedAccountsCount;
  final AchTransfer? latestTransfer;
  final AchTransfer? nextClearingTransfer;

  const AchSummary({
    this.totalDeposited = 0.0,
    this.totalWithdrawn = 0.0,
    this.netCashFlow = 0.0,
    this.pendingDeposits = 0.0,
    this.pendingWithdrawals = 0.0,
    this.completedTransfersCount = 0,
    this.pendingTransfersCount = 0,
    this.linkedAccountsCount = 0,
    this.verifiedAccountsCount = 0,
    this.latestTransfer,
    this.nextClearingTransfer,
  });

  factory AchSummary.fromTransfersAndRelationships(
    List<AchTransfer> transfers,
    List<AchRelationship> relationships,
  ) {
    double totalDeposited = 0.0;
    double totalWithdrawn = 0.0;
    double pendingDeposits = 0.0;
    double pendingWithdrawals = 0.0;
    int completedCount = 0;
    int pendingCount = 0;

    AchTransfer? latest;
    AchTransfer? nextClearing;

    for (final transfer in transfers) {
      if (latest == null ||
          (transfer.createdAt != null &&
              (latest.createdAt == null || transfer.createdAt!.isAfter(latest.createdAt!)))) {
        latest = transfer;
      }

      if (transfer.isCompleted) {
        completedCount++;
        if (transfer.isDeposit) {
          totalDeposited += transfer.amount;
        } else if (transfer.isWithdrawal) {
          totalWithdrawn += transfer.amount;
        }
      } else if (transfer.isPending) {
        pendingCount++;
        if (transfer.isDeposit) {
          pendingDeposits += transfer.amount;
        } else if (transfer.isWithdrawal) {
          pendingWithdrawals += transfer.amount;
        }

        final landing = transfer.expectedLandingDateTime ?? transfer.expectedLandingDate;
        if (landing != null) {
          final nextLanding = nextClearing?.expectedLandingDateTime ?? nextClearing?.expectedLandingDate;
          if (nextLanding == null || landing.isBefore(nextLanding)) {
            nextClearing = transfer;
          }
        }
      }
    }

    final activeRelationships = relationships.where((r) => !r.isUnlinked).toList();
    final verifiedCount = activeRelationships.where((r) => r.isApproved && r.verified).length;

    return AchSummary(
      totalDeposited: totalDeposited,
      totalWithdrawn: totalWithdrawn,
      netCashFlow: totalDeposited - totalWithdrawn,
      pendingDeposits: pendingDeposits,
      pendingWithdrawals: pendingWithdrawals,
      completedTransfersCount: completedCount,
      pendingTransfersCount: pendingCount,
      linkedAccountsCount: activeRelationships.length,
      verifiedAccountsCount: verifiedCount,
      latestTransfer: latest,
      nextClearingTransfer: nextClearing,
    );
  }

  String get formattedTotalDeposited => _currencyFormat.format(totalDeposited);
  String get formattedTotalWithdrawn => _currencyFormat.format(totalWithdrawn);
  String get formattedNetCashFlow => _currencyFormat.format(netCashFlow);
  String get formattedPendingDeposits => _currencyFormat.format(pendingDeposits);
  String get formattedPendingWithdrawals => _currencyFormat.format(pendingWithdrawals);
}

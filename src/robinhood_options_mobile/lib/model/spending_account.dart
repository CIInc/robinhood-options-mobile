import 'package:intl/intl.dart';
import 'package:robinhood_options_mobile/utils/json.dart';

final _currencyFormat = NumberFormat.simpleCurrency();

/// Represents a Robinhood Spending / Cash Management Account (`/rhy/accounts/`).
class SpendingAccount {
  final String id;
  final String accountNumber;
  final String? routingNumber;
  final String status;
  final double balance;
  final double availableBalance;
  final double unsettledCharges;
  final double interestEarned;
  final double apy;
  final String? cardStatus;
  final String? cardLastFour;
  final String? cardType;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SpendingAccount({
    required this.id,
    required this.accountNumber,
    this.routingNumber,
    this.status = 'active',
    this.balance = 0.0,
    this.availableBalance = 0.0,
    this.unsettledCharges = 0.0,
    this.interestEarned = 0.0,
    this.apy = 0.0,
    this.cardStatus,
    this.cardLastFour,
    this.cardType,
    this.createdAt,
    this.updatedAt,
  });

  factory SpendingAccount.fromJson(dynamic json) {
    if (json is! Map) {
      return const SpendingAccount(id: '', accountNumber: '');
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

    final id = (json['id'] ?? json['account_id'] ?? json['uuid'] ?? '')
        .toString();
    final acctNum =
        (json['account_number'] ??
                json['mask'] ??
                json['rhs_account_number'] ??
                '')
            .toString();
    final routing = json['routing_number']?.toString();
    final status = (json['status'] ?? json['state'] ?? 'active').toString();

    final bal =
        parseDouble(
          json['balance'] ?? json['current_balance'] ?? json['total_balance'],
        ) ??
        0.0;
    final avail =
        parseDouble(
          json['available_balance'] ??
              json['cash_available'] ??
              json['available'],
        ) ??
        bal;
    final unsettled =
        parseDouble(json['unsettled_charges'] ?? json['pending_charges']) ??
        0.0;
    final interest =
        parseDouble(json['interest_earned'] ?? json['ytd_interest']) ?? 0.0;
    final apyVal = parseDouble(json['apy'] ?? json['interest_rate']) ?? 0.0;

    final card = json['card'] is Map ? json['card'] : null;
    final cardStat = card != null
        ? card['status']?.toString()
        : json['card_status']?.toString();
    final cardFour = card != null
        ? card['last_four']?.toString()
        : json['card_last_four']?.toString();
    final cType = card != null
        ? card['type']?.toString()
        : json['card_type']?.toString();

    return SpendingAccount(
      id: id,
      accountNumber: acctNum,
      routingNumber: routing,
      status: status,
      balance: bal,
      availableBalance: avail,
      unsettledCharges: unsettled,
      interestEarned: interest,
      apy: apyVal,
      cardStatus: cardStat,
      cardLastFour: cardFour,
      cardType: cType,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  bool get isActive => status.toLowerCase() == 'active';
  bool get isCardLocked => cardStatus?.toLowerCase() == 'locked';

  String get formattedBalance => _currencyFormat.format(balance);
  String get formattedAvailable => _currencyFormat.format(availableBalance);
  String get formattedApy => '${(apy * 100).toStringAsFixed(2)}%';
  String get formattedInterest => _currencyFormat.format(interestEarned);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'account_number': accountNumber,
      if (routingNumber != null) 'routing_number': routingNumber,
      'status': status,
      'balance': balance,
      'available_balance': availableBalance,
      'unsettled_charges': unsettledCharges,
      'interest_earned': interestEarned,
      'apy': apy,
      if (cardStatus != null) 'card_status': cardStatus,
      if (cardLastFour != null) 'card_last_four': cardLastFour,
      if (cardType != null) 'card_type': cardType,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }
}

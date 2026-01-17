import 'package:intl/intl.dart';

class InsiderTransaction {
  final String filerName;
  final String filerRelation;
  final String filerUrl;
  final int maxAge;
  final String moneyText;
  final String ownership;
  final String shares;
  final num? sharesValue;
  final DateTime? startDate;
  final String transactionText;
  final double? value;

  InsiderTransaction({
    required this.filerName,
    required this.filerRelation,
    required this.filerUrl,
    required this.maxAge,
    required this.moneyText,
    required this.ownership,
    required this.shares,
    this.sharesValue,
    this.startDate,
    required this.transactionText,
    this.value,
  });

  factory InsiderTransaction.fromJson(Map<String, dynamic> json) {
    DateTime? startDate;
    if (json['startDate'] != null && json['startDate']['fmt'] != null) {
      try {
        startDate = DateFormat("yyyy-MM-dd").parse(json['startDate']['fmt']);
      } catch (e) {
        // ignore
      }
    }

    double? value;
    if (json['value'] != null && json['value']['raw'] != null) {
      value = (json['value']['raw'] as num).toDouble();
    }

    num? sharesValue;
    if (json['shares'] != null && json['shares']['raw'] != null) {
      sharesValue = json['shares']['raw'] as num;
    }

    return InsiderTransaction(
      filerName: json['filerName'] ?? '',
      filerRelation: json['filerRelation'] ?? '',
      filerUrl: json['filerUrl'] ?? '',
      maxAge: json['maxAge'] ?? 1,
      moneyText: json['moneyText'] ?? '',
      ownership: json['ownership'] ?? '', // 'D' or 'I'
      shares: json['shares'] != null ? json['shares']['fmt'] ?? '0' : '0',
      sharesValue: sharesValue,
      startDate: startDate,
      transactionText: json['transactionText'] ?? '',
      value: value,
    );
  }
}

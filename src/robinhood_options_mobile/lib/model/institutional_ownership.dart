import 'package:flutter/material.dart';

@immutable
class InstitutionalOwnership {
  final String symbol;
  final double? institutionalShares;
  final double? totalShares;
  final double? percentageHeld;
  final double? floatPercentageHeld;
  final double? insidersPercentageHeld;
  final int? institutionCount;
  final List<InstitutionalHolder> topHolders;

  const InstitutionalOwnership({
    required this.symbol,
    this.institutionalShares,
    this.totalShares,
    this.percentageHeld,
    this.floatPercentageHeld,
    this.insidersPercentageHeld,
    this.institutionCount,
    this.topHolders = const [],
  });

  factory InstitutionalOwnership.fromJson(Map<String, dynamic> json) {
    return InstitutionalOwnership(
      symbol: json['symbol'] as String,
      institutionalShares: (json['institutionalShares'] as num?)?.toDouble(),
      totalShares: (json['totalShares'] as num?)?.toDouble(),
      percentageHeld: (json['percentageHeld'] as num?)?.toDouble(),
      floatPercentageHeld: (json['floatPercentageHeld'] as num?)?.toDouble(),
      insidersPercentageHeld: (json['insidersPercentageHeld'] as num?)?.toDouble(),
      institutionCount: (json['institutionCount'] as num?)?.toInt(),
      topHolders: (json['topHolders'] as List<dynamic>?)
              ?.map((e) =>
                  InstitutionalHolder.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

@immutable
class InstitutionalHolder {
  final String name;
  final double sharesHeld;
  final double? change; // Share change
  final double? percentageChange;
  final DateTime? dateReported;

  const InstitutionalHolder({
    required this.name,
    required this.sharesHeld,
    this.change,
    this.percentageChange,
    this.dateReported,
  });

  factory InstitutionalHolder.fromJson(Map<String, dynamic> json) {
    return InstitutionalHolder(
      name: json['name'] as String,
      sharesHeld: (json['sharesHeld'] as num).toDouble(),
      change: (json['change'] as num?)?.toDouble(),
      percentageChange: (json['percentageChange'] as num?)?.toDouble(),
      dateReported: json['dateReported'] != null
          ? DateTime.tryParse(json['dateReported'] as String)
          : null,
    );
  }
}

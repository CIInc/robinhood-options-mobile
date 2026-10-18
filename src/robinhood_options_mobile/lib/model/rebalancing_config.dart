import 'package:cloud_firestore/cloud_firestore.dart';

enum RebalancingFrequency {
  daily,
  weekly,
  monthly,
}

class RebalancingConfig {
  bool isEnabled;
  RebalancingFrequency frequency;
  double
      driftThreshold; // Drift amount (currency) to trigger notification/action
  bool autoExecute; // Whether to automatically execute or just notify
  DateTime? lastRun;

  RebalancingConfig({
    this.isEnabled = false,
    this.frequency = RebalancingFrequency.weekly,
    this.driftThreshold = 100.0,
    this.autoExecute = false,
    this.lastRun,
  });

  factory RebalancingConfig.fromJson(Map<String, dynamic> json) {
    return RebalancingConfig(
      isEnabled: json['isEnabled'] as bool? ?? false,
      frequency: _parseFrequency(json['frequency'] as String?),
      driftThreshold: (json['driftThreshold'] as num?)?.toDouble() ?? 100.0,
      autoExecute: json['autoExecute'] as bool? ?? false,
      lastRun: json['lastRun'] != null
          ? (json['lastRun'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'frequency': frequency.name,
      'driftThreshold': driftThreshold,
      'autoExecute': autoExecute,
      'lastRun': lastRun != null ? Timestamp.fromDate(lastRun!) : null,
    };
  }

  static RebalancingFrequency _parseFrequency(String? frequency) {
    switch (frequency) {
      case 'daily':
        return RebalancingFrequency.daily;
      case 'weekly':
        return RebalancingFrequency.weekly;
      case 'monthly':
        return RebalancingFrequency.monthly;
      default:
        return RebalancingFrequency.weekly;
    }
  }

  RebalancingConfig copyWith({
    bool? isEnabled,
    RebalancingFrequency? frequency,
    double? driftThreshold,
    bool? autoExecute,
    DateTime? lastRun,
  }) {
    return RebalancingConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      frequency: frequency ?? this.frequency,
      driftThreshold: driftThreshold ?? this.driftThreshold,
      autoExecute: autoExecute ?? this.autoExecute,
      lastRun: lastRun ?? this.lastRun,
    );
  }
}

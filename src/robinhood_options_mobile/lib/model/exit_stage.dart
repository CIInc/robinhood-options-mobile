class ExitStage {
  final double profitTargetPercent;
  final double quantityPercent; // 0.0 to 1.0 (e.g. 0.5 for 50%)

  ExitStage({required this.profitTargetPercent, required this.quantityPercent});

  Map<String, dynamic> toJson() => {
        'profitTargetPercent': profitTargetPercent,
        'quantityPercent': quantityPercent,
      };

  factory ExitStage.fromJson(Map<String, dynamic> json) => ExitStage(
        profitTargetPercent: (json['profitTargetPercent'] as num).toDouble(),
        quantityPercent: (json['quantityPercent'] as num).toDouble(),
      );
}

/// User privacy preferences for portfolio visibility and social features.
class PortfolioPrivacySettings {
  final bool isPublic;
  final bool showTradeAmounts;
  final bool showHoldings;
  final bool showTrades;
  final bool allowFollowers;

  const PortfolioPrivacySettings({
    this.isPublic = true,
    this.showTradeAmounts = false,
    this.showHoldings = true,
    this.showTrades = true,
    this.allowFollowers = true,
  });

  factory PortfolioPrivacySettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PortfolioPrivacySettings();
    return PortfolioPrivacySettings(
      isPublic: json['isPublic'] as bool? ?? true,
      showTradeAmounts: json['showTradeAmounts'] as bool? ?? false,
      showHoldings: json['showHoldings'] as bool? ?? true,
      showTrades: json['showTrades'] as bool? ?? true,
      allowFollowers: json['allowFollowers'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isPublic': isPublic,
      'showTradeAmounts': showTradeAmounts,
      'showHoldings': showHoldings,
      'showTrades': showTrades,
      'allowFollowers': allowFollowers,
    };
  }

  PortfolioPrivacySettings copyWith({
    bool? isPublic,
    bool? showTradeAmounts,
    bool? showHoldings,
    bool? showTrades,
    bool? allowFollowers,
  }) {
    return PortfolioPrivacySettings(
      isPublic: isPublic ?? this.isPublic,
      showTradeAmounts: showTradeAmounts ?? this.showTradeAmounts,
      showHoldings: showHoldings ?? this.showHoldings,
      showTrades: showTrades ?? this.showTrades,
      allowFollowers: allowFollowers ?? this.allowFollowers,
    );
  }
}

// Gamma Exposure (GEX) data models.
//
// GEX measures the net gamma that market makers (dealers) hold across all
// open option contracts. Used as a trading regime indicator.

class GexStrikeLevel {
  final double strike;
  final double callGamma;
  final double putGamma;
  final double callOI;
  final double putOI;
  final double callGEX;
  final double putGEX;
  final double
      netGEX; // positive = long gamma (pinning), negative = short gamma (trending)

  const GexStrikeLevel({
    required this.strike,
    required this.callGamma,
    required this.putGamma,
    required this.callOI,
    required this.putOI,
    required this.callGEX,
    required this.putGEX,
    required this.netGEX,
  });

  factory GexStrikeLevel.fromJson(Map<String, dynamic> json) => GexStrikeLevel(
        strike: (json['strike'] as num).toDouble(),
        callGamma: (json['callGamma'] as num?)?.toDouble() ?? 0.0,
        putGamma: (json['putGamma'] as num?)?.toDouble() ?? 0.0,
        callOI: (json['callOI'] as num?)?.toDouble() ?? 0.0,
        putOI: (json['putOI'] as num?)?.toDouble() ?? 0.0,
        callGEX: (json['callGEX'] as num?)?.toDouble() ?? 0.0,
        putGEX: (json['putGEX'] as num?)?.toDouble() ?? 0.0,
        netGEX: (json['netGEX'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'strike': strike,
        'callGamma': callGamma,
        'putGamma': putGamma,
        'callOI': callOI,
        'putOI': putOI,
        'callGEX': callGEX,
        'putGEX': putGEX,
        'netGEX': netGEX,
      };
}

enum DealerPositioning {
  longGamma, // dealers long gamma → mean-reverting / price pinning
  shortGamma, // dealers short gamma → trend amplifying / volatile
  neutral,
}

extension DealerPositioningX on DealerPositioning {
  String get displayLabel {
    switch (this) {
      case DealerPositioning.longGamma:
        return 'Long Gamma';
      case DealerPositioning.shortGamma:
        return 'Short Gamma';
      case DealerPositioning.neutral:
        return 'Neutral';
    }
  }

  String get description {
    switch (this) {
      case DealerPositioning.longGamma:
        return 'Dealers are net long gamma. They buy dips and sell rips, '
            'creating a mean-reverting / price-pinning environment.';
      case DealerPositioning.shortGamma:
        return 'Dealers are net short gamma. They must buy as price rises and '
            'sell as it falls, amplifying directional moves.';
      case DealerPositioning.neutral:
        return 'Dealer gamma exposure is near zero. No strong directional bias '
            'from options market makers.';
    }
  }
}

class GammaExposureData {
  final String symbol;
  final double spotPrice;
  final double totalCallGEX;
  final double totalPutGEX;
  final double totalNetGEX;
  final double? gammaFlip; // strike where net GEX crosses zero
  final double? maxGammaStrike; // strike with highest absolute GEX
  final List<GexStrikeLevel> gexByStrike;
  final DealerPositioning dealerPositioning;
  final int signalStrength; // 0–100
  final int updatedAt; // epoch ms
  final String? expirationFilter;
  final double? callWall; // strike with highest callGEX
  final double? putWall; // strike with highest putGEX
  final double gexRatio; // call GEX relative ratio

  const GammaExposureData({
    required this.symbol,
    required this.spotPrice,
    required this.totalCallGEX,
    required this.totalPutGEX,
    required this.totalNetGEX,
    this.gammaFlip,
    this.maxGammaStrike,
    required this.gexByStrike,
    required this.dealerPositioning,
    required this.signalStrength,
    required this.updatedAt,
    this.expirationFilter,
    this.callWall,
    this.putWall,
    this.gexRatio = 0.5,
  });

  factory GammaExposureData.fromJson(Map<String, dynamic> json) {
    DealerPositioning positioning;
    switch (json['dealerPositioning'] as String?) {
      case 'long_gamma':
        positioning = DealerPositioning.longGamma;
        break;
      case 'short_gamma':
        positioning = DealerPositioning.shortGamma;
        break;
      default:
        positioning = DealerPositioning.neutral;
    }

    return GammaExposureData(
      symbol: json['symbol'] as String? ?? '',
      spotPrice: (json['spotPrice'] as num?)?.toDouble() ?? 0.0,
      totalCallGEX: (json['totalCallGEX'] as num?)?.toDouble() ?? 0.0,
      totalPutGEX: (json['totalPutGEX'] as num?)?.toDouble() ?? 0.0,
      totalNetGEX: (json['totalNetGEX'] as num?)?.toDouble() ?? 0.0,
      gammaFlip: (json['gammaFlip'] as num?)?.toDouble(),
      maxGammaStrike: (json['maxGammaStrike'] as num?)?.toDouble(),
      gexByStrike: (json['gexByStrike'] as List<dynamic>?)
              ?.map((e) =>
                  GexStrikeLevel.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      dealerPositioning: positioning,
      signalStrength: json['signalStrength'] as int? ?? 0,
      updatedAt: json['updatedAt'] as int? ?? 0,
      expirationFilter: json['expirationFilter'] as String?,
      callWall: (json['callWall'] as num?)?.toDouble(),
      putWall: (json['putWall'] as num?)?.toDouble(),
      gexRatio: (json['gexRatio'] as num?)?.toDouble() ?? 0.5,
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'spotPrice': spotPrice,
        'totalCallGEX': totalCallGEX,
        'totalPutGEX': totalPutGEX,
        'totalNetGEX': totalNetGEX,
        if (gammaFlip != null) 'gammaFlip': gammaFlip,
        if (maxGammaStrike != null) 'maxGammaStrike': maxGammaStrike,
        'gexByStrike': gexByStrike.map((e) => e.toJson()).toList(),
        if (expirationFilter != null) 'expirationFilter': expirationFilter,
        'dealerPositioning': dealerPositioning == DealerPositioning.longGamma
            ? 'long_gamma'
            : dealerPositioning == DealerPositioning.shortGamma
                ? 'short_gamma'
                : 'neutral',
        'signalStrength': signalStrength,
        'updatedAt': updatedAt,
        if (callWall != null) 'callWall': callWall,
        if (putWall != null) 'putWall': putWall,
        'gexRatio': gexRatio,
      };

  /// Returns the strikes closest to spot price, useful for focused chart view.
  List<GexStrikeLevel> get nearMoneyStrikes {
    if (gexByStrike.isEmpty) return gexByStrike;
    final sorted = [...gexByStrike]..sort((a, b) =>
        (a.strike - spotPrice).abs().compareTo((b.strike - spotPrice).abs()));
    return sorted.take(20).toList()
      ..sort((a, b) => a.strike.compareTo(b.strike));
  }

  /// Returns the visible strikes for chart or table, ensuring crucial levels
  /// (Call Wall, Put Wall, Gamma Flip, Max Gamma Strike) are guaranteed to be included.
  List<GexStrikeLevel> getVisibleStrikes({int count = 20}) {
    if (gexByStrike.isEmpty) return gexByStrike;
    
    // Take the closest ones to spot
    final sorted = [...gexByStrike]..sort((a, b) =>
        (a.strike - spotPrice).abs().compareTo((b.strike - spotPrice).abs()));
    final baseList = sorted.take(count).toList();
    
    final includedStrikes = baseList.map((e) => e.strike).toSet();
    
    void addKeyLevel(double? targetStrike) {
      if (targetStrike == null) return;
      final matches = gexByStrike.where((e) => (e.strike - targetStrike).abs() < 0.01);
      if (matches.isNotEmpty) {
        final match = matches.first;
        if (!includedStrikes.contains(match.strike)) {
          baseList.add(match);
          includedStrikes.add(match.strike);
        }
      }
    }
    
    addKeyLevel(callWall);
    addKeyLevel(putWall);
    addKeyLevel(gammaFlip);
    addKeyLevel(maxGammaStrike);
    
    baseList.sort((a, b) => a.strike.compareTo(b.strike));
    return baseList;
  }

  /// Net GEX formatted in billions/millions for display.
  String get formattedNetGEX {
    final abs = totalNetGEX.abs();
    final sign = totalNetGEX >= 0 ? '+' : '-';
    if (abs >= 1e9) return '$sign\$${(abs / 1e9).toStringAsFixed(2)}B';
    if (abs >= 1e6) return '$sign\$${(abs / 1e6).toStringAsFixed(0)}M';
    return '$sign\$${abs.toStringAsFixed(0)}';
  }
}

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

class GexSensitivity {
  final double spotMinus2Pct;
  final double spotMinus1Pct;
  final double spotCurrent;
  final double spotPlus1Pct;
  final double spotPlus2Pct;

  const GexSensitivity({
    required this.spotMinus2Pct,
    required this.spotMinus1Pct,
    required this.spotCurrent,
    required this.spotPlus1Pct,
    required this.spotPlus2Pct,
  });

  factory GexSensitivity.fromJson(Map<String, dynamic> json) => GexSensitivity(
        spotMinus2Pct: (json['spotMinus2Pct'] as num?)?.toDouble() ?? 0.0,
        spotMinus1Pct: (json['spotMinus1Pct'] as num?)?.toDouble() ?? 0.0,
        spotCurrent: (json['spotCurrent'] as num?)?.toDouble() ?? 0.0,
        spotPlus1Pct: (json['spotPlus1Pct'] as num?)?.toDouble() ?? 0.0,
        spotPlus2Pct: (json['spotPlus2Pct'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'spotMinus2Pct': spotMinus2Pct,
        'spotMinus1Pct': spotMinus1Pct,
        'spotCurrent': spotCurrent,
        'spotPlus1Pct': spotPlus1Pct,
        'spotPlus2Pct': spotPlus2Pct,
      };
}

class GexKeyLevel {
  final String label;
  final double price;
  final double distanceFromSpotPercent;

  const GexKeyLevel({
    required this.label,
    required this.price,
    required this.distanceFromSpotPercent,
  });
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
  final double? pTrans; // nearest positive GEX transition at/above spot
  final double? nTrans; // nearest negative GEX transition below spot
  final double? cotmp; // center of put mass
  final double? plusGex; // positive GEX target
  final double gexRatio; // call GEX relative ratio
  final double riskFreeRate; // interest rate used
  final GexSensitivity? gexSensitivity;

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
    this.pTrans,
    this.nTrans,
    this.cotmp,
    this.plusGex,
    this.gexRatio = 0.5,
    this.riskFreeRate = 0.05,
    this.gexSensitivity,
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
      pTrans: (json['pTrans'] as num?)?.toDouble(),
      nTrans: (json['nTrans'] as num?)?.toDouble(),
      cotmp: (json['cotmp'] as num?)?.toDouble(),
      plusGex: (json['plusGex'] as num?)?.toDouble(),
      gexRatio: (json['gexRatio'] as num?)?.toDouble() ?? 0.5,
      riskFreeRate: (json['riskFreeRate'] as num?)?.toDouble() ?? 0.05,
      gexSensitivity: json['gexSensitivity'] != null
          ? GexSensitivity.fromJson(
              Map<String, dynamic>.from(json['gexSensitivity'] as Map))
          : null,
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
        if (pTrans != null) 'pTrans': pTrans,
        if (nTrans != null) 'nTrans': nTrans,
        if (cotmp != null) 'cotmp': cotmp,
        if (plusGex != null) 'plusGex': plusGex,
        'gexRatio': gexRatio,
        'riskFreeRate': riskFreeRate,
        if (gexSensitivity != null) 'gexSensitivity': gexSensitivity!.toJson(),
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
  /// (walls, transitions, targets, Gamma Flip, Max Gamma Strike) are included.
  List<GexStrikeLevel> getVisibleStrikes({int count = 20}) {
    if (gexByStrike.isEmpty) return gexByStrike;

    // Take the closest ones to spot
    final sorted = [...gexByStrike]..sort((a, b) =>
        (a.strike - spotPrice).abs().compareTo((b.strike - spotPrice).abs()));
    final baseList = sorted.take(count).toList();

    final includedStrikes = baseList.map((e) => e.strike).toSet();

    void addKeyLevel(double? targetStrike) {
      if (targetStrike == null) return;
      final matches =
          gexByStrike.where((e) => (e.strike - targetStrike).abs() < 0.01);
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
    addKeyLevel(pTrans);
    addKeyLevel(nTrans);
    addKeyLevel(cotmp);
    addKeyLevel(plusGex);

    baseList.sort((a, b) => a.strike.compareTo(b.strike));
    return baseList;
  }

  Duration ageAt(DateTime now) {
    if (updatedAt <= 0) return const Duration(days: 36500);
    final age = now.difference(
      DateTime.fromMillisecondsSinceEpoch(updatedAt),
    );
    return age.isNegative ? Duration.zero : age;
  }

  bool isStaleAt(
    DateTime now, {
    Duration threshold = const Duration(hours: 4),
  }) =>
      updatedAt <= 0 || ageAt(now) > threshold;

  GexKeyLevel? get nearestKeyLevel {
    if (spotPrice <= 0) return null;

    final levels = <String, double?>{
      'Zero Gamma': gammaFlip,
      'Call Wall': callWall,
      'Put Wall': putWall,
      'Max Gamma': maxGammaStrike,
    };
    final uniquePrices = <double>{};
    final candidates = <GexKeyLevel>[];

    for (final entry in levels.entries) {
      final price = entry.value;
      if (price == null || price <= 0 || !uniquePrices.add(price)) continue;
      candidates.add(GexKeyLevel(
        label: entry.key,
        price: price,
        distanceFromSpotPercent: ((price - spotPrice) / spotPrice) * 100,
      ));
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.distanceFromSpotPercent
        .abs()
        .compareTo(b.distanceFromSpotPercent.abs()));
    return candidates.first;
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

class PortfolioGexSummary {
  final double netGEX;
  final double grossGEX;
  final double dampeningGEX;
  final double amplifyingGEX;
  final double topConcentration;
  final int dampeningSymbols;
  final int amplifyingSymbols;
  final DealerPositioning positioning;

  const PortfolioGexSummary({
    required this.netGEX,
    required this.grossGEX,
    required this.dampeningGEX,
    required this.amplifyingGEX,
    required this.topConcentration,
    required this.dampeningSymbols,
    required this.amplifyingSymbols,
    required this.positioning,
  });

  factory PortfolioGexSummary.fromData(Iterable<GammaExposureData> data) {
    double netGEX = 0;
    double dampeningGEX = 0;
    double amplifyingGEX = 0;
    double largestAbsoluteGEX = 0;
    int dampeningSymbols = 0;
    int amplifyingSymbols = 0;

    for (final item in data) {
      netGEX += item.totalNetGEX;
      final absoluteGEX = item.totalNetGEX.abs();
      if (absoluteGEX > largestAbsoluteGEX) {
        largestAbsoluteGEX = absoluteGEX;
      }
      if (item.totalNetGEX > 0) {
        dampeningGEX += item.totalNetGEX;
        dampeningSymbols++;
      } else if (item.totalNetGEX < 0) {
        amplifyingGEX += absoluteGEX;
        amplifyingSymbols++;
      }
    }

    final grossGEX = dampeningGEX + amplifyingGEX;
    final netToGrossRatio = grossGEX == 0 ? 0 : netGEX.abs() / grossGEX;
    final positioning = grossGEX == 0 || netToGrossRatio < 0.1
        ? DealerPositioning.neutral
        : netGEX > 0
            ? DealerPositioning.longGamma
            : DealerPositioning.shortGamma;

    return PortfolioGexSummary(
      netGEX: netGEX,
      grossGEX: grossGEX,
      dampeningGEX: dampeningGEX,
      amplifyingGEX: amplifyingGEX,
      topConcentration: grossGEX == 0 ? 0 : largestAbsoluteGEX / grossGEX,
      dampeningSymbols: dampeningSymbols,
      amplifyingSymbols: amplifyingSymbols,
      positioning: positioning,
    );
  }

  double get dampeningShare => grossGEX == 0 ? 0.5 : dampeningGEX / grossGEX;

  bool get hasMixedExposure => dampeningSymbols > 0 && amplifyingSymbols > 0;
}

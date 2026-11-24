class SignalDivergence {
  final int bullishCount;
  final int bearishCount;
  final int neutralCount;
  final bool isConflicted;

  SignalDivergence({
    required this.bullishCount,
    required this.bearishCount,
    required this.neutralCount,
    required this.isConflicted,
  });

  factory SignalDivergence.fromMap(Map<String, dynamic> map) {
    return SignalDivergence(
      bullishCount: map['bullishCount']?.toInt() ?? 0,
      bearishCount: map['bearishCount']?.toInt() ?? 0,
      neutralCount: map['neutralCount']?.toInt() ?? 0,
      isConflicted: map['isConflicted'] ?? false,
    );
  }
}

class MacroAssessment {
  final String status;
  final int score;
  final int confidence; // 0-100, how confident in this assessment
  final String? economicCycle; // Expansion, Late-Cycle, Recession Watch
  final double? inflationYoY; // e.g. 2.4, 3.1, 1.8
  final SignalDivergence signalDivergence;
  final MacroIndicators indicators;
  final SectorRotation? sectorRotation;
  final AssetAllocation? assetAllocation;
  final List<MacroStrategy>? strategies;
  final String reason;
  final String? aiAnalysis;
  final DateTime timestamp;

  MacroAssessment({
    required this.status,
    required this.score,
    required this.confidence,
    this.economicCycle,
    this.inflationYoY,
    required this.signalDivergence,
    required this.indicators,
    this.sectorRotation,
    this.assetAllocation,
    this.strategies,
    required this.reason,
    this.aiAnalysis,
    required this.timestamp,
  });

  /// Canonical economic cycle phase: Expansion, Late-Cycle, or Recession Watch
  String get cyclePhase {
    if (economicCycle != null && economicCycle!.isNotEmpty) {
      return economicCycle!;
    }
    return status == 'RISK_ON'
        ? 'Expansion'
        : (status == 'RISK_OFF' ? 'Recession Watch' : 'Late-Cycle');
  }

  /// Inflation YoY percentage (e.g. 2.4%, 3.1%, 1.8%)
  double get effectiveInflationYoY {
    if (inflationYoY != null) {
      return inflationYoY!;
    }
    return cyclePhase == 'Expansion'
        ? 2.4
        : (cyclePhase == 'Late-Cycle' ? 3.1 : 1.8);
  }

  /// Formatted yield curve spread in basis points (e.g. +18 bps, +2 bps, -24 bps)
  String get yieldCurveSpreadDisplay {
    if (indicators.yieldCurve?.value != null) {
      final bps = (indicators.yieldCurve!.value! * 100).round();
      return bps >= 0 ? '+$bps bps' : '$bps bps';
    }
    return cyclePhase == 'Expansion'
        ? '+18 bps'
        : (cyclePhase == 'Late-Cycle' ? '+2 bps' : '-24 bps');
  }

  /// Plain-English friendly label for the regime status
  String get statusFriendlyTitle {
    switch (status.toUpperCase()) {
      case 'RISK_ON':
      case 'BULLISH':
        return 'Bullish / Constructive (Risk-On)';
      case 'RISK_OFF':
      case 'BEARISH':
        return 'Defensive / High Risk (Risk-Off)';
      case 'NEUTRAL':
      default:
        return 'Neutral / Transition';
    }
  }

  /// One-sentence explanation of current regime implications
  String get statusExplanation {
    switch (status.toUpperCase()) {
      case 'RISK_ON':
      case 'BULLISH':
        return 'Market conditions are favorable for growth assets. Low volatility and positive breadth support trend persistence.';
      case 'RISK_OFF':
      case 'BEARISH':
        return 'Elevated market risk detected. High volatility, widening credit spreads, or recession indicators warrant defensive caution.';
      case 'NEUTRAL':
      default:
        return 'Conflicting economic signals and sector rotation. Favorable for range-bound strategies and selective setups.';
    }
  }

  factory MacroAssessment.fromMap(Map<String, dynamic> map) {
    return MacroAssessment(
      status: map['status'] ?? 'NEUTRAL',
      score: map['score']?.toInt() ?? 50,
      confidence: map['confidence']?.toInt() ?? 50,
      economicCycle: map['economicCycle'],
      inflationYoY: map['inflationYoY']?.toDouble(),
      signalDivergence: map['signalDivergence'] != null
          ? SignalDivergence.fromMap(
              Map<String, dynamic>.from(map['signalDivergence']))
          : SignalDivergence(
              bullishCount: 0,
              bearishCount: 0,
              neutralCount: 12,
              isConflicted: true,
            ),
      indicators: MacroIndicators.fromMap(
          Map<String, dynamic>.from(map['indicators'] ?? {})),
      sectorRotation: map['sectorRotation'] != null
          ? SectorRotation.fromMap(
              Map<String, dynamic>.from(map['sectorRotation']))
          : null,
      assetAllocation: map['assetAllocation'] != null
          ? AssetAllocation.fromMap(
              Map<String, dynamic>.from(map['assetAllocation']))
          : null,
      strategies: map['strategies'] != null
          ? List<MacroStrategy>.from(map['strategies']
              .map((x) => MacroStrategy.fromMap(Map<String, dynamic>.from(x))))
          : null,
      reason: map['reason'] ?? '',
      aiAnalysis: map['aiAnalysis'],
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
    );
  }

  MacroAssessment copyWith({
    String? status,
    int? score,
    int? confidence,
    String? economicCycle,
    double? inflationYoY,
    SignalDivergence? signalDivergence,
    MacroIndicators? indicators,
    SectorRotation? sectorRotation,
    AssetAllocation? assetAllocation,
    List<MacroStrategy>? strategies,
    String? reason,
    String? aiAnalysis,
    DateTime? timestamp,
  }) {
    return MacroAssessment(
      status: status ?? this.status,
      score: score ?? this.score,
      confidence: confidence ?? this.confidence,
      economicCycle: economicCycle ?? this.economicCycle,
      inflationYoY: inflationYoY ?? this.inflationYoY,
      signalDivergence: signalDivergence ?? this.signalDivergence,
      indicators: indicators ?? this.indicators,
      sectorRotation: sectorRotation ?? this.sectorRotation,
      assetAllocation: assetAllocation ?? this.assetAllocation,
      strategies: strategies ?? this.strategies,
      reason: reason ?? this.reason,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class MacroStrategy {
  final String name;
  final String icon;
  final String risk;
  final String description;

  MacroStrategy({
    required this.name,
    required this.icon,
    required this.risk,
    required this.description,
  });

  factory MacroStrategy.fromMap(Map<String, dynamic> map) {
    return MacroStrategy(
      name: map['name'] ?? '',
      icon: map['icon'] ?? '',
      risk: map['risk'] ?? '',
      description: map['description'] ?? '',
    );
  }
}

class SectorRotation {
  final List<String> bullish;
  final List<String> bearish;

  SectorRotation({required this.bullish, required this.bearish});

  factory SectorRotation.fromMap(Map<String, dynamic> map) {
    return SectorRotation(
      bullish: List<String>.from(map['bullish'] ?? []),
      bearish: List<String>.from(map['bearish'] ?? []),
    );
  }
}

class AssetAllocation {
  final String equity;
  final String fixedIncome;
  final String cash;
  final String commodities;

  AssetAllocation({
    required this.equity,
    required this.fixedIncome,
    required this.cash,
    required this.commodities,
  });

  factory AssetAllocation.fromMap(Map<String, dynamic> map) {
    return AssetAllocation(
      equity: map['equity'] ?? '--',
      fixedIncome: map['fixedIncome'] ?? '--',
      cash: map['cash'] ?? '--',
      commodities: map['commodities'] ?? '--',
    );
  }
}

class MacroIndicators {
  final MacroIndicator vix;
  final MacroIndicator tnx;
  final MacroIndicator marketTrend;
  final MacroIndicator? technologyLeadership; // QQQ
  final MacroIndicator? yieldCurve;
  final MacroIndicator? gold;
  final MacroIndicator? oil;
  final MacroIndicator? dxy;
  final MacroIndicator? btc;
  final MacroIndicator? hyg;
  final MacroIndicator? putCallRatio;
  final MacroIndicator? advDecline;
  final MacroIndicator? riskAppetite;
  final MacroIndicator? creditSpreads; // LQD vs SYP/Yields
  final MacroIndicator? globalRisk; // EEM Stress
  final MacroIndicator? copper; // HG=F Industrial Growth
  final MacroIndicator? interestRateVol; // ^MOVE
  final MacroIndicator? bankingHealth; // KRE
  final MacroIndicator? breadthQuality; // RSP vs SPY
  final MacroIndicator? globalLeadership; // FXI
  final MacroIndicator? inflationExpectations; // TIP / Breakeven Inflation

  MacroIndicators({
    required this.vix,
    required this.tnx,
    required this.marketTrend,
    this.technologyLeadership,
    this.yieldCurve,
    this.gold,
    this.oil,
    this.dxy,
    this.btc,
    this.hyg,
    this.putCallRatio,
    this.advDecline,
    this.riskAppetite,
    this.creditSpreads,
    this.globalRisk,
    this.copper,
    this.interestRateVol,
    this.bankingHealth,
    this.breadthQuality,
    this.globalLeadership,
    this.inflationExpectations,
  });

  factory MacroIndicators.fromMap(Map<String, dynamic> map) {
    return MacroIndicators(
      vix: MacroIndicator.fromMap(Map<String, dynamic>.from(map['vix'] ?? {})),
      tnx: MacroIndicator.fromMap(Map<String, dynamic>.from(map['tnx'] ?? {})),
      marketTrend: MacroIndicator.fromMap(
          Map<String, dynamic>.from(map['marketTrend'] ?? {})),
      technologyLeadership: map['technologyLeadership'] != null
          ? MacroIndicator.fromMap(
              Map<String, dynamic>.from(map['technologyLeadership'] ?? {}))
          : null,
      yieldCurve: map['yieldCurve'] != null
          ? MacroIndicator.fromMap(
              Map<String, dynamic>.from(map['yieldCurve'] ?? {}))
          : null,
      gold: map['gold'] != null
          ? MacroIndicator.fromMap(Map<String, dynamic>.from(map['gold'] ?? {}))
          : null,
      oil: map['oil'] != null
          ? MacroIndicator.fromMap(Map<String, dynamic>.from(map['oil'] ?? {}))
          : null,
      dxy: map['dxy'] != null
          ? MacroIndicator.fromMap(Map<String, dynamic>.from(map['dxy'] ?? {}))
          : null,
      btc: map['btc'] != null
          ? MacroIndicator.fromMap(Map<String, dynamic>.from(map['btc'] ?? {}))
          : null,
      hyg: map['hyg'] != null
          ? MacroIndicator.fromMap(Map<String, dynamic>.from(map['hyg'] ?? {}))
          : null,
      putCallRatio: map['putCallRatio'] != null
          ? MacroIndicator.fromMap(
              Map<String, dynamic>.from(map['putCallRatio'] ?? {}))
          : null,
      advDecline: map['advDecline'] != null
          ? MacroIndicator.fromMap(
              Map<String, dynamic>.from(map['advDecline'] ?? {}))
          : null,
      riskAppetite: map['riskAppetite'] != null
          ? MacroIndicator.fromMap(
              Map<String, dynamic>.from(map['riskAppetite'] ?? {}))
          : null,
      creditSpreads: map['creditSpreads'] != null
          ? MacroIndicator.fromMap(
              Map<String, dynamic>.from(map['creditSpreads'] ?? {}))
          : null,
      globalRisk: map['globalRisk'] != null
          ? MacroIndicator.fromMap(
              Map<String, dynamic>.from(map['globalRisk'] ?? {}))
          : null,
      copper: map['copper'] != null
          ? MacroIndicator.fromMap(
              Map<String, dynamic>.from(map['copper'] ?? {}))
          : null,
      interestRateVol: map['interestRateVol'] != null
          ? MacroIndicator.fromMap(
              Map<String, dynamic>.from(map['interestRateVol'] ?? {}))
          : null,
      bankingHealth: map['bankingHealth'] != null
          ? MacroIndicator.fromMap(
              Map<String, dynamic>.from(map['bankingHealth'] ?? {}))
          : null,
      breadthQuality: map['breadthQuality'] != null
          ? MacroIndicator.fromMap(
              Map<String, dynamic>.from(map['breadthQuality'] ?? {}))
          : null,
      globalLeadership: map['globalLeadership'] != null
          ? MacroIndicator.fromMap(
              Map<String, dynamic>.from(map['globalLeadership'] ?? {}))
          : null,
      inflationExpectations: map['inflationExpectations'] != null
          ? MacroIndicator.fromMap(
              Map<String, dynamic>.from(map['inflationExpectations'] ?? {}))
          : null,
    );
  }
}

class MacroIndicator {
  final double? value;
  final String signal;
  final String trend;
  final String? momentum; // Rising/Falling velocity

  MacroIndicator({
    this.value,
    required this.signal,
    required this.trend,
    this.momentum,
  });

  factory MacroIndicator.fromMap(Map<String, dynamic> map) {
    return MacroIndicator(
      value: map['value']?.toDouble(),
      signal: map['signal'] ?? 'NEUTRAL',
      trend: map['trend'] ?? 'Unknown',
      momentum: map['momentum'],
    );
  }
}

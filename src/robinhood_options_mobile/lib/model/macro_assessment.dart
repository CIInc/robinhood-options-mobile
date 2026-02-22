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
    required this.signalDivergence,
    required this.indicators,
    this.sectorRotation,
    this.assetAllocation,
    this.strategies,
    required this.reason,
    this.aiAnalysis,
    required this.timestamp,
  });

  factory MacroAssessment.fromMap(Map<String, dynamic> map) {
    return MacroAssessment(
      status: map['status'] ?? 'NEUTRAL',
      score: map['score']?.toInt() ?? 50,
      confidence: map['confidence']?.toInt() ?? 50,
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
  final MacroIndicator? yieldCurve;
  final MacroIndicator? gold;
  final MacroIndicator? oil;
  final MacroIndicator? dxy;
  final MacroIndicator? btc;
  final MacroIndicator? hyg;
  final MacroIndicator? putCallRatio;
  final MacroIndicator? advDecline;
  final MacroIndicator? riskAppetite;

  MacroIndicators({
    required this.vix,
    required this.tnx,
    required this.marketTrend,
    this.yieldCurve,
    this.gold,
    this.oil,
    this.dxy,
    this.btc,
    this.hyg,
    this.putCallRatio,
    this.advDecline,
    this.riskAppetite,
  });

  factory MacroIndicators.fromMap(Map<String, dynamic> map) {
    return MacroIndicators(
      vix: MacroIndicator.fromMap(Map<String, dynamic>.from(map['vix'] ?? {})),
      tnx: MacroIndicator.fromMap(Map<String, dynamic>.from(map['tnx'] ?? {})),
      marketTrend: MacroIndicator.fromMap(
          Map<String, dynamic>.from(map['marketTrend'] ?? {})),
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

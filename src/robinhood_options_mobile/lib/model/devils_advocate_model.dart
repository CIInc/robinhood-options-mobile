class ThesisCounterArgument {
  final String title;
  final String argument;
  final String severity; // High, Medium, Low

  ThesisCounterArgument({
    required this.title,
    required this.argument,
    this.severity = 'Medium',
  });

  factory ThesisCounterArgument.fromJson(Map<String, dynamic> json) {
    return ThesisCounterArgument(
      title: json['title'] ?? '',
      argument: json['argument'] ?? '',
      severity: json['severity'] ?? 'Medium',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'argument': argument,
      'severity': severity,
    };
  }
}

class SkewTrap {
  final String title;
  final String description;
  final String severity; // High, Medium, Low

  SkewTrap({
    required this.title,
    required this.description,
    this.severity = 'Medium',
  });

  factory SkewTrap.fromJson(Map<String, dynamic> json) {
    return SkewTrap(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      severity: json['severity'] ?? 'Medium',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'severity': severity,
    };
  }
}

class EventHazard {
  final String event;
  final String timing;
  final String risk;
  final String hazardLevel; // High, Medium, Low

  EventHazard({
    required this.event,
    required this.timing,
    required this.risk,
    this.hazardLevel = 'Medium',
  });

  factory EventHazard.fromJson(Map<String, dynamic> json) {
    return EventHazard(
      event: json['event'] ?? '',
      timing: json['timing'] ?? '',
      risk: json['risk'] ?? '',
      hazardLevel: json['hazard_level'] ?? json['hazardLevel'] ?? 'Medium',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event': event,
      'timing': timing,
      'risk': risk,
      'hazard_level': hazardLevel,
    };
  }
}

class StressScenario {
  final String scenario;
  final String projectedImpact;
  final String assessment;

  StressScenario({
    required this.scenario,
    required this.projectedImpact,
    required this.assessment,
  });

  factory StressScenario.fromJson(Map<String, dynamic> json) {
    return StressScenario(
      scenario: json['scenario'] ?? '',
      projectedImpact: json['projected_impact'] ?? json['projectedImpact'] ?? '',
      assessment: json['assessment'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scenario': scenario,
      'projected_impact': projectedImpact,
      'assessment': assessment,
    };
  }
}

class DevilsAdvocateAnalysis {
  final String symbol;
  final String direction;
  final double resilienceScore; // 0-100
  final String verdict; // Fragile, Moderate, Resilient
  final String killerQuestion;
  final List<ThesisCounterArgument> counterArguments;
  final List<SkewTrap> skewTraps;
  final List<EventHazard> eventHazards;
  final List<StressScenario> stressScenarios;
  final String summary;
  final DateTime? lastUpdated;

  DevilsAdvocateAnalysis({
    required this.symbol,
    this.direction = 'Bullish',
    this.resilienceScore = 50.0,
    this.verdict = 'Moderate',
    required this.killerQuestion,
    this.counterArguments = const [],
    this.skewTraps = const [],
    this.eventHazards = const [],
    this.stressScenarios = const [],
    required this.summary,
    this.lastUpdated,
  });

  factory DevilsAdvocateAnalysis.fromJson(Map<String, dynamic> json) {
    return DevilsAdvocateAnalysis(
      symbol: (json['symbol'] ?? '').toString().toUpperCase(),
      direction: json['direction'] ?? 'Bullish',
      resilienceScore: (json['resilience_score'] as num?)?.toDouble() ?? 50.0,
      verdict: json['verdict'] ?? 'Moderate',
      killerQuestion: json['killer_question'] ?? '',
      counterArguments: (json['counter_arguments'] as List<dynamic>?)
              ?.map((e) =>
                  ThesisCounterArgument.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      skewTraps: (json['skew_traps'] as List<dynamic>?)
              ?.map((e) => SkewTrap.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      eventHazards: (json['event_hazards'] as List<dynamic>?)
              ?.map((e) => EventHazard.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      stressScenarios: (json['stress_scenarios'] as List<dynamic>?)
              ?.map((e) => StressScenario.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      summary: json['summary'] ?? '',
      lastUpdated: json['last_updated'] != null
          ? DateTime.tryParse(json['last_updated'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'direction': direction,
      'resilience_score': resilienceScore,
      'verdict': verdict,
      'killer_question': killerQuestion,
      'counter_arguments': counterArguments.map((e) => e.toJson()).toList(),
      'skew_traps': skewTraps.map((e) => e.toJson()).toList(),
      'event_hazards': eventHazards.map((e) => e.toJson()).toList(),
      'stress_scenarios': stressScenarios.map((e) => e.toJson()).toList(),
      'summary': summary,
      'last_updated': lastUpdated?.toIso8601String(),
    };
  }
}

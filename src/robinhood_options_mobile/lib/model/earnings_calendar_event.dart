/// Represents a scheduled or historical company earnings announcement.
class EarningsCalendarEvent {
  final String symbol;
  final DateTime date;
  final String? timing; // 'am', 'pm', or null
  final int? year;
  final int? quarter;
  final double? epsEstimate;
  final double? epsActual;
  final DateTime? callDateTime;
  final bool verified;
  final double? sharesHeld;
  final int? contractsHeld;

  const EarningsCalendarEvent({
    required this.symbol,
    required this.date,
    this.timing,
    this.year,
    this.quarter,
    this.epsEstimate,
    this.epsActual,
    this.callDateTime,
    this.verified = false,
    this.sharesHeld,
    this.contractsHeld,
  });

  /// Calculates calendar day difference from [now].
  int daysUntil(DateTime now) {
    final reportDay = DateTime(date.year, date.month, date.day);
    final currentDay = DateTime(now.year, now.month, now.day);
    return reportDay.difference(currentDay).inDays;
  }

  /// Human-readable timing representation (AM / PM / BMO / AMC).
  String get timingDisplay {
    final t = timing?.toLowerCase().trim();
    if (t == 'am' || t == 'bmo') {
      return 'Before Open';
    } else if (t == 'pm' || t == 'amc') {
      return 'After Close';
    }
    return '';
  }

  /// Compact timing tag e.g. "BMO" or "AMC".
  String get timingTag {
    final t = timing?.toLowerCase().trim();
    if (t == 'am' || t == 'bmo') {
      return 'BMO';
    } else if (t == 'pm' || t == 'amc') {
      return 'AMC';
    }
    return '';
  }

  /// Formatted EPS estimate e.g. "$1.45" or null.
  String? get formattedEstimate {
    if (epsEstimate == null) return null;
    return '\$${epsEstimate!.toStringAsFixed(2)}';
  }

  /// Copies this event with updated position quantities.
  EarningsCalendarEvent copyWith({
    String? symbol,
    DateTime? date,
    String? timing,
    int? year,
    int? quarter,
    double? epsEstimate,
    double? epsActual,
    DateTime? callDateTime,
    bool? verified,
    double? sharesHeld,
    int? contractsHeld,
  }) {
    return EarningsCalendarEvent(
      symbol: symbol ?? this.symbol,
      date: date ?? this.date,
      timing: timing ?? this.timing,
      year: year ?? this.year,
      quarter: quarter ?? this.quarter,
      epsEstimate: epsEstimate ?? this.epsEstimate,
      epsActual: epsActual ?? this.epsActual,
      callDateTime: callDateTime ?? this.callDateTime,
      verified: verified ?? this.verified,
      sharesHeld: sharesHeld ?? this.sharesHeld,
      contractsHeld: contractsHeld ?? this.contractsHeld,
    );
  }

  /// Parses an element from Robinhood's `marketdata/earnings/` endpoint.
  factory EarningsCalendarEvent.fromRobinhoodJson(
    dynamic json, {
    String? defaultSymbol,
    double? sharesHeld,
    int? contractsHeld,
  }) {
    if (json is! Map) {
      throw ArgumentError('Expected Map but received ${json.runtimeType}');
    }

    final symbol = (json['symbol'] ?? defaultSymbol ?? '').toString();
    final report = json['report'];
    final dateStr = report is Map ? report['date']?.toString() : null;
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

    final timing = report is Map ? report['timing']?.toString() : null;
    final verified = report is Map && report['verified'] == true;

    final year = json['year'] is int ? json['year'] as int : null;
    final quarter = json['quarter'] is int ? json['quarter'] as int : null;

    double? epsEst;
    double? epsAct;
    final eps = json['eps'];
    if (eps is Map) {
      if (eps['estimate'] != null) {
        epsEst = double.tryParse(eps['estimate'].toString());
      }
      if (eps['actual'] != null) {
        epsAct = double.tryParse(eps['actual'].toString());
      }
    }

    DateTime? callDate;
    final call = json['call'];
    if (call is Map && call['datetime'] != null) {
      callDate = DateTime.tryParse(call['datetime'].toString());
    }

    return EarningsCalendarEvent(
      symbol: symbol,
      date: date ?? DateTime.now(),
      timing: timing,
      year: year,
      quarter: quarter,
      epsEstimate: epsEst,
      epsActual: epsAct,
      callDateTime: callDate,
      verified: verified,
      sharesHeld: sharesHeld,
      contractsHeld: contractsHeld,
    );
  }

  factory EarningsCalendarEvent.fromJson(Map<String, dynamic> json) {
    return EarningsCalendarEvent(
      symbol: (json['symbol'] ?? '').toString(),
      date: DateTime.parse(json['date'] as String),
      timing: json['timing']?.toString(),
      year: json['year'] as int?,
      quarter: json['quarter'] as int?,
      epsEstimate: (json['epsEstimate'] as num?)?.toDouble(),
      epsActual: (json['epsActual'] as num?)?.toDouble(),
      callDateTime: json['callDateTime'] != null
          ? DateTime.tryParse(json['callDateTime'] as String)
          : null,
      verified: json['verified'] as bool? ?? false,
      sharesHeld: (json['sharesHeld'] as num?)?.toDouble(),
      contractsHeld: json['contractsHeld'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'date': date.toIso8601String(),
        if (timing != null) 'timing': timing,
        if (year != null) 'year': year,
        if (quarter != null) 'quarter': quarter,
        if (epsEstimate != null) 'epsEstimate': epsEstimate,
        if (epsActual != null) 'epsActual': epsActual,
        if (callDateTime != null)
          'callDateTime': callDateTime!.toIso8601String(),
        'verified': verified,
        if (sharesHeld != null) 'sharesHeld': sharesHeld,
        if (contractsHeld != null) 'contractsHeld': contractsHeld,
      };
}

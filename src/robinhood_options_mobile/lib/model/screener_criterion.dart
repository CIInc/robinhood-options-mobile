import 'package:robinhood_options_mobile/model/instrument.dart';

enum ScreenerField {
  sector,
  marketCap,
  peRatio,
  dividendYield,
  price,
  volume,
  pbRatio,
  fiftyTwoWeekPosition,
}

extension ScreenerFieldDetails on ScreenerField {
  String get label {
    switch (this) {
      case ScreenerField.sector:
        return 'Sector';
      case ScreenerField.marketCap:
        return 'Market cap';
      case ScreenerField.peRatio:
        return 'P/E ratio';
      case ScreenerField.dividendYield:
        return 'Dividend yield';
      case ScreenerField.price:
        return 'Price';
      case ScreenerField.volume:
        return 'Average volume';
      case ScreenerField.pbRatio:
        return 'P/B ratio';
      case ScreenerField.fiftyTwoWeekPosition:
        return '52-week position';
    }
  }

  bool get isText => this == ScreenerField.sector;

  String get unit {
    switch (this) {
      case ScreenerField.marketCap:
        return 'USD';
      case ScreenerField.dividendYield:
      case ScreenerField.fiftyTwoWeekPosition:
        return '%';
      case ScreenerField.price:
        return 'USD';
      case ScreenerField.volume:
        return 'shares';
      case ScreenerField.peRatio:
      case ScreenerField.pbRatio:
      case ScreenerField.sector:
        return '';
    }
  }
}

class ScreenerCriterion {
  final ScreenerField field;
  final double? minimum;
  final double? maximum;
  final String? textValue;

  const ScreenerCriterion({
    required this.field,
    this.minimum,
    this.maximum,
    this.textValue,
  });

  bool get isValid {
    if (field.isText) return textValue != null && textValue!.isNotEmpty;
    if (minimum == null && maximum == null) return false;
    return minimum == null || maximum == null || minimum! <= maximum!;
  }

  bool matches(Instrument instrument) {
    if (!isValid) return false;
    if (field == ScreenerField.sector) {
      return instrument.fundamentalsObj?.sector == textValue;
    }

    final fundamentals = instrument.fundamentalsObj;
    final value = switch (field) {
      ScreenerField.marketCap => fundamentals?.marketCap,
      ScreenerField.peRatio => fundamentals?.peRatio,
      ScreenerField.dividendYield => fundamentals?.dividendYield,
      ScreenerField.price => instrument.quoteObj?.lastTradePrice,
      ScreenerField.volume => fundamentals?.averageVolume,
      ScreenerField.pbRatio => fundamentals?.pbRatio,
      ScreenerField.fiftyTwoWeekPosition => _fiftyTwoWeekPosition(instrument),
      ScreenerField.sector => null,
    };
    if (value == null) return false;
    return (minimum == null || value >= minimum!) &&
        (maximum == null || value <= maximum!);
  }

  Map<String, dynamic> toJson() => {
        'field': field.name,
        'minimum': minimum,
        'maximum': maximum,
        'textValue': textValue,
      };

  factory ScreenerCriterion.fromJson(Map<String, dynamic> json) {
    final field = ScreenerField.values.firstWhere(
      (value) => value.name == json['field'],
      orElse: () => ScreenerField.marketCap,
    );
    return ScreenerCriterion(
      field: field,
      minimum: (json['minimum'] as num?)?.toDouble(),
      maximum: (json['maximum'] as num?)?.toDouble(),
      textValue: json['textValue'] as String?,
    );
  }

  static double? _fiftyTwoWeekPosition(Instrument instrument) {
    final price = instrument.quoteObj?.lastTradePrice;
    final low = instrument.fundamentalsObj?.low52Weeks;
    final high = instrument.fundamentalsObj?.high52Weeks;
    if (price == null || low == null || high == null || high <= low) {
      return null;
    }
    return ((price - low) / (high - low)) * 100;
  }
}

import 'package:robinhood_options_mobile/model/instrument.dart';

class MidlandMoversItem {
  final String instrumentUrl;
  final String symbol;
  final DateTime? updatedAt;
  final double? marketHoursPriceMovement;
  final double? marketHoursLastPrice;
  final String description;

  Instrument? instrumentObj;

  MidlandMoversItem(
      this.instrumentUrl,
      this.symbol,
      this.updatedAt,
      this.marketHoursPriceMovement,
      this.marketHoursLastPrice,
      this.description);

  MidlandMoversItem.fromJson(dynamic json)
      : instrumentUrl = json['instrument_url'],
        symbol = json['symbol'],
        updatedAt = DateTime.tryParse(json['updated_at']),
        marketHoursPriceMovement = double.tryParse(
            json['price_movement']['market_hours_last_movement_pct']),
        marketHoursLastPrice =
            double.tryParse(json['price_movement']['market_hours_last_price']),
        description = json['description'];
}

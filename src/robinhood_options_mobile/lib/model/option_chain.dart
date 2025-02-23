import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:robinhood_options_mobile/model/option_instrument.dart';

/*
https://api.robinhood.com/options/chains/?equity_instrument_ids=943c5009-a0bb-4665-8cf4-a95dab5874e4
{
    "next": null,
    "previous": null,
    "results": [
        {
            "id": "945e9a7d-e46c-4b6d-81d2-61c84f32eb96",
            "symbol": "GOOG",
            "can_open_position": true,
            "cash_component": null,
            "expiration_dates": [
                "2023-02-10",
                "2023-02-17",
                "2023-02-24",
                "2023-03-03",
                "2023-03-10",
                "2023-03-17",
                "2023-03-24",
                "2023-03-31",
                "2023-04-21",
                "2023-06-16",
                "2023-07-21",
                "2023-09-15",
                "2024-01-19",
                "2024-06-21",
                "2025-01-17",
                "2025-06-20"
            ],
            "trade_value_multiplier": "100.0000",
            "underlying_instruments": [
                {
                    "id": "07687dbe-a079-4426-a3d5-3fc7935a2820",
                    "instrument": "https:\/\/api.robinhood.com\/instruments\/943c5009-a0bb-4665-8cf4-a95dab5874e4\/",
                    "quantity": 100
                }
            ],
            "min_ticks": {
                "above_tick": "0.05",
                "below_tick": "0.01",
                "cutoff_price": "3.00"
            },
            "late_close_state": "disabled"
        }
    ]
}
*/
// TODO: Add missing underlying_instruments and late_close_state properties.
class OptionChain {
  final String id;
  final String symbol;
  final bool canOpenPosition;
  final double? cashComponent;
  final List<DateTime> expirationDates;
  final double? tradeValueMultiplier;
  //   final double? underlying_instruments;
  final MinTicks minTicks;

  OptionChain(this.id, this.symbol, this.canOpenPosition, this.cashComponent,
      this.expirationDates, this.tradeValueMultiplier, this.minTicks);

  OptionChain.fromJson(dynamic json)
      : id = json['id'],
        symbol = json['symbol'],
        canOpenPosition = json['can_open_position'],
        cashComponent = json['cash_component'] != null
            ? double.tryParse(json['cash_component'])
            : null,
        expirationDates = json['expiration_dates']
            .map<DateTime>(
                (e) => e is Timestamp ? (e).toDate() : DateTime.parse(e))
            .toList(),
        tradeValueMultiplier = json['trade_value_multiplier'] != null
            ? json['trade_value_multiplier'] is double
                ? json['trade_value_multiplier']
                : double.tryParse(json['trade_value_multiplier'])
            : null,
        minTicks = MinTicks(
            json['min_ticks']['above_tick'] is double
                ? json['min_ticks']['above_tick']
                : double.tryParse(json['min_ticks']['above_tick']),
            json['min_ticks']['below_tick'] is double
                ? json['min_ticks']['below_tick']
                : double.tryParse(json['min_ticks']['below_tick']),
            json['min_ticks']['cutoff_price'] is double
                ? json['min_ticks']['cutoff_price']
                : double.tryParse(json['min_ticks']['cutoff_price']));
  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'can_open_position': canOpenPosition,
        'cash_component': cashComponent,
        'expiration_dates': expirationDates.map((e) => e), // .toIso8601String()
        'trade_value_multiplier': tradeValueMultiplier,
        'min_ticks': minTicks.toJson()
      };
}

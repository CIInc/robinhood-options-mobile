import 'package:robinhood_options_mobile/model/option_instrument.dart';

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
            .map<DateTime>((e) => DateTime.parse(e))
            .toList(),
        tradeValueMultiplier = json['trade_value_multiplier'] != null
            ? double.tryParse(json['trade_value_multiplier'])
            : null,
        minTicks = MinTicks(
            double.tryParse(json['min_ticks']['above_tick']),
            double.tryParse(json['min_ticks']['below_tick']),
            double.tryParse(json['min_ticks']['cutoff_price']));
}

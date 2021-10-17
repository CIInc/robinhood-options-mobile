import 'package:robinhood_options_mobile/model/option_leg_execution.dart';

class OptionLeg {
  final String id;
  final String? position; // Not in OptionOrder example ?
  final String? positionType; // Not in OptionOrder example ?
  final String option;
  final String? positionEffect; // Not in OptionAggregatePosition example ?
  final int ratioQuantity;
  final String? side; // Not in OptionAggregatePosition example ?
  final DateTime? expirationDate;
  final double? strikePrice;
  final String optionType;
  final List<OptionLegExecution>
      executions; // Not in OptionAggregatePosition example ?

  OptionLeg(
      this.id,
      this.position,
      this.positionType,
      this.option,
      this.positionEffect,
      this.ratioQuantity,
      this.side,
      this.expirationDate,
      this.strikePrice,
      this.optionType,
      this.executions);

  OptionLeg.fromJson(dynamic json)
      : id = json['id'],
        position = json['position'],
        positionType = json['position_type'],
        option = json['option'],
        positionEffect = json['position_effect'],
        ratioQuantity = json['ratio_quantity'],
        side = json['side'],
        expirationDate = DateTime.tryParse(json['expiration_date']),
        strikePrice = double.tryParse(json['strike_price']),
        optionType = json['option_type'],
        executions = json['executions'] != null
            ? OptionLegExecution.fromJsonArray(json['executions'])
            : [];

  static List<OptionLeg> fromJsonArray(dynamic json) {
    List<OptionLeg> legs = [];
    for (int i = 0; i < json.length; i++) {
      //try {
      var leg = OptionLeg.fromJson(json[i]);
      legs.add(leg);
      /*} catch (e) {
        print(e);
      }*/
    }
    return legs;
  }
}

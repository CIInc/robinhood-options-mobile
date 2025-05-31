import 'package:cloud_firestore/cloud_firestore.dart';
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
        expirationDate = json['expiration_date'] is Timestamp
            ? (json['expiration_date'] as Timestamp).toDate()
            : DateTime.tryParse(json['expiration_date']),
        strikePrice = json['strike_price'] is double
            ? json['strike_price']
            : double.tryParse(json['strike_price']),
        optionType = json['option_type'],
        executions = json['executions'] != null
            ? OptionLegExecution.fromJsonArray(json['executions'])
            : [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'position': position,
        'position_type': positionType,
        'option': option,
        'position_effect': positionEffect,
        'ratio_quantity': ratioQuantity,
        'side': side,
        'expiration_date': expirationDate,
        'strike_price': strikePrice,
        'option_type': optionType,
        'executions': executions.map((e) => e.toJson()).toList()
      };

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

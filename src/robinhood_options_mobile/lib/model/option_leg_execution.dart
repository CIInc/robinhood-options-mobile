import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:robinhood_options_mobile/utils/json.dart';

class OptionLegExecution {
  final String id;
  final double? price;
  final double? quantity;
  final DateTime? settlementDate;
  final DateTime? timestamp;

  OptionLegExecution(
      this.id, this.price, this.quantity, this.settlementDate, this.timestamp);

  OptionLegExecution.fromJson(dynamic json)
      : id = json['id'],
        price = parseDouble(json['price']),
        quantity = parseDouble(json['quantity']),
        settlementDate = json['settlement_date'] is Timestamp
            ? (json['settlement_date'] as Timestamp).toDate()
            : (json['settlement_date'] is String
                ? DateTime.tryParse(json['settlement_date'])
                : null),
        timestamp = json['timestamp'] is Timestamp
            ? (json['timestamp'] as Timestamp).toDate()
            : (json['timestamp'] is String
                ? DateTime.tryParse(json['timestamp'])
                : null);

  Map<String, dynamic> toJson() => {
        'id': id,
        'price': price,
        'quantity': quantity,
        'settlement_date': settlementDate,
        'timestamp': timestamp
      };

  static List<OptionLegExecution> fromJsonArray(dynamic json) {
    List<OptionLegExecution> legs = [];
    for (int i = 0; i < json.length; i++) {
      //try {
      var leg = OptionLegExecution.fromJson(json[i]);
      legs.add(leg);
      /*} catch (e) {
        print(e);
      }*/
    }
    return legs;
  }
}

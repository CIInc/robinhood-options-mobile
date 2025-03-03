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
        price = double.tryParse(json['price']),
        quantity = double.tryParse(json['quantity']),
        settlementDate = DateTime.tryParse(json['settlement_date']),
        timestamp = DateTime.tryParse(json['timestamp']);

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

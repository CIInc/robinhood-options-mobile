class ForexOrder {
  final String id;
  final String? refId;
  final String? accountId;
  final String? currencyPairId;
  final String? side;
  final String? cancel;
  final String? type;
  final String? timeInForce;
  final String? state;
  final double? price;
  final double? quantity;
  final double? stopPrice;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? averagePrice;
  final double? cumulativeQuantity;
  final double? fees;

  ForexOrder({
    required this.id,
    this.refId,
    this.accountId,
    this.currencyPairId,
    this.side,
    this.cancel,
    this.type,
    this.timeInForce,
    this.state,
    this.price,
    this.quantity,
    this.stopPrice,
    this.createdAt,
    this.updatedAt,
    this.averagePrice,
    this.cumulativeQuantity,
    this.fees,
  });

  factory ForexOrder.fromJson(Map<String, dynamic> json) {
    return ForexOrder(
      id: json['id'],
      refId: json['ref_id'],
      accountId: json['account_id'],
      currencyPairId: json['currency_pair_id'],
      side: json['side'],
      cancel: json['cancel'],
      type: json['type'],
      timeInForce: json['time_in_force'],
      state: json['state'],
      price: json['price'] != null
          ? double.tryParse(json['price'].toString())
          : null,
      quantity: json['quantity'] != null
          ? double.tryParse(json['quantity'].toString())
          : null,
      stopPrice: json['stop_price'] != null
          ? double.tryParse(json['stop_price'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      averagePrice: json['average_price'] != null
          ? double.tryParse(json['average_price'].toString())
          : null,
      cumulativeQuantity: json['cumulative_quantity'] != null
          ? double.tryParse(json['cumulative_quantity'].toString())
          : null,
      fees: json['fees'] != null
          ? double.tryParse(json['fees'].toString())
          : null,
    );
  }
}

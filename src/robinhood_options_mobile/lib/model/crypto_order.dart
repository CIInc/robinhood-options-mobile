/*
Robinhood Crypto Order API Response Format:
{
    "id": "5f394f52-e11e-4b5d-bb4e-b3e6b6e7e8b6",
    "account_id": "808983b7-cf2b-4953-9969-ba8c05150def",
    "currency_pair_id": "3d961844-d360-45fc-989b-f6fca761d511",
    "side": "buy",
    "type": "market",
    "quantity": "0.001",
    "price": "64500.00",
    "state": "filled",
    "cumulative_quantity": "0.001",
    "average_price": "64499.50",
    "fees": "0.50",
    "created_at": "2024-12-03T12:00:00.000000Z",
    "updated_at": "2024-12-03T12:00:05.000000Z",
    "cancel_url": null,
    "time_in_force": "gtc"
}
*/

class CryptoOrder {
  final String id;
  final String accountId;
  final String currencyPairId;
  final String side; // buy or sell
  final String type; // market or limit
  final String state; // confirmed, filled, cancelled, etc.
  final String? timeInForce; // gtc, gfd, ioc
  final double? quantity;
  final double? price;
  final double? cumulativeQuantity;
  final double? averagePrice;
  final double? fees;
  final String? cancelUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String? symbol;
  String? currencyCode;

  CryptoOrder(
    this.id,
    this.accountId,
    this.currencyPairId,
    this.side,
    this.type,
    this.state,
    this.timeInForce,
    this.quantity,
    this.price,
    this.cumulativeQuantity,
    this.averagePrice,
    this.fees,
    this.cancelUrl,
    this.createdAt,
    this.updatedAt,
  );

  CryptoOrder.fromJson(dynamic json)
      : id = json['id'] ?? '',
        accountId = json['account_id'] ?? '',
        currencyPairId = json['currency_pair_id'] ?? '',
        side = json['side'] ?? '',
        type = json['type'] ?? '',
        state = json['state'] ?? '',
        timeInForce = json['time_in_force'],
        quantity = double.tryParse(json['quantity']?.toString() ?? '0'),
        price = double.tryParse(json['price']?.toString() ?? '0'),
        cumulativeQuantity = double.tryParse(json['cumulative_quantity']?.toString() ?? '0'),
        averagePrice = double.tryParse(json['average_price']?.toString() ?? '0'),
        fees = double.tryParse(json['fees']?.toString() ?? '0'),
        cancelUrl = json['cancel_url'],
        createdAt = DateTime.tryParse(json['created_at'] ?? ''),
        updatedAt = DateTime.tryParse(json['updated_at'] ?? '');

  Map<String, dynamic> toJson() => {
        'id': id,
        'account_id': accountId,
        'currency_pair_id': currencyPairId,
        'side': side,
        'type': type,
        'state': state,
        'time_in_force': timeInForce,
        'quantity': quantity,
        'price': price,
        'cumulative_quantity': cumulativeQuantity,
        'average_price': averagePrice,
        'fees': fees,
        'cancel_url': cancelUrl,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  bool get isFilled {
    return state == 'filled';
  }

  bool get isCancelled {
    return state == 'cancelled';
  }

  bool get isPending {
    return state == 'confirmed' || state == 'queued';
  }

  bool get canCancel {
    return cancelUrl != null && !isFilled && !isCancelled;
  }

  double get totalCost {
    if (averagePrice == null || cumulativeQuantity == null) {
      return 0.0;
    }
    return averagePrice! * cumulativeQuantity!;
  }

  double get totalCostWithFees {
    return totalCost + (fees ?? 0.0);
  }
}

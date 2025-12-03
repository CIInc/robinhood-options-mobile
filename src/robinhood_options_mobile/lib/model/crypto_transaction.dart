/*
Robinhood Crypto Transaction API Response Format:
{
    "id": "7a5b8c9d-1e2f-3a4b-5c6d-7e8f9a0b1c2d",
    "account_id": "808983b7-cf2b-4953-9969-ba8c05150def",
    "currency_id": "d674efea-e623-4396-9026-39574b92b093",
    "side": "buy",
    "type": "order",
    "state": "completed",
    "quantity": "0.001",
    "price": "64500.00",
    "fees": "0.50",
    "created_at": "2024-12-03T12:00:00.000000Z",
    "updated_at": "2024-12-03T12:00:05.000000Z"
}
*/

class CryptoTransaction {
  final String id;
  final String accountId;
  final String currencyId;
  final String side; // buy, sell
  final String type; // order, deposit, withdrawal, transfer
  final String state; // completed, pending, cancelled
  final double? quantity;
  final double? price;
  final double? fees;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String? currencyCode;
  String? currencyName;

  CryptoTransaction(
    this.id,
    this.accountId,
    this.currencyId,
    this.side,
    this.type,
    this.state,
    this.quantity,
    this.price,
    this.fees,
    this.createdAt,
    this.updatedAt,
  );

  CryptoTransaction.fromJson(dynamic json)
      : id = json['id'] ?? '',
        accountId = json['account_id'] ?? '',
        currencyId = json['currency_id'] ?? '',
        side = json['side'] ?? '',
        type = json['type'] ?? '',
        state = json['state'] ?? '',
        quantity = double.tryParse(json['quantity']?.toString() ?? '0'),
        price = double.tryParse(json['price']?.toString() ?? '0'),
        fees = double.tryParse(json['fees']?.toString() ?? '0'),
        createdAt = DateTime.tryParse(json['created_at'] ?? ''),
        updatedAt = DateTime.tryParse(json['updated_at'] ?? '');

  Map<String, dynamic> toJson() => {
        'id': id,
        'account_id': accountId,
        'currency_id': currencyId,
        'side': side,
        'type': type,
        'state': state,
        'quantity': quantity,
        'price': price,
        'fees': fees,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  bool get isCompleted {
    return state == 'completed';
  }

  bool get isPending {
    return state == 'pending';
  }

  bool get isCancelled {
    return state == 'cancelled';
  }

  bool get isBuy {
    return side == 'buy';
  }

  bool get isSell {
    return side == 'sell';
  }

  bool get isOrder {
    return type == 'order';
  }

  bool get isDeposit {
    return type == 'deposit';
  }

  bool get isWithdrawal {
    return type == 'withdrawal';
  }

  bool get isTransfer {
    return type == 'transfer';
  }

  double get totalAmount {
    if (price == null || quantity == null) {
      return 0.0;
    }
    return price! * quantity!;
  }

  double get totalAmountWithFees {
    return totalAmount + (fees ?? 0.0);
  }
}

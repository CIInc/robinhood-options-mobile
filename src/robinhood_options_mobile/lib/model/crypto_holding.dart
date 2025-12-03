/*
Robinhood Crypto API Response Format:
{
    "account_id": "808983b7-cf2b-4953-9969-ba8c05150def",
    "cost_bases": [
        {
            "currency_id": "1072fc76-1862-41ab-82c2-485837590762",
            "direct_cost_basis": "499.950000000000000000",
            "direct_quantity": "0.015607460000000000",
            "id": "60dd3bf4-d4be-4149-9324-c6d8043f3ff5",
            "intraday_cost_basis": "0.000000000000000000",
            "intraday_quantity": "0.000000000000000000",
            "marked_cost_basis": "0.000000000000000000",
            "marked_quantity": "0.000000000000000000"
        }
    ],
    "created_at": "2021-06-30T23:52:20.005423-04:00",
    "currency": {
        "brand_color": "EA963D",
        "code": "BTC",
        "id": "d674efea-e623-4396-9026-39574b92b093",
        "increment": "0.000000010000000000",
        "name": "Bitcoin",
        "type": "cryptocurrency"
    },
    "id": "60dd3bf3-e8de-44b4-9cf1-9fe1994b0d54",
    "quantity": "0.015607460000000000",
    "quantity_available": "0.015607460000000000",
    "quantity_held_for_buy": "0.000000000000000000",
    "quantity_held_for_sell": "0.000000000000000000",
    "updated_at": "2021-07-19T23:17:25.367967-04:00"
}
*/
import 'package:robinhood_options_mobile/model/crypto_historicals.dart';
import 'package:robinhood_options_mobile/model/crypto_quote.dart';

class CryptoHolding {
  final String id;
  final String accountId;
  final String currencyId;
  final String currencyCode;
  final String currencyName;
  final String? currencyType;
  final String? brandColor;
  final double? quantity;
  final double? quantityAvailable;
  final double? quantityHeldForBuy;
  final double? quantityHeldForSell;
  final double? directCostBasis;
  final double? intradayCostBasis;
  final double? intradayQuantity;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  CryptoQuote? quoteObj;
  CryptoHistoricals? historicalsObj;

  CryptoHolding(
    this.id,
    this.accountId,
    this.currencyId,
    this.currencyCode,
    this.currencyName,
    this.currencyType,
    this.brandColor,
    this.quantity,
    this.quantityAvailable,
    this.quantityHeldForBuy,
    this.quantityHeldForSell,
    this.directCostBasis,
    this.intradayCostBasis,
    this.intradayQuantity,
    this.createdAt,
    this.updatedAt,
  );

  CryptoHolding.fromJson(dynamic json)
      : id = json['id'],
        accountId = json['account_id'],
        currencyId = json['currency']['id'],
        currencyCode = json['currency']['code'],
        currencyName = json['currency']['name'],
        currencyType = json['currency']['type'],
        brandColor = json['currency']['brand_color'],
        quantity = double.tryParse(json['quantity'] ?? '0'),
        quantityAvailable = double.tryParse(json['quantity_available'] ?? '0'),
        quantityHeldForBuy = double.tryParse(json['quantity_held_for_buy'] ?? '0'),
        quantityHeldForSell = double.tryParse(json['quantity_held_for_sell'] ?? '0'),
        directCostBasis = json['cost_bases'] != null && json['cost_bases'].isNotEmpty
            ? double.tryParse(json['cost_bases'][0]['direct_cost_basis'] ?? '0')
            : 0.0,
        intradayCostBasis = json['cost_bases'] != null && json['cost_bases'].isNotEmpty
            ? double.tryParse(json['cost_bases'][0]['intraday_cost_basis'] ?? '0')
            : 0.0,
        intradayQuantity = json['cost_bases'] != null && json['cost_bases'].isNotEmpty
            ? double.tryParse(json['cost_bases'][0]['intraday_quantity'] ?? '0')
            : 0.0,
        createdAt = DateTime.tryParse(json['created_at'] ?? ''),
        updatedAt = DateTime.tryParse(json['updated_at'] ?? '');

  Map<String, dynamic> toJson() => {
        'id': id,
        'account_id': accountId,
        'currency': {
          'id': currencyId,
          'code': currencyCode,
          'name': currencyName,
          'type': currencyType,
          'brand_color': brandColor,
        },
        'quantity': quantity,
        'quantity_available': quantityAvailable,
        'quantity_held_for_buy': quantityHeldForBuy,
        'quantity_held_for_sell': quantityHeldForSell,
        'directCostBasis': directCostBasis,
        'intradayCostBasis': intradayCostBasis,
        'intradayQuantity': intradayQuantity,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  double get marketValue {
    if (quoteObj == null || quoteObj!.markPrice == null || quantity == null) {
      return 0.0;
    }
    return quoteObj!.markPrice! * quantity!;
  }

  double get averageCost {
    if (directCostBasis == null || quantity == null || quantity! <= 0) {
      return 0.0;
    }
    return directCostBasis! / quantity!;
  }

  double get totalCost {
    return directCostBasis ?? 0.0;
  }

  double get totalReturn {
    return marketValue - totalCost;
  }

  double get totalReturnPercent {
    if (totalCost <= 0) {
      return 0.0;
    }
    return (totalReturn / totalCost) * 100;
  }

  double get intradayReturn {
    if (quoteObj == null || quoteObj!.markPrice == null || 
        intradayQuantity == null || intradayCostBasis == null) {
      return 0.0;
    }
    var intradayValue = quoteObj!.markPrice! * intradayQuantity!;
    return intradayValue - intradayCostBasis!;
  }

  double get intradayReturnPercent {
    if (intradayCostBasis == null || intradayCostBasis! <= 0) {
      return 0.0;
    }
    return (intradayReturn / intradayCostBasis!) * 100;
  }
}

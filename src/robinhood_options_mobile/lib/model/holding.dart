/*
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
class Holding {
  final String id;
  final String currencyName;
  final double? quantity;

  Holding(this.id, this.currencyName, this.quantity);

  Holding.fromJson(dynamic json)
      : id = json['id'],
        currencyName = json['currency']['name'],
        quantity = double.tryParse(json['quantity']);
}

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
import 'package:flutter/material.dart';
import 'package:robinhood_options_mobile/model/forex_historicals.dart';
import 'package:robinhood_options_mobile/model/forex_quote.dart';

class ForexHolding {
  final String id;
  final String currencyId;
  final String currencyCode;
  final String currencyName;
  final double? quantity;
  final double? directCostBasis;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  //double? value;
  ForexQuote? quoteObj;
  ForexHistoricals? historicalsObj;

  ForexHolding(
    this.id,
    this.currencyId,
    this.currencyCode,
    this.currencyName,
    this.quantity,
    this.directCostBasis,
    this.createdAt,
    this.updatedAt,
  );

  ForexHolding.fromJson(dynamic json)
      : id = json['id'],
        currencyId = json['currency']['id'],
        currencyCode = json['currency']['code'],
        currencyName = json['currency']['name'],
        quantity = double.tryParse(json['quantity']),
        directCostBasis =
            double.tryParse(json['cost_bases'][0]['direct_cost_basis']),
        createdAt =
            //DateFormat('y-M-dTH:m:s.SZ').parse(json['created_at'].toString()),
            DateTime.tryParse(json['created_at']),
        updatedAt =
            //DateFormat('y-M-dTH:m:s.SZ').parse(json['updated_at'].toString()),
            DateTime.tryParse(json['updated_at']);

  double get marketValue {
    return quoteObj!.markPrice! * quantity!;
  }

  double get averageCost {
    return directCostBasis! / quantity!;
  }

  double get totalCost {
    return directCostBasis!;
  }

  double get gainLoss {
    return marketValue - totalCost;
  }

  double get gainLossPerShare {
    return gainLoss / quantity!;
  }

  double get gainLossPercent {
    return gainLoss / totalCost;
  }

  double get gainLossToday {
    return quoteObj!.changeToday * quantity!;
  }

  double get gainLossPercentToday {
    return quoteObj!.changePercentToday;
  }
  /*
  double get gainLossToday {
    return (instrumentObj!.quoteObj!.lastExtendedHoursTradePrice ?? instrumentObj!.quoteObj!.lastTradePrice!) -
        instrumentObj!.quoteObj!.adjustedPreviousClose!;
  }

  double get gainLossPercentToday {
    return gainLossToday / instrumentObj!.quoteObj!.adjustedPreviousClose!;
  }
  */

  Icon get trendingIcon {
    return Icon(
            gainLoss > 0
                ? Icons.trending_up
                : (gainLoss < 0 ? Icons.trending_down : Icons.trending_flat),
            color: (gainLoss > 0
                ? Colors.green
                : (gainLoss < 0 ? Colors.red : Colors.grey)))
        /*: Icon(
            gainLoss < 0
                ? Icons.trending_up
                : (gainLoss > 0
                    ? Icons.trending_down
                    : Icons.trending_flat),
            color: (gainLoss < 0
                ? Colors.lightGreenAccent
                : (gainLoss > 0 ? Colors.red : Colors.grey)),
            size: 14.0)*/
        ;
  }

  /*
  Icon get trendingIconToday {
    return Icon(
            gainLossToday > 0
                ? Icons.trending_up
                : (gainLossToday < 0
                    ? Icons.trending_down
                    : Icons.trending_flat),
            color: (gainLossToday > 0
                ? Colors.green
                : (gainLossToday < 0 ? Colors.red : Colors.grey)))
        ;
  }
  */
}

/*
https://nummus.robinhood.com/currency_pairs/
{
    "next": null,
    "previous": null,
    "results": [
        {
            "asset_currency": {
                "brand_color": "EA963D",
                "code": "BTC",
                "id": "d674efea-e623-4396-9026-39574b92b093",
                "increment": "0.000000010000000000",
                "name": "Bitcoin",
                "type": "cryptocurrency"
            },
            "display_only": false,
            "id": "3d961844-d360-45fc-989b-f6fca761d511",
            "max_order_size": "15.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000000010000000000",
            "min_order_size": "0.000001000000000000",
            "name": "Bitcoin to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "BTC-USD",
            "tradability": "tradable"
        },
        {
            "asset_currency": {
                "brand_color": "707DB5",
                "code": "ETH",
                "id": "c527c04a-394b-4a44-ae07-19b901ca609c",
                "increment": "0.000000000000000001",
                "name": "Ethereum",
                "type": "cryptocurrency"
            },
            "display_only": false,
            "id": "76637d50-c702-4ed1-bcb5-5b0732a81f48",
            "max_order_size": "150.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000001000000000000",
            "min_order_size": "0.000100000000000000",
            "name": "Ethereum to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "ETH-USD",
            "tradability": "tradable"
        },
        {
            "asset_currency": {
                "brand_color": "99C061",
                "code": "BCH",
                "id": "913a38ed-36f3-45fb-a967-fb6e30d4a7fb",
                "increment": "0.000000010000000000",
                "name": "Bitcoin Cash",
                "type": "cryptocurrency"
            },
            "display_only": false,
            "id": "2f2b77c4-e426-4271-ae49-18d5cb296d3a",
            "max_order_size": "25.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000000010000000000",
            "min_order_size": "0.001000000000000000",
            "name": "Bitcoin Cash to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "BCH-USD",
            "tradability": "tradable"
        },
        {
            "asset_currency": {
                "brand_color": "BEBBBB",
                "code": "LTC",
                "id": "f9432751-b54d-4d84-b573-f06dc390b766",
                "increment": "0.000000010000000000",
                "name": "Litecoin",
                "type": "cryptocurrency"
            },
            "display_only": false,
            "id": "383280b1-ff53-43fc-9c84-f01afd0989cd",
            "max_order_size": "250.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000000010000000000",
            "min_order_size": "0.001000000000000000",
            "name": "Litecoin to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "LTC-USD",
            "tradability": "tradable"
        },
        {
            "asset_currency": {
                "brand_color": "BEA649",
                "code": "DOGE",
                "id": "c6996ebc-2f9b-443a-b2c2-7ddf02e0ef3a",
                "increment": "0.010000000000000000",
                "name": "Dogecoin",
                "type": "cryptocurrency"
            },
            "display_only": false,
            "id": "1ef78e1b-049b-4f12-90e5-555dcf2fe204",
            "max_order_size": "5000000.0000000000000000",
            "min_order_price_increment": "0.000001000000000000",
            "min_order_quantity_increment": "0.010000000000000000",
            "min_order_size": "1.000000000000000000",
            "name": "Dogecoin to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "DOGE-USD",
            "tradability": "tradable"
        },
        {
            "asset_currency": {
                "brand_color": "",
                "code": "XRP",
                "id": "6b7f1ac0-79d2-4dd1-b227-d98b7474715b",
                "increment": "0.000001000000000000",
                "name": "Ripple",
                "type": "cryptocurrency"
            },
            "display_only": true,
            "id": "5f1325b6-f63c-4367-9d6f-713e3a0c5d76",
            "max_order_size": "0.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000001000000000000",
            "min_order_size": "0.000001000000000000",
            "name": "Ripple to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "XRP-USD",
            "tradability": "untradable"
        },
        {
            "asset_currency": {
                "brand_color": "",
                "code": "QTUM",
                "id": "617f87b7-8e1c-4631-8260-c68374e9d978",
                "increment": "0.000000000000000001",
                "name": "Qtum",
                "type": "cryptocurrency"
            },
            "display_only": true,
            "id": "7837d558-0fe9-4287-8f3e-6de592db127c",
            "max_order_size": "0.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000000000000000001",
            "min_order_size": "0.000000000000000001",
            "name": "Qtum to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "QTUM-USD",
            "tradability": "untradable"
        },
        {
            "asset_currency": {
                "brand_color": "",
                "code": "ETC",
                "id": "ee3bcf3e-4ac7-4f0a-b887-4cea2b49ff70",
                "increment": "0.000001000000000000",
                "name": "Ethereum Classic",
                "type": "cryptocurrency"
            },
            "display_only": false,
            "id": "7b577ce3-489d-4269-9408-796a0d1abb3a",
            "max_order_size": "1000.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000001000000000000",
            "min_order_size": "0.010000000000000000",
            "name": "Ethereum Classic to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "ETC-USD",
            "tradability": "tradable"
        },
        {
            "asset_currency": {
                "brand_color": "",
                "code": "XLM",
                "id": "2989eeb7-b6c7-4b3b-b099-a273ba346c38",
                "increment": "0.000000010000000000",
                "name": "Stellar",
                "type": "cryptocurrency"
            },
            "display_only": true,
            "id": "7a04fe7a-e3a8-4a07-8c35-d0fec9f35569",
            "max_order_size": "0.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000000010000000000",
            "min_order_size": "0.000000010000000000",
            "name": "Stellar to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "XLM-USD",
            "tradability": "untradable"
        },
        {
            "asset_currency": {
                "brand_color": "",
                "code": "NEO",
                "id": "e6e6574f-6359-4220-ba44-4df2acde4ab1",
                "increment": "1.000000000000000000",
                "name": "NEO",
                "type": "cryptocurrency"
            },
            "display_only": true,
            "id": "b9729798-2aec-4ca9-8637-4d9789d63764",
            "max_order_size": "0.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "1.000000000000000000",
            "min_order_size": "1.000000000000000000",
            "name": "NEO to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "NEO-USD",
            "tradability": "untradable"
        },
        {
            "asset_currency": {
                "brand_color": "",
                "code": "ZEC",
                "id": "7c67eab0-3bed-4ead-8130-0435bfaa25ee",
                "increment": "0.000000010000000000",
                "name": "Zcash",
                "type": "cryptocurrency"
            },
            "display_only": true,
            "id": "35f0496d-6c3a-4cac-9d2f-6702a8c387eb",
            "max_order_size": "0.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000000010000000000",
            "min_order_size": "0.000000010000000000",
            "name": "Zcash to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "ZEC-USD",
            "tradability": "untradable"
        },
        {
            "asset_currency": {
                "brand_color": "",
                "code": "XMR",
                "id": "6b70c056-f526-43a7-bb83-cf35dd87575b",
                "increment": "0.000000000001000000",
                "name": "Monero",
                "type": "cryptocurrency"
            },
            "display_only": true,
            "id": "cc2eb8d1-c42d-4f12-8801-1c4bbe43a274",
            "max_order_size": "0.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000000000001000000",
            "min_order_size": "0.000000000001000000",
            "name": "Monero to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "XMR-USD",
            "tradability": "untradable"
        },
        {
            "asset_currency": {
                "brand_color": "",
                "code": "DASH",
                "id": "c2c86423-aea7-4fbb-adb7-a452125a9541",
                "increment": "0.000000010000000000",
                "name": "Dash",
                "type": "cryptocurrency"
            },
            "display_only": true,
            "id": "1461976e-a656-481a-af27-dc6f2980e967",
            "max_order_size": "0.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000000010000000000",
            "min_order_size": "0.000000010000000000",
            "name": "Dash to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "DASH-USD",
            "tradability": "untradable"
        },
        {
            "asset_currency": {
                "brand_color": "",
                "code": "BTG",
                "id": "d409b958-c9fe-4837-9bae-e7a8fd314aee",
                "increment": "0.000000010000000000",
                "name": "Bitcoin Gold",
                "type": "cryptocurrency"
            },
            "display_only": true,
            "id": "a31d3fe3-38e6-4adf-ab4b-e303349f5ee4",
            "max_order_size": "0.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000000010000000000",
            "min_order_size": "0.000010000000000000",
            "name": "Bitcoin Gold to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "BTG-USD",
            "tradability": "untradable"
        },
        {
            "asset_currency": {
                "brand_color": "",
                "code": "LSK",
                "id": "4fbc3184-0899-4987-b62c-9a976ebe21e5",
                "increment": "0.000000010000000000",
                "name": "Lisk",
                "type": "cryptocurrency"
            },
            "display_only": true,
            "id": "2de36458-56cf-458d-b76a-6b3f61b2034c",
            "max_order_size": "0.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000000010000000000",
            "min_order_size": "0.000000010000000000",
            "name": "Lisk to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "LSK-USD",
            "tradability": "untradable"
        },
        {
            "asset_currency": {
                "brand_color": "",
                "code": "OMG",
                "id": "aec15954-7d0f-4adb-b370-5e78e8bf3f30",
                "increment": "0.000000000000000001",
                "name": "OmiseGO",
                "type": "cryptocurrency"
            },
            "display_only": true,
            "id": "bab5ccb4-6729-416e-ac75-019d650016c9",
            "max_order_size": "0.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000000000000000001",
            "min_order_size": "0.000000000000000001",
            "name": "OmiseGO to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "OMG-USD",
            "tradability": "untradable"
        },
        {
            "asset_currency": {
                "brand_color": "",
                "code": "BSV",
                "id": "4a7924c8-d554-47d6-8595-c4e522b0183a",
                "increment": "0.000000010000000000",
                "name": "Bitcoin SV",
                "type": "cryptocurrency"
            },
            "display_only": false,
            "id": "086a8f9f-6c39-43fa-ac9f-57952f4a1ba6",
            "max_order_size": "50.0000000000000000",
            "min_order_price_increment": "0.010000000000000000",
            "min_order_quantity_increment": "0.000000010000000000",
            "min_order_size": "0.000100000000000000",
            "name": "Bitcoin SV to US Dollar",
            "quote_currency": {
                "brand_color": "",
                "code": "USD",
                "id": "1072fc76-1862-41ab-82c2-485837590762",
                "increment": "0.010000000000000000",
                "name": "US Dollar",
                "type": "fiat"
            },
            "symbol": "BSV-USD",
            "tradability": "tradable"
        }
    ]
}
*/

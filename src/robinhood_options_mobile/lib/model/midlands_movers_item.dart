import 'package:robinhood_options_mobile/model/instrument.dart';

/*
{
    "count": 10,
    "next": null,
    "previous": null,
    "results": [
        {
            "instrument_url": "https://api.robinhood.com/instruments/2346aaa6-b39f-480c-a42c-58134a6f349a/",
            "symbol": "FTNT",
            "updated_at": "2023-02-08T21:34:13.186913Z",
            "price_movement": {
                "market_hours_last_movement_pct": "10.95",
                "market_hours_last_price": "59.6700"
            },
            "description": "Fortinet, Inc. provides cybersecurity solutions to variety of business, such as enterprises, communication service providers and small businesses. It operates through the following segments: Network Security; Infrastructure Security; Cloud Security; and Endpoint Protection, Internet of Things and Operational Technology. The Network Security segment include majority of product sales from it FortiGate network security appliances. The Infrastructure Security segment provide platform which is an architectural approach that protects the entire digital attack surface, including network core, endpoints, applications, data centers and private and public cloud. Together with it network of Fabric-Ready Partners, the Fortinet Security Fabric platform enables disparate security devices to work together as an integrated, automated and collaborative solution. The Cloud Security segment provides help to the customers connect securely to and across their cloud environments by offering security through it virtual firewall and other software products in public and private cloud environments. The Endpoint Protection, Internet of Things and Operational Technology segment include the proliferation of Internet of Things (“IoT”) and an Operational Technology (“OT”) device has generated new opportunities for it to grow it business. IoT and OT have created an environment where data move freely between devices across locations, network environments, remote offices, mobile workers and public cloud environments, making the data difficult to consistently track and secure. The company was founded by Ken Xie and Michael Xie in October 2000 and is headquartered in Sunnyvale, CA."
        },
*/
class MidlandMoversItem {
  final String instrumentUrl;
  final String symbol;
  final DateTime? updatedAt;
  final double? marketHoursPriceMovement;
  final double? marketHoursLastPrice;
  final String description;

  Instrument? instrumentObj;

  MidlandMoversItem(
      this.instrumentUrl,
      this.symbol,
      this.updatedAt,
      this.marketHoursPriceMovement,
      this.marketHoursLastPrice,
      this.description);

  MidlandMoversItem.fromJson(dynamic json)
      : instrumentUrl = json['instrument_url'],
        symbol = json['symbol'],
        updatedAt = DateTime.tryParse(json['updated_at']),
        marketHoursPriceMovement = double.tryParse(
            json['price_movement']['market_hours_last_movement_pct']),
        marketHoursLastPrice =
            double.tryParse(json['price_movement']['market_hours_last_price']),
        description = json['description'];
}

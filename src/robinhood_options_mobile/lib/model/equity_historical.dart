class EquityHistorical {
  final double? adjustedOpenEquity;
  final double? adjustedCloseEquity;
  final double? openEquity;
  final double? closeEquity;
  final double? openMarketValue;
  final double? closeMarketValue;
  final DateTime? beginsAt;
  final double? netReturn;
  final String session;

  EquityHistorical(
      this.adjustedOpenEquity,
      this.adjustedCloseEquity,
      this.openEquity,
      this.closeEquity,
      this.openMarketValue,
      this.closeMarketValue,
      this.beginsAt,
      this.netReturn,
      this.session);

  EquityHistorical.fromJson(dynamic json)
      : adjustedOpenEquity = double.tryParse(json['adjusted_open_equity']),
        adjustedCloseEquity = double.tryParse(json['adjusted_close_equity']),
        openEquity = double.tryParse(json['open_equity']),
        closeEquity = double.tryParse(json['close_equity']),
        openMarketValue = double.tryParse(json['open_market_value']),
        closeMarketValue = double.tryParse(json['close_market_value']),
        beginsAt = DateTime.tryParse(json['begins_at']),
        netReturn = double.tryParse(json['net_return']),
        session = json['session'];

  static List<EquityHistorical> fromJsonArray(dynamic json) {
    List<EquityHistorical> list = [];
    for (int i = 0; i < json.length; i++) {
      var equityHistorical = EquityHistorical.fromJson(json[i]);
      list.add(equityHistorical);
    }
    return list;
  }
}

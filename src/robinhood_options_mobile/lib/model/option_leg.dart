class OptionLeg {
  final String id;
  final String position;
  final String positionType;
  final String option;
  final int ratioQuantity;
  final DateTime? expirationDate;
  final double? strikePrice;
  final String optionType;

  OptionLeg(
      this.id,
      this.position,
      this.positionType,
      this.option,
      this.ratioQuantity,
      this.expirationDate,
      this.strikePrice,
      this.optionType);

  OptionLeg.fromJson(dynamic json)
      : id = json['id'],
        position = json['position'],
        positionType = json['position_type'],
        option = json['option'],
        ratioQuantity = json['ratio_quantity'],
        expirationDate = DateTime.tryParse(json['expiration_date']),
        strikePrice = double.tryParse(json['strike_price']),
        optionType = json['option_type'];

  static List<OptionLeg> fromJsonArray(dynamic json) {
    List<OptionLeg> legs = [];
    for (int i = 0; i < json.length; i++) {
      try {
        var leg = OptionLeg.fromJson(json[i]);
        legs.add(leg);
      } catch (e) {
        print(e);
      }
    }
    return legs;
  }
}

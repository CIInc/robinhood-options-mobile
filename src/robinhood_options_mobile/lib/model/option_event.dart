class OptionEvent {
  final String account;
  final String? cashComponent;
  final String chainId;
  final DateTime? createdAt;
  final String direction;
  final List<String> equityComponents;
  final DateTime? eventDate;
  final String id;
  final String option;
  final String position;
  final double? quantity;
  final String? sourceRefId;
  final String state;
  final double? totalCashAmount;
  final String type;
  final double? underlyingPrice;
  final DateTime? updatedAt;

  OptionEvent(
      this.account,
      this.cashComponent,
      this.chainId,
      this.createdAt,
      this.direction,
      this.equityComponents,
      this.eventDate,
      this.id,
      this.option,
      this.position,
      this.quantity,
      this.sourceRefId,
      this.state,
      this.totalCashAmount,
      this.type,
      this.underlyingPrice,
      this.updatedAt);

  OptionEvent.fromJson(dynamic json)
      : account = json['account'],
        cashComponent = json['cash_component'],
        chainId = json['chain_id'],
        createdAt = DateTime.tryParse(json['created_at']),
        direction = json['direction'],
        equityComponents =
            json['equity_components'].map<String>((e) => e.toString()).toList(),
        eventDate = DateTime.tryParse(json['event_date']),
        id = json['id'],
        option = json['option'],
        position = json['position'],
        quantity = double.tryParse(json['quantity']),
        sourceRefId = json['source_ref_id'],
        state = json['state'],
        totalCashAmount = double.tryParse(json['total_cash_amount']),
        type = json['type'],
        underlyingPrice = json['underlying_price'] != null
            ? double.tryParse(json['underlying_price'])
            : null,
        updatedAt = DateTime.tryParse(json['updated_at']);

  Map<String, dynamic> toJson() => {
        'account': account,
        'cash_component': cashComponent,
        'chain_id': chainId,
        'created_at': createdAt,
        'direction': direction,
        'equity_components': equityComponents,
        'event_date': eventDate,
        'id': id,
        'option': option,
        'position': position,
        'quantity': quantity,
        'source_ref_id': sourceRefId,
        'state': state,
        'total_cash_amount': totalCashAmount,
        'type': type,
        'underlying_price': underlyingPrice,
        'updated_at': updatedAt
      };
}

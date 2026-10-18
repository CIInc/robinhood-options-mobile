/// Supported tax lot disposition strategies for equity sell orders.
enum TaxLotStrategy {
  /// First In, First Out (default): Oldest shares acquired sold first.
  fifo('FIFO', 'First In, First Out',
      'Oldest shares sold first (brokerage default).'),

  /// Last In, First Out: Most recently acquired shares sold first.
  lifo('LIFO', 'Last In, First Out', 'Newest shares sold first.'),

  /// Highest In, First Out: Highest cost basis shares sold first to maximize tax losses / minimize taxable gains.
  hifo('HIFO', 'Highest In, First Out',
      'Highest cost basis sold first to maximize capital losses.'),

  /// Lowest In, First Out: Lowest cost basis shares sold first (maximizes capital gains).
  lofo('Low Cost', 'Lowest In, First Out',
      'Lowest cost basis sold first to maximize realized gains.'),

  /// Tax Minimizer: Prioritizes short-term losses, then long-term losses, then long-term gains, and short-term gains last.
  taxMinimizer('Tax Minimizer', 'Tax Minimizer',
      'Optimizes disposal across tax brackets and holding periods.'),

  /// Specific Lots: User manually selects lots and allocates specific share quantities.
  specified('Specified Lots', 'Specific Lot Selection',
      'Manually select exact tax lots and allocated share quantities.');

  final String shortName;
  final String label;
  final String description;

  const TaxLotStrategy(this.shortName, this.label, this.description);

  /// User-friendly display name.
  String get displayName => label;

  /// Converts enum to the API string expected by brokerage endpoints.
  String toApiKey() {
    switch (this) {
      case TaxLotStrategy.fifo:
        return 'fifo';
      case TaxLotStrategy.lifo:
        return 'lifo';
      case TaxLotStrategy.hifo:
        return 'hifo';
      case TaxLotStrategy.lofo:
        return 'lofo';
      case TaxLotStrategy.taxMinimizer:
        return 'tax_optimizer';
      case TaxLotStrategy.specified:
        return 'custom';
    }
  }

  static TaxLotStrategy fromApiKey(String key) {
    switch (key.toLowerCase()) {
      case 'lifo':
        return TaxLotStrategy.lifo;
      case 'hifo':
        return TaxLotStrategy.hifo;
      case 'lofo':
      case 'low_cost':
        return TaxLotStrategy.lofo;
      case 'tax_optimizer':
      case 'tax_minimizer':
        return TaxLotStrategy.taxMinimizer;
      case 'custom':
      case 'specified':
      case 'spec_id':
        return TaxLotStrategy.specified;
      case 'fifo':
      default:
        return TaxLotStrategy.fifo;
    }
  }
}

/// Represents an individual tax lot (equity acquisition) for an account holding.
class TaxLot {
  final String openLotId;
  final String symbol;
  final String openTranType;
  final String? orderId;
  final double quantity;
  final double quantityAvailable;
  final bool isSelectable;
  final double costPerShare;
  final double taxCostBasis;
  final DateTime openDate;
  final String term; // 'st' or 'lt'

  TaxLot({
    String? openLotId,
    String? id,
    required this.symbol,
    this.openTranType = 'buy',
    this.orderId,
    required this.quantity,
    required this.quantityAvailable,
    this.isSelectable = true,
    required this.costPerShare,
    double? taxCostBasis,
    required this.openDate,
    this.term = 'st',
  })  : openLotId = openLotId ?? id ?? '',
        taxCostBasis = taxCostBasis ?? (costPerShare * quantityAvailable);

  bool get isShortTerm => term.toLowerCase() == 'st';
  bool get isLongTerm => term.toLowerCase() == 'lt';

  /// Convenient aliases for openLotId and taxCostBasis.
  String get id => openLotId;
  double get totalCost => taxCostBasis;

  int daysHeld([DateTime? asOf]) {
    final target = asOf ?? DateTime.now();
    return target.difference(openDate).inDays;
  }

  double unrealizedGainLoss(double currentPrice) {
    return (currentPrice - costPerShare) * quantityAvailable;
  }

  double unrealizedGainLossPercent(double currentPrice) {
    if (costPerShare <= 0) return 0.0;
    return ((currentPrice - costPerShare) / costPerShare) * 100;
  }

  double estimatedTaxLiability(
    double currentPrice, {
    double shortTermTaxRate = 0.24,
    double longTermTaxRate = 0.15,
  }) {
    final gain = unrealizedGainLoss(currentPrice);
    if (gain <= 0) return 0.0;
    final rate = isLongTerm ? longTermTaxRate : shortTermTaxRate;
    return gain * rate;
  }

  factory TaxLot.fromJson(Map<String, dynamic> json,
      {String defaultSymbol = ''}) {
    final lotId =
        (json['open_lot_id'] ?? json['id'] ?? json['lot_id'] ?? '').toString();
    final sym = (json['symbol'] ?? defaultSymbol).toString();
    final tranType = (json['open_tran_type'] ?? 'buy').toString();
    final ordId = json['order_id']?.toString();

    final qty = double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0;
    final qtyAvail = double.tryParse(json['quantity_available']?.toString() ??
            json['available_quantity']?.toString() ??
            qty.toString()) ??
        qty;
    final selectable =
        json['is_selectable'] == null ? true : (json['is_selectable'] == true);

    final costShare = double.tryParse(json['cost_per_share']?.toString() ??
            json['price']?.toString() ??
            json['cost_basis_per_share']?.toString() ??
            '0') ??
        0.0;

    final costBasis = double.tryParse(json['tax_cost_basis']?.toString() ??
            json['cost_basis']?.toString() ??
            (costShare * qty).toString()) ??
        (costShare * qty);

    DateTime parsedDate;
    final rawDate =
        json['open_date'] ?? json['acquired_at'] ?? json['created_at'];
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate != null) {
      parsedDate = DateTime.tryParse(rawDate.toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    String parsedTerm = (json['term'] ?? '').toString().toLowerCase();
    if (parsedTerm.isEmpty) {
      final days = DateTime.now().difference(parsedDate).inDays;
      parsedTerm = days > 365 ? 'lt' : 'st';
    }

    return TaxLot(
      openLotId: lotId,
      symbol: sym,
      openTranType: tranType,
      orderId: ordId,
      quantity: qty,
      quantityAvailable: qtyAvail,
      isSelectable: selectable,
      costPerShare: costShare,
      taxCostBasis: costBasis,
      openDate: parsedDate,
      term: parsedTerm,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'open_lot_id': openLotId,
      'symbol': symbol,
      'open_tran_type': openTranType,
      'order_id': orderId,
      'quantity': quantity.toStringAsFixed(6),
      'quantity_available': quantityAvailable.toStringAsFixed(6),
      'is_selectable': isSelectable,
      'cost_per_share': costPerShare.toStringAsFixed(6),
      'tax_cost_basis': taxCostBasis.toStringAsFixed(6),
      'open_date': openDate.toIso8601String(),
      'term': term,
    };
  }
}

/// An individual lot with its assigned share count for an order.
class AllocatedLot {
  final TaxLot lot;
  final double allocatedQuantity;

  const AllocatedLot({
    required this.lot,
    required this.allocatedQuantity,
  });

  double get costBasis => lot.costPerShare * allocatedQuantity;
  double proceeds(double price) => price * allocatedQuantity;
  double gainLoss(double price) => proceeds(price) - costBasis;
  bool get isShortTerm => lot.isShortTerm;
  bool get isLongTerm => lot.isLongTerm;

  Map<String, dynamic> toOrderPayload() {
    return {
      'open_lot_id': lot.openLotId,
      'quantity':
          allocatedQuantity.toStringAsFixed(allocatedQuantity % 1 == 0 ? 0 : 4),
    };
  }
}

/// The result of calculating tax lot allocation for a specified order quantity.
class TaxLotAllocation {
  final TaxLotStrategy strategy;
  final List<AllocatedLot> allocatedLots;
  final double totalAllocatedQuantity;
  final double totalCostBasis;
  final double averageCostPerShare;
  final double estimatedProceeds;
  final double estimatedRealizedGainLoss;
  final double shortTermGainLoss;
  final double longTermGainLoss;
  final double estimatedTaxLiability;
  final double taxSavingsVsFifo;

  const TaxLotAllocation({
    required this.strategy,
    required this.allocatedLots,
    required this.totalAllocatedQuantity,
    required this.totalCostBasis,
    required this.averageCostPerShare,
    required this.estimatedProceeds,
    required this.estimatedRealizedGainLoss,
    required this.shortTermGainLoss,
    required this.longTermGainLoss,
    required this.estimatedTaxLiability,
    required this.taxSavingsVsFifo,
  });

  /// Convenient alias for estimated realized gain or loss.
  double get realizedGainLoss => estimatedRealizedGainLoss;

  /// Formats allocated lots for Robinhood / Brokerage order placement payload.
  List<Map<String, dynamic>> toOrderPayloadLots() {
    return allocatedLots.map((al) => al.toOrderPayload()).toList();
  }
}

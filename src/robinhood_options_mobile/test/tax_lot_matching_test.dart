import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/tax_lot.dart';
import 'package:robinhood_options_mobile/services/tax_optimization_service.dart';

void main() {
  group('TaxLot Model Tests', () {
    test('TaxLot fromJson and toJson roundtrip', () {
      final json = {
        'id': 'lot_001',
        'symbol': 'AAPL',
        'quantity': '50.0000',
        'quantity_available': '50.0000',
        'cost_per_share': '150.25',
        'total_cost': '7512.50',
        'open_date': '2023-01-15T10:00:00Z',
        'term': 'lt',
        'is_selectable': true,
      };

      final lot = TaxLot.fromJson(json);

      expect(lot.id, 'lot_001');
      expect(lot.openLotId, 'lot_001');
      expect(lot.symbol, 'AAPL');
      expect(lot.quantity, 50.0);
      expect(lot.quantityAvailable, 50.0);
      expect(lot.costPerShare, 150.25);
      expect(lot.totalCost, 7512.50);
      expect(lot.isLongTerm, isTrue);
      expect(lot.isShortTerm, isFalse);
      expect(lot.isSelectable, isTrue);

      final outJson = lot.toJson();
      expect(outJson['open_lot_id'], 'lot_001');
      expect(outJson['symbol'], 'AAPL');
      expect(double.parse(outJson['quantity']), 50.0);
      expect(double.parse(outJson['cost_per_share']), 150.25);
    });

    test('Holding period and term determination', () {
      final now = DateTime.now();
      final shortTermDate = now.subtract(const Duration(days: 180));
      final longTermDate = now.subtract(const Duration(days: 400));

      final shortTermLot = TaxLot(
        id: 'st_lot',
        symbol: 'NVDA',
        quantity: 10,
        quantityAvailable: 10,
        costPerShare: 100,
        openDate: shortTermDate,
        term: 'st',
      );

      final longTermLot = TaxLot(
        id: 'lt_lot',
        symbol: 'NVDA',
        quantity: 10,
        quantityAvailable: 10,
        costPerShare: 80,
        openDate: longTermDate,
        term: 'lt',
      );

      expect(shortTermLot.isShortTerm, isTrue);
      expect(shortTermLot.isLongTerm, isFalse);
      expect(longTermLot.isShortTerm, isFalse);
      expect(longTermLot.isLongTerm, isTrue);
    });

    test('Unrealized gain/loss and tax liability calculations', () {
      final now = DateTime.now();
      final lot = TaxLot(
        id: 'gain_lot',
        symbol: 'MSFT',
        quantity: 10,
        quantityAvailable: 10,
        costPerShare: 200,
        openDate: now.subtract(const Duration(days: 100)), // short term
        term: 'st',
      );

      // Current price = $250. Gain = 10 * ($250 - $200) = $500.
      expect(lot.unrealizedGainLoss(250), 500.0);
      expect(lot.unrealizedGainLossPercent(250), 25.0);

      // Short term tax rate = 24% => $500 * 0.24 = $120.
      expect(lot.estimatedTaxLiability(250, shortTermTaxRate: 0.24), 120.0);

      // Current price = $150. Loss = 10 * ($150 - $200) = -$500.
      expect(lot.unrealizedGainLoss(150), -500.0);
      // estimatedTaxLiability returns 0.0 for losses (no tax liability)
      expect(lot.estimatedTaxLiability(150, shortTermTaxRate: 0.24), 0.0);
    });
  });

  group('TaxLotStrategy Enum Tests', () {
    test('toApiKey and fromApiKey mapping', () {
      expect(TaxLotStrategy.fifo.toApiKey(), 'fifo');
      expect(TaxLotStrategy.lifo.toApiKey(), 'lifo');
      expect(TaxLotStrategy.hifo.toApiKey(), 'hifo');
      expect(TaxLotStrategy.lofo.toApiKey(), 'lofo');
      expect(TaxLotStrategy.taxMinimizer.toApiKey(), 'tax_optimizer');
      expect(TaxLotStrategy.specified.toApiKey(), 'custom');

      expect(TaxLotStrategy.fromApiKey('fifo'), TaxLotStrategy.fifo);
      expect(TaxLotStrategy.fromApiKey('lifo'), TaxLotStrategy.lifo);
      expect(TaxLotStrategy.fromApiKey('hifo'), TaxLotStrategy.hifo);
      expect(TaxLotStrategy.fromApiKey('lofo'), TaxLotStrategy.lofo);
      expect(TaxLotStrategy.fromApiKey('tax_optimizer'),
          TaxLotStrategy.taxMinimizer);
      expect(TaxLotStrategy.fromApiKey('custom'), TaxLotStrategy.specified);
      expect(TaxLotStrategy.fromApiKey('specified'), TaxLotStrategy.specified);
    });
  });

  group('TaxOptimizationService.applyTaxLotStrategy Tests', () {
    final now = DateTime.now();

    // Setup 4 distinct lots:
    // Lot A: Oldest, lowest cost ($100), Long Term (bought 400 days ago), 10 shares
    final lotA = TaxLot(
      id: 'lot_A',
      symbol: 'TSLA',
      quantity: 10,
      quantityAvailable: 10,
      costPerShare: 100,
      openDate: now.subtract(const Duration(days: 400)),
      term: 'lt',
    );

    // Lot B: Moderate cost ($150), Long Term (bought 370 days ago), 10 shares
    final lotB = TaxLot(
      id: 'lot_B',
      symbol: 'TSLA',
      quantity: 10,
      quantityAvailable: 10,
      costPerShare: 150,
      openDate: now.subtract(const Duration(days: 370)),
      term: 'lt',
    );

    // Lot C: High cost ($250), Short Term (bought 60 days ago), 10 shares
    final lotC = TaxLot(
      id: 'lot_C',
      symbol: 'TSLA',
      quantity: 10,
      quantityAvailable: 10,
      costPerShare: 250,
      openDate: now.subtract(const Duration(days: 60)),
      term: 'st',
    );

    // Lot D: Highest cost ($300), Short Term (bought 20 days ago), 10 shares
    final lotD = TaxLot(
      id: 'lot_D',
      symbol: 'TSLA',
      quantity: 10,
      quantityAvailable: 10,
      costPerShare: 300,
      openDate: now.subtract(const Duration(days: 20)),
      term: 'st',
    );

    final List<TaxLot> lots = [lotA, lotB, lotC, lotD];

    test('FIFO Strategy: Allocates oldest lots first', () {
      // Sell 15 shares at current price $200
      // FIFO will take: 10 shares from Lot A ($100), 5 shares from Lot B ($150)
      final allocation = TaxOptimizationService.applyTaxLotStrategy(
        lots: lots,
        strategy: TaxLotStrategy.fifo,
        orderQuantity: 15,
        currentPrice: 200,
      );

      expect(allocation.strategy, TaxLotStrategy.fifo);
      expect(allocation.totalAllocatedQuantity, 15.0);
      expect(allocation.allocatedLots.length, 2);
      expect(allocation.allocatedLots[0].lot.id, 'lot_A');
      expect(allocation.allocatedLots[0].allocatedQuantity, 10.0);
      expect(allocation.allocatedLots[1].lot.id, 'lot_B');
      expect(allocation.allocatedLots[1].allocatedQuantity, 5.0);

      // Cost Basis: (10 * 100) + (5 * 150) = 1000 + 750 = 1750
      expect(allocation.totalCostBasis, 1750.0);
      // Proceeds: 15 * 200 = 3000
      expect(allocation.estimatedProceeds, 3000.0);
      // Realized Gain: 3000 - 1750 = 1250 (All Long Term)
      expect(allocation.realizedGainLoss, 1250.0);
      expect(allocation.longTermGainLoss, 1250.0);
      expect(allocation.shortTermGainLoss, 0.0);

      // Baseline tax savings vs FIFO is 0
      expect(allocation.taxSavingsVsFifo, 0.0);
    });

    test('LIFO Strategy: Allocates newest lots first', () {
      // Sell 15 shares at current price $200
      // LIFO will take: 10 shares from Lot D ($300), 5 shares from Lot C ($250)
      final allocation = TaxOptimizationService.applyTaxLotStrategy(
        lots: lots,
        strategy: TaxLotStrategy.lifo,
        orderQuantity: 15,
        currentPrice: 200,
      );

      expect(allocation.strategy, TaxLotStrategy.lifo);
      expect(allocation.totalAllocatedQuantity, 15.0);
      expect(allocation.allocatedLots.length, 2);
      expect(allocation.allocatedLots[0].lot.id, 'lot_D');
      expect(allocation.allocatedLots[0].allocatedQuantity, 10.0);
      expect(allocation.allocatedLots[1].lot.id, 'lot_C');
      expect(allocation.allocatedLots[1].allocatedQuantity, 5.0);

      // Cost Basis: (10 * 300) + (5 * 250) = 3000 + 1250 = 4250
      expect(allocation.totalCostBasis, 4250.0);
      // Proceeds: 15 * 200 = 3000
      expect(allocation.estimatedProceeds, 3000.0);
      // Realized Loss: 3000 - 4250 = -1250 (All Short Term)
      expect(allocation.realizedGainLoss, -1250.0);
      expect(allocation.shortTermGainLoss, -1250.0);
      expect(allocation.longTermGainLoss, 0.0);

      // Tax savings vs FIFO:
      // FIFO liability: $1250 LT gain * 0.15 = $187.50
      // LIFO liability: $0.00 (tax liability is non-negative on capital loss)
      // Tax Savings: $187.50 - $0.00 = $187.50
      expect(allocation.taxSavingsVsFifo, closeTo(187.50, 0.01));
    });

    test(
        'HIFO Strategy: Allocates highest cost lots first to maximize tax losses',
        () {
      // Sell 15 shares at current price $200
      // HIFO will select Lot D ($300) first, then Lot C ($250)
      final allocation = TaxOptimizationService.applyTaxLotStrategy(
        lots: lots,
        strategy: TaxLotStrategy.hifo,
        orderQuantity: 15,
        currentPrice: 200,
      );

      expect(allocation.strategy, TaxLotStrategy.hifo);
      expect(allocation.allocatedLots[0].lot.id, 'lot_D');
      expect(allocation.allocatedLots[1].lot.id, 'lot_C');
      expect(allocation.realizedGainLoss, -1250.0);
      expect(allocation.taxSavingsVsFifo, greaterThan(0.0));
    });

    test(
        'LOFO Strategy: Allocates lowest cost lots first to maximize realized gains',
        () {
      // Sell 15 shares at current price $200
      // LOFO will select Lot A ($100, lowest) first, then Lot B ($150)
      final allocation = TaxOptimizationService.applyTaxLotStrategy(
        lots: lots,
        strategy: TaxLotStrategy.lofo,
        orderQuantity: 15,
        currentPrice: 200,
      );

      expect(allocation.strategy, TaxLotStrategy.lofo);
      expect(allocation.allocatedLots[0].lot.id, 'lot_A');
      expect(allocation.allocatedLots[1].lot.id, 'lot_B');
      expect(allocation.realizedGainLoss, 1250.0);
    });

    test('Specified Lots Strategy: Respects manual allocations map', () {
      // Allocate 3 shares from Lot A, 7 shares from Lot C = 10 shares total
      final manualAllocations = {
        'lot_A': 3.0,
        'lot_C': 7.0,
      };

      final allocation = TaxOptimizationService.applyTaxLotStrategy(
        lots: lots,
        strategy: TaxLotStrategy.specified,
        orderQuantity: 10,
        currentPrice: 200,
        manualAllocations: manualAllocations,
      );

      expect(allocation.strategy, TaxLotStrategy.specified);
      expect(allocation.totalAllocatedQuantity, 10.0);
      expect(allocation.allocatedLots.length, 2);

      final lotAAlloc =
          allocation.allocatedLots.firstWhere((al) => al.lot.id == 'lot_A');
      final lotCAlloc =
          allocation.allocatedLots.firstWhere((al) => al.lot.id == 'lot_C');

      expect(lotAAlloc.allocatedQuantity, 3.0);
      expect(lotCAlloc.allocatedQuantity, 7.0);

      // Cost Basis: (3 * 100) + (7 * 250) = 300 + 1750 = 2050
      expect(allocation.totalCostBasis, 2050.0);
      // Proceeds: 10 * 200 = 2000
      expect(allocation.estimatedProceeds, 2000.0);
      // Realized: 2000 - 2050 = -50
      expect(allocation.realizedGainLoss, -50.0);

      // ST gain/loss: Lot C (7 * (200 - 250)) = -350
      expect(allocation.shortTermGainLoss, -350.0);
      // LT gain/loss: Lot A (3 * (200 - 100)) = +300
      expect(allocation.longTermGainLoss, 300.0);
    });

    test('toOrderPayloadLots formats correctly for API submission', () {
      final manualAllocations = {
        'lot_B': 4.0,
        'lot_D': 6.0,
      };

      final allocation = TaxOptimizationService.applyTaxLotStrategy(
        lots: lots,
        strategy: TaxLotStrategy.specified,
        orderQuantity: 10,
        currentPrice: 200,
        manualAllocations: manualAllocations,
      );

      final payloadLots = allocation.toOrderPayloadLots();
      expect(payloadLots.length, 2);
      expect(
        payloadLots
            .any((p) => p['open_lot_id'] == 'lot_B' && p['quantity'] == '4'),
        isTrue,
      );
      expect(
        payloadLots
            .any((p) => p['open_lot_id'] == 'lot_D' && p['quantity'] == '6'),
        isTrue,
      );
    });
  });
}

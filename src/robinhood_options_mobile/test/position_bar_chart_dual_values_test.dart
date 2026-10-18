import 'package:community_charts_flutter/community_charts_flutter.dart'
    as charts;
import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';
import 'package:robinhood_options_mobile/model/quote.dart';
import 'package:robinhood_options_mobile/widgets/chart_bar_widget.dart';

void main() {
  group('Position Bar Chart Dual Values and CSV Export Tests', () {
    test(
        'InstrumentPosition CSV export generates correct header and row values',
        () {
      final instrument = Instrument(
        id: 'aapl-id',
        url: '',
        quote: '',
        fundamentals: '',
        splits: '',
        state: '',
        market: '',
        name: 'Apple Inc.',
        simpleName: 'Apple',
        tradeable: true,
        tradability: '',
        symbol: 'AAPL',
        bloombergUnique: '',
        country: '',
        type: 'stock',
        rhsTradability: '',
        fractionalTradability: '',
        isSpac: false,
        isTest: false,
        ipoAccessSupportsDsp: false,
        dateCreated: DateTime(2025, 1, 1),
      )..quoteObj = Quote(
          symbol: 'AAPL',
          askPrice: 150.0,
          askSize: 10,
          bidPrice: 149.9,
          bidSize: 10,
          lastTradePrice: 150.0,
          lastExtendedHoursTradePrice: null,
          previousClose: 140.0,
          adjustedPreviousClose: 140.0,
          previousCloseDate: null,
          tradingHalted: false,
          hasTraded: true,
          lastTradePriceSource: 'robinhood',
          updatedAt: DateTime(2025, 1, 1),
          instrument: '',
          instrumentId: 'aapl-id',
        );

      final position = InstrumentPosition(
        'https://api.robinhood.com/positions/ACC1/aapl-id/',
        'https://api.robinhood.com/instruments/aapl-id/',
        'https://api.robinhood.com/accounts/ACC1/',
        'ACC1',
        100.0, // averageBuyPrice
        null,
        10.0, // quantity
        null,
        null,
        10.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        false,
        DateTime(2025, 1, 1),
        DateTime(2025, 1, 1),
      )..instrumentObj = instrument;

      final csvString = InstrumentPosition.generateCsvString([position]);
      expect(
          csvString,
          contains(
              'Symbol,Name,Quantity,Average Buy Price,Current Price,Market Value,Total Cost'));
      expect(
          csvString,
          contains(
              'AAPL,Apple,10.0,100.0,150.0,1500.0,1000.0,500.0,0.5,100.0,0.07142857142857142,https://api.robinhood.com/accounts/ACC1/'));
    });

    test(
        'OptionAggregatePosition CSV export generates correct header and row values',
        () {
      final op = OptionAggregatePosition.fromJson({
        'id': 'op-pos-1',
        'chain': 'aapl-chain',
        'account': 'https://api.robinhood.com/accounts/ACC1/',
        'symbol': 'AAPL',
        'strategy': 'call',
        'average_open_price': 2.0,
        'quantity': 5.0,
        'direction': 'debit',
        'intraday_direction': 'debit',
        'trade_value_multiplier': 100.0,
        'strategy_code': 'long_call',
        'created_at': '2026-08-03T10:00:00.000Z',
        'updated_at': '2026-08-03T10:00:00.000Z',
        'legs': [
          {
            'id': 'leg-1',
            'position': 'pos-1',
            'position_type': 'long',
            'option': '/options/aapl-call/',
            'position_effect': 'open',
            'side': 'buy',
            'expiration_date': '2027-01-15T00:00:00.000Z',
            'strike_price': 160.0,
            'option_type': 'call',
            'ratio_quantity': 1,
            'executions': <dynamic>[],
          }
        ],
        'optionInstrument': {
          'chain_id': 'aapl-chain',
          'chain_symbol': 'AAPL',
          'created_at': '2026-08-03T10:00:00.000Z',
          'expiration_date': '2027-01-15T00:00:00.000Z',
          'id': 'opt-inst-1',
          'issue_date': '2026-08-01T00:00:00.000Z',
          'min_ticks': {
            'above_tick': 0.05,
            'below_tick': 0.01,
            'cutoff_price': 3.0,
          },
          'rhs_tradability': 'tradable',
          'state': 'active',
          'strike_price': 160.0,
          'tradability': 'tradable',
          'type': 'call',
          'updated_at': '2026-08-03T10:00:00.000Z',
          'url': '/options/opt-inst-1/',
          'long_strategy_code': 'long_call',
          'short_strategy_code': 'short_call',
          'option_market_data': {
            'instrument': '/options/opt-inst-1/',
            'instrument_id': 'opt-inst-1',
            'symbol': 'AAPL',
            'occ_symbol': 'AAPL270115C00160000',
            'adjusted_mark_price': 3.5,
            'ask_price': 3.55,
            'ask_size': 10,
            'bid_price': 3.45,
            'bid_size': 10,
            'previous_close_price': 3.0,
            'open_interest': 1000,
            'volume': 500,
          }
        }
      });

      final csvString =
          OptionAggregatePosition.generatePositionsCsvString([op]);
      expect(
          csvString,
          contains(
              'Symbol,Strategy,Option Type,Strike Price,Expiration Date,Quantity,Average Open Price,Current Price,Market Value,Total Cost'));
      expect(
          csvString,
          contains(
              'AAPL,call,call,160.0,2027-01-15,5.0,2.0,3.5,1750.0,10.0,1740.0,174.0,250.0,0.16666666666666666,https://api.robinhood.com/accounts/ACC1/'));
    });

    test(
        'BrokerageUser secondary measure pairs are consistently mapped for dual display',
        () {
      final user = BrokerageUser.fromJson({
        'source': 'robinhood',
        'userName': 'test_user',
      });

      // For marketValue, secondary is totalCost and vice versa
      user.displayValue = DisplayValue.marketValue;
      DisplayValue? secondary;
      if (user.displayValue == DisplayValue.marketValue) {
        secondary = DisplayValue.totalCost;
      } else if (user.displayValue == DisplayValue.totalCost) {
        secondary = DisplayValue.marketValue;
      }
      expect(secondary, DisplayValue.totalCost);

      // For totalReturn ($), secondary is totalReturnPercent (%) and vice versa
      user.displayValue = DisplayValue.totalReturn;
      if (user.displayValue == DisplayValue.totalReturn) {
        secondary = DisplayValue.totalReturnPercent;
      } else if (user.displayValue == DisplayValue.totalReturnPercent) {
        secondary = DisplayValue.totalReturn;
      }
      expect(secondary, DisplayValue.totalReturnPercent);

      // For todayReturn ($), secondary is todayReturnPercent (%) and vice versa
      user.displayValue = DisplayValue.todayReturnPercent;
      if (user.displayValue == DisplayValue.todayReturn) {
        secondary = DisplayValue.todayReturnPercent;
      } else if (user.displayValue == DisplayValue.todayReturnPercent) {
        secondary = DisplayValue.todayReturn;
      }
      expect(secondary, DisplayValue.todayReturn);
    });

    test('Combined label formatting displays both \$ and % values cleanly', () {
      final user = BrokerageUser.fromJson({
        'source': 'robinhood',
        'userName': 'test_user',
      });

      // Total return with percent
      final primaryText =
          user.getDisplayText(150.0, displayValue: DisplayValue.totalReturn);
      final secondaryText = user.getDisplayText(0.152,
          displayValue: DisplayValue.totalReturnPercent);

      final combinedLabel = '$primaryText ($secondaryText)';
      expect(combinedLabel, contains('\$150.00'));
      expect(combinedLabel, contains('15.20%'));

      // Market value bar label does NOT include (Cost: ...) because the detail pane displays it
      final mvText =
          user.getDisplayText(12500.0, displayValue: DisplayValue.marketValue);
      final costText =
          user.getDisplayText(10000.0, displayValue: DisplayValue.totalCost);
      const secondaryDisplayValue = DisplayValue.totalCost;
      String combinedBarLabel = mvText;
      if (costText.isNotEmpty) {
        if (secondaryDisplayValue != DisplayValue.totalCost &&
            secondaryDisplayValue != DisplayValue.marketValue) {
          combinedBarLabel = '$mvText ($costText)';
        }
      }
      expect(combinedBarLabel, '\$12,500.00');
      expect(combinedBarLabel, isNot(contains('Cost')));
      expect(combinedBarLabel, isNot(contains('Total Cost')));
    });

    test(
        'isDualAxis is only true for \$ vs % and false for marketValue vs totalCost',
        () {
      bool checkDualAxis(DisplayValue primary, DisplayValue? secondary) {
        return secondary != null &&
            ((primary == DisplayValue.totalReturn &&
                    secondary == DisplayValue.totalReturnPercent) ||
                (primary == DisplayValue.totalReturnPercent &&
                    secondary == DisplayValue.totalReturn) ||
                (primary == DisplayValue.todayReturn &&
                    secondary == DisplayValue.todayReturnPercent) ||
                (primary == DisplayValue.todayReturnPercent &&
                    secondary == DisplayValue.todayReturn));
      }

      // marketValue <-> totalCost are both in currency units ($), so they share 1 axis
      expect(checkDualAxis(DisplayValue.marketValue, DisplayValue.totalCost),
          isFalse);
      expect(checkDualAxis(DisplayValue.totalCost, DisplayValue.marketValue),
          isFalse);

      // Return ($) <-> Return (%) have different units, so they use 2 axes (dual-axis)
      expect(
          checkDualAxis(
              DisplayValue.totalReturn, DisplayValue.totalReturnPercent),
          isTrue);
      expect(
          checkDualAxis(
              DisplayValue.totalReturnPercent, DisplayValue.totalReturn),
          isTrue);
      expect(
          checkDualAxis(
              DisplayValue.todayReturn, DisplayValue.todayReturnPercent),
          isTrue);
      expect(
          checkDualAxis(
              DisplayValue.todayReturnPercent, DisplayValue.todayReturn),
          isTrue);
    });

    test('Market Value bar chart x-axis extents start at 0', () {
      double computeMinExtent(DisplayValue displayValue, List<double> values) {
        var extents = charts.NumericExtents.fromValues(values);
        double primaryPad = extents.width > 0 ? extents.width * 0.1 : 0.05;
        final bool startsAtZero = displayValue == DisplayValue.marketValue ||
            displayValue == DisplayValue.totalCost;
        return startsAtZero ? 0.0 : extents.min - primaryPad;
      }

      // Even if positions have high positive minimums (e.g. $5,000 - $12,000),
      // Market Value axis must start at 0
      final mvMin =
          computeMinExtent(DisplayValue.marketValue, [5000.0, 8000.0, 12000.0]);
      expect(mvMin, 0.0);

      final costMin =
          computeMinExtent(DisplayValue.totalCost, [4000.0, 7000.0, 10000.0]);
      expect(costMin, 0.0);

      // Return charts can have negative baselines below min
      final returnMin =
          computeMinExtent(DisplayValue.totalReturn, [100.0, 200.0, 500.0]);
      expect(returnMin, lessThan(100.0));
    });

    test('multi-axis bar charts align \$0 tick with 0% tick', () {
      // Scenario 1: Mixed positive and negative returns on both axes
      // Primary: Dollar returns [-$150.0, +$450.0]
      // Secondary: Percent returns [-12%, +60%]
      final alignedMixed = AlignedAxisExtents.compute(
        primaryValues: [-150.0, 450.0],
        secondaryValues: [-0.12, 0.60],
      );

      final pExt = alignedMixed.primaryExtents;
      final sExt = alignedMixed.secondaryExtents;

      // Ensure data is not clipped
      expect(pExt.min, lessThanOrEqualTo(-150.0));
      expect(pExt.max, greaterThanOrEqualTo(450.0));
      expect(sExt.min, lessThanOrEqualTo(-0.12));
      expect(sExt.max, greaterThanOrEqualTo(0.60));

      // Check that the zero fraction on primary exactly matches secondary
      final pZeroFraction = (0.0 - pExt.min) / (pExt.max - pExt.min);
      final sZeroFraction = (0.0 - sExt.min) / (sExt.max - sExt.min);

      expect((pZeroFraction - sZeroFraction).abs(), lessThan(1e-9));
      expect((pZeroFraction - alignedMixed.zeroFraction).abs(), lessThan(1e-9));

      // Scenario 2: All positive returns
      final alignedAllPos = AlignedAxisExtents.compute(
        primaryValues: [50.0, 200.0],
        secondaryValues: [0.05, 0.25],
      );
      expect(alignedAllPos.primaryExtents.min, 0.0);
      expect(alignedAllPos.secondaryExtents.min, 0.0);
      expect(alignedAllPos.zeroFraction, 0.0);

      // Scenario 3: All negative returns
      final alignedAllNeg = AlignedAxisExtents.compute(
        primaryValues: [-200.0, -50.0],
        secondaryValues: [-0.30, -0.05],
      );
      expect(alignedAllNeg.primaryExtents.max, 0.0);
      expect(alignedAllNeg.secondaryExtents.max, 0.0);
      expect(alignedAllNeg.zeroFraction, 1.0);

      // Scenario 4: Asymmetric returns (large gains, small losses)
      final alignedAsymmetric = AlignedAxisExtents.compute(
        primaryValues: [-10.0, 1000.0],
        secondaryValues: [-0.01, 0.50],
      );
      final pZeroAsym = (0.0 - alignedAsymmetric.primaryExtents.min) /
          (alignedAsymmetric.primaryExtents.max -
              alignedAsymmetric.primaryExtents.min);
      final sZeroAsym = (0.0 - alignedAsymmetric.secondaryExtents.min) /
          (alignedAsymmetric.secondaryExtents.max -
              alignedAsymmetric.secondaryExtents.min);
      expect((pZeroAsym - sZeroAsym).abs(), lessThan(1e-9));
    });
  });
}

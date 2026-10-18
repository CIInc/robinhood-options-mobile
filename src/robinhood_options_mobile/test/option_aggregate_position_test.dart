import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/model/option_aggregate_position.dart';

void main() {
  test('parses PaperTradingStore camelCase option instrument metadata', () {
    final position = OptionAggregatePosition.fromJson({
      'id': 'paper-option-position',
      'chain': 'aapl-chain',
      'account': 'paper_account',
      'symbol': 'AAPL',
      'strategy': 'call',
      'average_open_price': 1.25,
      'legs': [
        {
          'id': 'paper-leg',
          'position': 'paper-position',
          'position_type': 'long',
          'option': '/options/aapl-call/',
          'position_effect': 'open',
          'ratio_quantity': 1,
          'side': 'buy',
          'expiration_date': '2026-09-18T00:00:00.000Z',
          'strike_price': 250.0,
          'option_type': 'call',
          'executions': <dynamic>[],
        },
      ],
      'quantity': 1.0,
      'intraday_average_open_price': 1.25,
      'intraday_quantity': 1.0,
      'direction': 'debit',
      'intraday_direction': 'debit',
      'trade_value_multiplier': 100.0,
      'created_at': '2026-08-03T10:00:00.000Z',
      'updated_at': '2026-08-03T10:00:00.000Z',
      'strategy_code': 'long_call',
      'optionInstrument': {
        'chain_id': 'aapl-chain',
        'chain_symbol': 'AAPL',
        'created_at': '2026-08-03T10:00:00.000Z',
        'expiration_date': '2026-09-18T00:00:00.000Z',
        'id': 'aapl-call',
        'issue_date': '2026-08-01T00:00:00.000Z',
        'min_ticks': {
          'above_tick': 0.05,
          'below_tick': 0.01,
          'cutoff_price': 3.0,
        },
        'rhs_tradability': 'tradable',
        'state': 'active',
        'strike_price': 250.0,
        'tradability': 'tradable',
        'type': 'call',
        'updated_at': '2026-08-03T10:00:00.000Z',
        'url': '/options/aapl-call/',
        'sellout_datetime': null,
        'long_strategy_code': 'long_call',
        'short_strategy_code': 'short_call',
      },
    });

    expect(position.optionInstrument, isNotNull);
    expect(position.optionInstrument!.chainSymbol, 'AAPL');
    expect(position.optionInstrument!.strikePrice, 250.0);
  });
}

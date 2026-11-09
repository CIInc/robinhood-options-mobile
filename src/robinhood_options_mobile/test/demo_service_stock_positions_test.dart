import 'package:flutter_test/flutter_test.dart';
import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/model/brokerage_user.dart';
import 'package:robinhood_options_mobile/model/instrument.dart';
import 'package:robinhood_options_mobile/model/instrument_position_store.dart';
import 'package:robinhood_options_mobile/model/instrument_store.dart';
import 'package:robinhood_options_mobile/model/quote_store.dart';
import 'package:robinhood_options_mobile/services/demo_service.dart';

void main() {
  test('ignores instruments without a matching stock position', () async {
    final service = _OrphanInstrumentDemoService();
    final user = BrokerageUser(BrokerageSource.demo, 'demo_user', null, null);
    final positions = await service.getStockPositionStore(
      user,
      InstrumentPositionStore(),
      InstrumentStore(),
      QuoteStore(),
    );

    expect(positions.items, isNotEmpty);
    expect(positions.items.every((position) => position.instrumentObj == null),
        isTrue);
  });
}

class _OrphanInstrumentDemoService extends DemoService {
  @override
  Future<List<Instrument>> getInstrumentsByIds(
    BrokerageUser user,
    InstrumentStore store,
    List<String> ids,
  ) async {
    return [
      Instrument.fromJson({'id': 'orphan', 'symbol': 'ORPHAN'})
    ];
  }
}

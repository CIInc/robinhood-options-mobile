import 'package:robinhood_options_mobile/enums.dart';
import 'package:robinhood_options_mobile/services/ibrokerage_service.dart';
import 'package:robinhood_options_mobile/services/robinhood_service.dart';
import 'package:robinhood_options_mobile/services/schwab_service.dart';

class AgenticTradingBrokerageServiceFactory {
  static IBrokerageService? forSource(
    BrokerageSource source, {
    IBrokerageService Function()? robinhoodFactory,
    IBrokerageService Function()? schwabFactory,
  }) =>
      switch (source) {
        BrokerageSource.robinhood =>
          (robinhoodFactory ?? RobinhoodService.new)(),
        BrokerageSource.schwab => (schwabFactory ?? SchwabService.new)(),
        _ => null,
      };
}

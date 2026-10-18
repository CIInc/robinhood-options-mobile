import 'package:robinhood_options_mobile/model/trade_strategy_config.dart';

void main() {
  final config = TradeStrategyConfig();
  print('priceMovement: ${config.enabledIndicators['priceMovement']}');
  print('momentum: ${config.enabledIndicators['momentum']}');
}

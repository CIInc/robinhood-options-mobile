enum StrategyType {
  single,
  vertical,
  calendar,
  diagonal,
  straddle,
  strangle,
  shortStraddle,
  shortStrangle,
  ironCondor,
  butterfly,
  ironButterfly,
  condor,
  jadeLizard,
  ratioSpread,
  backSpread,
  box,
  strap,
  strip,
  seagull,
  synthetic,
  custom
}

class OptionStrategy {
  final StrategyType type;
  final String name;
  final String description;
  final List<StrategyLegTemplate> legTemplates;
  final List<String> tags;

  OptionStrategy({
    required this.type,
    required this.name,
    required this.description,
    required this.legTemplates,
    this.tags = const [],
  });

  static final List<OptionStrategy> strategies = [
    OptionStrategy(
      type: StrategyType.single,
      name: 'Single Option',
      description:
          'Buying or selling a single call or put option. Buying offers leverage with limited risk; selling offers income with potentially unlimited risk.',
      legTemplates: [
        StrategyLegTemplate(name: 'Option', action: LegAction.any),
      ],
      tags: ['Directional'],
    ),
    OptionStrategy(
      type: StrategyType.vertical,
      name: 'Bull Call Spread',
      description:
          'A bullish vertical spread. Buy a lower strike call and sell a higher strike call. Limits both risk and profit.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Call (Low)', action: LegAction.buy, type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell Call (High)',
            action: LegAction.sell,
            type: LegType.call),
      ],
      tags: ['Bullish', 'Risk Defined', 'Debit'],
    ),
    OptionStrategy(
      type: StrategyType.vertical,
      name: 'Bear Call Spread',
      description:
          'A bearish vertical spread. Sell a lower strike call and buy a higher strike call. Limits both risk and profit.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Call (Low)',
            action: LegAction.sell,
            type: LegType.call),
        StrategyLegTemplate(
            name: 'Buy Call (High)', action: LegAction.buy, type: LegType.call),
      ],
      tags: ['Bearish', 'Risk Defined', 'Credit'],
    ),
    OptionStrategy(
      type: StrategyType.vertical,
      name: 'Bull Put Spread',
      description:
          'A bullish vertical spread. Buy a lower strike put and sell a higher strike put. Limits both risk and profit.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Put (Low)', action: LegAction.buy, type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell Put (High)', action: LegAction.sell, type: LegType.put),
      ],
      tags: ['Bullish', 'Risk Defined', 'Credit'],
    ),
    OptionStrategy(
      type: StrategyType.vertical,
      name: 'Bear Put Spread',
      description:
          'A bearish vertical spread. Sell a lower strike put and buy a higher strike put. Limits both risk and profit.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Put (Low)', action: LegAction.sell, type: LegType.put),
        StrategyLegTemplate(
            name: 'Buy Put (High)', action: LegAction.buy, type: LegType.put),
      ],
      tags: ['Bearish', 'Risk Defined', 'Debit'],
    ),
    OptionStrategy(
      type: StrategyType.straddle,
      name: 'Straddle',
      description:
          'A neutral strategy that profits from significant volatility in either direction. Involves buying both a call and a put at the same strike and expiration.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Call', action: LegAction.buy, type: LegType.call),
        StrategyLegTemplate(
            name: 'Put', action: LegAction.buy, type: LegType.put),
      ],
      tags: ['Neutral', 'Volatility', 'Debit', 'Undefined Risk'],
    ),
    OptionStrategy(
      type: StrategyType.strangle,
      name: 'Strangle',
      description:
          'Similar to a Straddle but cheaper to enter. Profits from a large move in either direction. Involves buying out-of-the-money call and put options.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Call', action: LegAction.buy, type: LegType.call),
        StrategyLegTemplate(
            name: 'Put', action: LegAction.buy, type: LegType.put),
      ],
      tags: ['Neutral', 'Volatility', 'Debit', 'Undefined Risk'],
    ),
    OptionStrategy(
      type: StrategyType.shortStraddle,
      name: 'Short Straddle',
      description:
          'A neutral strategy that profits from low volatility. Involves selling both a call and a put at the same strike and expiration. Unlimited risk.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Call', action: LegAction.sell, type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell Put', action: LegAction.sell, type: LegType.put),
      ],
      tags: ['Neutral', 'Income', 'Credit', 'Undefined Risk'],
    ),
    OptionStrategy(
      type: StrategyType.shortStrangle,
      name: 'Short Strangle',
      description:
          'A neutral strategy that profits from the stock staying within a range. Involves selling out-of-the-money call and put options. Unlimited risk.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Call', action: LegAction.sell, type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell Put', action: LegAction.sell, type: LegType.put),
      ],
      tags: ['Neutral', 'Income', 'Credit', 'Undefined Risk'],
    ),
    OptionStrategy(
      type: StrategyType.ironCondor,
      name: 'Iron Condor',
      description:
          'A neutral strategy designed to profit from low volatility. It combines a Bull Put Spread and a Bear Call Spread to define a range where the stock is expected to stay.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Put', action: LegAction.buy, type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell Put', action: LegAction.sell, type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell Call', action: LegAction.sell, type: LegType.call),
        StrategyLegTemplate(
            name: 'Buy Call', action: LegAction.buy, type: LegType.call),
      ],
      tags: ['Neutral', 'Income', 'Risk Defined', 'Credit'],
    ),
    OptionStrategy(
      type: StrategyType.ironCondor,
      name: 'Reverse Iron Condor',
      description:
          'A volatility strategy. Buy a Bull Call Spread and a Bear Put Spread. Profits from a large move in either direction.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Put', action: LegAction.sell, type: LegType.put),
        StrategyLegTemplate(
            name: 'Buy Put', action: LegAction.buy, type: LegType.put),
        StrategyLegTemplate(
            name: 'Buy Call', action: LegAction.buy, type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell Call', action: LegAction.sell, type: LegType.call),
      ],
      tags: ['Volatility', 'Risk Defined', 'Debit'],
    ),
    OptionStrategy(
      type: StrategyType.butterfly,
      name: 'Long Call Butterfly',
      description:
          'A neutral strategy with high reward-to-risk ratio. Buy 1 lower strike call, sell 2 middle strike calls, buy 1 higher strike call.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Call (Low)', action: LegAction.buy, type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell 2 Calls (Mid)',
            action: LegAction.sell,
            type: LegType.call,
            ratio: 2),
        StrategyLegTemplate(
            name: 'Buy Call (High)', action: LegAction.buy, type: LegType.call),
      ],
      tags: ['Neutral', 'Risk Defined', 'Debit'],
    ),
    OptionStrategy(
      type: StrategyType.butterfly,
      name: 'Long Put Butterfly',
      description:
          'A neutral strategy with high reward-to-risk ratio. Buy 1 lower strike put, sell 2 middle strike puts, buy 1 higher strike put.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Put (Low)', action: LegAction.buy, type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell 2 Puts (Mid)',
            action: LegAction.sell,
            type: LegType.put,
            ratio: 2),
        StrategyLegTemplate(
            name: 'Buy Put (High)', action: LegAction.buy, type: LegType.put),
      ],
      tags: ['Neutral', 'Risk Defined', 'Debit'],
    ),
    OptionStrategy(
      type: StrategyType.calendar,
      name: 'Long Call Calendar Spread',
      description:
          'A neutral-to-bullish strategy. Sell a short-term call and buy a longer-term call at the same strike.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Call (Long-term)',
            action: LegAction.buy,
            type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell Call (Short-term)',
            action: LegAction.sell,
            type: LegType.call),
      ],
      tags: ['Neutral', 'Calendar', 'Debit'],
    ),
    OptionStrategy(
      type: StrategyType.calendar,
      name: 'Long Put Calendar Spread',
      description:
          'A neutral-to-bearish strategy. Sell a short-term put and buy a longer-term put at the same strike.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Put (Long-term)',
            action: LegAction.buy,
            type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell Put (Short-term)',
            action: LegAction.sell,
            type: LegType.put),
      ],
      tags: ['Neutral', 'Calendar', 'Debit'],
    ),
    OptionStrategy(
      type: StrategyType.diagonal,
      name: 'Long Call Diagonal Spread',
      description:
          'Buy a long-term call (usually ITM) and sell a short-term call (usually OTM).',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Call (Long-term)',
            action: LegAction.buy,
            type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell Call (Short-term)',
            action: LegAction.sell,
            type: LegType.call),
      ],
      tags: ['Directional', 'Calendar', 'Debit'],
    ),
    OptionStrategy(
      type: StrategyType.diagonal,
      name: 'Long Put Diagonal Spread',
      description:
          'Buy a long-term put (usually ITM) and sell a short-term put (usually OTM).',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Put (Long-term)',
            action: LegAction.buy,
            type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell Put (Short-term)',
            action: LegAction.sell,
            type: LegType.put),
      ],
      tags: ['Directional', 'Calendar', 'Debit'],
    ),
    OptionStrategy(
      type: StrategyType.ironButterfly,
      name: 'Iron Butterfly',
      description:
          'A neutral strategy similar to an Iron Condor but with a narrower profit zone and higher potential profit. Involves selling a straddle and buying a strangle for protection.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Put', action: LegAction.buy, type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell Put', action: LegAction.sell, type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell Call', action: LegAction.sell, type: LegType.call),
        StrategyLegTemplate(
            name: 'Buy Call', action: LegAction.buy, type: LegType.call),
      ],
      tags: ['Neutral', 'Income', 'Risk Defined', 'Credit'],
    ),
    OptionStrategy(
      type: StrategyType.ironButterfly,
      name: 'Reverse Iron Butterfly',
      description:
          'A volatility strategy. Buy a straddle and sell a strangle. Profits from a large move in either direction.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Put', action: LegAction.sell, type: LegType.put),
        StrategyLegTemplate(
            name: 'Buy Put', action: LegAction.buy, type: LegType.put),
        StrategyLegTemplate(
            name: 'Buy Call', action: LegAction.buy, type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell Call', action: LegAction.sell, type: LegType.call),
      ],
      tags: ['Volatility', 'Risk Defined', 'Debit'],
    ),
    OptionStrategy(
      type: StrategyType.condor,
      name: 'Long Call Condor',
      description:
          'A neutral strategy. Buy lower strike call, sell two middle strike calls, buy higher strike call.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Call (Low)', action: LegAction.buy, type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell Call (Mid-Low)',
            action: LegAction.sell,
            type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell Call (Mid-High)',
            action: LegAction.sell,
            type: LegType.call),
        StrategyLegTemplate(
            name: 'Buy Call (High)', action: LegAction.buy, type: LegType.call),
      ],
      tags: ['Neutral', 'Risk Defined', 'Debit'],
    ),
    OptionStrategy(
      type: StrategyType.condor,
      name: 'Long Put Condor',
      description:
          'A neutral strategy. Buy lower strike put, sell two middle strike puts, buy higher strike put.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Put (Low)', action: LegAction.buy, type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell Put (Mid-Low)',
            action: LegAction.sell,
            type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell Put (Mid-High)',
            action: LegAction.sell,
            type: LegType.put),
        StrategyLegTemplate(
            name: 'Buy Put (High)', action: LegAction.buy, type: LegType.put),
      ],
      tags: ['Neutral', 'Risk Defined', 'Debit'],
    ),
    OptionStrategy(
      type: StrategyType.jadeLizard,
      name: 'Jade Lizard',
      description:
          'A slightly bullish to neutral strategy that combines a short put with a short call spread. It is designed to have no upside risk if the stock rallies.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Put', action: LegAction.sell, type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell Call', action: LegAction.sell, type: LegType.call),
        StrategyLegTemplate(
            name: 'Buy Call', action: LegAction.buy, type: LegType.call),
      ],
      tags: ['Bullish', 'Income', 'Credit', 'Undefined Risk'],
    ),
    OptionStrategy(
      type: StrategyType.ratioSpread,
      name: 'Call Ratio Spread',
      description:
          'A bullish strategy where you buy one call and sell multiple calls (usually 2) at a higher strike. Profits from a moderate rise in stock price.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Call (Low)', action: LegAction.buy, type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell 2 Calls (High)',
            action: LegAction.sell,
            type: LegType.call,
            ratio: 2),
      ],
      tags: ['Bullish', 'Income', 'Undefined Risk'],
    ),
    OptionStrategy(
      type: StrategyType.ratioSpread,
      name: 'Put Ratio Spread',
      description:
          'A bearish strategy where you buy one put and sell multiple puts (usually 2) at a lower strike. Profits from a moderate fall in stock price.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Put (High)', action: LegAction.buy, type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell 2 Puts (Low)',
            action: LegAction.sell,
            type: LegType.put,
            ratio: 2),
      ],
      tags: ['Bearish', 'Income', 'Undefined Risk'],
    ),
    OptionStrategy(
      type: StrategyType.backSpread,
      name: 'Call Back Spread',
      description:
          'A bullish volatility strategy. Sell a lower strike call and buy multiple higher strike calls. Profits from a large upside move.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Call (Low)',
            action: LegAction.sell,
            type: LegType.call),
        StrategyLegTemplate(
            name: 'Buy 2 Calls (High)',
            action: LegAction.buy,
            type: LegType.call,
            ratio: 2),
      ],
      tags: ['Bullish', 'Volatility', 'Debit', 'Undefined Risk'],
    ),
    OptionStrategy(
      type: StrategyType.backSpread,
      name: 'Put Back Spread',
      description:
          'A bearish volatility strategy. Sell a higher strike put and buy multiple lower strike puts. Profits from a large downside move.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Put (High)', action: LegAction.sell, type: LegType.put),
        StrategyLegTemplate(
            name: 'Buy 2 Puts (Low)',
            action: LegAction.buy,
            type: LegType.put,
            ratio: 2),
      ],
      tags: ['Bearish', 'Volatility', 'Debit', 'Undefined Risk'],
    ),
    OptionStrategy(
      type: StrategyType.box,
      name: 'Box Spread',
      description:
          'An arbitrage strategy that combines a Bull Call Spread and a Bear Put Spread. It should have a risk-free profit if the price is favorable.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Call (Low)', action: LegAction.buy, type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell Call (High)',
            action: LegAction.sell,
            type: LegType.call),
        StrategyLegTemplate(
            name: 'Buy Put (High)', action: LegAction.buy, type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell Put (Low)', action: LegAction.sell, type: LegType.put),
      ],
      tags: ['Neutral', 'Risk Defined'],
    ),
    OptionStrategy(
      type: StrategyType.strap,
      name: 'Strap',
      description:
          'A bullish volatility strategy. Similar to a straddle, but involves buying 2 calls and 1 put. Profits more from an upside move.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy 2 Calls',
            action: LegAction.buy,
            type: LegType.call,
            ratio: 2),
        StrategyLegTemplate(
            name: 'Buy Put', action: LegAction.buy, type: LegType.put),
      ],
      tags: ['Bullish', 'Volatility', 'Debit'],
    ),
    OptionStrategy(
      type: StrategyType.strip,
      name: 'Strip',
      description:
          'A bearish volatility strategy. Similar to a straddle, but involves buying 1 call and 2 puts. Profits more from a downside move.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Call', action: LegAction.buy, type: LegType.call),
        StrategyLegTemplate(
            name: 'Buy 2 Puts',
            action: LegAction.buy,
            type: LegType.put,
            ratio: 2),
      ],
      tags: ['Bearish', 'Volatility', 'Debit'],
    ),
    OptionStrategy(
      type: StrategyType.butterfly,
      name: 'Short Call Butterfly',
      description:
          'A volatility strategy. Sell 1 lower strike call, buy 2 middle strike calls, sell 1 higher strike call. Profits from a large move in either direction.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Call (Low)',
            action: LegAction.sell,
            type: LegType.call),
        StrategyLegTemplate(
            name: 'Buy 2 Calls (Mid)',
            action: LegAction.buy,
            type: LegType.call,
            ratio: 2),
        StrategyLegTemplate(
            name: 'Sell Call (High)',
            action: LegAction.sell,
            type: LegType.call),
      ],
      tags: ['Volatility', 'Risk Defined', 'Credit'],
    ),
    OptionStrategy(
      type: StrategyType.butterfly,
      name: 'Short Put Butterfly',
      description:
          'A volatility strategy. Sell 1 lower strike put, buy 2 middle strike puts, sell 1 higher strike put. Profits from a large move in either direction.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Put (Low)', action: LegAction.sell, type: LegType.put),
        StrategyLegTemplate(
            name: 'Buy 2 Puts (Mid)',
            action: LegAction.buy,
            type: LegType.put,
            ratio: 2),
        StrategyLegTemplate(
            name: 'Sell Put (High)', action: LegAction.sell, type: LegType.put),
      ],
      tags: ['Volatility', 'Risk Defined', 'Credit'],
    ),
    OptionStrategy(
      type: StrategyType.condor,
      name: 'Short Call Condor',
      description:
          'A volatility strategy. Sell lower strike call, buy two middle strike calls, sell higher strike call. Profits from a large move in either direction.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Call (Low)',
            action: LegAction.sell,
            type: LegType.call),
        StrategyLegTemplate(
            name: 'Buy Call (Mid-Low)',
            action: LegAction.buy,
            type: LegType.call),
        StrategyLegTemplate(
            name: 'Buy Call (Mid-High)',
            action: LegAction.buy,
            type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell Call (High)',
            action: LegAction.sell,
            type: LegType.call),
      ],
      tags: ['Volatility', 'Risk Defined', 'Credit'],
    ),
    OptionStrategy(
      type: StrategyType.condor,
      name: 'Short Put Condor',
      description:
          'A volatility strategy. Sell lower strike put, buy two middle strike puts, sell higher strike put. Profits from a large move in either direction.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Put (Low)', action: LegAction.sell, type: LegType.put),
        StrategyLegTemplate(
            name: 'Buy Put (Mid-Low)',
            action: LegAction.buy,
            type: LegType.put),
        StrategyLegTemplate(
            name: 'Buy Put (Mid-High)',
            action: LegAction.buy,
            type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell Put (High)', action: LegAction.sell, type: LegType.put),
      ],
      tags: ['Volatility', 'Risk Defined', 'Credit'],
    ),
    OptionStrategy(
      type: StrategyType.seagull,
      name: 'Bull Seagull',
      description:
          'A bullish strategy. Buy a Call Spread and sell an OTM Put to finance it. Profits from a rise in stock price.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Put (Lower)',
            action: LegAction.sell,
            type: LegType.put),
        StrategyLegTemplate(
            name: 'Buy Call (Low)', action: LegAction.buy, type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell Call (High)',
            action: LegAction.sell,
            type: LegType.call),
      ],
      tags: ['Bullish', 'Income', 'Undefined Risk'],
    ),
    OptionStrategy(
      type: StrategyType.seagull,
      name: 'Bear Seagull',
      description:
          'A bearish strategy. Buy a Put Spread and sell an OTM Call to finance it. Profits from a fall in stock price.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Call (Higher)',
            action: LegAction.sell,
            type: LegType.call),
        StrategyLegTemplate(
            name: 'Buy Put (High)', action: LegAction.buy, type: LegType.put),
        StrategyLegTemplate(
            name: 'Sell Put (Low)', action: LegAction.sell, type: LegType.put),
      ],
      tags: ['Bearish', 'Income', 'Undefined Risk'],
    ),
    OptionStrategy(
      type: StrategyType.synthetic,
      name: 'Synthetic Long Stock',
      description:
          'Simulates a long stock position using options. Buy a call and sell a put at the same strike price.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Buy Call', action: LegAction.buy, type: LegType.call),
        StrategyLegTemplate(
            name: 'Sell Put', action: LegAction.sell, type: LegType.put),
      ],
      tags: ['Bullish', 'Directional', 'Undefined Risk'],
    ),
    OptionStrategy(
      type: StrategyType.synthetic,
      name: 'Synthetic Short Stock',
      description:
          'Simulates a short stock position using options. Sell a call and buy a put at the same strike price.',
      legTemplates: [
        StrategyLegTemplate(
            name: 'Sell Call', action: LegAction.sell, type: LegType.call),
        StrategyLegTemplate(
            name: 'Buy Put', action: LegAction.buy, type: LegType.put),
      ],
      tags: ['Bearish', 'Directional', 'Undefined Risk'],
    ),
    OptionStrategy(
      type: StrategyType.custom,
      name: 'Custom',
      description:
          'Build your own strategy by selecting up to 4 legs. Combine calls and puts to create unique risk/reward profiles.',
      legTemplates: [
        StrategyLegTemplate(name: 'Leg 1', action: LegAction.any),
        StrategyLegTemplate(name: 'Leg 2', action: LegAction.any),
        StrategyLegTemplate(name: 'Leg 3', action: LegAction.any),
        StrategyLegTemplate(name: 'Leg 4', action: LegAction.any),
      ],
      tags: ['Custom'],
    ),
  ];
}

enum LegAction { buy, sell, any }

enum LegType { call, put, any }

class StrategyLegTemplate {
  final String name;
  final LegAction action;
  final LegType type;
  final int ratio;

  StrategyLegTemplate({
    required this.name,
    this.action = LegAction.any,
    this.type = LegType.any,
    this.ratio = 1,
  });
}

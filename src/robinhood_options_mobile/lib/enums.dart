enum UserRole { user, admin }

enum FeatureRolloutMode {
  disabled,
  adminOnly,
  betaOptIn,
  public;

  static FeatureRolloutMode fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'disabled':
        return FeatureRolloutMode.disabled;
      case 'admin_only':
      case 'adminonly':
        return FeatureRolloutMode.adminOnly;
      case 'beta_opt_in':
      case 'betaoptin':
      case 'beta':
        return FeatureRolloutMode.betaOptIn;
      case 'public':
      case 'enabled':
        return FeatureRolloutMode.public;
      default:
        return FeatureRolloutMode.disabled;
    }
  }
}

enum FeatureBundle {
  advancedResearch,
  aiResearch,
  advancedTrading,
  backtesting,
  riskGuardrails,
  socialCopy,
  investorGroups,
  accountTools,
  extendedBrokerages,
  automatedTrading,
  agenticTrading,
  macroIntelligence;

  String get remoteConfigKey => switch (this) {
        FeatureBundle.advancedResearch => 'beta_advanced_research',
        FeatureBundle.aiResearch => 'beta_ai_research',
        FeatureBundle.advancedTrading => 'beta_advanced_trading',
        FeatureBundle.backtesting => 'beta_backtesting',
        FeatureBundle.riskGuardrails => 'beta_risk_guardrails',
        FeatureBundle.socialCopy => 'beta_social_copy',
        FeatureBundle.investorGroups => 'beta_investor_groups',
        FeatureBundle.accountTools => 'beta_account_tools',
        FeatureBundle.extendedBrokerages => 'beta_extended_brokerages',
        FeatureBundle.automatedTrading => 'beta_automated_trading',
        FeatureBundle.agenticTrading => 'beta_agentic_trading',
        FeatureBundle.macroIntelligence => 'beta_macro_intelligence',
      };

  String get displayName => switch (this) {
        FeatureBundle.advancedResearch => 'Advanced Research & Flow',
        FeatureBundle.aiResearch => 'AI Market Copilot & Assistant',
        FeatureBundle.advancedTrading => 'Advanced Trading (Multi-Leg Spreads)',
        FeatureBundle.backtesting => 'Strategy Backtesting',
        FeatureBundle.riskGuardrails =>
          'Risk Circuit Breakers & Tilt Guardrails',
        FeatureBundle.socialCopy => 'Social Sharing & Copy Trading',
        FeatureBundle.investorGroups => 'Investor Groups & Channels',
        FeatureBundle.accountTools => 'Tax, Margin & Account Tools',
        FeatureBundle.extendedBrokerages => 'Extended Brokerages',
        FeatureBundle.automatedTrading => 'Automated & Algorithmic Orders',
        FeatureBundle.agenticTrading => 'Autonomous Agentic Trading (AI)',
        FeatureBundle.macroIntelligence => 'Macro Assessment & Economic Radar',
      };

  String get description => switch (this) {
        FeatureBundle.advancedResearch =>
          'Options flow, GEX charts, stock screeners, and SEC filings research.',
        FeatureBundle.aiResearch =>
          'AI market assistant chat, strategy coaching, and trade risk copilot.',
        FeatureBundle.advancedTrading =>
          'Multi-leg spread builder, complex option strategy templates, and combo orders.',
        FeatureBundle.backtesting =>
          'Historical strategy backtesting, performance analytics, and simulation.',
        FeatureBundle.riskGuardrails =>
          'Autonomous loss limits, peak-to-trough drawdown protection, rapid-cancel loop detection, and tilt cooling-off locks.',
        FeatureBundle.socialCopy =>
          'Community trade sharing, public profile showcase, and copy trading.',
        FeatureBundle.investorGroups =>
          'Investor group chats, community channels, and group watchlists.',
        FeatureBundle.accountTools =>
          'Banking, tax documents, day trade monitor, margin buffer, and tax lot optimizer.',
        FeatureBundle.extendedBrokerages =>
          'Connect alternative brokerage accounts (Fidelity CSV import, Plaid).',
        FeatureBundle.automatedTrading =>
          'Rule-based bracket orders, trailing stop triggers, and automated execution.',
        FeatureBundle.agenticTrading =>
          'Autonomous AI agent market reasoning and algorithmic order placement.',
        FeatureBundle.macroIntelligence =>
          'Macro economic regime tracking, Fed rate forecasts, and yield curve shifts.',
      };
}

enum SortType { alphabetical, change }

enum SortDirection { asc, desc }

enum ChartDateSpan {
  hour,
  day,
  week,
  month,
  month_3,
  rolling_30,
  rolling_60,
  rolling_90,
  ytd,
  year,
  year_2,
  year_3,
  year_5,
  all
}

extension ChartDateSpanDisplay on ChartDateSpan {
  String get label => switch (this) {
        ChartDateSpan.hour => '1H',
        ChartDateSpan.day => '1D',
        ChartDateSpan.week => '1W',
        ChartDateSpan.month => '1M',
        ChartDateSpan.month_3 => '3M',
        ChartDateSpan.rolling_30 => '30D',
        ChartDateSpan.rolling_60 => '60D',
        ChartDateSpan.rolling_90 => '90D',
        ChartDateSpan.ytd => 'YTD',
        ChartDateSpan.year => '1Y',
        ChartDateSpan.year_2 => '2Y',
        ChartDateSpan.year_3 => '3Y',
        ChartDateSpan.year_5 => '5Y',
        ChartDateSpan.all => 'All',
      };
}

enum Bounds { regular, t24_7, trading }

enum OptionsView { grouped, list }

enum DisplayValue {
  expirationDate,
  totalCost,
  marketValue,
  lastPrice,
  todayReturnPercent,
  todayReturn,
  totalReturnPercent,
  totalReturn
}

enum BrokerageSource { robinhood, schwab, demo, plaid, fidelity, paper }

String convertChartBoundsFilter(Bounds chartBoundsFilter) {
  String bounds = "regular";
  switch (chartBoundsFilter) {
    case Bounds.regular:
      bounds = "regular";
      break;
    case Bounds.t24_7:
      bounds = "24_7";
      break;
    case Bounds.trading:
      bounds = "trading";
      break;
  }
  return bounds;
}

String convertChartSpanFilter(ChartDateSpan chartDateSpanFilter) {
  String span = "day";
  switch (chartDateSpanFilter) {
    case ChartDateSpan.hour:
      span = "hour";
      //bounds = "24_7"; // Does not work with regular?!
      break;
    case ChartDateSpan.day:
      span = "day";
      break;
    case ChartDateSpan.week:
      span = "week";
      // bounds = "24_7"; // Does not look good with regular?!
      break;
    case ChartDateSpan.month:
      span = "month";
      // bounds = "24_7"; // Does not look good with regular?!
      break;
    case ChartDateSpan.month_3:
      span = "3month";
      break;
    case ChartDateSpan.rolling_30:
      span = "month";
      break;
    case ChartDateSpan.rolling_60:
    case ChartDateSpan.rolling_90:
      span = "3month";
      break;
    case ChartDateSpan.ytd:
      span = "ytd";
      break;
    case ChartDateSpan.year:
      span = "year";
      break;
    case ChartDateSpan.year_2: // Does not exist in Robinhood API
      span = "2year";
      break;
    case ChartDateSpan.year_3: // Does not exist in Robinhood API
      span = "3year";
      break;
    case ChartDateSpan.year_5:
      span = "5year";
      break;
    case ChartDateSpan.all:
      span = "all";
      break;
  }
  return span;
}

List<String> convertChartSpanFilterWithInterval(
    ChartDateSpan chartDateSpanFilter) {
  String interval = "5minute";
  String span = "day";
  switch (chartDateSpanFilter) {
    case ChartDateSpan.hour:
      interval = "15second";
      span = "hour";
      //bounds = "24_7"; // Does not work with regular?!
      break;
    case ChartDateSpan.day:
      interval = "5minute";
      span = "day";
      break;
    case ChartDateSpan.week:
      interval = "10minute"; //"hour";
      span = "week";
      // bounds = "24_7"; // Does not look good with regular?!
      break;
    case ChartDateSpan.month:
      interval = "hour";
      span = "month";
      // bounds = "24_7"; // Does not look good with regular?!
      break;
    case ChartDateSpan.month_3:
      interval = "day";
      span = "3month";
      break;
    case ChartDateSpan.rolling_30:
      interval = "day";
      span = "month";
      break;
    case ChartDateSpan.rolling_60:
    case ChartDateSpan.rolling_90:
      interval = "day";
      span = "3month";
      break;
    case ChartDateSpan.ytd:
      interval = "day";
      span = "ytd";
      break;
    case ChartDateSpan.year:
      interval = "day";
      span = "year";
      break;
    case ChartDateSpan.year_2: // Does not exist in Robinhood API
      interval = "week";
      span = "2year";
      break;
    case ChartDateSpan.year_3: // Does not exist in Robinhood API
      interval = "week";
      span = "3year";
      break;
    case ChartDateSpan.year_5:
      interval = "week";
      span = "5year";
      break;
    case ChartDateSpan.all:
      interval = "week";
      span = "all";
      break;
    //default:
    //  interval = "5minute";
    //  span = "day";
  }
  return [span, interval];
}

enum UserRole { user, admin }

enum SortType { alphabetical, change }

enum SortDirection { asc, desc }

enum ChartDateSpan {
  hour,
  day,
  week,
  month,
  month_3,
  ytd,
  year,
  year_2,
  year_3,
  year_5,
  all
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

enum BrokerageSource { robinhood, schwab, demo, plaid }

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
      // interval = "week";
      span = "all";
      break;
    //default:
    //  interval = "5minute";
    //  span = "day";
  }
  return [span, interval];
}

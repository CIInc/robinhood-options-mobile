# Retail Order Flow & Robinhood Sentiment

RealizeAlpha integrates first-party Robinhood market data to provide real-time retail customer order flow dynamics, net buy/sell ratios, volume trends, and historical sentiment shifts directly within the instrument view.

## Overview

Retail investor sentiment and order routing behavior provide unique insights into retail positioning, momentum, and potential retail-institutional divergences. By tracking first-party Robinhood customer buy and sell ratios along with volume percentage shifts, traders can identify whether retail flows are accumulating or distributing an equity.

## Core Features

### 1. Retail Net Buy/Sell Ratios
- **Buyers vs. Sellers Split Bar:** A visual two-tone ratio gauge highlighting the proportion of Robinhood customer buy orders versus sell orders.
- **Net Retail Bias:** The difference between buy and sell percentages ($\text{Buy \%} - \text{Sell \%}$), indicating net retail accumulation (positive) or distribution (negative).
- **Sentiment Regimes:**
  - **Strong Bullish:** Buy orders $\ge 70\%$ indicating aggressive retail accumulation.
  - **Bullish:** Buy orders between $55\%$ and $70\%$ reflecting sustained buying interest.
  - **Neutral:** Buy orders between $45\%$ and $55\%$ reflecting balanced order flow.
  - **Bearish:** Buy orders between $30\%$ and $45\%$ reflecting net retail selling pressure.
  - **Strong Bearish:** Buy orders $< 30\%$ indicating heavy liquidation or capitulation.

### 2. Order Volume & Momentum Shifts
- **Volume Shift Percentage:** Day-over-day and rolling trend shifts in customer order volume for the instrument.
- **Total Customer Orders:** Order count breakdown between buy and sell orders where provided by the endpoint.
- **Contextual Guidance Banners:** Actionable summary callouts interpreting retail momentum and conviction.

### 3. Historical Daily Sentiment Trend
- **Interactive Trend Table:** An expandable history view tracking daily buy percentage, sell percentage, net flow, and volume shift across recent sessions.
- **Educational Guidance:** Context explaining how first-party order flow reflects retail trader positioning, net accumulation/distribution, and momentum shifts.

## Architecture & Data Flow

### Endpoint
- **Retail Order Flow Summary:** `https://api.robinhood.com/marketdata/equities/summary/robinhood/{instrument_id}/`

#### Example Response
```json
{
  "instrument_id": "943c5009-a0bb-4665-8cf4-a95dab5874e4",
  "daily_transactions": [
    {
      "date": "2026-08-12",
      "net_buy_percentage": 6.733010406913009,
      "net_sell_percentage": -6.733010406913009,
      "buy_volume_percentage_change": null,
      "sell_volume_percentage_change": null
    },
    {
      "date": "2026-08-13",
      "net_buy_percentage": 2.2814620083776327,
      "net_sell_percentage": -2.2814620083776327,
      "buy_volume_percentage_change": -34.70567348204625,
      "sell_volume_percentage_change": -28.611824946031497
    },
    {
      "date": "2026-09-09",
      "net_buy_percentage": 31.58138057168694,
      "net_sell_percentage": -31.58138057168694,
      "buy_volume_percentage_change": 112.82247169835675,
      "sell_volume_percentage_change": 54.81522591529
    }
  ]
}
```

The data binding engine:
1. Maps `daily_transactions` into a chronologically sorted sequence of `RetailOrderFlowPoint` instances.
2. Derives explicit buy/sell ratios from `net_buy_percentage` ($\text{buy} = 50\% + \frac{\text{net\_buy}}{2}$, $\text{sell} = 100\% - \text{buy}$) when explicit buy/sell percentages are not provided.
3. Automatically sets the current `RetailOrderFlow` metrics from the latest available transaction in `daily_transactions`.
4. Captures both `buy_volume_percentage_change` and `sell_volume_percentage_change` to visualize directional customer volume shifts.

### Service Interface
- `IBrokerageService.getRetailSentiment(BrokerageUser user, String instrumentId)`
- Implemented in `RobinhoodService` (live production endpoints) and `DemoService` (deterministic mock environment for offline and testing workflows, supporting tickers such as TSLA, GME, AAPL, and bearish equities).

### Models & Widgets
- **Models:** [src/robinhood_options_mobile/lib/model/retail_order_flow.dart](src/robinhood_options_mobile/lib/model/retail_order_flow.dart) (`RetailOrderFlow`, `RetailOrderFlowPoint`).
- **UI Component:** [src/robinhood_options_mobile/lib/widgets/retail_order_flow_widget.dart](src/robinhood_options_mobile/lib/widgets/retail_order_flow_widget.dart) (`RetailOrderFlowWidget`).
- **Instrument Integration:** Embedded in [src/robinhood_options_mobile/lib/widgets/instrument_widget.dart](src/robinhood_options_mobile/lib/widgets/instrument_widget.dart) CustomScrollView slivers for equity instruments.

## Testing & Verification

Unit and widget tests validate model normalization, regime classification, demo service responses, and expandable widget rendering:

```sh
flutter test test/retail_order_flow_test.dart test/retail_order_flow_widget_test.dart
```

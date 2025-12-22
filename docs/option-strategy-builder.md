# Option Chain Screener & Strategy Builder

RealizeAlpha v0.23.0 introduces powerful tools for options traders: the Option Chain Screener and the Multi-Leg Strategy Builder. These features are designed to help you find the right contracts and construct complex strategies with confidence.

## Option Chain Screener

The Option Chain Screener enhances the standard option chain view with advanced filtering and AI-driven insights.

### Key Features

- **Advanced Filtering**: Filter options not just by expiration and strike, but also by:
  - **Greeks**: Delta, Gamma, Theta, Vega, Rho.
  - **Market Data**: Implied Volatility (IV), Volume, Open Interest.
  - **Price**: Bid/Ask spread, Last Price.
- **AI Recommendations**: Tap the "AI" button to get intelligent contract recommendations based on current market conditions and your trading goals. The AI analyzes the option chain to suggest contracts with favorable risk/reward profiles.
- **Visual Indicators**: Quickly identify high-volume or high-IV contracts with visual cues directly in the chain.
- **Custom Presets**: Save your favorite filter configurations as presets for quick access.

### How to Use

1. Navigate to any instrument's detail page.
2. Tap on "View Options".
3. Tap the **Filter** icon (top right) to open the screener settings.
4. Adjust sliders for Greeks, IV, and other metrics.
5. Tap **Apply** to see the filtered list of contracts.
6. To use AI, tap the **AI** button in the filter sheet or on the chain view (if available) to generate recommendations.

## Multi-Leg Strategy Builder

The Strategy Builder allows you to construct and analyze complex multi-leg options strategies.

### Supported Strategies

- **Vertical Spreads**: Bull Call Spread, Bear Put Spread, Bull Put Spread, Bear Call Spread.
- **Straddles & Strangles**: Long/Short Straddle, Long/Short Strangle.
- **Iron Condors**: Long/Short Iron Condor.
- **Butterflies**: Long/Short Call/Put Butterfly.
- **Custom Strategies**: Build your own custom multi-leg strategies.

### Key Features

- **Visual Payoff Diagrams**: Visualize your potential profit and loss at expiration with interactive charts. See your break-even points and max profit/loss at a glance.
- **P&L Analysis**: detailed breakdown of estimated P&L at different price points.
- **Strategy Greeks**: View the aggregated Greeks for your entire strategy to understand your net exposure.
- **Leg Selection**: Easily select and modify individual legs of your strategy from the option chain.
- **Order Preview**: Review your strategy, estimated cost/credit, and risk metrics before placing the order.

### How to Use

1. Navigate to an instrument's detail page.
2. Tap on **Strategy Builder** (or "Trade" -> "Strategy Builder").
3. Select a strategy template (e.g., "Vertical Spread") or start from scratch.
4. Select the expiration date.
5. Tap on the legs to select specific contracts from the option chain.
6. View the **Payoff Diagram** to analyze the strategy's risk profile.
7. Adjust quantity and price.
8. Tap **Preview Order** to review and submit.

## Integration

Both features are fully integrated with the rest of the RealizeAlpha ecosystem:
- **Real-time Data**: All data is streamed in real-time (brokerage dependent).
- **Portfolio Integration**: Strategies are tracked as multi-leg positions in your portfolio.
- **Risk Management**: Use the Strategy Builder in conjunction with Advanced Risk Controls to ensure your trades align with your risk tolerance.

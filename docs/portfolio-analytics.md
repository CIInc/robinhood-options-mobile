# Portfolio Analytics

The Portfolio Analytics dashboard provides a comprehensive suite of advanced financial metrics to help you understand the risk and return characteristics of your portfolio. It goes beyond simple gain/loss numbers to give you professional-grade insights.

## Key Features

### 1. Benchmark Comparison
- **Selectable Benchmarks**: Compare your portfolio against major market indices:
  - **SPY**: S&P 500 (Large Cap US Stocks)
  - **QQQ**: Nasdaq 100 (Tech/Growth Stocks)
  - **DIA**: Dow Jones Industrial Average (Blue Chip Stocks)
- **Dynamic Calculation**: All metrics are recalculated in real-time based on the selected benchmark and your portfolio's historical performance.

### 2. Smart Insights & Health Score
The dashboard automatically analyzes your metrics to provide plain-English insights and a **Portfolio Health Score** (0-100):
- **Health Score**: A composite score based on Sharpe, Alpha, Drawdown, and Volatility.
  - *80+*: Excellent
  - *50-79*: Moderate
  - *<50*: Needs Attention
- **Performance**: Highlights if you are outperforming or underperforming the benchmark.
- **Risk Assessment**: Warns about high drawdowns or excessive volatility.
- **Volatility Comparison**: Tells you if your portfolio is more or less volatile than the market (e.g., "20% less volatile than the market").

### 3. Risk-Adjusted Return Metrics
These metrics help you evaluate if the returns you are generating are worth the risk you are taking.

- **Sharpe Ratio**: The gold standard for risk-adjusted return. Measures excess return per unit of total risk (volatility).
  - *Goal*: > 1.0 (Good), > 2.0 (Excellent).
- **Sortino Ratio**: Similar to Sharpe, but only penalizes *downside* volatility. This is often more relevant for investors who don't mind upside volatility (big gains).
- **Treynor Ratio**: Measures excess return per unit of *systematic* risk (Beta). Useful for well-diversified portfolios.
- **Information Ratio**: Measures your ability to generate excess returns relative to the benchmark, adjusted for the consistency of those excess returns (Tracking Error).
- **Calmar Ratio**: Annualized return divided by Maximum Drawdown. A great measure of return relative to your worst-case scenario.
- **Omega Ratio**: The probability-weighted ratio of gains vs. losses for a threshold return target. A value > 1 indicates more expected gains than losses.

### 4. Market Comparison Metrics
Understand how your portfolio moves in relation to the broader market.

- **Beta**: Measures volatility relative to the market.
  - *1.0*: Moves in lockstep with the market.
  - *> 1.0*: More volatile (aggressive).
  - *< 1.0*: Less volatile (defensive).
- **Alpha**: The excess return generated *beyond* what would be expected given the portfolio's Beta. Positive Alpha indicates true outperformance.
- **Excess Return**: The simple difference between your portfolio's return and the benchmark's return.

### 5. Risk Metrics
Quantify the potential downside.

- **Max Drawdown**: The largest percentage drop from a peak to a trough. This tells you the "pain" you would have felt during the worst period.
- **Volatility**: The annualized standard deviation of returns. A higher number means wider price swings.
- **VaR (95%)**: Value at Risk. The maximum loss expected over a single day with 95% confidence.
  - *Example*: A VaR of -2% means there is only a 5% chance you will lose more than 2% in a day.

### 6. Integrated Risk Heatmap
The dashboard includes the **[Risk Heatmap](risk-heatmap.md)**, allowing you to visually correlate these high-level metrics with your specific position exposures.

### 7. Tax Optimization
- **[Tax Loss Harvesting](tax-loss-harvesting.md)**: An integrated tool that identifies opportunities to realize losses to offset gains. It features seasonality awareness (highlighting urgency near year-end) and smart visibility to keep your dashboard focused.

## Definitions Guide
Unsure what a metric means? Tap the **Info (i)** icon in the header to view a built-in glossary with simple definitions for all supported metrics.

# Portfolio Analytics

The Portfolio Analytics dashboard provides a comprehensive suite of advanced financial metrics to help you understand the risk and return characteristics of your portfolio. It goes beyond simple gain/loss numbers to give you professional-grade insights.

## Interactive Documentation & Help System

### In-App Help Menu
Access comprehensive documentation directly within the app through the **Help** menu (top-right corner):

- **Quick Guide**: Step-by-step introduction to using portfolio analytics
  - Getting started with benchmark selection
  - Reading and interpreting metrics
  - Understanding key thresholds
  - Taking action based on insights

- **All Definitions**: Complete reference of every metric, organized by category:
  - **Interactive Cards**: Tap metrics with "Tips" badge for detailed examples
  - Risk-Adjusted Returns (Sharpe, Sortino, Treynor, etc.)
  - Market Comparison (Alpha, Beta, Correlation)
  - Risk Metrics (Max Drawdown, Volatility, VaR)
  - Advanced Edge Metrics (Kelly Criterion, Tail Ratio)
  - Daily Return Stats (Win Rate, Profit Factor)

- **Benchmark Guide**: Visual guide explaining when to use each benchmark:
  - SPY (S&P 500) - Large-cap growth
  - QQQ (Nasdaq 100) - Tech/growth focused
  - DIA (Dow Jones) - Blue-chip, dividend portfolios
  - IWM (Russell 2000) - Small-cap investing
  - **Active Indicator**: Shows which benchmark is currently selected

- **Health Score Info**: Detailed breakdown of how your portfolio health score is calculated

### Deep Metric Insights
Selected metrics feature enhanced detail views accessible by tapping on cards with the "Tips" badge:

- **Real-World Examples**: Concrete scenarios illustrating what metric values mean
  - "A Sharpe of 2.5 means you earn 2.5% excess return for every 1% of risk taken"
  - "Alpha of 5% means you outperformed the benchmark by 5% annually"

- **Performance Thresholds**: Visual color-coded indicators showing:
  - 🟢 Excellent performance levels
  - 🟠 Acceptable performance levels
  - 🔴 Areas needing improvement

- **Pro Tips**: Actionable advice for improving each metric:
  - "Diversification and position sizing can improve your Sharpe ratio"
  - "Use stop-losses and position sizing to limit maximum drawdown"
  - "High win rate with low payoff ratio can still be profitable"

### Interactive Tooltips
Every metric features enhanced tooltips with:
- **Bold metric name** for quick identification
- **Detailed definition** explaining what it measures
- **Visual formatting** with proper spacing and readability
- **Extended display time** (8 seconds) for comfortable reading
- **Rich text styling** with multiple font weights and sizes

### Contextual Help
Throughout the interface:
- **Browse by Category**: Organized sections for easy navigation
- Tap any metric to see its definition
- Long-press for extended tooltip display
- Visual indicators (green/red) show good vs. concerning values
- Smart insights provide actionable recommendations

## Key Features

### 1. Benchmark Comparison
- **Selectable Benchmarks**: Compare your portfolio against major market indices:
  - **SPY**: S&P 500 (Large Cap US Stocks)
  - **QQQ**: Nasdaq 100 (Tech/Growth Stocks)
  - **DIA**: Dow Jones Industrial Average (Blue Chip Stocks)
  - **IWM**: Russell 2000 (Small Cap Stocks)
- **Dynamic Calculation**: All metrics are recalculated in real-time based on the selected benchmark and your portfolio's historical performance.

### 2. Smart Insights & Health Score
The dashboard automatically analyzes your metrics to provide plain-English insights and a **Portfolio Health Score** (0-100) with academic-style letter grades:

#### Health Score Grading System
- **A+ (90-100)**: Outstanding - Exceptional performance across all metrics
- **A (85-89)**: Excellent - Strong risk-adjusted returns and management
- **A- (80-84)**: Excellent - Very good performance with room for optimization
- **B+ (75-79)**: Very Good - Solid strategy with consistent execution
- **B (70-74)**: Very Good - Above-average performance
- **B- (65-69)**: Very Good - Acceptable performance overall
- **C+ (60-64)**: Good - Reasonable strategy with areas to improve
- **C (55-59)**: Good - Basic competence, focus on risk management
- **C- (50-54)**: Fair - Borderline performance, needs attention
- **D+ (45-49)**: Below Average - Significant areas for improvement
- **D (40-44)**: Below Average - Poor execution or strategy issues
- **D- (35-39)**: Below Average - Critical issues requiring review
- **F (<35)**: Poor/Critical - Immediate action required

#### Score Calculation
The health score starts at a base of **50** and adjusts based on five key dimensions:
1. **Risk-Adjusted Returns** (Max +35/-15) - Sharpe, Sortino, Treynor, Omega ratios
2. **Market Performance** (Max +20/-15) - Alpha and Information Ratio vs. benchmark
3. **Risk Management** (Max +20/-40) - Drawdown, volatility, VaR/CVaR, correlation, Beta
4. **Efficiency & Consistency** (Max +30/-15) - Profit Factor, Win Rate, Calmar, Payoff Ratio
5. **Advanced Risk & Edge** (Max +15/-15) - Kelly Criterion, Ulcer Index, Tail Ratio

#### Smart Insights
The dashboard provides **contextual, actionable recommendations**:
- **Performance Insights**: Highlights if you are outperforming or underperforming the benchmark with specific alpha values
- **Risk Assessment**: Warns about high drawdowns (categorized as moderate/high/severe/catastrophic) with specific guidance
- **Volatility Comparison**: Tells you if your portfolio is more or less volatile than the market (e.g., "50%+ more volatile than market")
- **Strategy Feedback**: Specific recommendations based on metrics (e.g., "Cut losses faster" for low profit factor, "Add defensive stocks" for high Beta)
- **Edge Quantification**: Shows mathematical edge (Kelly Criterion), stress levels (Ulcer Index), and return skew (Tail Ratio)

### 3. Risk-Adjusted Return Metrics
These metrics help you evaluate if the returns you are generating are worth the risk you are taking.

- **Sharpe Ratio**: The gold standard for risk-adjusted return. Measures excess return per unit of total risk (volatility).
  - *Goal*: > 1.0 (Good), > 1.5 (Very Good), > 2.0 (Excellent), > 2.5 (Outstanding).
- **Sortino Ratio**: Similar to Sharpe, but only penalizes *downside* volatility. This is often more relevant for investors who don't mind upside volatility (big gains).
  - *Goal*: > 0.75 (Good), > 1.5 (Very Good), > 2.5 (Exceptional).
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
  - *Goal*: > 0% (Positive), > 2% (Good), > 5% (Very Good), > 10% (Excellent).
- **Excess Return**: The simple difference between your portfolio's return and the benchmark's return.
- **Correlation**: Measures how closely your portfolio moves with the benchmark.
  - *1.0*: Perfect positive correlation.
  - *0.0*: No correlation.
  - *-1.0*: Perfect negative correlation (moves opposite).

### 5. Risk Metrics
Quantify the potential downside.

- **Max Drawdown**: The largest percentage drop from a peak to a trough. This tells you the "pain" you would have felt during the worst period.
  - *Goal*: < 5% (Exceptional), < 10% (Excellent), < 15% (Good), > 30% (Severe penalty).
- **Volatility**: The annualized standard deviation of returns. A higher number means wider price swings.
- **VaR (95%)**: Value at Risk. The maximum loss expected over a single day with 95% confidence.
  - *Example*: A VaR of -2% means there is only a 5% chance you will lose more than 2% in a day.
- **CVaR (95%)**: Conditional Value at Risk (Expected Shortfall). The average loss expected *given* that the loss is greater than the VaR threshold. This captures the "tail risk" better than VaR.

### 6. Advanced Edge Metrics
Sophisticated metrics to evaluate the statistical edge of your trading strategy.

- **Kelly Criterion**: The optimal position size percentage based on your win rate and payoff ratio to maximize long-term wealth growth. A positive value indicates a mathematical edge.
  - *Goal*: > 0% (Positive edge), > 8% (Strong edge), > 15% (Very strong edge).
- **Ulcer Index**: Measures the depth and duration of drawdowns . Unlike standard deviation, it only penalizes downside volatility. Lower is better (e.g., < 0.05 or 5% is low stress).
- **Tail Ratio**: The ratio of the 95th percentile return to the 5th percentile loss. A value > 1 indicates that your big wins are larger than your big losses (positive skew).
  - *Goal*: > 0.9 (Positive), > 1.0 (Good), > 1.3 (Strong positive skew).
  - *Avoid*: < 0.9 indicates negative skew where losses hurt more than wins help.

### 7. Daily Return Stats
Granular statistics based on your daily P&L.

- **Profit Factor**: Gross Profit divided by Gross Loss. A value > 1.0 means you are profitable.
  - *Goal*: > 1.2 (Good), > 1.5 (Very Good), > 2.0 (Excellent), > 3.0 (Exceptional).
- **Win Rate**: The percentage of days with a positive return.
  - *Goal*: > 50% (Above average), > 55% (Consistent), > 65% (Very consistent).
- **Payoff Ratio**: Average Win divided by Average Loss. Measures the size of your wins relative to your losses.
- **Expectancy**: The average amount you can expect to win (or lose) per day/trade.
- **Streaks**: Tracks your longest consecutive winning and losing streaks.

### 8. ESG Scoring
Evaluate the sustainability of your portfolio.

- **Total ESG Score**: A weighted average of the Environmental, Social, and Governance scores of your holdings.
- **Breakdown**: View individual scores for:
  - **Environmental**: Resource use, emissions, innovation.
  - **Social**: Workforce, human rights, community.
  - **Governance**: Management, shareholders, CSR strategy.

### 9. Integrated Risk Heatmap
The dashboard includes the **[Risk Heatmap](risk-heatmap.md)**, allowing you to visually correlate these high-level metrics with your specific position exposures.

### 10. Tax Optimization
- **[Tax Loss Harvesting](tax-loss-harvesting.md)**: An integrated tool that identifies opportunities to realize losses to offset gains. It features seasonality awareness (highlighting urgency near year-end) and smart visibility to keep your dashboard focused.

## Using the Help System

### Quick Start
1. **Open Portfolio Analytics** from the main navigation
2. **Tap the Help icon** (question mark) in the top-right corner
3. **Choose "Quick Guide"** for a comprehensive introduction
4. **Review key thresholds** to understand what makes a good vs. bad metric

### Learning Path
- **Beginners**: Start with Quick Guide → Benchmark Guide → Health Score Info
- **Intermediate**: Focus on All Definitions and explore each category
- **Advanced**: Use tooltips for quick reference while analyzing specific metrics

### Tips for Best Results
- **Select the right benchmark**: Match your portfolio's investment style
  - Growth/Tech → QQQ
  - Balanced/Large-cap → SPY
  - Conservative/Dividend → DIA
  - Small-cap → IWM
- **Monitor Health Score**: Aim for 60+ (Good) or 80+ (Excellent)
- **Review Smart Insights**: Color-coded by priority (red = urgent, orange = moderate, green = positive)
- **Use tooltips liberally**: Each metric has detailed explanations accessible with a tap
- **Check definitions by category**: Organized into logical groups for easier learning

## Metric Categories Explained

### Risk-Adjusted Returns
Evaluate if your returns justify the risks taken. Higher is generally better.

### Market Comparison  
Understand how your portfolio performs relative to the broader market.

### Risk Metrics
Quantify potential downside and volatility exposure.

### Advanced Edge Metrics
Sophisticated indicators of your strategy's statistical advantage.

### Daily Return Stats
Granular performance metrics based on day-to-day portfolio changes.

## Definitions Guide
Access the complete, categorized glossary by tapping the Help icon and selecting "All Definitions". Each definition includes:
- What the metric measures
- How to interpret it
- Good vs. bad threshold values
- Practical implications for your portfolio

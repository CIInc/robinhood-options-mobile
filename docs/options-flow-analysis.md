# Options Flow Analysis

RealizeAlpha provides advanced Options Flow Analysis to help traders gauge institutional sentiment and identify potential market moves before they happen.

## Features

### Real-Time Flow Monitoring
*   **Sweeps & Blocks:** Detect large institutional orders executed across multiple exchanges (sweeps) or as single large blocks.
*   **Unusual Activity:** Identify options contracts with volume significantly higher than open interest, indicating aggressive positioning.
*   **Dark Pool Activity:** Monitor off-exchange trading volume to spot hidden institutional accumulation or distribution.

### Smart Tags & Flags
Our system automatically tags trades with specific characteristics to help you identify the nature of the flow. Tap on any flag in the app to see its definition.

*   **Super Whale:** Massive premium > $5M. Represents the highest level of institutional conviction.
*   **WHALE:** Large premium orders (>$1M), indicating massive institutional conviction. Follow the big money.
*   **Institutional:** Large block trade > $2M premium. Often indicates institutional rebalancing or positioning.
*   **Large Block:** A single trade execution with significant size (>$200k premium), indicating institutional activity in one transaction.
*   **Golden Sweep:** Aggressive sweep orders with >$1M premium, executed out-of-the-money. Often a strong directional signal.
*   **Steamroller:** Massive size (>$500k), short term (<30 days), aggressive OTM sweep.
*   **Mega Vol:** Volume is >10x Open Interest. Extreme unusual activity indicating a major new position.
*   **Vol Explosion:** Volume is >5x Open Interest. Significant unusual activity.
*   **High Vol/OI:** Volume is >1.5x Open Interest. Indicates unusual interest.
*   **New Position:** Volume exceeds Open Interest, confirming that new contracts are being opened.
*   **Gamma Squeeze:** Short-dated (<7 days), OTM calls with high volume (>5k) and OI (>1k). Can force dealers to buy stock to hedge, fueling the rally.
*   **Panic Hedge:** Short-dated (<7 days), OTM puts with high volume (>5k) and OI (>1k). Indicates fear or hedging against further downside.
*   **Floor Protection:** High volume deep OTM puts. Likely institutional hedging/insurance.
*   **Earnings Play:** Options expiring shortly after an upcoming earnings release (2-14 days). High volatility expected.
*   **IV Crush Risk:** High IV just before earnings. Risk of volatility crush.
*   **Bullish Divergence:** Call buying while stock is down. Smart money betting on a reversal.
*   **Bearish Divergence:** Put buying while stock is up. Smart money betting on a reversal.
*   **Contrarian:** Trades that go against the current stock trend (>2% move).
*   **Extreme IV:** Implied Volatility > 250%. Extreme fear or greed, potential binary event.
*   **High IV:** Implied Volatility > 100%. Market expects a large move.
*   **Low IV:** Implied Volatility < 20%. Cheap premium, often good for long positions.
*   **Cheap Vol:** High volume (>2000) on low-priced options (<$0.50). Speculative activity on cheap contracts.
*   **High Premium:** Significant volume (>100) on expensive options (>$20.00). High capital commitment per contract.
*   **Tight Spread:** Bid-Ask spread < 1%. Indicates high liquidity and potential institutional algo execution.
*   **Wide Spread:** Bid-Ask spread > 10%. Warning: Low liquidity or poor execution prices.
*   **ATM Flow:** At-The-Money options (strike within 1% of spot). High Gamma potential, often used by market makers.
*   **Deep ITM:** Deep In-The-Money contracts (>10% ITM). Often used as a stock replacement strategy.
*   **Deep OTM:** Deep Out-Of-The-Money contracts (>15% OTM). Aggressive speculative bets.
*   **Aggressive:** Orders executed above the ask (buying) or below the bid (selling), showing urgency to get filled.
*   **Above Ask:** Trade executed at a price higher than the ask price. Indicates extreme urgency to buy.
*   **Below Bid:** Trade executed at a price lower than the bid price. Indicates extreme urgency to sell.
*   **Mid Market:** Trade executed between the bid and ask prices. Often indicates a negotiated block trade or less urgency.
*   **Ask Side:** Trade executed at the ask price. Indicates buying pressure.
*   **Bid Side:** Trade executed at the bid price. Indicates selling pressure.
*   **Cross Trade:** High volume trade executed exactly at the Bid or Ask price. Often pre-arranged and neutral in sentiment.
*   **0DTE:** Contracts expiring today. High risk, high reward speculative trading.
*   **0DTE Lotto:** High volume (>1000) OTM options expiring today. Extremely speculative "lotto" ticket bets.
*   **Lotto:** Far OTM (>15%) contracts expiring within 2 weeks with low premium (< $1.00). Low probability, high payout bets.
*   **Weekly OTM:** Out-of-the-money contracts expiring within a week with volume > 500.
*   **LEAPS:** Long-term Equity Anticipation Securities. Contracts expiring in > 1 year (365 days). Long-term conviction.
*   **Leaps Buy:** Long-term OTM bullish speculation.

### Sentiment Analysis
*   **Bullish/Bearish Flow:** Visualize the ratio of bullish (calls bought, puts sold) vs. bearish (puts bought, calls sold) flow.
*   **Premium Analysis:** Track the total premium spent on bullish vs. bearish positions.

### Conviction Score
A proprietary 0-100 score that rates the significance of each trade based on:
*   **Premium Size:** Larger premiums (> $1M) carry significantly more weight.
*   **Flow Type:** Sweeps (urgent execution) score higher than Blocks (negotiated).
*   **Urgency:** OTM, short-dated (especially 0DTE), and aggressive fills add to the score.
*   **Unusual Activity:** Volume exceeding Open Interest (up to >10x) boosts the rating.
*   **Smart Money Flags:** Golden Sweeps, Whales, Gamma Squeezes, Steamrollers, Earnings Plays, and Divergences apply multipliers or bonuses to the final score.

### Filtering & Alerts
*   **Smart Filters:** Filter flow by sector, market cap, expiration, moneyness (ITM/OTM), and **specific flags** (e.g., "Show me only Golden Sweeps").
*   **Custom Alerts:** Set up push notifications for specific flow criteria (e.g., "TSLA Call Sweeps > $1M").

## How to Use

1.  Navigate to the **Search** tab.
2.  Select **Options Flow** from the menu.
3.  **Filter:** Use the filter bar to narrow down results by symbol, sentiment, or specific flags like "WHALE" or "Earnings Play".
4.  **Analyze:** Tap on a flow item to open the **Detail View**. This shows all active flags, moneyness, and detailed contract stats.
5.  **Learn:** Tap on any flag, score, or multiplier badge to see a **Tooltip** with its definition.
6.  **Sort:** Use the sort button to rank trades by Premium, Time, or Volume/OI ratio.

## Methodology

Our flow analysis engine aggregates data from multiple sources to provide a comprehensive view of the options market. We use proprietary algorithms to classify trades as aggressive (buying on the ask) or passive (selling on the bid) to determine sentiment.

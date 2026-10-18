# Carry Trade Optimizer

The **Carry Trade Optimizer** helps traders analyze global interest rate differentials, quantify currency rollover yields, construct risk-adjusted currency baskets, and guard against volatile carry trade unwinds.

## Background & Mechanics

A **currency carry trade** involves borrowing or shorting a low-yielding currency (e.g., the Japanese Yen or Swiss Franc) and buying a higher-yielding currency (e.g., the US Dollar, Australian Dollar, or Mexican Peso) to collect the net interest differential as daily rollover swap.

$$\text{Net Annual Carry (\%)} = (\text{Base Policy Rate} - \text{Quote Policy Rate}) - \text{Spread Haircut}$$

### Daily Rollover Swap
For a $\$10,000$ notional position, daily swap income is approximated by:

$$\text{Daily Swap (\$)} = \frac{\text{Notional (\$)} \times \text{Net Carry Yield (\%)}}{365}$$

## Key Capabilities

### 1. Central Bank Benchmark Rate Monitor
Tracks policy rates, monetary policy trajectories (hiking, holding, cutting), and real inflation-adjusted rates across 10 major central banks:
- **Federal Reserve (USD):** 5.25%
- **European Central Bank (EUR):** 3.75%
- **Bank of England (GBP):** 5.00%
- **Bank of Japan (JPY):** 0.25% (primary funding currency)
- **Swiss National Bank (CHF):** 1.25% (defensive funding currency)
- **Reserve Bank of Australia (AUD):** 4.35%
- **Bank of Canada (CAD):** 4.50%
- **Reserve Bank of New Zealand (NZD):** 5.25%
- **Banco de México (MXN):** 10.75% (high-yield emerging carry)
- **Banco Central do Brasil (BRL):** 10.50%

### 2. Carry-to-Risk Ratio
Raw yield alone does not define an effective carry trade. Volatile exchange rate swings can wipe out months of accumulated swap in days. The Carry Trade Optimizer computes a Sharpe-like **Carry-to-Risk Ratio**:

$$\text{Carry-to-Risk} = \frac{\text{Net Annual Carry (\%)}}{\text{Annualized Realized Volatility (\%)}}$$

Higher ratios indicate superior risk-adjusted compensation for holding the position.

### 3. Basket Optimization Strategies
Constructs diversified currency portfolios based on trader risk profiles:
- **Risk-Adjusted (Sharpe Maximizer):** Optimizes allocations based on the Carry-to-Risk ratio, prioritizing stable yield spreads with low price volatility.
- **Maximum Yield:** Focuses capital on the highest gross interest rate differentials (e.g., USD/MXN, AUD/JPY).
- **Diversified Multi-Funding:** Distributes funding liabilities across multiple low-rate currencies (JPY, CHF, EUR) using inverse-volatility weighting to mitigate single-currency squeeze risks.

### 4. Unwind Risk Analysis
Identifies carry trade vulnerabilities:
- **Central Bank Divergence:** Warnings when funding central banks signal rate hike cycles.
- **VIX / MOVE Volatility Spikes:** Alerts when macro volatility triggers institutional deleveraging.
- **Macro Regime Alignment:** Recommends defensive hedging or de-risking when RealizeAlpha's Macro Assessment enters `RISK_OFF`.

### 5. Live Market Data Integration
- **Real-Time / Delayed Spot Rates:** Dynamically fetches current exchange rates across all carry pairs using batched quotes (`USDJPY=X`, `AUDJPY=X`, `NZDJPY=X`, `GBPJPY=X`, `USDMXN=X`, `EURUSD=X`, `GBPUSD=X`, etc.) via `YahooService.getForexQuotesByIds()`.
- **Dynamic Re-calculation:** Real-time updates to spot prices immediately flow into daily swap calculations, pip values, and carry-to-risk ratio ranking.
- **Manual & Automatic Refresh:** App bar refresh action allows one-tap data refreshes with timestamp indicators.

## Navigation & Access

Access the Carry Trade Optimizer from:
1. **Search Tab:** Under the Research & Analytics section.
2. **Forex Instrument View:** Via the currency exchange icon in the app bar.
3. **Trading Strategies Page:** Accessible from the top action bar.

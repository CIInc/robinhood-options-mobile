# Beta-Weighted Portfolio Delta & Cross-Asset Greeks Engine

RealizeAlpha includes an institutional-grade quantitative risk engine that calculates **Beta-Weighted Portfolio Delta ($\Delta_\beta$)** and aggregate cross-asset Greeks (Gamma, Vega, Theta) across equities, options, futures, cryptocurrencies, and forex.

---

## 1. Overview & Theoretical Foundation

Standard portfolio delta sums raw delta values across options contracts ($\sum \Delta_i$), but raw delta suffers from the **apples-to-oranges fallacy**: 100 deltas of an ultra-volatile tech stock (e.g., NVDA, beta $\beta = 2.1$) represent vastly different dollar exposure than 100 deltas of a defensive consumer staple (e.g., KO, beta $\beta = 0.55$) or a 3x leveraged ETF (e.g., TQQQ, beta $\beta = 3.0$).

**Beta-weighting** normalizes every position in a multi-asset portfolio against a single liquid benchmark index (by default **SPY**, with 1-tap switching to **QQQ**, **DIA**, or **IWM**). This translates disparate holdings into equivalent benchmark index shares:

$$\Delta_{\beta, \text{pos}} = \Delta_{\text{pos}} \times \left(\frac{S_{\text{pos}}}{S_{\text{benchmark}}}\right) \times \beta_{\text{pos}}$$

Where:
*   $\Delta_{\text{pos}}$ is the position's directional sensitivity:
    *   **Equities**: Number of shares held (long $> 0$, short $< 0$).
    *   **Options**: Contract count $\times 100 \times \text{Delta}$ per contract.
    *   **Futures**: Contracts $\times$ Multiplier $\times$ Delta (e.g., /ES = 50x, /NQ = 20x, /YM = 5x).
    *   **Forex / Crypto**: Quantity held $\times$ Asset price $\times$ Benchmark sensitivity.
*   $S_{\text{pos}}$ is the current spot/market price of the underlying asset.
*   $S_{\text{benchmark}}$ is the price of the benchmark index (e.g., SPY at \$500).
*   $\beta_{\text{pos}}$ is the asset's beta relative to the benchmark index ($\frac{\text{Cov}(R_{\text{pos}}, R_{\text{bench}})}{\text{Var}(R_{\text{bench}})}$).

### True Dollar Market Risk ($ Delta per 1% Move)
The dollar risk per 1% move in the benchmark is computed directly as:

$$\$ \Delta_{1\%} = \Delta_{\beta, \text{portfolio}} \times S_{\text{benchmark}} \times 0.01$$

If a portfolio has $\Delta_{\beta-SPY} = +250$ with SPY at \$500, a +1% rally in the S&P 500 will generate an expected gain of:

$$\$ \Delta_{1\%} = 250 \times 500 \times 0.01 = +\$1,250.00$$

---

## 2. Cross-Asset Coverage & Multipliers

The analytics engine (`AnalyticsUtils.calculateBetaWeightedGreeks`) natively aggregates risk across five major asset classes:

| Asset Class | Position Type | Spot Valuation | Beta Fallback Source | Formula |
| :--- | :--- | :--- | :--- | :--- |
| **Equities** | `InstrumentPosition` | Last trade quote / average buy price | Fundamental beta or fallback: 1.0 (default), 3.0 (3x bull), -3.0 (3x bear) | $\text{Shares} \times \left(\frac{S}{S_B}\right) \times \beta$ |
| **Options** | `OptionAggregatePosition` | Underlying instrument quote | Underlying fundamental beta or asset fallback | $\text{Contracts} \times 100 \times \Delta \times \left(\frac{S}{S_B}\right) \times \beta$ |
| **Futures** | `FuturesPositionStore` | Product contract quote / trade price | /ES: 1.0, /NQ: 1.25, /YM: 0.95, /RTY: 1.15, /CL: 0.35, /GC: 0.10 | $\text{Contracts} \times \text{Multiplier} \times \left(\frac{S}{S_B}\right) \times \beta$ |
| **Crypto** | `ForexHolding` | Currency pair quote (BTC, ETH, SOL) | BTC: 1.6, ETH: 1.8, SOL: 2.0, other crypto: 1.4 | $\text{Qty} \times \left(\frac{S}{S_B}\right) \times \beta_{\text{crypto}}$ |
| **Forex** | `ForexHolding` | Fiat currency quote (EUR, GBP, JPY) | Fiat currencies: 0.15 | $\text{Qty} \times \left(\frac{S}{S_B}\right) \times 0.15$ |

### Aggregate Greeks Aggregation
*   **Beta-Weighted Delta ($\Delta_\beta$)**: Sum of equivalent benchmark shares across all positions.
*   **Portfolio Gamma ($\Gamma$)**: Aggregate rate of change of delta per \$1 move in option underlyings:
    $$\Gamma_{\text{portfolio}} = \sum \text{Contracts}_i \times 100 \times \Gamma_i$$
*   **Portfolio Vega ($\nu$)**: Aggregate dollar change per 1% change in implied volatility:
    $$\text{Vega}_{\text{portfolio}} = \sum \text{Contracts}_i \times 100 \times \nu_i$$
*   **Portfolio Theta ($\Theta$)**: Aggregate daily calendar decay in dollars:
    $$\text{Theta}_{\text{portfolio}} = \sum \text{Contracts}_i \times 100 \times \Theta_i$$

---

## 3. UI Component Architecture (`PortfolioGreeksCard`)

The `PortfolioGreeksCard` widget in `lib/widgets/portfolio/portfolio_greeks_card.dart` provides an interactive, institutional-grade analytics dashboard embedded in the Portfolio Risk Section (`RiskSectionPage`):

### Key Visual Elements
1.  **Dual-View Segmented Toggle**:
    *   **Beta-Weighted View**: Shows normalized benchmark-equivalent shares, dollar risk per 1% move, asset class contributions, and top delta drivers.
    *   **Raw Greeks View**: Classic sum of contract Greeks for traders focusing purely on raw options inventory.
2.  **Benchmark Selector Chips**:
    *   Supports quick 1-tap switching between **SPY** (S&P 500), **QQQ** (Nasdaq 100), **DIA** (Dow Jones), and **IWM** (Russell 2000).
    *   Dynamically recalculates all equivalent shares, driver impacts, and stance badges in real-time.
3.  **Portfolio Stance Badge**:
    *   **Bullish**: $\Delta_\beta > +10$ benchmark shares (Green badge).
    *   **Bearish**: $\Delta_\beta < -10$ benchmark shares (Red badge).
    *   **Neutral / Delta-Neutral**: $-10 \le \Delta_\beta \le +10$ benchmark shares (Grey/Neutral badge).
4.  **Delta by Asset Class Chips**:
    *   Visual chips showing sub-totals for **Stocks**, **Options**, **Crypto**, and **Futures**.
5.  **Top Delta Drivers Breakdown**:
    *   Sorted list showing the highest-impact positions driving market exposure, displaying raw shares/contracts, spot price, beta, and net $\Delta_\beta$.
6.  **Educational Modal Bottom Sheet**:
    *   Integrated info button (`Icons.info_outline`) displaying complete mathematical formulations, greek interpretations, and guidance on delta hedging strategies.

---

## 4. Integration & State Management

In `RiskSectionPage` (`lib/widgets/portfolio/risk_section_page.dart`), the card is connected to the application's global state and stores:

```dart
PortfolioGreeksCard(
  positions: options,
  equityPositions: portfolio.positions,
  futuresStore: futuresStore,
  forexStore: forexStore,
  benchmarkSymbol: controller.selectedBenchmark,
  benchmarkPrice: controller.benchmarkQuote?.lastTradePrice ?? 500.0,
  onBenchmarkChanged: (newBenchmark) {
    controller.selectBenchmark(newBenchmark);
  },
)
```

If the controller or live quote is temporarily loading, safe fallback pricing ensures calculation stability without throwing null exceptions.

---

## 5. Verification & Testing

The engine is validated with unit and widget tests:
*   `test/beta_weighted_greeks_test.dart`:
    *   Validates single equities and inverse ETF negative beta dampening.
    *   Validates option contracts with underlying spot price weighting.
    *   Validates multi-asset portfolios spanning stocks, options, /ES futures, and BTC crypto.
    *   Validates benchmark switching between SPY and QQQ.
    *   Validates zero/unpriced position handling.
*   `test/portfolio_greeks_card_test.dart`:
    *   Validates empty state rendering.
    *   Validates beta-weighted view rendering, hero metrics, Greek tiles, asset chips, and top drivers.
    *   Validates interactive benchmark switching and segmented view switching.
    *   Validates educational guide bottom sheet presentation and scrollability.

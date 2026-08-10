# Gamma Exposure (GEX) Analysis Pro

RealizeAlpha includes a comprehensive options market-microstructure division that tracks **Gamma Exposure (GEX)** to understand market-maker positioning and pricing-gravity dynamics.

---

## 1. Theoretical Foundation & Mathematical Engine
Gamma Exposure tracks the net volume of option gamma held by options dealers (market makers). When standard investors execute trades at brokerage firms, they buy from or sell to market makers. Standard market makers maintain risk-neutral portfolios by dynamically hedging their option exposures with the underlying stock of the asset.

### Standard Normal PDF
Our engine computes standard normal probability densities:
$$N'(x) = \frac{e^{-\frac{1}{2}x^2}}{\sqrt{2\pi}}$$

### Black-Scholes Option Gamma Formula
Option contract-specific gamma is formulated as:
$$\Gamma = \frac{N'(d_1)}{S \sigma \sqrt{T}}$$

Where:
*   $S$ is the current spot price of the underlying asset.
*   $K$ is the strike price of the contract.
*   $T$ is the annualized time to option contract expiration.
*   $r$ is the standard annualized risk-free interest rate ($5\%$).
*   $\sigma$ is the implied volatility of the specific strike option.
*   $d_1 = \frac{\ln(S/K) + (r + \frac{1}{2}\sigma^2)T}{\sigma\sqrt{T}}$

### Dealer GEX Formulation
$$\text{GEX}_{\text{Call}} = \Gamma_{\text{Call}} \times \text{OI}_{\text{Call}} \times 100 \times S^2 \times 0.01$$
$$\text{GEX}_{\text{Put}} = \Gamma_{\text{Put}} \times \text{OI}_{\text{Put}} \times 100 \times S^2 \times 0.01 \times M$$

Where:
*   $\text{OI}$ represents Open Interest totals on the specific strike.
*   $S^2 \times 0.01$ converts per-dollar gamma into dollar exposure for a 1% move in the underlying.
*   $M$ represents dealer direction adjustments (standard retail put purchasing positions dealers short puts/long gamma; standard retail call purchasing positions dealers short calls/short gamma).

---

## 2. Dynamic Client-Side Failover Calculations
To provide extreme architectural resilience against server-side platform rate limits or API outage thresholds, the app hosts a dual-path calculation engine:

1.  **Backend Path (Primary)**: Queries an optimized Node/TypeScript cloud engine (`getGammaExposure`) which hosts rapid centralized databases.
2.  **On-Device Path (Failover)**: Implements standard Black-Scholes option pricing evaluations concurrently inside Dart ([gamma_exposure_widget.dart](../src/robinhood_options_mobile/lib/widgets/gamma_exposure_widget.dart)).
    *   Fetches up to **4 distinct expirations in parallel** asynchronously using the direct Yahoo Finance public options API interface.
    *   Computes and maps GEX locally to bypass cloud network dependencies completely.
    *   Visualizes a custom `Local Calc` chip highlight row on the dashboard summary to notify traders of raw on-device math calculations in real-time.

---

## 3. Visualization Interface Features

### Call Wall & Put Wall gravity:
*   **Call Wall (Upside Ceiling)**: Highlights the options strike level holding the absolute highest net Call GEX. Acts as a prominent resistance ceiling due to heavy market-maker buy-high/sell-low gamma pinning.
*   **Put Wall (Downside Floor)**: Represents the options strike level containing the highest Put GEX. Acts as standard ultimate support due to structural delta hedging and volatility containment.

### Market Maker Pinning Gauge:
*   **Pinning Range Visualization**: Displays current spot price relative to the Put Wall floor and Call Wall ceiling with a dedicated spot marker.
*   **Gamma Flip Context**: Overlays the Gamma Flip threshold on the same visual track when available so users can quickly judge whether spot is near a regime transition.
*   **Intraday Readability**: Compresses the most actionable wall levels into a single glanceable widget for faster interpretation on mobile.

### Spot-Shift GEX Sensitivity Dashboard:
*   **Five-point Stress Test**: Simulates net GEX at `-2%`, `-1%`, `spot`, `+1%`, and `+2%` price shifts.
*   **Sensitivity Curve**: Uses a custom painter to visualize whether dealer positioning becomes more stabilizing or more destabilizing as spot moves.
*   **Regime Tracking**: Helps traders identify if the underlying is close to entering a more pinned or more volatile hedging state.

### Interactive Charts & Grid Highlight:
*   **Tap and Drag Handlers**: The custom horizontal bar chart includes vertical coordinate translation gesture detectors for both tap selection and drag-based strike scrubbing.
*   **Detail Panel overlays**: Renders dynamic metric analysis components mapping specific percent-distances from spot, raw Open Interest counts, and Call vs Put GEX volume contributions.
*   **Spreadsheet grid bindings**: Supports direct highlighted rows inside the GEX table for simplified multi-dimensional indexing.
*   **Weighted Exposure Leaders**: A dynamic ranks leaderboard tracks top active, liquid GEX tickers (e.g. `SPY`, `QQQ`, `TSLA`, `NVDA`) indicating dealer balances.
*   **Top-N Expansion Controls**: The dashboard defaults to a condensed list of leaders and expands on demand to preserve mobile readability.
*   **Instrument Preview Navigation**: The dashboard includes a live instrument preview card and direct navigation into the instrument detail workflow.

### Portfolio GEX Dashboard:
*   **Holdings-Only Analysis**: Collects stock and option symbols from the active portfolio and explicitly excludes the general dashboard's default market symbols.
*   **Aggregate Regime Summary**: Reports portfolio net and gross GEX, dampening versus amplifying breadth, largest-symbol concentration, and mixed-regime offsets.
*   **Top Gamma Drivers**: Ranks holdings by absolute exposure so the positions with the strongest dealer-hedging influence remain visible.
*   **Actionable Position Profiles**: Shows spot, Zero Gamma, Call Wall, Put Wall, the nearest key level and its signed distance, plus Call/Put exposure balance for every holding.
*   **Risk Triage**: Supports sorting by exposure magnitude or nearest key level and filtering to short-gamma positions where hedging may amplify price moves.
*   **Freshness & Recovery**: Aligns stale labels with the four-hour backend cache window and provides pull-to-refresh, retry, loading, and empty states.

### Transition Map & Regime Context:
*   **Closest Levels**: Ranks Gamma Flip, Call/Put Walls, and positive/negative transitions by distance from spot and links matching levels to strike details.
*   **Transition Map**: Surfaces `P Trans`, `N Trans`, Put Mass, and +GEX target values in a responsive two- or four-column layout.
*   **Regime Language**: Describes long gamma as dampening, short gamma as amplifying, and near-zero net-to-gross exposure as balanced without treating gamma sign as directional sentiment.

---

## 4. GEX-Based Trading Strategies & Automated Exits
RealizeAlpha integrates GEX data directly into its **Auto-Trading** engine, allowing for regime-aware execution and risk management.
#### GEX Orchestrator & Agentic Reasoning
The **GEX Orchestrator** acts as a bridge between raw positional data and the AI reasoning engine. It feeds real-time Call/Put wall proximity and Gamma Flip context into the **Agentic Reasoning Mode**, allowing the Alpha Agent to adjust its conviction based on dealer hedging gravity. If a BUY signal is generated near a major Call Wall, the orchestrator may flag it as a "high resistance" entry, prompting the agent to wait for a breakout.
### Automated Technical Exits
Traders can now configure automated sell orders based on dealer gamma thresholds:
*   **GEX Exit Threshold**: Set a specific dollar-weighted threshold (e.g., \$0M) that triggers an automatic position exit. 
*   **Regime Shift Protection**: Automatically close positions when the market transitions from a "Long Gamma" (pinning/stable) state into a "Short Gamma" (accelerating/volatile) state to protect capital from expanding volatility.

### Pre-Built GEX Strategies
The platform includes professional strategy templates optimized for gamma regimes:
1.  **GEX Mean Reversion**: Targets "Pinning" environments. Enters when GEX is strongly positive and price is at Bollinger Band extremes, expecting price to be "magnetized" back toward the highest GEX strike levels.
2.  **GEX Trend Accelerator**: Capitalizes on "Short Gamma" acceleration. Enters when GEX is negative and momentum indicators (MACD, ADX) confirm a breakout, expecting market-maker hedging to amplify the directional move.
3.  **GEX Intraday Scalp**: Optimized for 15-minute charts using GEX magnitude and VWAP to identify high-probability intraday turning points or continuation zones.

### Historical Validation
The **Backtesting Engine** has been upgraded to support GEX exit simulation, enabling users to verify the historical performance of gamma-based regime filtering across multi-year data sets.

---

## 5. Reliability, Validation, and Workflow Notes
*   **Backend + Client Fallback**: The GEX stack continues to prefer Cloud Functions first and gracefully falls back to device-side computation when server-side requests fail or return incomplete data.
*   **Standard Unit**: Backend and on-device engines report dollar gamma exposure for a 1% underlying move using `Gamma × OI × 100 × Spot² × 0.01`.
*   **Validation Coverage**: Dart tests cover serialization, transition levels, freshness, nearest levels, and portfolio breadth. Backend tests cover 1%-move scaling, signal evaluation, and holdings-only symbol resolution.
*   **Mobile-first Layout Tuning**: Leader cards, strike detail panels, and dashboard previews were adjusted to reduce overflow and improve scanning on narrow screens.

---

## 6. File References & Setup
*   **Backend Mathematics**: [gamma-exposure.ts](../src/robinhood_options_mobile/functions/src/gamma-exposure.ts)
*   **Frontend Model Layer**: [gamma_exposure_model.dart](../src/robinhood_options_mobile/lib/model/gamma_exposure_model.dart)
*   **Dynamic Visual UI & On-Device Engine**: [gamma_exposure_widget.dart](../src/robinhood_options_mobile/lib/widgets/gamma_exposure_widget.dart)
*   **Portfolio GEX Dashboard**: [portfolio_gex_dashboard_widget.dart](../src/robinhood_options_mobile/lib/widgets/portfolio_gex_dashboard_widget.dart)
*   **Leaders Board & Search Dashboard**: [gamma_exposure_dashboard_widget.dart](../src/robinhood_options_mobile/lib/widgets/gamma_exposure_dashboard_widget.dart)
*   **Dart Validation Test**: [gamma_exposure_validation_test.dart](../src/robinhood_options_mobile/test/gamma_exposure_validation_test.dart)
*   **Backend Function Test**: [gamma-exposure.test.ts](../src/robinhood_options_mobile/functions/tests/gamma-exposure.test.ts)

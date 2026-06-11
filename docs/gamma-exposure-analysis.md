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
$$\text{GEX}_{\text{Call}} = \Gamma_{\text{Call}} \times \text{OI}_{\text{Call}} \times 100 \times S$$
$$\text{GEX}_{\text{Put}} = \Gamma_{\text{Put}} \times \text{OI}_{\text{Put}} \times 100 \times S \times M$$

Where:
*   $\text{OI}$ represents Open Interest totals on the specific strike.
*   $M$ represents dealer direction adjustments (standard retail put purchasing positions dealers short puts/long gamma; standard retail call purchasing positions dealers short calls/short gamma).

---

## 2. Dynamic Client-Side Failover Calculations
To provide extreme architectural resilience against server-side platform rate limits or API outage thresholds, the app hosts a dual-path calculation engine:

1.  **Backend Path (Primary)**: Queries an optimized Node/TypeScript cloud engine (`getGammaExposure`) which hosts rapid centralized databases.
2.  **On-Device Path (Failover)**: Implements standard Black-Scholes option pricing evaluations concurrently inside Dart ([src/robinhood_options_mobile/lib/widgets/gamma_exposure_widget.dart](src/robinhood_options_mobile/lib/widgets/gamma_exposure_widget.dart)).
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

---

## 4. Reliability, Validation, and Workflow Notes
*   **Backend + Client Fallback**: The GEX stack continues to prefer Cloud Functions first and gracefully falls back to device-side computation when server-side requests fail or return incomplete data.
*   **Validation Coverage**: Serialization/deserialization validation exists for the GEX data model, and backend tests cover the Cloud Function path.
*   **Mobile-first Layout Tuning**: Leader cards, strike detail panels, and dashboard previews were adjusted to reduce overflow and improve scanning on narrow screens.

---

## 5. File References & Setup
*   **Backend Mathematics**: [src/robinhood_options_mobile/functions/src/gamma-exposure.ts](src/robinhood_options_mobile/functions/src/gamma-exposure.ts)
*   **Frontend Model Layer**: [src/robinhood_options_mobile/lib/model/gamma_exposure_model.dart](src/robinhood_options_mobile/lib/model/gamma_exposure_model.dart)
*   **Dynamic Visual UI & On-Device Engine**: [src/robinhood_options_mobile/lib/widgets/gamma_exposure_widget.dart](src/robinhood_options_mobile/lib/widgets/gamma_exposure_widget.dart)
*   **Leaders Board & Search Dashboard**: [src/robinhood_options_mobile/lib/widgets/gamma_exposure_dashboard_widget.dart](src/robinhood_options_mobile/lib/widgets/gamma_exposure_dashboard_widget.dart)
*   **Dart Validation Test**: [src/robinhood_options_mobile/test/gamma_exposure_validation_test.dart](src/robinhood_options_mobile/test/gamma_exposure_validation_test.dart)
*   **Backend Function Test**: [src/robinhood_options_mobile/functions/tests/gamma-exposure.test.ts](src/robinhood_options_mobile/functions/tests/gamma-exposure.test.ts)

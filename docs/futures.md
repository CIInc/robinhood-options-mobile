# Futures Positions

RealizeAlpha now enriches futures positions with contract & product metadata, real-time quotes, and settlement prices, exposing both Open P&L and Day P&L calculations per contract.

## Overview
Futures data is aggregated client-side from brokerage APIs, then augmented with metadata (contract + product), live quotes, and previous close prices before being displayed. The implementation provides transparent Open P&L and Day P&L; realized P&L, margin analytics, and roll logic are planned.

## Data Sources
- **Aggregated Positions:** Base quantity and average trade price.
- **Contract Metadata (arsenal):** Root symbol, expiration, currency, multiplier.
- **Product Metadata (arsenal):** Product-level details (e.g., category/class if available).
- **Quotes (marketdata futures):** Last trade price (used for Open P&L and Day P&L).
- **Closes (marketdata futures):** Previous close price (used for Day P&L calculation).

## Enrichment Fields (per position)
| Field | Description |
|-------|-------------|
| `symbol` | Full futures symbol (e.g., ESZ25). |
| `rootSymbol` | Root (e.g., ES). |
| `expiration` | Contract expiration date. |
| `currency` | Pricing currency. |
| `multiplier` | Contract price multiplier (e.g., 50 for ES). |
| `avgTradePrice` | Average execution price of current open position. |
| `lastTradePrice` | Latest trade price from quote feed. |
| `previousClosePrice` | Previous close (settlement) price from closes endpoint. |
| `quantity` | Number of contracts held (signed). |
| `openPnlCalc` | Computed Open P&L value (see formula). |
| `dayPnlCalc` | Computed Day P&L value (see formula). |

## P&L Formulas

### Open P&L
The Open P&L is derived directly from the last trade price vs the average trade price, scaled by contract quantity and multiplier.

$Open\ P\&L = (Last\ Price - Avg\ Price) \times Quantity \times Multiplier$

Example:
```
AvgTradePrice = 4520.00
LastTradePrice = 4527.25
Quantity = 3
Multiplier = 50
OpenPnlCalc = (4527.25 - 4520.00) * 3 * 50 = 1087.50
## UI Integration
- Both Day P&L and Open P&L are displayed in the Futures Positions widget with color-coded values (green for positive, red for negative, grey for zero).
- Day P&L is shown above Open P&L for each position.
- Precision: last trade price shown with 2–4 decimals depending on instrument.
- Contract & product metadata shown as supplemental descriptive text.lose price, scaled by contract quantity and multiplier.

$Day\ P\&L = (Last\ Price - Previous\ Close\ Price) \times Quantity \times Multiplier$

Example:
```
PreviousClosePrice = 4518.50
LastTradePrice = 4527.25
Quantity = 3
Multiplier = 50
DayPnlCalc = (4527.25 - 4518.50) * 3 * 50 = 1312.50
```

## UI Integration
- Displayed in the Futures Positions widget with color-coded value (positive/negative).
- Precision: last trade price shown with 2–4 decimals depending on instrument.
- Contract & product metadata shown as supplemental descriptive text.
## Technical Implementation
- Service layer method (`streamFuturePositions`) fetches aggregated positions, then sequentially:
  1. Fetches contract & product metadata via `getFuturesContractsByIds` and `getFuturesProductsByIds`.
  2. Fetches quotes for all distinct symbols via quotes endpoint.
  3. Fetches previous close prices via `getFuturesClosesByIds`.
  4. Computes `openPnlCalc` and `dayPnlCalc` per position.
- Enriched positions exposed as a stream for reactive UI updates.
- No secrets: all sensitive logic (if any future brokerage write operations are needed) should move to Firebase Functions.
## Limitations
- No realized P&L yet (requires trade history processing).
- Margin impact / maintenance requirement not shown.
- No contract roll detection or calendar spread awareness.
- No Greeks or implied volatility surface metrics.
- Assumes multiplier is available and non-null; positions without multiplier may show `openPnlCalc = null` and `dayPnlCalc = null`.
- Day P&L calculation depends on availability of previous close price; if unavailable, `dayPnlCalc` will be null.
- No Greeks or implied volatility surface metrics.
## Roadmap
Planned enhancements:
- Margin metrics & risk layer (SPAN-style summary).
- Realized P&L tracking using trade history.
- Contract roll assistant (alerts near expiration, auto-suggest roll strikes/months).
- Greeks and term structure analytics for rate-sensitive products.
- Volatility overlays and seasonal tendencies.
- Aggregated portfolio risk (VaR / expected shortfall) including futures.
- Volatility overlays and seasonal tendencies.
- Aggregated portfolio risk (VaR / expected shortfall) including futures.

## Developer Notes
- Keep enrichment client-side unless broker rate limits require caching; move heavy logic to `functions/` if needed.
- Avoid persisting enriched documents until a server reconciliation workflow is defined.
- Extend tests when adding calculation complexity (e.g., margin formulas).

## Safety Checklist
Before extending futures logic:
1. No API keys or secrets in Dart; use Firebase Functions for secure calls.
2. Add unit tests for new calculations (especially margin, realized P&L).
3. Maintain consistent naming (snake_case files, UpperCamelCase classes).
## Summary
Futures support now delivers enriched contract context with transparent Open P&L and Day P&L calculations, providing comprehensive position tracking and forming the foundation for advanced risk and analytics to come.
## Summary
Initial futures support delivers enriched contract context and transparent Open P&L, forming the foundation for advanced risk and analytics to come.

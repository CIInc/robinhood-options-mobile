# Portfolio Return Attribution

The Performance section's Return Attribution card explains part of today's
portfolio performance relative to the selected benchmark. It is an on-device
estimate, not a broker-reported historical attribution statement.

## Sectors

The Sectors view decomposes the equity-and-cash sleeve with a Brinson-Fachler
calculation. It reports portfolio and benchmark returns, active return, and
allocation, selection, and interaction effects by sector. The three effects sum
to active return, subject to floating-point rounding.

Sector returns use same-day quotes for these SPDR Select Sector ETF proxies:

| Sector | Proxy |
| --- | --- |
| Communication Services | XLC |
| Consumer Discretionary | XLY |
| Consumer Staples | XLP |
| Energy | XLE |
| Financials | XLF |
| Health Care | XLV |
| Industrials | XLI |
| Information Technology | XLK |
| Materials | XLB |
| Real Estate | XLRE |
| Utilities | XLU |

Benchmark sector weights are approximations for SPY, QQQ, DIA, and IWM. Other
benchmarks use SPY weights and are identified as using proxy weights. If sector
quotes are unavailable, the card offers a retry; equity positions without
usable previous-close and current prices are omitted instead of estimated.
Options are shown separately in Greeks & Income.

## Greeks & Income

Option P&L is estimated with a second-order Taylor approximation from current
Greeks and today's underlying-price change: `delta * dS + 0.5 * gamma * dS^2 +
theta * dt`, scaled by signed contracts and contract multiplier.

Vega P&L is inferred from the remaining observed mark-to-market change when a
vega value is available. If not, the unexplained amount is reported as residual
P&L. Prior implied-volatility snapshots are not stored, so these Greek figures
are estimates, not broker-reported values.

Income includes three disaggregated components dated within the current day's
window (excluding pending, voided, cancelled, failed, and reversed entries):

- **Dividends:** Paid cash dividends dated within the current day's window.
- **Cash Sweeps & Interest:** Paid interest/sweep entries dated within the window,
  or an estimated daily sweep accrual (`estimatedAnnualInterest / 365`) when
  enrolled in Cash Sweeps (`SweepsInterest`) and no interest payout landed today.
- **SLIP Securities Lending:** Paid/settled SLIP stock loan payouts
  (`StockLoanPayment`) dated within the window, or an estimated daily lending
  accrual (`totalLoanedValue * estimatedAnnualizedYield / 365`) when enrolled in
  SLIP (`SlipEligibility`) and no SLIP payout landed today.

These cash-sweep and SLIP daily accruals are on-device estimates when daily
broker statements have not yet settled and are labeled clearly in the UI and CSV
export ([#278](https://github.com/CIInc/robinhood-options-mobile/issues/278)).

## Privacy and Export

Dollar amounts respect the account balance-visibility setting; percentages
remain visible. The Performance section's CSV export includes sector effects,
option Greek P&L, disaggregated income rows (`Dividends P&L`, `Cash Sweeps &
Interest P&L`, `SLIP Securities Lending P&L`, and `Income/Yield P&L`), and the
estimate disclaimer when those attribution results are available. Calculations
use hydrated account data on-device and are not written to Firestore.

Implementation references: `lib/model/return_attribution.dart`,
`lib/services/return_attribution_service.dart`, and
`lib/widgets/portfolio/analytics/return_attribution_card.dart`.
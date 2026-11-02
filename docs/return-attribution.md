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

Income currently includes paid dividends and interest entries dated within the
current day's window; pending and voided entries are excluded. Separate stock
lending and cash-sweep attribution is not currently calculated. Issue
[#278](https://github.com/CIInc/robinhood-options-mobile/issues/278) remains open
for completing and verifying the full attribution scope.

## Privacy and Export

Dollar amounts respect the account balance-visibility setting; percentages
remain visible. The Performance section's CSV export includes sector effects,
option Greek P&L, and the estimate disclaimer when those attribution results are
available. Calculations use hydrated account data on-device and are not written
to Firestore.

Implementation references: `lib/model/return_attribution.dart`,
`lib/services/return_attribution_service.dart`, and
`lib/widgets/portfolio/analytics/return_attribution_card.dart`.
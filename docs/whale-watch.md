# Whale Watch

Whale Watch combines reported insider transactions with institutional ownership snapshots to highlight unusually large activity without presenting current holdings as measured accumulation.

## User Experience

The dashboard is available from Search and displays:

- Aggregate insider buy and sell totals.
- An Insider Sentiment Index derived from reported transactions.
- Recent large insider transactions.
- A ranked institutional section labeled either **Top Institutional Accumulation** or **Top Institutional Holdings**.

The label is part of the data contract. It tells the user whether the backend measured a positive change from a previous snapshot or is showing current holdings as a fallback.

## Institutional Ranking

Yahoo's ownership response contains current positions, not a reliable `positionChange` value. The backend therefore aggregates `sharesHeld` by symbol and compares the result with the previous stored snapshot.

For each symbol present in both snapshots:

```text
accumulation = current aggregate shares - previous aggregate shares
```

Only positive changes participate in accumulation ranking. If there is no prior snapshot or no symbol has a positive change, the backend ranks current aggregate holdings and sets `institutionalRankingMode` to `holdings`.

| Mode | Dashboard label | Score meaning |
| --- | --- | --- |
| `accumulation` | Top Institutional Accumulation | Positive share change since the previous snapshot |
| `holdings` | Top Institutional Holdings | Current aggregate reported shares |

The dashboard shows an explicit unavailable state when no institutional ownership data can be ranked.

## Backend Architecture

- Scheduler: `functions/src/whale-watch-cron.ts`
- Ranking helper: `functions/src/whale-watch-utils.ts`
- Shared models: `functions/src/whale-watch-models.ts`
- Authenticated Yahoo transport: `functions/src/yahoo-proxy.ts`
- Flutter model: `lib/model/whale_watch.dart`
- Dashboard: `lib/widgets/whale_watch_dashboard_widget.dart`

The scheduler uses the authenticated Yahoo proxy for quote-summary modules. An authorization response (`401` or `403`) is retried once so the proxy can renew its Yahoo cookie/crumb session.

## Firestore Data

The daily aggregate and holdings baseline are committed together in a Firestore batch:

- `market_intelligence/whale_watch_aggregate`
- `market_intelligence/whale_watch_institutional_holdings`

The aggregate document includes:

- `totalBuyValue`, `totalSellValue`, `buyCount`, and `sellCount`
- `topAccumulatedSymbols`
- `institutionalRankingMode`
- `recentLargeTransactions`
- Server timestamp

The holdings document stores aggregate shares by symbol for the next comparison. Do not infer accumulation directly from the current ownership payload or silently label a holdings fallback as accumulation.

## Testing

Run the focused backend test from `src/robinhood_options_mobile/functions`:

```sh
npm test -- --runInBand tests/whale-watch-utils.test.ts
```

Coverage includes positive snapshot deltas, first-snapshot holdings fallback, and fallback when no institution increased its position.
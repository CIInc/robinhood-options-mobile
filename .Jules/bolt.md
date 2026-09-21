## 2025-05-18 - Multi-Symbol Equity Curve Aggregation
**Learning:** In backtesting routines with multi-symbol combined time-series data, nested array linear searching (`.find()` and reverse searching `[...array].reverse().find()`) over timestamps turns equity aggregation into an O(N^2 * M) bottleneck with significant memory copying overhead.
**Action:** Extract equity time series into lookup Maps per symbol and track running equity values during forward chronological traversal, reducing time complexity to O(N * M).

## 2025-05-18 - Crossover & Trend Detection in Time-Series Indicators
**Learning:** Calling full indicator evaluation functions on `prices.slice(0, -1)` to obtain the previous bar's value for crossover/trend detection causes O(N) redundant EMA/Wilder's calculations and large array cloning on every evaluation pass. Since forward-iterative series already compute intermediate states for index N-2, exposing `prevHistogram` / `prevAdx` directly from the base calculation eliminates O(N) re-evaluation.
**Action:** Always capture and return previous bar state (`prevVal`) during forward time-series passes instead of re-running indicator functions on sliced `(0, -1)` inputs.

## 2025-05-18 - Multi-Symbol Equity Curve Aggregation
**Learning:** In backtesting routines with multi-symbol combined time-series data, nested array linear searching (`.find()` and reverse searching `[...array].reverse().find()`) over timestamps turns equity aggregation into an O(N^2 * M) bottleneck with significant memory copying overhead.
**Action:** Extract equity time series into lookup Maps per symbol and track running equity values during forward chronological traversal, reducing time complexity to O(N * M).

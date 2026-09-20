## 2025-05-18 - Multi-Symbol Equity Curve Aggregation
**Learning:** In backtesting routines with multi-symbol combined time-series data, nested array linear searching (`.find()` and reverse searching `[...array].reverse().find()`) over timestamps turns equity aggregation into an O(N^2 * M) bottleneck with significant memory copying overhead.
**Action:** Extract equity time series into lookup Maps per symbol and track running equity values during forward chronological traversal, reducing time complexity to O(N * M).

## 2026-03-29 - Redundant Indicator Recalculations and Subarray Allocations
**Learning:** Re-computing indicator functions over sliced arrays (`prices.slice(0, -1)`) to obtain previous step values (e.g., in MACD, ADX, Williams %R) doubles execution time in multi-indicator pipelines like `evaluateAllIndicators`. Additionally, sub-range array allocations (`.slice().map().reduce()` / `Math.min(...slice)`) within indicator loops create significant GC pressure.
**Action:** Return trailing/previous step values (`prevHistogram`, `prevAdx`) directly from indicator calculation functions in the primary pass, and replace sub-range array slicing with index-based loop helpers (`rangeMin`/`rangeMax`).

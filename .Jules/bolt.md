## 2025-05-18 - Multi-Symbol Equity Curve Aggregation
**Learning:** In backtesting routines with multi-symbol combined time-series data, nested array linear searching (`.find()` and reverse searching `[...array].reverse().find()`) over timestamps turns equity aggregation into an O(N^2 * M) bottleneck with significant memory copying overhead.
**Action:** Extract equity time series into lookup Maps per symbol and track running equity values during forward chronological traversal, reducing time complexity to O(N * M).

## 2026-03-29 - Redundant Indicator Recalculations and Subarray Allocations
**Learning:** Re-computing indicator functions over sliced arrays (`prices.slice(0, -1)`) to obtain previous step values (e.g., in MACD, ADX, Williams %R) doubles execution time in multi-indicator pipelines like `evaluateAllIndicators`. Additionally, sub-range array allocations (`.slice().map().reduce()` / `Math.min(...slice)`) within indicator loops create significant GC pressure.
**Action:** Return trailing/previous step values (`prevHistogram`, `prevAdx`) directly from indicator calculation functions in the primary pass, and replace sub-range array slicing with index-based loop helpers (`rangeMin`/`rangeMax`).

## 2026-03-30 - Eliminating Array Slicing in Custom Indicator Crossover Evaluation
**Learning:** Evaluating custom indicator crossover conditions (`CrossOverAbove`/`CrossOverBelow`) was slicing `prices`, `highs`, `lows`, and `volumes` arrays on every step (`.slice(0, -1)`), generating significant memory churn and GC pressure in backtesting and multi-indicator pipelines.
**Action:** Propagate an optional `endIndex` parameter to indicator computation functions (`computeSMA`, `computeEMA`, `computeRSI`, `computeMACD`, `computeBollingerBands`, `computeStochastic`, `computeATR`, `computeOBV`, `computeVWAP`, `computeADX`, `computeCCI`, `computeROC`) so previous candle values can be evaluated by index without array allocations.

## 2026-03-31 - O(1) Indicator Set Lookup and Single-Pass Signal Aggregation in evaluateAllIndicators
**Learning:** In backtesting loops, calling `evaluateAllIndicators` on every bar executed `config.enabledIndicators.includes(key)` linear array scans over 60+ times per bar and allocated 5 temporary intermediate arrays (`standardVals`, `customVals`, `allVals`, `.filter()`) for signal summary stats (`buyCount`, `sellCount`, `allGreen`, `allRed`). Over 50,000 backtest bars, this generated millions of linear search operations and heavy GC pressure.
**Action:** Pre-build a `Set<string>` once per `evaluateAllIndicators` call for O(1) `isEnabled` lookups, and aggregate counts/scores in a single loop pass without intermediate array allocations.

## 2026-03-31 - Sliding Window & Flow Pre-computation for Local Alpha Factor Indicators
**Learning:** In factor discovery and backtesting pipelines, local indicator array computations like CCI and MFI were re-allocating array slices per bar (`tp.slice()`) and running nested O(N * period) money flow comparisons. For 2,500 historical price bars, this created thousands of array allocations and tens of thousands of redundant loop passes.
**Action:** Use sliding window sums for SMA and pre-calculate per-bar money flow arrays (`posFlows`/`negFlows`), reducing time complexity to O(N) and eliminating temporary array slice allocations.

## 2026-04-01 - Scalar Technical Indicator Evaluation without Full-Series Array Allocations
**Learning:** Scalar indicator computation functions (`computeRSI`, `computeATR`, `computeADX`) delegated to full-series array generators (`computeRSIArray`, `computeATRArray`) or created up to 9 intermediate arrays (`plusDM`, `minusDM`, `tr`, `smoothedPlusDM`, `smoothedMinusDM`, `smoothedTR`, `plusDI`, `minusDI`, `dx`, `changes`, `trueRanges`). In backtests and multi-indicator evaluations across thousands of bars, this caused millions of transient heap allocations and heavy GC pauses.
**Action:** Refactor scalar indicator functions (`computeRSI`, `computeATR`, `computeADX`) to calculate smoothed Wilder averages directly using running scalar variables in O(1) space, and compute series differences on-the-fly without allocating intermediate arrays.

## 2026-04-01 - Scalar Stochastic and Keltner Channels directly in O(1) Space
**Learning:** Scalar indicator functions `computeStochastic` and `computeKeltnerChannels` delegated to full-series array generators (`computeStochasticArray`, `computeKeltnerChannelsArray`). In custom indicator evaluations and backtests over 500+ bars, this created dynamic arrays of hundreds of elements and intermediate objects on every evaluation step only to return a single trailing value.
**Action:** Refactor `computeStochastic` to compute trailing %K/%D directly in O(dPeriod * kPeriod) time and O(1) space, and refactor `computeKeltnerChannels` to directly use scalar `computeEMA` and `computeATR` helpers.

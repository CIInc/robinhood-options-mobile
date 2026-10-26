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

## 2026-04-01 - O(1) Space Scalar Evaluation for ATR and Typical Price On-The-Fly CCI
**Learning:** `evaluateATR` delegated to `computeATRArray` and accumulated full-series array allocations (`fullATRSeries`, `trueRanges`, `atrValues`), adding 19.7 µs/op per bar. Similarly, `evaluateCCI` and `evaluateCustomIndicator` allocated temporary `typicalPrices` arrays on every call.
**Action:** Refactor `evaluateATR` to track running ATR sums and counts directly in scalar variables (reducing runtime by ~73%), and accept direct HLC arrays in `computeCCI` to calculate typical prices on-the-fly without intermediate array allocations.

## 2026-04-01 - Scalar Bollinger Bands Evaluation without Full-Series Array Allocations
**Learning:** `evaluateBollingerBands` allocated full-series arrays (`computeBollingerBandsArray` and `computeKeltnerChannelsArray`) on every single evaluation call in `evaluateAllIndicators`. In backtesting loops and automated trading cycles over 500+ bars, this generated thousands of transient array objects for every candle evaluated, taking ~65.2 µs/op.
**Action:** Replace `computeBollingerBandsArray` and `computeKeltnerChannelsArray` in `evaluateBollingerBands` with scalar helpers `computeBollingerBands` and `computeKeltnerChannels`, evaluating trailing bandwidth squeeze using index-bounded scalar calls. This speeds up `evaluateBollingerBands` by ~8.6x (from 65.2 µs/op down to 7.6 µs/op) and eliminates full-series array allocations per bar.

## 2026-04-02 - Propagating Index Boundaries to Indicator Evaluators Eliminates Backtest Slicing
**Learning:** In backtesting simulation loops (`runBacktestSimulation`), slicing 7 price/volume/market arrays on every bar step (`opens.slice(...)`, `highs.slice(...)`, `closes.slice(...)`, `volumes.slice(...)`, `marketData.closes.slice(...)`, etc.) generated 35,000+ transient array allocations per 5,000-bar backtest.
**Action:** Propagate optional `endIndex` and `marketEndIndex` parameters through `evaluateAllIndicators` and all 20 individual indicator evaluation functions, passing full dataset references and index boundaries to evaluate indicators in-place without array allocations per bar.

## 2026-04-02 - Zero-Allocation Timestamp Comparison and Sorting in Backtesting
**Learning:** In `runBacktestSimulation` and `aggregateEquityCurves`, evaluating `new Date(t * 1000) >= startDate` in `.findIndex()` and `new Date(a).getTime() - new Date(b).getTime()` in `.sort()` allocated thousands of transient `Date` objects and forced ISO 8601 string parsing overhead during backtests.
**Action:** Compare millisecond unix timestamps directly (`t * 1000 >= startMs`) in search predicates, and leverage lexicographical string sorting (`a < b ? -1 : a > b ? 1 : 0`) for ISO 8601 timestamps to avoid object instantiation.

## 2026-04-03 - Scalar Stochastic Oscillator Evaluation without Full-Series Array Allocations
**Learning:** `evaluateStochastic` called `computeStochasticArray` and performed array slicing (`stochArray.slice(-20)`, `closes.slice(...)`) on every bar evaluation. In multi-indicator backtest loops and real-time scanning across 500+ bars, this generated hundreds of thousands of transient arrays and object wrappers, running in ~45.0 µs/op.
**Action:** Refactor `evaluateStochastic` to evaluate scalar `computeStochastic` directly over the trailing lookback window without full-series array allocations or array slicing. This speeds up `evaluateStochastic` by ~15x (from 45.0 µs/op down to 3.0 µs/op) and eliminates GC memory overhead.

## 2026-04-03 - O(1) Space Scalar MACD Evaluation without Full-Series Array Allocations
**Learning:** `computeMACD` previously allocated 4 full-series intermediate arrays (`fastEMAs`, `slowEMAs`, `macdSeries`, `signalLineSeries`) per bar evaluation. In backtesting loops and automated trading scans over hundreds of bars, this caused millions of transient array allocations and ran in ~24.5 µs/op.
**Action:** Refactor `computeMACD` to calculate fast, slow, and signal line EMAs directly using running scalar variables in O(1) space. This speeds up MACD computation by ~8.5x (from 24.5 µs/op down to 2.97 µs/op) and eliminates 100% of transient array allocations per evaluation.

## 2026-04-03 - Zero-Allocation Pattern Scan & RSI Momentum Evaluation
**Learning:** `detectChartPattern` and `evaluateMomentum` were creating 6+ transient sub-arrays (`windowPrices`, `recentPrices`, `set`, `pole`, `flag`, `volumes.slice(-30)`, `rsiSeries.slice(startIdx)`) per bar evaluation. In multi-indicator backtests over thousands of bars, this generated millions of temporary array objects and triggered frequent GC pauses.
**Action:** Access dataset arrays directly using window index offset helpers (`px(i) = prices[start + i]`, `getRSI(k) = rsiSeries[startIdx + k]`) and index loop bounds (`rangeMin`/`rangeMax`/Flag loops) to evaluate chart patterns and RSI momentum with zero transient array allocations.

## 2026-04-03 - Scalar Raw %K Evaluation Eliminates Redundant Stochastic Re-Evaluations
**Learning:** `evaluateStochastic` called `computeStochastic` 22 times per evaluation bar (2 calls for current/previous bar and 20 calls inside the divergence detection loop). Because `computeStochastic` recomputed %K and %D over trailing `dPeriod` lookbacks, the 20-bar divergence scan ran 840 inner loop passes and generated 20 transient result objects per bar evaluation—even though divergence scanning only inspects raw %K values.
**Action:** Extract a lightweight `computeRawK` helper that evaluates raw %K for a single bar index in O(kPeriod) time, and refactor `evaluateStochastic` to evaluate trailing `stoch`, `prevStoch`, and divergence trend directly via `computeRawK`. This eliminates 22 redundant `computeStochastic` calls and reduces `evaluateStochastic` execution time by ~55% (~2.25x speedup).

## 2026-04-03 - Zero-Allocation Indexed Pearson Correlation in Alpha Factor Discovery
**Learning:** In factor discovery routines (`discoverAlphaFactors`), computing factor IC correlations allocated 3 transient arrays (`filteredValues`, `filteredReturns`, and `filteredValues.filter()`) per factor per symbol evaluation. In a universe of 50 symbols and 14 factors, this caused thousands of transient array allocations and multiple redundant passes over price data.
**Action:** Refactor `calculateCorrelation` to accept an optional `indices` array parameter and return both correlation and valid pair count in a single pass directly over index boundaries, eliminating 100% of intermediate array allocations per factor evaluation.

## 2026-04-03 - Scalar On-Balance Volume (OBV) Evaluation in O(1) Space
**Learning:** `evaluateOBV` and `evaluateCustomIndicator` for "OBV" called `computeOBV`, which instantiated full-series cumulative OBV arrays (`const obv: number[] = [0]`) on every evaluation bar. In multi-indicator backtests and market scans over 500+ bars, this created hundreds of thousands of transient array objects for every candle evaluated.
**Action:** Implement `computeScalarOBV` to compute trailing OBV in $O(1)$ space, and refactor `evaluateOBV` to evaluate lookback averages and min/max extremes over the trailing 20-bar window directly using running scalar accumulators.

## 2026-04-03 - Direct Scalar Net GEX and Loop-Based Open Interest Evaluation
**Learning:** `computeTotalNetGexAtSpot` in `gamma-exposure.ts` delegated to `computeGEXByStrike` 4 times per evaluation bar for spot price sensitivity checks (-2%, -1%, +1%, +2%), instantiating 40+ transient Map objects, allocating hundreds of `GexStrikeLevel` objects, and performing 40 array sorts per call. Similarly, `hasUsableOptionsOpenInterest` allocated intermediate arrays via `.flatMap().reduce()`.
**Action:** Refactor `computeTotalNetGexAtSpot` to compute scalar net GEX directly over call and put options in O(N) time and O(1) space, and replace `.flatMap().reduce()` in `hasUsableOptionsOpenInterest` with direct index loops.

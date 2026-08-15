# Event Study Analyzer

The Event Study Analyzer measures how an instrument performed around a known event and compares its return with a benchmark. Use it for earnings, FDA decisions, product launches, guidance changes, or another dated event.

## Using The Analyzer

Open Event Study Analyzer from the instrument or research workflow, then provide:

- **Stock:** The instrument to analyze.
- **Benchmark:** The comparison symbol, defaulting to `SPY`.
- **Event type:** Earnings, FDA decision, Product launch, Guidance, or Other.
- **Event date:** The date when the market learned about the event. Weekend and holiday dates are mapped to the nearest trading session.
- **Days before / days after:** The event window, from 1 to 120 trading days on each side.
- **Rolling statistics window:** The number of daily returns used for rolling risk statistics, from 5 to 120 days.

Presets are available for 5/5, 10/10, and 20/20 trading-day event windows.

## Results

The analysis returns a dated series around the event containing:

- Asset return from the start of the event window.
- Benchmark return over the same window.
- Abnormal return, calculated as asset return minus benchmark return.
- Event-day asset, benchmark, and abnormal returns.
- Cumulative asset and abnormal returns through the end of the post-event window.
- The actual trading session used for the requested event date.
- Rolling annualized volatility, beta, correlation, and sample size.

A positive cumulative abnormal return means the instrument outperformed the selected benchmark over the displayed event window. This is descriptive analysis, not a prediction or a trading recommendation.

## Technical Details

The backend callable is `analyzeEventStudy` in `functions/src/event-study.ts`. It loads daily historical data for the instrument and benchmark, aligns their trading sessions, and calculates the event and rolling statistics server-side. The callable requires Firebase Authentication and the `TWELVE_DATA_API_KEY` secret through the existing market-data service.

The rolling metrics use aligned daily returns:

- **Volatility:** Annualized standard deviation of the instrument's returns using 252 trading days.
- **Beta:** Covariance of instrument and benchmark returns divided by benchmark variance.
- **Correlation:** Pearson correlation of instrument and benchmark returns.

The event date is normalized to the nearest available trading session. Invalid symbols, dates, or window values are rejected before analysis.

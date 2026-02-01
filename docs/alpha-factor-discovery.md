# Alpha Factor Discovery

## Overview

The Alpha Factor Discovery engine is a research tool designed to identify and validate predictive trading signals (alpha factors). It allows quantitative traders to systematically test hypotheses about what drives market movements by analyzing the correlation between technical indicators and future price returns.

## Core Concepts

### Information Coefficient (IC)
The primary metric used to evaluate an alpha factor. It represents the correlation (Pearson) between the factor's value today and the asset's return in the future.
*   **Positive IC (> 0.05):** The factor positively predicts returns (e.g., higher value -> higher price).
*   **Negative IC (< -0.05):** The factor predicts lower returns (e.g., higher value -> lower price).
*   **Near Zero:** The factor has no predictive power.

### ICIR (Information Ratio)
We calculate the **ICIR** (Information Coefficient Information Ratio) to measure the stability of the signal. It is calculated as `Mean IC / StdDev IC`. High stability means the factor works consistently across different assets or timeframes.

## Supported Factors

The engine supports testing numerous technical indicators as potential alpha factors:

*   **RSI (Relative Strength Index):** Mean reversion or momentum.
*   **SMA Distance:** Price relative to Moving Average (Extension).
*   **MACD Signal:** Momentum trends.
*   **Bollinger Band Width:** Volatility compression/expansion.
*   **Momentum:** Rate of change over time.
*   **Stochastic K:** Overbought/Oversold levels.
*   **ATR (Average True Range):** Volatility measure.
*   **ADX (Average Directional Index):** Trend strength.
*   **CCI (Commodity Channel Index):** Cyclical trends.
*   **OBV (On-Balance Volume):** Volume flow.
*   **Keltner Position:** Price relative to Keltner Channels.
*   **Williams %R:** Momentum indicator.
*   **ROC (Rate of Change):** Velocity of price changes.
*   **MFI (Money Flow Index):** Volume-weighted RSI.

## How to Use

1.  **Define Universe:** Enter a list of stock symbols (comma-separated) or select a predefined list (e.g., SPY Top 10, Mag 7).
2.  **Select Factor:** Choose a factor type (e.g., RSI) and configure its parameters (e.g., Period: 14).
3.  **Forward Period:** Choose the look-ahead period for returns (e.g., 1 day, 5 days).
4.  **Run Discovery:** The system fetches historical data, computes the factor and future returns, and calculates the IC for each asset and the universe aggregate.

### Interpreting Results

*   **Global IC:** The average predictive power across your universe.
*   **Symbol Breakdown:** See which specific assets react best to this factor.
*   **Correlation Heatmap:** Visualize the relationship.

## Use Cases

*   **Strategy Optimization:** Find the best lookback period for an RSI strategy on Tech stocks.
*   **New Signal Generation:** Discover that "Low Volatility (Low BB Width)" predicts breakouts in specific sectors.
*   **Regime Detection:** Validate if Momentum or Mean Reversion is currently working better.

# Correlation Analysis

The Correlation Analysis feature provides a visualization of the correlation matrix for the assets in your portfolio. This tool helps investors understand the diversification of their holdings and identify concentration risks.

## Overview

A correlation matrix displays the correlation coefficients between pairs of assets. The coefficient ranges from:
- **+1.0**: Perfect positive correlation (assets move in the same direction).
- **0.0**: No correlation (assets move independently).
- **-1.0**: Perfect negative correlation (assets move in opposite directions).

## Features

- **Correlation Matrix Heatmap**: Visual grid showing correlation between your top 15 holdings.
- **Interactive Details**: Tap on any cell to see the precise correlation value, proper descriptive interpretation (e.g., "Strong positive correlation"), and the "Overlapping Days" count to judge data quality.
- **Legend & Education**: Built-in legend explaining the color scale and an information dialog explaining how to interpret correlation coefficients.
- **Color Coding**:
  - **Red**: High positive correlation (Low diversification benefit).
  - **Blue**: High negative correlation (Hedging benefit).
  - **Grey/White**: Low correlation (Diversification benefit).
- **Automated Calculation**: uses 1-year historical daily returns to compute robust correlation statistics.
- **Progress Tracking**: Real-time loading status showing the number of symbols processed.

## How to use

1. Go to the **Portfolio Analytics** section.
2. Scroll to the **Risk Metrics** card.
3. Tap on **View Correlation Matrix**.
4. The matrix will load, fetching historical data for your positions.

## Implementation Details

- **Backend/Service**: Uses `RobinhoodService` (or other brokerage services) to fetch `InstrumentHistoricals`.
- **Math**: Calculates Pearson correlation coefficient on daily returns of aligned trading days.
- **Privacy**: All calculations are performed on-device or via secure proxy; no portfolio data is stored externally for this analysis.

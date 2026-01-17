# AI Price Targets

## Overview

RealizeAlpha utilizes Generative AI to provide data-driven price target analysis for any tradable instrument. By synthesizing technical indicators, historical volatility, and market conditions, the system generates projected price levels with confidence assessments.

## Features

### AI-Driven Analysis
The system analyzes key factors to determine potential price directives:
- **Technical patterns:** Support/Resistance levels, moving averages, and chart formations.
- **Volatility bounds:** ATR and Bollinger Band based projections.
- **Market context:** Correlation with broader market indices.

### Visual Price Targets
- **Target Price:** A projected price level for a specific timeframe.
- **Direction:** Bullish, Bearish, or Neutral bias.
- **Confidence Score:** AI-determined confidence in the projection based on signal alignment.
- **Reasoning:** A summary of the factors driving the specific target.

## Usage

Access Price Targets within the **Instrument Detail** view:
1.  Navigate to a stock or ETF detail page.
2.  Locate the **AI Insights** or **Analysis** section.
3.  View the generated **Price Target Card** to see the projection and underlying rationale.

*Note: Price targets are generated using the `analyzePriceTargets` cloud function and `gemini-2.5-flash-lite` model for rapid inference.*

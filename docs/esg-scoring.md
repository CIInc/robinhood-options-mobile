# ESG Scoring

RealizeAlpha now includes comprehensive Environmental, Social, and Governance (ESG) scoring to help you make values-aligned investment decisions.

## Overview

The ESG Scoring feature provides a quantitative assessment of a company's performance in three key areas:
- **Environmental:** Impact on the planet (carbon emissions, resource usage, etc.).
- **Social:** Impact on people (labor standards, community relations, etc.).
- **Governance:** Corporate leadership standards (board diversity, executive pay, ethics).

Our system aggregates data from trusted sources (powered by Yahoo Finance) to provide both individual instrument scores and a portfolio-wide weighted average.

## Key Features

### 1. Portfolio-Level Analysis
- **Weighted Average Score:** Your portfolio's overall ESG score is calculated based on the weight of each holding.
- **Visual Dashboard:** View your portfolio's ESG performance in the [Portfolio Analytics](portfolio-analytics.md) dashboard.
- **Breakdown:** See the contribution of Environmental, Social, and Governance factors to your overall score.

### 2. Instrument Detail View
- **Integrated Card:** Every stock detail page now features an ESG card located below the Fundamentals section.
- **Detailed Metrics:**
    - **Total Score:** A 0-100 score (higher is better).
    - **Risk Rating:** The underlying risk category (e.g., Low, Medium, High).
    - **Component Scores:** Individual bars for Environmental, Social, and Governance performance.
    - **Controversies:** Highlights any significant controversies related to the company.

### 3. Scoring Methodology
- **Risk to Score Conversion:** We convert standard ESG Risk Ratings (where lower is better) into a "Goodness Score" (0-100, where higher is better) for intuitive understanding.
    - `Score = 100 - Risk Rating`
- **Color Coding:**
    - **Green (70-100):** Excellent ESG performance (Low Risk).
    - **Orange (50-69):** Average ESG performance (Medium Risk).
    - **Red (0-49):** Poor ESG performance (High Risk).

## How to Use

1. **Portfolio View:** Navigate to the "Analytics" tab in your portfolio view to see your aggregate ESG score.
2. **Stock View:** Tap on any stock in your watchlist or portfolio. Scroll down past the "Fundamentals" section to find the "ESG Score" card.

## Technical Implementation

- **Data Source:** Yahoo Finance API (unofficial).
- **Parallel Processing:** ESG data for your entire portfolio is fetched in parallel to ensure fast loading times.
- **Caching:** Scores are cached in-memory to reduce network requests during your session.

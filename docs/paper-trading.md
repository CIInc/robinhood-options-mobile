# Paper Trading

## Overview

Paper Trading is a fully featured simulation environment that allows you to practice trading strategies, test the platform's features, and validate automated agents without risking real capital. The system is built on a robust `PaperService` architecture that ensures simulated orders and portfolios behave realistically.

## Getting Started

Your paper trading account is initialized with a simulated equity of **$100,000**.
*   **Reset:** You can reset your paper account to the initial $100k balance at any time via the "Refresh"/Reset icon in the dashboard.
*   **Switching:** Toggle between "Live" and "Paper" modes using the switch in the main navigation drawer or Agentic Trading settings.

## Dashboard Features

The Paper Trading Dashboard offers a comprehensive view of your simulated portfolio:

### 1. Portfolio Overview
*   **Total Equity:** Real-time value of cash + positions.
*   **P&L:** Total Profit/Loss since inception (or last reset).
*   **Day P&L:** Daily change in value.
*   **Buying Power:** Differentiates between paper and real account buying power during order placement.

### 2. AI-Powered Analysis
Tap the **Analytics (Magic Wand/Chart)** icon to trigger an AI analysis of your paper portfolio.
*   **Generative Insights:** The AI acts as a portfolio manager, reviewing your current holdings, cash levels, and performance using the `GenerativeService`.
*   **Portfolio Analysis:** It provides qualitative feedback on diversification, risk exposure, and suggestions for improvement based on simulated data.

### 3. Asset Allocation
Visual charts display your capital distribution:
*   **Interactive Charts:** Explore your distribution via the `community_charts_flutter` package.
*   **Stocks vs. Options vs. Cash:** See exactly how leveraged you are.
*   **Sector Breakdown:** Understand your industry exposure with updated asset color mapping.

### 4. Active Positions
Manage your simulated trades directly from the list:
*   **Quotes:** Real-time (or delayed, depending on plan) price updates.
*   **Closing:** Swipe or tap to close positions at current market prices.

## Technical Architecture

The paper trading system uses a dedicated service layer to maintain consistency:
- **PaperService:** Centralized management for user accounts, simulated portfolios, and virtual order placement.
- **Testing:** Extensively tested using `fake_cloud_firestore` to ensure data integrity and realistic state mutations.
- **Model Integration:** Shares the same underlying models as live trading for a seamless transition between modes.

## Integration with Agentic Trading

The Agentic Trading system fully supports Paper Trading.
*   **Testing Strategies:** You can run automated agents in Paper Mode to verify their performance in current market conditions.
*   **Performance Tracking:** Paper trades are tracked separately in the **Agentic Trading Performance** widget (use the filter to toggle between Live and Paper history).
*   **Notifications:** Push notifications for automated trades explicitly indicate "[PAPER]" to differentiate from live execution.

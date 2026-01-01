# Tax Loss Harvesting

RealizeAlpha includes a sophisticated **Tax Loss Harvesting** tool designed to help you optimize your tax liability by identifying opportunities to realize losses in your portfolio. This feature is integrated directly into the Portfolio Analytics dashboard and provides actionable, seasonality-aware insights.

## Key Features

### 1. Intelligent Opportunity Detection
The system automatically scans your entire portfolio (both Stocks and Options) to identify positions that are currently at a loss.

- **Stocks**: Identifies long positions where the current market value is lower than your cost basis.
- **Options**: Handles both Long (Debit) and Short (Credit) positions.
  - *Long Options*: Identifies when the current value is lower than the premium paid.
  - *Short Options*: Identifies when the cost to close (buy back) is higher than the premium received.

### 2. Seasonality Awareness
The feature understands the calendar and adjusts its urgency level based on the time of year, helping you prioritize tax planning when it matters most.

- **High Urgency (December)**:
  - **Status**: `URGENT` (Red Badge)
  - **Message**: "End of tax year approaching. Harvest losses now to offset this year's gains."
  - **Action**: Highly recommended to review all opportunities before Dec 31st.

- **Medium Urgency (October - November)**:
  - **Status**: `SEASON` (Orange Badge)
  - **Message**: "Tax season is approaching. Consider harvesting losses to optimize your tax liability."
  - **Action**: Start planning your end-of-year moves.

- **Low Urgency (January - September)**:
  - **Status**: Standard monitoring.
  - **Message**: "Monitor these positions for potential tax loss harvesting opportunities throughout the year."

### 3. Smart Visibility
To keep your dashboard clean and focused, the Tax Loss Harvesting card uses "Smart Visibility" logic:

- **During Tax Season (Oct-Dec)**: The card appears for any potential loss greater than **$10**.
- **Off-Season (Jan-Sep)**: The card remains hidden unless you have a significant potential loss (greater than **$100**).

### 4. Wash Sale Rule Warning
The tool includes a built-in educational warning about the **Wash Sale Rule**. This rule disallows the tax deduction of a loss if you buy a "substantially identical" security within 30 days before or after the sale.

### 5. Direct Trading Integration
The interface is designed for action:
- **Top Opportunity**: The dashboard card highlights your single largest tax loss opportunity immediately.
- **One-Tap Execution**: Tapping on any opportunity in the detailed list navigates directly to the instrument's trading page, allowing you to execute the trade seamlessly.
  - *Stocks*: Navigates directly to the stock page.
  - *Options*: Fetches the underlying instrument and navigates to it, allowing you to manage the option position.

## How to Use

1.  Navigate to the **Home** tab.
2.  Scroll down to the **Portfolio Analytics** section.
3.  Look for the **Tax Loss Harvesting** card (if visible based on Smart Visibility rules).
4.  Tap the card to view the detailed **Tax Optimization** screen.
5.  Review the list of opportunities, sorted by the size of the potential loss.
6.  Tap on a specific item to go to the trading screen and close the position if desired.

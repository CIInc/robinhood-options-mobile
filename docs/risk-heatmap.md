# Risk Heatmap

The Risk Heatmap is a powerful visualization tool designed to give you an immediate, high-level overview of your portfolio's performance and risk exposure. It uses a **Treemap** layout where the size of each tile represents the **Equity** (value) of the position, and the color represents its **Performance**.

## Key Features

### 1. Treemap Visualization
- **Size by Equity**: Larger tiles indicate larger positions, allowing you to instantly see where your capital is concentrated.
- **Color by Performance**:
  - **Green**: Positive performance.
  - **Red**: Negative performance.
  - **Intensity**: The brightness of the color scales with the magnitude of the change (e.g., bright green for large gains, dark red for large losses).

### 2. Flexible Views
Toggle between two different grouping modes to analyze your portfolio from different angles:
- **Sector View**: Aggregates positions by their industry sector (e.g., Technology, Healthcare). This helps you identify sector-wide trends and risks.
- **Symbol View**: Displays individual ticker symbols. This is useful for seeing the specific performance of each stock or option in your portfolio.

### 3. Performance Metrics
Switch between two key performance indicators:
- **Daily Change**: Visualizes the percentage change in value for the current trading day. Ideal for monitoring intraday volatility.
- **Total Return**: Visualizes the total percentage gain or loss since opening the position. Best for long-term performance tracking.

### 4. Smart Grouping ("Others")
To keep the visualization clean and readable, the heatmap automatically groups smaller positions:
- The top 11 largest positions (or sectors) are shown as individual tiles.
- All remaining smaller positions are aggregated into a single **"Others"** tile.
- The "Others" tile displays the combined equity and weighted average performance of all the smaller items.

### 5. Interactive Drill-Down
Tap on any tile to view detailed information:
- **Sector/Symbol Details**: See the specific equity, portfolio percentage, and position count.
- **Position List**: When tapping a sector or the "Others" tile, a bottom sheet appears listing all the individual positions contained within that group, sorted by equity.
- **Options Support**: The heatmap includes both stock and option positions, clearly labeled in the details view.

## How to Use
1.  Navigate to the **Search** tab (or the dedicated Risk Heatmap section).
2.  Use the **View** toggle to switch between "Sector" and "Symbol".
3.  Use the **Metric** toggle to switch between "Daily" and "Total".
4.  Tap on any tile to explore the underlying positions.

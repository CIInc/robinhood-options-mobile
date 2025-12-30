# Advanced Order Types

RealizeAlpha v0.23.0 introduces advanced order types to give you more control over your trade execution and risk management.

## Trailing Stop Orders

A Trailing Stop order allows you to set a stop price at a fixed amount or percentage below the market price with a "trailing" amount. As the market price rises, the stop price rises by the trail amount, but if the stock price falls, the stop price doesn't change, and a market order is submitted when the stop price is hit.

### Key Benefits
- **Lock in Profits**: Automatically adjusts your stop price upward as the asset price increases.
- **Limit Losses**: Provides downside protection without limiting upside potential.
- **No Manual Adjustment**: Removes the need to constantly monitor and manually adjust stop orders.

### How to Use
1. In the Trade screen, select **Sell**.
2. Tap the **Order Type** dropdown and select **Trailing Stop**.
3. Choose **Percentage** or **Amount** for the trail type.
4. Enter the trail value (e.g., 5% or $2.00).
5. Review the estimated initial stop price.
6. Swipe to submit the order.

## Stop-Limit Orders

A Stop-Limit order combines the features of a stop order and a limit order. Once the stop price is reached, a limit order is placed at the specified limit price.

### Key Benefits
- **Price Control**: Ensures you don't sell below a certain price (or buy above a certain price) once the stop is triggered.
- **Precision**: Useful in volatile markets where a standard stop order might execute at a significantly worse price than expected (slippage).

### How to Use
1. In the Trade screen, select **Buy** or **Sell**.
2. Tap the **Order Type** dropdown and select **Stop Limit**.
3. Enter the **Stop Price**: The price that triggers the order.
4. Enter the **Limit Price**: The worst price you are willing to accept.
5. Enter Quantity and other details.
6. Swipe to submit the order.

## Time in Force

You can now specify how long your order remains active before it is cancelled.

### Supported Options
- **GFD (Good For Day)**: The order remains active until the market closes on the current trading day. This is the default.
- **GTC (Good Till Cancelled)**: The order remains active until you manually cancel it or it is filled (typically up to 90 days).
- **IOC (Immediate Or Cancel)**: Any portion of the order that cannot be filled immediately is cancelled.
- **OPG (At The Open)**: The order is executed at the opening of the market.

### How to Use
1. In the Trade screen, tap **More Options** (or the settings icon).
2. Select your desired **Time in Force** option.
3. Proceed with placing your order.

## Trading UI Refactor

The trading interface has been completely redesigned for clarity and ease of use.

- **Order Preview**: A clear summary of your order details, estimated cost/credit, and resulting position impact before you confirm.
- **Slide to Confirm**: A new slide-to-confirm mechanism prevents accidental order submissions.
- **Real-time Estimates**: Dynamic updates of estimated total and stop prices as you adjust order parameters.

## Order Templates

> **New in v0.26.1**

Order Templates allow you to save complex order configurations and reuse them later, saving time and reducing errors.

### Key Benefits
- **Speed**: Quickly load frequently used order setups (e.g., "Buy 100 shares with 5% Trailing Stop").
- **Consistency**: Ensure you always use the same parameters for your standard trades.
- **Convenience**: Great for complex multi-leg strategies or specific risk management setups.

### How to Use
1. Configure an order with your desired parameters (Type, Quantity, Limit Price, Time in Force, etc.).
2. Tap the **Save Template** icon (floppy disk) in the top bar.
3. Give your template a name (e.g., "Standard Swing Entry").
4. To load a template, tap the **Load Template** icon (folder) and select from your saved list.


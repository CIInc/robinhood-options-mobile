# Order Templates

Order Templates allow you to save frequently used order configurations and reuse them later. This feature is available for Stocks, Options, and Crypto trading.

## Features

-   **Save Templates:** Save your current order configuration (Order Type, Quantity, Price, Time in Force, etc.) as a named template.
-   **Reuse Templates:** Quickly apply a saved template to populate the order form.
-   **Overwrite Protection:** If you try to save a template with an existing name, you will be asked if you want to overwrite it.
-   **Delete Templates:** Remove templates you no longer need.
-   **Cross-Device Sync:** Templates are stored in the cloud and synced across all your devices.

## How to Use

1.  **Navigate to Trade Screen:** Go to the trade screen for a Stock, Option, or Crypto.
2.  **Configure Order:** Set up your order parameters (e.g., Limit Buy, 10 shares, $150).
3.  **Save Template:**
    *   Tap the **Save Template** icon (floppy disk with pen) in the top-right corner of the AppBar.
    *   Select "Save current as template".
    *   Enter a name for your template (e.g., "Standard Buy").
    *   Tap "Save".
4.  **Load Template:**
    *   Tap the **Save Template** icon.
    *   Select a template from the list.
    *   The order form will be populated with the template's values.
5.  **Delete Template:**
    *   Tap the **Save Template** icon.
    *   Tap the delete icon (trash can) next to the template you want to remove.

## Supported Fields

The following fields are saved in a template:

-   **Position Type:** Buy / Sell
-   **Order Type:** Market, Limit, Stop, Stop Limit, Trailing Stop
-   **Time in Force:** GTC (Good Till Canceled), GFD (Good For Day), etc.
-   **Quantity:** Number of shares, contracts, or units.
-   **Price:** Limit price or Stop Limit price.
-   **Stop Price:** Stop price for Stop and Stop Limit orders.
-   **Trailing Amount:** Percentage or Amount for Trailing Stop orders.
-   **Trailing Type:** Percentage or Amount.

## Technical Details

Templates are stored in the `order_templates` collection in Firestore. Each template is linked to your user ID and is private to you.

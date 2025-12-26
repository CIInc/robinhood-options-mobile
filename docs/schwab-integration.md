# Schwab Integration

RealizeAlpha has integrated with Charles Schwab to provide users with a broader range of brokerage options. This integration allows Schwab clients to connect their accounts and manage their portfolios directly from the RealizeAlpha app.

## Key Features

- **Account Linking:** Securely link your Schwab account using OAuth authentication.
- **Portfolio Management:** View your Schwab portfolio holdings, including stocks, options, and cash.
- **Order Management:**
    - **View Orders:** Access your history of executed and pending orders.
    - **Option Orders:** Enhanced handling of option orders, including multi-leg strategies. **(Updated v0.25.0)**
- **Real-Time Data:** Fetch real-time quotes and market data for your holdings.
- **Seamless Navigation:** The app's navigation has been updated to support Schwab accounts, providing a consistent experience across different brokerages.

## Getting Started

1.  **Link Account:** Go to the "Settings" or "Accounts" section in the app.
2.  **Select Schwab:** Choose "Charles Schwab" from the list of available brokerages.
3.  **Authenticate:** You will be redirected to the Schwab login page to authenticate and authorize RealizeAlpha.
4.  **Sync Data:** Once linked, your portfolio and order data will automatically sync with the app.

## Technical Details

- **`SchwabService`:** A dedicated service class handles all interactions with the Schwab API, ensuring secure and efficient data retrieval.
- **Data Models:** New data models (e.g., `Instrument.fromSchwabJson`, `OptionOrder.fromSchwabJson`) have been implemented to parse Schwab-specific data formats.
- **Token Management:** The app handles OAuth token refresh automatically to maintain a secure connection.
- **Enhanced Integration (v0.25.0):** Improved reliability for option order execution and status tracking.

## Limitations & Future Work

- **Trading:** Currently, the integration focuses on portfolio and order management. Full trading capabilities (placing new orders) are planned for future updates.
- **Streaming Data:** Real-time streaming of quotes is being enhanced for better performance.

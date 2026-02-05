# Fidelity Integration

RealizeAlpha supports importing data from Fidelity accounts via CSV files. This allows you to view your Fidelity positions and history within the app without providing account credentials.

## Features

- **Positions Import**: Import your current positions from a Fidelity CSV export.
- **History Import**: Import your transaction history from a Fidelity CSV export.
- **Privacy First**: Data is processed locally and no login credentials are required.

## How to Import

1.  **Export from Fidelity**:
    *   Log in to your Fidelity account on a desktop browser.
    *   Navigate to your Portfolio Positions page.
    *   Click "Download" (CSV icon) to save your positions.
    *   Navigate to your History page for transaction history and download that CSV as well.

2.  **Import in RealizeAlpha**:
    *   Open RealizeAlpha and go to the Login/Accounts screen.
    *   Select **Fidelity** as the brokerage source.
    *   Tap "Enter" to enter the Fidelity manual mode.
    *   Use the file picker to select your downloaded CSV files.
    *   The app will parse the files and populate your portfolio and history.

## Limitations

- Since this is a manual import, data does not update in real-time. You will need to re-import CSV files to update your positions.
- Some complex transaction types might not be fully parsed.

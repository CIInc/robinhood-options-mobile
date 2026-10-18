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
    *   The app will parse the files using **FidelityService**, reconcile the data with existing instruments, and populate your portfolio and history.

## Portfolio Analytics Export

You can export your consolidated portfolio analytics to CSV for external review. This includes:
- Aggregated P&L metrics
- Reconciled position data from both manual imports and live brokerage links.
- Performance history headers.

## Technical Details

- **FidelityService:** Handles localized parsing and validation of Fidelity's unique CSV formatting.
- **CsvImportService:** Generic utility for handling cross-platform file selection and stream parsing.

## Limitations

- Since this is a manual import, data does not update in real-time. You will need to re-import CSV files to update your positions.
- Some complex transaction types might not be fully parsed.

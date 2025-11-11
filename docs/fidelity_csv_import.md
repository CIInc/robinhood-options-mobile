# Fidelity CSV Import

## Overview
The Fidelity CSV import feature allows users to import their transaction history from Fidelity brokerage accounts into the RealizeAlpha app.

## How to Use

1. **Export from Fidelity**:
   - Log into your Fidelity account
   - Navigate to the Accounts & Trade section
   - Go to History → Download
   - Select the date range you want to export
   - Choose CSV format
   - Download the file

2. **Import into RealizeAlpha**:
   - Open the RealizeAlpha app
   - Navigate to the Transactions (History) tab
   - Tap the upload icon (📤) in the top app bar
   - Select your Fidelity CSV file
   - Wait for the import to complete
   - You'll see a success message with the number of imported transactions

## Supported Transactions

### Stock Transactions
- Buy orders
- Sell orders
- Includes:
  - Symbol
  - Quantity
  - Price
  - Commission and fees
  - Settlement dates

### Option Transactions
- Buy to open
- Sell to open
- Buy to close
- Sell to close
- Includes:
  - Underlying symbol
  - Strike price
  - Expiration date
  - Option type (Call/Put)
  - Quantity
  - Premium
  - Commission and fees

## CSV Format

The Fidelity CSV export typically includes the following columns:
- Run Date
- Action
- Symbol
- Security Description
- Security Type
- Quantity
- Price
- Commission
- Fees
- Accrued Interest
- Amount
- Settlement Date

### Example Stock Transaction
```csv
Run Date,Action,Symbol,Security Description,Security Type,Quantity,Price,Commission,Fees,Accrued Interest,Amount,Settlement Date
01/15/2024,BUY,AAPL,APPLE INC,EQUITY,10,150.50,$0.00,$0.00,$0.00,-$1505.00,01/17/2024
```

### Example Option Transaction
```csv
Run Date,Action,Symbol,Security Description,Security Type,Quantity,Price,Commission,Fees,Accrued Interest,Amount,Settlement Date
02/01/2024,BUY TO OPEN,AAPL 02/16/2024 $150 CALL,APPLE INC CALL OPTION,OPTION,1,5.50,$0.00,$0.65,$0.00,-$550.65,02/02/2024
```

## Features

- **Automatic Header Detection**: The parser automatically finds the header row, even if there are metadata rows at the top of the CSV
- **Mixed Transactions**: Can handle CSVs containing both stock and option transactions
- **Error Handling**: Provides clear error messages if the import fails
- **Analytics Tracking**: Import events are logged for analytics purposes
- **Duplicate Handling**: Imported transactions are appended to existing transactions (no automatic deduplication)

## Limitations

- Only supports Fidelity CSV format
- Transactions are appended to existing data (not merged)
- No automatic duplicate detection
- Option details parsing is best-effort based on symbol format

## Troubleshooting

### Import Failed: Could not find header row in CSV file
- Ensure you're importing a valid Fidelity transaction CSV
- The file should contain headers like "Run Date", "Action", "Symbol", etc.

### Import Failed: CSV file is empty
- The selected file contains no data
- Try re-exporting from Fidelity

### No transactions imported
- The CSV might not contain any valid transactions
- Check that the date range includes actual transactions
- Ensure the CSV format matches the expected Fidelity format

## Future Enhancements

Potential future improvements:
- Support for other brokerage CSV formats (Schwab, TD Ameritrade, etc.)
- Automatic duplicate detection and prevention
- CSV validation before import
- Preview of transactions before confirming import
- Import history tracking
- Ability to undo imports.

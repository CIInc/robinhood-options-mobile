# Fidelity CSV Import Architecture

## Component Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         User Interface                          │
│                    (history_widget.dart)                        │
│                                                                 │
│  ┌──────────────┐  ┌─────────────┐  ┌────────────────────┐   │
│  │   Upload     │  │   File      │  │  Success/Error     │   │
│  │   Button     │→ │   Picker    │→ │    Messages        │   │
│  │   (📤)       │  │   Dialog    │  │   (SnackBar)       │   │
│  └──────────────┘  └─────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      Import Service Layer                       │
│             (fidelity_csv_import_service.dart)                  │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  parseTransactionsCsv()                                   │ │
│  │    ↓                                                      │ │
│  │  1. Read CSV file                                        │ │
│  │  2. Find header row (skip metadata)                      │ │
│  │  3. Parse each data row                                  │ │
│  │  4. Determine transaction type (stock vs option)         │ │
│  │  5. Create appropriate model objects                     │ │
│  │  6. Return parsed lists                                  │ │
│  └──────────────────────────────────────────────────────────┘ │
│                              ↓                                  │
│         ┌─────────────────────┴─────────────────────┐          │
│         ↓                                           ↓          │
│  ┌─────────────────┐                    ┌──────────────────┐  │
│  │ Stock Parser    │                    │  Option Parser   │  │
│  │                 │                    │                  │  │
│  │ _parseInstrument│                    │ _parseOption     │  │
│  │ Order()         │                    │ Order()          │  │
│  │                 │                    │                  │  │
│  │ • Symbol        │                    │ • Chain Symbol   │  │
│  │ • Quantity      │                    │ • Strike         │  │
│  │ • Price         │                    │ • Expiration     │  │
│  │ • Side (buy/sell)                    │ • Type (call/put)│  │
│  │ • Fees          │                    │ • Premium        │  │
│  │ • Dates         │                    │ • Strategy       │  │
│  └─────────────────┘                    └──────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                         Data Models                             │
│                                                                 │
│  ┌──────────────────────┐        ┌───────────────────────┐    │
│  │  InstrumentOrder     │        │    OptionOrder        │    │
│  │                      │        │                       │    │
│  │  • id                │        │  • id                 │    │
│  │  • symbol            │        │  • chainSymbol        │    │
│  │  • quantity          │        │  • direction          │    │
│  │  • price             │        │  • legs []            │    │
│  │  • side              │        │  • premium            │    │
│  │  • state             │        │  • openingStrategy    │    │
│  │  • createdAt         │        │  • closingStrategy    │    │
│  │  • updatedAt         │        │  • createdAt          │    │
│  └──────────────────────┘        └───────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                        State Management                         │
│                                                                 │
│  Existing transactions + Imported transactions                  │
│  ↓                                                              │
│  Display in Transaction History view                            │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. User Interaction
```
User taps Upload Button
  → File Picker opens (filtered to .csv)
  → User selects CSV file
  → Loading dialog appears
```

### 2. CSV Parsing
```
Read CSV file content
  → Find header row (skip metadata)
  → For each data row:
      → Extract values based on headers
      → Determine if stock or option transaction
      → Call appropriate parser
      → Create model object
  → Return lists of parsed transactions
```

### 3. Transaction Type Detection
```
Check Symbol + Description + Security Type
  ↓
Contains "CALL" or "PUT"? 
  → YES: Option Transaction
  → NO:  Stock Transaction
```

### 4. Stock Transaction Parsing
```
CSV Row → InstrumentOrder
  • Symbol      → instrumentId
  • Action      → side (buy/sell)
  • Quantity    → quantity, cumulativeQuantity
  • Price       → price, averagePrice
  • Commission  → fees (+ other fees)
  • Dates       → createdAt, updatedAt
  • Generate    → unique id
```

### 5. Option Transaction Parsing
```
CSV Row → OptionOrder
  • Symbol        → parse for chainSymbol, strike, expiration
  • Action        → determine strategy (opening/closing)
  • Description   → parse for call/put type
  • Quantity      → quantity, processedQuantity
  • Price         → price
  • Amount        → premium (with sign based on direction)
  • Create        → OptionLeg object
  • Generate      → unique id
```

### 6. State Update
```
Parsed transactions
  → Append to existing positionOrders (stocks)
  → Append to existing optionOrders (options)
  → setState() triggers UI update
  → Show success message with counts
  → Log analytics event
```

## Error Handling

```
┌─────────────────────────────────────────────┐
│             Error Scenarios                 │
├─────────────────────────────────────────────┤
│                                             │
│  Empty File                                 │
│    → throw "CSV file is empty"             │
│                                             │
│  No Header Row Found                        │
│    → throw "Could not find header"         │
│                                             │
│  File Read Error                            │
│    → catch and show error message          │
│                                             │
│  Parse Error in Row                         │
│    → print error, skip row, continue       │
│                                             │
│  Invalid Date/Number Format                 │
│    → tryParse() returns null, use default  │
│                                             │
└─────────────────────────────────────────────┘
```

## Key Design Decisions

### 1. Append vs Merge Strategy
- **Decision**: Append imported transactions to existing lists
- **Rationale**: Simple, no complex duplicate detection needed
- **Trade-off**: May create duplicates if user imports same file twice
- **Future**: Could add duplicate detection based on transaction details

### 2. ID Generation
- **Decision**: Generate unique IDs from transaction details + timestamp
- **Format**: `fidelity_{symbol}_{timestamp}_{quantity}`
- **Rationale**: Ensures uniqueness without server-side coordination

### 3. Header Detection
- **Decision**: Search for header row automatically
- **Rationale**: Fidelity CSVs often have metadata rows at top
- **Implementation**: Look for common headers like "Run Date", "Action", "Symbol"

### 4. Error Recovery
- **Decision**: Continue parsing on individual row errors
- **Rationale**: One bad row shouldn't fail entire import
- **Implementation**: Try-catch around individual row parsing

### 5. UI Feedback
- **Decision**: Show loading, then success/error message
- **Rationale**: Import can take a few seconds for large files
- **Implementation**: Dialog for loading, SnackBar for results

## Testing Strategy

### Unit Tests
- Test each parser function independently
- Cover edge cases (empty, malformed data)
- Verify correct model object creation
- Test with various CSV formats

### Integration Testing
- Full file import workflow
- Mixed transaction types
- Real-world CSV examples

### Manual Testing
- Use sample CSV file
- Test on actual device with file picker
- Verify UI feedback
- Check transaction display

## Performance Considerations

- **CSV Size**: Parser handles files with hundreds of transactions
- **Memory**: Transactions loaded into memory (acceptable for typical use)
- **UI Thread**: File reading is async, but parsing is synchronous
  - For very large files (thousands of rows), could add progress indicator
  - Current implementation handles typical CSVs (< 1000 rows) instantly

## Future Enhancements

1. **Other Brokerages**
   - Schwab CSV format
   - TD Ameritrade format
   - E*TRADE format
   - Generic CSV mapper

2. **Duplicate Detection**
   - Hash transactions by key fields
   - Skip or flag duplicates
   - Allow user to choose merge strategy

3. **Import Preview**
   - Show parsed transactions before confirming
   - Allow user to select which to import
   - Display parsing warnings

4. **Advanced Parsing**
   - Multi-leg option strategies
   - Corporate actions (splits, mergers)
   - Dividends and interest
   - Transfers and deposits

5. **Import History**
   - Track which files were imported
   - Allow undo of import
   - Export audit log

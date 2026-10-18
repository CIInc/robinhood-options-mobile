# Congress & Political Trading Tracker

Under the Stop Trading on Congressional Knowledge (STOCK) Act of 2012, Members of the United States Congress (Senate and House of Representatives) and senior legislative branch officials must publicly disclose transactions in stocks, bonds, options, and commodities made by themselves, their spouses, or dependent children exceeding \$1,000 within 45 days of the trade date via Periodic Transaction Reports (PTR).

The Congress & Political Trading Tracker monitors these financial disclosures, measures disclosure delay metrics, flags late filings violating the 45-day STOCK Act statutory limit, categorizes party affiliations, and matches political trades against the user's active stock and option portfolio holdings to power proactive smart alerts and instrument-level research.

---

## Architecture & Components

### 1. Cloud Functions Backend (`functions/src/congress-trading.ts`)
- **Live Disclosures Ingestion Pipeline (`fetchMemberDisclosuresLive`, `normalizeLiveCongressTrade`)**:
  - Automatically queries live public REST feeds aggregating House and Senate Periodic Transaction Reports (PTR).
  - Actively tracks the top trading Members of Congress across both chambers (Nancy Pelosi, Tommy Tuberville, Dan Crenshaw, Michael McCaul, Ro Khanna, Josh Gottheimer, Markwayne Mullin, Cory Booker, Sheldon Whitehouse, Mitch McConnell, John Curtis, Kevin Hern, Victoria Spartz, Marjorie Taylor Greene, Daniel Meuser, Dan Newhouse, Cleo Fields, Gilbert Cisneros, John McGuire, Pete Sessions).
  - Normalizes raw filing records into structured `CongressTrade` objects, extracting politician name, chamber, party, ticker, transaction type, amount brackets, trade date, disclosure date, owner, and official Clerk source PDF links.
- **Callable Cloud Function (`getCongressTrades`)**:
  - Serves PTR disclosure listings filtered by `symbol`, `chamber` (`senate`, `house`), `party` (`democrat`, `republican`, `independent`), `transactionType` (`purchase`, `sale`, `exchange`), and `minAmount`.
  - Determines portfolio overlap server-side: when invoked by an authenticated user, it cross-references user positions stored in Firestore (`user/{uid}/instrumentPosition`) and marks `hasPortfolioOverlap` along with `heldSymbol`.
  - Computes statutory compliance metrics:
    - **Filing Lag**: Elapsed calendar days between transaction date and public disclosure date.
    - **Overdue Flag**: Disclosures filed greater than 45 days after transaction execution (`isOverdue: true`).
- **Scheduled Synchronization (`refreshCongressTrades`)**:
  - Runs periodically (every 6 hours) via Firebase Scheduler to poll and sync live disclosures for tracked members, batching and upserting records with deduplication into Firestore (`congress_disclosures`).

### 2. Data Models & Client Service
- **Model (`lib/model/congress_trade.dart`)**:
  - `CongressTrade`: Structured disclosure model (politician name, chamber, party, district/state, ticker symbol, asset description, transaction type, amount brackets with numerical min/max values, transaction date, disclosure date, owner type, official PTR source URL, filing lag days, and overdue status).
  - `CongressTradingSnapshot`: Summary container containing trade listings, total disclosed volume estimate, net purchase ratio, top traded symbols, and portfolio overlap count.
- **Service (`lib/services/congress_trading_service.dart`)**:
  - Queries `getCongressTrades` with client-side caching.
  - Resilient offline fallback with verified public STOCK Act disclosures if offline, unauthenticated, or in demo mode.

### 3. Portfolio Alerts & Smart Alerts Integration
- **Portfolio Alert System (`lib/services/portfolio_alert_service.dart`)**:
  - Automatically evaluates recent congressional disclosures against user equity positions (`InstrumentPosition`) and option contracts (`OptionAggregatePosition`).
  - Severity calculation:
    - Purchases $\ge \$250,000$: `PortfolioAlertSeverity.positive` (high-conviction buying signal).
    - Sales $\ge \$250,000$: `PortfolioAlertSeverity.warning` (major divestment alert).
    - Standard trades: `PortfolioAlertSeverity.info`.
  - Tapping an alert deep-links directly to the Insights section (`PortfolioAlertTarget.congressionalTrading`).
- **Custom / Smart Alerts (`lib/model/custom_alert.dart`)**:
  - Added `AlertType.congress_trading` with triggers:
    - `congress_trade_purchase`: Triggers when a Member purchases $\ge$ threshold amount.
    - `congress_trade_sale`: Triggers on sales $\ge$ threshold amount.
    - `congress_trade_any`: Triggers on any trade $\ge$ threshold amount.

### 4. User Interface
- **Instrument Detail Card (`lib/widgets/congress_trading_widget.dart`)**:
  - Integrated into the research slivers of stock and option instrument views.
  - Displays political party badges (Democrat blue, Republican red, Independent purple), politician name, transaction type, filing lag, STOCK Act overdue status (>45 days), and link to original disclosure PTR document.
  - Prominently displays a "Held in Portfolio" chip when the user holds shares or options in the company.
- **Congress Trading Dashboard (`lib/widgets/congress_trading_dashboard_widget.dart`)**:
  - Accessible via the Search/Discovery screen (`search_widget.dart`).
  - Searchable by member name or ticker symbol.
  - Filter chips for Portfolio Overlap, Chamber (Senate/House), Political Party (Democrat/Republican), and Transaction Type (Purchase/Sale).
  - Summary metrics: total disclosure volume, purchase vs. sale breakdown, and active alerts.

---

## Scope & Limitations
- Disclosures are sourced from public House and Senate financial disclosure portals under the STOCK Act of 2012.
- Due to statutory filing windows (30-45 days), trades are reported with a delay; the tracker highlights this filing lag prominently to ensure transparency.

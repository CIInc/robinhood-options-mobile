# Robinhood Options Mobile

## Use Cases
- A better options UI view for Robinhood users.
- Ability to make better trades.
- Price target recommendations. 

## Requirements

### Tabs

- Portfolio tab
  - Summary section
    - [x] Portfolio historical charts view.
    - [x] Portfolio summary breakdown view.
  - Options section
    - [x] Options list with filters.
    - [x] Option detail view with market data (see Option view).
  - Stocks section
    - [x] Stock list with filters.
    - [x] Stock detail view with market data (see Stock view).
  - Crypto section
    - [x] Crypto holdings
- Search tab
  - [x] Search companies by name or symbol.
- Lists tab
  - [x] View your lists and its stocks. Drill into the stocks listed.
    - [ ] List sort order maintenance.
    - [ ] List item sort order maintenance.
  - [ ] Create new list.
  - [ ] Edit list.
  - [ ] Add symbol to list.
- History tab
  - [x] Position order list.
  - [x] Option order list.
  - [x] Balances and order counts.
  - [ ] Option event list.

### Views

- Option view
  - [x] Option greeks view.
    - [ ] Risk analysis with charts.
- Stock view
  - [x] Instrument (Stock) view
    - [x] Positions, options, orders view
    - [x] Fundamentals view.
    - [x] Historical charts view.
    - [ ] Related stock view.
    - [x] News view.
    - [ ] Earnings view.
    - [ ] Splits & Corporate Actions view.
  - [x] Option chain view.
    - [ ] Show current price list divider with scroll to function.
  - [ ] Stock research
    - [ ] Movers (gainers and losers).
    - [ ] Popular (based on average volume vs current volume).
    - [ ] Undervalued/Overvalued (Fair value evaluation)
- Trading View
  - [ ] Place stock order.
  - [ ] Place option order.
    - [ ] buy-to-close, sell-to-open, limit, time-in-force
    - [ ] Multi-leg strategies.
      - [ ] Call/Put debit/credit spreads.
      - [ ] Synthetic long/short.
      - [ ] Calendar/diagonal spreads.
    - [ ] Price spread selector (bid/ask analysis for low volume options).
  - [ ] Place crypto order.
  - [ ] Cancel pending order.
  - [ ] Replace order.
- Account View
  - [ ] Manage multiple account on the trading platform.
  - [ ] Allow the switching between acounts without having to logout.

## Future work

### Social integration
  - [ ] Reddit
    - [ ] Publish gain/loss results to /WSB
  - [ ] Twitter
### Machine Learning
  - [ ] Machine learning target price model service.

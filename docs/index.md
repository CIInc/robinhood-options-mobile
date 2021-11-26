# Robinhood Options Mobile

## Use Cases
- A better options UI view for Robinhood users.
- Ability to make better trades.
- Price target recommendations. 

## Requirements

### Tabs

- Portfolio tab
  - Summary section
    - [x] Portfolio historical charts view
    - [x] Portfolio summary breakdown view
  - Options section
    - [x] Options list with filters
    - [x] Option detail view with market data (see Option view)
  - Stocks section
    - [x] Stock list with filters
    - [x] Stock detail view with market data (see Stock view)
  - Crypto section
    - [x] Crypto holdings
- Search tab
  - [x] Search companies by name or symbol
- Lists tab
  - [x] View your lists and its stocks
    - [ ] List sort order maintenance
    - [ ] List item sort order maintenance
  - [x] View RobinHood lists
  - [ ] Create new list
  - [ ] Edit list
  - [ ] Add symbol to list
- History tab
  - [x] Position order list
  - [x] Option order list
    - [x] Integrated option event list
  - [x] Balances and order counts
  - [x] Share orders as a link

### Views

- Stock view
  - [x] Instrument (Stock) view
    - [x] Positions, options, orders view
    - [x] Fundamentals view
    - [x] Historical charts view
    - [x] Related lists view
    - [x] News view
    - [x] Ratings view
    - [x] Earnings view
    - [x] Similar view
    - [ ] Splits & Corporate Actions view
  - [x] Option chain view
    - [ ] Show current price list divider with scroll to function
- [x] Stock Search/Research
  - [x] Movers (gainers and losers)
  - [x] Popular (based on average volume vs current volume)
  - [ ] Undervalued/Overvalued (Fair value evaluation)
- Option view
  - [x] Option greeks view
    - [ ] Risk analysis with charts
- Trading view
  - [ ] Place stock order
  - [x] Place option order
    - [ ] buy-to-close, sell-to-open, limit, time-in-force
    - [ ] Multi-leg strategies
      - [ ] Call/Put debit/credit spreads
      - [ ] Synthetic long/short
      - [ ] Calendar/diagonal spreads
    - [ ] Price spread selector (bid/ask analysis for low volume options)
  - [ ] Place crypto order
  - [ ] Cancel pending order
  - [ ] Replace order
- Account view
  - [ ] Manage multiple account on the trading platform
  - [ ] Allow the switching between acounts without having to logout

## Future work

### Social integration
  - [ ] Reddit
    - [ ] Publish gain/loss results to /WSB
  - [ ] Twitter
### Machine Learning
  - [ ] Machine learning target price model service

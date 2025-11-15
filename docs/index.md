# RealizeAlpha

## Use Cases
- A better options UI view for Robinhood users.
- Ability to make better trades.
- Price target recommendations.
- Enhanced portfolio management with advanced analytics.
- Simplified trading for beginners with guided workflows.
- Centralized view for stocks, options, and crypto assets.
- Integration with brokerage accounts for real-time data.
- AI-driven insights and recommendations.
  - Note: AI portfolio prompts now include per-account cash and a total cash summary when available.
- Historical data analysis for informed decision-making.
- Cross-platform access for iOS and Android users.
- Community-driven features for shared insights and discussions.
- Enhanced security and privacy for user data.
- Customizable watchlists and alerts for market movements.
- Advanced charting tools for technical analysis.
- Integration with social media for sentiment analysis.

## Investment Profile Feature

This feature adds investment profile configuration to user settings, allowing users to specify their investment goals, time horizon, risk tolerance, and portfolio value. These preferences are then integrated into AI Portfolio Recommendations to provide personalized financial advice.

### Model changes
- Added optional fields on the `User` model: `investmentGoals`, `timeHorizon`, `riskTolerance`, `totalPortfolioValue`.

### AI integration
- `GenerativeService.portfolioPrompt()` now accepts a `user` parameter and includes an "Investment Profile" section when available.
- The prompt also includes per-account cash (`portfolioCash`) and an aggregated total cash across accounts when `user.accounts` is present.

### UI
- New `Investment Profile Settings` widget under user settings for editing goals, time horizon, risk tolerance, and portfolio value.

### Developer notes
- The AI generation pipelines accept an optional `user` parameter and pass it through to `generateContent()`.
- When `user` is not provided, behavior is backward compatible.


## Requirements

### Tabs

- Portfolio tab
  - Portfolio section
    - [x] Portfolio historical chart with filters  
      _Visualize portfolio value over time with customizable date ranges and chart types (line, candlestick, etc.)._
    - [x] Portfolio summary breakdown view  
      _See allocation by asset class, sector, or custom tags._
  - Options section
    - [x] Options summary with bar chart  
      _Quickly assess open options positions by type, expiry, or strategy._
    - [x] Options list with filters and grouping  
      _Filter by expiry, strike, underlying, or strategy (e.g., spreads, covered calls)._
    - [x] Option detail view with market data (see Option view)  
      _Access Greeks, IV, open interest, and historical performance._
  - Stocks section
    - [x] Stock summary with bar chart  
      _Visualize holdings by ticker, sector, or performance._
    - [x] Stock list with filters  
      _Filter by gainers, losers, sector, or watchlist._
    - [x] Stock detail view with market data (see Stock view)  
      _Access fundamentals, news, analyst ratings, and earnings._
  - Crypto section
    - [x] Crypto holdings  
      _Track balances and performance for supported cryptocurrencies._
    - [x] Crypto detail view with market data (see Crypto view)  
      _View price charts, news, and on-chain analytics._
    - [ ] Crypto sentiment analysis  
      _Gauge market sentiment from social media and news sources._

- Transactions tab
  - [x] Position order list  
    _Review all past and open orders for stocks, options, and crypto._
  - [x] Option order list  
    _Track option-specific orders and their outcomes._
    - [x] Integrated option event list  
      _See assignment, exercise, and expiration events._
  - [x] Balances and order counts  
    _Monitor cash, margin, and buying power._
  - [x] Share orders  
    _Track fractional and whole share purchases and sales._
  - [ ] Transaction analytics  
    _Break down profits, losses, and fees by trade type or asset._

- Search tab
  - [x] Search companies by name or symbol  
    _Find stocks, options, or crypto quickly._
  - [x] S&P movers, losers, and gainers  
    _See daily market leaders and laggards._
  - [x] Top 100 stocks  
    _Browse the most popular or highest-volume stocks._
  - [ ] Undervalued/Overvalued (Fair value evaluation)  
    _Identify potential bargains or overpriced assets using valuation models._
  - [ ] Advanced search filters  
    _Filter by sector, market cap, P/E ratio, dividend yield, etc._

- Lists tab
  - [x] View your lists and its stocks  
    _Organize watchlists and custom groups._
    - [ ] List sort order maintenance  
      _Drag and drop to reorder lists._
    - [ ] List item sort order maintenance  
      _Reorder items within a list._
  - [x] View RobinHood lists  
    _Access default lists like "Top Movers" or "Most Popular."_
  - [ ] Create new list  
    _Add custom watchlists for tracking ideas._
  - [ ] Edit list  
    _Rename, reorder, or delete lists._
  - [ ] Add symbol to list  
    _Quickly add stocks, options, or crypto to any list._
  - [ ] Collaborative lists  
    _Share and manage lists with friends or the community._

### Views

- Stock view
  - [x] Instrument (Stock) view  
    _Comprehensive overview of a stock, including price, news, and performance._
    - [x] AI-generated trend analysis  
      _Get insights on price trends and patterns._
    - [ ] AI-generated price target  
      _Get a recommended price target based on AI analysis._
    - [ ] AI-generated news sentiment analysis
      _Analyze news sentiment and its potential impact on stock price._
    - [x] Position detail with orders  
      _See all trades and open positions for a stock._
    - [x] Options list with orders  
      _View all options trades related to the stock._
    - [x] Fundamentals view  
      _Access key financial metrics and ratios._
    - [x] Historical chart with filters  
      _Analyze price trends over different periods._
    - [x] Related lists view  
      _See which lists the stock appears in._
    - [x] News view  
      _Stay updated with the latest headlines._
    - [x] Ratings view  
      _See analyst recommendations and target prices._
    - [x] Earnings view  
      _Review past and upcoming earnings reports._
    - [x] Similar view  
      _Discover similar stocks based on sector or performance._
    - [ ] Splits & Corporate Actions view  
      _Track splits, dividends, and other events._
    - [ ] Insider trading activity view  
      _Monitor insider buys and sells._
  - [x] Option chain view  
    _Browse available options contracts and strategies._
    - [x] Show current price list divider with scroll-to function  
      _Quickly jump to at-the-money options._

- Option view
  - [x] Option greeks view  
    _Analyze delta, gamma, theta, vega, and rho._
    - [x] AI-generate contract selection  
      _Get recommendations on which options to trade._
    - [ ] Risk analysis with charts  
      _Visualize risk/reward and breakeven points._
    - [ ] Probability of profit (POP) calculator  
      _Estimate the likelihood of a profitable outcome._

- Crypto view
  - [x] Crypto historical chart with filters  
    _Analyze price trends and volatility._
  - [ ] Crypto staking rewards tracker  
    _Track earned rewards from staking._
  - [ ] Crypto wallet integration  
    _Connect external wallets for a unified view._

- Trading view
  - [ ] Place stock order  
    _Buy or sell stocks directly from the app._
  - [x] Place option order  
    _Trade single-leg and multi-leg options._
    - [ ] buy-to-close, sell-to-open, limit, time-in-force  
      _Support advanced order types._
    - [ ] Multi-leg strategies  
      _Trade spreads, straddles, and more._
      - [ ] Call/Put debit/credit spreads
      - [ ] Synthetic long/short
      - [ ] Calendar/diagonal spreads
    - [ ] Price spread selector (bid/ask analysis for low-volume options)  
      _Find optimal entry/exit points._
  - [ ] Place crypto order  
    _Trade supported cryptocurrencies._
  - [ ] Cancel pending order  
    _Easily cancel open orders._
  - [ ] Replace order  
    _Modify existing orders without canceling._
  - [ ] Trade simulator (practice trading with virtual money)  
    _Test strategies risk-free._

- Account view
  - [ ] Manage multiple accounts on the trading platform  
    _Switch between accounts without logging out._
  - [ ] Account performance analytics (e.g., CAGR, Sharpe ratio)  
    _Track long-term performance and risk-adjusted returns._

### Future Feature Suggestions

- **Social Integration**
  - [ ] Reddit integration for trending tickers and sharing results.
  - [ ] Twitter sentiment tracking and sharing.
  - [ ] Community-driven trade ideas and discussions.

- **Machine Learning & Analytics**
  - [ ] AI-powered price target and trade recommendations.
  - [ ] Portfolio optimization using machine learning.
  - [ ] Sentiment analysis for news and social media.
  - [ ] Risk exposure and sector allocation heatmaps.

- **Notifications & Alerts**
  - [ ] Custom price alerts for stocks, options, and crypto.
  - [ ] Earnings and dividend notifications.
  - [ ] News alerts for portfolio holdings.

- **Mobile & Usability Enhancements**
  - [ ] Offline mode for portfolio and charts.
  - [ ] Push notifications for trade execution and alerts.
  - [ ] Home screen widgets for quick updates.

- **Collaboration & Sharing**
  - [ ] Shared watchlists with friends.
  - [ ] Group discussions for specific assets.
  - [ ] Public leaderboards for portfolio performance.

---

- [App Launcher Icon](https://icon.kitchen/i/H4sIAAAAAAAAAz2PQQvCMAyF%2F8vzuoswQXrdH%2FCwm4h0a9oVu2V0rSJj%2F910ipfk8RLyvax46pBpgVphdHy0A40EZXVYqIJ1TfCzjqmMF5IGQ1bnkFDB9zyJkSJNxk%2FunmdsFTrXvme5gJ4DR1nrXLMrhUNdn7W14qVCMVAp5p1y0aacKJTEM9TxVCF6NwiwyI5T4vGrA9ndFZT9o34hxRvZ5FDeuUJPJrI3JSkvUl%2FU4bZ9AAfiKa7xAAAA)

## Testing

- Run unit tests for the app:

```bash
cd src/robinhood_options_mobile
flutter test
```

- Run a single test file (example):

```bash
flutter test test/user_model_test.dart
```

## Developer Reference

- Key files:
  - `lib/main.dart` - App entrypoint and provider wiring
  - `lib/model/user.dart` - User model and investment profile fields
  - `lib/services/generative_service.dart` - AI prompt generation and `portfolioPrompt()`
  - `lib/widgets/investment_profile_settings_widget.dart` - Investment profile UI
  - `functions/` - Server-side Firebase Functions and helpers

## Support

- For issues related to investment profile behavior or AI prompts:
  1. Check `lib/services/generative_service.dart` for prompt construction
  2. Review unit tests under `test/`
  3. Use Firebase emulator for local testing of functions
  4. Contact the development team with reproducible steps and sample user data
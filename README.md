# RealizeAlpha

This repository implements brokerage APIs like Robinhood to provide an options focused Android and iOS mobile app using the Flutter SDK.

## Getting Started

See our [docs](https://ciinc.github.io/robinhood-options-mobile/) for use cases and application requirements.

## Features

*   **Brokerage Integration:** Connects securely to brokerage accounts (e.g., Robinhood) to fetch real-time data.
*   **Options Chain Viewing:** Displays detailed options chains for various underlying assets.
*   **Historical Data Analysis:** Fetches and visualizes historical price data for instruments. **New:** Benchmark Chart with Date Range Selection (1W, 1M, 3M, YTD, 1Y, ALL) for performance comparison.
*   **Portfolio Allocation Visualization:** Interactive carousel of pie charts showing portfolio allocation breakdown by asset type, individual positions (top 5 holdings), sector, and industry. Features bidirectional highlighting between chart slices and legend entries with visual page indicators.
*   **Stock Screener:** Advanced stock filtering by sector, market cap, P/E ratio, dividend yield, price, and volume with quick presets and Yahoo Finance integration. Now features a dedicated interface for easier discovery.
*   **Trade Signals:** AI-powered agentic trading with 12-indicator correlation system (Price Movement, RSI with divergence, Market Direction, Volume, MACD, Bollinger Bands, Stochastic, ATR, OBV, VWAP, ADX, Williams %R) for automatic trade detection and execution. Fully autonomous operation with 5-minute periodic checks, trade-level take profit/stop loss tracking, trailing stops, and Firebase persistence. User-configurable settings with per-indicator enable/disable controls and in-app documentation widget. Supports both daily and intraday signals (15-minute, hourly, and daily intervals) with real-time Firestore updates, market status indicators, signal strength visualization, and push notifications. Includes comprehensive performance analytics with 9 analytics cards tracking Sharpe ratio, profit factor, expectancy, streaks, drawdown, time-of-day performance, indicator combination effectiveness, and symbol-specific win rates. Paper Trading Mode enables risk-free strategy testing with simulated order execution. **New:** Advanced filtering by Signal Strength (Strong/Moderate/Weak) and 4-way Indicator states (Off/BUY/SELL/HOLD) with server-side optimization. **New:** Advanced Risk Controls (Sector Limits, Correlation Checks, Volatility Filters, Drawdown Protection) and Order Approval Workflow. **New:** Custom Indicators support and ML-powered Signal Optimization. **New:** Advanced Exit Strategies including Partial Exits, Time-Based Exits, and Market Close Exits. **New:** Emergency Stop functionality (long-press auto-trade toggle) and improved status display.
*   **Backtesting Interface:** Test trading strategies on historical data using the same 12-indicator system as live trading. Configure symbols, date ranges, intervals, and risk parameters. Analyze comprehensive metrics including Sharpe ratio, max drawdown, win rates, and profit factors. View trade-by-trade breakdowns with interactive equity curves, save reusable configuration templates, and compare multiple backtest results. Supports daily, hourly, and 15-minute intervals with template management and result export.
*   **AI-Powered Insights:** Leverages Generative AI (like Gemini) to provide analysis on market data (e.g., chart trends) with personalized investment profile integration.
*   **Generative Actions:** Context-aware AI actions and insights integrated directly into the UI for streamlined decision-making.
*   **Watchlist Management:** Create and manage custom watchlists, add/remove instruments, and view real-time data for tracked assets.
*   **Investor Groups:** Create and join investor groups to share portfolios and collaborate with other investors. Includes comprehensive member management with invitation system, admin controls for promoting/demoting members, and direct portfolio viewing for private group members. Features real-time user search and 3-tab admin interface (Members, Pending, Invite).
*   **Copy Trading:** Per-group settings to copy filled stock/ETF and option trades from a selected member with immediate manual execution via brokerage API, quantity/amount limits, audit trail in `copy_trades`, and push notifications. Now features a dedicated **Copy Trading Dashboard** with trade history, filtering, and a request approval workflow. Includes **Inverse Copying** (contrarian mode) and **Exit Strategies** (Take Profit/Stop Loss) for better risk management. Auto-execute planned.
*   **Futures Positions:** Live futures position enrichment with contract & product metadata (root symbol, expiration, currency, multiplier) plus real-time quote integration and Open P&L calculation using `(lastTradePrice - avgTradePrice) * quantity * multiplier`. (Realized/day P&L, margin metrics, and roll detection planned.)
*   **[Option Chain Screener](docs/option-strategy-builder.md#option-chain-screener):** Advanced filtering capabilities for option chains including Delta, Theta, Gamma, Vega, Implied Volatility, and more. Features AI-powered "Find Best Contract" suggestions based on risk tolerance and strategy.
*   **[Strategy Builder](docs/option-strategy-builder.md#multi-leg-strategy-builder):** Multi-leg options strategy builder supporting Spreads, Straddles, Iron Condors, and custom combinations with visual payoff diagrams and risk/reward analysis.
*   **[Advanced Order Types](docs/advanced-order-types.md):** Support for Trailing Stop, Stop-Limit, and Time-in-Force (GTC, IOC, etc.) orders for both stocks and options.
*   **Cross-Platform:** Built with Flutter for a consistent experience on both Android and iOS.


## Architecture Overview

RealizeAlpha utilizes a combination of technologies:

*   **Mobile App:** Developed using the Flutter SDK and Dart for cross-platform deployment (iOS, Android).
*   **Backend Services:** Firebase Functions (written in TypeScript/JavaScript) are used for:
    *   Securely interacting with brokerage APIs.
    *   Handling business logic that shouldn't reside on the client.
    *   Integrating with AI services (e.g., Google AI Gemini API).
*   **Authentication:** Firebase Authentication manages user sign-in and security.
*   **Database/Storage:** Firestore or other Firebase services might be used for storing user preferences or other relevant data (if applicable).
*   **Hosting:** Firebase Hosting is used for deploying web-related components or documentation sites.


### Latest Release

- [RealizeAlpha | Apple App Store](https://testflight.apple.com/join/ARmsGSN8): TestFlight only, production release coming soon.
- [RealizeAlpha | Google Play Store](https://play.google.com/apps/internaltest/4701722902176245187): Internal testing only, production release coming soon.

<!--
## Usage

TODO
-->

## Build

### Dependencies

In order to build and debug locally, you must install the following dependencies:

- Android Studio (for Android deployment)
- XCode (for iOS deployment)
- Flutter SDK
- VS Code
- Dart & Flutter VS Code extensions

To ensure your installation was successful, run this command: 
```
flutter doctor -v
```

Once you see a "No issues found!" message, you are ready to start running the application.  

## Run & Debug

In VS Code, ```F5``` key, the ```Run``` icon, or from the ```Run``` menu to start debugging.
If prompted choose the ```Flutter``` configuration.

### Android Device

1. Enable USB debugging on your Android device.
2. Plug in your device. 
3. Open the command palette (```Ctrl+Shift+P```) and enter ```Flutter: Select Device```  
Or  
Navigate to the project directory and run the flutter command.
    ```bash
    flutter run
    ```

#### Debugging Notes

##### Wireless debugging

- On device, open Settings > System > Developer options.
    - Enable USB debugging & Wireless debugging.
- Connect device to computer over USB. Accept pairing notification on device.
- Open Android Studio > Tools > Device Manager and pair device.
- Run these commands to connect wirelessly:
    ```bash
    $ ${HOME}/AppData/Local/Android/Sdk/platform-tools/adb tcpip 5555
    restarting in TCP mode port: 5555
    $ ${HOME}/AppData/Local/Android/Sdk/platform-tools/adb connect 192.168.86.36
    connected to 192.168.86.36:5555
    ```
- Unplug device and start debugging.

### iOS Device

1. Enable developer on your iOS device.
2. Open ```Devices and Simulators``` window in XCode and ensure that your device is paired and connected. 
3. Open the command palette (```Ctrl+Shift+P```) and enter ```Flutter: Select Device```  
Or  
Navigate to the project directory and run the flutter command.
    ```bash
    flutter run --release
    ```

**Debugging Notes**
- For error `Exception: Error running pod install`, run the following commands:
    ```bash
    rm -rf ./ios/Pods;rm ./ios/Podfile.lock;flutter clean;flutter pub get
    flutter build ios
    # or flutter run
    ```

    If that doesn't work try a pod repo update.
    ```bash
    cd ios
    pod repo update
    flutter build ios
    ```

    If that doesn't work try a `pod update` in `ios`.
    Then in Xcode clean build folder, and build again.

### Web

Select a browser from the device selector. *Note that this is not working due to CORS.*

### Emulator 

Select a mobile emulator from the device selector. *Note that this is not working due to ?*

## Install

### Device

1. Connect your Android device to your computer with a USB cable.
2. Navigate to the project directory and run the flutter command.
    ```bash
    flutter install
    ```

    The response should contain the following status message.

    ```bash
    Installing app.apk to Pixel 5...
    Uninstalling old version...
    Installing build\app\outputs\flutter-apk\app.apk...                 5.2s
    ```

## Maintain

### Upgrade dependencies

#### Flutter upgrades

To ensure you are using the latest packages, run these commands to check and upgrade them: 
```bash
flutter pub outdated
flutter pub upgrade --major-versions
flutter pub upgrade --tighten
```

#### Firebase upgrades

Run these commands in both `functions` and `firebase` folders for Firebase function deployment and running admin tools respectively.
```bash
npm install -g npm-check-updates
ncu -u
npm install
```

### Generate App Icons & Launch Images

1. Replace src/robinhood_options_mobile/icon.png with latest icon PNG image at the maximum possible resolution (1024x1024?).
2. Run `dart run flutter_launcher_icons` in the project directory to generate all icons for iOS and Android.
3. Run `dart run flutter_native_splash:create` in the project directoru to generate all splash screens for iOS, Android and Web.

### Linting (javascript & typescript)

To fix issues with code formatting such as:
> 10 errors and 0 warnings potentially fixable with the `--fix` option.
> Error: functions predeploy error: Command terminated with non-zero exit code 1

Run the following command in the `functions` directory.

```bash
npm run lint -- --fix
```

_You can do this automatically in VS Code by installing the eslint plugin._

### Manage Firebase Auth Claims

#### Change a user role to admin

- Download Service Account private key from [https://console.firebase.google.com/project/realizealpha/settings/serviceaccounts/adminsdk](https://console.firebase.google.com/project/realizealpha/settings/serviceaccounts/adminsdk)
- Open `src/firebase-admin.js` Node.js file.
    - Change the path of the downloaded file at the following line: `var serviceAccount = require("/Users/aymericgrassart/Downloads/realizealpha-firebase-adminsdk-uzw9z-7a694c5249.json");`
    - Change the id of the user that you want to add the role to at the following line.
        ```js
        admin.credential.setCustomUserClaims('exKIqutDIgWmPs6FDXEWMHJYdam1', {
            role: 'admin'
        });
        ```
- Save and execute the Node.js script from the src folder.
    ```bash
    node firebase-admin.js
    ```

## Publish

### Firebase Hosting

`firebase.json` was changed to modify the `hosting` property `"source": "."` to `"public": "build/web"` in order to deploy custom builds.

```bash
#flutter build web --web-renderer html
flutter build web --release
firebase deploy --only hosting
```

Previously, the public folder was deployed with this configuration:
```json
{
  "hosting": {
    "public": "public",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ]
  }
}
```

### Firebase Functions

Functions will automatically deploy with hosting deployments with `firebase deploy`. To deploy only the functions, use the following command.

```bash
firebase deploy --only functions
```

The following secrets should be configured to prevent storing sensitive passwords and tokens in source control.

```bash
# Change the value of an existing secret
firebase functions:secrets:set GEMINI_API_KEY
# View the value of a secret
firebase functions:secrets:access GEMINI_API_KEY
```

### Firebase Firestore

To deploy the Firestore rules and indexes, use the following command.

```bash
firebase deploy --only firestore
```

To export the current Firestore indexes to the local files, use the following command.

```bash
firebase firestore:indexes > ./firebase/firestore.indexes.json
# firebase firestore:indexes --export
#firebase firestore:rules > ./firebase/firestore.rules
```

### Android Play Store

#### Build app bundle

```bash
flutter build appbundle --release
```

#### Generate APKs

This command generates an .apk file used to publish an installation file.

```bash
flutter build apk --release
```

### Apple App Store

#### Build IPA

```bash
flutter build ipa --release
```

If you get an error, see Debugging Notes section above to clean the project.

#### Upload to App Store

1. Install [Transporter App](https://apps.apple.com/us/app/transporter/id1450874784)
2. Add ipa file from `./build/ios/ipa/`
3. `Verify` and `Deliver`

## Test

```bash
flutter test
```

## Future Enhancements

This project is actively evolving. For a comprehensive roadmap of planned features and enhancements, see [ROADMAP.md](ROADMAP.md).

Key areas of planned development include:
- **Investor Groups**: Enhanced collaboration features, advanced permissions, group analytics
- **Trade Signals & AI**: Portfolio-wide analysis, custom agent training, ML model optimization
- **Social & Community**: User profiles, leaderboards, strategy templates
- **Portfolio Management**: Multi-broker support, asset allocation tools, tax optimization
- **Advanced Analytics**: Custom dashboards, backtesting engine, performance attribution
- **Education**: Interactive tutorials, glossary, strategy guides
- **Mobile Experience**: Widgets, shortcuts, offline mode, tablet optimization

See the [full documentation](docs/index.md) for detailed descriptions of each planned enhancement.

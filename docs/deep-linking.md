# Deep Linking & Referrals

RealizeAlpha supports deep linking for seamless navigation from external sources (emails, messages, web) directly into specific app content. It also includes a referral tracking system to reward users for inviting others.

## Supported Protocols

### 1. Custom URL Scheme
The app responds to the `realizealpha://` custom scheme. This is the most reliable way to trigger the app from non-browser environments.

### 2. Universal Links (iOS) & App Links (Android)
The app is configured to intercept standard HTTPS links for the following domains:
- `https://realizealpha.com`
- `https://realizealpha.web.app`
- `https://realizealpha.firebaseapp.com`

## Supported Routes

The following paths are supported across both custom schemes and universal links:

| Target | Path / Format | Example |
|---|---|---|
| **Instrument Ticker** | `/instrument/{symbol}` | `realizealpha://instrument/AAPL` |
| **Referral Code** | `/?ref={id}` | `https://realizealpha.com/?ref=USER123` |
| **Investor Group** | `/investors?groupId={id}` | `https://realizealpha.com/investors?groupId=...` |
| **Watchlists** | `/watchlist` | `realizealpha://watchlist` |
| **Group Watchlist**| `/group-watchlist?groupId={id}&watchlistId={id}` | `realizealpha://group-watchlist?groupId=...` |
| **Trade Signals** | `/signals` | `realizealpha://signals` |

## Sharing Functionality

The app now supports easy sharing of key elements with deep link integration:
- **Instrument Sharing:** Tap the share icon on any instrument page to generate a deep link (e.g., `realizealpha://instrument/AAPL`) that others can use to view the asset.
- **Referral Sharing:** Generate personalized referral codes and share them via system dialogs. These links automatically capture and persist referral attribution on the new user's device.

## Referral System

Any supported link can include a referral code using the `ref` query parameter.

**Example:** `https://realizealpha.com/instrument/TSLA?ref=USERNAME_OR_ID`

### How it works:
1. **Detection:** When a user opens a link containing a `ref` parameter, the app captures the code.
2. **Persistence:** The referral code is saved locally in `SharedPreferences`.
3. **Attribution:**
   - If the user is already logged in, their `User` document in Firestore is updated immediately.
   - If the user is not logged in, the code remains cached and is applied to their account as soon as they sign in or create an account.
4. **Display:** Users can find their own referral link and share it from the **User Profile** screen.

## Implementation Details

### Manual Routing
Native auto-routing is disabled (`FlutterDeepLinkingEnabled: false`) to prevent conflicts. All routing logic is managed manually in `src/robinhood_options_mobile/lib/widgets/navigation_widget.dart` via the `app_links` package.

### Security & Robustness
- **Duplicate Prevention:** The app includes a 1-second debounce mechanism to prevent double-navigation from duplicate system events.
- **Biometric Integration:** Deep links that require authentication will prompt for biometrics (if enabled) before navigating to the content.
- **Login Callbacks:** The app handles redirects for third-party brokerage logins (e.g., Schwab, Robinhood) using the `investing-mobile://` scheme.

## Platform Configuration

### Android
Managed in `AndroidManifest.xml` via `<intent-filter>` blocks.

### iOS
- **Info.plist:** Custom schemes registered under `CFBundleURLTypes`.
- **Runner.entitlements:** Associated domains configured for `applinks:realizealpha.com`, etc.
- ** apple-app-site-association:** Hosted at `/.well-known/apple-app-site-association` on the web domains.

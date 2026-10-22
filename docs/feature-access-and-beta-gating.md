# Feature Access & Beta Rollout Architecture (Beta Labs)

This document details the feature flag gating and user self-serve beta opt-in ("Beta Labs") architecture implemented for the **Signals-First MVP Scope** (tracking [GitHub Issue #239](https://github.com/CIInc/robinhood-options-mobile/issues/239)).

---

## 1. Overview & Goals

As Robinhood Options Mobile scales towards app store releases and broad public distribution, complex features (such as autonomous agentic order execution, social copy trading, AI assistant dialogues, multi-leg spreads, and alternative brokerage bridges) must be strictly decoupled from the core "Signals-First" baseline.

The core public MVP focus comprises:
* **Real-time Trade Signals** (breakout, moving average crossovers, volatility spikes, and RSI signals).
* **Core Single-Account Portfolio & Watchlist tracking**.
* **Essential Order History & Search**.

All non-core or high-liability features are partitioned into **Feature Bundles** controlled by Firebase Remote Config and surfaced through the in-app **Beta Labs** dashboard. When a user is signed in, preferences are synchronized across local `SharedPreferences`, the in-memory `User`, and the Firestore user document.

---

## 2. Feature Access Resolution

`FeatureAccessService.isFeatureEnabled` applies these checks in order:

1. **Global disable:** Remote Config mode `disabled` denies access to everyone, including admins.
2. **Explicit user flag:** A boolean in `User.featureFlags` overrides rollout defaults and role checks. This permits an explicit Firestore grant or denial, except when the global disable switch is active.
3. **Admin-only mode:** Non-admin users are denied unless an explicit user flag grants access. Admins still need to opt in locally when no explicit user flag is set.
4. **Public mode:** Enabled by default; a local user opt-out disables it unless an explicit Firestore flag overrides that preference.
5. **Beta opt-in mode:** Requires a local opt-in. The `beta_self_opt_in_enabled` master switch blocks opt-ins for non-admins when disabled; admins can still opt in.

Users manage local opt-ins and public-mode opt-outs in **Beta Labs** (`UserWidget` -> **Profile & Community** -> **Beta Labs**). Changes update local `SharedPreferences` and the in-memory `User` immediately, and synchronize to the Firestore user document when one is available.

---

## 3. Remote Config Parameters & Default Rollouts

| Parameter Key | Bundle Identifier | Default Remote Value | Scope & Functionality |
| :--- | :--- | :--- | :--- |
| `beta_self_opt_in_enabled` | *Master Switch* | `true` | Master kill-switch controlling whether user self-serve opt-in is allowed. |
| `beta_advanced_research` | `FeatureBundle.advancedResearch` | `betaOptIn` | Options flow, GEX charts, stock screeners, and SEC filings research. |
| `beta_ai_research` | `FeatureBundle.aiResearch` | `betaOptIn` | Market Assistant Copilot, macro sentiment analyzers, AI trade coaches, and Investment Profile settings. |
| `beta_advanced_trading` | `FeatureBundle.advancedTrading` | `betaOptIn` | Multi-leg spread builder, complex option strategy templates, and combo orders. |
| `beta_backtesting` | `FeatureBundle.backtesting` | `betaOptIn` | Historical strategy backtesting, performance analytics, and simulation. |
| `beta_risk_guardrails` | `FeatureBundle.riskGuardrails` | `betaOptIn` | Autonomous account loss limits, peak-to-trough drawdown protection, rapid-cancel loop detection, and tilt cooling-off locks. |
| `beta_automated_trading` | `FeatureBundle.automatedTrading` | `betaOptIn` | Automated order execution and algorithmic trading strategies. |
| `beta_social_copy` | `FeatureBundle.socialCopy` | `betaOptIn` | Investor discovery, shared trade logs, discussion threads, copy trading, and Portfolio & Social Privacy settings. |
| `beta_account_tools` | `FeatureBundle.accountTools` | `betaOptIn` | Wash sale tracking, tax lot optimization, and retirement planning tools. |
| `beta_extended_brokerages` | `FeatureBundle.extendedBrokerages` | `betaOptIn` | Alternative brokerage accounts (Fidelity CSV import, Plaid). **Core platforms (Robinhood, Charles Schwab, Paper Trading, Demo) are never gated.** |

> [!IMPORTANT]
> **Core Brokerage Scope:** **Charles Schwab** and **Paper Trading** are core, production-ready platforms in Robinhood Options Mobile alongside Robinhood and Demo. They are **never** subject to `extendedBrokerages` or beta flags. The `extendedBrokerages` bundle strictly applies to auxiliary or experimental integrations like Fidelity manual CSV imports and Plaid.

Remote config keys accept one of four case-insensitive strings: `disabled`, `adminOnly`, `betaOptIn`, or `public`.

---

## 4. Key Architecture Components

### Enums (`lib/enums.dart`)
* `FeatureRolloutMode`: Enum representing rollout states: `disabled`, `adminOnly`, `betaOptIn`, `public`.
* `FeatureBundle`: Enum representing the 9 partitioned feature groups. Each entry provides:
  * `remoteConfigKey`: Associated Firebase Remote Config string key.
  * `displayName`: Human-readable label displayed in UI.
  * `description`: Explanatory subtitle of the features included in the bundle.

### Remote Config Service (`lib/services/remote_config_service.dart`)
* Loads Remote Config parameter definitions with safe offline fallbacks.
* Exposes `isBetaSelfOptInEnabled` and `getFeatureRollout(key)`.

### Feature Access Service (`lib/services/feature_access_service.dart`)
* Singleton extending `ChangeNotifier` to allow real-time UI rebuilds when flags or opt-in states change.
* Methods:
  * `isFeatureEnabled(bundle, {userRole, user})`: Resolves access using the precedence above.
  * `getRolloutMode(bundle)`: Returns current `FeatureRolloutMode`.
  * `isUserOptedIn(bundle)` / `isUserOptedOut(bundle)`: Checks the in-memory preference cache and local `SharedPreferences`.
  * `setUserPreference(bundle, enabled, {user, userDocRef})`: Updates local preference, the in-memory `User.featureFlags`, and Firestore when supplied.
  * `resetAllOptIns({user, userDocRef})`: Clears local choices and the corresponding in-memory and Firestore flags.
  * `setOverrideMode(bundle, mode)`: In-memory override for automated testing and sandbox previews.

### Beta Labs UI (`lib/widgets/beta_labs_widget.dart`)
* Accessible from User Profile (`UserWidget`).
* Displays Material 3 card list of all 7 bundles with badges (`Public`, `Beta`, `Admin Only`, `Disabled`).
* Provides clear disclosure for high-risk trading features (`FeatureBundle.advancedTrading`) with a confirmation dialog explaining execution risks and liability before toggling on.
* Provides a quick reset action (`resetAllOptIns`) in the top app bar.

---

## 5. UI Gating Touchpoints

### Navigation Shell (`lib/widgets/navigation_widget.dart`)
* **Bottom Navigation Bar**:
  * Default public tabs (4 tabs): **Portfolio**, **History**, **Search**, **Signals**.
  * 5th Tab (**Investors**): Conditionally displayed only when `FeatureAccessService.instance.isFeatureEnabled(FeatureBundle.socialCopy, userRole: userRole)` is `true`.
* **Floating Action Button**:
  * **Market Assistant / AI Research FAB**: Gated behind `FeatureBundle.aiResearch`.

### User Profile (`lib/widgets/user_widget.dart`)
* **Beta Labs Tile**: Added to the **Profile & Community** section with a science flask icon (`Icons.science_outlined`), navigating directly to `BetaLabsWidget`.
* **Feature Tile Gating**: `_buildFeatureTile` checks `FeatureAccessService.instance.isFeatureEnabled(featureBundle, userRole: userRole)`.
  * `Automated Trading`: Gated behind `FeatureBundle.advancedTrading`.
  * `Backtesting`: Gated behind `FeatureBundle.advancedTrading`.

---

## 6. Testing & Quality Assurance

Comprehensive tests verify both unit logic and UI behaviors:
* **`test/feature_access_service_test.dart`**:
  * Global disable (`disabled`) enforcement and explicit user-flag precedence.
  * Admin-only access requires an admin and opt-in unless a user document grants access.
  * `public` rollout mode granting access to all users.
  * Beta opt-in, public opt-out, and master-switch behavior.
  * Preference synchronization across local state, the in-memory user, and Firestore.
* **`test/beta_labs_widget_test.dart`**:
  * Status badge rendering for all bundles.
  * Disclaimer dialog for automated trading confirmation.
  * Reset all opt-ins button functionality.
* **`test/user_widget_features_availability_test.dart`**:
  * Advanced Trading features hidden when user is opted out.
  * Navigation to `BetaLabsWidget` from profile.
  * Admin-only features remain unavailable until an admin opts in or receives an explicit user-document grant.

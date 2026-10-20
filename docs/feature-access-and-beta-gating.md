# Feature Access & Beta Rollout Architecture (Beta Labs)

This document details the feature flag gating and user self-serve beta opt-in ("Beta Labs") architecture implemented for the **Signals-First MVP Scope** (tracking [GitHub Issue #239](https://github.com/CIInc/robinhood-options-mobile/issues/239)).

---

## 1. Overview & Goals

As Robinhood Options Mobile scales towards app store releases and broad public distribution, complex features (such as autonomous agentic order execution, social copy trading, AI assistant dialogues, multi-leg spreads, and alternative brokerage bridges) must be strictly decoupled from the core "Signals-First" baseline.

The core public MVP focus comprises:
* **Real-time Trade Signals** (breakout, moving average crossovers, volatility spikes, and RSI signals).
* **Core Single-Account Portfolio & Watchlist tracking**.
* **Essential Order History & Search**.

All non-core or high-liability features are partitioned into **Feature Bundles** controlled by Firebase Remote Config and surfaced to experimental users through the in-app **Beta Labs** dashboard.

---

## 2. Four-Tier Access Waterfall

Each feature check follows a deterministic 4-tier resolution hierarchy within `FeatureAccessService.isFeatureEnabled(FeatureBundle bundle, {UserRole? userRole})`:

```
                       [ Feature Check Requested ]
                                    |
                                    v
                         Is userRole == Admin?
                              /          \
                         (Yes)            (No)
                            /                \
                 [ Access GRANTED ]      Is Remote Config
                  (Instant Bypass)       mode == 'disabled'?
                                            /           \
                                       (Yes)             (No)
                                          /                 \
                               [ Access DENIED ]       Is Remote Config
                              (Remote Kill Switch)     mode == 'public'?
                                                          /          \
                                                     (Yes)            (No)
                                                        /                \
                                             [ Access GRANTED ]    Is Remote Config
                                               (GA / Full Rollout) mode == 'betaOptIn'?
                                                                      /          \
                                                                 (Yes)            (No)
                                                                    /                \
                                                     Is global opt-in enabled    [ Access DENIED ]
                                                     AND user opted in locally?
                                                            /          \
                                                       (Yes)            (No)
                                                          /                \
                                               [ Access GRANTED ]     [ Access DENIED ]
```

1. **Tier 1: Admin Bypass**: Internal team members with `UserRole.admin` have immediate access regardless of remote flags or local toggle states.
2. **Tier 2: Global Remote Kill Switch (`disabled`)**: If Firebase Remote Config marks a bundle as `disabled`, access is immediately revoked for all non-admin users, overriding any local user opt-in.
3. **Tier 3: GA / Public (`public`)**: Bundles graduated to general availability are enabled for all users without requiring opt-in.
4. **Tier 4: Self-Serve Beta Opt-In (`betaOptIn`)**: Users can self-opt into features via **Beta Labs** (`UserWidget` -> **Profile & Community** -> **Beta Labs**), provided the global kill switch `beta_self_opt_in_enabled` is `true`. Choices persist locally in `SharedPreferences`.

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
  * `isFeatureEnabled(bundle, {userRole})`: Resolves access according to the 4-tier waterfall.
  * `getRolloutMode(bundle)`: Returns current `FeatureRolloutMode`.
  * `isUserOptedIn(bundle)`: Checks local `SharedPreferences` toggle.
  * `setUserOptIn(bundle, enabled)`: Sets local preference and notifies listeners.
  * `resetAllOptIns()`: Resets all preferences back to default (`false`).
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
  * Admin bypass validation across all rollout modes.
  * Remote kill switch (`disabled`) enforcement even if local opt-in is active.
  * `public` rollout mode granting access to all users.
  * User opt-in and opt-out toggle behavior.
  * Master switch `beta_self_opt_in_enabled = false` preventing opt-in.
  * In-memory overrides and reset actions.
* **`test/beta_labs_widget_test.dart`**:
  * Status badge rendering for all bundles.
  * Disclaimer dialog for automated trading confirmation.
  * Reset all opt-ins button functionality.
* **`test/user_widget_features_availability_test.dart`**:
  * Advanced Trading features hidden when user is opted out.
  * Navigation to `BetaLabsWidget` from profile.
  * Admin role seeing gated features regardless of opt-in.

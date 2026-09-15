# Multi-Account, Retirement & Connected Agents

## Overview

RealizeAlpha provides complete multi-account architecture and native retirement portfolio management. Users can seamlessly toggle between taxable individual margin/cash brokerage accounts and tax-advantaged Traditional/Roth IRAs, track annual IRS contribution limits with Robinhood Gold match calculations (`/retirement/history/`), monitor spending/cash accounts (`/rhy/accounts/`), inspect and revoke external trading agents and OAuth2 integrations (`/oauth2/list_external_tokens/`), and stay informed with the in-app notification center (`/midlands/notifications/stack/`, `/inbox/threads/`).

---

## Key Capabilities

### 1. Traditional & Roth IRA Account Architecture
- **Account Type Classification:** Strict discrimination of `brokerage_account_type` (`individual`, `ira_traditional`, `ira_roth`) in `Account` and `UnifiedAccount` models.
- **Enforced Margin Restrictions:** Automated enforcement of IRS and regulatory margin rules — IRAs are strictly non-margin (`isMarginAccount = false`) even if underlying Robinhood payloads specify margin borrowing capacity.
- **Multi-Account Selector:** Header dropdown in `SliverAppBarWidget` with custom savings icons (`Icons.savings_outlined`) and distinct badges for `Roth IRA` and `Traditional IRA`.
- **Filtered Account Stores:** Dedicated getters on `AccountStore` (`store.brokerageAccounts` and `store.retirementAccounts`) for clean separation in UI and metrics aggregators.

### 2. Retirement Contributions & IRS Limits
- **Annual IRS Limit Tracking:** Built-in IRS contribution limits across tax years ($7,000 baseline for 2024–2026, $8,000 for age 50+ catch-up).
- **Interactive Catch-Up Toggle:** Dynamic switch in `RetirementWidget` toggling standard vs. age 50+ catch-up limits with instant recalculation of remaining headroom and percentage maxed.
- **Robinhood Retirement Match:** Real-time tracking of bonus match payments (e.g. Robinhood Gold 3% match and standard 1% match) credited directly to the IRA balance.
- **Multi-Year History Ledger:** Chronological ledger of tax year contributions, match amounts, and progress bars.
- **IRS Regulatory Disclosures:** Clear guidance on April 15 tax deadlines, combined annual limit rules across Traditional and Roth accounts, and early withdrawal tax penalties.

### 3. Connected External Agents & OAuth Tokens
- **Connected Applications Directory:** Complete inventory of third-party applications, automation scripts, and autonomous AI trading agents authenticated via OAuth2.
- **Token Permission Scopes:** Granular visibility into approved OAuth scopes (`internal`, `read`, `write`, `trade`).
- **Lifecycle & Expiration Tracking:** Badges displaying active or expired status with formatted creation and expiration dates.
- **One-Tap Token Revocation:** Interactive confirmation dialog allowing users to instantly revoke OAuth2 tokens (`/oauth2/revoke_token/`) directly from the mobile UI.

### 4. Midlands Notification Center & Inbox Threads
- **Real-World Inbox Threads Integration:** Full integration of Robinhood's `/inbox/threads/` schema alongside `/midlands/notifications/stack/`. Supports real thread attributes: `short_display_name`, `avatar_color`, `is_critical`, `preview_text`, `rich_text`, `action`, and interactive `responses`.
- **Intelligent Auto-Categorization:** Heuristics classify threads into `Orders`, `Options`, `Crypto`, `Futures`, `Dividends`, `IPO Access`, `Announcements`, and `Security`.
- **Custom Asset Avatars:** Dynamic avatar badges displaying ticker or short code (e.g., `DOGE`, `BTC`, `/M2K`, `BAC`, `IPOA`, `!`) with authentic hex background colors from the Robinhood API.
- **Critical Notice Priority Banners:** Prominent warning styling and priority sorting for trade confirmations and security notices.
- **Real-Time Search & Unread Filters:** Multi-field search filtering on title, message, symbols, and action links, plus an unread-only toggle switch.
- **Deep-Link Routing & Interactive Response Chips:** Automatic handling for `robinhood://orders`, `robinhood://lists`, `robinhood://dividends`, `robinhood://instrument`, `robinhood://trusted_devices`, and quick response prompt chips (e.g. *"Can I see more details? 🤓"*, *"I'd like to place a new order. 😎"*).

---

## Architecture & Data Flow

```
Robinhood / Brokerage APIs
  ├── /accounts/
  ├── /phoenix/accounts/unified
  ├── /retirement/history/
  ├── /rhy/accounts/
  ├── /oauth2/list_external_tokens/
  ├── /oauth2/revoke_token/
  ├── /midlands/notifications/stack/
  └── /inbox/threads/
            │
            ▼
IBrokerageService
  ├── getAccounts()               ──► List<Account>
  ├── getRetirementHistoryModel() ──► RetirementHistory
  ├── getSpendingAccountModel()   ──► SpendingAccount?
  ├── getExternalTokensModel()    ──► List<ExternalToken>
  ├── revokeExternalToken()       ──► Future<bool>
  ├── getNotificationStackModel() ──► List<NotificationItem>
  └── getInboxThreadsModel()      ──► List<NotificationItem>
            │
            ▼
UI Dashboards & Widgets
  ├── SliverAppBarWidget (Multi-account switcher with IRA tags & savings icons)
  ├── RetirementWidget (Contribution progress, IRS limits, match tracker, history)
  ├── ConnectedAgentsWidget (Connected apps, permissions, revoke access)
  ├── NotificationCenterWidget (Category chips, stack cards, announcements)
  └── UserWidget (Settings entry points under Banking & Documents)
```

---

## UI Components & Navigation

### `RetirementWidget` (`lib/widgets/retirement_widget.dart`)
- Accessible from `UserWidget` under "Banking & Documents" -> "Retirement & IRA".
- Shows account overview hero card with tax-advantaged badge.
- Current tax year linear progress bar with percentage maxed and remaining headroom.
- Age 50+ catch-up limit toggle switch.
- Lifetime total contributions and match earnings cards.
- Historical contribution cards by tax year with match details.

### `ConnectedAgentsWidget` (`lib/widgets/connected_agents_widget.dart`)
- Accessible from `UserWidget` under "Banking & Documents" -> "Connected Agents & Apps".
- **Overview & Security Header:** Active connections indicator, 3-metric breakdown (AI Agents, Linked Hubs, Direct Apps), and collapsible Security & Delegated Authority Guidance.
- **Dynamic Search & Multi-Category Filtering:** Instant search by application name, client ID, agent ID, or account number; category filter chips for `All`, `AI Agents`, `Linked Services`, and `Direct Apps`, plus `Active Only` filter.
- **Sorting & View Mode Controls:**
  - Sorting: Recently Active, First Authorized, Alphabetical (A-Z), and Category (AI Agents First).
  - View modes: Rich detailed cards and space-efficient compact list tiles.
- **AI Agent Execution Highlighting:** Purple gradient branding (`Icons.psychology`), Agent ID copy-to-clipboard, authorized account pills, and autonomous trade execution indicator.
- **Integration Inspection Bottom Sheet:** Detailed slide-up modal with granted scopes breakdown (plain English descriptions), cryptographic identifiers with one-tap copy, connection lifecycle timestamps, technical JSON payload viewer, and prominent revocation button.
- **Safety Revocation Dialog:** Danger-themed confirmation prompt showing Token ID and Agent ID before terminating delegated access.

### `NotificationCenterWidget` (`lib/widgets/notification_center_widget.dart`)
- Accessible from `UserWidget` under "Banking & Documents" -> "Notification Center".
- **Dynamic Search Bar:** Filter notifications in real time across symbols, titles, message body, and actions.
- **Multi-Category Filter Chips:** Horizontal scrolling filter bar with live item counts for `All`, `Orders`, `Options`, `Crypto`, `Futures`, `Dividends`, `IPO Access`, `Announcements`, and `Security`.
- **Status & Toggles Bar:** Shows unread badge count, "Unread only" filter toggle, and "Mark all read" button.
- **Card Aesthetics:** Color-matched circular avatars displaying instrument symbols (e.g. `DOGE`, `BTC`, `/M2K`, `BAC`, `IPOA`), critical priority warning banners, bold unread dots, and relative timestamps (e.g. `Just now`, `2h ago`, `Yesterday`).
- **Interactive Action Buttons & Deep Linking:** Direct triggers for order details (`robinhood://orders`), watchlists (`robinhood://lists`), dividend summaries (`robinhood://dividends`), stock views (`robinhood://instrument`), and device security (`robinhood://trusted_devices`).
- **Interactive Prompt Responses:** Tappable response chips directly from thread notifications with instant user feedback.
- **Expandable Messages:** Automatic "Show more" / "Show less" toggle for lengthy announcement texts.

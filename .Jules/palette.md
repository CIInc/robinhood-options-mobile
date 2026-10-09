## 2026-03-31 - Accessibility for Custom Gesture-Based Controls in Flutter
**Learning:** Custom drag-and-gesture components (such as `SlideToConfirm`) are completely inaccessible to screen reader users (VoiceOver/TalkBack) unless explicitly wrapped in a `Semantics` container with `button: true` and an explicit `onTap` handler. `ExcludeSemantics` on inner textual children prevents duplicate screen reader announcements.
**Action:** Always wrap custom gesture components with `Semantics(container: true, button: true, label: ..., hint: ..., onTap: ...)` and `ExcludeSemantics` on redundant child text nodes so screen readers can trigger actions via tap gestures.

## 2026-04-01 - Screen Reader Accessibility for Visual-Only Financial Badges
**Learning:** Visual color cues (green/red) on financial badges (`PnlBadge`) are inaccessible to screen reader users who cannot perceive color-coded profits or losses. Wrapping financial badges in `Semantics(container: true, excludeSemantics: true, label: ...)` and prefixing text with explicit context ("Profit: ...", "Loss: ...", or "Neutral") ensures unambiguous screen reader announcements without changing visual styling.
**Action:** Always wrap visual financial indicators/badges with explicit semantic labels describing financial direction (profit/loss/neutral) based on numerical values or signs.

## 2026-04-03 - Unified Semantics for Watchlist Grid Cards
**Learning:** Complex financial grid items (`WatchlistGridItemWidget`) containing disjointed elements (symbols, visual trend icons, percentage change numbers, and company names) cause fragmented screen reader navigation. Wrapping the card in `Semantics(container: true, button: true, label: ..., excludeSemantics: true)` provides a cohesive screen reader summary (e.g., "AAPL, up 2.50%, Apple Inc.") and prevents screen readers from stopping on unlabelled trend icons.
**Action:** Wrap composite financial cards/tiles in `Semantics(container: true, button: true, label: ..., excludeSemantics: true)` to announce symbol, movement direction, and description as a single interactive action item.

## 2026-04-05 - Semantics for Dual-Action AppBar Status Badges
**Learning:** Composite status badges embedded in AppBars (`AutoTradeStatusBadgeWidget`) that respond to both single taps (opening settings) and long presses (emergency stop menu) are read as disjointed strings (e.g., "AUTO ON", "2:05") by screen readers unless explicitly wrapped in `Semantics(button: true, label: ..., hint: ..., excludeSemantics: true)`. Explicating the status label and gesture hints ensures screen reader users understand both tap and long-press capabilities.
**Action:** Wrap dual-action AppBar badges in `Semantics(button: true, label: ..., hint: ..., excludeSemantics: true)` to announce the badge status clearly and explain available gestures.

## 2026-04-06 - Accessibility for Interactive Poll Widgets and Segmented Distribution Bars
**Learning:** Visual-only segmented distribution bars (e.g., sentiment polls) and custom option button tiles in community widgets lack screen reader context unless explicitly wrapped in `Semantics`. Providing a summary label on the segmented bar (`Sentiment poll breakdown: ...`) and setting `button: true`, `selected: isSelected`, `enabled`, and explicit `hint`s on option tiles allows screen reader users to understand both poll results and voting capabilities.
**Action:** Wrap segmented progress/distribution bars in `Semantics(container: true, excludeSemantics: true, label: ...)` with percentage breakdowns, and wrap option tiles with `Semantics(button: true, selected: ..., hint: ...)`.

## 2026-04-07 - Accessibility for Inline Counter Action Buttons in Social Items
**Learning:** Interactive counter buttons (such as upvote/like controls in comment cards) consisting of an icon and count string are read as raw, isolated numbers by screen readers unless wrapped in `Semantics`. Explicitly setting `button: true`, `selected: isLiked`, `enabled`, `label: '$count upvotes'`, `hint`, and `excludeSemantics: true` ensures screen readers announce both the count and state while offering clear gesture guidance.
**Action:** Wrap inline counter buttons in `Semantics(button: true, selected: ..., enabled: ..., label: '$count ...', hint: ..., excludeSemantics: true)` to unify icon and count string into an explicit, state-aware button action.

## 2026-04-08 - Live Region & Unified Key-Value Semantics for Order Preview Cards
**Learning:** Pre-trade warning and rejection alert cards in order verification widgets (e.g., `SchwabOrderPreviewCard`) are missed by screen reader users when updated dynamically unless wrapped in `Semantics(container: true, liveRegion: true, excludeSemantics: true, label: ...)` to announce order rejections immediately. Furthermore, separate key-value row texts ("Estimated Commission", "$0.00") force double swipe stops on screen readers unless merged using `Semantics(container: true, excludeSemantics: true, label: '$label: $value')`.
**Action:** Wrap dynamic pre-trade validation alert boxes in `Semantics(liveRegion: true, excludeSemantics: true)` and key-value financial pairs in `Semantics(container: true, excludeSemantics: true, label: '$label: $value')`.

## 2026-04-09 - Unified Screen Reader Semantics for Option Flow Cards
**Learning:** Complex option flow list cards (`OptionFlowListItem`) containing fragmented statistics (sentiment icons, scores, contract expiration/strike, moneyness, volume/OI ratios, and detection flags) cause screen readers to stop dozens of times per item. Wrapping the card in `Semantics(container: true, button: true, label: ..., excludeSemantics: true)` unifies the entire trade flow entry into a single comprehensive, actionable screen reader announcement.
**Action:** Wrap dense financial flow list cards in `Semantics(container: true, button: true, label: ..., excludeSemantics: true)` combining symbol, sentiment, premium, contract terms, moneyness, and flags.

## 2026-04-10 - Unified Screen Reader Semantics for Social User List Tiles
**Learning:** Social user list tiles (`UserListTile`) containing multi-part profile information (avatar, name, email/location, follower count with people icon, and reputation badge with tier icon) cause screen readers to stop 6–8 times per user entry. Wrapping the tile in `Semantics(container: true, button: showNavigation, label: ..., excludeSemantics: true)` consolidates profile details into a single cohesive announcement (e.g., "Jane Trader, New York, 5 followers, Novice Trader") and prevents screen readers from stalling on unlabelled decorative icons.
**Action:** Wrap social profile tiles in `Semantics(container: true, button: showNavigation, label: ..., excludeSemantics: true)` combining trader name, location/email, follower count, and reputation tier.

## 2026-04-11 - Unified Screen Reader Semantics for Market Sentiment Summary Cards
**Learning:** Interactive market overview cards (`MarketSentimentCardWidget`) containing multi-part information (custom-painted gauge arc, numeric score, uppercase sentiment badge, timestamp, summary text, and trailing chevron) cause screen readers to stop multiple times on disjointed visual nodes or ignore visual gauge graphics completely. Wrapping the interactive card in `Semantics(container: true, button: true, label: ..., hint: ..., excludeSemantics: true)` consolidates all market sentiment data into a single, cohesive, actionable screen reader announcement and prevents screen readers from stopping on unlabelled icon nodes or canvas graphics.
**Action:** Wrap interactive multi-node summary/dashboard cards in `Semantics(container: true, button: true, label: ..., hint: ..., excludeSemantics: true)` combining sentiment label, score, timestamp, and summary.

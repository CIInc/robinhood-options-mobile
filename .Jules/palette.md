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

## 2026-04-08 - Accessibility and Live Regions for Pre-Trade Order Validation Banners
**Learning:** Pre-trade validation feedback cards (such as Schwab order rejections and warnings) containing icons and list items can leave screen reader users unaware of dynamic validation status changes unless explicitly wrapped in `Semantics` with `container: true`, `liveRegion: true`, and `excludeSemantics: true`. Combining messages into a structured summary label ensures screen readers immediately announce critical order validation alerts when rendered without repeating nested text nodes.
**Action:** Always wrap dynamic order validation/error/warning banners in `Semantics(container: true, liveRegion: true, excludeSemantics: true, label: ...)` to immediately notify screen readers of critical status updates.

## 2026-03-31 - Accessibility for Custom Gesture-Based Controls in Flutter
**Learning:** Custom drag-and-gesture components (such as `SlideToConfirm`) are completely inaccessible to screen reader users (VoiceOver/TalkBack) unless explicitly wrapped in a `Semantics` container with `button: true` and an explicit `onTap` handler. `ExcludeSemantics` on inner textual children prevents duplicate screen reader announcements.
**Action:** Always wrap custom gesture components with `Semantics(container: true, button: true, label: ..., hint: ..., onTap: ...)` and `ExcludeSemantics` on redundant child text nodes so screen readers can trigger actions via tap gestures.

## 2026-04-01 - Screen Reader Accessibility for Visual-Only Financial Badges
**Learning:** Visual color cues (green/red) on financial badges (`PnlBadge`) are inaccessible to screen reader users who cannot perceive color-coded profits or losses. Wrapping financial badges in `Semantics(container: true, excludeSemantics: true, label: ...)` and prefixing text with explicit context ("Profit: ...", "Loss: ...", or "Neutral") ensures unambiguous screen reader announcements without changing visual styling.
**Action:** Always wrap visual financial indicators/badges with explicit semantic labels describing financial direction (profit/loss/neutral) based on numerical values or signs.

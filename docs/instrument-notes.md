# Personal Instrument Notes

The **Personal Instrument Notes** feature allows users to maintain private, persistent notes for any specific trading instrument (Stock, Option, Crypto, etc.). This acts as a digital trading journal directly integrated into the quote detail view.

![Instrument Notes UI](../src/robinhood_options_mobile/assets/images/notes_preview.png)

## Key Features

### 1. Markdown Support
Notes are not just plain text. The feature supports full **Markdown rendering**, allowing for rich formatting:
- **Headers** for organizing sections.
- **Bold** and *Italics* for emphasis.
- **Bullet points** and **Numbered lists** for key levels or thesis points.
- **Code blocks** for specific values or algorithms.
- **Clickable Links** that open in your external browser.

### 2. AI-Powered Drafting
Struggling to start? The **Draft with AI** feature analyzes the current instrument (symbol) and generates a structured trading note for you.
- **Context Aware:** prompts the AI to focus on recent price action, key levels, and potential catalysts.
- **Formatted:** The AI automatically generates content in Markdown format (using bullet points and bold keys) for immediate readability.

### 3. Smart UI/UX
- **Expandable View:** Long notes are automatically collapsed to save screen space, with a "Show All" toggle.
- **Quick Copy:** A dedicated copy button allows you to instantly export your thesis to other apps.
- **Timestamping:** Every note tracks its last updated time.

## How to Use

1.  **Navigate** to any Instrument Detail page (Stock, Option, etc.).
2.  Scroll to the **My Notes** card.
3.  **Tap** on "Tap to create a personal note..." (or the existing note) to open the editor.
4.  **Edit** your note using the `TextField`.
    *   *Tip:* Use standard Markdown syntax (e.g., `# Title`, `- Item`).
5.  **Actions:**
    *   **Magic Wand Icon:** Generate a draft using AI.
    *   **Checkmark Icon:** Save your changes.
    *   **Trash Icon:** Delete the note permanently.

## Technical Details
- **Storage:** Notes are stored securely in Firestore under `users/{userId}/notes/{symbol}`.
- **Privacy:** Notes are strictly private to the user account.

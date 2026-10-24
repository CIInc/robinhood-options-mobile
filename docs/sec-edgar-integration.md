# SEC EDGAR Disclosures & Financial Statements

The instrument research view (`SecDisclosuresWidget`) provides direct access to
SEC EDGAR regulatory filings, XBRL financial statements, an automated 10-K/10-Q
filing research assistant, and Action Center / Smart Alert integration:

- **Form 4 Insider Trading & Cluster Detection**: Parses open-market purchases
  (`P`) and sales (`S`), reporting owner names, officer titles, net shares
  transacted, net transaction dollar value, and 30-day distinct insider buying
  and selling clusters (`countInsiderBuyCluster`, `countInsiderSellCluster`).
- **Form 8-K Material Event Disclosures**: Extracts deduplicated item codes,
  maps them to human-readable material event descriptions (e.g., `1.01`, `1.03`,
  `2.02`, `3.01`, `4.02`, `5.02`), and classifies event severity (`critical`,
  `warning`, `info`).
- **Form 10-K / 10-Q Periodic Filings & XBRL Financial Statements**: Parses
  recent 10-K and 10-Q submissions for fiscal period, Item 1A Risk Factor
  highlights, and Item 7/2 MD&A highlights (`parse10KOr10QHtml`), and extracts
  structured US-GAAP financial statement metrics from SEC XBRL `companyfacts`
  (`parseCompanyFactsFinancials`): Revenue, YoY Revenue Growth, Net Income, Net
  Margin, Diluted EPS, Operating Income, Operating Cash Flow, Cash &
  Equivalents, Total Assets/Liabilities/Equity, and Liabilities-to-Equity ratio.
- **Form 13F-HR Institutional Holdings**: Searches EDGAR full text for 13F-HR
  information tables reporting the issuer as a holding (`parse13FXml`).
- **Automated 10-K/Q & Filing Research Assistant**: Synthesizes an executive
  filing brief (`buildSecFilingResearchBrief` / callable `analyzeSecFiling` /
  `SecFilingResearchBrief.fromSnapshot`) with overall tone (`bullish`,
  `neutral`, `cautious`, `bearish`), financial highlights, insider & 8-K
  summaries, risk flags, and interactive quick-question analysis (`10-K/10-Q
  Financials`, `Form 4 Insiders`, `8-K Risks & Catalysts`, `13F Ownership`).
- **Action Center & Smart Alerts Integration**: `PortfolioAlertService` surfaces
  Action Center alerts for overlapping portfolio positions on 8-K material
  events, Form 4 insider buy/sell clusters, and 10-K/10-Q filings, and evaluates
  `AlertType.sec_filing` rules (`sec_form4_insider_buy`,
  `sec_form4_insider_sell`, `sec_8k_material_event`, `sec_13f_institutional`,
  `sec_10k_10q_filing`).

## Data and refresh behavior

- The callable `getSecDisclosures` resolves a ticker to its SEC CIK, reads the
  issuer's recent Form 4, 8-K, 10-K, and 10-Q submissions, fetches XBRL
  `companyfacts` financials, searches EDGAR full text for 13F filings, and
  synthesizes a `researchBrief`.
- The callable `analyzeSecFiling` evaluates cached or freshly fetched SEC
  disclosures and XBRL financials to answer targeted filing questions.
- Filing metadata, XBRL financials, and the research brief are cached in
  `sec_disclosures/{symbol}` for 30 minutes. The signed-in user's saved
  positions are read server-side for each call; brokerage credentials and raw
  position data are not sent to the SEC.
- Symbols viewed by users are recorded in `sec_tracked_symbols`. The scheduled
  `refreshTrackedSecDisclosures` function refreshes the ten most recently
  requested symbols hourly.
- EDGAR's 13F reports identify issuers by name. The integration only associates
  a holding when its normalized issuer name matches the SEC company name, so
  name variations may not be recognized.

## Configuration and deployment

Configure `SEC_EDGAR_USER_AGENT` as a Firebase Functions string parameter with
the app name and a monitored contact email, for example:

```dotenv
SEC_EDGAR_USER_AGENT="RealizeAlpha/1.0 (contact: maintainer@example.com)"
```

Use a real monitored address in the local Functions `.env` file or deployment
environment; do not commit it. SEC requests are serialized through a shared
Firestore rate slot at no more than eight requests per second.

Deploy the callables (`getSecDisclosures`, `analyzeSecFiling`) and scheduled
function (`refreshTrackedSecDisclosures`) with the normal Functions deployment
workflow after setting the parameter. No SEC API key is required.

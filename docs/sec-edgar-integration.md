# SEC EDGAR Disclosures

The instrument research view includes SEC-filed insider Form 4 transactions,
institutional 13F holdings, and 8-K material-event disclosures. It highlights
insider purchases by distinct reporting owners across the last 30 days and
shows a portfolio-overlap notice when the displayed symbol has a nonzero
position in the signed-in user's saved stock positions.

## Data and refresh behavior

- The callable `getSecDisclosures` resolves a ticker to its SEC CIK, reads the
  issuer's recent Form 4 and 8-K submissions, and searches EDGAR full text for
  13F filings that report the issuer as a holding.
- Filing metadata is cached in `sec_disclosures/{symbol}` for 30 minutes. The
  signed-in user's saved positions are read server-side for each call; brokerage
  credentials and raw position data are not sent to the SEC.
- Symbols viewed by users are recorded in `sec_tracked_symbols`. The scheduled
  `refreshTrackedSecDisclosures` function refreshes the ten most recently
  requested symbols hourly. The instrument card also loads cached disclosures
  on demand; refreshes are not push notifications.
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

Deploy the callable and scheduled function with the normal Functions deployment
workflow after setting the parameter. No SEC API key is required.

## Scope

This release slice provides research access to 13F, Form 4, and 8-K filings.
Real-time 13F/Form 4 ingestion, automated 8-K event alerts, 10-K/10-Q statement
parsing, and an automated 10-K/Q research assistant remain outside the
delivered scope and are still tracked in
[issue #143](https://github.com/CIInc/robinhood-options-mobile/issues/143).

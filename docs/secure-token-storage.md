# Secure OAuth Token Storage

Brokerage OAuth credentials and MCP access/refresh tokens are stored with
`flutter_secure_storage`, rather than as plaintext in `SharedPreferences` or
Firestore. Brokerage credentials use a random per-account key; the local
preferences cache stores account metadata and that opaque key, never the token
JSON. User documents serialize brokerage metadata without credentials or local
secure-storage keys.

## Migration

On startup, legacy brokerage credentials in the local preferences cache are
written to secure storage before the cache is rewritten without plaintext
credentials. Existing brokerage tokens in a Firestore user document are first
copied to the local secure store and then the document is rewritten without
credentials. MCP tokens are migrated from preferences when the MCP token flow
first reads or authorizes them. If secure storage cannot accept a legacy token,
the migration fails before removing the old local value.

Token refreshes are persisted back to secure storage. Unlinking a brokerage
account deletes its secure-storage entry before removing the account from the
local store. Signing out clears brokerage accounts and tokens before Firebase
sign-out proceeds, including MCP tokens and their connection metadata; a secure
deletion failure cancels sign-out and is surfaced to the user. Disconnecting
MCP uses the same token cleanup.

## Platform and backup behavior

The plugin uses Apple Keychain on iOS and Android's encrypted secure-storage
implementation backed by Android Keystore. Android app backup is disabled
because restored encrypted values may not have the original device's Keystore
keys. Firestore-backed data can be downloaded again after sign-in, but local
preferences are not restored from Android backup and brokerage accounts may
need to be linked again on a replacement device.

The plugin does not enforce a hardware-backed key on every device. Android
hardware backing depends on device support and the platform's key selection;
generic Keychain items are not themselves a guarantee of Secure Enclave
protection. Strict hardware-backed-key enforcement remains open in
[#88](https://github.com/CIInc/robinhood-options-mobile/issues/88). The plugin's
web implementation is experimental and requires a secure HTTPS context; the
native Keychain/Keystore guarantees described above apply to iOS and Android.

# PokePackBar 0.22.0

App PRs #24/#25 and server PR #18 fix card-detail size/position and recurring
sign-outs. Session validity is decided by the server, including loaded/cached
credentials whose originally saved expiry metadata has passed.

## Login policy

- New sessions last 365 days. A valid authenticated request renews to 365 days
  when less than half the lifetime remains, including valid legacy seven-day
  sessions. Renewal is bounded rather than a write on every request.
- Longer-lived bearer sessions stay usable until server expiry or revocation.
  Logout, password change/reset and same-device re-login retain their existing
  revocation behavior. Device/account mismatches and expired/revoked sessions
  are rejected before renewal; expired sessions require login again.
- Busy renewal writes roll back without failing the otherwise valid request;
  the next authenticated request retries renewal.
- Keychain storage remains non-synchronizing and account/device-bound. The
  normal reader remains background/non-interactive. No password is persisted.

## Review and validation

- Add an isolated credential loader and tests for both real loading and cache
  branches. Restoring the old expiry gates makes both assertions fail.
- Focused app suite: 14 passed, including credentials, singular labels and
  six-language release notes. Full local suite: 1025 tests, 9 skipped, zero
  failures; logic-core coverage 88.90% clears the existing 75% gate.
- Server suite: 304 passed; 94 optional pure-rule comparisons are skipped for
  this auth/layout release. Rules/catalogue/prices are unchanged. Runtime code,
  tests, migrations and scripts pass Ruff.
- Server regressions cover legacy renewal, renewal threshold, expired/revoked
  rejection, device/account mismatch and renewal contention rollback/retry.
- Native HTTP audits accept stale saved metadata on a valid session, exercise
  the cache branch and verify authoritative 401 handling after revocation.
  Native auth/state patches, profile/alerts, commerce/counter-offers, opening
  jobs and durable replay also pass. The signed package repeats these checks.
- Korean/English 22-screen popover audits and account layouts pass. Representative
  single-copy/duplicate card details were visually inspected. Fixtures use
  isolated wallets, synthetic login data and no personal Keychain access.
- Packaging/signature gates pass. Stable bundle/signing identity remains
  unchanged; original card scans remain outside the distributed app.
- Fresh production-copy backup: 3 accounts, 3 password identities, 12 sessions
  and 12572 events. All saved account resources/claims validate unchanged.

## Deployment

- Server main candidate: `2ec27c194e9a5d51d349972af8a483b9a3c02faa`.
- Game rules stay at
  `ppb-server-v2/8047628cb035814b0b409a25e476c0a377942bafcd458dcaddc94621df96c540`;
  schema remains `20261015_0009`. No resource migration or price changes.
- Take a fresh stopped-API backup, preserve every existing row/column, then
  start the immutable server release. Session expiry updates after authenticated
  requests are intentional. Keep public signup and current diagnostic/auth gates.
- Preserve current DB writes on code rollback. Restoring an old backup is a
  separate recovery decision and must not discard new user transactions.
- Final main CI, cutover and local install evidence is recorded in the GitHub
  release. The prior local app is backed up and the offline save is preserved.

`PokePackBar.zip` SHA-256:
`37220512fe09657619d8a19c0c584cc71bc130f3c10e7f836842b0fcbf8f6821`.

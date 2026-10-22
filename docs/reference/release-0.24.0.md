# PokePackBar 0.24.0

Persist server sessions in app-local files instead of Keychain. This removes
server-session Keychain access from startup, synchronization, account-window
loading, login saves and logout cleanup. The user approved this storage change
and its reduced protection without paid Apple Developer enrollment.

## Storage and migration

- Use `Application Support/PokePackBar/server-credentials/<storageKey>.json`.
  The key includes server URL, account and device. Keep development app roots
  separate through the existing `AppEnv.supportDirectory` configuration.
- Directory permissions are 0700; session files are 0600 and atomically
  replaced. Files are unencrypted. Other programs running as the same macOS
  user can read the token. No account password is persisted.
- Only the account-window import button or explicit `--import-server-session`
  command may read a legacy Keychain item. The first import may need one macOS
  approval; ordinary file operations never fall back to Keychain.
- Keep legacy items untouched for rollback. Existing file sessions take
  precedence; missing, denied or mismatched imports preserve existing data.
- Logout/password changes retain server revocation and remove only the matching
  local credential file. Old Keychain sessions are never automatically restored.
- Server validation remains authoritative, including stale expiry metadata.
  No gameplay, server login policy, rules, prices or schema changes.

## Verification

- Storage tests cover reload/update/remove, zero automatic Keychain queries,
  permissions, password absence, identity isolation, malformed/mismatched files,
  failed writes and explicit/failed legacy import.
- A deliberately injected invalid Keychain query in file loading makes the
  zero-query test fail (five calls observed instead of zero).
- Focused storage/session/release-note suite: 20 passed. Full local suite:
  1036 tests, 9 skipped, zero failures; logic-core line coverage 88.85%.
- Native HTTP audits load actual isolated credential files and check server
  rejection after revocation. Account snapshots show the explicit import action
  and storage disclosure in Korean and English.
- Both debug and signed-package HTTP audits pass login/revocation, profile/alerts,
  commerce/counter-offers, 1001-pack jobs and durable request replay. Korean and
  English account layouts pass compact/full, light/dark and close/reopen checks.
- Stable-signature packaging passes names, prices, foil and 18,949 original-
  geometry guards. ZIP extraction retains a valid strict signature.
- Final test, package, CI and deployment results are recorded with the release.

## Deployment

- Preserve the existing signing certificate/bundle ID and original offline save.
- Server main/running release remains `2ec27c194e9a5d51d349972af8a483b9a3c02faa`;
  no server migration or restart is needed.
- Fresh production backup: 3 accounts, 3 password identities, 12 sessions and
  12792 events; integrity/foreign-key checks pass. All three saved account states
  retain existing resources and claimed rewards under the unchanged rules.
- Publish the signed ZIP with a matching Homebrew checksum, migrate this Mac's
  existing session without printing its value, then update/relaunch the app.
- A rollback to an older app may require legacy Keychain approval or login.
  Keep current server data; no DB restoration is part of this app-only change.

`PokePackBar.zip` SHA-256:
`6c942a6bcf188feeaa60989c45b630c631e13eb5b76d7e5881dec0f7c167b581`.

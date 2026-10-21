# PokePackBar 0.21.0

App PRs #22/#23 and server PR #17 refresh dex combinations and rewards, restore
fine anniversary glitter, group themes by stars, keep card-detail size stable
with duplicates, and allow multiple card types/quantities in one trade picker.

## Rules and compatibility

- 350 dexes: 223 themes and 127 set dexes, with 58 new combinations. All 292 old
  dex IDs remain. Nine existing non-perk rewards are upgraded.
- Existing permanent-perk allocations are redistributed. Each kind's total
  budget and cap remain unchanged. Existing resources and claims are preserved;
  previously claimed rewards are not automatically granted again.
- Only `dexes`, `ladder` and `rules_version` change in server rules data.
  Pack rules, oracle, base prices and other catalogue fields are unchanged.
- All runtime dex fields and ladder entries match between app and server after
  applying the current Codable fields/defaults. Non-runtime source metadata is
  excluded by that decoder, as before.
- New rules version:
  `ppb-server-v2/8047628cb035814b0b409a25e476c0a377942bafcd458dcaddc94621df96c540`.
- Online devices must update to 0.21.0. The server rejects new game commands
  using old rules; previously committed requests retain their durable replay
  path before rule-version checks. Schema remains `20261015_0009`.

## Validation

- Combined local app suite: 1022 tests, 9 skipped, zero failures. Logic-core
  coverage 88.90% clears the existing 75% gate.
- Server suite: 301 passed. All 94 opt-in Swift/Python differential checks pass.
  Runtime code, tests, migrations and scripts pass Ruff.
- Native HTTP auth/state-patch, profile/notifications, commerce/counter-offer,
  opening-job and durable receipt-replay suites pass on disposable accounts.
  The final signed package repeats those checks successfully.
- Korean/English online layouts, multi-selected picker and all 22 compact
  popover screens pass. Selected screenshots were visually inspected; fixtures
  use isolated synthetic wallets.
- Representative 30th-anniversary renders were compared with signed 0.19.0
  across 36 angles each. The full-art sample matches every pixel; the classic
  sample matches 33 frames and differs by at most 2/255 per channel in three.
  This verifies the fine-glitter regression, not physical factory equivalence.
- Packaging audits for physical packs, prices, labels, geometry and foil pass.
  Original card scans remain excluded; stable signing identity is unchanged.
- Fresh verified production-copy backup: 3 accounts, 3 password identities,
  11 sessions and 10970 game events. All saved account states validate under
  the new rules with resources, coupons, pity and claimed rewards preserved.

## Cutover and rollback

- Server main candidate: `45612f3bf5a94b040f2d01d26f9fe6e0e4fb90ce`.
- Prepare an immutable server release and publish the matching app together.
  Take a second fresh backup while the API is stopped and verify every existing
  row/column before restarting. Keep public signup and current security gates.
- Preserve current DB writes for any code rollback. A backup restore is a
  separately approved recovery operation; do not discard new user transactions.
- Final cutover counts, public CI and local installation checks are recorded
  in the GitHub release after completion.

## Distribution

`PokePackBar.zip` SHA-256:
`33df4761ca9bfb80307e14af79c471395a9c417fcd4485fc4a94f45d8b1728f3`.

The archive passes strict signature verification with the existing stable
bundle identity and certificate. The previous local app is backed up before
Homebrew upgrade; the original offline save is preserved.

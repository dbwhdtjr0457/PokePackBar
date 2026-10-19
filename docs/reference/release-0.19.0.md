# PokePackBar 0.19.0

App PR #20 and server PR #15 add money on one side of card trades and buyer
price offers on player listings. Balances are checked again at acceptance;
money is not held while proposals are pending. Offers expire after 48 hours
or when their listing can no longer fill them. Bot listings retain fixed prices.

Listing details share a draggable, double-sided card view. Card details show
pull odds, market summaries and wishlist controls. Unread notifications appear
as a menu-bar dot; changing accounts relaunches the app into the new account.
Development-app files and settings are isolated from the stable app.

## Review corrections

- Money-bearing trade acceptance must echo the exact displayed amounts under
  the server transaction lock. Legacy apps keep card-only trades and receive a
  conflict before accepting unseen money terms. Both payment directions are
  covered; disabling the guard makes both regression cases fail.
- Wishlist replacement data uses the revision of the profile it came from.
  Concurrent updates now conflict instead of overwriting newer wishes.
- Added acceptance replay and injected partial-settlement rollback tests.

## Validation

- Server suite: 299 passed; runtime, tests, migrations and scripts pass Ruff.
  A whole-tree Ruff scan also finds pre-existing price-tool style warnings in
  unchanged exported data files; these are outside the runtime lint scope.
- All 94 Swift/Python comparison checks pass against the matching rules app.
- Full local app suite before the final wishlist request-builder correction:
  1001 tests, 9 skipped, zero failures; logic-core coverage 88.90% (gate 75%).
- Final focused app suite: 15 passed, including money acceptance requests,
  wishlist revision binding, card source data and six-language release notes.
- Native online suites pass: auth, state patches, jobs, counter-offers,
  market settlement and durable request replay.
- Real HTTP tests with synthetic accounts and Python rules pass: offer
  settlement, exact wallet/card changes, partial stock, concurrent receipt
  replay, offer history/notifications and both trade money directions.
- Korean/French online layouts and 21-screen Korean popover layouts pass.
  Screenshot fixtures use isolated wallets; offline images may show placeholders
  and disabled actions. These are layout checks, not production-account actions.
- Card front/back and angled poses rendered and visually inspected. Low/high
  artwork URLs respond successfully; original artwork remains outside the app.

## Server deployment

- Production main/runtime: `a99ce6e36913963d993902f0d9316cef4ceabe35`.
- Rehearsal and paused-production migrations to `20261015_0009` preserve every
  existing column and row across 26 old tables, including credentials/sessions.
- Fresh cutover backup: 3 accounts, 3 password identities, 10 sessions and
  8999 game events. All account wallet/card/pack/coupon/pity/reward states validate.
- Local readiness and public health return 200. Public diagnostics return 404;
  UUID-only access returns 401. Existing public signup and image CDN remain enabled.
- Private rollback inputs are retained under the service root's
  `rollbacks/20261019-0.19.0`. Preserve current DB writes for any code rollback;
  restore an old DB only as an explicitly approved recovery operation.

## Distribution

- Final packaged app repeats all native online suites successfully and passes
  strict signature verification with the existing stable bundle identity and
  certificate. Original artwork is not bundled.
- `PokePackBar.zip` SHA-256:
  `353a6ec1d5589a949bed47ca0768a6eb189c0d16780b32e51031f0c5be04991e`.
- Public CI and installation results are recorded in the GitHub release after
  publishing. Private wallet files and Keychain credentials are preserved.

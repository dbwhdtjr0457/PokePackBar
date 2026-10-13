# PokePackBar 0.17.0

App PR #18 adds missing-card trade discovery from a friend's spare cards,
the missing-only binder filter, and ownership-independent collection price
ordering. The review adds a private-data epoch so late friend-binder responses
respect logout cache clearing.

Validation:

- 55 targeted app tests pass, covering missing cards across printings, price
  ordering, cache retention on failed refresh, logout during an awaited request,
  remote sessions/state, bulk sales and release notes.
- Removing the logout epoch check makes the new regression fail. After restoring
  it, the targeted suite passes.
- 264 server tests pass (94 optional oracle checks separately enabled).
- All 94 Swift/Python comparison checks pass. The four updated Oripa frozen
  cases now run in ordinary server tests with their pinned catalogue/price data.
- Native authentication/gameplay/commerce/device/job/replay audits pass against
  the prepared server. Korean/French/Spanish online layout audits cover missing
  trade cards, both picker modes and close/reopen; screenshots are isolated fixtures.

Server commit 2c4b9bf updates tests/fixtures only; runtime logic, rules data and
schema remain unchanged. Schema is `20261008_0007`; rules version is
`ppb-server-v2/e835cec930b86e5a50298b384e3c2670a013eef1ca3d020ba38b7da001bdbb2e`.
Existing clients retain API compatibility. Preserve a verified database backup
and prior release/env/plist before API activation. Public signup remains enabled.

The final stable-signed 0.17.0 bundle repeats the three native online suites
and 55 targeted tests. Strict signature verification and all packaging gates
pass, including URL-based artwork separation, source Energy scans, price/foil
resources and bulk-opening responsiveness. ZIP SHA-256:
`cc1b41444f47aa15b7e75bf8bb57598d69b9a8458b2c6bd58a3436f6bcc42a0d`.

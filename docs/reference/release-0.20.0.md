# PokePackBar 0.20.0

App PR #21 refines era-specific foil colors, patterns and coverage, moves nickname
editing to the account Profile tab, and automatically reads related notifications
while the online window is in the foreground. Stored card finishes, prices and
game resources remain unchanged.

## Review corrections

- Parse the server's `{revision, profile}` envelope for nickname loading/saving.
  Preserve all privacy flags and the revision from that same read; malformed
  profile replies cannot silently reset choices.
- Invalidate auto-read visits when focus, visibility, tabs or login state change.
  Recheck the visit after notification reads and between individual mutations.
  Late responses cannot refill cleared account caches.
- Split a new squiggle Canvas expression and explicitly type its calculations
  for the shipping Swift 6.2.4 compiler. Rendering math is unchanged.
- Regression tests use the production nickname request builder and auto-read
  sending loop. Injecting a privacy reset and disabling visit guards makes the
  targeted tests fail; unchanged foreground visits continue normally.

## Validation evidence

- Full local app suite: 1018 tests, 9 skipped, zero failures. Logic-core line
  coverage is 88.85%, above the existing 75% gate.
- Focused app suite: 38 passed, including nickname/privacy/revision, foreground
  visits, physical-finish corrections and six-language release notes.
- Native HTTP checks pass on disposable accounts: nickname updates preserve
  mixed public/private flags; reading a shown trade preserves unrelated alerts.
- Native auth/state-patch, commerce, counter-offer, opening-job and durable replay
  suites pass against the unchanged server code.
- Account layouts pass at 560/760 widths with light/dark fixtures and form
  disposal. Online layouts pass at 740/980 widths; all 21 compact popover
  screens pass. Screenshots use synthetic isolated wallets, not real accounts.
- Representative Base holo, Delta reverse, alternate-art VMAX and SV reverse
  render through 36-angle sweeps. Selected frames were visually inspected.
  The contributor's complete physical comparison is not independently repeated;
  inferred masks and relief remain approximations of physical printing.

## Server and data

- No open server PR or undeployed main changes at release review.
- Server main/runtime remains `0408c1ffb8b33abb05d0f208a873dc0f2d52b4cf`;
  schema `20261015_0009` and game rules version are unchanged.
- Server suite: 301 passed; 94 opt-in Swift comparisons run separately.
- Runtime, tests, migrations and scripts pass Ruff.
- Fresh verified production backup: 3 accounts, 3 password identities,
  11 login sessions and 9786 game events. All three saved account states validate
  with wallet, cards, packs, coupons, pity and claimed rewards preserved.
- Public health/local readiness return 200, public diagnostics return 404 and
  UUID-only state access returns 401. Existing public signup is retained.
- The running server is kept healthy without an unnecessary restart or DB
  migration. No production test accounts or profile changes are created.

## Distribution

The final package repeats all native online checks successfully, including the
new profile/alerts checks. Strict signature verification retains bundle identity
`dev.local.pokepackbar` and the existing signing certificate.

`PokePackBar.zip` SHA-256:
`927e5e63deb3a3d4384e50a3394ea56df646b2fb266e5fa148c5a9f90d8b093e`.

The GitHub release records final CI counts and local installation verification.
Existing stable bundle/signing identity and
the offline save are preserved. Artwork remains CDN-served; original scans are
excluded from the distributed app.

# PokePackBar 0.23.0

App PR #26 restarts dismissal timers when a reward or online celebration is
replaced. Consecutive dex claims, trades, purchases and listings now let the
last banner dismiss automatically.

## Review and validation

- Hosted production SwiftUI views exercise one reward, consecutive rewards and
  consecutive online celebrations. Removing both task identity keys makes both
  replacement tests fail while the single-reward test passes.
- Sparks and pack-flight children already have presentation-specific UUID
  identities. Their lifecycle remains unchanged.
- Native layout fixtures include the reward and listing banners. Snapshots
  establish layout; timed hosted tests establish automatic dismissal.
- Server suite: 304 passed, 94 optional pure-rule comparisons skipped. This
  release changes presentation only; game rules, prices and schema stay fixed.
- Fresh online backup: 3 accounts, 3 password identities, 12 sessions and
  12737 events. Integrity/foreign-key checks pass and all 3 account states retain
  wallet, collection, packs, coupons, pity and claimed rewards.
- Full local app suite: 1028 tests, 9 skipped, zero failures. Logic-core line
  coverage is 88.90% (75% gate). Focused banner/release-note suite: 9 passed.
- Native HTTP audits pass profile/alerts, commerce/counter-offers, 1001-pack
  jobs, durable replay, stale credential metadata and server-authoritative 401.
- Stable-signature packaging passes catalogue/name, price, foil and 18,949
  original-geometry guards. The bundle excludes original scans; the ZIP is 12 MB.
- Final main CI results and local installation are recorded with the release
  after completion.

## Deployment

- Server main and immutable running release match
  `2ec27c194e9a5d51d349972af8a483b9a3c02faa`; no server PR is open.
- Keep the healthy running server. Rules remain
  `ppb-server-v2/8047628cb035814b0b409a25e476c0a377942bafcd458dcaddc94621df96c540`
  and schema `20261015_0009`. No data migration or server restart is needed.
- Preserve stable signing, bundle identity and the original offline save.
  Publish the signed package and matching Homebrew checksum, then update the
  local app. Original card scans remain outside the distributed bundle.

`PokePackBar.zip` SHA-256:
`780956baa1959c0510ccef33bae529aa7117ea745ec0bfce34b774e54268819b`.

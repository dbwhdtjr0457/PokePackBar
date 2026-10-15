# PokePackBar 0.18.0

App PR #19 and server PR #14 replace the client-computed daily rotation with
server-managed bot market listings. At 00:00 UTC / 09:00 Korea, twenty cards
(4 top, 8 middle, 8 RR) restock with five copies each, one per account. Seller
and missing-card filters, purchase badges and card-detail selling links follow
the same market APIs. Quick sales pay 50% of market value before dex sale
bonuses, rounded once with a 100-won floor. Pack pricing remains unchanged.

## Validation

- 62 targeted app tests pass, including sale values, rounding, expected return,
  bulk sales, bot presentation, legacy rotation state and remote-state handling.
- Final server suite: 280 passed; optional Swift comparisons run separately.
- All 94 Swift/Python comparison checks pass against the matching candidate app.
- Native online suites pass: auth/state patches, opening jobs, trading,
  counter-offers, market settlement and durable request replay.
- Real HTTP bot-market audit: 20 offers, distinct sets, five copies, single-copy
  account limit, exact wallet/card changes, replay, stale-version acceptance
  for another buyer and missing/seller filters pass on disposable accounts.
- Korean/French online and 21-screen Korean popover layout audits pass.
- Copied production database migrates 0007 to 0008 with all 25 old tables'
  existing columns and rows preserved. Both account states validate with wallet,
  cards, packs, coupons, pity and claimed rewards retained. Migration tests also
  enforce CHECK constraints, foreign keys and indexes after the SQLite rebuild.
- Review repair: rotation failure logs retain request ID and sanitized stack
  locations. An injected SQL exception preserves market availability without
  logging its private marker; reintroducing raw traceback logging fails the test.

## Coordinated cutover

Schema is `20261014_0008`. Publish this client before activating the new server.
Older clients can receive changed sales quotes and the removed rotation command
is rejected. Update clients to 0.18.0 for online selling and the new market UI.
Existing replay receipts stay recoverable. Do not overwrite resumed transactions
with an old DB snapshot. Keep backup/env/plist/old release for recovery and prefer
forward repair after 0008 writes; older server releases require schema 0007.
Public signup and the persistent PokePackBar Local signing identity are retained.

The final 0.18.0 signed package passes native online audits, strict signature
verification and packaging gates (URL artwork separation, Energy source audit,
bulk-opening responsiveness, prices, Korean names and foil geometry/resources).
Release ZIP SHA-256:
`bff4c915d442c49735dc627ef9cf5172e37ecf7920357aeb94b9a91df4e493ce`.

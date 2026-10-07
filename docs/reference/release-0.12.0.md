# PokePackBar 0.12.0

Integrated app PRs #3–#7: stable local-signing fallback, value-aware immediate
reveals and sorted summaries, online marketplace/trading redesign and tracing,
anniversary Energy/ACE SPEC/reverse/gold foil fixes, collection search/numbers
and a statistics tab. Server PR #3 enables gzip for large JSON responses.

Review repairs cover market price overflow and server bounds, price-version
invalidation of reveal caches, statistics refresh after purchases/trades, explicit
SwiftUI actor isolation, readable controls, and updated navigation/foil tests.

Validation: combined release build; 32 targeted app tests; isolated native API
audit including two devices, trades, market purchase, response-loss replay and
1,001-pack jobs; 15 compact popover screens and six online sections at two sizes.
The server suite passed 235 tests (95 Swift-oracle cases excluded for this HTTP-only
change). A copied production state compressed from 1,381,356 to 100,122 bytes;
the price snapshot compressed from 8,051,470 to 1,003,520 bytes with identical JSON.

The full app suite was already red on main (915 tests, 696 assertion failures,
including one unexpected failure). Do not interpret successful packaging/native
audits as a green full test/coverage CI. The review fixes address regressions
introduced by these PRs; existing catalogue/reward/localization/style failures
remain separately visible in CI. Account state schema and server rules version
are unchanged; no migration or account relinking is required.

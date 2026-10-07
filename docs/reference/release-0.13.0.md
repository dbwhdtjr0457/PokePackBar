# PokePackBar 0.13.0

App PRs #8–#11: capture trade/market payloads before sheets close, value-sorted
binder editing/reordering, six-language online UX and error messages, retry
backoff, notification badges, off-main decoding/cache work and stable signing.
Server PRs #4–#7 add lock-timeout 503 responses, exact-name market ranking,
notification summaries and opt-in state patches. Existing clients retain full
snapshots; first commands and replay receipts also return full state.

Review added strict resource validation before asynchronous full/patch/online
mutation snapshots are published. Negative-ledger regressions fail before the
repair and pass after it; invalid patches retain their base and fetch full state.
The PR #10 merge conflicts were reconciled to the already tested combined tree.

Validation: server suite 241 passed, 95 Swift-oracle cases skipped for protocol
changes; native API audits pass with old 0.12.0 and the new client, including
trades, market, notification counts, 1,001-pack jobs and receipt replay. A cloned
production account returned a 638-byte token-report patch versus a 1,376,522-byte
full response; reconstructing the state and comparing its digest both pass.
Native layout audits covered English/Korean/Japanese online views, Spanish
account views and compact English popovers, with no production mutations.
Final packaged signed-app API audit and English online layout audit pass;
the final targeted XCTest suite has 93 passing tests.

Full app tests: 921 tests, 9 skipped, 689 assertion failures including one
unexpected failure. Failing test cases dropped from 26 in the prior combined
review to 16, with no new failing cases. Existing game catalogue/reward/odds,
source-copy and usage-environment failures remain; full CI is not green.

Code signing uses the persistent PokePackBar Local identity in the login
keychain. No private key or certificate is shipped in source or public assets.
This is self-signed internal distribution, not Apple notarization. Moving from
the previous ad-hoc release can require one initial Keychain access approval.
State schema and rules version stay unchanged; no relinking or migration.

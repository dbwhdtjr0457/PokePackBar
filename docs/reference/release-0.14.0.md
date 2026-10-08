# PokePackBar 0.14.0

App PR #12 clarifies optional invitation/account-linking codes in six languages,
trims pasted whitespace, and explains invite-only legacy-server rejection.
Existing account login, resources, state schema and rules version are unchanged.

Validation: 19 targeted app tests and Korean/English native account-window
layout audits pass. Both the candidate app and installed 0.13.0 app pass isolated
gameplay/commerce/device/job/replay audits against server PR #8. The candidate
server passes 240 tests (95 Swift-oracle tests skipped), including open sign-up,
optional operator invites, one-time code reuse rejection and login/rate limits.

Server PR #8 removes invite-only registration entirely, including the old
PPB_REGISTRATION_MODE switch. Activating it is a separate operator policy choice:
the public API admits anyone with email/password, without email verification.
No migration is required. Verify the approved production policy before deploying.
Full app CI retains the previously documented game-data/odds and legacy failures;
targeted/native passes are not a claim that the full test/coverage gate is green.

The final 0.14.0 packaged app repeats the three native online audit suites and
passes strict signature verification with the same PokePackBar Local identity.
Package audits cover 18,949 card layouts, artwork URL routing, bounded HD
prefetch, foil/price resources and bulk-opening responsiveness. Original card
artwork is not included in the bundle. The release zip SHA-256 is
`e487bf8b0a635e8dbd5830b326019d6b9cee3d390b86170380b9628eff7a1847`.

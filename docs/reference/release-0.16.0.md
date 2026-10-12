# PokePackBar 0.16.0

App PR #17 and server PR #12 add macOS online alerts, latest-first contextual
notification history, bounded read-all, trade price sorting/navigation and
printing-ledger caching for bulk sales. The review fix bounds read-all by the
displayed page even when the background summary advances.

Validation: 47 targeted app tests pass, including alert cursors, read-all bounds,
printing-cache invalidation and the 2,500-card-kind bulk-sale performance check.
Server integration passes 260 tests (95 opt-in oracle tests skipped) and Ruff.
Native authentication/gameplay/commerce/device/job/replay suites pass against
the combined server. Korean/English native online layout audits pass, including
the alert-arrival and trade-picker screens. Screenshots use isolated fixtures.

Opt-in oracle verification reports 94 passes and one existing Oripa fixture
difference. Deployed server commit 4561f04 (merged main e30ed06) deliberately
removed headline-card price limits; the old fixed-seed fixture still expects
the former range. The new notification PR does not modify Oripa code or rules
data. Preserve the deployed headline policy; record the baseline difference
and report 94 passing comparisons with the existing fixture difference.

Runtime schema remains `20261008_0007`, and rules version remains
`ppb-server-v2/e835cec930b86e5a50298b384e3c2670a013eef1ca3d020ba38b7da001bdbb2e`.
Existing 0.15.0 clients retain API compatibility. Back up the database and
preserve prior release/env/plist before switching the API. Public registration
remains enabled. macOS alert banners depend on system permission, notification
settings and Focus; background polling requires the app to be running.

Final signed 0.16.0 package passes strict signature verification, resource/
energy/price/foil/geometry and bulk-opening packaging gates, and native online
audits. The installed 0.15.0 client also passes against the updated server.
The displayed-page cutoff regression rejects a cutoff advanced into an unseen
notification and passes after restoring the implementation.
Release ZIP SHA-256:
`87a3d7b4ab15331c3842d2badbf22a602e91f7bc2ae768fd8f23a211f734fd13`.

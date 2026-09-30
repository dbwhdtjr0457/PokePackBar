# Bulk opening performance — 2026-09-29

## Scope and preserved behavior

Optimize large openings without changing pack recipes, RNG ordering, pity, NEW
flags, god-pack rules, physical reveal order, or the single all-or-nothing save.
The only quantity limit remains owned inventory. No live inventory is used in QA.

## Changes

- `PreparedPackBatch`: immutable, cancellable preparation on a worker task.
  Price/expected-value and rules metadata are computed once per batch. Only the
  last 1,000 history records are built (the existing persistence retention limit).
- `WalletStore.openPacksAsync`: prevent duplicate openings, validate relevant live
  state after preparation, then commit once. Cancellation before commit consumes
  nothing; concurrent grants are preserved; conflicting collection/mode/pity/perk
  edits reject the prepared batch. Storage failure rolls everything back.
- Card collection stages dictionary updates locally and publishes once, instead
  of notifying Observation for each field of every card.
- Show preparation immediately. Build presentation totals/order/pack-boundary
  indexes once off the main actor instead of traversing every card on UI updates.
- Preload the first 24 reveal cards and 24 summary thumbnails, with at most six
  tasks per prefetch call. Maintain a sliding reveal window. Other summary cells
  load lazily. Keep original HD dimensions and foil rendering unchanged.
- ImageIO bitmap decoding/rotation runs on a dedicated actor. Decoded images have
  a 96 MiB cost-limited memory cache; the initial/sliding windows retain only a
  bounded set, rather than all unique HD cards from the opening.

## Measurements

Release build, isolated empty wallet, Black Bolt, seeds `20260929 + offset`.
Measurements include drawing, collecting, history and the actual filesystem save;
they exclude image/network preparation and the intentional one-second reveal lead-in.

| Work | Before | After, first run |
| --- | ---: | ---: |
| 1,000 packs | 12.495 s | 0.213 s |
| 10,000 packs | Not measured | 1.103 s |
| Presentation for 1,000 / 10,000 packs | Not measured | 0.004 / 0.034 s |
| Worst main-actor heartbeat gap, 1,000 / 10,000 | Blocking synchronous operation | 45 / 65 ms |

Timings are local observations, not a fixed latency guarantee. The final atomic
save remains synchronous; large pre-existing saves or slow disks can still add a
short pause. Cold network image fetching can still extend the preparation screen.

## Reproducible checks

`PPB_OFFLINE=1 .build/release/PokePackBar --benchmark-bulk-opening 1000`

Also run with `10000`. The command creates and removes its own temporary wallet.
It compares every pack to sequential seeded draws, verifies history retention and
pity, checks that the main actor yields, and exercises failed persistence,
cancellation, concurrent duplicate requests, stale settings, and concurrent grants.
The packaged-app build runs the 1,000-pack check before installation.

`PPB_OFFLINE=1 .build/release/PokePackBar --audit-local`

The existing 127-set/25,400-pack, special-variant, replay, atomic-save and corruption
recovery checks also passed after the refactor. These checks do not certify real
world pull-rate estimates; they verify preservation of the existing simulator rules.

## Native view check

`--benchmark-bulk-opening 10000 --render-bulk OUTPUT_DIRECTORY` renders the actual
reveal and summary SwiftUI views with 110,000 displayed cards (including Energy).
The first layout took 10.8 ms / 7.8 ms respectively. Both captures showed card art,
labels, counts and actions without clipping; temporary captures were moved to Trash
after inspection. This is a native render check, not an end-to-end click/scroll test.
An 8,000-ID duplicate-heavy prefetch also returned exactly eight full-resolution
Energy images and verified the decoded memory-cache hits.

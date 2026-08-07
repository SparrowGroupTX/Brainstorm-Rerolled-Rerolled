# Brainstorm v2.8.0-alpha release and performance notes

This document records what changed, what was validated, how to interpret the
performance figures, and which ideas remain optional future work. The release
still uses Balatro's exact seeded random-number behavior: every fast gate is a
necessary-condition filter, and every returned seed is checked by the full
authoritative simulator.

## Deployment record

- Installed version: `Brainstorm v2.8.0-alpha`.
- Installed native DLL SHA-256:
  `1DBCC11592930428FC05E5A358AAF2814121406B06C178C284339202697BEEF4`.
- Installed native DLL size: 11,689,976 bytes, PE x86-64.
- Pre-release backup:
  `C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\20260806-002713-pre-v2.8.0-alpha`.
- The user's existing `config.lua` was preserved.
- Repository and installed hashes match for the core Lua, UI, Lovely patch,
  compatibility metadata, and native DLL.

## User-facing changes

### Menu and controls

- Split the oversized mod menu into Search, Cards, Jokers 1-2, Jokers 3-4,
  Joker 5, Estimate, and Advanced pages so controls remain on-screen.
- Removed the misleading seeds-per-frame control. Native searching does not
  run as a Lua per-frame loop.
- Added Balanced and Maximum native CPU modes. Maximum uses every logical CPU
  and is the fastest tested setting, at the cost of game/desktop responsiveness.

### Joker search

- Added five independent Joker occurrence slots covering the full vanilla
  Joker list.
- Added Any Edition or Negative as a per-slot requirement.
- Fixed the Negative Blueprint filter so it requires Blueprint identity and a
  Negative edition together. Selecting other Joker criteria no longer makes
  the Negative Blueprint part disappear from the search.
- The same Joker can be selected in multiple slots without clearing an earlier
  slot.
- Duplicate selections become a chronological acquisition plan: one visible
  Joker cannot satisfy two slots, and the selected order must be playable.
- Added exact and cumulative timing windows through Ante 8. Cumulative windows
  accept the starting Charm pack, natural shop stock, and displayed Buffoon
  packs without paid rerolls through the chosen deadline.
- Added the starting-pack alternative for non-Legendary Jokers through
  Judgement. Soul creates Legendary Jokers, matching Balatro.
- Modelled selling a first copy before a later duplicate. Invisible Joker must
  complete two blinds before the assumed sale; Showman allows duplicates to
  remain in the pool.
- Modelled Gold/Black-stake Eternal behavior. An Eternal acquired Joker cannot
  be used as the sale route for a later copy. Invisible Joker retains its
  Eternal exemption; Rental and Perishable copies remain sellable.

### Charm pack, Souls, cards, decks, and vouchers

- Added 0-4 as the requested Soul count in the starting five-card Charm-tag
  Mega Arcana pack. The pack can display four Souls even though its normal
  selection limit remains two.
- Added Any One Suit: Clubs, Diamonds, Hearts, or Spades may qualify, but one
  individual suit must meet the complete threshold.
- Corrected fixed-deck card counting. Plasma and most decks begin with four of
  each rank and thirteen of each suit; only Erratic has seed-random base cards.
  Abandoned and Checkered use their actual starting transformations.
- Added Observatory deadlines through Ante 8. Telescope must be offered and
  acquired first; Observatory may arrive later without requiring Instant
  Observatory.
- The native API now receives the active stake as well as the deck. Older API
  entry points remain available and retain White-stake behavior for ABI
  compatibility.

### Time estimates

- Added a configuration-specific estimate page with typical time, 90% time,
  uncertainty range, measured throughput, sample evidence, and confidence.
- Added exact sampling when hits are common and a labelled staged estimate
  when the configuration is too rare to observe enough hits in the short
  sample.
- Fixed double-counting of the validated Charm Tag in staged opening estimates.
- Estimates are probability distributions, not countdowns. Rare configurations
  can still finish much earlier or much later than their displayed typical
  time.

## Search-engine changes

### Exact vector gates

- Added runtime-dispatched scalar, AVX2, and AVX-512 implementations for the
  common Charm Tag/Soul/Legendary opening route.
- Added an exact tag-only vector route.
- Added an exact Negative Blueprint edition route. When other Joker targets
  are present, it also checks Blueprint's Rare roll before entering the full
  simulator, reducing authoritative survivors by about 20 times.
- The full simulator rechecks every surviving seed. SIMD cannot create a false
  positive result.

### Data and random-number work

- Replaced the general node hash table used on the hot path with a dense cache
  and compact index while retaining full-string collision checks.
- Replaced individual lock booleans and touched-lock bookkeeping with compact
  bitsets.
- Added compact packed seed characters, shared-prefix seed hashing, exact
  vectorized final hash rounds, and a faster positive-domain scalar hash path.
- Added an exact scalar Lua-RNG jump table and removed repeated general-purpose
  RNG object construction.
- Reused worker-local batch storage and simulator state to reduce allocation
  and reset overhead.

### Timeline and scheduling work

- The no-reroll Joker timeline now advances the shop card-type stream but only
  generates Joker identities for cards that are actually Jokers. Unused Tarot,
  Planet, Spectral, and playing-card identities are not materialized.
- Timeline sticker work is skipped when Eternal status cannot affect a future
  duplicate sale. When Eternal can matter, an internal Eternal-only path keeps
  the exact Eternal decision but omits unused Rental/Perishable processing.
- Cheap deterministic and highly selective gates run before full deck or later
  Ante simulation.
- Query ordering, batching, counter flushing, block scheduling, and thread
  counts were benchmarked on the target 16-core/32-thread CPU. Maximum mode at
  32 logical workers was the fastest tested production setting.
- The release DLL is built with exact-safe native profile-guided optimization.
  Fast-math, floating-point reassociation, reciprocal approximations, and FP
  contraction remain disabled because they can change Balatro seed results.

## Measured performance

Measurements were taken on a Ryzen 9 9950X3D. They describe seed evaluation,
not a guaranteed wall-clock time to the next match.

| Workload | Measured change |
| --- | ---: |
| Common Charm + Soul + one Legendary route, vector gate versus scalar route | about 4.5x at 32 threads |
| Negative Blueprint combined with later Joker targets | about 2.0x at 32 threads |
| Joker-only chronological generation | about 7-8% faster |
| Timelines where stickers cannot affect duplicate selling | about 25-33% faster |
| Eternal-compatible duplicate timelines using Eternal-only processing | about 14% faster |
| Exact current Perkeo/Invisible/Invisible + Telescope/Observatory configuration, last sticker change alone | about 1.7% faster |

The final PGO release processes 3.2 billion known-no-hit seeds in a median of
about 5.24 seconds, or roughly 610 million seeds per second. Its opening
Charm/Soul probability dominates, so later timeline-only improvements have a
smaller effect on that particular search. A fresh release benchmark starting
at `ABCDEFGH` found valid Gold-stake seed `6QUGIBTH` in 40.14 seconds, and a
one-seed authoritative rerun accepted it at both one and 32 threads. Real
searches stop on a random hit; the observed 20-52 second runs are compatible
with a much longer mathematical average.

## Validation performed

- Native and portable builds pass the full CTest suite.
- Scalar, AVX2, and AVX-512 opening gates are differentially checked against
  the authoritative implementation, including seed-domain wraparound.
- Negative Blueprint scalar/vector paths are checked across ordinary, Ghost,
  and Zodiac shop rates and Rare/Negative combinations.
- Fixed and Erratic deck card counts are checked against exact fixtures.
- Gold-stake fixtures cover Eternal rejection, Rental/Perishable sale,
  Invisible Joker's exemption, Showman, Soul, Judgement, shop, and Buffoon
  sources.
- Sticker elision was compared across shop and Buffoon identities, locks,
  packs, tags, vouchers, future streams, and thousands of Gold-stake timelines.
- Legacy exported APIs remain available alongside the stake-aware search and
  estimator APIs.
- Lua files are compiled with Balatro's bundled Lua 5.1 library, and the Lovely
  TOML file is parsed before deployment.

## Known boundaries

- Later-Ante Joker timing models natural initial shop stock and displayed
  Buffoon packs without paid rerolls. It does not claim every possible economy,
  skip, reroll, or consumable play sequence.
- Only vanilla decks are simulated. Challenge runs and modded decks with custom
  pools or rules are rejected rather than guessed.
- Showing three or four Souls does not increase the Mega Arcana pack's ordinary
  two-card selection limit.
- Estimates remain uncertain for extremely rare conjunctions; more samples
  improve calibration but also make the estimate itself slower.

## Optional future work

There is no known required code fix left for this release. The following items
are documented follow-ups, ordered by likely value.

1. **Specialized Judgement opening gate.** The current Perkeo + starting-pack
   Invisible route is dominated by Charm-pack generation. A specialized exact
   gate could vectorize or stage Judgement visibility and its generated Joker
   before constructing the chronological simulator. This must preserve Soul
   forcing, transient Tarot locks, resampling, two-card choice order, and the
   Judgement Joker's rarity/edition streams. It is the most plausible remaining
   speedup for the exact configuration.
2. **Single-acquisition timeline fast path.** A completed code audit found that
   a display with exactly one reachable requirement currently allocates a
   branch vector and deep-copies simulator state. A safe direct decline/acquire
   path was designed, but the user-requested release cutoff arrived before full
   differential and performance validation, so it was deliberately reverted.
   Required coverage includes ordered cascades, duplicate identities,
   Negative-then-Any slots, Showman, Eternal, Invisible aging, and both shop and
   Buffoon choices.
3. **Arbitrary Negative-Joker batch gates.** Negative Blueprint has a dedicated
   exact vector path. Extending this to arbitrary per-slot Negative targets may
   help very rare searches, but a safe gate must union all allowed sources and
   Antes without rejecting a later valid occurrence.
4. **Longer empirical estimate calibration.** Store opt-in local observations
   of seeds checked and time-to-hit by normalized configuration, then use them
   to calibrate staged estimates. This needs privacy-conscious local storage,
   versioning, outlier handling, and a clear reset control.
5. **Offline or GPU search mode.** A proof-of-concept exact GPU hybrid reached
   high raw throughput, but the advantage shrank after the CPU SIMD work and it
   would compete with Balatro's renderer while adding a CUDA/runtime deployment
   burden. A separate offline helper process is the safer form if this is
   revisited.
6. **Cross-machine release matrix and CI.** Add automated Windows builds and
   differential tests for CPUs with scalar-only, AVX2, and AVX-512 support, plus
   packaged runtime-dependency and export checks.
7. **In-game smoke testing.** After deployment, verify one short seed on Plasma
   and Erratic, one duplicate Invisible route, one Negative target, and one
   Gold-stake Eternal fixture in the actual Steamodded/Lovely environment. The
   native and syntax suites cover the code paths, but only the game can validate
   every loader/UI interaction.
8. **Repository cleanup and release commit.** The installed mod is updated, but
   no Git commit or tag was created because that was not requested. Diagnostic
   `Immolate/build-*` directories and benchmark evidence were intentionally
   retained. After the in-game smoke test, archive any evidence worth keeping,
   remove unwanted build directories, review the source-only diff, then create
   a release commit/tag if this repository is meant to be published.

## Explored ideas not retained

- A fixed-capacity shop chronology was exact but only about 1.3-1.6% faster and
  did not clear the retention threshold.
- A 64 KiB SIMD Lua-RNG byte-jump table was exact but 32% slower with AVX2 and
  56% slower with AVX-512 than the shift kernel.
- A direct Observatory voucher precheck, a longer shared seed prefix, several
  scheduler variants, LTO/MSVC builds, and exact-safe compiler flag probes did
  not produce a stable material gain.
- Unsafe fast-math options were rejected regardless of speed because they can
  return the wrong Balatro seed.
- The GPU hybrid remains diagnostic-only for the deployment and contention
  reasons described above.

# Brainstorm v2.9.0-alpha release and research notes

This release turns the rare Perkeo/Invisible search that motivated the latest
performance work into an exact indexed query. It also improves the ordinary
raw search, integrates index-aware time estimates, and records the results of
several independent attempts to find exploitable algebraic or statistical
structure in Balatro's seed space.

The central safety rule is unchanged: a seed is returned only after the normal
authoritative simulator accepts every selected criterion. An index narrows the
candidate population; it does not substitute cached guesses for simulation.

## Deployment record

- Installed version: `Brainstorm v2.9.0-alpha`.
- Installed native PGO DLL SHA-256:
  `B1834B8C637861874B0BBD0A295FE9BF7A2A9962F33E65CAB7A6A2E0C2ADCA9D`.
- Installed native PGO DLL size: 14,411,234 bytes, PE x86-64.
- Pre-release backup:
  `C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\20260806-145750-pre-v2.9.0-alpha`.
- The live `config.lua` SHA-256 before and after deployment:
  `94CF0E878A917CC282B881B4DAD289B485688C9DCF7B074E64C54B03ECEAF9D1`.
- Repository and installed runtime-file hashes are verified after deployment.

## The practical breakthrough: complete rare-event indexes

The eight-character seed space contains exactly 2,318,107,019,761 canonical
IDs. We exhaustively scanned that entire domain once and stored the IDs for a
rare opening predicate shared by the user's target configurations:

- Charm Tag opens the starting five-card Mega Arcana pack;
- Perkeo is selectable from a Soul; and
- Invisible Joker is selectable from Judgement in the same pack.

The complete parent population contains 209,798 seed IDs. Its sorted raw
payload is only 1,678,384 bytes. The full scan was split into 2,159 gap-free,
crash-recoverable shards and completed in 46.08 minutes at an average 838.46
million IDs per second. Every one of the 209,798 final IDs was independently
rechecked through the authoritative simulator.

A bounded postpass over that parent population found 2,145 IDs that also
produce another Invisible Joker at exact Ante 2 on the natural no-reroll
Plasma/Gold timeline. Of those, 137 offer Telescope first and 17 subsequently
offer Observatory by Ante 2. That 2,145-ID child is the complete accelerator
for the literal development configuration.

### Shipped assets

| Asset | Records | Bytes | SHA-256 |
| --- | ---: | ---: | --- |
| `perkeo_invisible_anchor_v1.ids` | 209,798 | 1,678,384 | `bd9725e8ac6ec74cff092068996125d06959237863af1f7a62f70d33f4ac1d57` |
| `perkeo_invisible_ante2_invisible_anchor_v1.ids` | 2,145 | 17,160 | `f43da8550fb30f50afa8dad0cfd00e1d7b18a827beaa9a0ae425e59bffb090d8` |

The parent predicate was differentially tested across all 15 supported
vanilla decks at White, Black, and Gold Stake over a `2^30`-ID sample, plus
known full-index hits. The code path proves the intervening stakes cannot
affect these starting-pack outcomes, so the parent is published for stake
levels 1-8. The Ante-2 child remains deliberately scoped to Plasma Deck at
Gold Stake because later shop and ownership state can vary with deck or stake.

### Runtime planning and fail-safe behavior

The engine recognizes an applicable index from normalized criteria, not from a
loose display-string approximation. The exact child is tried before the parent.
Candidate traversal preserves the same cyclic order as a raw search by using
two sorted spans around the selected starting seed. Multiple workers retain
the smallest cyclic matching offset, so parallel checking cannot return a
later candidate merely because its thread finished first.

Before an index is trusted as complete, the loader checks its file-size limit,
eight-byte record alignment, exact record count, strict ordering, uniqueness,
domain range, and a hard-coded FNV-1a content checksum. Its file is located
relative to the loaded DLL rather than the game's working directory.

Missing, truncated, duplicated, unsorted, out-of-range, disabled, or
checksum-mismatched assets cannot produce a false "no seed" result. A valid
but untrusted list can only act as a priority branch and is followed by raw
fallback if it misses. A trusted complete index may prove that the requested
cyclic range has no match.

## Measured performance

All timings below were taken on the same Ryzen 9 9950X3D development machine
with 36 search workers. Microsecond-scale indexed timings naturally have some
process-start and scheduler noise, so seven-run medians are used.

### Literal Plasma/Gold configuration

Configuration: Perkeo and Invisible Joker in the starting Charm pack, another
Invisible Joker at exact Ante 2, Charm Tag, Telescope, and Observatory by Ante
2, starting from `11111111`.

| Path | Result | Time |
| --- | --- | ---: |
| v2.9.0 exact child index, seven-run median | `YJABSL71` | 0.001900 s |
| v2.9.0 raw search with both indexes disabled, three-run median | `YJABSL71` | 13.552794 s |
| previously installed v2.8.1 raw search | `YJABSL71` | 17.187338 s |

The index is approximately 7,100 times faster than the same new DLL's raw
path, and approximately 9,000 times faster than the installed v2.8.1 build in
this controlled comparison. The ordinary raw fallback itself uses about 21.2%
less wall time than v2.8.1 (about 26.9% more throughput). Compared with the
user's observed 20-52 second searches, the indexed route is roughly four
orders of magnitude faster.

This acceleration applies when the selected configuration logically implies a
shipped complete predicate. Other Joker combinations continue to use the
improved raw search unless a future general index covers them.

### Index-aware estimate

The Estimate page now measures the plan that the actual search will use. For
the literal route it evaluates all 2,145 indexed candidates, observes all 17
matches, reports `method=exact_index`, and shows the indexed candidate count
and candidate-checking speed. The measured estimate call itself completed in
about five milliseconds and reports a sub-second display value rather than the
old multi-minute raw-space projection.

If an index population cannot be fully evaluated within the UI budget, the
method is labeled `index_sample`. Raw configurations retain the existing exact
sample or staged heuristic methods. A timing-sensitive regression for the raw
estimator now uses the UI's full one-second ceiling; it passed 10 consecutive
native runs and five consecutive portable runs after the change.

## Faster ordinary search

The exact index is the headline gain, but the non-indexed path also improved.

### Specific-Legendary-first evaluation

When a starting-pack query asks for a particular Legendary Joker, the AVX-512
opening kernel now computes that identity first. Four out of five seeds are
rejected before Charm-tag and Soul work. The isolated kernel was about 1.42x as
fast as the previous tag-first ordering in paired four-billion-ID tests, with
identical survivor counts and checksums. Generic Soul-count queries with no
specific Legendary remain tag-first because that is their cheaper order.

### Partial-bit exact tag classification

The first tag category usually needs only the high nine Lua-random mantissa
bits. Of 512 possible prefixes, 505 determine the exact tag category directly.
Only seven boundary prefixes fall back to the full random-number computation.
This optimization is exact, not approximate, and contributed roughly 10-14%
to representative opening throughput on top of the earlier SIMD pipeline.

### Search and build hardening

- Candidate search no longer sorts per-query `(offset, id)` pairs. It walks
  two `lower_bound` spans over the already-sorted payload.
- Indexed workers are capped by useful 64-candidate blocks to avoid thread
  overhead on tiny lists.
- Seed ID zero is represented by an explicit found flag instead of being
  confused with "no result".
- Index dispatch is independent of SIMD availability, so portable/scalar
  systems can still benefit from the exact assets.
- Profile training explicitly disables indexes for its long mixed workloads;
  otherwise the new child would make training finish too quickly to profile
  raw fallback loops.
- A MinGW/GCC instrumentation-only AVX-512 crash was traced to a 64-byte
  aligned ZMM spill on a stack that the profiler had left only 16-byte
  aligned. Isolated AVX2/AVX-512 intrinsic translation units are now excluded
  from both PGO phases, while dispatcher, search, and authoritative simulation
  code remain profile-guided. This is safer and gives intrinsic-heavy kernels
  little reason to depend on branch profiles.

## Seed-structure research

We attacked the "crack the seeds" question from several independent angles.
The negative results matter because they prevent unsafe predictors from being
mistaken for exact search acceleration.

### Statistical structure tests

A held-out study covering approximately 9.74 billion labeled seeds tested:

- individual characters and positions;
- prefixes and suffixes;
- numeric ID strides and residue classes;
- alternate enumeration orders;
- intermediate pseudohash values;
- nearby IDs and Hamming-neighbor relationships; and
- train/test ranking stability.

No reproducible feature produced useful held-out enrichment. Nearby seed text
and adjacent canonical IDs rapidly decorrelate after Balatro's pseudohash and
keyed random streams. There is structure in the deterministic mapping, but no
measured cheap ordering rule that ranks future hits better than chance.

### Algebraic inversion and meet-in-the-middle

The seed pseudohash, keyed node construction, Lua PRNG transition, rounding,
and selection thresholds were traced exactly. Direct inversion is blocked by
many-to-one floating-point rounding, `fract`, multiple independently keyed
streams, and the need to satisfy a conjunction of events rather than one RNG
output.

A four-character/four-character meet-in-the-middle does not expose a compact
join key: the right half is mixed through state that depends on the entire left
half and the event key. Materializing enough state for an exact join was
estimated at 16 TiB or more before downstream event constraints, making it
worse than forward enumeration.

An exact SMT encoding validated small fragments, but even four free seed
characters exceeded a ten-second solve window once the real nonlinear and
floating-point semantics were present. It is useful as a correctness oracle,
not as a full-domain solver.

### GPU and other contrarian approaches

An exact CUDA implementation passed parity checks for the full opening gate.
The naive kernel reached about 335.5 million seeds/s and an optimized
Perkeo-first version reached about 449.8 million seeds/s. Both lost to the
current CPU path on this machine, before accounting for transfer,
orchestration, distribution, and contention with Balatro. GPU deployment is
therefore not in this release.

The useful "hidden structure" turned out to be query reuse rather than seed
predictability: many very expensive searches imply the same rare opening
event. Exhaust that event once, store its exact IDs, and evaluate every stricter
configuration over the small parent population.

## Validation completed

- Full PGO GENERATE and USE phases each passed all 18 CTests.
- The hardened native build passed the API regression 10/10 consecutively and
  then passed all 18 tests.
- The hardened portable build passed the API regression 5/5 consecutively and
  then passed all 18 tests.
- Scalar, AVX2, AVX-512, and automatic opening paths match the authoritative
  simulator across normal, short, tail, and domain-wrap ranges, Soul counts
  1-4, and all five Legendary identities.
- The historical four-billion-ID probe reproduced exactly: 368 parent
  anchors, five Ante-2 child anchors, and one Telescope child.
- All 209,798 parent IDs and all 2,145 derived IDs were independently
  regenerated and revalidated.
- Malformed-index tests cover valid-untrusted, unsorted, duplicate,
  out-of-range, truncated, empty, missing, disabled, and packaged trusted
  assets.
- Raw and indexed searches from `11111111` both return `YJABSL71` for the
  literal configuration.
- The final DLL exports every versioned search and estimate entry point plus
  `free_result` and the CPU-mode API.

## Remaining work, in priority order

1. **In-game smoke matrix.** Exercise the installed build in the real
   Steamodded/Lovely environment: indexed Plasma/Gold, a parent-index query on
   another vanilla deck/stake, one raw arbitrary-Joker query, one Negative
   target, one Erratic card query, and one malformed/missing-asset fallback.
   Native tests cover the logic, but the game owns loader and UI integration.
2. **General at-least-two-Souls index.** Build the projected 13.8-million-ID
   parent (about 33 MiB with Elias-Fano), plus small three- and four-Soul
   children. Add compact signatures for the selectable Legendary identities
   and their Negative flags. This should accelerate arbitrary pairs of
   starting Soul Legendaries, not only Perkeo plus Judgement.
3. **Negative Legendary postings.** A Negative Perkeo parent projects to about
   1.38 million IDs; all five Legendary variants should fit in roughly 20 MiB
   with succinct postings. This directly targets the large Any-versus-Negative
   disparity without raw rejection scans.
4. **Optional Perkeo-plus-Judgement catalog.** Index the broader starting-pack
   family by the Judgement Joker outcome. It could cover "Instant Perkeo plus
   any chosen non-Legendary" configurations, but likely costs hundreds of MiB
   and should be an optional asset.
5. **Generic predicate planner and parent/child codec.** Replace the two
   hard-coded applicability rules with a typed predicate catalog supporting
   complete intersections, complete unions, priority branches, parent-ordinal
   children, Elias-Fano, and per-shard range counts. Preserve authoritative
   checking and explicit trust modes.
6. **Derived local cache.** After a complete parent has been exhausted for a
   normalized downstream query, optionally retain the result as a tiny
   checksummed child. This would make repeated custom Observatory deadlines or
   duplicate timelines immediate without distributing every niche index.
7. **Estimate history calibration.** Store opt-in, versioned local observations
   of throughput and censored time-to-hit for raw searches. Indexed estimates
   are now exact; rare unindexed conjunctions still benefit from empirical
   calibration and honest uncertainty intervals.
8. **Cross-machine release matrix.** Run portable/scalar, AVX2, and AVX-512
   parity and DLL-load tests on Intel and AMD Windows systems. The current
   machine exercises every backend, but broader CPU/OS coverage is still
   valuable.
9. **Revisit GPU only after batching broader parents.** A GPU may become useful
   for offline full-domain index construction on different hardware. It is not
   competitive for the current live search kernel on this system.
10. **Repository cleanup and release commit/tag.** Diagnostic build trees and
    research reports are retained as evidence. Review and archive them before
    publishing the repository, then create a release commit/tag if desired.

## Detailed evidence

- Full index build and validation:
  `Immolate/build-anchor-index-full/REPORT.md`
- Broader index architecture:
  `Immolate/build-candidate-seed-index/BROADER_ARCHITECTURE.md`
- Algebraic/inversion study:
  `Immolate/build-inversion-math-20260806/REPORT.md`
- Statistical and contrarian study:
  `Immolate/build-contrarian-seed-cracking-20260806/REPORT.md`
- Held-out structure analysis:
  `Immolate/build-structure-stats/analysis-final/analysis_report.md`

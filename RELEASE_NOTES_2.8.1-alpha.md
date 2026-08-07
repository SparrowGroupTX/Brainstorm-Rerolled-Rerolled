# Brainstorm v2.8.1-alpha release and performance notes

This release is the completed overnight performance pass on top of
[v2.8.0-alpha](RELEASE_NOTES_2.8.0-alpha.md). It keeps Balatro's exact seeded
random-number behavior: optimized batch filters may reject impossible seeds,
but every surviving result is still accepted only by the authoritative
simulator.

## Deployment record

- Installed version: `Brainstorm v2.8.1-alpha`.
- Installed native DLL SHA-256:
  `CC3C723ED6F22635D2DC89FC0AC3B07A666741F0C8F1904CFA50E94F88A16635`.
- Installed native DLL size: 13,545,594 bytes, PE x86-64.
- New pre-release backup:
  `C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\20260806-121348-pre-v2.8.1-alpha`.
- The earlier `20260806-002713-pre-v2.8.0-alpha` backup remains available.
- Deployment changed only `Core\Brainstorm.lua`, `steamodded_compat.lua`, and
  `Immolate.dll`; the already-current UI and patch files were not recopied.
- The existing live `config.lua` was preserved byte-for-byte. Its SHA-256 is
  `94CF0E878A917CC282B881B4DAD289B485688C9DCF7B074E64C54B03ECEAF9D1`.
- Repository and installed hashes match for every runtime allowlist file.

## What changed in v2.8.1-alpha

### Faster exact opening search

- Compact seed characters are now filled incrementally instead of repeatedly
  rebuilding the complete packed seed representation.
- The exact Lua random-number transition used by the opening gate is evaluated
  directly with a four-vector AVX-512 pipeline on supported CPUs.
- Initial tag and fresh-roll work is pipelined across four vectors.
- Locked-tag resamples share the already-computed 14-character seed-hash
  prefix instead of repeating it for each attempt.
- An exhaustively verified compensated operation replaces the division in the
  final hash round. The narrow floating-point predecessor ambiguity interval
  remains on a conservative exact fallback.
- Runtime dispatch still selects scalar, AVX2, or AVX-512 according to the
  current CPU. These paths are necessary-condition gates only.

The frozen isolated opening-kernel comparison was about 36.5% faster at one
thread and 28.6% faster at 32 threads. The gain to a complete search is smaller
because survivors still run through the authoritative timeline.

### General Negative-Joker batching

- Arbitrary per-slot Negative Joker requirements now receive an exact scalar
  batch prefilter, extending the specialized Negative Blueprint work to the
  general Joker timeline.
- The filter understands rarity, deck-specific shop rates, timing windows,
  starting Soul/Judgement sources, multiple distinct Negative events, awkward
  batch tails, and seed-domain wraparound.
- When the opening Charm/Soul batch owns the first filtering stage, the
  arbitrary Negative gate runs only on those survivors. This preserves the
  selectivity of the cheaper opening route.
- Experimental AVX2 and AVX-512 versions were deliberately excluded from the
  shipped build. MinGW on Windows intermittently emitted aligned vector stack
  spills against an unaligned ABI stack, producing access violations. The
  exact scalar batch is stable and already materially faster.

Representative eligible Negative timelines measured about 2.2-3.3x faster,
depending on the target mix and thread count. This multiplier applies to the
Negative timeline stage, not necessarily to an entire search dominated by a
rarer Charm, tag, or voucher condition.

### Timeline and scheduling

- A single-acquisition timeline fast path avoids branch-vector allocation and
  simulator-state copies when only one reachable Joker requirement remains.
  It measured about 5.1% faster at 32 threads on its representative workload.
- Maximum CPU mode now uses a benchmarked 36-worker schedule on this
  16-core/32-logical-processor system. Four paired 4-billion-seed comparisons
  favored 36 workers over 32 by a median of about 2.6%.
- Balanced mode, explicit environment overrides, and automatic behavior on
  other logical-processor counts are unchanged.
- Forty workers, affinity pinning, ideal-processor mapping, smaller blocks,
  and alternate batch chunks were all slower or failed the retention threshold
  and were not shipped.

### Profile-guided build coverage

- The reproducible trainer now includes a forced starting-Charm plus Negative
  timeline, as well as the literal user search, relaxed Observatory route,
  standalone Negative timeline, Negative Blueprint, four-Soul, and Erratic
  workloads.
- Training output is immediately flushed, which makes long builds observable
  without changing the profile.
- The final DLL retains exact-safe native profile-guided optimization. Fast
  math, reassociation, reciprocal approximations, and floating-point
  contraction remain disabled.

## Measured end-to-end performance

All figures below were measured on the same Ryzen 9 9950X3D development
machine. No-hit scans are used for stable throughput comparisons; a real
search stops at a random matching seed and therefore has much higher
run-to-run variance.

| Measurement | Previous installed build | v2.8.1-alpha | Change |
| --- | ---: | ---: | ---: |
| Controlled 4-billion-seed scan, 32 workers | about 586.4 M seeds/s | about 696.9 M seeds/s | **+18.8%** |
| Same search class in Maximum mode | about 586.4 M seeds/s | about 701.8 M seeds/s | **about +19.7%** |
| Known Gold-stake search from `ABCDEFGH` to `6QUGIBTH` | 40.142815 s | 33.873536 s | **15.6% less time** |

The practical expectation for the user's Perkeo/Invisible/Invisible,
Charm-tag, Telescope/Observatory Gold-stake configuration is approximately
19-20% more sustained seed throughput than the previously installed release.
The deterministic known-hit example improved by 15.6%. Individual fresh
searches may still finish in seconds or take much longer because match distance
is random; the optimization changes checking speed, not where the next valid
seed happens to lie.

## Validation completed

- Native PGO GENERATE and USE phases each passed all seven regression tests.
- Independent native non-PGO and portable builds also passed all seven tests.
- The final scalar arbitrary-Negative regression passed three consecutive
  runs with zero false negatives.
- Opening scalar, AVX2, and AVX-512 paths were compared over 12,582,912 seeds
  per implementation across ordinary, zero, wraparound, Charm, Soul, Perkeo,
  and locked-resample cases with zero mismatches.
- The final-hash replacement was exhaustively compared for every integer
  numerator from 0 through 10,000,000,000,000 with zero mismatches.
- The single-acquisition timeline path was compared across 700,000 evaluations
  covering one, two, and five targets, duplicates, editions, Gold stake,
  Showman, Invisible aging, and pack/shop sources with zero mismatches.
- The final release accepted known seed `6QUGIBTH` at one, 32, and 36 workers.
- A 10-million-seed run with authoritative fast-filter verification enabled
  completed without a mismatch.
- Native and portable DLLs load and expose all 12 required exported functions.
- All four Lua files compile with Balatro's Lua 5.1 runtime, and Lovely TOML
  parses successfully.
- The installed DLL itself passed the load/export and CPU-mode smoke test after
  deployment.

## User-facing capability now present

The completed v2.8.0 and v2.8.1 work provides:

- a paged menu that stays on-screen;
- fixed Negative Blueprint searching;
- five arbitrary Joker occurrence slots with independent Any/Negative edition
  requirements;
- duplicate Joker targets without one slot erasing another;
- chronological exact/deadline timing through Ante 8, including repeated
  Invisible Joker sale and maturation rules;
- Soul or Judgement starting-Charm acquisition and a requested 0-4 Soul count;
- Any One Suit, fixed Plasma/normal-deck counts, and seeded Erratic counts;
- Gold-stake Eternal-aware duplicate planning;
- Telescope followed by an Observatory deadline;
- configuration-specific time estimates; and
- Balanced or Maximum native CPU scheduling.

See the v2.8.0 notes for the detailed rules and known modeling boundaries for
each feature.

## Updated remaining-work list

There is no known required native correctness fix left in this release. These
are follow-ups, ordered by expected practical value.

1. **In-game smoke test.** Start Balatro and verify one short Plasma or normal
   fixed-deck search, one Erratic search, one repeated Invisible route, one
   arbitrary Negative target, and one Gold-stake Eternal-sensitive route. The
   native, Lua, and patch suites pass, but only the real Steamodded/Lovely
   environment covers every loader and menu interaction.
2. **Empirical estimate calibration.** The estimator intentionally reports a
   broad probability model for very rare conjunctions, and the user's observed
   searches have often beaten it. An opt-in local history of normalized
   configurations, throughput, censoring, and time-to-hit could calibrate the
   display without pretending a random hit is a countdown. It needs versioned
   storage, outlier treatment, a reset control, and privacy-conscious defaults.
3. **ABI-safe SIMD for arbitrary Negative timelines.** Revisit the withheld
   vector kernel using an ABI-safe wrapper, heap-aligned scratch storage,
   hand-written entry shim, or a compiler whose Windows vector-stack contract
   is reliable. It must beat the stable scalar batch by at least 2% end-to-end
   and repeat the full false-negative differential suite before shipping.
4. **Cross-machine Windows release matrix.** Automate scalar-only, AVX2, and
   AVX-512 builds and differential tests on several CPU families. Include Lua,
   TOML, dependency, DLL-load, export, and thread-mode checks.
5. **Conditional deeper prefix sharing.** Prototype the next shared seed-hash
   prefix only if profiling on another important configuration predicts at
   least a 2% whole-search gain. The current prefix-14 route already captures
   the useful locked-tag reuse; earlier variants did not justify more code.
6. **Optional offline helper or GPU experiment.** A separate offline process
   could avoid competing with Balatro's renderer and could search while the
   game is closed. The prior GPU hybrid's advantage narrowed after CPU SIMD,
   so deployment complexity currently outweighs its measured benefit.
7. **Repository cleanup and release commit/tag.** Diagnostic build directories
   and benchmark artifacts were retained as evidence, and no commit or tag was
   created because that was not requested. After the in-game smoke test,
   archive useful measurements, remove unwanted build trees, review the
   source-only diff, and create a release commit/tag if this repository will be
   published.

## Investigated and closed

- A specialized Judgement opening gate is no longer a priority: complete work
  after the opening filter was only 0.486% of the literal configuration's
  profile, so even eliminating it entirely would barely change wall time.
- SIMD widths of six or eight, alternate gather/group layouts, affinity and
  ideal-processor scheduling, 40 workers, alternate chunk sizes, and the final
  exact-safe compiler-flag probe failed the material-improvement threshold.
- The AVX2/AVX-512 arbitrary-Negative prototypes were exact in their kernel
  comparisons but unsafe under the current MinGW/Windows stack ABI; they are
  intentionally absent from production.
- Unsafe floating-point shortcuts remain rejected regardless of benchmark
  speed because they can change the seed result.

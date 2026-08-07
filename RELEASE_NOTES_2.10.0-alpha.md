# Brainstorm v2.10.0-alpha release notes

This release adds a second exact-index family for the Plasma Deck/Gold Stake
route built around a starting Soul Perkeo and a searched Mega Spectral pack.
Its reusable parent accelerates many configurations that share that opening,
while a much smaller child targets the five-Joker NaNEInf core directly.

The central correctness rule remains unchanged: an index is a candidate
planner, not a replacement for simulation. Brainstorm returns a seed only
after the normal authoritative simulator accepts every currently selected
criterion.

> Release status: the full-domain payloads, portable build, native PGO build,
> automated validation, and indexed-versus-raw parity benchmarks are complete.
> The deployment record below is filled from the final live installation.

## New behavior

### Reusable Charm/Perkeo/Mega Spectral parent

The new parent stores every canonical seed ID in the complete
`[0, 2318107019761)` domain that satisfies this baseline:

- Plasma Deck at Gold Stake;
- the Ante 1 Charm Tag opens the starting Mega Arcana pack;
- the effective required Soul count is one;
- the Soul supplies Perkeo, with any edition or stake sticker accepted; and
- the first booster checked by **Booster Pack Search** is Mega Spectral Pack.

This is intentionally a reusable opening anchor. Other Joker, voucher,
Observatory, card-count, edition, timing, and advanced criteria are not baked
into the parent; they are evaluated when each indexed candidate is
authoritatively rechecked.

The Mega Spectral condition concerns the pack type only. It makes no promise
about Cryptid, Ankh, or any other card inside the pack.

### Five-Joker Plasma/Gold child

The child is derived from the complete parent and adds the natural no-reroll
five-Joker baseline:

1. Perkeo from the starting Soul;
2. Blueprint by the end of Ante 4;
3. Brainstorm by the end of Ante 4;
4. Baron by the end of Ante 8; and
5. Mime by the end of Ante 8.

The five names are treated as the exact five target occurrences for index
selection; their UI slot order does not matter because they are distinct. The
stored child accepts any edition or sticker. A query that asks for a Negative
edition or an earlier/fixed timing is narrower than this baseline and can still
use the child, with the active query checked authoritatively. A query that gives
one of the four non-Legendary Jokers a later deadline is broader and therefore
cannot treat a child miss as proof; it falls back to the parent route instead.

Voucher, Observatory, rank, suit, and advanced filters can also narrow the
child safely. They are not precomputed answers and may leave no matching child
candidate in the requested cyclic range.

### Search and estimate routing

For an applicable five-Joker query, Brainstorm tries the child first. If the
child is unavailable or is not trusted as complete, the reusable parent is
next. If no trustworthy complete index can settle the request, ordinary raw
enumeration remains available. Candidate traversal preserves the raw search's
cyclic order around the selected starting seed, including wraparound.

The Estimate page uses the same most-specific-complete-index selection. Its
output names the selected child or parent even when the sampled index contains
zero final matches for additional active constraints, making the chosen route
observable instead of silently reporting an unlabeled sample.

## Safety and exact scope

| Property | Parent | Five-Joker child |
| --- | --- | --- |
| Seed domain | Complete canonical eight-character domain | Complete relative to the full-domain parent |
| Deck/stake | Plasma Deck / Gold Stake only | Plasma Deck / Gold Stake only |
| Starting route | Charm Tag, one effective required Soul, Soul Perkeo | Same |
| Booster criterion | Mega Spectral Pack | Same |
| Joker timeline | Unconstrained after Perkeo | Blueprint + Brainstorm by Ante 4; Baron + Mime by Ante 8; no rerolls |
| Stored editions | Perkeo Any | All five Any |
| Extra active filters | Authoritatively rechecked | Authoritatively rechecked when they narrow the baseline |

Important exclusions and implications:

- A minimum of two, three, or four Souls does not imply the one-Soul parent
  predicate and stays on another applicable route or raw search.
- A second Legendary target likewise raises the effective Soul requirement and
  does not use this parent.
- A non-Plasma deck, a non-Gold stake, another searched booster type, an
  incompatible explicit tag, or Perkeo assigned to a later source is outside
  this family's scope.
- Negative requirements are safe child refinements because **Negative** is a
  subset of the stored **Any Edition** population. They can still be very rare
  within that population.
- Earlier deadlines are refinements; later deadlines are expansions. Only the
  former can use a complete child miss as proof.
- A complete indexed miss proves only that no matching seed exists inside the
  requested cyclic search range. It does not change or relax the query.

Every candidate returned by either payload is passed through the same active
configuration simulator used by raw search. This prevents an index from
returning a seed that fails an added voucher, Observatory, edition, card, or
advanced requirement.

## Payload integrity, build, and provenance

The offline builder divides the domain into 2,159 gap-free `2^30`-ID shards.
A shard carries its predicate hash, exact bounds, record counts, payload
SHA-256, and completion footer. It is written by atomic rename only after it is
complete. A resumed build validates every existing shard before reuse, so a
partial or damaged shard is rebuilt rather than trusted.

The parent verification pass reconstructs the global strictly increasing
sequence and authoritatively revalidates every stored ID. The child is derived
only from that complete parent. A separate `Instance`-entry consistency pass
regenerates the child and requires exact sequence equality. This is a second
route through the production simulator, not a separately implemented Balatro
RNG oracle.

### Final asset record

| Asset | Records | Bytes | SHA-256 | Raw-byte FNV-1a-64 |
| --- | ---: | ---: | --- | --- |
| `charm_perkeo_mega_spectral_anchor_v1.ids` | 1,439,049 | 11,512,392 | `d9a9f4fc710a106d0d8bf5f1dfff7c9c682da3d6c3663955dedd9aaa28d902cd` | `e0bf84e23d4f2856` |
| `charm_perkeo_mega_naneinf_plasma_gold_v1.ids` | 70 | 560 | `bee9ee99625b059b82169882b311557b6491e2649518f9b6b9e313b9236e0841` | `200697665262e061` |

The package also includes the corresponding
`charm_perkeo_mega_spectral_anchor_v1.manifest.json` and
`charm_perkeo_mega_naneinf_plasma_gold_v1.manifest.json` provenance records.
Release builds can enable `BRAINSTORM_REQUIRE_MEGA_INDEX_ASSETS`; configuration
then fails unless both payloads and both manifests are present. The optimized
PGO release workflow enables this requirement so it cannot silently package a
DLL without its indexes.

### Full-domain build record

- Parent predicate SHA-256:
  `50ac1070461be3056e26be990e0870d4adb37e1e6f5fc26a2de78441f2e01fef`.
- Shards completed and verified: 2,159 / 2,159.
- Worker count: 32.
- Reused validated shards: 252; newly scanned IDs: 2,047,524,080,113.
- Completion/resume pass: 1,713.992220 seconds (28.567 minutes).
- Fresh-scan rate: 1,194,593,567 IDs/second, or about 1.195 billion/s.
  At that sustained rate, a cold full-domain pass is about 32.34 minutes.
- Parent authoritative verification: all 1,439,049 records rechecked in
  2.820967 seconds, with zero failures.
- Child derivation and second consistency pass: 6.212576 seconds; both passes
  produced the same strictly ordered 70-record sequence.
- Parent manifest creation: `2026-08-07T05:12:19Z`; child manifest creation:
  `2026-08-07T05:13:11Z`.
- An additional 45-way differential sample across all 15 supported vanilla
  decks at White, Black, and Gold Stake found exact parent membership equality
  over a `2^30`-ID raw sample. Runtime publication remains conservatively
  Plasma/Gold-only.

## Runtime fallback behavior

Payloads are found relative to the loaded DLL, not Balatro's current working
directory. Before a payload may be trusted as complete, the loader enforces a
per-file size limit, eight-byte alignment, nonempty content, strict increasing
order, uniqueness, seed-domain bounds, exact record count, and the release's
hard-coded FNV-1a-64 fingerprint. SHA-256 and predicate details remain in the
manifest and offline verification record.

The failure modes are deliberately conservative:

- A missing, disabled, empty, oversized, truncated, unsorted, duplicate, or
  out-of-range payload is ignored.
- A structurally valid payload whose count or fingerprint does not match the
  release can be used only as a priority list. If it misses, raw search is
  still required.
- Only a payload matching the hard-coded release count and fingerprint is
  marked complete and allowed to prove that an applicable range has no match.
- If the child cannot be trusted, Brainstorm tries the parent. If the parent
  also cannot be trusted, the normal exhaustive path remains intact.
- Every hit from a trusted or priority-only payload is still authoritatively
  revalidated against the complete active configuration.

For diagnostics, `BRAINSTORM_PERKEO_MEGA_ANCHOR_INDEX` and
`BRAINSTORM_PERKEO_MEGA_NANEINF_INDEX` can override the individual asset paths;
setting one to `0` disables that asset. `BRAINSTORM_ANCHOR_PRIORITY=0` disables
index priority routing globally. These are test and troubleshooting controls,
not normal menu settings.

## Performance measurement

The payloads, hard-coded fingerprints, final DLL, and packaged-asset tests were
frozen before measurement. Every row below uses 36 workers, start seed
`11111111`, the full canonical search limit, and the same Ryzen 9 9950X3D
machine. Medians are reported rather than a single best run.

The primary benchmark configuration is:

- Plasma Deck / Gold Stake;
- Charm Tag and one Soul;
- Perkeo from the starting Soul, Any Edition;
- Mega Spectral Pack as the searched booster;
- Blueprint and Brainstorm by Ante 4;
- Baron and Mime by Ante 8; and
- no rerolls, with no additional voucher, Observatory, card, or advanced
  constraint unless a separate row names it.

| Path | Start seed | Search result | Runs | Median wall time | Relative speed |
| --- | --- | --- | ---: | ---: | ---: |
| Complete five-Joker child | `11111111` | `4RH2LW91` | 7 | 0.001007 s | 18,444.2x raw |
| Complete reusable parent, child disabled | `11111111` | `4RH2LW91` | 7 | 0.040698 s | 456.4x raw |
| Raw v2.10 search, both new indexes disabled | `11111111` | `4RH2LW91` | 3 | 18.573289 s | baseline |

The child contains 70 candidates globally. From this starting seed the first
child ID is the winning seed, so the indexed search performs one authoritative
candidate check; the measured time also includes process startup, DLL loading,
payload validation, and thread setup. The parent route processes 10,478
candidates through the winning ID, including loading and fingerprinting its
11 MiB payload, at an effective 257,457 candidates/s. Raw enumeration covers
16,845,684,276 IDs through the same winner at about 906.98 million IDs/s.

The Estimate call evaluates all 70 child candidates, observes all 70 baseline
matches, labels the route `exact_index`, and reports a one-millisecond median
and 90th-percentile search time. Seven Estimate calls had a 4.377 ms wall-time
median. Extra Negative, voucher, Observatory, card, or advanced constraints
can reduce those 70 survivors, but are still checked by the authoritative
simulator rather than assumed from the index.

## Validation gates

The following automated release gates passed:

- the builder self-test, including scalar/AVX2/AVX-512 parity and direct
  authoritative membership checks;
- full parent `verify` across every shard and every stored parent ID;
- child `derive` followed by exact `verify-derived` equality;
- packaged payload count, FNV, SHA-256, manifest, and complete-coverage checks;
- malformed-loader cases for valid priority-only, unsorted, duplicate,
  out-of-range, truncated, empty, missing, and disabled assets;
- route parity with both assets packaged, the child missing, both assets
  missing, explicit disablement, corruption, and priority-only fixtures;
- cyclic candidate-search ordering, multi-block selection, endpoint exclusion,
  and seed-domain wraparound;
- a clean portable Release build and complete test suite;
- a frozen-source native PGO GENERATE/train/USE build and complete test suite;
- live DLL loading plus an in-game indexed search and one raw-fallback search;
  and
- workspace-to-installed hashes for the DLL, both payloads, both manifests,
  and the preserved live configuration.

Final test totals and status:

- builder self-test: passed, including scalar/AVX2/AVX-512 parity;
- parent verify: 1,439,049 / 1,439,049 authoritative records passed;
- child verify: exact 70-record sequence equality passed;
- portable Release: 46 / 46 CTests passed;
- native PGO GENERATE: 46 / 46 CTests passed;
- native PGO USE: 46 / 46 CTests passed; and
- indexed child, parent-only, and raw benchmark paths returned the same first
  seed, `4RH2LW91`.

## Deployment and restart

The final deployment consists of the v2.10 native DLL, the two `.ids`
payloads, their two `.manifest.json` provenance files, and the matching Lua
front end. The existing live `config.lua` must be preserved.

Before replacement, create a timestamped backup of only the runtime files that
will be overwritten. After replacement, compare workspace and installed
SHA-256 values and verify that `config.lua` has the same hash it had before
deployment.

Brainstorm loads these indexes into process-static state. Fully close and
restart Balatro after installing or replacing the DLL or either payload; merely
returning to the main menu does not reload them. On startup, the native log
reports each loaded index's candidate count and whether it is **complete** or
**priority-only**.

### Final deployment record

- Installed version: `Brainstorm v2.10.0-alpha`.
- Installed native DLL: 14,284,006 bytes; SHA-256
  `765e48d1cb1853c569a58e4aaf747a883b7fd70da2ddeae987db5e183d177370`.
- Installed parent payload SHA-256:
  `d9a9f4fc710a106d0d8bf5f1dfff7c9c682da3d6c3663955dedd9aaa28d902cd`.
- Installed child payload SHA-256:
  `bee9ee99625b059b82169882b311557b6491e2649518f9b6b9e313b9236e0841`.
- Installed parent/child manifest SHA-256 values:
  `34f2e0bc97c1a7e222360cc61931e3777eff5049ffe16621cd0871e499146650`
  and `cb655b4ec8e7307cc3999f6267b305d4a48e76bac15a0670c177e293f8b9caa9`.
- Pre-release backup:
  `C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\20260807-002443-pre-v2.10.0-alpha`.
- Live `config.lua` SHA-256 before and after deployment:
  `16033cbd68f825f3380637290c2acd8ed2fdcc6ea8c0589c6555698119c35ede`.
- Workspace/installed hash parity: exact for the DLL, two payloads, two
  manifests, `Core/Brainstorm.lua`, and `steamodded_compat.lua`.
- Direct live-file DLL smoke: the exact child loaded as 70 **complete**
  candidates and returned `4RH2LW91`; a broadened Blueprint deadline selected
  the 1,439,049-record **complete** parent and returned the same seed.

## Remaining work

1. **Exercise the real game integration.** On a fully restarted Balatro, test
   the exact five-Joker route, a narrower Negative or Observatory route, a
   reusable-parent query, and a deliberately disabled/missing-index raw
   fallback. Confirm that Plasma Deck and Gold Stake are reflected in the live
   call.
2. **Bind resumable shards to implementation sources.** Shards currently carry
   the exact predicate string and its SHA-256. Future long-running builders
   should additionally hash every simulator and RNG source file that can
   influence membership, so a source edit cannot reuse semantically stale
   shards unless an explicit compatibility decision is recorded.
3. **Make payload copying a first-class build dependency.** Asset discovery and
   route-test registration are intentionally configure-time today. A future
   packaging target should depend directly on each payload and manifest so an
   asset-only change retriggers copying without requiring a fresh configure.
4. **Generalize beyond one Soul.** The v2.10 parent does not accelerate the
   user's two-to-four-Soul or multiple-Legendary plans. A future family should
   index multi-Soul visibility and compact Legendary identity/edition
   signatures, with explicit handling of duplicate ownership rules.
5. **Broaden deck/stake coverage only with proof.** The current family is
   deliberately Plasma/Gold-only. A reusable cross-deck parent should be
   published only after full-domain proof establishes which opening and booster
   outcomes are genuinely invariant; later-timeline children should remain
   scoped wherever shop, voucher, sticker, or ownership state differs.
6. **Replace hard-coded routing with a typed predicate catalog.** A general
   planner could compose complete parents, children, and safe refinements while
   making the subset/superset proof explicit. It should preserve the current
   distinction between complete proof sets and priority-only hints.
7. **Add compact encodings when the catalog grows.** Raw sorted `uint64_t`
   payloads are simple and fast for this release. Elias-Fano, parent-ordinal
   children, per-shard counts, or compressed postings become worthwhile if
   multi-Soul and arbitrary-Joker catalogs make distribution size material.
8. **Add an optional derived-query cache.** Once a complete parent has been
    exhausted for a normalized downstream query, a versioned checksummed local
    child could make repeated custom voucher, Observatory, edition, and timing
    combinations immediate without distributing every niche intersection.
9. **Calibrate estimates from opt-in observations.** Complete indexes make
    their candidate populations exact, but uncommon downstream refinements may
    still yield noisy time estimates. Versioned local throughput and censored
    time-to-hit history could improve those estimates without weakening their
    uncertainty labels.
10. **Expand the release matrix.** Test the portable scalar path and native
    AVX2/AVX-512 paths on additional Intel and AMD Windows machines, then clean
    or archive diagnostic build trees before a public release commit and tag.

## Related records

- [v2.9.0-alpha release and seed-structure notes](RELEASE_NOTES_2.9.0-alpha.md)
- [Offline v2.10 index-builder instructions](Immolate/build-charm-perkeo-mega-index/README.md)
- [v2.8.1-alpha optimization record](RELEASE_NOTES_2.8.1-alpha.md)

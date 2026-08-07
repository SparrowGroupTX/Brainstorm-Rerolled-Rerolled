# Broader exact seed-index architecture

This is a diagnostic design note only. It does not modify production or the
installed mod. It extends the narrow Perkeo + Invisible starting-pack index
into a reusable acceleration system for the criteria currently exposed by the
Brainstorm UI.

## Executive conclusion

There is no measured seed-text ordering or algebraic inverse that safely skips
large regions. The held-out 4-billion-seed study found no reproducible lift in
characters, prefixes, suffixes, ID strides, intermediate hashes, Hamming
neighbors, or alternate enumeration orders. Direct reciprocal/fract inversion
and a four/four meet-in-the-middle both expand to the original domain or worse.

The practical hidden structure is instead **reuse across queries**. Balatro's
seed map is effectively pseudorandom, but many expensive user queries imply the
same rare opening event. Exhaust that opening event once, store its exact seed
IDs, and answer all stricter queries from the much smaller population. The
right design is a hierarchy of exact necessary-condition indexes, not a giant
database of every event and not a predictor.

The three highest-value reusable assets are:

1. the current Perkeo + Invisible starting-pack anchor (about 213,000 IDs,
   1.63 MiB raw or 0.67 MiB Elias-Fano);
2. a Charm + at-least-two-Souls anchor (about 13.83 million IDs, 105.5 MiB raw
   or about 33.4 MiB Elias-Fano), with tiny nested children for three and four
   Souls; and
3. Negative Legendary anchors (Negative Perkeo alone projects about 1.38
   million IDs and about 3.9 MiB Elias-Fano; all five Legendary variants should
   be roughly 20 MiB when kept as separate postings).

Those assets are small enough to distribute and remove between roughly
1.7 million and 168,000 raw seed evaluations per indexed candidate. The
current starting-pack pair removes about 10.9 million raw evaluations per
candidate. A broader Perkeo-only parent is useful for offline derivation but is
too large for the default mod bundle: about 461 million IDs and 837 MiB in the
measured Elias-Fano estimate.

## Evidence and exact size projections

The universe is `U = 2,318,107,019,761` canonical seed IDs. Measured values are
from the existing 4-billion-seed and 100-million-seed probes. Soul-count-only
rows use the exact UI model of five independent `p = 0.003` Soul rolls after a
Charm tag; they are projections and must be replaced by builder counts before
release.

| Necessary predicate | Probability / measured density | Projected IDs | Raw `uint64` | Approx. Elias-Fano | Raw-domain reduction |
|---|---:|---:|---:|---:|---:|
| Charm + Soul + specific Legendary (Perkeo measured) | 1 / 5,030.69 | 460.79 M | 3.43 GiB | 837 MiB | 5,031x |
| Charm + at least 2 Souls | 1 / 167,670 | 13.825 M | 105.5 MiB | 33.4 MiB | 167,670x |
| Charm + at least 3 Souls | 1 / 55.8 M | 41,538 | 324.5 KiB | 145 KiB globally; smaller as child ordinals | 55.8 Mx |
| Charm + at least 4 Souls | 1 / 37.1 B | about 62 | 500 bytes | a few hundred bytes | 37.1 Bx |
| Charm + Soul + Negative Perkeo | about 1 / 1.677 M | 1.382 M | 10.55 MiB | 3.9 MiB | 1.68 Mx |
| Perkeo + Invisible in starting pack (measured) | 1 / 10,869,565 | 213,266 | 1.63 MiB | 0.67 MiB | 10.87 Mx |
| Previous row + Ante-2 Invisible (measured sample) | about 1 / 800 M | about 2,898 | 22.6 KiB | 11.2 KiB globally; about 3 KiB as parent ordinals | 800 Mx |

For comparison, a full-domain bitset is about 270 GiB **per predicate**. A tag
or first-voucher bitmap is therefore a poor distributed asset even though the
predicate itself is cheap. Uniform random sparse sets also do not compress well
with run-length schemes. Elias-Fano or bit-packed deltas are the appropriate
default for the measured distributions.

### Important scope observation

The current pair builder describes its predicate as Plasma Deck + Gold Stake,
but the indexed opening facts appear independent of both:

- `setDeck` only pre-activates Crystal Ball, Telescope, Tarot Merchant, Planet
  Merchant, and Overstock for the affected vanilla decks. None changes the
  Charm tag, Soul/Tarot slots, or Soul/Judgement Joker generation.
- Soul and Judgement call `nextJoker(..., stickerGeneration=None)`, so stake
  cannot change those starting-pack outcomes.
- Hone/Glow Up and Omen Globe are not starting-deck vouchers.

After a cross-deck/stake differential test, the same pair payload should be
usable for every supported vanilla deck and stake. Later shop, sticker, voucher,
rank, and duplicate behavior remains in the authoritative query verifier. This
broadening costs no additional index bytes and greatly increases reuse.

## Query model: predicates, implication, and branches

Normalize every UI configuration into a typed predicate AST rather than
matching display strings. Relevant primitive families are:

- opening tag and starting Charm-pack visibility;
- minimum Soul count, selectable Legendary outcomes, and per-Joker Negative
  flags;
- selectable Judgement outcome;
- natural shop/Buffoon Joker occurrences by exact Ante or cumulative deadline;
- duplicate ownership/sale state, Invisible maturation, Showman, and Gold-stake
  Eternal restrictions;
- first voucher or the ordered Telescope -> Observatory chain;
- displayed booster pack;
- Erratic rank/suit counts (fixed-deck counts should stay deterministic); and
- legacy custom presets.

An index predicate `P` is a complete candidate generator only when the query
`Q` logically implies `P` (`Q => P`). Examples:

- Negative Perkeo in the starting Soul implies any-edition Perkeo there.
- at least four Souls implies the at-least-three and at-least-two anchors.
- Perkeo + Invisible both explicitly in the starting Charm pack implies the
  current pair anchor.
- Perkeo + Invisible **by Ante 2** does *not* imply the starting-pack pair,
  because Invisible may occur naturally later. The pair can be searched first
  as a fast branch, but raw search remains necessary if that branch misses.

The distinction should be explicit in the plan:

1. **complete plan** -- a validated full-domain superset; safe to skip all IDs
   outside the index and able to preserve the earliest cyclic result;
2. **priority branch** -- an exact but non-exhaustive route checked first, then
   the normal raw search; always returns a criterion-valid seed but may not be
   the same earliest seed as sequential enumeration; and
3. **derived exact cache** -- a fully exhausted parent population for a
   normalized query, making subsequent runs complete and immediate.

Intersections of applicable necessary-condition sets remain safe and are often
much narrower. Unions are required when separate indexes cover alternative
routes. Never turn an OR branch into an AND requirement.

## Storage design

### A parent/child forest

Represent assets as a forest instead of unrelated global ID lists:

```text
canonical seed universe
|-- Charm + >=2 Souls                         (~13.825M IDs)
|   |-- >=3 Souls                             (~41.5k parent ordinals)
|   |   `-- >=4 Souls                         (~62 parent ordinals)
|   `-- selectable Soul outcome signatures
|-- Charm + Soul + Negative Legendary
|   |-- Canio
|   |-- Triboulet
|   |-- Yorick
|   |-- Chicot
|   `-- Perkeo                                (~1.382M IDs)
`-- Perkeo + Invisible in starting pack       (~213k IDs)
    |-- extra Invisible exact/by Ante children
    |-- Negative-edition children
    |-- Telescope/Observatory deadline children
    `-- local normalized-query result caches
```

A child stores ordinal positions in its parent, not 64-bit global IDs. The
Ante-2 Invisible child, for example, has density about 1/74 inside the 213k
parent. Its global list is about 11 KiB Elias-Fano, while a parent-ordinal list
is only a few KiB. More importantly, one uncompressed bitvector over the 213k
parent costs only about 26 KiB, so dozens of downstream facts remain cheap.

### Codecs by cardinality

- Up to roughly 250,000 IDs: sorted little-endian `uint64_t`. It is simple,
  cache-resident, and already only 1.63 MiB for the pair anchor.
- Larger uniformly sparse populations: Elias-Fano with rank/select and
  `lower_bound`, or a blockwise equivalent with bit-packed low bits.
- Child sets over a small parent: plain bitvectors when moderately dense;
  Elias-Fano parent ordinals when sparse.
- Very small derived sets: raw parent ordinals or raw global IDs.
- Roaring64 is acceptable for interoperability, but for effectively random
  global IDs it will generally lose to Elias-Fano. Run-length and prefix tries
  have no measured structure to exploit.

Shard every file by a stable high-ID range (the current `2^30`-ID builder shard
is suitable). Each shard gets a count, minimum/maximum, checksum, and codec
offset. A top directory maps canonical ranges to byte spans, allowing a cyclic
limited search to map only the required pages.

### Manifest and semantic ABI

Every asset needs:

- magic, format/codec version, parent asset ID, and predicate ID/revision;
- exact covered domain and record count;
- canonical predicate AST/hash;
- seed alphabet/ID mapping and RNG semantic fingerprint;
- game version, pool/unlock model, Showman assumptions, and only the deck/stake
  assumptions that truly affect membership;
- payload and per-shard hashes; and
- a completion footer written only after all shards cover the domain exactly.

Runtime should reject a stale or partial *complete* asset. An invalid asset may
still be used only as a priority hint if every returned seed is authoritatively
verified and raw fallback remains enabled. The two trust modes should not share
an ambiguous loader API.

## Per-event signatures: where they help

Rich records are valuable only after a rare parent has made the row count
small.

### Multi-Soul signature (high value)

For each of the 13.825M at-least-two-Soul IDs, store only the facts the UI can
ask about:

- visible Soul count, capped to 2/3/4;
- the first and second selectable Legendary IDs (three bits each); and
- their Negative flags (one bit each).

Ten to twelve bits per row is enough, roughly 17-20 MiB in addition to the
33.4 MiB compressed seed IDs. This one roughly 50 MiB asset answers any legal
two-Legendary/edition/minimum-Soul starting-pack combination by a memory scan,
then passes survivors through the authoritative simulator. Store the >=3 and
>=4 ordinal children so high-count queries do not scan all 13.8M rows.

### Perkeo + Judgement catalog (high value, optional)

The measured Invisible pair is a rare-Joker member of a broader useful family:
Perkeo from the Soul, a visible/selectable Judgement, then one non-Legendary
Judgement outcome. Using the measured rare-target density and the game's
70%/25%/5% common/uncommon/rare split suggests roughly 80-90M total records
across the ordinary Joker pool. A compact catalog can store:

- the global seed-ID parent (Perkeo + visible Judgement);
- one-byte Judgement Joker ID;
- Perkeo/Judgement Negative bits; and
- per-target parent-ordinal postings.

The expected compressed footprint is on the order of a few hundred MiB, not
terabytes. Sharding it by Legendary makes Perkeo an installable optional pack;
building all five Legendary variants would be several times larger. This is
the best broad accelerator for "any Joker in my starting pack" while preserving
the two-choice rule.

### Later-event ledgers (restricted value)

Do not serialize a universal Ante-1-to-8 Joker timeline. Shop and Buffoon
outcomes depend on acquired/locked Jokers, Showman, selling, duplicate order,
deck shop rates, stake stickers, and starting-pack branch choices. A single
query-independent event log would either be wrong or would need a state-space
explosion.

On the 213k pair parent, however, rerunning the authoritative timeline is cheap.
Derived child sets for exact configurations or carefully defined state
scenarios are preferable to brittle serialized `Instance` snapshots. If event
columns are added, include a prerequisite-state fingerprint with every column
and continue to verify final seeds authoritatively.

## Adaptive query planner

The planner should do the following for every search:

1. Normalize UI values, including duplicate occurrence order, edition, exact
   versus deadline timing, deck/stake, Soul count, voucher route, and rank/suit
   semantics.
2. Ask the catalog for every predicate implied by the query.
3. Estimate candidate count in the requested cyclic range from per-shard
   counts. Estimate verification cost from maximum requested Ante, duplicate
   mode, stake, and measured per-candidate timings.
4. Choose among raw SIMD, one index, an intersection, a union of complete
   branches, or an opportunistic priority branch.
5. Start with the smallest posting. Intersect a tiny list against larger lists
   with galloping/binary membership; use bitwise AND for siblings sharing a
   parent. Avoid materializing/sorting `(offset, id)` records.
6. Traverse the already-sorted candidates as two `lower_bound` spans: start to
   domain end, then zero to wrapped end. Cap workers to available candidate
   blocks and retain the smallest successful cyclic offset.
7. Run the ordinary authoritative configured filter on every surviving seed.
8. If a priority branch misses, continue through raw SIMD. If a trusted
   complete plan misses, it is a true no-result for the searched range.

The cost threshold matters. The 461M-ID Perkeo-only list has an excellent
5,000x enumeration reduction, but authoritative reconstruction of hundreds of
millions of candidates can still be slower than the highly optimized opening
SIMD. It should be benchmarked and may be a derivation asset rather than a
runtime plan. Conversely, 213k, 41k, or 1.4M candidates are clear runtime wins.

### Estimate integration

Time estimates must describe the chosen plan, not continue dividing raw seed
distance by raw SIMD throughput. Report:

- selected accelerator and whether it is complete, priority-only, or cached;
- candidates in the requested range and measured candidate verification rate;
- observed conditional hit count/rate in the parent population; and
- raw fallback cost when a priority branch can miss.

Once a parent has been exhausted for a normalized query, its exact match count
is better evidence than the current staged independence estimate. It also
explains why a nominally eight-minute raw estimate can become a sub-second
indexed query.

## Offline builder architecture

Do not pay one full-domain pass per asset. Extend the resumable builder into a
multi-output pipeline:

1. Enumerate a shard once with the current exact SIMD seed/opening machinery.
2. Emit nested Soul-count populations in the same pass.
3. For rare survivors, run the same authoritative pack simulator and capture
   Legendary, Negative, Judgement, and selection-signature outputs.
4. Append records to predicate-specific shard writers. Each writer has bounded
   buffers and its own completion hash.
5. Merge and compact only after every shard validates.
6. Derive children from parents without rescanning the universe.

At the measured 701.8M raw seeds/s, an opening-only universe pass is about
55 minutes; the existing exact pair design conservatively budgets 62-76
minutes. Multi-output extraction should turn that one hour into several useful
assets. Capturing all Perkeo/Judgement targets adds work only on opening
survivors and is far cheaper than 145 separate full scans.

Build-time and ship-time artifacts should be separated:

- **warehouse/build only:** 461M-ID Perkeo parent, raw shard records, verbose
  signatures;
- **core distribution:** current pair anchor, small manifests, perhaps
  Negative Legendary postings;
- **optional accelerator pack:** >=2-Soul signature asset and Perkeo/Judgement
  catalog; and
- **local cache:** user-specific derived predicate children with an LRU size
  cap and a reset control.

A crowd/distributed builder can claim signed shard ranges and reduce wall time,
but it is not required on this machine. Reproducibility is established by
identical final count/hash across worker counts and backends.

## Local derived-query cache

This is the most flexible extension after the first index ships.

When a user searches a query under a small complete parent, optionally exhaust
the whole parent in the background (or while Balatro is closed), not merely up
to the first hit. Store the matching parent ordinals under:

```text
semantic-RNG hash + parent payload hash + normalized query AST hash
```

Future starts, search limits, or reruns of that configuration become one
`lower_bound` lookup. Closely related queries can reuse less-specific cached
children. A cache entry is exact only if the complete parent range was scanned;
partial entries are priority hints and must record coverage intervals.

This approach supports arbitrary later Jokers, duplicates, editions, voucher
deadlines, and stake behavior without creating a universal combinatorial index.
It also learns the user's actual recurring search family rather than bloating
the release with every possible five-slot query.

## Ranked additional assets

### 1. Finish and ship the current pair anchor

Expected impact: transformative for the literal Perkeo + starting-pack
Invisible family; the full population is only about 213k. Validate manifest,
checksum, complete coverage, cyclic equivalence, corruption fallback, and
release packaging. Then broaden deck/stake applicability if differential tests
confirm the source-level independence above.

### 2. Build the >=2-Soul signature hierarchy

Expected impact: the largest general-purpose reduction per distributed byte.
It directly targets the UI's new 2/3/4-Soul capability and arbitrary multiple
Legendary targets. One roughly 50 MiB asset covers all target names and Negative
choices allowed by the two-selection rule.

### 3. Build Negative Legendary postings

Expected impact: very high for a few MiB each, especially Negative Perkeo. They
also accelerate legacy Negative Perkeo and combined custom filters. Generate
all five in one pass.

### 4. Add parent-ordinal derived children for the user's route

Starting with the pair parent, derive:

- another Invisible at exact Ante 2 and cumulative deadlines;
- Negative requirements for each occurrence;
- first reachable Telescope and Telescope -> Observatory completion Ante; and
- commonly used conjunctions.

The measured Ante-2 child projects only about 2,900 global IDs. Most of these
children will be KiB-scale and can make the recurring Gold-stake NanEInf route
effectively immediate.

### 5. Build an optional Perkeo + Judgement catalog

Expected impact: broad support for any non-Legendary starting-pack target at a
few-hundred-MiB cost. Capture all targets in one full-domain build and shard by
Legendary. Do not ship all five Legendary catalogs by default.

### 6. Retain a Perkeo-only parent for offline derivation

Expected impact: lets an offline helper derive arbitrary later-Joker/deadline
indexes without another 2.3T-seed scan. Its roughly 837 MiB compressed size and
461M authoritative candidates make it questionable for direct in-game use.

### 7. Add sparse Erratic tail indexes only from actual demand

Fixed decks need no seed index. For Erratic, high rank/suit thresholds can be
rare enough for sparse postings, but common thresholds would create enormous
assets. First record query frequency and measure exact tail cardinalities;
index only thresholds that beat the planner's byte/latency threshold. Store
nested threshold children because `count >= x+1` implies `count >= x`.

## Low-value or rejected broad assets

- Per-tag and first-voucher full-domain indexes: each common category contains
  hundreds of billions of IDs; bitsets are hundreds of GiB and postings are
  worse than computing the cheap RNG event.
- Observatory-by-deadline as a global index: the measured Ante-2 conditional
  rate is about 0.39%, still billions of IDs and many GiB compressed. It is
  excellent only as a child of a rare opening parent.
- Full global shop/Buffoon event database: state-dependent and combinatorial.
- Full-domain bitmaps, tries, run-length encoding, seed-prefix rankings, and
  Gray/transposed traversal: the measured output behaves randomly at relevant
  spacing.
- Bloom/Xor filters as the only index: useful as membership sidecars, never as
  an exact enumerator, and cannot prove a seed is absent.
- Serialized post-pack `Instance` objects: brittle across semantic revisions
  and unnecessary at 213k candidates.

## Contrarian avenues worth bounded tests

1. **Batch many user queries in one candidate pass.** If the user explores
   several Joker/deadline combinations, evaluate all normalized plans against
   each parent candidate once and emit several children. This is a database
   workload, not repeated search.
2. **Persistent covered-interval cache.** When a search is cancelled, remember
   exact scanned intervals for its semantic query so a restart does not repeat
   them. This is especially useful when no complete parent exists.
3. **External/offline helper.** Keep the large Perkeo warehouse outside
   Balatro, derive a tiny signed child, then let the in-game mod consume it.
   This avoids renderer contention and keeps the mod bundle small.
4. **State-automaton memoization on a rare parent.** For repeated Invisible
   routes, canonicalize only the small ownership/age/sale state and memoize
   transitions per seed. Test it on the 213k parent; abandon it if query setup
   or cache traffic exceeds direct simulation.
5. **Succinct categorical wavelet matrix.** A Perkeo/Judgement catalog could
   store the target Joker column as a wavelet matrix, supporting `rank/select`
   for any Joker without 145 separate files. This is technically attractive
   if a direct-postings implementation becomes unwieldy, but benchmark it
   against simple per-target parent ordinals.
6. **Content-addressed community shards.** Shards built on different machines
   can be merged only when semantic fingerprints and overlapping-range hashes
   agree. This reduces one-time construction time, not query complexity.

SAT/SMT inversion, binary decision diagrams over eight characters, and learned
seed rankings are much lower probability. Existing inversion and held-out
statistics already give strong reasons to stop unless a new mathematical
constraint is found.

## Concrete integration sequence

1. Finalize the current pair payload and trusted manifest; package it beside
   every native/portable DLL.
2. Split the loader into validated complete-index and untrusted priority-hint
   APIs. Preserve raw fallback for the latter.
3. Replace per-query candidate sorting with two sorted cyclic spans and add
   candidate progress reporting.
4. Introduce the normalized predicate AST, explicit implication functions, and
   catalog. Start with only the pair predicate so behavior is testable.
5. Add parent IDs and parent-ordinal codecs plus intersection/union tests.
6. Extend the offline builder to emit >=2/3/4 Soul populations, two selectable
   Legendary IDs, and Negative bits in one pass.
7. Differential-test scalar/AVX2/AVX-512 builders, worker counts, decks/stakes,
   ordinary/wrapped/truncated ranges, editions, duplicates, and deliberately
   corrupt/partial files.
8. Add plan-aware estimates and UI status (`Exact index`, `Priority route`,
   `Raw search`, or `Cached exact result`).
9. Add local derived children with full/partial coverage metadata and an LRU
   limit.
10. Only then consider the optional Perkeo/Judgement catalog and build-only
    Perkeo warehouse.

## Plausible ceiling

For one-off arbitrary criteria with no reusable rare implication, the ceiling
remains the optimized raw engine plus modest constant-factor improvements; the
statistical and inversion work found no route to skip most seeds.

For queries under a rare complete parent, the ceiling changes qualitatively:
raw seed enumeration disappears. The pair anchor reduces a 2.318T universe to
about 213k authoritative checks, and the measured Ante-2 child to only a few
thousand. A fully derived exact query becomes a disk lookup. Depending on how
much later-Ante simulation remains, practical repeated-query improvements can
reasonably range from hundreds-fold to effectively instantaneous, with the
theoretical enumeration reduction reaching millions-fold. The gain comes from
amortizing one exhaustive build, not from predicting Balatro's pseudorandom
outputs.


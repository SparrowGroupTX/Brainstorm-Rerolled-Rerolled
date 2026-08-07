# Exact rare-anchor index design (diagnostic proposal)

This proposal intentionally lives outside the production source tree.  It is
for the literal Gold-stake / Plasma-deck search family whose starting Charm
pack must yield Perkeo and Invisible Joker, with a later Invisible Joker and
voucher conditions checked by the authoritative simulator.

## Why this anchor

An exact 4,000,000,000-seed contiguous probe starting at canonical seed ID 8
measured:

| stage | matches | raw probability |
|---|---:|---:|
| Charm + at least one Soul + Soul produces Perkeo | 794,671 | 1 / 5,033.5 |
| same starting Charm pack can produce Perkeo and Invisible Joker | 368 | 1 / 10,869,565 |
| plus Invisible Joker in the Ante-2 no-reroll window | 5 | 1 / 800,000,000 |
| plus first voucher Telescope | 1 | 1 / 4,000,000,000 |

The first-stage SIMD scan took 7.911 seconds with 36 workers.  Extrapolating
the second row to the 2,318,107,019,761-seed domain gives about 213,000 IDs.
That is only about 1.63 MiB (1.71 MB) when stored as uncompressed 64-bit IDs and removes
about 10.9 million raw enumerations per indexed candidate.

The recommended first index is the second row.  It is selective while still
being reusable when the later Invisible deadline, editions, or voucher
deadline change.  An optional derived index for the third row should contain
only a few thousand IDs and is useful when the exact Ante-2/no-reroll timing is
selected.

## Exact anchor predicate

The builder must not reproduce RNG logic in a new, approximate predicate.  It
must call the same authoritative simulator used by normal searches, after the
existing exact opening SIMD prefilter.  The normalized anchor is:

* canonical seed ID in `[0, 2,318,107,019,761)`;
* Plasma Deck, Gold Stake, complete profile unlock model, Showman absent;
* lock-aware Ante-1 tag generation resolves to Charm Tag;
* the Charm Tag Mega Arcana pack has five generated cards and two choices;
* single-Soul generation semantics (`allowDuplicateSouls == false`);
* a selectable Soul produces Perkeo, any edition/sticker; and
* a selectable Judgement in that same pack produces Invisible Joker, any
  edition/sticker.

In current code terms, configure a search containing only `Perkeo` and
`Invisible Joker`, both with location `soul_pack`, Charm Tag, one Soul, Plasma
Deck, Gold Stake, and any editions.  First run
`openingCharmSoulBatchPrefilter()` with one Soul and Perkeo's legendary index;
then run the authoritative configured filter for every survivor.  The
authoritative second call is what establishes index membership.

The single-Soul qualification is important.  Asking for two or more Souls
changes pack-generation semantics by allowing duplicate Souls, so the
single-Soul index is not assumed to cover those searches.

## Stable file format: `BSRAIDX1`

Use a simple sorted array of canonical little-endian `uint64_t` seed IDs in
version 1.  Saving roughly 1 MiB with Elias-Fano or varints is not worth a more
fragile decoder in the first implementation.

The file consists of a 256-byte header, the payload, and a 64-byte footer.
All integers are little-endian.

### Header (256 bytes)

| offset | size | field |
|---:|---:|---|
| 0 | 8 | magic `BSRAIDX1` |
| 8 | 4 | format version (`1`) |
| 12 | 4 | header bytes (`256`) |
| 16 | 4 | codec (`0` = sorted LE `uint64_t`) |
| 20 | 4 | record bytes (`8`) |
| 24 | 8 | covered domain begin (`0`) |
| 32 | 8 | covered domain end, exclusive (`2,318,107,019,761`) |
| 40 | 8 | record count |
| 48 | 8 | payload byte count |
| 56 | 8 | predicate ID |
| 64 | 8 | predicate revision |
| 72 | 8 | builder shard size |
| 80 | 8 | semantic flags |
| 88 | 32 | seed/RNG semantic SHA-256 fingerprint |
| 120 | 32 | canonical predicate SHA-256 fingerprint |
| 152 | 32 | payload SHA-256 |
| 184 | 32 | builder/source metadata SHA-256 (informational) |
| 216 | 8 | creation time (Unix seconds, informational) |
| 224 | 8 | build duration in milliseconds (informational) |
| 232 | 24 | zero-reserved bytes |

The semantic fingerprint covers the seed alphabet and ID mapping, pseudohash
constants and operation order, round-13 behavior, Lua RNG behavior, relevant
item arrays/locks, and pack/Joker generation semantics.  It is a deliberately
versioned semantic ABI, not a compiler or optimization fingerprint.  The
predicate fingerprint is SHA-256 of a canonical UTF-8 descriptor containing
every bullet in the exact predicate above.  Any relevant behavior change
therefore invalidates the index.

### Payload

`record_count` strictly increasing canonical IDs.  There are no duplicates,
no IDs outside the covered half-open domain, and
`payload_bytes == record_count * 8`.

### Completion footer (64 bytes)

| offset | size | field |
|---:|---:|---|
| 0 | 16 | completion magic `BSRAIDX-DONE-v1` |
| 16 | 8 | duplicate record count |
| 24 | 8 | duplicate payload byte count |
| 32 | 32 | duplicate payload SHA-256 |

The loader accepts a file only when the exact length, both magics, both
fingerprints, duplicated metadata, SHA-256, sortedness, uniqueness, bounds,
and full-domain coverage all validate.  Any failure silently disables the
optimization and uses the existing raw search, so a corrupt/stale/partial file
cannot create a false negative.

## Crash-safe, resumable full-domain builder

1. Divide `[0, SEED_DOMAIN_SIZE)` into fixed `2^30`-ID half-open shards.  This
   yields about 2,160 shards and roughly one minute of work per shard/core at
   observed rates, providing useful restart granularity.
2. A worker claims one shard, scans it in existing exact SIMD batches, and
   applies the authoritative anchor predicate only to opening survivors.
3. It writes the shard's sorted IDs to `shard-N.tmp`, writes a shard completion
   footer and hash, flushes and closes it, then atomically renames it to
   `shard-N.complete`.  A cancelled run retains completed shards.
4. On restart, validate each completed shard's predicate fingerprints, exact
   half-open range, payload hash, ordering, and footer.  Rescan only missing or
   invalid shards.
5. After every shard is valid, verify the shard ranges cover the entire domain
   exactly once with no gaps or overlaps.  Concatenate their already sorted
   payloads, construct the finalized header and footer in
   `anchor.bsidx.tmp.<pid>`, flush it, and atomically replace `anchor.bsidx` on
   the same volume.  Keep any previous valid final index until this last swap.
6. Delete shard files only after reopening and fully validating the installed
   final file.

The expected one-time build is about 62--76 minutes at the measured 36-worker
opening rates.  It can run offline in CI and the resulting roughly 1.7 MiB
index (about 1.63 MiB) can be bundled, avoiding any build delay for users.  A local builder
should support cancellation and a lower worker cap, but an incomplete index is
never used for skipping.

## Transparent applicability and fallback

Treat an index predicate as a necessary-condition set.  Use it only if a
normalized query logically implies that predicate and the file fingerprints
match the running simulator.  For the first index this requires, at minimum:

* the same deck/stake/unlock/Showman and single-Soul pack semantics;
* a required starting Charm route;
* a `Perkeo` target constrained to the starting Soul pack; and
* an `Invisible Joker` target constrained to that starting pack.

Stricter editions or extra later targets are safe: the any-edition anchor is a
superset and the authoritative query filter will enforce the stricter facts.
Two-or-more-Soul searches, different starting-pack semantics, or a location
that permits Perkeo/Invisible outside the starting pack are not safe and must
fall back to raw enumeration.  Implement this as an explicit predicate-ID
specific implication function; do not infer it from display strings.

If several valid indexes apply, use the narrowest necessary-condition set:

1. optional `pack pair + Ante-2 no-reroll Invisible` derived index;
2. `starting-pack Perkeo + Invisible` index;
3. existing raw SIMD search.

Missing, stale, corrupt, partial, or inapplicable indexes always select step 3
without changing search results.

## Indexed search ordering

For start ID `S` and raw search limit `L`, preserve the current cyclic seed
order.  Use two `lower_bound` spans over the sorted payload: first IDs in
`[S, min(domain, S + L))`, then (when the range wraps) IDs in
`[0, (S + L) mod domain)`.  Associate each ID with its cyclic raw offset and
run the full authoritative configured filter.  This preserves exactness and
produces the same earliest valid seed as a sequential raw scan.

Parallel workers should consume contiguous ranges of this cyclic candidate
sequence.  A result is final only after every earlier range is known not to
contain a match; equivalently, atomically retain the smallest successful cyclic
offset and finish all ranges whose start precedes it.  A persistent worker pool
avoids making thread creation the dominant cost.  Progress may report both
`indexed candidates checked` and the equivalent raw-domain span skipped.

The first release should deliberately rerun the full authoritative filter,
including the starting pack, for every indexed ID.  This makes the index only
a candidate enumerator and provides a second exactness guard.  An
`after-anchor` continuation can be considered later, but it is not needed for
the expected latency.

## Expected query latency and richer records

The full-domain list is about 213,000 IDs.  Mapping and hashing a 1.63 MiB file
should take only a few milliseconds.  A conservative estimate for rebuilding
the seed, revalidating the pack, and simulating later windows is roughly
0.2--3 seconds for full exhaustion on this 36-worker machine, depending on the
latest requested ante.  Time to the first result is normally much lower: the
4B probe found the Ante-2 Invisible condition in 5 of 368 pack anchors (about
1 in 74), so only a small prefix of the indexed candidates is normally tested
before later voucher probabilities are applied.  This range should be
confirmed by a controlled A/B once an actual full index exists.

Richer per-ID records are not recommended initially:

* cached seed hashes/RNG state tie the file to floating-point implementation
  details and save little at 213,000 candidates;
* pack positions, editions, and sticker bits duplicate facts the
  authoritative filter can cheaply regenerate; and
* serialized post-pack `Instance` state would be large and extremely brittle.

A separate derived index is more valuable than richer records.  From the
starting-pack index, build an optional second sorted-ID file for the literal
Ante-2/no-reroll Invisible condition.  The 4B sample projects about 2,900 IDs
for the full domain (with a wide confidence interval because only five were
observed), so this file should be only tens of KiB and voucher/deadline variants
would be effectively immediate.

## Required validation before production use

* Compare prefilter-plus-anchor membership to direct authoritative membership
  over many small contiguous ranges, all seed lengths, and domain wrap points.
* Require bit-identical candidate lists from scalar, AVX2, and AVX-512 builder
  backends on shared fixtures.
* Build with several worker counts and require the same record count and
  payload SHA-256.
* Differential-test indexed versus raw search for random starts, wrapped and
  truncated limits, applicable edition/extra-target variants, and the literal
  configuration.  Require the same earliest cyclic seed.
* Test truncation, one-bit corruption, wrong semantic fingerprints, duplicate
  and out-of-range IDs, missing footer, stale predicate revision, cancellation,
  and interrupted final replacement.  Every invalid case must fall back to raw
  search.

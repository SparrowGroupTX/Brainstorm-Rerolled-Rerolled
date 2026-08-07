# Exact seed inversion investigation (2026-08-06)

This directory is diagnostic-only. It does not modify or replace any
Brainstorm production source.

## Authoritative map

For an eight-character text seed `s[1]...s[8]`, define `H_k(s)` by starting
at `x=1` and processing `s[8]` through `s[1]`:

```
x <- fract(1.1239285023 / x * byte(s[j]) * 3.141592653589793116
           + 3.141592653589793116 * (k + j))
```

`H_k` is the value after the seed characters. Continuing the same recurrence
through a key from its last byte to its first produces the hash of
`key + seed`.

For a fresh RNG node with key `K`:

```
u = round13(fract(hash(K + seed) * 1.72431234 + 2.134453429141))
q = (u + H_0(seed)) / 2
roll = LuaRandom(q).random()
```

Lua initializes four words from four successive binary64 evaluations of
`d <- d*pi + e`, advances each Tausworthe word eleven times, XORs the words,
and keeps the low 52 bits as the exact random fraction.

The opening condition studied here is:

1. `floor(24 * roll(Tag1)) == 10` after independently keyed resamples of the
   nine Ante-1-locked tag indices;
2. at least one of five successive `soul_Tarot1` node rolls is greater than
   `0.997`; and
3. `floor(5 * roll(Joker4)) == 4` (Perkeo).

The independent implementation in `inversion_math_probe.cpp` matched the
production scalar opening collector for 100,000 randomly distributed seed
IDs with zero discrepancies. The repository's opening regression separately
uses `Instance` as its authoritative reference across ordinary, short,
wraparound, multi-Soul, all-Legendary, and tag-only ranges.

## What is reversible

### Lua's Tausworthe recurrence

Each word transition is linear over GF(2), so an individual transition can
be reversed on its valid state subspace. That does not invert an opening
roll. The retained random output is a 52-bit XOR of four 64-bit words. The
measured ranks of the four eleven-step, low-52-bit maps are `52,52,52,47`;
the combined 52-by-256 map has full output rank 52 and nullity 204. Thus a
complete 52-bit roll still has `2^204` four-word preimages before enforcing
the nonlinear, rounded `q -> (d1,d2,d3,d4)` initialization relation.

### The 13-decimal node transition

Once a node has been rounded, write its state as `n / 10^13`. Ignoring binary
rounding for a moment, its next grid integer is

```
(round(n * 172431234 / 100000000) + 21344534291410) mod 10^13.
```

This circle map is useful structure. In 1,000,000 random states the exact
binary64/`round13` result differed from the integer formula 2,266 times
(0.2266%), always by exactly one grid unit. Enumerating the neighboring
integer targets and checking the authoritative forward function recovered
the original state in all 1,000,000 cases. Each target had one or two exact
predecessors (mean 1.67249).

This is a real reversible component, but it does not yield seed strings.
The Lua input is `(n/10^13 + H_0(seed))/2`, so the unknown base hash remains.
Even for a fixed base hash, scanning the decimal node grid means `10^13`
states. On adjacent `10^-13` inputs, Soul-producing Lua outputs were isolated:
2,976 hits formed 2,972 runs in a one-million-state sample. Extrapolation is
about 30 billion Lua preimages per Soul draw on the node grid, before relating
any of them to a seed. Five Soul draws do not repair that mismatch.

## Why reciprocal/fract inversion explodes

Over the reals, one pseudohash step

```
y = fract(C_character / x + B_position)
```

has inverse branches

```
x = C_character / (integer_branch + y - B_position).
```

Small reachable `x` values create a huge number of integer branches. Complete
enumeration of every four-character processed half (`35^4 = 1,500,625`)
found:

- zero collisions in `H_0`;
- zero collisions in the `(H_0,H_4)` pair needed by Tag1; and
- reachable values as small as `2.2254025680013e-6` for `H_0` and
  `1.047699242917588e-7` for `H_4`.

For a representative target hash of 0.5, just one reverse step constrained to
those observed middle-state ranges produces:

- 3,953,912,410 real branches across the 35 characters for `H_0`; and
- 83,984,650,637 branches across the 35 characters for `H_4`.

Binary64 rounding turns each equality into a rounding interval and cannot
remove this branch explosion. Testing candidates with the exact forward step
is still required.

## Meet-in-the-middle result

A four/four split gives only 1,500,625 forward middle states (24 MB for the
two needed doubles), but the leading four characters describe 1,500,625
different nonlinear functions of each middle state. With no middle-state
collisions, materializing their cross product is exactly `35^8 =
2,251,875,390,625` entries: about 16 TiB for one hash or 33 TiB for the
`(H_0,H_4)` pair. Evaluating the functions on demand performs the original
full enumeration. The broad Tag/Soul/Perkeo output intervals provide no fixed
terminal hash value for a hash join.

This closes the straightforward exact meet-in-the-middle formulation. A
lossy bucket table could be a prefilter, but because the subsequent Lua map
is effectively random at seed spacing it cannot reject without evaluating
the omitted state bits.

## Lua-output interval structure

There is local structure only at adjacent binary64 inputs. Around `q=0.5`, a
million adjacent doubles produced 199,231 distinct Lua outputs; Charm hits
formed 496 runs with mean length 81.1. This comes from plateaus and carries in
the four rounded affine initialization values.

The structure disappears at the spacing relevant to node states and seeds:

| Input sequence | Charm hits | Charm runs | Mean positive run | Soul hits | Soul runs |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1,000,000 adjacent binary64 values | 40,218 | 496 | 81.08 | 3,086 | 156 |
| 1,000,000 uniform points | 41,665 | 39,972 | 1.04 | 2,985 | 2,979 |
| 1,000,000 adjacent `10^-13` grid values | 41,832 | 41,059 | 1.02 | 2,976 | 2,972 |
| 1,000,000 consecutive real Tag1 seed inputs | 41,525 | 39,783 | 1.04 | 3,058 | 3,050 |

Consequently, expressing desired RNG outputs as `q` intervals gives nearly
one interval per accepted grid state or seed. Sorting every seed by `q` could
use the short adjacent-double runs, but constructing that sort already needs
a full-domain evaluation and several tens of terabytes of key/value material.

## Exact persistent candidate index

The practical exact candidate generator is a one-time exhaustive anchor index,
not algebraic inversion. Scan the domain once with the existing bit-exact
batch collector, store sorted seed-ID deltas (or Elias-Fano), and subsequently
enumerate only IDs satisfying the invariant opening condition.

A 100,000,000-seed AVX2 diagnostic found 19,878 exact
Charm + at-least-one-Soul + Perkeo candidates:

- measured density `0.000198780` (one per 5,030.69);
- theoretical density `0.000198803595` (one per 5,030.09);
- projected full-domain candidates: 460.79 million;
- unsigned LEB128 deltas: 2.0139 bytes/candidate, about 0.928 GB; and
- Elias-Fano with 12 low bits: about 0.820 GB.

An independent 4-billion-seed exact literal-stage probe measured 794,671
opening candidates (one per 5,033.53). Adding the invariant starting-pack
Perkeo + Invisible requirement left 368 candidates. Extrapolated to the full
domain, that deeper anchor contains about 213,266 IDs and occupies about
0.674 MB with Elias-Fano (23 low bits). Adding the tested Ante-2 no-reroll
Invisible event left five in four billion, projecting only about 2,898 IDs
and an approximately 11.4 KB Elias-Fano list, although that last estimate has
wide sampling uncertainty.

At the measured production rate of 701.8 million raw seeds/second, a complete
domain anchor build is about 55.4 minutes. It does not speed up its own first
build. It removes the opening gate from every later run with the same anchor
signature. Since the measured literal profile spent only 0.486% after that
gate, the ideal repeated full-domain replay ceiling is roughly 206x before
index decoding and changed downstream costs. The deeper 0.674 MB pack anchor
is the better artifact for the current fixed target because it fits in cache
and reduces raw candidate enumeration by about 10.9 million to one.

Recommended index properties:

- version by game/RNG implementation, unlock pool, stake/deck assumptions,
  and exact criteria;
- build disjoint seed-ID ranges in parallel, then merge in ID order;
- store a file checksum, total count, and periodic absolute-ID restart points;
- verify sampled entries and sampled gaps with authoritative `Instance`;
- search by lower-bound at the requested starting ID, then wrap once; and
- never treat the index as sufficient for a hit: downstream acceptance remains
  authoritative.

## Recommendation

1. Build the persistent starting-pack Perkeo + Invisible anchor first. It is
   exact, small (~0.674 MB projected), and reuses the already-proven opening
   collector. This is the only investigated route that produces a massive
   repeated-search reduction with practical memory.
2. Keep the decimal-node inverse as a research primitive. It is elegant and
   cheap, but do not integrate it until someone finds a way to constrain the
   unknown base hash or represent the tens of billions of fragmented Lua
   preimages compactly.
3. Close direct reciprocal inversion, four/four MITM, and Lua-output interval
   enumeration for the current search. Their measured branch/state sizes meet
   or exceed exhaustive scanning.
4. If the search criteria change often, keep a broader 0.82 GB opening anchor;
   otherwise prefer the target-specific pack anchor. A hierarchy of indexes
   can support both cases.

## Reproduction

Run `build.ps1`, then:

```
./inversion_math_probe.exe all 1000000
$env:BRAINSTORM_OPENING_BATCH_BACKEND='avx2'
./candidate_index_probe.exe 100000000 1000000000000
```

The standalone AVX-512 diagnostic binary built by MinGW exhibited the known
Windows vector-stack access violation on a multi-chunk run; the AVX2 path was
used for the 100-million index measurement. Production's deployed AVX-512
build and its regression evidence are unaffected by this diagnostic-only
compiler/ABI behavior.

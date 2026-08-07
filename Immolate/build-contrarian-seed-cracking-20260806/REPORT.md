# Contrarian seed-cracking investigation (2026-08-06)

This directory is diagnostic-only.  Nothing here is part of the production
mod or installed Balatro files.

## Interim conclusion

Balatro's seed **encoding** has structure, but the criteria map does not expose
a practical algebraic shortcut.  Exact reciprocal/fract inversion, a direct
four/four meet-in-the-middle, seed-output aliases, coarse lookup tables, and an
IEEE-754 SAT encoding all fail for different measurable reasons.  Exact CUDA
also loses to the current CPU after end-to-end measurement.

Two routes did produce concrete value:

1. amortize one exhaustive pass into small exact parent/child indexes; and
2. for every query that names a specific Legendary, evaluate that independent
   1-in-5 predicate before the expensive lock-aware Tag/Soul gate.

The first route is already real: the starting-pack Perkeo + Invisible anchor
contains 209,798 IDs out of 2.318 trillion.  A later-event bitset over that
parent costs only 26 KiB per Boolean fact, making repeated variants
database lookups rather than seed searches.  The second route was integrated
into production AVX-512 and measured 1.4245x faster with exact result parity.

## Direct inversion and algebraic state recovery

The independent inversion work established the exact map and verified it
against production on 100,000 distributed IDs.  The useful reversible pieces
do not connect end to end:

- A node state on the `10^-13` grid has only one or two exact predecessors
  (mean 1.67249), but the Lua input also contains the unknown base seed hash.
  Searching that node grid is `10^13` states before relating a result to any
  seed string.
- Lua's retained 52-bit output is a full-rank linear projection of four
  64-bit Tausworthe words, leaving a 204-dimensional kernel before the
  nonlinear, rounded binary64 initialization constraints are imposed.
- At real seed/node spacing, accepted Lua inputs are fragmented almost one
  interval per hit (mean run about 1.02--1.04), so inverse intervals do not
  compact the candidate set.
- One reverse reciprocal/fract step has billions of branches over the observed
  middle-state range.  Binary64 rounding changes branches into intervals but
  does not remove them.

Eliminating the shared `H0(seed)` between two Lua inputs only produces a
difference of independently generated decimal-node states.  Because the Lua
acceptance sets are already fragmented on the node grid, this does not create
a useful join relation.

## Meet-in-the-middle and compressed fingerprints

There are `35^4 = 1,500,625` four-character halves.  All observed `(H0,H4)`
middle states were unique.  A four/four split therefore has a small left table
but no fixed terminal hash on which to join: each of the 1,500,625 other halves
is a distinct nonlinear function of every middle state.  Materializing the
cross product is the original `35^8 = 2,251,875,390,625` work items:

- 16 TiB for one 64-bit result;
- 33 TiB for the `(H0,H4)` pair; and
- more once Soul and Joker prefix hashes are included.

Truncating the fingerprint is not an exact prefilter.  A bin can be discarded
only if *every* omitted low-bit state misses.  The measured map avalanches at
real seed spacing, so memory-sized bins become almost universally occupied.
Making bins fine enough to reject restores essentially one record per
candidate--an ordinary sparse seed index.

The same argument closes a Hellman/rainbow-table variant for these predicates.
Rainbow chains can trade memory for inversion of one fixed output, whereas a
search configuration denotes broad ranges across several independently keyed
outputs.  Preprocessing those accepted sets over the complete domain is the
index build under a more collision-prone representation.

## Seed aliases and alternative text encodings

The canonical domain has `2,318,107,019,761` IDs, or 41.076 bits.  Treating one
seed hash as a uniform 52-bit value predicts about 596.6 million colliding
pairs over the full domain, but that saves only roughly 0.026% evaluations even
under ideal deduplication.  A joint independent 104-bit `(H0,H4)` fingerprint
has only `1.3e-7` expected colliding pairs over the whole domain.  Real searches
need still more prefix hashes, so equivalent-seed classes cannot produce a
meaningful reduction.

Canonical order is already close to the best incremental order: it varies the
last-processed character through 35 values before carrying.  A recursive or
base-35 Gray traversal can reduce theoretical seed-prefix work to about
`35/34 = 1.029` pseudosteps per leaf/hash, versus about 1.20 when only the
current 35-wide sharing is counted.  That affects only the seed-hash portion,
not the keyed Tag/Soul/Joker transforms.  The production hierarchy experiment
was measured as neutral, confirming that bookkeeping and SIMD packing consume
the small theoretical saving.

One alternative encoding *is* relevant to a GPU: enumerate the `35^7` fixed
rightmost-seven-character groups directly and generate 35 length-eight seeds
per group.  This removes per-seed mixed-radix ID division and shares fourteen
binary64 seed-prefix divisions across 35 threads.  The remaining 2.857% short
seeds can be handled as separate length domains.  This changes hardware
mapping, not search probability.

## Exact SAT/SMT probe

`z3_exact_tag_probe.py` encodes the initial Tag1 Charm condition using:

- symbolic 0..34 seed digits;
- exact binary64 RNE division, multiplication, addition, floor/fract, and the
  production `round13` nextafter fallback;
- exact binary64-to-bit-vector state initialization; and
- all eleven 64-bit Tausworthe transitions before the exact Charm interval.

The encoding was cross-checked concretely: fixing the one-character seed to
`4` returns SAT in 0.031 seconds, and production's scalar calculation also
places seed `4` in initial tag category 10.

Symbolic performance fails before the actual problem begins:

| Symbolic domain | Solver | Limit | Result |
|---|---|---:|---|
| one character, four allowed values (`1`..`4`) | default | 10 s | timeout |
| one character, four allowed values (`1`..`4`) | `QF_FPBV` | 10 s | timeout |
| one character, all 35 values | default | 10 s | timeout |

The four-value domain contains the known solution `4`.  Z3 nevertheless
cannot choose among two symbolic character bits in ten seconds once the exact
floating-point/Lua circuit is present.  Fixing a character lets constant
propagation solve it; iterating fixed characters is ordinary enumeration.
Eight characters, lock resamples, five Soul rolls, and Joker selection are
therefore not credible SAT targets.  A custom bit-blaster could improve the
constant factor, but random-looking 41-input-bit Boolean functions also have
exponential BDD/AIG representations absent exploitable low-degree structure;
the held-out prefix/pair/Hamming statistics found none.

## Exact RTX 5090 result

The machine has an NVIDIA GeForce RTX 5090 (compute capability 12.0, 32 GiB)
and CUDA 12.8.  Three bounded exact probes were run only after the full-domain
CPU index scan finished.

### Established full gate

The pre-existing `build-gpu-probe/opening_gate_cuda` implementation evaluates
the complete lock-aware Charm + Soul + Perkeo gate per GPU thread.  It uses
round-to-nearest CUDA binary64 intrinsics, FMA contraction disabled, exact node
rounding, and the integer Lua recurrence.

- 65,536 seeds x 17 intermediate 64-bit values matched the CPU bit for bit.
- The complete decisions over 1,048,576 seeds matched exactly (231 hits).
- Persistent allocation took 4.0 ms; context setup took 80.1 ms.
- At the largest 16,777,216-seed batch it reached 336.25M seeds/s in the
  kernel and 335.54M seeds/s end to end, including compact survivor transfer.

The completed current CPU builder processed the whole domain in 2,764.73 s,
or 838.46M seeds/s including authoritative anchor checks.  The naive exact GPU
is therefore 2.50x slower than the CPU and is not a useful production backend.

### Natural 35-seed grouping

`cuda_exact_tag_probe.cu` tested the strongest alternative seed encoding:
factor length-eight seeds into `35^7` groups and share seven `H0/H4` prefix
steps over each 35-character final run.

- A raw 1,048,576-seed fixture and a separately encoded 700,000-seed grouped
  fixture had zero category mismatches against production scalar results.
- On 100M seeds, raw initial Tag1 ran at 1.989B/s and grouped Tag1 at 2.205B/s:
  only a 1.109x improvement.

The expected division saving did not become a proportional speedup because
the grouped kernel adds synchronization/under-filled 35-thread groups, while
the full gate is dominated by divergent locked-tag resamples and later sparse
work.  This is far too little to close the 2.50x full-gate deficit.

### Perkeo-first CUDA ordering

`cuda_perkeo_first_probe.cu` evaluates the independently keyed 1-in-5
Legendary identity before Tag resamples.  It matched the established order on
host and GPU over 1,048,576 seeds (231 identical hits), and its 300M-seed A/B
returned identical survivor totals:

| Order | Kernel | End to end |
|---|---:|---:|
| Tag first | 334.74M/s | 334.44M/s |
| Perkeo first | 474.95M/s | 449.84M/s |

This is a real 1.42x kernel / 1.35x end-to-end GPU gain, but it remains 46%
slower than the current CPU.  CUDA stays diagnostic-only; deployment/runtime
complexity and competition with Balatro's renderer are not justified.

## Retained exact discovery: specific-Legendary first on AVX-512

The CUDA profile exposed a CPU optimization that *does* clear the retention
bar.  Charm, Soul, and the first `Joker4` result are independently keyed pure
functions of the seed.  When the query requests a specific Legendary, their
conjunction can be evaluated in any order.  Checking the 1-in-5 Legendary
identity first prevents four fifths of seeds from entering the expensive
lock-aware Tag path.

The production AVX-512 implementation now:

1. shares the first seven `H0` and `H6` steps over each natural 35-seed run;
2. evaluates the requested Legendary identity;
3. runs the exact staged-top-nine Tag classifier and locked resamples only for
   survivors;
4. checks the requested 1--4 Soul count; and
5. restores canonical seed order before returning candidates.

Queries with no Legendary identity keep the established tag-first path.  AVX2
also remains unchanged pending its own performance evidence.

Exact validation included ordinary/short/wrapped ranges, all five Legendary
identities, Soul counts 1--4, and a 4-billion-ID A/B.  Both orders returned the
same 793,808 survivor IDs and checksum.  The integrated release-mode A/B was:

| Order | Run A | Run B |
|---|---:|---:|
| Existing staged Tag first | 949.73M/s | 965.52M/s |
| Specific Legendary first | 1,368.86M/s | 1,359.33M/s |

The paired mean speedup is **1.4245x**: 42.45% more raw throughput, or about
29.8% less opening-gate time.  Applying that ratio conservatively to the
46.08-minute full-domain build projects about 32.35 minutes for the same
specific-Legendary scan before run-to-run thermal and downstream differences.

A fresh native build completed successfully and all 18 CTest entries passed,
including the expanded opening matrix and index corruption/package tests.

## Actionable non-algebraic accelerators

### 1. Parent-relative feature index

Once the 209,798 starting-pack pair IDs exist, simulate each one through the
supported later horizon exactly once.  Store narrowly defined facts as parent
bitvectors or sparse parent ordinals:

- Invisible occurrence at exact Ante / by deadline;
- occurrence edition and sale/maturation scenario fingerprint;
- Telescope deadline;
- Observatory deadline after Telescope; and
- exact normalized conjunctions the user actually repeats.

A dense bitvector over 209,798 rows is about 26 KiB.  Dozens of features remain
cache-sized, intersections take microseconds, and every returned seed can
still be authoritatively rechecked.  This offers a larger practical gain than
an algebraic inverse because a completed child turns a repeated query into a
lookup.

### 2. Batched query derivation

When the user is exploring several joker/deadline configurations, evaluate all
of them during one pass over the parent rather than rerunning the timeline for
each query.  Emit several exact child bitsets in the same pass.  The expensive
state reconstruction is shared while predicate checks are cheap.

### 3. Persistent covered intervals

For configurations without a complete parent, store semantic-query hash plus
the exact cyclic ID intervals already exhausted.  Cancelling and restarting no
longer repeats work.  Partial coverage is only a resume aid/priority hint, not
proof about unscanned gaps.

### 4. Multi-output offline warehouse

One universe pass should emit several rare populations rather than one:
at-least-2/3/4 Souls, Legendary IDs, Negative bits, and selectable Judgement
outcomes.  The broader architecture projects a ~50 MiB two-Soul signature
asset capable of answering arbitrary two-Legendary/edition combinations, plus
very small three/four-Soul children.  This amortizes the exhaustive hour across
many UI configurations.

### 5. Distributed/content-addressed shards

If exact CUDA is not a win, wall time for new global assets can still be cut by
building disjoint fingerprinted shards on several machines and merging only
when overlapping range hashes agree.  This does not change total computation,
but it is exact and embarrassingly parallel.

## Reproduction

The solver package is isolated under `pydeps`.  From this directory:

```powershell
$env:PYTHONPATH = (Resolve-Path .\pydeps)
python .\z3_exact_tag_probe.py --length 1 --fix-digit 3 --timeout-ms 10000
python .\z3_exact_tag_probe.py --length 1 --max-digit 3 --logic qffpbv --timeout-ms 10000
```

Compile `scalar_tag_fixture.cpp` with production `opening_batch.cpp`,
`seed.cpp`, and `util.cpp`.  The retained binaries/probes are:

- `../build-gpu-probe/opening_gate_cuda.exe` -- established exact full CUDA
  gate and batch-size benchmark;
- `cuda_exact_tag_probe.exe` -- raw/grouped initial-Tag parity and throughput;
- `cuda_perkeo_first_probe.exe` -- exact tag-first/Perkeo-first CUDA A/B; and
- `production_order_ab.exe` -- integrated AVX-512 exact/order A/B.

The fresh production validation build is `../build-legendary-first-diagnostic`:

```powershell
ctest --test-dir ..\build-legendary-first-diagnostic --output-on-failure -j 1
```

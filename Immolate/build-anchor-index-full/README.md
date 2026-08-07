# Full Perkeo + Invisible anchor builder

Diagnostic/offline builder only. It compiles against the current shared
`Immolate/src` implementation and does not modify production or installed mod
files.

The original exact build predicate is the documented Gold-stake Plasma search
with Charm Tag, one Soul, and two starting-pack targets: Perkeo from Soul plus
Invisible Joker from Judgement, both any edition. Subsequent differential and
code-path validation generalized the published parent predicate to every
supported vanilla deck and stake level 1-8; the manifest retains the original
build predicate and hash as provenance. The opening SIMD batch is only a
prefilter; every emitted ID passes the authoritative configured simulator.

Commands:

```powershell
./build.ps1
./build/anchor_index_builder.exe selftest
./build/anchor_index_builder.exe workers
./build/anchor_index_builder.exe build
./build/anchor_index_builder.exe status
./build/anchor_index_builder.exe verify
./build/anchor_index_builder.exe derive
./build/anchor_index_builder.exe verify-derived
./build/anchor_index_builder.exe crosscheck-decks
./build/anchor_index_builder.exe publish-manifest
```

Worker count defaults to the current machine's detected logical-processor
count. Pass an explicit value from 1 through 256 only for controlled
benchmarking or to leave additional processor capacity free. The `workers`
command reports both the detected and selected values without starting a scan.

Completed `2^30`-ID shards are hash-validated and reused after interruption.
Each shard is written to a unique temporary file, flushed, and atomically
renamed. Final merge emits:

- `perkeo_invisible_anchor_v1.ids`: raw, strictly increasing little-endian
  `uint64_t` IDs;
- `perkeo_invisible_anchor_v1.manifest.json`: predicate, domain, count, and
  payload SHA-256 plus raw-byte FNV-1a-64 (`fnv1a64`, 16 lowercase hex
  digits).

Both final files use atomic same-volume replacement. Shards are retained after
merge for independent restart and audit evidence.

After the base payload verifies, `derive` performs a bounded postpass over only
its roughly 211,000 IDs. It emits the reusable third-target asset
`perkeo_invisible_ante2_invisible_anchor_v1.ids` and sibling manifest for an
additional Invisible Joker at `ante_2`. The same postpass records the exact counts after
requiring first-voucher Telescope and then Observatory by Ante 2.
`verify-derived` independently regenerates the third-target set from every
base ID, verifies ordering/range/SHA/manifest, and checks the historical 4B
probe counts.

`crosscheck-decks` takes a bounded `2^30`-ID opening-candidate sample and
requires bit-for-bit anchor membership equality across all 15 supported
vanilla decks at White, Black, and Gold stakes. It also checks all ten known
anchor fixtures and the finalized base-index prefix.

`publish-manifest` validates the existing payload against all completed shards
and atomically publishes the generalized parent predicate without rewriting
the payload. It verifies that payload size, timestamp, SHA-256, and FNV-1a-64
remain unchanged.

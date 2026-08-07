# Charm + Perkeo + Mega Spectral exact index builder

This is an offline, resumable full-domain builder. It uses the same opening
batch prefilter and authoritative simulator as the production search, but it
does not modify the production DLL or the installed mod.

The parent predicate is:

- Charm Tag at Ante 1;
- at least one Soul in the starting Charm pack;
- the required Soul Legendary is Perkeo, with any edition/sticker;
- the first pack searched after the opening pack is Mega Spectral.

The child is derived only from the complete parent and adds the exact
Plasma/Gold, no-reroll route:

- Blueprint and Brainstorm by the end of Ante 4;
- Baron and Mime by the end of Ante 8;
- every target accepts any edition/sticker.

## Commands

Run these from this directory:

```powershell
./build.ps1
./build/charm_perkeo_mega_index_builder.exe selftest
./build/charm_perkeo_mega_index_builder.exe build 36
./build/charm_perkeo_mega_index_builder.exe status
./build/charm_perkeo_mega_index_builder.exe verify 36
./build/charm_perkeo_mega_index_builder.exe derive 36
./build/charm_perkeo_mega_index_builder.exe verify-derived 36
./build/charm_perkeo_mega_index_builder.exe crosscheck-decks 36
```

`build` divides the complete `[0, 2318107019761)` seed-ID domain into
`2^30`-ID shards. Each completed shard contains its predicate hash, bounds,
record counts, payload SHA-256, and a completion footer. A shard is flushed and
atomically renamed only after completion. Restarting `build` verifies and
reuses every valid completed shard and rebuilds damaged or partial shards.

The final outputs are also written atomically:

- `charm_perkeo_mega_spectral_anchor_v1.ids`
- `charm_perkeo_mega_spectral_anchor_v1.manifest.json`
- `charm_perkeo_mega_naneinf_plasma_gold_v1.ids`
- `charm_perkeo_mega_naneinf_plasma_gold_v1.manifest.json`

Payloads are strictly increasing little-endian `uint64_t` IDs. Manifests
record the exact predicates, domain coverage, source payload provenance,
record counts, SHA-256, and raw-byte FNV-1a-64. `verify` checks every shard,
reconstructs the final sequence, and authoritatively revalidates every parent
record. `verify-derived` regenerates the child in a separate pass through the
direct `Instance` simulator entry path and requires exact equality. This is a
full consistency pass, not a separately implemented RNG oracle.

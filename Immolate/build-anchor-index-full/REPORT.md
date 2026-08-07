# Full-domain anchor-index build report

Completed 2026-08-06 (America/Chicago). This work stayed entirely under
`Immolate/build-anchor-index-full`; it did not edit production/live files.

## Full-domain base index

- Domain: `[0, 2,318,107,019,761)` (complete, gap-free shard coverage)
- Workers: 36
- Shards: 2,159 valid `2^30`-ID shards (last shard truncated at domain end)
- Full scan wall time: 2,764.732145 seconds (46.079 minutes)
- Average throughput: 838.456 million IDs/second
- Opening candidates: 460,866,058
- Exact starting-pack Perkeo + Invisible anchors: 209,798
- Payload: `perkeo_invisible_anchor_v1.ids`
- Bytes: 1,678,384 (raw sorted little-endian `uint64_t`)
- FNV-1a-64: `276e186a7fb8c54d`
- SHA-256: `bd9725e8ac6ec74cff092068996125d06959237863af1f7a62f70d33f4ac1d57`
- Published predicate revision: `brainstorm.anchor.perkeo_invisible.v2`
- Published scope: every supported vanilla deck except Challenge Deck, at
  every supported stake level 1-8 (White through Gold)
- Published predicate SHA-256:
  `6c17d50767dd16d3eeab0194e3faa2165ee9727894c1ca97923231b1e318be35`
- Original Plasma/Gold build-predicate SHA-256, retained as shard provenance:
  `be311772f19c126657485bf058102db56ab46b2c7f54b975d5968c95e73fc96c`

The revision-2 manifest was atomically regenerated after validating all 2,159
shards against the original build predicate and requiring their concatenated
IDs to equal the finalized payload. This was a manifest-only publication: the
payload length, timestamp, FNV-1a-64, and SHA-256 were checked before and after
and remained identical. Its `completion_run_seconds` records only manifest
publication, while the original full scan wall time is reported above.

## Bounded derived index

The postpass evaluated only the 209,798 base IDs; it did not start another
full-domain scan.

- Predicate: base anchor plus a third Invisible Joker at `ante_2`, any edition
- Exact matches: 2,145
- Payload: `perkeo_invisible_ante2_invisible_anchor_v1.ids`
- Bytes: 17,160
- FNV-1a-64: `d3947298245256a8`
- SHA-256: `f43da8550fb30f50afa8dad0cfd00e1d7b18a827beaa9a0ae425e59bffb090d8`
- Adding first-voucher Telescope: 137 matches
- Adding Observatory by Ante 2: 17 matches

## Verification evidence

- Pre-launch selftest passed ten known fixtures, filtered-vs-direct simulator
  checks at short IDs, a known-hit neighborhood, and domain wrap.
- Scalar, AVX2, and AVX-512 opening candidate lists were identical on
  1,048,576 IDs.
- Crash-safe shard encode/write/reopen/SHA/decode round-trip passed.
- The completed first-four-shard payload contained exactly 368 anchors in the
  historical `[8, 4,000,000,008)` probe window, matching the prior independent
  4B scan.
- Every base payload ID (209,798/209,798) passed a fresh direct authoritative
  simulator call. Ordering, uniqueness, range, manifest values, SHA-256, and
  FNV-1a-64 all passed.
- The derived payload was regenerated independently from every base ID and
  matched exactly. Its historical 4B probe-window counts were 5 for the third
  Invisible and 1 after Telescope, matching prior measurements.
- Deck/stake differential: exact bit-vector equality across all 15 supported
  vanilla decks at White, Black, and Gold stakes (45 configurations) over a
  bounded `2^30` raw-ID sample: 213,424 opening candidates, 106 anchors, and
  all ten known anchor fixtures.
- Intervening stake levels 2, 3, 5, 6, and 7 are covered by the code path, not
  interpolation: pair-only Soul and Judgement generation explicitly disables
  Joker sticker generation, the two targets are distinct, and their matcher
  completes before any later timeline. The only stake-dependent branches are
  therefore unreachable or irrelevant to tag, pack, Perkeo, and Invisible
  identity for this predicate.
- Deck setup can activate Crystal Ball, Telescope, or merchant/Overstock
  vouchers for Magic, Nebula, and Zodiac decks. The anchor path checks only
  Omen Globe before generating the Charm pack and completes before shop or
  voucher timelines; its tag, tarot, Soul, and Judgement RNG keys do not read
  the deck enum. This supplies the code-level basis behind the 15-deck
  differential result.
- Independent PowerShell SHA-256 computation matched both manifests.

The published parent predicate is therefore deck/stake-independent across the
stated 15-deck, stake-level-1-8 scope. Runtime applicability should still
retain its normal authoritative fallback behavior for missing, corrupt, or
otherwise inapplicable indexes. The later Ante-2 derived child remains scoped
to the literal Plasma/Gold route because its later timeline can depend on deck
and stake.

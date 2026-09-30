# Conditional later Rare offer qualification

Registered before native execution, 2026-09-11. New bounded work preserves the
exact v1 two-Soul opening and adds one of twenty vanilla Rare targets. Builds use
a fresh Immolate/build-advisor-later265 directory; evidence goes to the fresh
tools/advisor_eval/runs/native_later265 directory. No game launch, window control,
save access, full episode, win-rate estimate or deployment by this worker.

Bounds: configure/build subprocesses 180 seconds each; at most four iterations
when compilation or a meaningful test fails. Native regression subprocesses
60 seconds each. Fixture APIs use one seed per call; at most 1500 fixture calls.
At most one separate discovery search of 1000000 seeds, one thread, 30 seconds,
only if the existing opening fixture does not offer a useful target by Ante8.
Source generation qualification uses at most 120 challenge/profile/route cases,
46 shop cards per case (Ante1 one shop, Ante2-8 three), 60 seconds per worker,
180 seconds cumulative. Failures/timeouts are retained. No exhaustive or adaptive
seed mining is authorized by this registration.

Scope: conditional initial shop stock offers, first Small Charm and two Soul
choices, then play every blind; zero further skips, rerolls, pack opens, voucher
purchases or Joker-generating consumable uses. Common/Uncommon shop purchases
and sales are allowed except Showman. No additional Rare acquisition/sale and
the starting Rare population and two Legendary opening Jokers must be retained.
Survival, money, free slots, legal acquisition and retention are not forecast.
The live ordered twenty-position Rare availability mask binds unlocks, bans and
starting owned Jokers. Bram Poker's no-shop-Joker route is unsupported by v2;
opening-only v1 remains supported. Jokerless remains excluded.

Location semantics: found_ante is round_resets.ante when the stock is generated.
Ante1/shop1 follows Big. AnteN/shop1 (N>=2) follows AnteN-1 Boss; shop2 follows
AnteN Small; shop3 follows AnteN Big. The next Boss shop is AnteN+1.

Implementation/qualification results and hashes will be appended after testing.

Second bounded qualification registration, before execution: root's independent
review requires source-backed known-capacity admission. Typecast's post-Ante4
zero-slot state must exclude offers while retaining the pair. Blast Off's two
Eternal starters plus the pair need a Negative offer or Negative opening Joker
for capacity. This newly requested correction authorizes one repeat 57-case
source matrix plus at most seven cases on the existing 9CISW211 two-Soul fixture,
at most 1300 additional one-seed native calls, 60 seconds per worker and
120 seconds cumulative. At most two rebuilds/regression runs under the previous
180/60-second caps. No seed discovery search has been performed or added.

Final source-only boundary registration: one X-ray all-unlocked fixture, no
native calls, 60-second hard subprocess cap, at most 44 shop cards and two actual
Riff-Raff generated Commons. Verify original Riff-Raff calculation leaves cdt,
shop rarity, shop Rare and shop edition nodes plus Rare eligibility unchanged.

## Completed native slice

Implemented the additive `brainstorm_challenge_opening_v2(seed, challenge_id,
legendary_csv, later_key, deadline_ante, rare_pool_mask)` C ABI. It preserves v1
byte-for-byte behavior and accepts one of the twenty original Rare center keys
with a live ordered availability mask. Query deadline is 2–8. Result is flat JSON,
at most 24 fields, with an explicit conditional offer and unverified retention.
The exact schedule token is `first_charm_then_play_all_fixed_rare_pool`.

The v2 shop projection uses source-separated cdt, rarity, Rare identity and edition
streams; it advances shop edition for every Joker and preserves unavailable Rare
positions/resampling. It explicitly handles the source singleton-Joker fallback
when a shop's first card exhausts the eligible Rare pool. Common/Uncommon choices
do not need speculative identity/deck forecasts. Showman (`j_ring_master`) is
excluded. Original Riff-Raff uses `rif` streams, independent of shop `sho` streams.

Known unavoidable capacity is checked before accepting an offer: protected
starting Eternals plus the retained pair must fit, with actual Negative opening
Legendary and offer slot bonuses. The Typecast zero-slot transition caps admitted
offers at current Ante4 even for a later requested deadline. A plain offer in
Blast Off's full Eternal row is rejected unless a Negative opening Joker provides
space. Optional Common/Uncommon replacements remain conditional on real legality.
No money or blind-survival projection is invented.

Final runtime sidecar is
`Brainstorm/Immolate-advisor-a569e1cb834352c23fed5eac3db30059279a57fe1eaf46e71cc8a594b672f885.dll`.
SHA256 is the full 64-character filename suffix. The existing v2.16 DLL was not
modified. This worker did not install; root owns coherent runtime integration.

Meaningful validation, all outputs retained under `runs/native_later265`:

- Final native challenge regression: 199 checks; all three CTest suites
  `brainstorm_(challenge_opening|api|soul_scanner)_regression` passed in 2.82s.
- `source3`: all 18 compatible stock-offer challenge profiles, three unlock
  fixtures each and three original visible Common/Uncommon buy/sell fixtures:
  57 cases, 1140 one-seed calls, 2508 original generated cards, 3.54s.
- `source4`: seven cases on the preexisting 9CISW211 two-Soul fixture, including
  live Negative-opening capacity, Blast Off's different rates, Rare restrictions,
  and 18 actual buy/sell callbacks. 140 calls/308 cards in 0.48s. Two original
  `end_round` Boss transitions confirmed Ante1→2 and Ante2→3 before ROUND_EVAL.
- `source5`: original Riff-Raff generated two Commons; shop cdt/rarity/Rare/edition
  nodes and Rare availability were unchanged while `edirif8` advanced. 0.10s,
  no native calls.

These are source-generation/capacity fixtures with synthetic declared unlocks
and isolated currency fixtures. They are not played routes, acquired later
targets, retained engines, full attempts, win rates or proof of affordable setup.
The two fixed seeds were already regression fixtures; no mining/search was run.
Ante2/3 rollover was exercised, but these two seeds' admitted Rare offers happen
later; this does not certify early-deadline yield or search economics.

`native_hashes.json` records final source/test hashes and the sidecar; `frozen/`
contains the final native sources and test inputs. `native_evidence_base.json`
binds build/validation receipts and logs; root must add final runtime companion
hashes before installation. Each source run separately records original ZIP,
bootstrap, payload, harness, DLL and Lua runtime hashes. Historical `source1/2`
precede the capacity correction and are not final admission evidence. Their
outputs remain retained. Build3's const-qualification compile error is retained;
build4 corrected it and passed. A first ad hoc fixture-loader dependency-path
failure performed no search; the corrected call is recorded in fixture_offers.

## Subsequent three-request smoke

Root separately authorized one fresh bounded smoke after the final DLL was
frozen. `runs/native_later265_smoke1/registration.json` binds the exact sidecar,
final native source hashes, helper, loader bytes, runtime dependencies and runner
before any calls. This is a scoped native/helper/loader freeze, not the final
runtime policy. The profile is explicitly synthetic with all twenty Rare entries
available. Each request ran once from a newly generated eight-character seed,
one thread, one million seeds, 5 seconds maximum; an exclusive durable lease
enforced a 20-second cumulative budget. No game, save, user profile or episode
was accessed, and no repeat/continuation was attempted.

| Request, pair Perkeo/Yorick | Start | Result | Resume cursor | Native call seconds |
| --- | --- | --- | --- | --- |
| City, Blueprint by Ante2 | AI2VIDIC | not_found | EIPIJDIC | 0.02768 |
| Blast Off, Blueprint by Ante8 | YN3S4SLY | not_found | 2OQF5SLY | 0.02730 |
| Typecast, Blueprint by Ante8 | 5QPVFDU4 | not_found | 8QDJGDU4 | 0.02817 |

All three processes completed without error/timeout. Including worker startup,
fingerprint checks and output recording, cumulative wall time was 0.72124s.
Misses and cursors remain in the summary and individual receipts. These three
misses establish neither filter yield nor setup economics, and imply no run
outcome or win-rate estimate. No source or DLL changed for this smoke.

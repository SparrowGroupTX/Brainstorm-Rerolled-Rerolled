# Public data for the Red/Gold Completionist pilot

Date: 2026-09-16. The current user objective is to specialize on Red Deck / Gold Stake with the provided Perkeo/Yorick opening, maximizing average **new distinct Gold stickers per run**. White Stake curriculum and generic win count are not this objective.

This audit read preserved recipe files, current runtime normalization/logger source, and bounded existing opt-in public journal segments. It did not read a player save/profile, control the game, execute a game/source policy, search seeds, replay a run, or construct a simulator episode. Separate manufactured wrapper tests mock the run initializer and transition function.

## A real public collection map is available

`SPECIALIZED_PUBLIC_DATA.json` contains the latest complete public collection map in the reviewed log prefix. Its `latest_goal.status_by_key` has exactly the same 150 distinct keys as the runtime vanilla Joker registry, with **59 complete, 91 missing, zero unknown**. All 857 reviewed goal snapshots have the same normalized map digest.

- Source: `C:/Users/trevo/AppData/Roaming/Balatro/advisor_player_log_v2/session-20260916T144933Z-1-000015.brj`, sequence **3408**, timestamp **2026-09-16T15:10:48Z**, loaded `Brainstorm v2.154.0-alpha`.
- Event SHA-256: `32dce0c04838c07b6f0be0764f03f1429182eed02491d55f18f1e60e156c2bbd`.
- Canonical map SHA-256: `f5020ea4d8da7f69811712d21be39792861743f340b3daf2896196cd3484fe5d`. Canonicalization is UTF-8 JSON of the `key: status` object, sorted keys, separators `(',', ':')`.
- Extraction artifact SHA-256: `c6572dcb8a42db0dbfa81752fc9b65ab926d992ceac4c8bc6c621fdb934237fe`.

The snapshot reports `metadata_status`, `catalog_status`, and `stake_status` all `complete`. Its *run* eligibility is false (`run_already_won`, `held_inventory_unavailable`), which does not turn its complete historical collection map into an eligible run or an award receipt. Do not infer a win from the incidental won flag. This is a frozen historical target map, not a claim that the collection is still unchanged now.

Perkeo, Yorick, Blueprint, Brainstorm, and Burnt are already `complete`. They are potential engine/support Jokers, not new-sticker targets under this map. For example, Joker, Abstract Joker, Raised Fist, and Shoot the Moon are `missing`; the complete authoritative list is in the JSON rather than duplicated in prose.

The read covered the preexisting numbered segments 000009–000016 of that session: 3,929,942 physical bytes, 84,692,983 decoded bytes, 1,573 events, 1.875 seconds. There were no decode errors, and each file's size/mtime was unchanged across its individual read. Per-file hashes and exact cutoffs are retained in the artifact. The newest reviewed segment had no newer collection snapshot; it does not refresh the 15:10:48Z map. No monitoring or continuing read was started.

## Normalization and logging semantics

The actual runtime module is `Brainstorm/Advisor/gold_stickers.lua`; there is no need to infer a separate `runtimeCompletionist` schema. `runtime.lua` attaches its result as `snapshot.completionist_goal` when the user has enabled the objective. `player_journal.lua` publishes a detached public snapshot with concealed identities redacted and shop forecasts omitted. Collection history is public objective context, not deck order or RNG.

The tracker enumerates the sorted 150 vanilla Joker keys, checks catalog and Gold stake mapping, and validates the already-loaded active profile's Joker history. A valid row with a positive stake-8 win count is `complete`. A valid absent row, or a valid row without a stake-8 win, is `missing`. Malformed/unavailable history or unverified catalog produces `unknown`; it must never silently become missing. Reading this source documents how the *existing public snapshot* was produced; the audit did not access the underlying profile.

Run eligibility separately requires the run stage, ordinary Gold Stake, no challenge, no manually seeded flag, no prior win/past winning ante, and verified metadata/held inventory. The normal filtered opening's public snapshots described below explicitly report eligible true. A deterministic simulator seed with a synthetic eligibility flag is not a real collection-eligible player run.

For model conditioning, use three statuses `[missing, complete, unknown]`, retain the exact frozen key order/digest, and mark absent or unverified data unknown. For terminal simulated reward, count distinct held vanilla Joker identities intersecting known-missing keys only at a verified qualifying win. Duplicate physical copies add no extra award. A debuff or sticker does not itself remove an otherwise held identity from source award accounting. `AWARD_OBJECTIVE_AUDIT.md` documents the independent source-grounded award audit.

## Provided development seeds and recipes

The following preserved recipes are already development data, not unseen hold-outs:

| Seed | Preserved recipe directory | Original public opening/acquisition sequences |
|---|---|---|
| `S7PXV521` | `../development328/validation_adapter/recipes/S7PXV521/` | 2638 / 2656, session-20260915T173716Z segment 000008 |
| `RH45AD21` | `../development328/validation_adapter/recipes/RH45AD21/` | 2767 / 2785, same session segment 000010 |
| `YAEARC31` | `../development328/validation_adapter/recipes/YAEARC31/` | 3397 / 3415, same session segment 000012 |

Each directory contains `normal_opening_recipe.json`, `normal_seed_selection.json`, and `opening_public_observation.json`. They explicitly identify previously observed failed public product runs selected for development validation, set `unseen_holdout=false`, and do not assert qualification or future acquisition. The historical adapter's objective was **synthetic fresh all 150 missing**, even though its recipe recorded 58 publicly observed complete stickers. That old synthetic mask must not replace the current 59/91 public map.

The declared route is Red/Gold `normal_two_soul_v1`: skip the first visible Charm Small Blind, then select two visible Souls, obtaining Perkeo and Yorick. Later Brainstorm/Burnt targets are declared search constraints, not proof of cash, acquisition, or survival. The reconstructed recipe says no native search receipt was imported. No new search was performed in this audit.

Runtime `Brainstorm.createCharmArcanaCard` implements a one-use mod behavior for the matching filtered Mega Arcana tag pack: after the first Soul, it temporarily bypasses Soul's duplicate guard so later pack slots retain their natural seeded Soul rolls. This is a material opening mechanic absent from simply passing the same string to the external engine. Pinned Jackdaw seed identity and a vanilla seed string alone do not reconstruct this filtered two-Soul route.

## Exact public starting reference

`SPECIALIZED_OPENING_SNAPSHOTS.json` records five existing public YAEARC31 observations, sequences 2184, 2191, 2196, 2201, and 2238 in session-20260916T144933Z segment 000010. The source segment SHA-256 is `5d2b8764dd64b443bb1bf48cd8b6d61804726aaa290fc80af145c6e432a2b0ef`; extraction SHA-256 is `414666da6b32ebb65218473a91057b31bc12c4709477d2bef877a9739ea703ce`.

The clean post-Soul reference is **sequence 2201**, event SHA-256 `beb7d6c50e34d1175cc2577c71bb2178e88d3dc03a9b7cc3726dc988d696c89f`:

- Red Deck, Gold Stake, Ante 1, round 0, blind-selection phase, **$4**.
- Small `Skipped`, Big `Select`, Boss `Upcoming`, one skip. Skipping is not a cleared blind.
- Ordered owned Jokers: **Perkeo, then Yorick**. Ordinary edition, no perishable/rental/eternal sticker or debuff, no consumables.
- Yorick has X1, `extra.discards=23` and live `yorick_discards=23`. No pre-grown value is justified.
- Both Jokers display cost $20 / sell value $10, but the two immediate Soul uses did not charge $20 purchases: cash remains $4 throughout the observed opening.
- The public run eligibility is true at this reference. Pack phase has ended; stale public `pack_choices=1` is not an active remaining choice and must not reopen a pack.

The first shop is a different reference: **sequence 2238**, after Big was defeated, round 1, $10. Yorick's live remaining discard counter is 14 while its per-threshold `extra.discards` stays 23. The offers are rental + perishable Raised Fist ($1), Justice ($3), normal Buffoon pack ($4), and normal Standard pack ($4). A first-shop reset imports blind survival, cash, nine physical discards of progress, and card history. It is not equivalent to the fresh post-Soul start and should not be substituted silently.

These are public observations, not full resumable engine checkpoints. They supply no verified hidden future order or matching consumed RNG state. Recreating them with a new simulator world is public conditioning, not replay.

## Implemented isolated scaffold

`tools/advisor_learning/specialized_environment.py` leaves the existing base wrapper untouched. Its constructor accepts only Red/Gold, validates the explicit goal specification, initializes one fresh simulator world under the job's authorization, and installs the public post-Soul situation above. It uses fresh `Card.set_ability`/`set_cost`/`add_to_deck` calls, verifies the $20/$10 and X1/23 defaults, and tracks the two held Joker keys. Consumed Soul is not retained in `used_jokers`, and `last_tarot_planet` remains unset. Hidden deck/RNG come from the fresh simulator initialization; no Charm/Soul generation or source/native seed consumption is claimed.

The wrapper adds public collection conditioning with dimensions global530/entities67/candidates163. It preserves the base wrapper's public projection, legal candidate descriptors, fidelity boundaries, action caps, and observed final-boss win latch. Its reward is the distinct known-missing held count at a verified eligible simulator win, otherwise zero, including zero-new-sticker wins. It reports `objective=completionist_distinct_v1`, `scope=public_conditioned_post_soul_training`, `simulated=true`, `actual_awards=0`, and `seed_equivalent_opening=false`, plus goal digest and new-key list/count.

This is a deliberately labelled training scaffold. The synthetic `seeded=false` flag models the observed normal-filtered eligibility category only; it does not claim a real game award or source-equivalent startup. Existing perishable, passive-debuff, and other fidelity boundaries still censor unsupported episodes.

Ten manufactured tests passed in 0.089 seconds using `python -B -m unittest tools.advisor_learning.test_specialized_environment -v`. They cover the mocked constructor recipe, hidden-world preservation, goal/deck validation before reset, schema augmentation, terminal distinctness, zero-new reward, eligibility/unknown-history gates, false terminal handling, and unchanged fidelity censorship. No simulator episode was initialized or stepped by these tests.

Future episode/training execution remains root's separately registered finite work. Neither these artifacts nor this document authorize it. Keep all provided seed/reference data labelled development; held-out Gold evaluation must have separately declared sampling and cannot be called retail validation while the simulator and filtered opening remain unqualified.

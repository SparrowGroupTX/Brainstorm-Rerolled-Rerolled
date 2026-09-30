# Jokerless opening search — 2026-09-13

**Current product checkpoint: 2.77.0-alpha.** The current target presets and
validation below supersede the earlier Saturn-only defaults and historical
spending snapshots later in this note. Current experiment spending and complete
attempt outcomes belong in the latest root checkpoint and source-attempt ledger.

`Core/jokerless_opening.lua` provides a detached deterministic search for a
Coupon Small Blind, selectable Blue seals in the first shop's Standard packs,
a selected visible Planet, and Telescope. The default selects Mars for Four of
a Kind, with two selectable Blue seals including at least one Steel. Jupiter
for Flush is an alternative; existing Saturn selections remain available.
This is a useful development predicate,
not a demonstrated optimal start or a survival guarantee. Standard and Ethereal
skip tags are unavailable at Ante 1 in the original source; the filter therefore
uses the legal Coupon route. Coupon makes the first shop's two cards and packs
free. Telescope still costs $10.

The search reproduces the original source's keyed RNG with private LuaJIT
64-bit arithmetic. It does not call the game's RNG, load a native search DLL,
inspect saves, play hands, or launch a game process. Public catalog admission
requires the original fresh Jokerless challenge, RUN/BLIND_SELECT, Small Blind
on deck and Select, zero skips/rounds/hands, a plain 52-card deck, no inventory or
voucher modifications, original pool order/bans and supported generation rates.
Unsupported catalogs produce a reason, not guessed mechanics.

`Core/jokerless_search_runtime.lua` attaches inertly. A user-clicked product
search uses batches of 512 seeds, at most one million per job. Subsequent user
jobs continue the in-memory deterministic cursor; the full 35^8 seed range never
silently wraps. Each batch and the final match recheck the fresh game identity
and catalog. Only a validated match uses the existing user-clicked filtered-run
replacement operation, retaining the exact challenge definition and stake.
Search computation seconds are separate from gameplay/opening/user costs and
are omitted when the clock is unavailable. No tool invoked that product action.

The stored recipe recommends skipping Small for Coupon, playing Big through the
ordinary advisor, using its selected free Planet, buying an affordable Telescope, and
opening the free Standard packs from left to right. Pack recommendations compare
the visible remaining cards against the recorded full rank/suit/enhancement/
edition/seal multiset before choosing a Blue seal. Hidden or changed contents
pause the recipe. Other pack types and all hands use the ordinary advisor. The
recipe does not establish that Big Blind can be cleared, that the complete route
can be acquired or retained, or that any run is won.

## Current target presets and validation — 2.77

The `Starting pattern` selector exposes these stable IDs:

| ID | Target | Required selectable Standard-pack cards |
| --- | --- | --- |
| `four_kind` (new default) | Mars / Four of a Kind | Two Blue seals, including at least one Steel |
| `flush` | Jupiter / Flush | Two Blue seals, including at least one Steel |
| `two_blue` | Saturn / Straight | Two Blue seals |
| `blue_steel` | Saturn / Straight | Two Blue seals, including at least one Steel |
| `three_blue_steel` | Saturn / Straight | Three Blue Steel cards |

Every preset also requires Coupon and Telescope. Steel and Blue counts respect
the actual number of choices in each pack. The new defaults do not require
matching Blue-card ranks, guarantee an early Four of a Kind, or establish an
optimal pattern. Five of a Kind is a later deck-development possibility:
Planet X, Ceres and Eris are excluded from fresh-opening target predicates.

New predictor/search options are `require_planet` and `target_hand`. Either can
identify one of the nine initially eligible Planets; supplying both requires an
exact match. New recipes bind canonical `target_planet` and `target_hand` fields.
Invalid, conflicting, or unavailable catalog targets fail before spending a
seed range. Runtime match admission checks that the returned recipe retains the
selected target. No target metadata changes generation draws, source catalogs,
search bounds, or the deterministic cursor.

The legacy `require_saturn` predicate still behaves as before. Predicting with
no target options retains the old recipe fields and generation results exactly;
stored recipes lacking both target fields retain Saturn advice. Existing saved
IDs `two_blue`, `blue_steel`, and `three_blue_steel` retain their selected Saturn
behavior even though two new presets precede them in the menu. Attaching or
rendering the module does not rewrite configuration. Only an explicit selector
change saves a different preference. An in-progress job keeps its frozen
predicate; subsequent user jobs may change targets without resetting the cursor.

For normal use after the user's next restart: start a fresh Jokerless challenge,
open Brainstorm's **Challenge opening** page, select **Four of a Kind + Blue
Steel** or **Flush + Blue Steel**, then click **Search this Jokerless opening**.
A saved legacy selection remains selected until changed. The page also offers
**Stop opening search** while work is active. A found match uses the existing
user-clicked filtered-run replacement, after which normal advisor actions remain
user-executed. No tool activates the installation or operates the game.

The exact installed 2.77 copy is frozen in `runs/jokerless277_installed/policy`,
with deployment and matching hashes in `runs/jokerless277_installed/record.json`.
Its frozen policy digest is
`1b5425735afb8190359949faef16084f8fc5394c041f559e43b83634fbf30a36`.
Relevant runtime hashes are:

- `Core/jokerless_opening.lua`:
  `0b185ca39bf140310df6cfac040b4f8fcda1c39b3c4d9570182e8231f3d6d722`
- `Core/jokerless_search_runtime.lua`:
  `f254ea18a5b8bbf9167fc7a17584103c51b09f95ad4fb54e752897600141de6c`
- `UI/challenge_opening.lua`:
  `fb7fc759761975a1321e3fc7dbafb64ea49859c8f842c3b31102412ac5386f56`

`runs/planet_targets277_focus1` passes five Lua fixtures in
0.10999999998603016 seconds under a 30-second cap: 279 existing opening checks,
83 target checks, 55 runtime checks, 16 source-recipe checks, and five dispatcher
checks. Target tests generate Mars/Jupiter shop rows through the frozen original
public catalog using controlled draw values. These are unit cases, not discovered
seeds or new original-source attempts. Existing source fixtures verify unchanged
generation, and the target cases cover complete recipe reproduction, correct
Planet purchase/use, full-inventory and price guards, unsupported targets and
frozen target metadata. No evaluation lease was used.

`runs/jokerless277_full_lua2` passes **110/110 Lua fixtures** against a copied
frozen installed-2.77 policy in 13.5 seconds under a 60-second cap. The tests and
Lua tool dependencies were copied before execution; manifests record all hashes
before and after. The runtime copy matches the installed policy record, and all
frozen files and source-policy hashes remained unchanged. The only excluded
fixture is `advisor_pack_fool.lua`: it exercises pending work whose runtime
transition is not installed in 2.77.

The preceding `runs/jokerless277_full_lua1` result remains preserved as
109/110, in 14.719000000040978 seconds. Its sole failure was the UI test's stale
Saturn-only heading assertion. Only that fixture was updated to assert the
current selected-Planet wording, Mars/Jupiter mappings, and later-development
Five of a Kind disclosure. Additional real-wrapper UI checks verify that a saved
legacy ID reopens at its new menu position without rewriting preferences and
that explicitly selecting Four of a Kind saves once without starting work.
No runtime change was made to obtain the passing final regression.

## Frozen opening evidence and spending — historical 2.71–2.73

All evidence below is under
`runs/jokerless271_push_20260912_214242/`. The original `authorization.json` is
immutable. `authorization_resume_20260913.json` carries forward the same shared
one-use caps after the PC shutdown; it does not renew any lease. The complete
machine-readable accounting and record/request hashes are in
`seed_budget_resume_20260913.json`.

Seven of twelve mechanical source leases are spent: **105 seconds reserved,
1.1098500000080094 seconds actual**, leaving five leases. The first source
probe failed on serialized Lua syntax; the third failed because the original
shop function had not been explicitly loaded. Both failures remain preserved
and spent. Probes 2/4/5/6/7 produced complete mechanical records, including pool
eligibility, original shop/Standard generation, and public catalog admission.
They did not play blinds or establish affordability or survival.

Four search/model leases are spent: **182 of 300 seconds reserved,
19.170088700018823 seconds actual**, leaving 118 reserved seconds. Faster
completion does not replenish the reserved cap.

| Directory | Registered range/predicate | Result |
| --- | --- | --- |
| `seed_search01_coupon_engine` | Start 0, limit 1,000,000; two Blue choices + Saturn + Telescope | Three matches after 123,177 seeds; 1.0534102999954484 s |
| `seed_search02_steel_engine` | Start 123,177, limit 1,000,000; add at least one Blue Steel | No match in the complete range; 7.823036800022237 s |
| `seed_search03_steel_engine_contiguous` | Start 1,123,177, limit 1,000,000; same stronger predicate | No match in the complete range; 10.220227000012528 s |
| `seed_search04_adapter_recipe` | Reconstruct the declared DLA21111 recipe for the evaluator | Complete recipe; 0.07341459998860955 s; no new seed range searched |

The first selected candidate, **DLA21111**, was separately verified against
original-source shop and Standard-pack generation in
`seed_source05_candidate_dla`: Small Coupon, Big D6, Pluto + Saturn,
Telescope, Jumbo Standard 1 with Blue Heart King in slot 4, and Jumbo Standard 2
with Blue Club 6 in slot 5. Both Blue cards are plain, without editions.
`route_dla21111.json` is its declared evaluator recipe. This is selected
development evidence; it is not an unfiltered random run. Its complete attempt
status belongs in the current source-attempt ledger.

Two other detached model matches were WFI31111 and CKV31111. They have not been
separately source-verified or played by this seed-search work. No Blue Steel
match was found in the two registered stronger-predicate ranges. No numerical
player win rate or percentage improvement follows from these searches.

## Resume validation

`runs/jokerless271_opening_resume1` passes both isolated Lua fixtures, **279
opening checks and 36 runtime-wrapper checks**, in 0.08700729999691248 seconds.
Tests include original RNG parity, source-generated shop/pack examples, detached
public snapshots, fresh-state guards, other-pack fallback, catalog drift,
invalid/mismatched recipes, cancellation, bounded cursor continuation and full
range exhaustion. These tests never invoke a real game's run replacement.

`jokerless_seed_search.py` now explicitly reads/writes UTF-8, binds resumed
authorization to the original authority and existing registrations, and rejects
workers whose entire lease cannot finish before the worker deadline. The same
deadline check runs in the frozen child before loading the source/runtime.
`runs/jokerless271_seed_runner_resume1` passes three Python tests for deadline
fit, preserved request hashes and non-renewable allowances in
0.12762759998440742 seconds. These are tooling tests, consuming no source or
search lease.

## Source-discovered edition repair for 2.73

The new selected DLA21111 attempt legally cleared its first Big Blind and reached
the first Standard pack, then stopped as unsupported. Every generated card
identity matched the recipe, but the source attaches auxiliary edition fields:
for example `{foil=true,type='foil',chips=50}`. The previous normalizer mistakenly
treated `chips` and `type` as additional unsupported editions.

The normalizer now accepts exactly the original Foil/Holographic/Polychrome
metadata (`chips=50`, `mult=10`, or `x_mult=1.5`, with a matching optional `type`).
Changed values, mixed editions and unknown metadata still pause the recipe.
The complete original detached failure snapshot is retained as
`tests/jokerless_source_recipe_fixture.lua`, with its source hash. The new
fixture verifies the actual Blue seal choice and malformed-metadata safeguards.
`runs/jokerless273_opening_source1` passes all three focused fixtures (279 + 36 +
16 checks) in 0.09991649998119101 seconds. No spent attempt was replayed; the
original unsupported outcome remains unchanged. Complete attempts and installed
slice hashes belong in the root checkpoint and source-attempt records.

## Stronger selected pattern search after resume

The separately registered `seed_search05_blue_steel_contiguous` reserved one
60-second lease for at most 5,000,000 previously unsearched contiguous seeds,
starting at 2,123,177, with at most three matches. It used the same predicate
plus at least one selectable Blue Steel card. Individual pure-model calls were
bounded to 100,000 seeds and flushed completed batches and candidates to the
preserved log. Runtime defaults did not change.

The worker **timed out after 60.010215000016615 seconds**. Exactly 49 batches,
4,900,000 seeds, are preserved as complete; the final requested 100,000-seed
range is censored and its actual count is unknown. The request is spent. A
future unseen range must begin at least at 7,123,177, after the entire censored
request, rather than replaying its uncertain tail. `partial_result.json`
explicitly retains this distinction; no final complete result was invented.

Completed batch 34 contains **TO6O4111**, a stronger detached-model candidate:

- Small Coupon and Big Boss tag; first shop Mercury + Saturn and Telescope.
- Normal Standard 3: Blue Steel Diamond Jack, slot 2.
- Mega Standard 1: Blue Steel Heart Jack, slot 2, plus Holographic Blue Steel
  Heart 5, slot 3. Its two picks permit taking both.

Thus the model supplies three selectable Blue Steel cards, one Holographic.
This candidate came from a complete batch even though the outer search later
timed out. Its recipe is `route_to6o4111.json`; the explicit selected-development
evidence is
`seed_search05_blue_steel_contiguous/candidate_to6o4111_selection.json`.
The original source must still verify this catalog/recipe and any acquisition,
retention, survival or terminal win in a fresh registered complete attempt.
Neither a player win rate nor a guarantee follows from the candidate.

Current seed-agent spending supersedes the earlier resume snapshot:
**242/300 search seconds reserved, 79.18030370003544 actual**, with 58 reserved
seconds remaining. Source spending is unchanged at seven of twelve leases.
`seed_budget_search05_20260913.json` binds every request and record hash. The
original and resumed authorizations, prior budget snapshot, timeout and partial
rows remain unchanged.

## Original optional search presets — superseded by 2.77 above

The product wrapper now exposes ordered presets `two_blue` (the unchanged
default), `blue_steel` (two Blue seals including at least one Steel), and
`three_blue_steel` (three selectable Blue Steel cards). Every preset retains
Coupon, Saturn and Telescope. The stronger presets explicitly describe rarity
and unknown survival; they contain no example seed and claim no optimality.

The selected id may be loaded from `config.jokerless_opening_search.preset`.
Attaching the module never writes settings; invalid stored values default only
in memory. A user-started job captures its immutable predicate. Later changes
through configuration, UI state, a prior result or search-option table cannot
alter its searches, final match admission or recorded predicate. A subsequent
user job may select another preset while retaining the shared next-seed cursor.
The existing one-million per-job cap and default 512-seed batches are unchanged.

`runs/jokerless_search_presets1` passes the three focused fixtures: 279 opening,
47 runtime and 16 detached source-recipe checks in 0.12121589999878779 seconds.
This change used no evaluation lease. Its installed version and user-facing
control validation belong in the current root checkpoint.

# Source preflight and development failure evidence — 2026-09-11

This note covers evaluator repairs and **development requests 0–3 only** from
`runs/weakness266_current_pilot1`. All eight development workers have completed.
The wider pilot is now complete: 16 records, 6 losses, 5 timeouts, 5 unsupported,
zero audit errors; its execution allowance is spent. Holdout requests 4–7 were
not inspected for this diagnosis; aggregate outcomes were accounted separately.
The final outcome_report.json/completion_ledger.json own total outcome/cost
accounting. These synthetic source attempts
are not measured player win rates. Neither per-challenge target is established.

## Preflight repairs completed before registration

The ordinary-policy module bindings were inspected against `Advisor/runtime.lua`.
The source loader includes the current optional finishing/liquidity dependencies
and remains compatible with frozen 2.62. Expanded-filter route support remains
outside this ordinary pilot.

The source adapter's previous `selected()` called original `unhighlight_all()`
then `add_to_highlighted()` for every index. Original `cardarea.lua:201–207`
retains forced cards; `cardarea.lua:131–158` does not deduplicate them. Therefore
a Bell-forced object already highlighted could be selected twice, while an
omitted forced object could remain selected. This differed from product
`Advisor/execution.lua:45–60` and could silently execute a different discard or
produce a false score mismatch.

`engine_contract.select_cards` now checks dense unique indices, legal counts,
forced-card membership, highlight limits and the complete resulting selected
set. Retained forced objects are not added twice. `engine_run.lua` applies the
same semantics to plays, discards and consumable targets. Zero-target consumables
preserve the forced selection; non-consumable pack choices do not change it.
Consumable preflight also calls original `Card:check_use()`: full-row Ankh can
otherwise pass the earlier usability check yet return without use. These are
tooling-only repairs; product Execute already had the relevant safeguards.

Decision-start records now include the detached current snapshot and source
fingerprint before running the advisor. The current failure context is also set
before computation. A killed worker therefore retains its current decision,
without attributing the timeout to an older completed action. These records do
not affect policy inputs or selected actions.

Evidence:

- `runs/continuation266_selection_unit1`: 40 Lua checks and 8 Python boundary
  tests passed, including product/adapter forced-play and discard admission.
- `runs/continuation266_selection_source1`: one preregistered synthetic fixture,
  5-second worker/cumulative cap, no retry, **0.437449900 seconds**. It uses
  original Cerulean Bell selection, reproduces the old duplicate, checks omitted
  and targeted selections, preserves zero-target Planet selection, discards
  exactly one selected object, conserves 52 unique playing cards, and rejects
  original full-row Ankh's no-op. The source result is an intentional censored
  boundary fixture, never a challenge win.
- Source registration digest:
  `e66c82a6c24dc0972fda0f451f2c7048069b5f058d0c1ec6145f7e8cf1db1c28`.
- Frozen pilot adapter digest:
  `fc5020779fe1aa386d59562dd1655b8224546ac7823af92346f2d3a13571b216`.
- Frozen candidate 2.66 policy digest:
  `933668e8d9cd96fba3f7efe84a08c5b36aaf6e9415e3723dd18e6c8664649dfb`.
- Frozen incumbent 2.62 policy digest:
  `60ededca68ab3e5ff10c655b4a0351b0df82b4bec498bd67ed4f7f09b159f98b`.

## Completed development attempts

The old `weakness263_requests` plan remains untouched. The new pilot binds the
original requests/caps to 2.62 versus 2.66 in fresh frozen products, with the
declared synthetic `all_unlocked_discovered_v1` profile. Its 16 sequential-worker,
80-second worker and 1320-second cumulative allowances are one-use limits; no
attempt here was retried or extended. Action 1.5s/retry 5s are scenarios.

| Pair / challenge | Incumbent 2.62 | Candidate 2.66 |
|---|---|---|
| 0 / Rich | Unsupported concealment advice, step40, Ante2 The Mark; 16.795632300s | Timeout during step110, Ante5 The Manacle; 80.036686400s |
| 1 / Five-Card Draw | Unsupported concealment advice, step54, Ante3 The Wheel; 9.029852900s | Source loss after step122, Ante6 The Needle; 41.531658300s |
| 2 / Golden Needle | Source loss after step74, Ante4 Small Blind; 50.995241000s | Timeout during step93 shop, Ante5; 80.033985200s |
| 3 / X-ray Vision | Unsupported concealment advice, step2, Ante1 Small Blind; 0.391864300s | Source loss after step15, Ante1 Big Blind; 4.217624900s |

The corresponding `000_` through `003_` incumbent/candidate logs and entries in
`episodes.jsonl` retain the full snapshots, actions, resolved effects and outcome
records. No illegal-action or selected-action score-mismatch event was observed
in these development logs. Uncertain/concealed/random forecasts are explicitly
unverified; source terminal losses do not qualify all score predictions. Old
baseline concealment refusals are not evidence of a new 2.66 visibility bug.

The Rich timeout snapshot is seven held cards against The Manacle with Sock and
Buskin, Abstract, Green Joker, Misprint and Blackboard, and no held consumables.
The Golden Needle timeout is a shop decision with Credit Card, Scary Face, Onyx
Agate, Smiley Face and Raised Fist. Both are bounded computation censors, not
proven losses or stuck source transitions. Detached component profiling is the
appropriate next investigation; do not renew these attempts' budgets.

## Concrete unimplemented generator opportunity

Five-Card Draw candidate `001_candidate.log`, decision-start **step122**, has one
hand, zero discards, 20,000 chips still needed, $88, and only an unused Emperor in
two consumable slots. Held cards are Mult-card Aces of Spades/Diamonds, a plain
Six of Spades, and plain Threes of Hearts/Diamonds. The row is Misprint, Joker,
Abstract, The Duo, Banner, Card Sharp and Blue Joker. No first-hand Card Sharp
trigger or Banner chips remain.

The chosen two-pair mean is 12,090; source actual is 14,300. From the visible
mechanics, the chosen hand's ceiling with Misprint's maximum 23 is:

`(20 + 11 + 11 + 3 + 3 + 82) * (2 + 8 + 4 + 21 + 23) * 2 = 15,080`.

Every subset of this particular five-card hand belongs to High Card, Pair or
Two Pair; its strongest supported immediate score remains below 20,000. This
is a local mechanics inference from the recorded snapshot, **not** a newly
implemented general scoring-ceiling certificate or a replayed rescue result.

Current `Advisor/consumables.lua` definitions omit Emperor and High Priestess,
so owned-generator use is absent from hand suggestions. Original `card.lua`
1401–1413 creates up to the declared count and available capacity. Original
`use_card` removes the owned card first; `can_use_consumeable` 1550–1551 allows
an owned generator even when the inventory initially fills its slots. Here,
using Emperor would reveal two unknown Tarots before the otherwise fatal play.
The reveal might supply a useful action; no generated identities or saved
outcome were observed, sampled or imputed in this diagnosis.

A future generic repair needs a complete supported immediate-play ceiling or
equivalent proof, explicit generation capacity/count and callback semantics,
and a replan after real public revelation. It must preserve whole-inventory
Perkeo/Negative/Observatory costs, existing deterministic rescue preference,
unknown mechanics and bounded computation. The installed scorer has supported
random floors, not a general random ceiling API. Do not substitute a low mean
or a failed sample for proof that every immediate play loses. This opportunity
is recorded as unfinished work, not implemented behavior.

The preceding shop at step113 left $88 with Card Sharp before The Needle and
declined further actions after opening an Arcana pack. Its sequence diagnostic
did not admit a supported shortfall search. This is a replay target, not proof
that an unseen reroll or another offered card would save the run.

X-ray candidate reaches a terminal Big Blind loss with three unused discards;
its final plays use fixed concealed slots and explicitly unverified prediction
means. The row includes Walkie Talkie and Bloodstone. The concealed immediate
comparison supports random floors, while continuations require supported exact
future transitions and can fall back. A bounded detached diagnostic is needed
to identify which continuation admission/transition caused this recorded choice.
Unused discards alone do not establish a successful alternative or authorize
bypassing hidden-identity safeguards.

No game executable was launched or controlled; source was read only as ZIP and
the single narrow fixture used a hidden isolated Lua DLL worker. No saves,
settings, native DLLs or runtime product files were changed for these repairs.

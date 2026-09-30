# Early Yorick audit from preserved public observations

This is read-only analysis of the existing `development350/log_analysis` frozen prefixes, plus current source inspection. No captured policy was evaluated, no counterfactual was scored, and no new source/search/run/game/save/profile access occurred. `report.json` binds every prefix, selected raw public events and current source hashes. It decoded 4,533 events from loaded 2.148 and 2.149 prefixes and records 44 observed early-round request groups. The recorded runs are dependent development observations, not a representative cohort.

## Concrete admission mismatch worth fixing

`growth.lua` rejects the current clear below **110%** before considering any investment. Its actual post-discard retained-finish validator requires **105%**. Thus a reliable current clear between 105% and 110% cannot even enter the existing exact comparison, although its candidate could meet the final safety requirement without a favorable draw. Aligning admission to that same 105% requirement changes coverage, not utility weights or final safety.

Recorded example: loaded 2.148, **YVYN2Z11, sequence 1158**, Ante 2 Small Blind, chooses `Play Pair (~1080)` against 1,000 with three discards unused. The selected cards are two Bonus 10s; Yorick is x1 with counter 15; 44 cards remain in the public deck; cash is $4. The row is Yorick, Perkeo, Holographic Cartomancer, Caino and Devious Joker. This lies inside the excluded margin band. The preserved observation establishes the admission gap, **not that any counterfactual was evaluated or that this run would be rescued**.

Other recorded clears in this band include sequences 1367 (5,200/4,800, three discards) and 1408 (6,720/6,400, three discards), but other hazards can still block those states. Sequence 1116 clears exactly 600/600 and remains below the unchanged final 105% safety standard.

Recommended bounded fixture: manufactured 106–109% exact clear, legal five-card spare discard, unchanged held finish >=105%, no RNG, no draw needed. Verify baseline rejection, repaired admission, exact physical Yorick countdown, whole inventory/population/cash conservation, below105% rejection, hazards and paid costs, and unchanged 12-score growth / 70-score fast-clear limits. Do not weaken the post-action threshold or assert any rescued run.

## Several separate limits explain the remaining behavior

- The $154-loss run RH45AD21 requests all three discards in early rounds 1, 2, 3, 4, 6 and 7, but their selected card totals are respectively **9, 10, 10, 13, 9 and 14**. Rounds 5 (Arm) and 8 (Goad) request none and leave three discards. These are request counts; the report also preserves observed physical Yorick counters. Hook can add automatic discarded cards, so request totals must not be equated to every physical trigger.
- Growth reserves one already-verified physical clearing subset, then discards only its complement. A five-card finish in an eight-card hand permits at most three safe spare-card discards. This deliberately avoids assuming a favorable redraw. For example the end-of-prefix YAEARC31 sequence 3488→3493→3498 spends all three discards on three cards each, then plays the retained Flush at3503. It does not discard five simply because five are legal.
- At M4BVSY11 sequences 322 and370, Yorick x3 clears with two discards unused and reserves five cards. Existing one-discard progress utility for three cards is `80*3/23/3 ≈ 3.478`, below the action cost4. Its special two-discard lookahead only credits a reachable threshold. Counters13 and10 cannot cross with two batches of three. This is an explicit heuristic/horizon limit, not missing card-count updates.
- Sequence1315 (YVYN2Z11,4,464/3,200,three discards) has a Glass Ace inside the retained Pair. `drawn_hazard` conservatively rejects multi-card Glass because automatic sorting can change multiplier order. This is outside the small admission fix. Sequence2773 includes Mult in an Arm clear with Sly/Golden/Greedy outside the current additive-order whitelist; sequence418 is Fish. Those qualifications must not be stripped merely to force growth.
- `Decision` invokes the ordinary growth helper only on its reliable-clear shortcut. `multi_discard` instead requires exactly one hand left and no reliable current finish; it is a survival search, not an early-round growth planner. `phase_copy` only adds a retained-clear first-discard Burnt-copy comparison; it is not general Yorick multi-discard planning. None of these mechanisms currently fills that long-horizon gap.

## Sequence111: four cards instead of the five-card threshold

M4BVSY11, Ante1 Psychic, sequence111 requests four cards with one discard left, Yorick x1/counter5. Sequence116 shows counter1 and plays a Flush estimated1,064 against600. **The observed counter is correct: five minus four equals one.** There is no demonstrated counting bug.

Static `search.lua` already prepares discard candidates with exact `after_discard`; its ordinary shortlist preserves a candidate at each draw size, including five. However its later remaining-blind comparison admits only the top two immediate redraw candidates and the smallest discard, then plays out hands without further discards. Thus a threshold-crossing size can be omitted from that second family even though initially considered. The log does not retain every discarded candidate's score/rank, so this audit cannot establish whether omission occurred at111 or whether a five-card option was better.

A possible later bounded test is to reserve an existing remaining-blind branch for an exact threshold-crossing discard when the branch family would otherwise omit it, maintaining the same complete common worlds and score cap. That requires manufactured evidence and careful candidate-completion tests; it is not blended into the admission fix.

Report SHA-256: `379e42860ed1529a1843b53c6e38f0d995a3e4b62dad0260b4e9e726ce0a5c93`. All selected original events are preserved separately with decoded/stored-frame hashes. No numerical win improvement is established.

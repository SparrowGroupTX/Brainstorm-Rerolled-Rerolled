# Ten-start public cohort: loaded-label 2.171 (2026-09-23)

**Capture and classification.** The user-started Red Deck / Gold Stake,
searched Yorick + Perkeo marathon ran from 18:27:19Z to 19:26:13Z.
`capture/manifest.json` binds 25 stable original journal segments (45,227,893
bytes), their frozen copies and SHA256 hashes. All 19,427 records are
consecutive through the terminal `session_stopped` record. The public log has
17,608 stamps for `Brainstorm v2.171.0-alpha`; this establishes the reported
loaded label, not an exact loaded-byte hash. The installed receipt at capture
was 2.171; the repository held an uninstalled validated 2.173 speed candidate.
All 3,041 snapshot projections carried `perkeo_yorick_win_v1`, with the
collection objective absent. The win-first path was therefore active in the
recorded projections. No settings or game process were controlled here.

Ten distinct searched seeds produced ten starts, **two verified wins, seven
verified losses and one unsupported retirement**. Operational yield is 2/10
starts; game outcome among terminal wins/losses is 2/9, reported separately
because run 6 is neither. There were no journal sequence gaps, search failures,
reported timeouts, errors or hidden replacement starts. The 1,818 request/
callback links have no missing callback; 1,805 have a first settled
observation. Thirteen `player_callback` records have empty action payloads, so
they are not evidence of a manual strategic move. This is a small selected
development cohort, not a calibrated win rate or a version A/B test.

| Run / searched seed | Outcome | Last relevant blind | Cash | Yorick | Copy Joker |
|---|---|---:|---:|---:|---|
| 1 `67DIAGSV` | loss | A6 Needle 39,780 / 60,000 | $163 | x6 | none |
| 2 `G66STISV` | loss | A3 House 6,344 / 6,400 | $24 | x2 | rental Brainstorm |
| 3 `UQBX6JSV` | loss | A8 Violet Vessel 352,800 / 1,200,000 | $75 | x8 | none |
| 4 `C1IKTOSV` | loss | A7 Wheel 121,632 / 220,000 | $123 | x4 | none |
| 5 `2I3CNRSV` | win | A8 boss 660,190 / 400,000 | $0 | x8 | rental Brainstorm |
| 6 `MJ3H8TSV` | unsupported | A8 Amber Acorn, no play | $308 | x7 before hide | rental Blueprint |
| 7 `T526BKTV` | win | A8 boss 538,650 / 400,000 | $10 | x6 | Brainstorm |
| 8 `PQXLRLTV` | loss | A1 Big 312 / 450 | $4 | x1 | none |
| 9 `X95C5OTV` | loss | A8 Big 210,808 / 300,000 | $122 | x8 | none |
| 10 `3R4B2RTV` | loss | A6 Water 56,097 / 120,000 | $13 | x6 | none |

## Causal clusters and contrasts

**Copy acquisition and an earlier scoring deficit (WR-013).** Six public
Blueprint/Brainstorm offers appeared. Four were bought, including both winning
runs' Brainstorms; run 3's A3 Blueprint cost $10 with only $2 cash and no safe
funded one-sale option. Four runs had no observed copy offer. All ten native
results reported the same conditional no-reroll shop/Buffoon route; the
product request sought a copy by Ante 5, but `collection_search.lua` itself
warns that other Joker acquisitions can change later offers. Missing offers
are therefore a route-fidelity question, not proof that the search result
guaranteed an actual purchase. Run 9's A5 Blueprint was affordable at $71, but the
five-Joker row required a sale. At action 16710 the complete replacement
receipt compared selling a rental +16 Mult Joker, found a 2.1844× paired
next-blind score ratio in four common worlds, yet assigned merit -15.1391 and
left the shop. `strategy.lua:joker_value` gives Blueprint its no-target score
26 when `blueprint_compat` is absent and the only known scoring copy target is
Yorick. `snapshot.lua:card` can omit that field; the current run's Yorick was
x5 and not explicitly incompatible. This is a reproducible local valuation
gap. The later run scraped through A5–A8 Small and lost A8 Big; its 21 clears
before that loss do not prove the alternative purchase would have won. The
targeted manufactured fixture in `tests/advisor_copy_target_rating375.lua`
failed before the repair and passes with a developed, public Yorick target;
explicit incompatibility and x1 controls stay below the replacement threshold.

**Late resource coverage (proposed WR-015).** The cohort paid for only one shop
reroll, while runs 1, 4 and 9 ended with $163, $123 and $122 respectively and
no copy Joker. Cash alone does not prove a useful supported reroll existed;
the prospective 2.171 reroll has narrow admission and no complete rejection
receipt at these exits. The stock concern is more concrete in run 9: public
observations during A8 showed a `c_jupiter` last-used Planet, 15 held Fools and
one Sun at the final loss (`fool_context.json`). `shop_sequences.lua:suggest`
excludes inventories over four cards, and `consumables.lua` has no ordinary
owned-Fool hand transition. The installed game's `card.lua:1373-1383,1553-1555`
permits a Fool with a previous non-Fool Tarot/Planet and capacity, while
`functions/misc_functions.lua:1212-1219` updates the last-used key when cards
are used. Thus a Fool/Jupiter cycle is a plausible resource opportunity, not
an already-valued action or a proven rescue. A bounded slot, order and
benefit comparison is required before using or selling that stock.

**Amber Acorn is an unsupported boundary, not a loss (WR-014).** Run 6 cleared
A8 Big at 1,134,840 / 300,000 and entered Acorn with seven visible Jokers.
The first concealed advice was unavailable; sequences 12662–12665 record
sticky public-model-gap status and guarded unsupported retirement before any
Acorn play. `acorn_belief.lua:start/validate` admits at most six Jokers and
720 complete slot worlds. Seven distinct Jokers require 5,040 worlds.
`acorn_ordering.lua:suggest` independently assumes a 720-order family.
Selling its nearly depleted Ice Cream before hide would reduce the count but
is not sufficient: Golden Ticket and Abstract Joker lack qualified completed-
play/discard transitions. Ice Cream's potential depletion also changes hidden
population. The read-only review in `development375/ACORN_REVIEW.md` records
the necessary guards and manufactured falsifiers. No hidden identities were
reconstructed, and no claim that this run would have won is justified.

**Early discards, consumables and score arithmetic.** Across 71 early cleared
rounds, 27 cleared with some discard remaining and 62 total discards were
retained. Both winning runs also retained discards. These are candidates for
qualified opportunity review, not 62 proven safe missed growth actions.
The stock was not categorically inert: 14 consumables were sold, run 3 used
Death six times, run 6 used Devil 24 times, and run 7 used Hanged Man 19 times
and won. Run 9's many Fools are a narrower coverage concern. Of 321 plays,
208 numeric-title same-round estimates matched realized score exactly;
45 differed and all 45 involved a visible random effect (Misprint, Space
Joker, or a selected Lucky card). Another 51 crossed rounds or lacked
comparable chip fields; 17 plays had no numeric title. This arithmetic check
does not prove full scorer correctness, but supplies no deterministic mismatch
from the listed differences. Run 8 exhausted all three opening discards and
four hands before its A1 loss, a contrast against blanket early-discard blame.

## Released repair and falsification

`UPDATE_SCOPE.md` froze the selected behavior before policy editing. Released
2.174 recognizes an active developed Yorick with public `x_mult>1`
and no explicit copy-incompatible flag as a Blueprint/Brainstorm scoring
target **only in shop rating**. It leaves the actual four-world shop scorer,
cash, sale, survival and action caps unchanged. The cheapest falsifiers are a
manufactured full-row copy offer with an explicit incompatible Yorick, an
undeveloped x1 Yorick, and the existing funded-copy/ordering fixtures.
Expected local behavior is a supported copy purchase in the developed case,
not a claim about any captured alternative or full-run win rate. The
previously validated 2.173 speed candidate was combined into backed release
2.174. `runs/marathon375_candidate/validation/report.json` and
`runs/marathon375_installed_validation/report.json` both passed 246 Lua
fixtures and 391 Python tests with identical policy/test hashes. The exact
installation is bound in `runs/marathon375_installed/record.json`: 91
deployment and 107 runtime/dependency files match, current configuration
and seven native DLLs are preserved. Release 2.174 is installed but loaded
activation and game benefit are unconfirmed; the user must normally restart.
Reassess WR-015's Fool/Planet loop and WR-014's Acorn support before broad
reroll aggression.

Raw evidence is kept under `capture/frozen/`; compact reproducible readers,
`runs.json`, `rounds.json`, `deep_dive.json`, `copy_opportunities.json`,
`arithmetic.json` and `fool_context.json` are adjacent. No captured state was
run through policy/scorer code. Intermediate historical evidence remains
unchanged.

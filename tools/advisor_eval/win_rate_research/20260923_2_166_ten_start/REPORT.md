# Loaded2.166 ten-start audit — September23,2026

**3 verified wins,7 GAME_OVER losses,0 unsupported/error/timeout/interruption
outcomes across10 starts.** All ten seeds are different and none overlaps the
previous two audited ten-start batches. Operational yield is3/10 starts; this
small selected batch is not a calibrated win rate. Different seeds prevent a
matched comparison with the preceding3 wins/5 losses/2 unsupported batch.

## Provenance and integrity

Session `session-20260923T044625Z-1`, cutoff05:35:31Z/sequence17038; starts04:46:25Z.
Local interval September22 23:46:25–September23 00:35:31 Central,49m06s.
25 stable frozen segments,40,133,648 raw bytes,304,893,072 decoded bytes,
17,038 contiguous records. Strict converter passes:2,670 observations,4,763
recommendations,1,595 action requests and callbacks,1,578 settled observation
groups. No orphan callbacks or accepted actions missing settlement links.
These links do not prove every queued effect finished or every estimate was correct.

Version-stamped public events confirm loaded **2.166.0-alpha**. All2,670
snapshots project `perkeo_yorick_win_v1` with collection-progress context and
without optional Completionist goal. All105 repository/installed frozen runtime
and dependency hashes match release366. Public stamps are not loaded-byte hashes.
Every start reaches the searched Yorick+Perkeo opening; search receipts and actual
opening actions are in `deep_dive.json`. Ten searches found ten seeds; no hidden
replacement start. Session ends at run_limit17037. No tool search or gameplay.

The dedicated cursor file reads2034120347245, exactly the public last seed's
index plus one. Its bytes/hash are preserved separately. Seed progression is
observed working; a future restart's loading of that file is not observed here.

## Every start

|Run|Seed|Outcome|Final chips / target|Copy acquired|
|---|---|---|---|---|
|1|SO1AWAOV|Loss, Ante3 Wall|9,632 /12,800|No|
|2|CLGIQJOV|Loss, Ante5 Needle|7,872 /25,000|Brainstorm, Ante2|
|3|AH4CBMOV|Loss, Ante4 Small|7,767 /9,000|No|
|4|BMYW2UOV|Loss, Ante5 Big|34,980 /37,500|No|
|5|DXZFPXOV|Loss, Ante1 Manacle|487 /600|No|
|6|OS3C1APV|Loss, Ante6 Ox|62,796 /120,000|No|
|7|FR67ZKPV|Win, Crimson Heart|437,619 /400,000|Blueprint, Ante5|
|8|AILQNQPV|Win, Cerulean Bell|521,946 /400,000|No|
|9|8QEHTRPV|Loss, Violet Vessel|863,086 /1,200,000|Blueprint, Ante1|
|10|RQFHXPV|Win, Crimson Heart|562,976 /400,000|Blueprint, Ante4|

Post-win Ante9 fields are not additional Ante9 wins. Five of the seven losses
occur by Ante5, so diagnosis must include opening strength/development, not just
final bosses. Run5 had Yorick x1,Perkeo,Zany,$2 and no consumables; after using
all three discards, its four recorded scores112+312+15+48 sum487. This was an
early scoring shortfall, not stock congestion or an unsupported retirement.

## What366 actually exercised

**Seed progression:** ten fresh seeds relative to the prior batch, durable
cursor beyond the last match. WR-006's observed repetition is absent.

**Hard stops:** none occurred, but **there was no Amber Acorn round and no
Mouth zero-score cycle**. Two Mouth rounds (run1 sequences480–492 and run2
1913–1957) cleared normally. Thus this cohort does not validate the new fallback
branches in real play. Do not claim their fixes rescued two runs.

**Stock management:**10 specifically identified new-manager use actions:
Venus2103; Hermit6750/6877/7027/7112/7219/7367/7519; Temperance8822/9973.
**Zero consumable sales** across the batch. There are145 shop exits,120 with
inventory;39 Ante6+ exits,32 with multiple cards. No Observatory appears in any
snapshot, so its preservation branch has no real-game coverage here.

**Early discards:**72 Ante<=3 cash-out-cleared rounds;26 retain60 discards,
versus32/76 retaining75 previously. That is a descriptive reduction on different
seeds, not causal evidence for the new weight. Safe useful additional-discard
opportunities remain unknown because growth admission/rejection receipts are
not serialized.

## Evidence-ranked bottlenecks

### 1. WR-002/WR-005: resources are bought and copied into unsupported use paths

Run6 buys Emperor4800 ($3, Ante1), first held observation4805. It never uses a
consumable and loses holding17 Emperors plus Wheel. Run9 buys High Priestess12595
($3, Ante3), first held12600; it never uses that type and loses holding10 High
Priestesses plus10 Worlds. Run3 acquires Judgement by observation2763 after
play2758 and holds three at its early loss; this appearance alone is not proof
of a purchase or the exact generating trigger.

Source mechanism is explicit: `consumables.lua:generator_rescue`430 onward
permits only a narrowly qualified last-hand reveal, then **rejects active Perkeo**.
Ordinary generator transitions also refuse generated identities without a public
reveal. `strategy.lua:manage_teacher_stock` excludes these generators and Wheel;
`stock_capacity` leaves their copy stock unsaturated. Consequently acquisition
and copy valuation can reward stocks that the available planner will not deploy.
Do not remove the public-information safeguard or pretend generated cards are known.

Across runs3/6/9,37 shop exits hold a supported generator key with active Perkeo;
32 have at least one generator with positive public slot arithmetic after removal.
These are structural opportunities, **not32 proven legal/profitable revelations**.
`generator_shop_opportunities.json` records each candidate and slot calculation.

Negative slots matter. Run6's leave6400 has one ordinary Emperor,15 Negative
Emperors and ordinary Wheel,17/17 slots. Removing the ordinary Emperor frees
one slot; removing a Negative Emperor frees none net. Run9 leave14282 similarly
has one ordinary High Priestess,8 Negative copies,9 Negative Worlds and ordinary
Jupiter,19/19 slots. A qualified planner must compare which card frees capacity,
and refresh after a reveal/use; merely selling Negative copies cannot create room.

This is the strongest currently supported planning mismatch. It does not prove
either loss was avoidable: run6 also lacked a copy Joker and failed at62,796/120,000;
run9 had a copy but weak Flush level4 and required1.2million.

The remaining suit-card saturation gap also matters: run7 wins holding21 Worlds,
run9 loses with10. `stock_capacity` returns infinite capacity for suit cards when
the profile is a Flush hand, without counting remaining off-suit targets. Run10
wins holding23 Wheels and10 Neptunes; unused stock can coexist with a win.

### 2. WR-001: the early growth preference cannot bypass unqualified draw effects

Ten of the26 early clears with unused discards (26 of60 unused discards) carry
active Blue Joker; three also carry Raised Fist. They occur in runs1 and4.
Run4 remains Yorick x1 through its Ante3 boss despite15 retained early discards;
run1 retains11 and later loses with x2. Exact round/observation anchors are in
`findings.json:growth_scope_block_presence`.

`growth.lua:drawn_hazard`205–215 blanket-rejects Blue Joker, Raised Fist,
Blackboard and Shoot the Moon because replacement draws can reduce retained
score. The new partial-growth weight acts only after this gate. Therefore another
weight increase cannot fix these excluded cases. Their presence does not prove
the gate was reached, the105% margin held, or a safe useful discard existed.
Blue Joker needs an exact remaining-deck-count correction before admitting its
retained-clear proof; Raised Fist/Blackboard require different held-card reasoning.
Do not simply delete the shared guard. Winner8 also retained16 early discards
and still won without a copy, weakening an unconditional aggression theory.

### 3. WR-004/WR-005: chance-dependent scores and shop valuation still matter

Run2 reaches Needle with Brainstorm, uses every discard2273/2284/2295, then
Magician2316 and Flush2327. Advice predicts31,488 against25,000 but realizes7,872.
The played flush contains **three Lucky cards**. The scoring model labels Lucky
effects as averages; its no-Lucky-Mult arithmetic explains the observed shortfall
(35 base chips+38 card chips+50 Foil chips)×4 base Mult×4 Yorick×4 copied Yorick
=7,872. Adding the modeled12 average Lucky Mult gives31,488. This is not evidence of a fourfold execution/scorer
bug. The consumable explanation still says it reaches the target "in the scoring
model" alongside the uncertainty warning. A better tactical risk comparison and
typed floor/mean telemetry remain needed. With one hand and no discards left,
the existence of a better available action is not established by this miss.

Seven visible copy opportunities: four acquired, two cash-short before sale,
one affordable miss. Run3 leave3099 passes Blueprint$10 with$15. Complete
replacement receipts show Perkeo→Blueprint ratio3.000149 but merit-46.720,
Runner→Blueprint ratio2.814014 but merit13.423 (<26); Misprint replacement is
survival-dominated, Vagabond Eternal, Yorick unsupported. It is valuation, not
missing enumeration. Ratios are uncertain means, not proof replacement was safe.
The correlation is now weaker: two of four copy-owning runs win and two lose;
one of six non-copy runs wins. Copies are useful, neither necessary nor sufficient
in these observations.

Only32 of692 action-linked hand timings reach140,000. Specific incomplete
families remain possible; global budget exhaustion does not explain every loss.
310 shop receipts contain248 hold/ordinary preferences,8 replacement preferences,
17 unsupported families and37 budget-incomplete decisions. These are decisions,
not distinct opportunities or completed transactions.

## Highest-priority implementation proposal

Qualify **Perkeo-aware generator use/hold and slot preparation**, starting with
Emperor/High Priestess, and align acquisition/copy utility with supported use.
This must be a complete integration, not just removal of the Perkeo guard.

Acceptance fixtures: ordinary versus Negative generators in full/partially free
slots; one versus two generated cards; useful sole templates versus redundant
copies; active/copying/debuffed Perkeo; unsupported source metadata; full action
and scoring budgets; settlement before fresh advice; generator use without
assigning any future generated identity. Include no-safe-use counterexamples and
cases where ordinary-card use/sale frees space but a Negative sale cannot. A
bounded last-hand rescue must retain the complete supported upper-bound proof;
shop development needs its own explicit qualification rather than borrowing
that terminal proof.

Cheapest falsifier: independently manufactured public states showing existing
code already gives an actionable generator use under these conditions, or that
all candidate uses lack legal slot capacity. Do not replay these captured states.
Expected observable change: eligible generator use/slot-preparation receipts and
fresh generated observations, with fewer inert duplicate piles; no promised win.
Dependencies: consumable transition/reveal handling, strategy inventory/acquisition,
executor settlement, journal rejection reasons. Risks: pool dilution, freeing the
wrong slot, unknown-source effects and overclaiming a sampled rescue. Require
targeted fixtures plus full candidate/exact-installed gates for later policy edits.

Blue Joker growth qualification is the next separate repair candidate. Do not
raise budgets or roll these observations into another unapproved cohort.

## Evidence and scope

`capture/manifest.json` binds frozen bytes and cutoff; `capture/events.jsonl`
maps every sequence to segment/ordinal/raw SHA256. `runs.json`, `rounds.json`,
`deep_dive.json`, `replacement_receipts.json`, `focused_actions.json`,
`generator_shop_opportunities.json`, `findings.json` and `checkpoint.json` retain
compact evidence. Eleven integrity checks pass. No runtime edits/installation,
game/save/profile access, captured-state policy/scorer execution, new search,
simulation, training, automation or deletion. Existing source notes are reused;
no new external research allowance was consumed.

Analysis correction: the reused review initially paired rows by run number despite
different seeds. That output is preserved as `review_summary_initial_positional.json`
and is **not a matched comparison**. Corrected `review_summary.json` matches only
identical seeds and therefore contains no paired cases. Some console inspection
was truncated; the frozen/indexed evidence remains complete.

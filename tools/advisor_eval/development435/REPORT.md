# Closed435 targeted paired experiment

The authorized four-worker pilot is complete. All53 registered jobs were started
once: four successful admission diagnostics, one failed pack-diagnostic export,
and48 continuations. Execution took41.83seconds elapsed and158.78 summed child
wall-seconds.795seconds were reserved under the53×15-second caps; all remaining
capacity is permanently closed. No retries, substitute cases or extra worlds.
There were no timeouts. See CLOSED.json, manifest.json and results/.

Installed434/2.214 remains unchanged. This is offline project-model evidence,
not original-game execution, user-loaded outcomes or a population win rate.
The initial action alone changes; every subsequent decision uses frozen2.214.
The pack comparison assumes both branches close the shop without more spending.

## Outcomes

| Public case | Left branch clears | Right branch clears | Complete paired worlds |
|---|---:|---:|---:|
|10067, Goad pack: Sly / Trio|8/8|7/8|8/8|
|10102, Goad hand: default4 / forced5|4/4|3/4|4/4|
|13255, Violet Vessel: default3 / forced5|unresolved|one failure, three unresolved|0/4|
|18317, Big Blind: default4 / forced5|2/4|3/4|4/4|
|27883, Needle: default4 / forced5|2/4|2/4|4/4|

The48 continuations yielded31 supported clears,10 modeled failures and7
unsupported transitions.20/24 pairs have both terminal outcomes. The extra
unpaired Violet failure cannot establish a comparative result. No floor-only
clear occurred in this captured pilot; qualification separately covers that path.

Across the12 fully paired **hand** worlds (three positions), forcing the initial
five increased cards discarded from108 to128 over32 discard actions per branch:
**3.375 to4.000 cards/discard**. Full-five actions rose from2 to18. Discards used
were unchanged:32/12=2.667 per continuation; those Needle positions start with
two left, and the other two cases start with three. Both branches cleared8/12,
but four worlds changed from failure to clear and four changed in the reverse
direction. This is a descriptive matched-set result, not12 independent runs.
Every one of the41 terminal continuations exhausted its available discards.
These selected short-discard cases do not test all known unused-discard failures.

## What this resolves

**Early Sly has a real immediate-survival case.** In pack world1, Sly clears and
Trio fails. Across the eight worlds Sly discards91 cards versus Trio74; both use
24 discard actions. However, Trio uses14 scoring plays versus Sly22, generally
leaving more hands when it survives. Every pack endpoint retains$6 and52 physical
cards; Yorick remainsX1 but has different progress. Round rewards are not modeled,
so remaining hands are a resource distinction, not an asserted income result.
This supports testing an early-survival safeguard, not globally ranking Sly above
Trio or assuming delayed Trio value is worthless.

**Five cards is a meaningful tradeoff, not a universal local improvement.**
At10102 the default keeps both threes; the selected five discards both of them.
Its existing24-world candidate estimate has fewer immediate clearing samples
(3/24 versus5/24), despite a slightly higher mean score. In continuation world0,
the five loses where the default clears. In worlds1 and3, however, the five
reaches YorickX2 while the default remainsX1. Future value and current survival
point in different directions; this one-blind adapter cannot price the next ante.

At18317 the five only adds the held five of Diamonds to the default discard.
It gains two clear worlds and loses one. World3 reaches YorickX10 and clears,
where the default staysX9 and fails. World2 goes the opposite way and discards
fewer cards overall after the initial intervention. A larger first discard does
not guarantee more total growth along every later policy trajectory.

At27883 the five discards both Kings and both sixes, replacing the retained
two-pair anchor. The existing candidate estimate strongly prefers the default
(8/24 versus2/24 immediate clearing samples). The continuation totals tie2/4,
with every world reversing its outcome. Hanged Man use also differs: clearing
branches end with40 cards versus42 in failing branches. These outcomes cannot
be attributed solely to a one-card growth increment; the intervention changes
later hands and consumable choices too. See DETAILS.json for physical IDs,
candidate evidence and resource endpoints, and results/ for every action trace.

## Unresolved coverage and tooling defects

All seven unsupported branches belong to Violet Vessel13255 and stop at an
uncertain selected play containing a Lucky card with owned Jokers. The frozen
sampled_outcomes module does not supply that stochastic transition family. The
adapter's reason string mistakenly serializes the effects table as a Lua address;
the saved selected IDs, held enhancements and uncertain-score receipts establish
the missing family by source inspection. No uncaptured score evaluation was used
to diagnose it. Five such prefixes still had discards available, but their round
endings are unknown. They are not losses or proof of abandoned discards.

The pack diagnostic exceeded player_journal's structure guard while serializing
the full paired comparison. Its evidence was not emitted; the exact traceback is
preserved in results/diag_10067.log. Therefore the production finishing ranking
cannot be explained from that diagnostic. The independent pack continuations
remain usable. Qualification checked capped pack comparison/input purity but
did not require a successfully supported large finishing payload; that was a
real qualification gap. A future harness should export bounded per-policy/world
scores and outcomes without nested duplicated state objects, and preserve
structured unsupported warnings. Neither the frozen adapter nor failed job was
changed or rerun after execution.

## Validation, boundaries and next work

Before captured execution:103 manufactured Lua assertions and6 Python controls
passed; current runtime wiring,110 policy dependencies, Lua/Python provenance,
all cases/worlds/jobs, adapter and tests were prospectively hash-bound. The
read-only review found and corrected a raw consumable-action dispatch mismatch,
covered by a real production Decision fixture. That review is exhausted.
Final preservation checks are in FINAL_VERIFICATION.json.

The next useful implementation target is a bounded comparison of current-blind
survival against actual Yorick threshold progress and retained rank anchors,
with regression controls for both the rescued and sacrificed patterns above.
Blindly forcing five would discard demonstrated survival advantages. Before
another captured experiment, qualify owned-Lucky transitions and compact full
finishing exports on manufactured states. A later long-horizon adapter must
model rewards, Perkeo generation, stickers and shops before it can compare their
delayed value. Any new experiment requires a new concrete allowance;435 is closed.
Any supported runtime repair still needs a new exact combined freeze and both
release gates. No runtime repair or installation was performed by this pilot.

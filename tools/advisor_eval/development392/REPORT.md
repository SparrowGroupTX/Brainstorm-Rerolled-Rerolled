# Copied ten-start public session and uninstalled repair — 2026-09-25

The user's completed session `session-20260925T203656Z-1` was copied **before**
their next clear-and-ten-start action. `logs1/` preserves all 25 BRJ2 segment
bytes (61,464,082 bytes). `capture/manifest.json` records per-file SHA-256 and
source-match at copy time; `capture/verification.json` verifies 26,628
consecutive public events, ten starts, ten endings and a session stop. There
are ten completed searches and ten actual starts, with ten distinct recorded
start seeds. `audit_capture.py` links 2,385 auto-run requests to public
observation, advice and callback records in `analysis/`. Neither the copied
records nor a captured state were run through policy or scorer.

All 3,957 recorded teacher observations say win-first
`perkeo_yorick_win_v1`; all public loaded labels are 2.184.0-alpha. The
installed 2.184 receipt is `SESSION_RESET_386.json`; exact running bytes
cannot be attested from a label. The repository 2.189 candidate and the new
2.190 candidate were not active in these games. The user's subsequent sprint
is separate and remains untouched.

| Start | Outcome | Last public position |
| --- | --- | --- |
| 1 | unsupported | Ante 8 Amber Acorn, 50,220/400,000; 3 hands, 4 discards |
| 2 | unsupported | Ante 8 Amber Acorn, 245,160/400,000; 3 hands, 3 discards |
| 3 | unsupported | Ante 6 The Mouth, 52,290/120,000; 2 hands, 0 discards, empty deck |
| 4 | win | Ante 8 Violet Vessel, 4,498,378/1,200,000 |
| 5 | loss | Ante 6 Big, 76,088/90,000 |
| 6 | win | Ante 8 Crimson Heart, 437,787/400,000 |
| 7 | loss | Ante 8 Big, 31,616/300,000; only Madness remains |
| 8 | loss | Ante 8 Crimson Heart, 114,032/400,000 |
| 9 | loss | Ante 8 Crimson Heart, 201,180/400,000 |
| 10 | loss | Ante 6 The Wheel, 41,034/120,000 |

Operational yield is **2 wins / 10 starts**, with five verified game losses
and three **unsupported stops**, not seven losses. This selected searched
cohort is neither a calibrated win rate nor evidence that 2.189/2.190 changed
full-run outcomes. `analysis/cohort.json` has each start's actions, later row,
cash and inventory; `analysis/actions.json` retains the linked per-decision
evidence. Aggregate 284 discards selecting under five cards, 142 plays while
discards remained, and 80 shop exits with at least $50 are **screening counts**,
not 506 proven mistakes. Hand conservation, score survival, interest,
available shop opportunities and budget rejection have not been adjudicated
for all of them.

Two source-level failures are concrete. At start 7, public observation 16127
showed a non-Eternal Constellation, Perkeo, Blueprint and Yorick (x3). Advice
16128 selected Madness from a Buffoon pack; action 16132 executed it. The
visible row later shrank, ending with only Madness x6.5 at observation 18389
and a 31,616/300,000 loss. The installed Balatro archive's `card.lua:2503`
shows non-boss blind selection grows Madness and randomly destroys an eligible
non-Eternal other Joker. `strategy.lua:joker_value` subtracted only 12 rating
points; `shop_scoring.lua` excluded such blind-start rows from its finite
next-blind comparison. A preview could therefore choose a long-horizon
destructive trade without pricing the core loss. Other purchases/draws are
unknown, so the full-run counterfactual is not claimed.

At start 3, the existing Mouth fallback recommended and executed a zero-score
cycle at 7500/7503 with three deck cards. Settled public observation 7508
showed two hands, no discards, an empty deck and no consumables, still short of
target. Advice 7511 had no action and the product retired as unsupported at
7512–7514. `decision.lua:mouth_cycle` excluded empty-deck and final-hand
states even though a zero-score engine-valid play could advance the game to
its actual terminal result. This is a hard-stop classification defect, not a
verified loss. The read-only 392 review independently checked source and raw
public anchors. The two Acorn unsupported stops match the earlier 2.184
post-play phenotype addressed in **uninstalled** 2.189; matching their exact
future public belief scope remains to be tested after activation.

Repository candidate **2.190.0-alpha**, uninstalled, incorporates 2.185–2.189.
It rejects Madness acquisition in win-first play when the owned row has a
non-Eternal Yorick, Perkeo, Blueprint or Brainstorm, through ordinary
shop/pack admission and the short-shop graph. All-Eternal and collection
contexts retain separate behavior. The Mouth fallback now permits a supported
zero-score play with an empty deck or a final hand, distinguishes draw from
no-draw in the UI/receipt, and waits for the game's real terminal result.
It retains the two-score probe, concealed-information and incumbent-action
guards. `tests/advisor_mouth_madness392.lua` has 24 manufactured checks;
`advisor_marathon_repairs366.lua` now checks the extended Mouth scope.
A focused read-only recheck of all normal Madness acquisition routes and the
Mouth guards found no blocking path or regression risk. It noted optional
additional negative fixtures for concealed Jokers, excess forced selections
and warning-bearing probes; those implementation guards remain in place.

`runs/mouth_madness392_candidate/freeze.json` freezes 108 runtime/dependency
hashes and 299 test hashes. Digest:
`d5e9b7288a8d5c88c870eec812470b9fd0e4b9309bb5e79fa212bd7aea4b5ac8`.
The full candidate gate passed **259 Lua fixtures and 392 Python tests**;
policy and test hashes were unchanged across the gate. Raw logs and the report
are under `runs/mouth_madness392_candidate/validation/`. The installed product
remains 2.184 with seven native DLLs unchanged. No installation or activation
is attempted during the user's new sprint. After a normal user game exit,
verify baseline/config/native and candidate hashes, install only the nine
runtime files named in `freeze.json` via `install_slice.py` with backup, then
freeze and validate exact installed bytes. Real-game gain remains unproven.

Next diagnostic questions: inspect the five losses' early resource trajectory,
especially whether high-cash shops had legal useful reroll/purchase candidates;
qualify short discards against actually supported survival and Yorick gain;
check held Hanged Man/Planet pools and Mouth/Acorn behavior on a later loaded
version. A future clear action still needs an automatic archival path; this
session is protected by the explicit verified copy, but the current button's
routine retention risk is not fixed by 2.190.

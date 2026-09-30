# Last-slot copy opportunity — 2026-09-25

The frozen, hash-verified loaded-label-2.184 win-first session in
`../development392/logs1/` shows start 10 leaving a visible Eternal
Brainstorm behind. Advice/action 25462 sold a rental Red Card with an explicit
Brainstorm follow-up; 25472 instead opened a Mega Buffoon pack, 25483 chose
Popcorn into the free Joker slot, and 25506 left with Brainstorm still offered
and $11 on hand. `../development392/analysis/actions.json` has the linked
public observation/advice/action anchors. No captured state was evaluated
through a policy or scorer. The next user-started sprint and its logs were
not touched.

`strategy.lua:best_shop_purchase` already preferred a qualified visible
Blueprint/Brainstorm over a nearly tied unknown pack when pack cost would
make the Joker unaffordable. A Buffoon pack can consume the last Joker slot
while leaving enough cash, so the cash-only gate missed this distinct
resource. Repository 2.191 also recognizes exactly one finite ordinary slot
at risk for the four known vanilla Buffoon pack keys. It retains the existing
win-first opening, owned Yorick/Perkeo, no owned copy, early Ante, durable
nonrental copy, admission, survival-dominance, score-floor and 24-point tie
conditions. A Negative, unknown or concealed copy does not enter the new
slot branch. The receipt identifies `resource='joker_slot'` or the unchanged
cash risk, and each sale is still followed by a fresh observation.

`tests/advisor_copy_slot393.lua` checks a wholly manufactured one-slot case
where pack purchase leaves the copy affordable, 12 exclusion controls and
the prior cash case (16 checks). The existing 68-check cash fixture also
passes. One read-only review and a focused recheck found no correctness
blocker; it noted that the legacy cash path's unknown guards are unchanged.
The subsequent explicit vanilla-pack whitelist further narrows the new slot
branch. Frozen candidate digest
`704117c068d6e6a2c1bdce33e1698fbdb788d8df8f1579c80357ebaa45c9aad0`;
`../runs/copy_slot393_candidate/validation/` passed 260 Lua fixtures and
392 Python tests with unchanged policy/test hashes. This source-level repair
does not prove the recorded run would have won or that loaded 2.184 would
have selected Brainstorm under 2.191; such captured-state replay was not
authorized. No game, process, setting, save, journal or installed file was
changed. No new experiment or historical budget was used.

An additional unresolved finding is WR-044 in `../WIN_RATE_RESEARCH.md`:
Hanged Man's late copying value and a sole matching Planet's use/sale
comparison deserve a separate bounded correction. Hanged Man was useful in
intervening blinds, so the final unused copies alone do not justify a
blanket ban. The next sprint cannot test this uninstalled candidate. See
`../CANDIDATE_CHECKPOINT_393.md` for deferred release conditions.

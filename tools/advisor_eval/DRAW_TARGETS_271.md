# Upgraded completion families — 2.71

The plain-deck discard shortlist now reserves at most two of its existing 16
slots for upgraded Straight/Flush completion families when their public
composition payoff hint exceeds the incumbent play. First-per-discard-size and
incumbent keep-play proposals remain. All admitted candidates receive the same
complete scoring comparison; samples and the140000 cap do not increase.

The completion probability uses finite-population rank inclusion-exclusion or
suit hypergeometric tails. It describes only the specified draw pattern, not a
blind or run win. Duplicate discard patterns retain their highest-valued specific
window; they are not union probabilities. Straight A2345 is represented.
Jokers/Observatory, concealed or malformed cards abstain. Wild cards abstain
from Flush hints. Existing safe fast-clear70 and protected mechanics remain.
Only admitted final-budget candidates appear in target diagnostics.

Evidence: tests/advisor_draw_targets.lua uses original advisor scoring and a
legal thinned composition to expose a missed upgraded wheel. The matched24-world
mean redraw score changes1921.875→6087.5833333333 with16candidates and80626scores.
This is a synthetic component example, not a demonstrated episode rescue or
calibrated gain. Deterministic repeats and deck-order invariance pass. The full
preinstall regression is runs/jokerless271_preinstall; earlier failed fixture
expectations remain in jokerless271_draw_targets1/2, superseded by3 and full tests.

Installed with the visible-development slice at17:09:06CDT; see
runs/jokerless271_installed/record.json and VISIBLE_DEVELOPMENT_271.md. No new native
code, real saves, settings restoration or running-game control occurred.

# Win-first hand-plan refinement — 2026-09-25

See `../development390/REPORT.md` for the preserved eight-start audit and
primary evidence. This addendum records the hand-plan correction separately
from the earlier frozen 2.188 Acorn/voucher stage.

At public action 8370 in start 4, a single level-one Straight tied a single
level-one Flush and `strategy.lua:favored_hand` selected Straight by its hand
ordering. Saturn was bought and later copied/held, while no scoring Joker was
owned at the Ante 2 loss. At 15106 and 15117 in start 7, two Hanged Man uses
were justified as development of Straight despite three discards remaining;
six Straight plays at level three outweighed two Full Houses at level one.
Those actions are observable; their counterfactual full-run outcomes are not.

Win-first `favored_hand` now applies a development prior of 18 to Straight
and Straight Flush and 9 to Flush while each has fewer than eight plays and
is below level four. Real supporting Joker affinity is still counted and can
overcome the prior. Established high-level/frequent hands, the collection
profile, exact tactical scoring and hand legality remain unchanged. This
changes stock and deck-development intent, not a rule that a Straight can
never be played. The thresholds are heuristic and need later outcome evidence.

`tests/advisor_hand_focus391.lua` has nine manufactured checks covering the
early tie, actual rank-hand comparison, supported/committed Straight/Flush,
other-profile isolation and a live shop ranking of Pair Mercury above
incidental Straight Saturn. The first full 2.189 gate exposed an unintended
change to a 14-play level-three Flush/Fool/Jupiter stock case in
`advisor_fool_stock376.lua`. Restricting the prior to weakly established hands
restored that fixture without changing it. Preserve the failed gate under
`runs/hand391_candidate/validation/`; the corrected freeze and passing gate
are `runs/hand391_verified_candidate/` (258 Lua fixtures, 392 Python tests,
unchanged frozen policy/test hashes).

No source, player save/profile, captured policy/scorer replay, native seed
search or game process was executed. The repository candidate is not
installed or active while the next user-started batch is underway.

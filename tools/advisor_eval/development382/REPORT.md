# 382 win-first Yorick discard candidate — 2026-09-24

The latest frozen public evidence is still the loaded-label-2.175,
win-first six-start interrupted prefix at
`../win_rate_research/20260924_132921_interrupted/`, cutoff sequence 13,931.
It has two wins, one loss, two unsupported stops and one incomplete controller
error. Across 82 Ante-1–5 cleared rounds, 130 discards remained; that is not
a count of safe missed actions. Among 48 growth-titled discards, sizes were
2:2, 3:18, 4:11 and 5:17. A five-card reserve in an eight-card hand leaves
only three currently safe spares. Journal UI alternatives lack scorer
reliability and growth rejection fields. In particular, the Ante-4
Four-of-a-Kind ~13,668 / Flush ~19,383 display near sequence 9840 is not a
certified growth opportunity: the Flush has Mult cards and a visible row
outside the current automatic-sort proof.

Static source inspection found two narrower remediable omissions. `decision`
passed only the search-selected 100%-clear play to the 105%-margin growth
check, even if another already-scored, resource-neutral clear had enough
margin. `search` valued Burnt in ordinary below-target redraws but gave
physical Yorick progress no value, then preferred a smaller batch on equal
sampled outcomes. It also stopped immediately on any certain clear, so it
could not consider the user's requested early clear-versus-growth risk trade.

The final 2.180 candidate changes `Advisor/` search, decision, growth,
runtime and player_journal, plus the two version files. In the win-first
profile with active Yorick X<=4
through Ante 5, a current clear enters the ordinary paired redraw comparison
within the existing 140,000-score cap. A risky discard needs an exact
`after_discard` transition, including physical Yorick growth, 24 complete
common-world samples, 23/24 next-play clears in Antes 1–2 or 24/24 in Antes
3–5, a positive stage-tapered value over the certain play, neutral discarded
cards and no paid/population/cash cost. Ramen and Green Joker exclude the
growth premium. These thresholds are heuristic; the 24 samples are not a
calibrated probability or an exhaustive search of all discard subsets.

For a below-target hand, the same small Yorick progress premium applies only
within the best sampled-clear count tier and after exact physical transition
and neutral-resource checks. It can prefer a five-card batch, but neither
forces five nor overrules a larger observed survival gap. For a retained
current clear, one already-scored reliable 105%-margin alternative may anchor
the existing exact growth proof if it has no visible population, Glass, Arm
or finish-reward regression and passes the unchanged draw/order hazard.
The original selected play remains the fallback. Fast clear remains capped at
70 scores for every non-opt-in state; growth remains capped at 12 and the
ordinary decision at 140,000. The actual final action is reconciled with
the sampled-risk receipt; the UI discloses when a certain clear is traded for
an uncalibrated redraw. The public journal now records bounded scalar risk,
anchor and growth-rejection reasons without prepared worlds or draw orders.

`tests/advisor_yorick_discard382.lua` contains 74 manufactured checks: source-
normal base-card ability shape, 5 versus shorter batches, exact Yorick X after
discard, one failure in 24 matched worlds and the later-ante decline,
held/cash/population exclusions, budget refusal, alternative-anchor
rejections and specialist override. Existing growth, search, fast-clear,
resource, journal and runtime fixtures passed targeted checks. The read-only
reviewer found an initial source-normal ability mismatch; it was fixed and
rechecked before freeze. The first frozen candidate passed but lacked the
structured journal receipt; its evidence remains in `../runs/yorick382_candidate/`
and is superseded. Final frozen candidate digest is
`7645564874e6302e7b435f8748973065f8d63f82f7c20294cf8903583c0d23b0`;
`../runs/yorick382_candidate2/{freeze.json,validation/report.json}` records
the exact files. Full final candidate regression passed 252 Lua fixtures and
392 Python tests with matching frozen policy/test hashes.

At the post-validation process check, Balatro was running (PID 54168,
started 2026-09-24 11:54 local). No game process was controlled and this
candidate has **not yet been installed or activated**. Installed 2.179 and
the existing settings, saves, seven native DLLs and all logs remain
untouched. No captured observation was passed to a policy/scorer, no new
seed search or experiment ran, and no real-game win-rate gain is known.

## Release update — 2026-09-25

After Balatro exited normally, the installed 2.179 baseline, current config,
seven native DLLs, candidate policy and 292 test-file hashes were verified.
The seven changed runtime files were installed as 2.180.0-alpha at
2026-09-25T09:40:37.5981874-05:00 with backup
`C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260925-094036`.
`../runs/yorick382_installed/{record.json,policy/}` attests all 92 deployment
files and 108 frozen runtime/dependency files. Exact-installed regression at
`../runs/yorick382_installed_validation/` passed 252 Lua fixtures and 392
Python tests with unchanged candidate policy/test hashes. Final verification
is `../runs/yorick382_final/final_verification.json` and
`../SESSION_RESET_382.json`. Current settings and all seven DLLs were
preserved. Installation does not establish activation; no 2.180 gameplay
result or win-rate improvement is known.

# Tactical supported score floors —368

Installed2.168.0-alpha at2026-09-23T01:16:40.7656848-05:00.
Backup:`C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm/deployment-backups/advisor-20260923-011639`.
Policy digest:`3b436d7232fa2b085e2c03a481333442f7496544054018cac1c6451d0ef7444d`.

## Behavior
367 distinguishes deterministic clears from uncertain means but tactical owned
consumables still lacked lower-bound probes. `Advisor/consumables.lua:suggest`
now completes each transformed state's mean-score subset enumeration, then checks
at most four deterministically ranked uncertain subsets within remaining allowance.
A legal, finite, nonuncertain, explicitly reliable supported floor reaching target
can become the candidate's guaranteed score; expected_score retains its mean and
conservative/deterministic_exact fields distinguish it from an exact outcome.
Unsupported or unverified means remain uncertain, never invented probabilities.

The baseline can receive one charged floor check to avoid unnecessary targeted
spending. Single-use and bounded two-use sequence comparisons share floor handling.
Single-pass work limits preserve the sequence reservation. All probes count toward
existing caller/25000 consumable/140000 ordinary caps; other score limits unchanged.
Only the first action is dispatched, followed by normal settlement and fresh advice.
Advice explicitly calls a floor a supported minimum. Diagnostics count candidates,
checks and proofs and disclose unavailable/partial coverage; bounded coverage warns.

`Advisor/search.lua:better` now requires two reliable clears before applying
clear-only Arm/card-conservation tie-breaks. Two uncertain means merely exceeding
target no longer trigger those tie-breaks. Equal-score stable tie-breaks remain.
No unrelated shop, stock, growth, search recipe or execution-policy changes.

## Validation and preservation
New `tests/advisor_risk_floors368.lua`:30 manufactured checks, including real Lucky
and Planet scoring, higher-mean unsafe versus lower-mean safe alternatives, invalid
bounds, exact caps, shortlist coverage, immutable inputs, baseline preservation,
caller opt-out, two-use sequence proof and insufficient-budget refusal. Existing
200 reservation checks,99 sequence checks and263 inventory-reuse checks pass.
The deterministic inventory outputs and score-call counts remain unchanged.

Final candidate2:240 Lua fixtures/391 Python tests pass,35.016s/12.672s.
Exact installed:240 Lua fixtures/391 Python tests pass,35.031s/12.547s.
Both retain unchanged frozen policy/test hashes and60s suite caps. Initial targeted
failure exposed unconditional diagnostics on unchanged deterministic outputs; lazy
initialization fixes it. First full candidate passed, then floor advice labels were
clarified and candidate2 revalidated. Preserve all these raw records; candidate1
was superseded passing evidence, not a failed gate.

Evidence: `development368/` (before bytes, runtime.diff, scope/budget/review,
targeted logs and preservation receipts), `runs/risk368_candidate2/validation`,
`runs/risk368_installed/record.json` and policy, `runs/risk368_installed_validation`,
and `runs/risk368_final/final_verification.json`. Canonical finding: WR-004 in
`WIN_RATE_RESEARCH.md`; source cohort unchanged under
`win_rate_research/20260923_2_166_ten_start/`.

All89 deployment and105 frozen runtime/dependency files match. Current config
SHA2565f6bc777a681c4b498cc9193912a1234fbfd1457b91b3b919bb23672d2bb5c8b
and all seven DLLs were preserved. Active DLL remains
Immolate-advisor-ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf.dll.

## Limits
Four candidates may miss another safe subset. Extra proof work consumes existing
allowance and can reduce other candidate coverage. This is a bounded supported-floor
repair, not complete stochastic planning or calibrated survival odds. No claim that
the observed Needle loss had a rescuing alternative. Latest actual audited cohort
remains loaded2.166:3 wins/7 losses/10 starts, zero hard stops.2.168 activation and
real-game benefit are unverified; normal user restart required.

No game control, save/profile access, captured-policy/scorer replay, original-source
execution, searches, simulations, training, agents or automation. All historical
budgets remain closed. No new cohort pending. Remaining priorities are in
NEXT_PRIORITIES_368.md and the WR ledger; this authorized slice ends here.

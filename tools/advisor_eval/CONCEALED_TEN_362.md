# Ten-card concealed immediate comparison (362)

The observed Fish rejection came from the immediate planner's nine-card size bound.
The user authorized the proposed bounded correction. Only
`Brainstorm/Advisor/concealed_belief.lua` and the two runtime version fields changed.

COMPLETED362 TEN-CARD CONCEALED SLICE

Concealed immediate play now supports ten held cards. It compares every one-to-five
card subset (637 without a forced card) in the same 12 sampled public-consistent
worlds: 7644 scores inside the unchanged 8000 cap. At most nine cards retain the
16-world default. Explicit sample requests are honored only if the full comparison
fits. More than ten current cards and more than nine future cards remain unsupported
in their respective planners. Incomplete future work retains the complete immediate
fallback. Population, unknown-origin, hidden-Joker and unsupported-scoring guards,
copy-work charging and ordinary routing remain intact. No hidden identities are
read as known information. This fixes the observed size rejection, not every Fish
position or unknown mechanic. Normal marathon stop behavior is unchanged.

Passive loaded-2.161 session-20260922T170022Z-1 (cutoff 2026-09-22T17:04:57Z,
sequence 464) was normal collection: max_runs=10, teacher_batch=false. Its first
run stopped unsupported_stalled with zero recorded wins/losses, not a loss.
Evidence: development361/fish_review/POSTMORTEM.md, diagnosis.json and frozen logs1.
No captured state was run through a policy/scorer. No 2.162 activation, terminal
outcome, rescued run or win-rate improvement is demonstrated. Full scope and tests:
CONCEALED_TEN_362.md and development362. All experimental allowances remain closed.

## Verification and installation

Installed 2.162.0-alpha at 2026-09-22T12:21:01.1374193-05:00.
Installation: C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm.
Backup: C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260922-122100.
Policy digest: b882e630a6ea1c3b81d7646d8da839c13a3e80d281e871f101db27e3ac7a3c70.
All 89 deployment and 105 frozen runtime/dependency files match. Full candidate
and exact-installed gates pass 233 Lua fixtures and 391 Python tests, with
unchanged policy/test hashes and 60s per suite. Evidence: tools/advisor_eval/runs/
concealed362_candidate/validation, concealed362_installed/record.json and policy,
concealed362_installed_validation, concealed362_final/final_verification.json.
Current settings and seven DLLs preserved; config SHA256: 5f6bc777a681c4b498cc9193912a1234fbfd1457b91b3b919bb23672d2bb5c8b.
Active native remains Immolate-advisor-ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf.dll.
Activation of 2.162 unconfirmed; normal user restart required. No 362 implementation,
installation or validation is pending. Intermediate failures are preserved.

Manufactured `tests/advisor_concealed_ten_card362.lua` passes 10638 checks,
including independent enumeration of all 637 subsets, the same 12 worlds for each,
7644 actual scoring calls, deterministic hidden-assignment/deck-order/ID invariance,
caller cap and explicit-sample rejection, forced selection, fresh observation,
unsupported scope, and integrated Decision/copy/continuation shared-cap fallback.
No real saved or captured game was evaluated. The original runtime fails the new
fixture at the expected ten-card rejection (`development362/baseline_regression.log`).

`tests/advisor_concealed_nine_card.lua` retains 7584 checks and the 16-world
nine-card behavior; only the obsolete size boundary moves to eleven. Other targeted
concealed belief/continuation/copy-order fixtures pass. `targeted01.log` preserves
an initial fixture-only ID-renaming error (separately copied card areas were not
all renamed); corrected fixture passes in `targeted02.log`. No runtime safeguard
or test acceptance was weakened. One independent read-only Astra Medium review
found no release blockers; see `development362/REVIEW.md` and `runtime.diff`.

Candidate and exact-installed report paths above retain full commands, timing,
policy and test hashes. The final receipt binds these records and documentation.
Current settings, saves/profiles, game process, journals and all seven existing
native DLLs were left intact. No new experiment, search, captured-policy/scorer
job, complete attempt, training or automation occurred (`development362/BUDGET.json`).

Next priority remains whole-inventory Perkeo use/hold/supported-sale planning.
Normal-marathon unsupported stopping and broader concealed continuation are separate
remaining work; this release does not promise ten completed games or ten wins.

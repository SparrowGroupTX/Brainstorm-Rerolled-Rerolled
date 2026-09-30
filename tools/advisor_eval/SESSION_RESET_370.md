# Checkpoint 370 — 2026-09-23

Release 370 is the auto-run action-lifecycle refactor described in
`development370/AUTO_RUN_ARCHITECTURE.md`. It changes shop settlement
injection and acknowledgement ownership, **not gameplay strategy**, search
recipe, native code or teacher settings. Candidate 2.170.0-alpha was held
while the user played the ten-start cohort; its exact candidate gate passed
241 Lua fixtures and 391 Python tests with unchanged policy/test hashes.
After the user reported completion, the candidate and installed 369 baseline
were rechecked, and exactly five runtime files were installed with
`install_slice.py`: `Advisor/auto_run.lua`, `Core/auto_run_product.lua`,
`Core/auto_run_settlement.lua`, `Core/Brainstorm.lua`, and
`steamodded_compat.lua`. The installation receipt, frozen installed policy,
exact-installed gate and final hashes are under `runs/auto_arch370_*` and
`SESSION_RESET_370.json`. The installed version is 2.170.0-alpha; activation
requires the user's normal restart and has **not** been observed. The cohort
below loaded 2.169, not this new installation.

The latest user-started, action-linked cohort is
`win_rate_research/20260923_2_169_ten_start/REPORT.md`: ten distinct
searched Red Deck/Gold Stake Yorick + Perkeo starts, two verified A8 wins,
eight verified losses, zero hard stops/nonterminal outcomes. The public log
stamps 2.169 and all 2,696 snapshots select `perkeo_yorick_win_v1`; exact
loaded bytes are not attested. Capture cutoff is 2026-09-23T16:36:58Z,
sequence 17189. All 25 frozen journal segments and original hashes are in
that directory. It is a small selected cohort, not a calibrated win rate or
causal comparison with the earlier loaded-2.168 cohort. No captured state
was run through the policy/scorer.

The canonical `WIN_RATE_RESEARCH.md` ranks the new evidence. WR-010 is a
confirmed **coverage gap**: run5 had $9, a $10 Blueprint, a free Joker slot,
and a $2 sellable Ice Cream, but sale-to-fund-copy was not compared. It is
not a proven winning trade. WR-011 records Burglar's zero-discard horizon in
run6; WR-012 records zero paid rerolls over 147 exits and no proactive safe-
current-blind procurement path. WR-002 stock quality and WR-001 safe early
growth remain conditional. Two late losses owned a copy Joker. See
`NEXT_PRIORITIES_370.md` and `ARCHITECTURE_MAP_370.md` for navigation.

Preserve all tracked/untracked work and all public journals; no commit,
reset, clean, deletion, PR, fresh checkout, old-settings restore or new
purge. Do not launch, restart, foreground, stop or control Balatro through
tools, read/modify saves/profile, infer hidden identities, or replay captured
states through policy/scorer. No new hidden seed search, original-game-source
execution, complete simulation, training, scheduled job, tool-started cohort
or historical budget rollover is authorized. The user controls normal game
restarts and batches. Preserve existing action/session/log caps, native DLLs,
settings, deterministic sampling, complete common-world comparisons,
unsupported-mechanics guards, physical/population conservation and runtime
score caps. The full standing execution/preservation/release requirements
remain in `ADVISOR_RESUME_PROMPT.md` and the prior 369 reset; this factual
checkpoint does not supersede them. Later verified evidence supersedes older
pending and activation wording.

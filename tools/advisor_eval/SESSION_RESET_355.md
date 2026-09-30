# Learning prototype 355 — runtime remains installed 2.154.0-alpha

This tooling work follows the user's new request to build and try a learned
Balatro agent, research modern game learning, and use their RTX 5090 for all
model training. That instruction supersedes the older no-neural/GPU restriction
for this isolated prototype. No previous experiment allowance is reused.

**Experiment status: CLOSED.** `development355/CLOSED.json` supersedes all
earlier active/pending wording. P01, S01, T01, T02, V01, V02 and V03 completed;
T03 and its entire unused capacity are closed without execution. Nothing is
running or scheduled. Reserved: 3,030 coordinator wall seconds; consumed job
reservations: 2,130 seconds; actual: 1,353.796999999904 seconds. At most eight
simulator processes ran per job. This is not summed CPU time. Original-source
workers, seed search, player saves/profiles, game control and automations: zero.
Do not reuse or replace a spent/closed lease. Any further actual experiment
requires a fresh concrete scope, total budget and authorization.

The installed product is unchanged. Exact runtime checkpoint, installed hashes,
preserved settings/native DLLs and 224 Lua / 361 Python regression results remain
in `SESSION_RESET_354.md`, its JSON and `runs/growth354_final/final_verification.json`.
No learned model has been installed or connected to auto-run. An existing public
log separately records loaded 2.154.0-alpha at 2026-09-16T15:10:48Z; this does not
report the currently running game's state. The game was never controlled.

## Current evidence

- P01: RTX 5090 / CUDA12.8 / PyTorch2.9.0.dev20250801+cu128; BF16 finite numerical
  check passed. Its tiny first-use timing is not a precision speed comparison.
- S01: 10,000 simulator decisions, 265 attempts: 175 losses, 83 unsupported,
  seven job-limit censored, zero wins. Approximately575.54 decisions/s across
  eight workers, with the simple public heuristic and no neural inference.
- V01: 32 fixed development seeds, 21 losses, 11 unsupported, zero wins.
- T01: 100,000 actions, 3,546 started attempts: 3,040 losses, 499 unsupported,
  seven censored, zero wins. CUDA BF16 PPO plus an explicitly weak public
  heuristic imitation auxiliary; 5,431,874 parameters. This is changing-policy
  generic training evidence, not the specialized target cohort or a win rate.
- Latest user steering restricted the target to Red Deck / Gold Stake with
  Perkeo and Yorick, maximizing average **distinct new Gold stickers per game**.
  `AMENDMENT_SPECIALIZED.json` changed remaining jobs without increasing limits.
  The proposed White Stake curriculum was cancelled and never executed.
- T02: specialized CUDA BF16 training, 5,607,074 parameters, 127,744 actions,
  6,986 starts: 6,859 losses, 119 unsupported, eight censored, zero wins and
  zero terminal sticker rewards. Its actor starts from an explicitly checked
  T01 migration; appended status weights and the changed-objective value head
  start at zero. Ninety-six manufactured tests passed before T02.
- V02: 32 matched development pairs. Learned: 28 losses, two unsupported,
  two step-censored; weak heuristic: 23 losses, nine unsupported. No wins.
  All 32 learned attempts sold both opening Jokers in their first two actions.
  1,564 of 2,177 learned decisions were Joker reorders. Observed supported-prefix
  clears averaged 1.5 learned / 3.15625 heuristic; these include censored prefixes
  and are not complete-run progress estimates. Learned was higher on zero pairs,
  equal on 11 and lower on 21. The heuristic is not the installed advisor.
- The T02 policy was frozen and rejected for promotion before V03 in
  `FINAL_POLICY_SELECTION.json`. V03: 32 separate final-namespace pairs; learned
  30 losses, one unsupported, one step-censored; heuristic 21 losses,
  11 unsupported. No wins/new stickers. Observed prefix means 1.1875 / 4.28125.
  No tuning followed this final evaluation. Checkpoint SHA-256:
  `86d4c62a0a375c9ab5e44a07732f7fa7051528ad773bd1369ddb51d2b7883086`.
- Final manufactured tooling regression: **105 tests passed**. Receipt and output
  are `development355/test_receipt.json` and `manufactured_tests.log`; no episodes
  or training were performed by those tests. Final hashes are in the355 JSON
  checkpoint and `development355/final_verification.json`.

Failures, unsupported states and censoring remain distinct. Recorded zero awards
are not evidence of a zero true win probability, nor a fully observed reward mean
when attempts are unresolved. Offline audits in `jobs/V02/analysis.json` and
`jobs/V03/analysis.json` preserve that distinction. No verified complete Jokerless
win was produced here, and no actual player award was produced by this tooling.

The fast engine is a pinned MIT-licensed external candidate, Jackdaw commit
`92df18c27e26e6d324132942905e41242e4e24bf`, not a replacement for our source reference.
The stock RL wrappers leaked hidden information, obscured candidate identities
and failed to stop at the first Ante8 win. A new public-only interface fixes those
contracts. A separate hash-gated overlay repairs source-confirmed Burnt/Perkeo
copy and sticker errors. Known perishable expiry, passive debuff and Mime resource
discrepancies censor attempts. Many mechanics remain unqualified. Synthetic
default catalog runs do not represent the player or prove real-game win rates.

The specialized public observation includes the entire three-status collection
map and target Joker status: missing / complete / unknown. The frozen public log
map contains 59 complete, 91 missing and zero unknown at 15:10:48Z, not a claim
about the current collection. It gives terminal simulated credit only for
distinct known-missing held identities at an eligible final win; buying, holding,
duplicates and zero-new-sticker wins give no extra credit. Gamma is 1, with no
time penalty. A small progress potential cancels at a true terminal; every
completed training loss therefore has total return zero. The policy has not
learned the intended support-retirement tradeoff.

`specialized_environment.py` uses a constructed public post-Soul opening:
Red/Gold, Small skipped, Big next, $4, ordinary Perkeo/Yorick, fresh X1/23 Yorick,
no consumables. It does not reproduce Soul RNG or the native filter. It is not
an exact replay of the supplied seeds. S7PXV521, RH45AD21 and YAEARC31 remain
previously inspected development data, never hold-outs. Initial collection
status stays fixed across this pilot; it is not a changing player campaign.

The prototype has no recurrent memory, public deck-history reconstruction,
search, trained world model or calibrated win probability. The correct reward
and available status inputs are not evidence of strategic understanding. See
`development355/MODERN_GAME_LEARNING.md`, `development355/SIMULATOR_FIDELITY_AUDIT.md`
and `../advisor_learning/README.md` for evidence and omissions. The concrete
failure analysis is in `SPECIALIZED_POSTMORTEM.md` and `V02_LEARNING_REVIEW.md`.
Latest sparse-reward research and the proposed next training sequence are in
`SPARSE_REWARD_NEXT.md`. They authorize no new workers.

Keep the running game undisturbed. Preserve all dirty and untracked work, current
settings, saves and native DLLs. No commit/reset/clean/deletion/PR. No background
continuation or renewed/relabeled leases. Installation requires a tested useful
runtime slice; this isolated tooling is not such a slice.

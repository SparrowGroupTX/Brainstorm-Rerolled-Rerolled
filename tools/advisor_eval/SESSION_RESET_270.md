# Current checkpoint — 2.70.0-alpha, 2026-09-12

Read NEXT_PRIORITIES_270.md next. This supersedes 269 and earlier current-state
wording. The user authorized failure-driven improvement focused on Knife's Edge
and Jokerless, then explicitly authorized a wave using up to five manually
restored checkpoints per run. This release implements a bounded first-decision
retry feature. The broader top-ten roadmap is not complete.

The objective remains minimum expected real time to finish all 20 challenges,
including failed attempts, retries, opening/filter costs, computation and user
actions. The 50%/75% targets apply to EACH challenge and remain unproven.

## Installed state and exact verification

Installed **2026-09-12T14:24:50.1078391-05:00**, version **2.70.0-alpha**. Backup:
`C:/Users/trevo/AppData/Roaming/Balatro/Mods/Brainstorm/deployment-backups/advisor-20260912-142449`.
All **49 deployment files / 64 frozen product and dependency files** match the
repository and installation. Exact hashes are in SESSION_RESET_270.json and
`runs/development270_installed/record.json`, `policy/`, `final_verification.json`.

Policy digest: `bfd867f36693b720026332674253a47380d1f5a18cbad594534609e748eec47b`.
New source adapter digest: `c38107e749df5e4d4e42f07de012cbc6236edff19b28b0723f566b6b08b95712`.

Final frozen candidate: 97 Lua fixtures and 221 Python tests pass, separate 60s
caps, 9.282s / 9.421s, unchanged policy/test hashes, in
`runs/development270_candidate_final/validation`. Earlier candidate also passed;
one later evidence-wording guard was then tested and included in the final freeze.
Exact installed regression: **97 Lua fixtures / 221 Python tests pass**, separate
60s caps, 10.031s / 11.188s, unchanged bytes, in
`runs/development270_installed_validation`. No installation, failed final
regression or source worker is pending. Earlier focused test failures remain
preserved and superseded, never relabeled as passed.

Settings were preserved at installation SHA256
`083f6c62a485cceceae4f0c55708ddde2750d18a0912e39cfcca47fc0e722f6c`.
User activity may later change settings; NEVER restore historical configuration.
Both native DLLs are unchanged: legacy
`34598478571391d272c1e1a837832061bd767a09ab552bb61ef3458e24e9d751`,
sidecar `a569e1cb834352c23fed5eac3db30059279a57fe1eaf46e71cc8a594b672f885`.
No native, game-process or save work occurred. Loaded game version is unknown;
activation waits for the user's normal restart. Product Execute remains clicked
by the user. No new source or full-attempt workers ran in 270.

## 270 implementation and source/test map

- `Advisor/retry_memory.lua`, `tests/advisor_retry_memory.lua`: pure bounded
  public-state ledger, canonical first-action keys, imported report/counter
  consistency, five reports shared across checkpoints. 177 focused checks.
- `Advisor/retry_journal.lua`, `tests/advisor_retry_journal.lua`: bounded plain-data
  non-executable codec and injected storage; write-ahead guard plus readback;
  64 identities / 16 MiB. Missing, corrupt or interrupted data cannot silently
  initialize or restore a lower counter. Stale pending writes are refused.
  112 focused checks; no actual user journal was accessed during tests.
- `Advisor/retry_policy.lua`, `tests/advisor_retry_policy.lua`: no additional
  scoring or samples. Uses complete existing plain-hand/discard and visible
  Planet pack/shop comparisons at a marked public match; filters reported line
  starts, preserves protected clears/population/inventory/resources and refuses
  unsupported substitution. Final focused fixture has 90 checks. A certain-loss
  final-hand explanation requires complete known evidence; uncertain inputs
  remain review-only. No provably losing substitute is executed automatically.
- `Advisor/search.lua`, `Advisor/strategy.lua`: export detached complete discard
  summaries and exact projected pack actions. No default ranking, score budget
  or sample changes. Adaptive discard elimination is not retry-complete because
  removing its previous leader invalidates its stopping argument.
- `Advisor/decision.lua`, `Advisor/runtime.lua`, `UI/advisor.lua`: explicit manual
  checkpoint controls; actual accepted Execute records a first action. Pending
  restored state needs an explicit reported loss. Generation, state epoch,
  public observation, persistent identity and transient game object bind
  callbacks/workers; stale clicks cannot reuse identical-state advice. Unknown
  storage is review-only. Runtime fixture now has 405 checks; UI fixture 55.
- `tools/advisor_eval/engine_probe.py`, `engine_run.lua`,
  `paired_policy_audit.py`, `outcome_validation.py` and
  `tests/test_advisor_retry_eval.py`: frozen disabled-clean retry context,
  independently applied receipt and strict auditing. See RETRY_EVAL_270.md.
  Source-profile synthetic qualification remains false. New schema2 registrations
  cannot claim manual retry evaluation; historical schema1 absence is explicitly
  historical_unreported, with no rewriting or invented activation.

Eight explicit runtime files plus the tool-owned Core/compat version stamps
were installed with install_slice.py. See RETRY_CHECKPOINTS_270.md for exact
workflow, bounds and limitations; RETRY_EVAL_270.md for evaluator compatibility.

## Manual workflow and limits

The user saves a checkpoint themselves, then at the same settled decision opens
Ctrl+H and selects **Remember this decision**. The first action must use Product
Execute to be recorded. After a losing continuation the user restores manually,
waits for the matching public state to settle, and selects **I restored after a
loss - try another line**. No save is created, verified, loaded or modified by
these controls; no loss is detected automatically. Five accepted reports permit
the original line plus five restored lines. Mark changes never renew the count.

This remembers the FIRST executed decision starting a reported losing line,
not an entire continuation or proof that its first move caused failure. Manual
first actions outside Execute are not recorded. Alternative selection currently
admits no owned Jokers or Observatory engine, plain small visible hand families
and restricted complete Planet endpoints. Complex Knife's Edge Joker positions
and protected growth/concealed/larger resource paths commonly require review.
The feature is not five independent random fresh runs or guaranteed useful retries.

Public keys omit hidden RNG, draw order and unstable object IDs but include known
composition and public mechanics. Concealed or inconsistent populations abstain.
A match proves public equality, not save/RNG equivalence. Profile/seed/challenge/
deck/stake identify a conservative shared cap: a genuinely new same-identity run
may inherit earlier spending. The user must preserve the two journal metadata
files while restoring saves. External rollback/deletion of both files is not
detectable tamper-proof storage and is not authorized allowance renewal.

## Existing completed work and preserved mechanics

269's owned Judgement/generator ceilings, narrow exact order-equivalence work,
complete revealed-Planet dominance and certified generator priority remain.
268's Emperor/Priestess revelation, zero-actual-Joker-rate Planet refresh and
ordered Dagger/Chicot forecasting remain. Use GENERATOR_RESCUE_269,
PLANET_COMMITMENT_269, FINAL_ORDER_269 and the relevant 268 notes only.
Use 266's architecture/source-map sections for unchanged components.

Earlier tactical pack/shop replacements, economy/survival, bounded finishing and
concealed continuations, safe scoring reuse and evaluation/replay tools remain
within their documented scope. Two opening Legendaries plus one optional later
Rare by Ante 2–8 are implemented; affordable acquisition, survival and retention
are not guaranteed. Jokerless is excluded from Joker filters. Ordinary discarded
backs are public; genuinely concealed discarded cards retain their safeguards.
Do not repeat completed batches.

Deterministic sampling, complete comparisons, ordinary 140000 / shop 50000 /
consumable 25000 / fast-clear 70 caps, Glass/population conservation, whole-
inventory Perkeo/Negative/Observatory, Kings Strength/Death, exact Yorick/Burnt,
safe growth and joint Joker/card order rescues remain protected. No native change,
global coefficient promotion or calibration was performed in 270.

## Evidence, odds and closed budgets

270 has unit/protocol evidence, **no terminal cohort, no checkpoint-branch cohort
and no demonstrated win-rate or completion-time gain**. The source adapter does
not exercise retry history, journal IO, restore or retry UI. Current/projected
player odds and all-20 completion time remain unknown. Recent guesses requested
by the user, including 40%/60% under a five-reload assumption, were explicitly
speculative; they are not reliable forecasts, calibrated results or new targets.
Passing tests and feature counts cannot establish wins or percentage-point gains.

- `focus268_development1`: frozen267/268 four source losses, identical role actions
  (Knife100/Jokerless17), zero timeout/unsupported/missing/censor/audit errors,
  178.1854702s wall. Four80s workers/340s workflow CLOSED. FAILURE_EVIDENCE_268.md
  owns failure details. Failures were not replayed or imputed rescued by 269/270.
- Original262/266 pilot `weakness266_current_pilot1`: 6loss / 5timeout /
  5unsupported,729.6207304s, all sixteen80s leases and1320s workflow spent.
  Old weakness263_requests remains its unexecuted original plan with no unused
  entitlement. Both step75 component leases are also spent.
- `focus268_component_allowance1`: three15s workers executed, one withdrawn,
  allowance closed,5.9077258s actual. FIFO candidate was slower and rejected;
  preserved, never installed. No cache-hit-rate-only performance claim.
- `planet_pool_source1`: one10s source worker passed10cases/74assertions,
  0.086772s, spent. `chicot_order_source1`: one10s source worker errored after
  three successful case records,0.090547s; remaining cases not executed. Spent.

No lease renewal, re-registering spent attempts, extended cap or imputed outcome.
Genuinely new useful experiments require fresh directories, prospective frozen
policy/adapter/profile/options and explicit one-use caps. Preserve errors,
timeouts, unsupported, missing and censored attempts. Retry branches are dependent
parts of one run; clean, checkpoint and filtered-route evidence stay separate.
Expanded-filter acquisition/retention is still unmeasured and unqualified.

## Operations

Preserve ALL tracked/untracked work on codex/exact-search-speedups. No commit,
reset, clean, deleting existing work or PR. Never launch Balatro.exe, even headless;
never foreground/fullscreen/restart/stop/control the game or execute live gameplay.
No saves for evaluation. Hidden bounded ZIP reads and isolated lua51.dll only.
No neural/GPU training, schedules or automations. Install tested coherent runtime
slices immediately via install_slice.py with explicit files, backups/settings
protection and verified hashes/versions. Preserve both native DLLs; changes need
the documented sidecar/evidence gate. Tooling/docs-only changes need no release.
Maintain START, HANDOFF, checkpoint/priorities and ADVISOR_RESUME_PROMPT.md.

Continue development in:
C:\Users\trevo\Documents\GitHub\Brainstorm-Rerolled-Rerolled

This is a reset after a usage-limit interruption, followed by completion of the
interrupted repair. Do not depend on old chat, subagent or tool memory. The user
requested this detailed handoff on September 22, 2026. Preserve the existing
workspace and every tracked modification and untracked file on
codex/exact-search-speedups. Most development is uncommitted. Do not commit,
reset, clean, delete existing work, discard changes, create a PR or move to a
fresh checkout.

READ FIRST

1. ADVISOR_START_HERE.md.
2. tools/advisor_eval/SESSION_RESET_359.md and NEXT_PRIORITIES_359.md.
3. Relevant tools/advisor_eval/ARCHITECTURE_MAP_359.md sections and the earlier
   maps it links for unchanged components.
4. tools/advisor_eval/YORICK_DISCARD_PRIORITY_359.md and
   tools/advisor_eval/development359/RESET_20260922.md.

Exact hashes are in SESSION_RESET_359.json and
tools/advisor_eval/runs/growth359_final/final_verification.json. Read only
relevant dated ADVISOR_HANDOFF.md sections; do not consume the whole historical
handoff. Later verified status supersedes historical unchecked items, estimates,
pending/deferred wording, old authorization and old loaded-version claims.

CURRENT VERIFIED CHECKPOINT

Installed version: 2.159.0-alpha.
Installation time: 2026-09-22T10:31:04.4428288-05:00.
Installation: C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm.
Latest backup: C:\Users\trevo\AppData\Roaming\Balatro\Mods\Brainstorm\deployment-backups\advisor-20260922-103103.
Policy digest: 44550e55371a8e4eb41aa4ea6aea30006daf5e693a4c93bcdc870d591b4f839e.
All 89 deployment files and 105 frozen runtime/dependency files matched
repository and installation. Both full candidate and exact-installed regression
passed 231 Lua fixtures and 391 Python tests with unchanged frozen policy/test
hashes. Current settings and all seven existing native DLLs were preserved.
Active native file:
Immolate-advisor-ecf7343e5cc19be0cf10d55e04a18b54b3456134e79acbd0dc1513ad73070acf.dll.
This release changes no native DLL. Exact settings/native hashes and preservation
receipts are in the final record; never restore old configuration.

Evidence directories:
- tools/advisor_eval/runs/growth359_candidate/validation/
- tools/advisor_eval/runs/growth359_installed/record.json and policy/
- tools/advisor_eval/runs/growth359_installed_validation/
- tools/advisor_eval/runs/growth359_final/

2.159 activation has NOT been confirmed. The September 16 public logs prove
2.158 was loaded then; that is not evidence about today's running process.
Activation waits for my normal restart. No 359 implementation, installation,
failed final regression, worker, search, training job or scheduled continuation
is pending. Intermediate failed component tests were preserved and superseded
by passing final validation; do not delete or misreport them.

CURRENT OBJECTIVE AND STRATEGY

The immediate focus is better actual Red Deck Gold Stake play with a searched
Yorick + Perkeo opening, building a reliable win-first heuristic teacher and
auditable real-game demonstrations. The eventual Completionist++ objective is
new distinct Gold-sticker Jokers per real time, including losses, retries,
search, computation, animation and user-action costs. Surplus score, unused cash,
copies, acquisitions and already-Gold-only wins are not the achievement goal.
The temporary win-first teacher deliberately suppresses optional sticker trades;
do not confuse that profile with the normal collection objective.

My preferred opening is Yorick and Perkeo from the starting Charm Pack, with
Blueprint or Brainstorm by the end of Ante5 (copy function is the aim) and Burnt
Joker if affordable to search for; Burnt is optional when it makes search slow.
No perishable targets. Maximum native CPU mode was requested. Red's extra discard
is useful; other supported decks can be compared without hardcoded deck/seed
advice. Starting Charm routing must use the actual searched tag and opening,
not simply assume the first Small Blind has a Charm Tag. Existing product search
and opening integration are implemented; do not restart earlier completed work.

Yorick should use worthwhile discards before clearing, preferably five cards
when safe. First-discard Burnt should favor a viable long-term hand. Perkeo should
retain a useful copying pool and support Death/Strength rank consolidation,
appropriate Planets, Hanged Man, profitable Temperance/Hermit and worthwhile
enhancements. My preference for Kings and rank-hand development is useful context,
not an unconditional forced Four of a Kind policy. Blueprint/Brainstorm ordering
can differ before leaving shop, first discard and scoring. Account for cash to
buy planned Jokers and replacement of expendable already-Gold Jokers when safe.
Do not keep improving score indefinitely after a safe finish is available.

INTERRUPTED REPAIR NOW COMPLETED IN 359

The latest complaint was rounds clearing before using discards and repeated
Empress use on the opening hand. Two issues were repaired:

- decision.lua previously tried optional known-clear consumable development
  first and only called growth when no consumable candidate existed. Repeated
  Empress upgrades could completely suppress the growth comparison. Available
  Yorick/first-Burnt growth is now checked once first. Only a supported useful
  discard preempts optional development; rejected growth falls back within the
  shared allowance. Death-cycle plays do not get discard-only priority.
- growth.lua counted physical Yorick growth but omitted extra scoring benefit
  from the actual visible Blueprint/Brainstorm row. A bounded exact same-play
  rescore measures that row's marginal copied effect, including additive Mult.
  The resulting bounded heuristic factor informs partial utility in both the
  one-discard and qualified two-discard comparison. It does not multiply physical
  counters, assume future reordering, or compare a score floor as if exact.

These changes do not mandate every discard. The retained finish must still have
the existing supported 105% margin, with boss, order, inventory, population,
cash/interest, Blue/Gold, action-cost and horizon protections. An eight-card hand
reserving a five-card clear may have only three safe spares. Mature growth or the
final boss can favor finishing. Copy credit has a narrow supported-row scope.
Tactical Empress use may still be needed before a discard to secure a clear.
Re-evaluate after each fresh observation; never pretend unknown draws are known.

Manufactured fixtures: tests/advisor_growth_priority359.lua (118 checks),
tests/advisor_growth_copy359.lua (86 checks), and the updated existing
tests/advisor_yorick_pair.lua (720 complete draw orders and 24 independent
count-family comparisons). The stronger copy value legitimately changes some
pair/cost selections; explicit physical endpoints and cash costs replace stale
expectations. Intermediate failures remain under development359/growth_review.
Independent review: development359/priority_review/RESUMED_REVIEW.md.

ACTUAL OBSERVED RESULTS, NOT WIN-RATE CLAIMS

Final loaded2.156 product journals: seven starts, two verified Ante8 wins, four
losses and one unfinished opening explicitly stopped by the user. Both wins
earned zero new Gold in win-first mode. This is selected development data, not
a representative player cohort. Records are under development357/logs2 and
development357/shop_review/FINAL_POSTMORTEM.md plus final_report.json.

The later loaded2.158 prefix is session-20260916T191059Z-1 on previously studied
seed M4BVSY11. Its frozen cutoff is 2026-09-16T19:17:59Z, sequence2512. Across
21 cleared rounds, 11 retained discards (32 total unused). There were24 Empress
uses:20 before the first play,9 before the first discard,18 optional development
and6 tactical. The last completed blind is Ante8 Small. NO terminal outcome
appears in this prefix. It usually retains a last Empress template, so the
observed problem includes sequencing and valuation rather than unconditional
inventory exhaustion. Not every unused discard is necessarily safe or useful.

Read development359/log_review/POSTMORTEM.md and report.json. Exact original
segment/ordinal/advice anchors, prefix bytes and hashes are preserved under
log_review/logs1. No captured state was run through a policy or scorer in359.
No2.159 terminal outcome, rescued run, calibrated odds or stronger-than-human
performance is demonstrated. Later logs, if any, require fresh passive inspection;
do not invent what occurred after the cutoff.

NEXT USEFUL WORK

Start with the current priorities and preserved public observations. Check loaded
version from passive evidence when available, distinguish the operating profile,
then repair the smallest complete comparison supported by the evidence. Do not
launch a new broad experiment just because this is a new chat.

1. Whole-inventory Perkeo use/hold/supported-sale planning remains incomplete.
   Value remaining profitable targets, usable copies, shop horizon, cash needs
   and action cost. Additive utilities can overvalue redundant Magicians or
   Temperances and consume a last Death/Planet too early. Do not protect every
   last type unconditionally, ignore Negative copies or invent a selected copy
   source. Generic surplus-consumable selling has not been added.
2. Better bounded joint hand/discard/owned-consumable planning is still needed.
   359 fixes an ordering omission, not the full future decision tree. Keep
   complete common-world comparisons and explicit unsupported mechanics.
3. At some below-target Serpent decisions, ordinary search spends all140000
   scores before a complete consumable comparison. See
   development357/shop_review/EMPRESS_BUDGET_ADDENDUM.md and the359 postmortem.
   Reserve meaningful bounded work within existing caps instead of raising them.
4. Ordinary uncertain-mean comparisons can call a mean above target a clear
   while its supported floor is below target. 358 repairs safe development beside
   an already-supported floor; it does not resolve all tactical risk comparisons.
5. Amber Acorn future discard/consumable planning over its public order belief,
   useful cash investment/rerolls, and calibrated survival-versus-sticker trades
   remain. Do not strip unknown-mechanics safeguards to force an action.

Recent completed runtime slices:357 protects asynchronous shop settlement against
duplicate queued buys and allows exact expired-rental disposal in the win-first
teacher's collection_progress context;358 uses supported score floors for safe
surplus development and better equal-gain enhancement targets;359 is above.
Read current maps rather than repeating those fixes.

LEARNING, SIMULATOR AND DEMONSTRATION STATUS

The production advisor is still heuristic. The355 GPU learning prototype was
rejected and is NOT deployed. All355 jobs and unused capacity are CLOSED.
tools/advisor_learning contains the separate simulator wrapper, candidate/entity
model, objective, training/analysis and one-use experiment launcher. Relevant
navigation is ARCHITECTURE_MAP_355.md; audits, modern primary-source research,
final policy selection and CLOSED.json are under development355. Do not repeat
the failed sparse-reward training or assume the simulator is fully qualified.

356 adds public current-ante Small/Big/Boss targets and restrictions to snapshots,
an explicit win-first teacher mode, linked state/advice/action records, and
standalone causal public-context / demonstration conversion tools. The old355
model representations do not automatically consume that new schema. Actual
real-game demonstrations help check simulator mismatch but are fallible labels:
a win does not make every action optimal, and a loss does not make every action
wrong. Keep successful, failed, interrupted, unsupported and censored outcomes
separate. No unseen confirmation or improved trained policy is established.

The prepared teacher product mode had a10-start cap,500 actions/1800seconds per
run,30seconds persearch,21600seconds persession,30-second inactivity retirement
with settlement/terminal guards, and a1GiB observation cap. The earlier stopped
batch is not pending; do not silently resume it, reset its counts or treat unused
starts as hidden experiment permission. Explicit user-started product controls
govern play. The user's current logs must be preserved; old cleanup authorization
does not authorize another purge now.

PRESERVATION AND EXECUTION BOUNDARIES

Never launch Balatro.exe, even with headless flags. Never foreground, fullscreen,
restart, stop or control the game, or execute live gameplay through tools.
Product Execute/auto-run is user-started; stop/resume controls must retain caps.
Do not read or modify player saves or profile files for evaluation. The user may
use Z+1..5 and X+1..5 checkpoint controls; development tools must not impersonate
those actions. Preserve checkpoint verification and journal protections.

No new hidden seed search, original-source component, captured-policy/scorer
evaluation, complete simulated attempt, GPU training, scheduled task or automation
is authorized by this handoff. Historical allowances are all CLOSED. A genuinely
new experiment needs its hypothesis, worker/count/time/compute caps and total
cost made concrete, fresh user authorization, then prospective frozen policy,
adapter/profile/source/runtime provenance and one-use limits. Never renew a
lease, relabel an old experiment or use a fresh directory to reset a budget.
Routine manufactured fixture/regression validation and passive public-log/source
analysis remain authorized. Tools may not use real saved games as fixtures.

Preserve deterministic sampling, complete common-world comparisons,140000
ordinary/50000 shop/25000 consumable/70 fast-clear/12 growth score budgets,
Glass/population conservation, whole-inventory Perkeo/Negative/Observatory,
Kings Strength/Death development, exact Yorick/Burnt and safe growth. Retry270
manual checkpoint memory keeps its persistent five-report cap; metadata changes
or mark restoration never renew it, public matching is not hidden RNG/save
equivalence, and source evaluation keeps retry context disabled and clean.

The older all20-challenge goal remains, with Jokerless and Knife's Edge on the
roadmap. Neither50% nor75% per-challenge success target is demonstrated. NO
verified complete Jokerless win exists. The historical twelve-attempt271 push
ended10losses,1error,1unsupported on selected synthetic profiles; furthest274
lost final Ante8 Cerulean Bell at38802/100000 despite an incidental GAME.won=true.
See FINAL_SOURCE_EVIDENCE_280.md/JSON and FINAL_BUDGET_281.json under
runs/jokerless271_push_20260912_214242 only when relevant. The weakness263 plan
was consumed by weakness266's16-worker pilot (6losses,5timeouts,5unsupported),
not unused authority. Old Reddit/wiki hypotheses are not win-rate evidence.

MODEL/REASONING PREFERENCE

I now prefer available lighter GPT-6 Astra reasoning settings over GPT-5.6 Sol
for routine non-Ultra work to reduce usage. I reported Light/Medium/High/Extra
High options in the app; treat those as my preference, not a verified pricing
claim or hardcoded API identifiers. Check what this session actually supports.
Use sufficiently strong reasoning for difficult proofs and integration reviews;
don't assume every bounded subtask needs Ultra. No model change or experimental
budget is authorized merely by this preference.

WORKFLOW AND REPORTING

Continue useful implementation autonomously with concise, candid updates.
Use independent bounded review where it helps, but don't trust old agent memory.
Install each appropriately tested coherent runtime slice immediately using
tools/advisor_eval/install_slice.py with explicit files, backups and verified
hashes. Preserve current settings/saves and all native DLLs; changed native work
requires the documented sidecar/evidence gate. Freeze exact installed bytes and
validate them after release. Preserve failures separately and report actual
outcomes and limits without invented odds. Never equate installation with loaded
activation. Tooling/docs-only changes need no runtime release.

Maintain ADVISOR_START_HERE.md, current SESSION_RESET/NEXT_PRIORITIES/ARCHITECTURE
records, relevant dated ADVISOR_HANDOFF.md, evidence/budget ledgers and this
ADVISOR_RESUME_PROMPT.md so the next reset is equally accurate. The current
final receipt binds this exact prompt. First verify the checkpoint/navigation,
then follow the priorities; don't spend the turn merely restating a plan.

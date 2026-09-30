"""Record final validated candidate facts while preserving navigation history."""
from pathlib import Path
import json

HERE=Path(__file__).resolve().parent
EVAL=HERE.parent
ROOT=EVAL.parents[1]
candidate=EVAL/'runs/repair408_candidate3'
frozen=json.loads((candidate/'freeze.json').read_text())
gate=json.loads((candidate/'validation/report.json').read_text())
assert gate['passed'] and gate['provenance_unchanged']
digest=frozen['candidate_policy_digest']
common=f'''FROZEN REPAIR408 CANDIDATE — 2026-09-26
User authorized repairs during another ten-run session. Repository2.196 is frozen
at tools/advisor_eval/runs/repair408_candidate3 and fully validated, NOT installed.
Read CANDIDATE_CHECKPOINT_408.md, NEXT_PRIORITIES_408.md, ARCHITECTURE_MAP_408.md
and development408/REPORT.md/REVIEW.md/FINAL_VERIFICATION.json under advisor_eval.
Digest{digest};
109 runtime dependencies,11 changed files,320 test files;274 Lua/458 Python pass
with unchanged policy/tests/provenance. Repairs cover funded-sale consistency,
Acorn Green/Misprint/Blackboard and editions, free Planet acquisition costs, and
non-Jupiter Perkeo Fool capability/value alignment. Offline screen408 adds four
qualitative flags and structured voucher-diversion joins; flags are hypotheses.
One substantive independent review plus one focused recheck are exhausted;
the final narrow observer-normalization finding has primary fixture/full-gate
verification. Candidate1 failures and superseded passing candidate2 are preserved.
Installed remains exact2.195 checkpoint404; all7 DLLs and historical work remain.
The current active session and journals were not controlled or analyzed. Latest
normal exit is unconfirmed. Install only after that session ends with explicit
normal-exit confirmation, fresh passive preflight, newer-log preservation, backed
explicit-file installation and separate exact-installed freeze/full validation.
No experimental allowance or game-control authority is renewed. Budgets remain
ordinary140000/shop50000/consumable25000/fast70/growth12. Latest audited407 cohort
is4 wins/4 losses/2 nonterminal retirements on loaded-label2.195; no2.196 outcome,
causal win improvement or population50% claim. All full historical preservation,
execution and release requirements below remain binding. Stop this slice after
candidate delivery; do not automatically implement qualitative research ideas.

'''
prefixes={name:common for name in ('ADVISOR_START_HERE.md','ADVISOR_HANDOFF.md','ADVISOR_RESUME_PROMPT.md')}
for name in ('NEXT_PRIORITIES_404.md','ARCHITECTURE_MAP_404.md'):
    prefixes['tools/advisor_eval/'+name]='Repair408 update: frozen2.196 candidate3, fully validated and NOT installed.\nRead CANDIDATE_CHECKPOINT_408.md, NEXT_PRIORITIES_408.md and ARCHITECTURE_MAP_408.md.\nInstalled404 remains2.195 during the active session; historical text below remains.\n\n'
prefixes['tools/advisor_eval/WIN_RATE_RESEARCH.md']='''## Repair408 candidate update — 2026-09-26

WR-054/055/056/057 now have manufactured and full-gate validated local repairs in
frozen2.196 candidate3, NOT installed. See development408/REPORT.md/REVIEW.md and
CANDIDATE_CHECKPOINT_408.md for exact scope, physical continuation contracts,
canonical Acorn floors/observer continuity, free acquisition hurdle, and Fool
capability restrictions. WR-055 protections cover supported endpoints; matched
incomplete continuation stops for review rather than spending elsewhere.
Offline screen408 adds four qualitative categories and structured plan joins.
Invisible/general pack durability/cash-pressure/growth-discard optimality remain
unproved. Earlier unpatched407 entries below describe the pre-repair baseline.
No2.196 loaded game, rescued whole run or population win rate has been established.
Current user session remains unread and on installed2.195; no new experiment.

'''
for rel,prefix in prefixes.items():
    p=ROOT/rel
    assert not p.read_bytes().startswith(prefix.encode('utf-8'))
    p.write_bytes(prefix.encode('utf-8')+p.read_bytes())
checkpoint=f'''# Frozen candidate408 — 2.196.0-alpha

Candidate3 is fully validated and **not installed**. Installed baseline remains
exact2.195 checkpoint404 while the user runs another ten-run session.

| Item | Verified candidate |
| --- | --- |
| Freeze | `runs/repair408_candidate3/freeze.json` |
| Digest | `{digest}` |
| Runtime / changed paths / tests |109 /11 /320 |
| Full gate |274 Lua fixtures;458 Python tests (447+9+2), all pass |
| Hash checks |Runtime, tests and validation provenance unchanged |
| Review |One substantive and one focused recheck; final narrow finding corrected and verified by primary |
| Preservation |`development408/FINAL_VERIFICATION.json` |
| Superseded evidence |Candidate1 failed Lua; candidate2 passed but precedes final observer normalization; both immutable |

Read development408/REPORT.md, REVIEW.md and NEXT_PRIORITIES_408.md. No loaded
2.196 evidence or causal win-rate claim exists. Audit407 remains four verified
wins/four losses/two nonterminal retirements across ten loaded-label2.195 starts.

Release only after the latest session completes and its normal exit is explicitly
confirmed. Check process absence passively; preserve and classify newer journals;
verify candidate/runtime/test/helper hashes, current installed baseline/settings
and all seven DLLs. Install with install_slice.py version2.196.0-alpha and the
eleven explicit paths in this freeze's changed_runtime_files (strip Brainstorm/).
Keep the backup, freeze exact installed bytes and run all installed gates. The
previous normal-exit confirmations do not apply to this current session.
No game control, saves/profile access, captured policy replay or new experiment.
'''
(EVAL/'CANDIDATE_CHECKPOINT_408.md').write_text(checkpoint,encoding='utf-8')
(EVAL/'NEXT_PRIORITIES_408.md').write_text('''# Priorities after repair408

1. Keep candidate3 uninstalled during current user play. After explicit latest
   normal-exit confirmation, complete the backed exact release/full installed
   gate specified in CANDIDATE_CHECKPOINT_408.md. No further patch/review slice
   is pending; do not launch or control a game to validate activation.
2. When the user reports this session complete, capture its public journals
   without assuming normal termination. It still tests installed2.195, so its
   outcomes cannot validate2.196. Preserve all starts and nonterminal stops.
3. In later user-started loaded2.196 play, inspect Acorn next-action continuity,
   funded-plan IDs/dispositions/settled ownership, free Planet component costs
   and Fool stock exits. Compare opportunities and complete starts, not selected
   success clips or terminal wins alone. Failed revalidation is an explicit stop.
4. Adjudicate Invisible, general pack durability/merit conflicts, affordable
   unopened Buffoons, cash pressure and growth-discard flags before proposing
   new policies. These remain hypotheses, not authority for experiments or forced
   purchases/discards. Current caps and full resume boundaries remain.
''',encoding='utf-8')
(EVAL/'ARCHITECTURE_MAP_408.md').write_text('''# Repair408 navigation

| Mechanism | Source and manufactured acceptance |
| --- | --- |
| Canonical Acorn action continuity | acorn_belief qualified_values/public_edition/advance_public/signatures; acorn_ordering/acorn_discard; advisor_acorn_growth408 and advisor_acorn_tracker408 |
| Funded physical shop plan | shop_sequences qualify_sale/prepare_commitment/observe_commitment/resume; strategy shop_sequence_admission and joker_admission; advisor_shop_continuation408 |
| Actual Execute and fresh public state | runtime snapshot wrapper/execute; advisor_runtime appended408 cases include real capture/Gold metadata/deck backs/asynchronous settlement/new GAME |
| Shared public owned composition | shop_scoring public_deck_identity uses existing paired deck normalization; physical offer/owned Joker IDs remain exact |
| Free pack acquisition hurdle | shop_scoring compare exposes weighted/clipped acquisition_hurdle; strategy best_pack_choice removes it only for free Planet; advisor_free_planet408 uses real finishing/D.run |
| Executable Fool stock value | strategy unusable_fool_stock/copy_utility/stock_capacity/consumable_value/manage_teacher_stock; advisor_fool_capability408 plus unchanged owned_fool_shop/hand route tests |
| Compact review receipts | player_journal compact_shop_sequence_review and compact_copy_death_review; public scalar/physical IDs only, no private matching keys or sampled worlds |
| Offline suspect review | flag_suspect_decisions.py408.1; existing406 tests plus test_advisor_suspect_decisions408.py; flags require causal links and physical effect confirmation |
| Exact candidate/preservation | development408 freeze.py/write_delivery.py/verify_candidate.py; runs/repair408_candidate3; CANDIDATE_CHECKPOINT_408.md |

All runtime paths are under Brainstorm/Advisor and all fixture paths under tests.
Scope/evidence are development407/REPAIR_SPEC.md and development408/REPORT.md.
Current session is unread; installation remains404 pending the current normal
exit and exact release requirements. No captured-state scoring or game control.
''',encoding='utf-8')
print(json.dumps({'candidate':candidate.name,'digest':digest,'navigation_histories_preserved':len(prefixes)}))

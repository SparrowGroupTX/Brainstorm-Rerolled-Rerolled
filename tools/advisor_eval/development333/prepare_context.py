"""Prepare current release notes and explicitly historical closed experiment context."""
from pathlib import Path
from datetime import datetime,timezone
import json,hashlib
ROOT=Path(__file__).resolve().parents[3]; HERE=Path(__file__).parent; EVAL=HERE.parent
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def ref(p):return {'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)}
def write(p,text):
    with p.open('x',encoding='utf-8') as f:f.write(text)
notes=HERE/'release_notes';manifest=notes/'manifest.json'
assert sha(manifest)=='a182d85ab9baac429c99de16df9713d466193371e8538723fb6e86535a3527d4'
for name,digest in read(manifest)['files'].items():assert sha(notes/name)==digest
prior=EVAL/'development328/acorn_release_final/context.json'; context=read(prior)
zero={key:0 for key in context['counts']}
context.update(release=333,created_at_utc=datetime.now(timezone.utc).isoformat(),
 counts_scope='historical_closed_cycle',release_counts=zero,previous_checkpoint_context=ref(prior),
 summary='Fix the journal and public-Joker observer repeatedly wrapping each other during idle updates. One shared weak wrapper-to-original registry lets each installer recognize its existing hook below another product-owned wrapper. A manufactured1000-tick/eight-callback workload changes16000 retained new wrappers to zero; one action retains exactly one public action beginning and one journal request/result pair. Genuine replacements, callback return tuples/errors, nested actions and observed state information are preserved. No archive format, compression, storage limit, scoring policy or native code changed.',
 outcome_summary='Release333 uses routine manufactured/regression fixtures and read-only timing analysis only, with zero new source attempts, source components, captured-policy comparisons or searches. A stable copy of one live-written log prefix contains78 complete compact performance windows:120593 stored bytes and435636 decoded bytes. The final six frames average0.8915426-second intervals while the one journal event takes0.0063389seconds. This confirms severe stalls, not their complete cause. The callback-growth defect is independently reproduced; restored live FPS and garbage-collector attribution remain unmeasured. The historical closed loss328 batch remains3losses/1error/1timeout/1unsupported and0wins; its policies327/329/331 are not333 validation.',
 budget_summary='All experiment allowances remain CLOSED. Historical loss328 used four public pairs and six source attempts,1200seconds reserved and685.3740000000689seconds actual; unusedP05/P06 and60seconds were closed. None is renewed. Release333 runs zero experiment workers and performs no source archive/runtime initialization, seed search, policy replay, game control or save/profile evaluation. One explicit observation-log prefix was copied read-only under a4MiB cap and strictly decoded with the existing bounded analyzer. Routine candidate and exact-installed fixture suites retain their60-second per-suite limits. No worker, source attempt, search or scheduled continuation remains pending.',
 limits_summary='The captured log has no action or loaded-version records, so it does not establish the active game version or live duplicate action counts. Low direct journal duration does not prove the sole stall cause; the larger original-game-update duration does not identify garbage collection. Manufactured callback counts and allocation work are not measured live FPS recovery. Installing files cannot remove chains in the running process; the user normal restart activates the repair. Weak ancestry covers only registered product wrappers, with bounded128-step inspection and no debug/upvalue or hidden-state access. Opaque external wrappers can retain duplicate old observation layers without exposing ancestry; no arbitrary-mod exactly-once guarantee is claimed. Public Joker inference, complete-world planning, all score/resource/population/retry protections remain as documented in332. Keep all logs, dirty/untracked work, settings and native DLLs. No complete win, numerical odds, achievement completion or human superiority follows.',
 unused_capacity='closed',remaining_authority_seconds=0,verified_complete_win=False,
 preparation_status='documentation_prepared_from_passed_candidate_installed_validation_bound_separately')
context['diagnostic_evidence']={name:ref(path) for name,path in {
 'previous_current_context':prior,'capture_receipt':HERE/'captured_log/receipt.json',
 'captured_segment':HERE/'captured_log/session-20260915T202738Z-1-000001.brj',
 'timing':HERE/'captured_log/timing.json','stall_index':HERE/'captured_log/stall_index.json',
 'logger_component':HERE/'logger_component/manifest.json','observer_component':HERE/'observer_component/manifest.json',
 'integration':HERE/'integration/receipt.json','prepared_notes':manifest}.items()}
out=HERE/'release_context';out.mkdir(exist_ok=False)
write(out/'context.json',json.dumps(context,indent=2)+'\n')
component=(notes/'COOPERATIVE_OBSERVATION_HOOKS_333.md').read_text(encoding='utf-8')
component=component.replace('shared weak-key registry','shared registry with weak keys and values')
component=component.replace('Garbage-collector time, memory growth','Live garbage-collector time, live memory growth')
component+='''
Production joint regression is `tests/advisor_callback_hooks.lua` (60 checks,
including forced garbage collection on every idle tick). Journal linkage and
replacement regression is `tests/advisor_logger_hooks.lua` (17 checks).
The joint1000-tick workload keeps zero additional wrappers instead of16000.
Runtime creates one shared registry before journal attachment and injects it
into observer attachment. All other strategic modules remain byte-identical.

Release evidence: `runs/hooks333_candidate/validation/report.json`,
`runs/hooks333_installed/record.json` and `policy/`,
`runs/hooks333_installed_validation/report.json`,
`runs/hooks333_final/final_verification.json`.
'''
write(EVAL/'COOPERATIVE_OBSERVATION_HOOKS_333.md',component)
write(out/'priorities.md',(notes/'PRIORITIES.md').read_text(encoding='utf-8'))
architecture=(notes/'ARCHITECTURE.md').read_text(encoding='utf-8').replace('a weak-key wrapper-to-original registry','a registry with weak function keys and values')
architecture+='\nProduction tests: `tests/advisor_callback_hooks.lua`, `tests/advisor_logger_hooks.lua`, plus unchanged journal/timing/archive and public-Joker fixtures. Deployment and policy discovery include the new runtime-only helper automatically. Source adapters and pure scoring graph are unchanged.\n'
write(out/'architecture.md',architecture)
objective=(EVAL/'development328/acorn_release_context/objective.md').read_text(encoding='utf-8')
write(out/'objective.md','Restore responsive ordinary play by fixing the observed callback accumulation without discarding logged information. Live FPS recovery awaits the user normal restart.\n\n'+objective)
print(json.dumps(ref(out/'context.json')))

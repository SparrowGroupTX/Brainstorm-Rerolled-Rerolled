"""Bind completed source accounting and reviewed notes to the installed Acorn slice."""
from pathlib import Path
from datetime import datetime, timezone
import json,hashlib
ROOT=Path(__file__).resolve().parents[3]; EVAL=ROOT/'tools/advisor_eval'; HERE=Path(__file__).parent
BASE=EVAL/'runs/loss328_validation_20260915'
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def ref(p): return {'path':p.relative_to(ROOT).as_posix(),'sha256':sha(p)}
def write(p,s):
    with p.open('x',encoding='utf-8') as f: f.write(s)
notes=HERE/'acorn_release_notes_final'
manifest=notes/'manifest.json'
assert sha(manifest)=='524072b144c59b63fd0c76b5a64f89dc8f7cac9e210804a5e0561a66a892e9d6'
for item in read(manifest)['files']+read(manifest)['evidence']:
    assert sha(ROOT/item['path'])==item['sha256']
closed=read(BASE/'CLOSED.json'); assert closed['status']=='CLOSED'
source=BASE/'FINAL_SOURCE_EVIDENCE_332.json'; assert source.is_file()
context=read(HERE/'nine_release_notes/context.json')
context.update(release=332,status='CLOSED',created_at_utc=datetime.now(timezone.utc).isoformat(),
 summary='Installed public Joker-effect observation and bounded iterative ordering. Concealed identities are redacted before capture and ordinary decision paths; remembered public unordered inventory plus actually displayed popups constrains complete possible slot assignments. Observed drags and certified Execute reorders transport slot beliefs. Current-order plays compare all legal subsets and all consistent worlds within140000 calls; reordering additionally requires a complete order family within30000 calls and an immediate clear in every world. Ambiguity, unsupported mechanics and missing observations remain explicit.',
 outcome_summary='Four public comparison jobs support the Purple continuation, complete affordable Blueprint replacement, retained Perkeo inventory and evidence-forwarding changes. Six selected source attempts ended with no wins: C01 baseline327 Pillar loss592/600; C02 policy329 cleared616/600 but ERROR at a nine-card House; C03 baseline327 Ante5Big loss18340/37500; C04 policy329 cleared that Big115080/37500 and reached Ante6 before TIMEOUT; C05 policy331 passed the same House stoppage, clearedHouse4164/2000 and Ante3Small6102/3200, then lostBig2436/4800; C06 policy329 stopped UNSUPPORTED before the first concealed Joker decision at Ante8 Acorn. The first two C05 House forecasts are sampled expectations, not exact scores or guaranteed floors. No source attempt evaluated332 public observation.',
 budget_summary='The user-authorized loss328 cycle is CLOSED. Four30-second public pairs and six180-second source attempts reserved1200seconds; actual worker time685.3740000000689seconds, including reported cleanup. UnusedP05/P06 and60seconds are closed. All workers are reaped and stdout drains complete; every original error, timeout, unsupported and incomplete capture remains preserved. No source components or seed searches were launched; no historical allowance was reused. There is no pending experiment, worker, search or scheduled continuation.',
 limits_summary='Source attempts use selected dependent development seeds with synthetic all-unlocked/discovered and150-missing Gold profiles, not the player profile or unseen holdouts. No verified complete Jokerless win, numerical player odds, per-challenge50/75percent targets, achievement completion or human superiority. Public observation has manufactured capture/Execute/decision/scoring regression evidence and static preserved-source grounding, but no live activation or original-source observer qualification. Immediate all-world score floors are not joint future hand/discard/consumable comparisons or a globally ideal order. At most6Jokers/720worlds/9visiblecards and256events; Glass/Lucky and Blue/Purple/Gold resource effects remain unsupported in this immediate path. The next concrete planning gap is nonempty shop-exit Perkeo copying combined with Certificate: C05shops55/60/62 return zero profiles and pack61 falls back; full-row Judgement copies accumulate. Do not drop that transition guard to manufacture support. Preserve existing score caps, inventory/population and persistent retry protections, settings/native DLLs and all dirty work. No saves/profile evaluation or game control. Activation waits for the user normal restart; no future experiment authority is granted.',
 counts=closed['counts'],complete_attempt_outcomes=closed['complete_attempt_outcomes'],verified_complete_win=False,
 unused_capacity='closed',remaining_authority_seconds=0)
context['evidence']['outcomes']=ref(source)
context['evidence']['budget']=ref(BASE/'FINAL_BUDGET_332.json')
context['diagnostic_evidence'].update({name:ref(path) for name,path in {
 'closure':BASE/'CLOSED.json','source_final':source,
 'C05_followup':BASE/'followup_C02_C05_audit.json',
 'notes':manifest,'integration':HERE/'acorn332_preparation/root_integration_evidence/receipt.json',
 'integration_preparation':HERE/'acorn332_preparation/preparation_manifest.json',
 'observer':HERE/'acorn_public_component/manifest.json','belief_order':HERE/'acorn_belief_component/manifest.json',
 'independent_review':HERE/'ACORN_INTEGRATION_REVIEW.json'}.items()})
out=HERE/'acorn_release_context'; out.mkdir(exist_ok=False)
write(out/'context.json',json.dumps(context,indent=2)+'\n')
component=(notes/'PUBLIC_JOKER_OBSERVATION_332.md').read_text()
component=component.replace('Prepared release note; root must finalize installation/version/test receipts.',
 'Installed 2.132.0-alpha. Full candidate and exact-installed regressions passed186 Lua fixtures and361 Python tests, with unchanged frozen policy/test hashes.')
component+='\nFinal source accounting: `runs/loss328_validation_20260915/FINAL_SOURCE_EVIDENCE_332.json` and its Markdown companion. Exact runtime freeze/install/verification: `runs/acorn332_candidate`, `acorn332_installed`, `acorn332_installed_validation`, and `acorn332_final/final_verification.json`.\n'
write(EVAL/'PUBLIC_JOKER_OBSERVATION_332.md',component)
for original,target in [('NEXT_PRIORITIES_332.md','priorities.md'),('ARCHITECTURE_MAP_332.md','architecture.md'),('objective.txt','objective.md')]:
    text=(notes/original).read_text()
    text=text.replace('Prepared notes; root finalizes current installation.','Installed2.132 is verified; exact current receipts are in SESSION_RESET_332.json.')
    text=text.replace('Prepared navigation; root finalizes version, installed evidence and status.','Installed2.132 navigation; exact version, installed evidence and status are in SESSION_RESET_332.json.')
    if target=='architecture.md':
        text+='\nProduction fixtures: `tests/advisor_acorn_belief.lua` (126checks), `tests/advisor_acorn_public.lua` (115checks), and four public-display checks appended to `tests/advisor_runtime.lua`. `tools/advisor_eval/component_profile.lua` includes the two pure modules; current and frozen source adapters remain unchanged. Final counts are186Lua/361Python,82deployment/98frozen product/dependency files.\n'
    write(out/target,text)
print(json.dumps(ref(out/'context.json')))

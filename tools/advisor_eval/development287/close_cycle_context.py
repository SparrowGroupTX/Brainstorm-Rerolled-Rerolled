"""Bind completed diagnostic receipts without executing or renewing experiments."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CYCLE = ROOT / 'tools/advisor_eval/runs/diagnostic287_20260913_222344'

def ref(name):
    path = CYCLE / name
    return {'path': path.relative_to(ROOT).as_posix(), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}

value = json.loads((CYCLE / 'context_checkpoint288.json').read_text())
value.update(status='CLOSED', unused_capacity='closed',
    summary='The fresh diagnostic cycle is complete and closed. All four selected complete attempts lost. Runtime slices287,288 and289 were tested and installed separately: complete shop-progress integration, repeated observed discards, and bounded joint owned-consumable timing. The two candidate attempts used the identical frozen289 policy.',
    outcome_summary='No verified complete Jokerless win. TO6O4111: frozen286 lost Ante3 Small at1,185/2,000 with5 cleared blinds; frozen289 lost Ante4 Big at4,379/7,500 with9 cleared blinds. P83R7111: frozen286 and frozen289 both lost Ante2 Flint with4 cleared blinds, at1,135/1,600 and748/1,600 respectively. All four provenance/selected-action/terminal audits passed; exact scores, supported floors and random gaps remain separate. These mixed dependent results do not establish a general improvement. Historical twelve attempts remain ten losses, one error and one unsupported; policy274 still has the farthest audited loss, final Ante8 Bell at38,802/100,000. Numerical win odds and human superiority remain unmeasured.',
    limits_summary='All starts are selected synthetic all_unlocked_discovered_v1 development data, never player cohorts or unseen holdouts. No confidence interval or individual-feature causal claim is justified by these two deliberately selected pairs. Four captured pair jobs produced eight parse errors before decisions; all failures and spent leases remain preserved. Two Lucky components passed20 conditional source-method cases with arithmetic/event doubles, not full scoring-phase qualification. Search returned zero matches on both fixed ranges and timed about1.65x faster for286 than285; this does not measure product FPS, expected waiting time, acquisition or survival. No game process or saves were touched; ZIP rules and isolated Lua were used only under fresh authority.',
    budget_summary='All14 one-use jobs are spent: A4x60s, B2x30s, C4x180s, D4x15s =1,080s reserved;263.5664256999735s actual outer worker time. Complete attempts account for258.1760814000154s. All unused capacity is closed, with zero replacements, retries or historical carry-forward. Further original-source components, captured replays, searches or complete attempts require fresh concrete authorization and preregistration. Routine synthetic fixtures, regression validation, read-only analysis and installation remain authorized.')
value['counts']['complete_attempts'] = 4
value['complete_attempt_outcomes'].update(loss=4, not_started=0)
value['evidence'] = {role: ref(name) for role, name in {
    'authority': 'authority.json', 'outcomes': 'FINAL_RESULTS.json',
    'budget': 'FINAL_BUDGET.json', 'limits': 'cycle_protocol.json'}.items()}
with (CYCLE / 'context_final289.json').open('x', encoding='utf-8') as stream:
    json.dump(value, stream, indent=2)
print(json.dumps({'status': value['status'], 'counts': value['counts']}))

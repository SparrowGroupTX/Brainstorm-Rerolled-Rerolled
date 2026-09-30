from pathlib import Path
from datetime import datetime, timezone
import hashlib, json

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
files = [
 'before/Brainstorm/Advisor/gold_retention.lua',
 'Brainstorm/Advisor/gold_retention.lua',
 'tests/advisor_gold_retention_order.lua',
 'before_01.json', 'candidate_01.json', 'validate.py', 'seal.py',
]
hashes = {str((OUT/p).relative_to(ROOT)): hashlib.sha256((OUT/p).read_bytes()).hexdigest() for p in files}
report = {
 'schema': 1, 'created_utc': datetime.now(timezone.utc).isoformat(),
 'component': '347 bounded explicit-order missing-Joker retention',
 'status': 'staged_only', 'files': hashes,
 'before': {'record': 'before_01.json', 'exit_code': 1, 'failure': 'current fixed-row hold is below the required margin'},
 'candidate': {'record': 'candidate_01.json', 'exit_code': 0, 'manufactured_checks': 88},
 'contract': [
  'Preserve the original complete paid incumbent, every original consumable, physical Joker, population, capacity and cash.',
  'Qualify every canonical current-or-copy-target held row before scoring, including its own whole-inventory Perkeo certificate.',
  'Preflight the complete fixed-row profile family in one original-root context; only budget fit can reduce the declared family to current hold before any floor call.',
  'Complete every declared paid-versus-hold comparison in identical four-world family; reject mechanical, scoring, accounting or late comparison failure without using an earlier eligible prefix.',
  'Keep the 125 percent next-blind margin, cash reserve and 8000 reserved score allowance within the existing 50000 shared total.',
  'Prefer zero remaining arrangement actions, then larger sampled floor, then canonical physical key.',
  'A noncurrent winner emits one reorder_jokers action only and requires fresh advice; an eligible current row emits leave_shop, preventing retention reordering cycles.',
 ],
 'tests': [
  'Targeted before failure and candidate pass with actual pure product scoring and staged gold_order/preflight helpers.',
  'Under-margin current Perkeo-copy row changes to an explicit winning-margin scoring row, followed by fresh leave advice.',
  'Repeated fresh advice, current-row zero-action priority, exact score accounting, complete family count and original state fingerprint.',
  'Budget-only fallback at 120 score calls, no-score rejection at cap1, unchanged reservation.',
  'Malformed/partial/duplicate family, changed cash/inventory/Joker effects, unsupported inventory, mechanical preflight failure, different-world pair, late unsupported pair and physical pin safeguards.',
 ],
 'limits': [
  'Manufactured fixture evidence only; no captured policy comparison, original-source execution, seed search, save/profile access, game control or terminal attempt.',
  'Bounded copy-count canonical rows, not all scoring permutations or a globally optimal arrangement.',
  'No future free reorder, terminal rescue, new sticker or win probability is demonstrated.',
 ],
 'runtime_promotion_required': ['gold_order dependency loading', 'shop_scoring preflight helper', 'decision phase-copy guard for complete retention reorder and leave'],
}
with (OUT/'component_report.json').open('x', encoding='utf-8') as f: json.dump(report, f, indent=2); f.write('\n')
print(hashlib.sha256((OUT/'component_report.json').read_bytes()).hexdigest())

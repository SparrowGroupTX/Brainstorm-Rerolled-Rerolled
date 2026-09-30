from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
paths=[OUT/'Brainstorm/Advisor/gold_order.lua',OUT/'tests/advisor_gold_order.lua',
 OUT/'tests/advisor_gold_acquisition_order.lua',OUT/'README.md']
report={
 'schema':1,'scope':'Manufactured pure helper and production-wired acquisition fixtures only.',
 'authority':{'new_experiments':False,'source_execution':False,'captured_state_policy_evaluation':False,
  'seed_search':False,'complete_attempts':False,'live_game_control':False,'save_or_profile_access':False},
 'changes':'Stage a zero-score pure physical copy-target family plus independent integration regression; root owns runtime integration.',
 'family':{'max_jokers':6,'max_permutations':720,'max_rows':6,'score_calls':0,
  'canonical_tie':'Stable physical-ID order, independent of current movable order',
  'complete_scope':'Current row plus one compatible active copy-count maximizer per physical active non-copy target',
  'all_scoring_orders':False,'free_reorder':False},
 'pure_validation':{'record':'validation4.json','checks':164,'passed':True},
 'acquisition_validation':{'record':'acquisition_validation5.json','checks':2668,'passed':True,
  'fixed_row_score_calls':120,'expanded_score_calls':360,'selected_minimum_score':216000,
  'next_blind_target':90000,'required_margin':1.25,'fresh_sale_index':2,'cash_before':80,'cash_after_sale':82,
  'cash_after_buy':78,'original_tarots_preserved':14,'playing_cards_preserved':16,'common_worlds':4,
  'fallback_cap':120,'fallback_score_calls':120,'insufficient_cap':119,'insufficient_score_calls':0},
 'failed_evidence_preserved':{'validation1.json':'Incorrect harness assertion overlooked a valid compatible Blueprint chain.',
  'acquisition_validation1.json':'Harness prohibited Score.score called internally by lower_bound.',
  'acquisition_validation2.json':'Same harness problem with diagnostic reason exposed.',
  'acquisition_validation3.json':'Physical IDs accidentally preserved the sale index instead of exercising reindexing.'},
 'limitations':['No measured wins or Gold-sticker gains.','No score-optimized order claim.',
  'Apply receipt binds current IDs and activity metadata, not full shop/cash/inventory observation.',
  'Expanded paid endpoint scoring still requires complete preflight within the unchanged shared shop allowance.'],
 'files':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}}
target=OUT/'component_report.json'
if target.exists():raise SystemExit('Preserving existing sealed component_report.json')
target.write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report['files'],indent=2))

from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[4]
OUT=Path(__file__).resolve().parent
paths=['tools/advisor_eval/runs/chicot_order_source1/source/card.lua',
 'tools/advisor_eval/runs/chicot_order_source1/source/functions/common_events.lua',
 'Brainstorm/Advisor/gold_tarot_hold.lua','Brainstorm/Advisor/snapshot.lua',
 'tools/advisor_eval/development346/constructor_component/Brainstorm/Advisor/gold_tarot_hold.lua',
 'tools/advisor_eval/development346/shape_audit/passive_shape_inventory.json',
 'tools/advisor_eval/development346/shape_audit/tests/advisor_gold_tarot_lifecycle_shape.lua',
 'tools/advisor_eval/development346/shape_audit/validation1.json',
 'tools/advisor_eval/development346/shape_audit/validation2.json']
report={'schema':1,'scope':'Independent read-only source/shape audit and manufactured lifecycle fixtures. No runtime edits.',
 'source_locations':{'Card:init':[5,74],'Card:set_base':[97,144],'Card:set_ability':[277,337],
  'Card:set_edition':[387,418],'Card:add_to_deck':[565,641],'Card:update':[4154,4175],
  'create_card':[2125,2130],'copy_card':[2156,2182],'Card:load':[4659,4664]},
 'passive_shapes':{'distinct_shapes':24,'distinct_tarot_identities':12,
  'finding':'All publicly logged ability/base/edition/pin/debuff fields agree with the existing constructor boundaries; no additional visible shape blocker found. Every available certificate declines at the broad ability/edition/front/params group.',
  'limitation':'Raw params, card.front and full center objects are not logged when capture fails. Passive card shapes were summarized only; no validator, policy or scoring function was applied to them.'},
 'source_review':[
  'create_card always passes selected-back presentation coordinates; copy_card inherits the original params table. Existing345 rejects bypass_back.',
  'Nonplaying empty-front base contains exactly four numeric zero fields; absent source pin is already normalized by Snapshot.',
  'Card:set_ability stores consumeable=center.config by reference; Card:update mod_num assignments preserve live center/config agreement. Copied ability.consumeable is detached but has the same existing mod_num value.',
  'Temperance money refresh is use-only and remains within its finite cap; copied zero score/size fields and held-unused scope remain necessary.',
  'Perkeo replaces the edition with pure Negative; add_to_deck adds exactly one consumable slot. Unknown seals, copied hand/discard effects and non-Tarot classes remain outside qualification.',
  'The staged constructor fix changes only qualified presentation params admission and rejection diagnostics; no additional unsafe qualification identified in the reviewed scope.'
 ],
 'validation':'Installed345 helper fails fresh manufactured Empress with source-native bypass_back. Staged constructor helper passes112 lifecycle checks, including shared-center updates, fresh Temperance refresh, inherited copy params, exact full inventory/capacity, immutable receipts and stale/unsafe data rejection.',
 'integration':'Copy staged tests/advisor_gold_tarot_lifecycle_shape.lua into repository tests; no runtime patch originates in this component.',
 'files':{p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest()for p in paths},
 'authority':'Read-only preserved source and passive journal plus routine manufactured fixtures. Zero source workers, captured-policy jobs, searches, complete attempts, executable/save/profile reads or game control.',
 'outcome_limit':'No new terminal result, predicted win rate or rescued recorded run is demonstrated.'}
(OUT/'component_report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'report':str(OUT/'component_report.json'),'fixture_sha256':report['files'][paths[6]]}))

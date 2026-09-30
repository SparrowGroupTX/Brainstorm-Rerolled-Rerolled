"""Read existing P02 evidence only; no policy imports, decisions or source execution."""
from pathlib import Path
import hashlib
import json

HERE=Path(__file__).resolve().parent
JOB=HERE.parent/'runs/loss328_validation_20260915/P02'

def read(name):return json.loads((JOB/name).read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def pick(value,keys):return {k:value[k] for k in keys if k in value}
def write(path,value):
    with path.open('x',encoding='utf-8') as stream:json.dump(value,stream,indent=2,allow_nan=False);stream.write('\n')

def main():
    source=read('snapshot.json');registration=read('registration.json');record=read('record.json')
    documents={role:read(role+'_result.json') for role in ('baseline','candidate')}
    assert record['status']=='complete' and record['worker_reaped'] and record['frozen_files_unchanged'] and record['external_files_unchanged']
    assert sha(JOB/'registration.json')==record['registration_sha256']
    assert all(sha(JOB/name)==value for name,value in registration['files'].items())
    for role,result in documents.items():
        summary=read(role+'_summary.json')
        assert summary['evidence_sha256']==sha(JOB/(role+'_result.json'))
        assert summary['input_sha256']==sha(JOB/'snapshot.json') and summary['input_unchanged']
        assert summary['status']=='complete' and summary['full_result_status']=='preserved'
        assert summary['score_calls']==result['full_result']['evaluations']<=50000
    baseline=documents['baseline']['full_result'];candidate=documents['candidate']['full_result']
    action=candidate['action'];assert action=={'kind':'sell','area':'jokers','index':3,'followup':{'kind':'buy','area':'shop_jokers','index':1}}
    sold=source['jokers'][2];bought=source['shop_jokers'][0]
    assert sold['key']=='j_sly' and bought['key']=='j_blueprint'
    assert not sold.get('pinned') and not sold['ability'].get('eternal')
    after_sale=source['dollars']+sold['sell_cost'];after_buy=after_sale-bought['cost']
    assert after_buy==43==candidate['strategy']['replacement']['cash_after_purchase']
    assert after_buy>=source['bankrupt_at'] and len(source['jokers'])==source['joker_limit']==5
    assert baseline['shop_diagnostics']['truncated'] and not candidate['shop_diagnostics']['truncated']
    assert 'shop_forecast' not in source
    assert 'scoring_evidence' not in candidate['strategy']
    ready=candidate['strategy']['readiness'];finish=ready['finishing']
    assert ready['opening_mean']==2778 and ready['target']==25000 and ready['samples']==4
    assert finish['complete'] and finish['supported'] and finish['known_mechanics'] and finish['samples']==4
    policies=[]
    original_keys=[j['key'] for j in source['jokers']]
    for policy in finish['policies']:
        assert [w['composition_world_id'] for w in policy['worlds']]==[1,2,3,4]
        worlds=[]
        for world in policy['worlds']:
            end=world['endpoint_resources']
            assert end['dollars']==52 and [j['key'] for j in end['jokers']]==original_keys
            assert len(end['population'])==52 and len(end['inventory'])==7 and world['population_loss']==0
            assert world['score']==sum(a.get('score',0) for a in world['actions'])
            assert world['clear']==(world['score']>=25000)
            assert world['action_count']==len(world['actions']) and world['hands_used']<=4 and world['discards_used']<=1
            item=pick(world,['composition_world_id','clear','score','progress','hands_used','discards_used','action_count','population_loss'])
            item.update(endpoint_cash=end['dollars'],endpoint_population=52,endpoint_inventory_count=7,
                        yorick_endpoint=pick(end['jokers'][0]['ability'],['x_mult','yorick_discards']),
                        actions=[pick(a,['kind','indices','hand','score','dollars_before','dollars_after','remaining_population']) for a in world['actions']])
            worlds.append(item)
        assert sum(w['clear'] for w in policy['worlds'])==policy['clearing_samples']==1
        policies.append(dict(pick(policy,['name','clearing_samples','mean_score','mean_progress','mean_hands_used','mean_discards_used','mean_action_count']),worlds=worlds))
    names=['registration.json','spent.json','record.json','snapshot.json','input_provenance.json','comparison.json',
           'baseline_result.json','candidate_result.json','baseline_summary.json','candidate_summary.json',
           'baseline_record.json','candidate_record.json','candidate/Brainstorm/Advisor/strategy.lua','candidate/Brainstorm/Advisor/shop_scoring.lua']
    audit={'schema':1,'kind':'existing_public_comparison_audit','job':'P02','source_sequence':3282,'source_run':4,
      'audit_script_sha256':sha(__file__),'evidence':{name:sha(JOB/name) for name in names},
      'new_policy_decisions':0,'source_executions':0,'registered_or_consumed_new_jobs':0,
      'verdict':'Confirmed affordable replacement recommendation and completion within unchanged cap; no terminal or replacement-world outcome proof.',
      'roles':{role:dict(pick(doc['summary'],['policy_digest','score_calls','decision_cap','decision_wall_seconds','input_unchanged','source_execution','action_dispatch','selected_action_rescore','qualification']),
                        action=doc['full_result']['action'],shop_diagnostics=doc['full_result']['shop_diagnostics']) for role,doc in documents.items()},
      'paid_plan':{'sold':pick(sold,['key','name','id','sell_cost']),'purchase':pick(bought,['key','name','id','cost']),
                  'incoming_eternal':bought['ability']['eternal'],'cash_before':52,'cash_after_sale':after_sale,'cash_after_purchase':after_buy,
                  'joker_limit':5,'slot_freed':1,'retained_joker_keys':[j['key'] for i,j in enumerate(source['jokers']) if i!=2],
                  'inventory_unchanged_by_sale_and_purchase':{'negative_venus':6,'ordinary_hermit':1},
                  'action_sequence_scope':'Sale is the selected first action; purchase is a declared follow-up requiring fresh advice. Neither action was dispatched.'},
      'reported_selected_replacement':{'opening_mean_before':2778,'opening_mean_after':7176,'samples':4,'target':25000,
                  'copy_order_shortlist':'2/5 layouts in advice','utility_gain':candidate['strategy']['replacement']['utility_gain'],
                  'paired_endpoint_object_exported':False,'independent_after_world_audit_possible':False,
                  'scope':'These endpoint means and complete-paired wording are emitted advice; the underlying replacement evidence object is not returned.'},
      'retained_readiness_is_original_owned_row':{'cash':52,'joker_keys':original_keys,
                  'opening':pick(ready,['opening_mean','opening_scores','target','samples','finishing_clearing_samples']),
                  'finishing_scope':pick(finish,['complete','supported','known_mechanics','policy_scope','reason','samples','candidate_limit','max_discards_used','generation_composition_samples','finishing_guarantee']),
                  'policies':policies},
      'limitations':['The supplied public snapshot has no shop_forecast; no future offer or acquisition was reconstructed.',
         'Candidate strategy.readiness retains the original row. Its one clearing composition world out of four is not the Blueprint endpoint result or a win probability.',
         'The actual selected replacement paired evidence is absent even from full_result; its per-world scores, clears and resource endpoints cannot be independently audited from this job.',
         'Finish policies are play-only or one targeted discard, at most four hands/eight cards/32 candidates. Multiple discards and arbitrary joint consumable policies are not covered.',
         'Retained Venus/Hermit and Perkeo inventory value is strategic utility, not an executed copy, Planet use or future survival result. No new Blue generation or complete Joker cashout income is established.',
         'The reported order shortlist is bounded; no globally optimal rearrangement is demonstrated. The incoming Blueprint is Eternal.',
         'This is a selected dependent development state, not an unseen holdout or a complete attempt. No rescued run, terminal win, win odds or player-population effect is established.']}
    out=HERE/'p02_blueprint_audit';out.mkdir(exist_ok=False)
    write(out/'audit.json',audit)
    markdown='''# P02: affordable Blueprint replacement, bounded audit

The exact redacted run4 sequence3282 shop state changes from **leave shop** under2.127 to **sell Sly Joker #3 ($1), then buy the visible Eternal Blueprint #1 ($10)** under2.129. Cash is $52 -> $53 -> $43; Yorick, Perkeo, Greedy Joker and Trio remain, with six Negative Venus and one ordinary Hermit. No action was executed.

The baseline uses49,956/50,000 score calls and falls back after incomplete coverage. The candidate uses40,320/50,000 with no shop truncation:9,636 fewer calls. Input and frozen files remain unchanged; the5.047-second supervised pair completed and its worker was reaped.

Advice reports2,778 ->7,176 opening chips over four paired composition samples against Ante5 Small's25,000 target, with a bounded copy-order shortlist. **The actual replacement evidence object is not exported.** Even the preserved full result contains only original-row readiness (cash52 and Sly still owned). Its two bounded policies each clear one of four common worlds. Those are original-row modeled clears, not Blueprint endpoint outcomes or win probabilities. Full candidate-world scores, resources and clearing counts cannot be independently audited from this receipt.

The supplied shop_forecast is absent. The comparison does not reconstruct later offers, use the held Planets, execute Perkeo copying or prove the failed run was rescued. Finish coverage is play-only or one targeted discard, up to four hands/eight cards/32 candidates. Joint multiple-discards/consumable planning remains outside that family.

`audit.json` binds the registration, original public input, complete returned results, installed policy records and relevant frozen source by SHA-256, and contains concise original-row world/resource checks. This audit only read existing evidence; it performed no policy evaluation or source execution.
'''
    with (out/'AUDIT.md').open('x',encoding='utf-8') as stream:stream.write(markdown)
    print(json.dumps({'audit':str(out/'audit.json'),'sha256':sha(out/'audit.json'),'checks':'passed','new_policy_decisions':0}))

if __name__=='__main__':main()

"""Descriptive public evidence export, not an executable captured fixture."""
from pathlib import Path
import json
H=Path(__file__).resolve().parent
def read(p):return json.loads(p.read_text())
decisions=read(H/'analysis/decisions.json');offers=read(H/'analysis/copy_opportunities.json')
ids={10481,10505,10528,7435,12609}
data={'session':'session-20260928T193840Z-1','cutoff_sequence':18890,
 'policy_executed':False,'scorer_executed':False,
 'missed_brainstorm':{'requests':[d for d in decisions if d['sequence']in(10481,10505,10528)],
  'offer':[o for o in offers if o['card']['id']=='card:1093'],
  'pipeline':{'observation':'visible rental Brainstorm cost1, cash47, full row with debuffed expired Riff-raff tally0',
   'candidate':'focused direct no_slot; one-sale replacement family declared including expired Riff-raff',
   'valuation':'heuristic purchase rating68.7; this is not a survival proof',
   'admission':'shop_scoring.prepare rejects unsupported blind-start callback before applying permanent expiry',
   'budget':'zero evaluations, not truncated',
   'arbitration':'unsupported family returns no certified copy priority; optional packs preferred',
   'settled':'Arcana4 then Jumbo Celestial6 then leave with37; Brainstorm never owned while offered'},
  'repair_scope':'strict expired canonical visible Riff-raff bypass only; no historical counterfactual claim'},
 'invisible_hypotheses':[d for d in decisions if d['sequence']in(7435,12609)],
 'loss':read(H/'analysis/runs.json')[0],
 'unused_clears':read(H/'UNUSED_CLEAR_TRACE.json')}
with(H/'TRACE.json').open('x')as f:json.dump(data,f,indent=2);f.write('\n')
print('Preserved descriptive trace for three missed-Brainstorm actions, two Invisible leads, the loss and15 unused clears.')

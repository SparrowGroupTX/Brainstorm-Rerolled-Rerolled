-- Invented endpoint comparisons, never captured public-state replay.
local P='Brainstorm/Advisor/';local S=dofile(P..'strategy.lua');local Snap=dofile(P..'snapshot.lua')
local J=dofile(P..'player_journal.lua');local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function j(key,a,id) a=a or {};a.set='Joker';return {key=key,id=id or key,ability=a,blueprint_compat=true,sell_cost=4,cost=1}end
local function state()
 return {phase='pack',teacher_profile='perkeo_yorick_win_v1',ante=3,win_ante=8,dollars=33,
 joker_limit=3,consumeables={},hand={},deck={},playing_cards={},hands={},modifiers={},
 jokers={j('j_yorick',{name='Yorick',x_mult=4,yorick_discards=5,extra={discards=23,xmult=1},eternal=true}),
 j('j_perkeo',{name='Perkeo',eternal=true}),j('j_egg',{name='Egg'})},
 -- A neutral scorer keeps this endpoint comparison independent of the419
 -- acquisition guard against Jokers that penalize using discards.
 pack_cards={j('j_ice_cream',{name='Ice Cream',extra={chips=85,chip_mod=5}},'scoring_offer'),
 j('j_blueprint',{name='Blueprint',eternal=true,rental=true},'copy_offer')}}
end
local function context(override)
 local c={evaluations=0,truncated=false}
 function c:compare(before,after)
  self.evaluations=self.evaluations+8
  local mean=100
  for _,v in ipairs(after.jokers) do
   if v.key=='j_blueprint' then mean=4000 elseif v.key=='j_ice_cream' then mean=override or 400 end
  end
  return {samples=4,ratio=mean/100,adjustment=35,after_mean=mean,before_mean=100,
   before_target=500,after_target=500,uncertain=true,complete_finishing=false,
   reason='Manufactured uncertain endpoints; no safety certificate.'}
 end
 return c
end
local s=state();local before=Snap.fingerprint(s)
local plan=S.advise(s,{shop_scoring=context()})
check(plan.action and plan.action.kind=='sell' and plan.action.index==3,'full row chooses legal Egg sale')
check(table.concat(plan.lines,' '):find('Blueprint',1,true),'sale advice identifies its Blueprint endpoint')
local fresh=Snap.copy(s);table.remove(fresh.jokers,3);fresh.dollars=37
local choice=S.advise(fresh,{shop_scoring=context()})
check(choice.action.kind=='choose' and choice.action.index==2,'fresh vacancy preserves Blueprint endpoint preference')
local chosen
for _,e in ipairs(plan.pack_diagnostics.comparisons) do
 if e.sold_index==3 and e.index==2 then chosen=e end
end
check(chosen and chosen.collection_admitted and chosen.score>0,'same Blueprint endpoint was admitted before sale')
check(Snap.fingerprint(s)==before,'original pack is unchanged')
fresh.pack_cards[2]=nil
local vanished=S.advise(fresh,{shop_scoring=context()})
check(vanished.action.index~=2,'absent offer cannot be followed by stale index')
fresh=Snap.copy(s);table.remove(fresh.jokers,3);fresh.dollars=37
local better=S.advise(fresh,{shop_scoring=context(1e12)})
check(better.action.index==1,'materially stronger newly observed endpoint may change preference')
local core=state();local offer=j('j_blueprint',{name='Blueprint',perishable=true,perish_tally=2,rental=true})
local after=Snap.copy(core);table.remove(after.jokers,2);after.jokers[#after.jokers+1]=offer
local okay,why=S.joker_admission(core,offer,after,nil)
check(not okay and why.kind=='temporary_core_bridge_guard','temporary power cannot casually consume durable Perkeo')
after=Snap.copy(core);table.remove(after.jokers,3);after.jokers[#after.jokers+1]=offer
check(S.joker_admission(core,offer,after,nil),'non-core replacement retains engine')
core.ante=8;core.next_blind={label='Boss',ante=8};after=Snap.copy(core);table.remove(after.jokers,2);after.jokers[#after.jokers+1]=offer
check(S.joker_admission(core,offer,after,nil),'final horizon does not impose blanket core-sale veto')
local receipt=J.compact_copy_death_review({strategy=plan,action=plan.action,
 copy_acquisition_diagnostics={reason='focused_rejected',replacements={complete=false,candidates={{sale_index=3,offer_index=2,reason='cash_reserve'}}}},
 death_fishing_review={status='declined',reason='no_better_source',attempted=true,complete=true,worlds={secret=true}}})
check(receipt.focused_replacements.candidates[1].reason=='cash_reserve','focused rejection remains distinct from ordinary pack context')
check(receipt.pack and #receipt.pack.candidates>0,'pack endpoint receipt survives serialization')
check(receipt.fishing.reason=='no_better_source' and not receipt.fishing.worlds,'fishing scalar disposition excludes private worlds')
print('advisor_pack_endpoint404: '..checks..' checks passed')

-- A supported emergency clear may justify spending future engine growth.
do
 local before=state();local offer=j('j_blueprint',{name='Blueprint',perishable=true,perish_tally=2})
 local after=Snap.copy(before);table.remove(after.jokers,2);after.jokers[#after.jokers+1]=offer
 local a,b={},{};for i=1,4 do a[i]={clear=false};b[i]={clear=true} end
 local e={samples=4,before_target=500,after_target=500,complete_finishing=true,
  common_worlds={kind='shop_four_common_worlds_v1',samples=4,family_key='independent404',world_ids={1,2,3,4}},
  before_finishing={complete=true,supported=true,known_mechanics=true,samples=4,selected={clearing_samples=0,worlds=a}},
  after_finishing={complete=true,supported=true,known_mechanics=true,samples=4,selected={clearing_samples=4,worlds=b}}}
 check(S.joker_admission(before,offer,after,e),'supported immediate rescue may justify temporary core replacement')
 e.uncertain=true
 check(not S.joker_admission(before,offer,after,e),'uncertain mean is not an emergency certificate')
 e.uncertain=false;e.after_finishing.selected.worlds[2].clear=false
 check(not S.joker_admission(before,offer,after,e),'one losing paired world cannot waive core bridge guard')
end
print('advisor_pack_bridge_total404: '..checks..' checks passed')

do
 local before=state();before.ante=8;before.next_blind={label='Small',ante=8}
 local offer=j('j_blueprint',{name='Blueprint',perishable=true,perish_tally=2})
 local after=Snap.copy(before);table.remove(after.jokers,2);after.jokers[#after.jokers+1]=offer
 check(not S.joker_admission(before,offer,after,nil),'early final ante still has three public unskipped blinds')
end
print('advisor_pack_horizon_total404: '..checks..' checks passed')

do
 local low=state();low.pack_cards[1]=j('j_pareidolia',{name='Pareidolia'},'face_offer')
 local function face_context()
  local c=context();local compare=c.compare
  function c:compare(before,after)
   local e=compare(self,before,after)
   for _,v in ipairs(after.jokers) do if v.key=='j_pareidolia' then e.after_mean=1e9;e.ratio=1e7 end end
   return e
  end
  return c
 end
 local sale=S.advise(low,{shop_scoring=face_context()});local endpoint
 for _,e in ipairs(sale.pack_diagnostics.comparisons) do if e.index==1 and e.sold_index==3 then endpoint=e end end
 check(endpoint and endpoint.incoming_score<26 and endpoint.admitted and endpoint.score>26,'low incoming rating cannot veto a stronger admitted endpoint')
 check(sale.action.kind=='sell' and sale.action.index==3 and table.concat(sale.lines,' '):find('Pareidolia',1,true),'full-row plan chooses strongest low-rated endpoint')
 table.remove(low.jokers,3);low.dollars=37
 local direct=S.advise(low,{shop_scoring=face_context()})
 check(direct.action.kind=='choose' and direct.action.index==1,'same retained row and offers preserve endpoint across sale')
 local guarded=state();local c=context();local compare=c.compare
 function c:compare(before,after)local e=compare(self,before,after);e.ratio=.8;return e end
 local rejected=S.advise(guarded,{shop_scoring=c})
 local receipt=J.compact_copy_death_review({strategy=rejected,action=rejected.action});local row
 for _,e in ipairs(receipt.pack.candidates) do if e.index==2 and e.sold_index==3 then row=e end end
 check(row and row.score>26 and row.objective_admitted and not row.admitted and not row.preserves_score and row.ratio==.8 and row.reason=='survival_ratio_guard','decisive survival rejection survives serialization')
 guarded.jokers[2].ability.eternal=false;guarded.pack_cards[2].ability.perishable=true;guarded.pack_cards[2].ability.perish_tally=2
 local temporary=S.advise(guarded,{shop_scoring=context()})
 receipt=J.compact_copy_death_review({strategy=temporary,action=temporary.action});row=nil
 for _,e in ipairs(receipt.pack.candidates) do if e.index==2 and e.sold_index==2 then row=e end end
 check(row and not row.admitted and row.reason=='temporary_core_bridge_guard','temporary-core rejection survives serialization')
end
print('advisor_pack_eligibility_receipts404: '..checks..' checks passed')

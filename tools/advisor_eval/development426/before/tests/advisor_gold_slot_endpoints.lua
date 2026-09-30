-- Manufactured complete endpoint families. Mechanical projections remain the
-- product implementation; only score receipts are deterministic fixture data.
local Slots=dofile('Brainstorm/Advisor/gold_slot.lua')
local Seq=dofile('Brainstorm/Advisor/shop_sequences.lua')
local Goal=dofile('Brainstorm/Advisor/gold_goal.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Liquidity=dofile('Brainstorm/Advisor/liquidity.lua')
Liquidity.snapshot=Snapshot;Strategy.liquidity=Liquidity;Strategy.consumables=Consumables;Strategy.gold_slot=Slots
Slots.gold_goal=Goal
local modules={strategy=Strategy,shop_sequences=Seq,consumables=Consumables,shop_scoring=Shop,liquidity=Liquidity,gold_slot=Slots}
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function cp(v)return Snapshot.copy(v)end
local names={j_joker='Joker',j_banner='Banner',j_popcorn='Popcorn',j_wily='Wily Joker',j_golden='Golden Joker'}
local function joker(key,id,a,cost)
 a=cp(a or {});a.name=names[key];a.set='Joker'
 return {key=key,id=id,name=a.name,ability=a,cost=cost or 3,base_cost=cost or 3,sell_cost=2,
  rarity=1,debuff=false,pinned=false,face_down=false,blueprint_compat=true}
end
local function metadata()
 return {schema=1,goal='gold_stickers',profile_id=1,metadata_status='complete',catalog_status='complete',
  stake_status='complete',held_status='complete',eligibility={status='eligible',eligible=true},
  counts={total=150,complete=147,missing=3,unknown=0},by_key={j_joker={status='complete'},
   j_banner={status='missing'},j_popcorn={status='missing'},j_wily={status='missing'},j_golden={status='missing'}}}
end
local function state()
 local s={phase='shop',ante=2,win_ante=8,stake=8,seeded=false,profile_id=1,dollars=40,bankrupt_at=0,
  joker_limit=5,consumable_limit=2,consumeable_buffer=0,jokers={},consumeables={},shop_jokers={},shop_vouchers={},shop_booster={},
  shop_forecast={discount_percent=0,inflation=0},hand_size=4,hand_limit=5,hand={},playing_cards={},deck={},hands={Pair={level=1,played=3}},
  round_resets={hands=1,discards=3},hands_left=1,discards_left=3,current_round={},modifiers={},probabilities={normal=1},
  interest_cap=25,interest_amount=1,rental_rate=3,deck_key='b_red',completionist_goal=metadata(),
  next_blind={key='bl_small',name='Small Blind',boss=false,ante=2,chips=600},blind={key='bl_small',name='Small Blind',chips=300}}
 for i=1,16 do s.playing_cards[i]={id='public:'..i,rank=2+i%8,nominal=2+i%8,suit='Hearts',ability={}}end
 return s
end
local function contains(s,key)
 for _,j in ipairs(s.jokers or {})do if j.key==key then return true end end
 return false
end
local hold={action={kind='leave_shop'}}
local function sequence_context()
 local c={evaluations=0,max_evaluations=50000,truncated=false,comparisons=0}
 local function value(s)
  local mult,chips=1,10
  if contains(s,'j_joker')then mult=mult+4 end
  if contains(s,'j_banner')then chips=chips+90 end
  if contains(s,'j_popcorn')then mult=mult+2 end
  return mult*chips+500*((s.hands.Pair or {}).level-1)
 end
 function c:readiness(s)
  local n=value(s)
  return {supported=true,status=n>=600 and 'sampled_safe' or 'sampled_deficit',target=600,
   opening_mean=n,opening_min=n,opening_max=n,opening_scores={n,n,n,n},hands=1,reason='Manufactured paired endpoint.'}
 end
 function c:compare(a,b)
  self.evaluations=self.evaluations+1;self.comparisons=self.comparisons+1
  return {samples=4,uncertain=false,ratio=value(b)/value(a),adjustment=math.min(35,value(b)/value(a)),
   before_mean=value(a),after_mean=value(b),before_readiness=self:readiness(a),after_readiness=self:readiness(b),
   reason='Manufactured paired endpoint; no deterministic survival certificate.'}
 end
 return c
end
local function bought_ids(s,actions)
 local offers=cp(s.shop_jokers);local out={}
 for _,a in ipairs(actions)do
  if a.kind=='buy' and a.area=='shop_jokers'then
   local card=table.remove(offers,a.index);if card then out[card.id]=true end
  end
 end
 return out
end
do
 local s=state();s.shop_jokers={joker('j_joker','protected',{mult=4,eternal=true}),joker('j_banner','useful',{extra=30}),joker('j_popcorn','useful2',{mult=20,extra=4})}
 local signature=Snapshot.fingerprint(s)
 local mechanical=Seq.transition(s,{kind='buy',area='shop_jokers',index=1},modules)
 check(mechanical and mechanical.jokers[1].id=='protected','policy does not rewrite a legal mechanical purchase')
 check(Slots.protected(s,s.shop_jokers[1]),'manufactured already-Gold ordinary Eternal offer is protected')
 local ctx=sequence_context();local advice,d=Seq.suggest(s,modules,hold,ctx)
 check(d.complete and d.comparisons>3,'the complete legal graph is still compared')
 eq(ctx.comparisons,d.comparisons,'endpoint admission adds no hidden score work')
 local rejected,admitted=0,0
 for _,p in ipairs(d.plans)do
  if bought_ids(s,p.actions).protected then
   rejected=rejected+1;eq(p.gold_slot_admitted,false,'every permanent completed acquisition endpoint is unselectable')
   check(p.gold_slot_admission and p.gold_slot_admission.applies,'each exclusion has a shared-policy receipt')
  elseif #p.actions>0 then admitted=admitted+1;eq(p.gold_slot_admitted,true,'unprotected visible alternatives remain eligible')end
 end
 check(rejected>1 and admitted>1,'both exclusion and viable alternatives survive complete enumeration')
 check(advice and advice.shop_sequence,'a useful alternative complete sequence remains selectable')
 check(not bought_ids(s,advice.shop_sequence.actions).protected,'chosen sequence cannot smuggle the protected card in a later step')
 for _,p in pairs(d.best_by_first_action)do
  check(not bought_ids(s,p.actions).protected,'retained first-action continuations cannot reintroduce an excluded endpoint')
 end
 eq(Snapshot.fingerprint(s),signature,'endpoint admission preserves the input')
end
do
 local s=state();s.shop_jokers={joker('j_joker','protected',{mult=4,eternal=true})}
 s.consumeables={{id='planet',key='c_mercury',cost=3,base_cost=3,sell_cost=1,ability={set='Planet',consumeable={hand_type='Pair'}}}}
 local ctx=sequence_context();local _,d=Seq.suggest(s,modules,hold,ctx)
 check(d.complete,'Planet-plus-purchase family remains mechanically complete')
 local mixed=0
 for _,p in ipairs(d.plans)do
  if bought_ids(s,p.actions).protected and p.planet_uses>0 then
   mixed=mixed+1;eq(p.gold_slot_admitted,false,'an unrelated Planet improvement cannot excuse the permanent completed acquisition')
  end
 end
 check(mixed>0,'the fixture actually contains scored Planet-plus-Eternal endpoints')
 for _,p in pairs(d.best_by_first_action)do check(not bought_ids(s,p.actions).protected,'only admitted continuations can be published')end
end
do
 for _,variant in ipairs({'missing','negative','ordinary','optout'})do
  local s=state();s.shop_jokers={joker('j_joker','offer',{mult=4,eternal=true}),joker('j_banner','other',{extra=30})}
  if variant=='missing'then s.completionist_goal.by_key.j_joker.status='missing'
  elseif variant=='negative'then s.shop_jokers[1].edition={negative=true,type='negative'}
  elseif variant=='ordinary'then s.shop_jokers[1].ability.eternal=false
  else s.completionist_goal=nil end
  local advice,d=Seq.suggest(s,modules,hold,sequence_context())
  check(advice and d.complete,'unrestricted two-buy strategy remains available: '..variant)
  check(bought_ids(s,advice.shop_sequence.actions).offer,'unrestricted incoming card can still be selected: '..variant)
  for _,p in ipairs(d.plans)do if #p.actions>0 then eq(p.gold_slot_admitted,true,'unrestricted endpoint remains admitted: '..variant)end end
 end
end
local function goal_context()
 local c={evaluations=0,max_evaluations=50000,truncated=false}
 local function value(s)return contains(s,'j_joker')and 1000 or contains(s,'j_golden')and 600 or 500 end
 function c:compare(before,after)
  self.evaluations=self.evaluations+1
  local a,b=value(before),value(after);local target=before.next_blind.chips
  return {samples=4,uncertain=false,low_sample_delta=b-a,before_target=target,after_target=target,
   before_mean=a,after_mean=b,ratio=b/a,
   before_readiness={supported=true,samples=4,target=target,opening_scores={a,a,a,a},discards=3},
   after_readiness={supported=true,samples=4,target=target,opening_scores={b,b,b,b},discards=3}}
 end
 return c
end
local function final_state()
 local s=state();s.ante=8;s.next_blind={key='bl_final_vessel',name='Violet Vessel',boss=true,ante=8,chips=100}
 s.jokers={joker('j_wily','owned-missing',{t_chips=100,type='Three of a Kind'})}
 s.shop_jokers={joker('j_joker','protected',{mult=4,eternal=true})}
 return s
end
local base={action={kind='sell',area='jokers',index=1,followup={kind='buy',area='shop_jokers',index=1}}}
do
 local s=final_state();local signature=Snapshot.fingerprint(s)
 local advice,d=Goal.suggest(s,modules,base,goal_context())
 check(advice and d.complete and d.evidence_complete,'complete final-boss retention family remains supported')
 eq(advice.action.kind,'leave_shop','keeping existing missing cargo does not require buying an unnecessary completed Eternal')
 local rejected=0
 for _,p in ipairs(d.endpoints)do
  if bought_ids(s,p.actions).protected then
   rejected=rejected+1;eq(p.gold_slot_admitted,false,'final-goal comparison also rejects protected acquisition')
   eq(p.eligible,false,'higher surplus chips cannot re-enable an inadmissible permanent slot')
  else eq(p.gold_slot_admitted,true,'the retained missing-cargo endpoint remains admitted')end
 end
 check(rejected>0,'final-goal fixture actually compares the blocked buy and replacement endpoints')
 eq(Snapshot.fingerprint(s),signature,'goal admission cannot mutate the public state')
 s.shop_jokers[2]=joker('j_golden','new-missing',{extra=4})
 advice,d=Goal.suggest(s,modules,base,goal_context())
 check(advice and d.complete,'an alternative missing target remains selectable')
 eq(advice.action.kind,'buy','alternative is a direct visible purchase')
 eq(advice.action.index,2,'the actual missing offer is chosen over surplus completed-Eternal score')
 eq(d.after_missing,2,'both distinct missing targets are retained')
end
do
 for _,variant in ipairs({'negative','ordinary','missing'})do
  local s=final_state()
  if variant=='negative'then s.shop_jokers[1].edition={negative=true,type='negative'}
  elseif variant=='ordinary'then s.shop_jokers[1].ability.eternal=false
  else s.completionist_goal.by_key.j_joker.status='missing'end
  local advice,d=Goal.suggest(s,modules,base,goal_context())
  check(advice and d.complete,'final-goal admissible purchase remains available: '..variant)
  eq(advice.action.kind,'buy','final-goal unprotected offer can still be acquired: '..variant)
  eq(d.selected.gold_slot_admitted,true,'selected goal endpoint contains its positive policy receipt: '..variant)
 end
end
print('PASS Gold slot endpoint integration '..checks..' checks')

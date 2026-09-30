-- Manufactured public states and prescribed evidence only. No captured/source run.
local P='tools/advisor_eval/development328/replacement_evidence_component/'
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local function same(a,b,label)check(Snapshot.fingerprint(a)==Snapshot.fingerprint(b),label)end
local function joker(key,name,extra,cost)
 local a={name=name,set='Joker',x_mult=1};for k,v in pairs(extra or {})do a[k]=v end
 return {id=key,key=key,name=name,ability=a,blueprint_compat=true,cost=cost or 4,sell_cost=2}
end
local function state(phase)
 local s={phase=phase,ante=4,win_ante=8,dollars=30,bankrupt_at=0,joker_limit=3,consumable_limit=2,
  jokers={joker('j_perkeo','Perkeo',{eternal=true}),
   joker('j_yorick','Yorick',{eternal=true,x_mult=12,yorick_discards=12,extra={discards=23,xmult=1}}),
   joker('j_joker','Joker',{mult=4})},
  consumeables={{id='planet',key='c_mercury',ability={set='Planet',consumeable={hand_type='Pair'}}}},
  playing_cards={},deck={},hand={},hands={Pair={played=8,level=4,chips=55,mult=5,l_chips=15,l_mult=1}},
  shop_jokers={},shop_booster={},shop_vouchers={},pack_cards={},pack_choices=1,interest_cap=25,modifiers={},reroll_cost=5}
 for _,suit in ipairs({'Spades','Hearts','Clubs','Diamonds'})do for rank=2,14 do
  s.playing_cards[#s.playing_cards+1]={id=suit..rank,rank=rank,suit=suit,ability={}}
 end end
 local offers={joker('j_blueprint','Blueprint',{},10),joker('j_brainstorm','Brainstorm',{},10)}
 s[phase=='shop' and 'shop_jokers' or 'pack_cards']=offers
 return s
end
local function context(s,unavailable)
 local ctx={evaluations=0,calls=0,records={}}
 function ctx:compare(left,right)
  self.calls=self.calls+1;self.evaluations=self.evaluations+17
  check(#left.jokers==3 and #right.jokers==3,'prescribed evidence compares full rows')
  local evidence={samples=4,ratio=4,adjustment=35,before_mean=100,after_mean=400,reason='Manufactured complete paired evidence.',
   complete_finishing=true,common_worlds={family_key='manufactured-four-worlds'},before_target=300,after_target=300}
  local function endpoint(input,score)
   local worlds={};for i=1,4 do worlds[i]={composition_world_id=i,score=score,clear=score>=300,
    endpoint_resources={dollars=input.dollars,jokers=Snapshot.copy(input.jokers),inventory=Snapshot.copy(input.consumeables)}}end
   return {complete=true,supported=true,known_mechanics=true,samples=4,
    selected={clearing_samples=score>=300 and 4 or 0,mean_progress=math.min(1,score/300),worlds=worlds}}
  end
  evidence.before_finishing=endpoint(left,100);evidence.after_finishing=endpoint(right,400)
  if not unavailable then self.records[#self.records+1]=evidence;return evidence end
 end
 return ctx
end
local function run(path,s,unavailable,decision)
 local strategy=dofile(path);local ctx=context(s,unavailable)
 local modules={strategy=strategy,scoring={},shop_scoring={new=function()return ctx end}}
 local result=decision and Decision.run(s,modules) or strategy.advise(s,{shop_scoring=ctx})
 return result,ctx,strategy
end
local old_random=math.random;math.random=function()error('Evidence forwarding cannot sample RNG')end
for _,phase in ipairs({'shop','pack'})do
 for _,decision in ipairs({false,true})do
  local s=state(phase);local initial=Snapshot.fingerprint(s)
  local baseline,bctx=run(P..'baseline.lua',s,false,decision)
  local candidate,cctx,strategy=run(P..'strategy.lua',s,false,decision)
  local b=decision and baseline.strategy or baseline;local c=decision and candidate.strategy or candidate
  check(b.action.kind=='sell' and b.action.index==3,'manufactured path chooses supported filler replacement')
  same(b.action,c.action,'first action and declared follow-up are unchanged')
  check(c.action.followup.kind==(phase=='shop' and 'buy' or 'choose'),'shared helper keeps phase-specific follow-up')
  check(b.scoring_evidence==nil,'baseline demonstrates missing replacement receipt')
  check(c.scoring_evidence~=nil,'candidate exports the already computed paired receipt')
  check(cctx.calls==bctx.calls and cctx.evaluations==bctx.evaluations,'forwarding adds no comparisons or score work')
  check(cctx.calls==2,'both admitted offers are compared exactly once')
  local selected=c.scoring_evidence;local found=false
  for _,e in ipairs(cctx.records)do if e==selected then found=true end end
  check(found,'returned evidence is the actual existing complete comparison object')
  check(selected.complete_finishing and selected.samples==4,'complete family metadata is forwarded')
  for _,endpoint in ipairs({selected.before_finishing,selected.after_finishing})do
   check(endpoint.complete and endpoint.supported and endpoint.known_mechanics,'each complete endpoint is preserved')
   for i,w in ipairs(endpoint.selected.worlds)do
    check(w.composition_world_id==i,'every world identifier is preserved')
    check(#w.endpoint_resources.inventory==1,'whole inventory survives in the receipt')
   end
  end
  local without=Snapshot.copy(c);without.scoring_evidence=nil
  same(without,b,'all preexisting advice fields are unchanged')
  check(Snapshot.fingerprint(s)==initial,'evidence forwarding does not mutate input')
  local fingerprint=Snapshot.fingerprint(selected)
  same(selected,Snapshot.copy(selected),'full evidence can be copied without losing fields')
  check(Snapshot.fingerprint(selected)==fingerprint,'receipt copy leaves evidence unchanged')
  if decision then
   check(candidate.evaluations==baseline.evaluations,'Decision wrapper reports identical work')
   check(candidate.strategy.scoring_evidence==selected,'Decision wrapper preserves full strategy evidence')
  end
  strategy.paid_reroll={catalog={},suggest=function()error('A replacement receipt must not admit new reroll work')end}
  local calls=cctx.calls
  check(strategy.shortfall_reroll(s,c,cctx)==nil and cctx.calls==calls,'ordinary replacement remains excluded from shortfall reroll')
 end
 local s=state(phase)
 local result,ctx=run(P..'strategy.lua',s,true,false)
 check(result.scoring_evidence==nil,'unavailable evidence is not invented')
 local strategy=dofile(P..'strategy.lua');local plain=strategy.advise(s)
 check(plain.scoring_evidence==nil,'heuristic-only advice remains explicitly without paired evidence')
end
math.random=old_random
print('replacement evidence forwarding: '..checks..' checks passed')

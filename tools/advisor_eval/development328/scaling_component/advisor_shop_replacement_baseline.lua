-- Manufactured fixtures only: no observed player state or historical seed is run.
local Strategy=dofile('tools/advisor_eval/development328/scaling_component/strategy_candidate.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local function eq(a,b,label)check(a==b,label..': '..tostring(a)..' ~= '..tostring(b))end
local function copy(v)return Snapshot.copy(v)end
local function joker(key,name,a,cost)
 a=a or {};a.name=name;a.set='Joker'
 return {id=key,key=key,name=name,ability=a,blueprint_compat=true,cost=cost or 0,sell_cost=2}
end
local function state()
 local s={phase='shop',ante=5,win_ante=8,dollars=60,bankrupt_at=0,joker_limit=5,consumable_limit=2,
 jokers={joker('j_yorick','Yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=11}),
 joker('j_perkeo','Perkeo'),joker('j_sly','Sly Joker',{t_chips=50,type='Pair'}),
 joker('j_greedy_joker','Greedy Joker',{extra={s_mult=3,suit='Diamonds'}}),
 joker('j_trio','The Trio',{x_mult=3,type='Three of a Kind',perishable=true,perish_tally=3,rental=true})},
 consumeables={},hand={},deck={},playing_cards={},shop_jokers={joker('j_blueprint','Blueprint',{eternal=true},10)},
 shop_booster={},shop_vouchers={},hand_size=8,hand_limit=5,
 hands={Pair={level=2,played=5,chips=25,mult=3},['Three of a Kind']={level=3,played=4,chips=70,mult=7}},
 round_resets={hands=4,discards=3},current_round={},blind={key='bl_small',name='Small Blind'},
 next_blind={key='bl_small',name='Small Blind',chips=12000},modifiers={scaling=3},probabilities={normal=1},
 interest_cap=25,reroll_cost=5,consumeable_buffer=0,deck_key='b_red'}
 for _,suit in ipairs({'Hearts','Clubs','Diamonds','Spades'})do for rank=2,14 do
  s.playing_cards[#s.playing_cards+1]={id='test:'..suit..rank,rank=rank,nominal=rank==14 and 11 or math.min(rank,10),
   suit=suit,enhancement='c_base',ability={}}
 end end
 return s
end
local function wire()
 local finish=dofile('Brainstorm/Advisor/blind_finishing.lua')
 local liquidity=dofile('Brainstorm/Advisor/liquidity.lua');liquidity.snapshot=Snapshot
 for _,name in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'})do
  finish[name]=dofile('Brainstorm/Advisor/'..name..'.lua')
 end
 finish.strategy=Strategy;Shop.blind_finishing=finish;Shop.liquidity=liquidity;Shop.strategy=Strategy
 Strategy.liquidity=liquidity;Strategy.consumables=dofile('Brainstorm/Advisor/consumables.lua')
 Strategy.conditional_value=dofile('Brainstorm/Advisor/conditional_value.lua');Strategy.conditional_value.liquidity=liquidity
 Strategy.synergies=dofile('Brainstorm/Advisor/synergies.lua')
end
wire()
math.random=function()error('shop replacement comparison used RNG')end
pseudorandom=function()error('shop replacement comparison used live RNG')end

-- Every complete paired request binds the actual retained row to its funded
-- purchase endpoint. There is no economically irrelevant vacant-slot baseline.
do
 local s=state();s.jokers[1].ability.eternal=true
 s.shop_jokers[2]=joker('j_brainstorm','Brainstorm',{},8)
 local before=Snapshot.fingerprint(s);local targets={};local calls=0
 local context={readiness=function()return {supported=false}end}
 function context:compare(left,right)
  calls=calls+1
  eq(#left.jokers,5,'complete original row is baseline')
  eq(Snapshot.fingerprint(left.jokers),Snapshot.fingerprint(s.jokers),'every baseline owns the same physical Jokers')
  eq(left.dollars,60,'every baseline keeps original cash')
  eq(#right.jokers,5,'replacement endpoint has the incoming Joker and retained row')
  local sold,owned=nil,{}
  for _,c in ipairs(right.jokers)do owned[c.id]=true end
  for _,c in ipairs(s.jokers)do if not owned[c.id]then sold=c end end
  check(sold and sold.key~='j_yorick','protected original is never admitted as a sale')
  local incoming=right.jokers[5]
  check(incoming.key=='j_blueprint' or incoming.key=='j_brainstorm','visible purchased copy reaches endpoint')
  eq(right.dollars,60+sold.sell_cost-incoming.cost,'sale proceeds and exact purchase cost fund endpoint')
  targets[sold.key..':'..incoming.key]=true
  eq(Snapshot.fingerprint(right.consumeables),Snapshot.fingerprint(s.consumeables),'whole inventory survives replacement')
  return {samples=4,ratio=3,adjustment=30,before_mean=100,after_mean=300,reason='Controlled complete paired endpoint.'}
 end
 local result=Strategy.advise(s,{shop_scoring=context})
 check(result.action.kind=='sell','a complete useful comparison produces the actual first sale')
 local count=0;for _ in pairs(targets)do count=count+1 end
 eq(count,8,'all four legal victims and both visible offers are compared')
 check(calls>=8,'comparison family was completed before choosing its first action')
 eq(Snapshot.fingerprint(s),before,'paired comparisons leave original state unchanged')
end

-- Funded affordability is evaluated after the actual sale, not at the root.
do
 local s=state();s.dollars=1;s.shop_jokers[1].cost=8;s.jokers[3].sell_cost=10
 for i,j in ipairs(s.jokers)do if i~=3 then j.ability.eternal=true end end
 local compared=0
 local context={compare=function(_,left,right)
  compared=compared+1;eq(left.dollars,1,'low-cash original remains original')
  eq(right.dollars,3,'sale funds the otherwise unaffordable offer')
  return {samples=4,ratio=4,adjustment=35,before_mean=100,after_mean=400,reason='Funded complete endpoint.'}
 end}
 Strategy.advise(s,{shop_scoring=context});check(compared>0,'funded endpoint is not pruned by pre-sale affordability')
 s.jokers[3].sell_cost=1;compared=0
 Strategy.advise(s,{shop_scoring=context});eq(compared,0,'an unfunded endpoint never receives a score comparison')
end

-- A real finite manufactured deck completes its entire admitted comparison
-- below 25k calls; the ordinary unchanged hard ceiling remains 50k.
do
 local s=state();local input=Snapshot.fingerprint(s)
 local context=Shop.new(s,Scoring,nil,{max_evaluations=25000})
 local evidence_by_victim={};local compare=context.compare
 context.compare=function(self,left,right)
  local evidence=compare(self,left,right);local owned={}
  for _,j in ipairs(right.jokers)do owned[j.id]=true end
  for i,j in ipairs(s.jokers)do if not owned[j.id]then evidence_by_victim[i]=evidence end end
  return evidence
 end
 local result=Strategy.advise(s,{shop_scoring=context})
 check(not context.truncated,'all admitted manufactured endpoints fit the smaller cap')
 check(context.evaluations>0 and context.evaluations<25000,'real work stays within the supplied budget')
 local selected=result.action.kind=='sell' and evidence_by_victim[result.action.index]
 check(selected and selected.complete_finishing,'the actual replacement keeps complete finishing evidence')
 eq(selected.samples,4,'four complete common worlds')
 check(selected.common_worlds and type(selected.common_worlds.family_key)=='string',
  'the complete comparison carries its original common-world identity')
 eq(selected.before_target,12000,'original target is preserved')
 eq(selected.after_target,12000,'paid endpoint uses the same target')
 for _,finish in ipairs({selected.before_finishing,selected.after_finishing})do
  check(finish.complete and finish.supported and finish.known_mechanics,'both endpoints have complete supported policies')
  for i,world in ipairs(finish.selected.worlds)do
   eq(world.composition_world_id,i,'both complete policies preserve identical declared composition-world IDs')
  end
 end
 eq(context.max_evaluations,25000,'lower requested cap is preserved')
 eq(Shop.new(s,Scoring,nil,{max_evaluations=100000}).max_evaluations,50000,'ordinary hard cap is preserved')
 eq(Snapshot.fingerprint(s),input,'real scoring and finishing do not mutate source state')
 local again=Shop.new(s,Scoring,nil,{max_evaluations=25000})
 eq(Snapshot.fingerprint(result),Snapshot.fingerprint(Strategy.advise(s,{shop_scoring=again})),'result is deterministic')
 eq(again.evaluations,context.evaluations,'work count is deterministic')
 local modules={strategy=Strategy,scoring=Scoring,shop_scoring=Shop,consumables=Strategy.consumables}
 local fallback=Strategy.advise(s)
 local capped=Decision.run(s,modules,nil,{shop_scoring={max_evaluations=1}})
 check(capped.shop_diagnostics.truncated,'incomplete entire comparison is explicitly reported')
 eq(Snapshot.fingerprint(capped.action),Snapshot.fingerprint(fallback.action),'incomplete family uses whole strategic fallback')
end
print('advisor_shop_replacement_baseline: '..checks..' checks passed')

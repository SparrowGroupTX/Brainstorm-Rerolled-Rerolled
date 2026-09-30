-- Manufactured public states only. No original source execution or save data.
local P='tools/advisor_eval/development299/drafts/certificate_opening/'
local C=dofile(P..'certificate.lua')
local Snap=dofile(P..'snapshot.lua');Snap.certificate=C
local Shop=dofile(P..'shop_scoring.lua')
local Q='tools/advisor_eval/development300/pack_survival310/'
local Finish=dofile(Q..'blind_finishing.lua')
local Pack=dofile(Q..'pack_survival.lua');Finish.pack_survival=Pack
local Discard=dofile(P..'multi_discard.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile(Q..'strategy.lua');Strategy.pack_survival=Pack
local Liquidity=dofile('Brainstorm/Advisor/liquidity.lua');Liquidity.snapshot=Snap
for _,name in ipairs({'search','draws','sampled_outcomes','finish_rewards'}) do
  Finish[name]=dofile('Brainstorm/Advisor/'..name..'.lua')
end
Finish.multi_discard=Discard;Finish.strategy=Strategy
Shop.blind_finishing=Finish;Shop.strategy=Strategy;Shop.liquidity=Liquidity
Shop.blind_start=dofile('Brainstorm/Advisor/blind_start.lua')
Shop.paired_deck=dofile('Brainstorm/Advisor/paired_deck.lua');Shop.certificate=C
Strategy.liquidity=Liquidity
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function eq(a,b,m)check(a==b,(m or '')..': '..tostring(a)..' ~= '..tostring(b))end
local copy=Snap.copy
local function registry()
  local fronts={};local names={[11]='Jack',[12]='Queen',[13]='King',[14]='Ace'}
  for _,suit in ipairs({'Clubs','Diamonds','Hearts','Spades'}) do for rank=2,14 do
    fronts[suit..rank]={id=rank,nominal=rank==14 and 11 or math.min(rank,10),suit=suit,value=names[rank] or tostring(rank)}
  end end
  return {P_CARDS=fronts,P_CENTERS={c_base={key='c_base',set='Default',name='Default Base',config={}}},
    jokers={cards={{config={center={key='j_certificate'}}}}}}
end
local function joker(key,name,a)
  a=a or {};a.name=name;a.set='Joker'
  return {id=key,key=key,name=name,ability=a,cost=4,sell_cost=2,blueprint_compat=true,face_down=false,debuff=false}
end
local function state()
  local s={phase='shop',ante=1,win_ante=8,dollars=6,bankrupt_at=0,joker_limit=5,consumeables={},consumeable_buffer=0,
    consumable_limit=2,jokers={},hands={},modifiers={},probabilities={normal=1},hand_size=8,hand_limit=1,
    round_resets={hands=4,discards=3},current_round={},playing_cards={},next_blind={key='bl_small',chips=150},
    next_blind_chips=150,shop_jokers={},shop_booster={},shop_vouchers={},reroll_cost=5,certificate_pool=C.capture(registry())}
  for _,hand in ipairs({'High Card','Pair','Two Pair','Three of a Kind','Straight','Flush','Full House',
    'Four of a Kind','Straight Flush','Five of a Kind','Flush House','Flush Five'}) do
    s.hands[hand]={level=1,chips=20,mult=1,played=0,l_chips=10,l_mult=1,s_chips=20,s_mult=1}
  end
  for i=1,24 do s.playing_cards[i]={id='p'..i,rank=2,nominal=2,suit=({'Clubs','Diamonds','Hearts','Spades'})[(i-1)%4+1],
    key='c_base',name='Default Base',face_down=false,debuff=false,ability={}} end
  return s
end
local function drawn(s)
  local r=copy(s);r.phase='hand';r.hand,r.deck={},{}
  r.blind={key='bl_small',chips=150,disabled=false,debuff={}}
  r.hands_left=4;r.discards_left=3;r.chips=0
  for i,c in ipairs(r.playing_cards) do if i<=8 then r.hand[#r.hand+1]=c else r.deck[#r.deck+1]=c end end
  return r
end
local old_random,old_seed=math.random,math.randomseed
math.random=function()error('Touched game RNG')end;math.randomseed=function()error('Reseeded game RNG')end

local s=state();s.phase='pack';s.pack_type='BUFFOON_PACK';s.pack_choices=1;s.interest_amount=1;s.interest_cap=25;s.next_blind.chips=100;s.next_blind_chips=100
s.jokers={joker('j_yorick','Yorick',{x_mult=1,yorick_discards=23,extra={discards=23,xmult=1}}),joker('j_perkeo','Perkeo')}
s.pack_cards={joker('j_certificate','Certificate'),joker('j_card_sharp','Card Sharp',{extra={Xmult=3}})}
local cert,sharp=copy(s),copy(s)
cert.jokers[#cert.jokers+1]=copy(s.pack_cards[1]);sharp.jokers[#sharp.jokers+1]=copy(s.pack_cards[2])
local ctx=Shop.new(s,Score,nil,{max_evaluations=50000});s._shop_scoring=ctx
local ce=ctx:compare(s,cert);local se=ctx:compare(s,sharp)
check(ce and se and ce.complete_finishing and se.complete_finishing,'both complete actual families')
local candidates={{index=1,card=s.pack_cards[1],score=100,scoring_evidence=ce},{index=2,card=s.pack_cards[2],score=50,scoring_evidence=se}}
local before_calls=ctx.evaluations
local initial_assets=Snap.fingerprint(Pack.capture(s));local initial_offers=Snap.fingerprint(s.pack_cards)
local chosen,diag=Pack.choose(s,candidates,candidates[1],{})
check(chosen==candidates[2],'complete current-blind survival chooses Card Sharp: '..tostring(diag.reason))
eq(ctx.evaluations,before_calls,'choice uses existing comparisons without extra scores')

Strategy.pack_survival=nil
local old_advice=Strategy.advise(s)
eq(old_advice.action.index,1,'unmodified heuristic prefers Certificate despite all failed composition worlds')
Strategy.pack_survival=Pack
local advice=Strategy.advise(s)
eq(advice.action.index,2,'complete public pack advice selects the supported survival choice')
check(advice.pack_diagnostics.survival_priority.selected_policy=='play_only','one whole fixed policy selected')
check(advice.pack_diagnostics.offers[1].score>advice.pack_diagnostics.offers[2].score,'survival decision does not rewrite heuristic ratings')
check(diag.forgone_generation_unpriced and diag.future_play_history_unpriced,'later optional generation/history value explicitly omitted')
eq(ctx.evaluations,before_calls,'full heuristic comparison and new override share cached work')
for _,e in ipairs({ce,se})do for _,p in ipairs(e.after_finishing.policies)do for _,w in ipairs(p.worlds)do
 check(w.endpoint_resources and w.endpoint_resources.play_history,'all endpoints preserve actual physical/history receipt')
 eq(w.endpoint_resources.inventory[1],nil,'whole empty Perkeo inventory preserved')
 eq(#w.endpoint_resources.jokers,3,'root two and selected offer recorded')
end end end

-- Receipt corruption tests deliberately operate on detached evidence, never
-- source game state. Every failure preserves the incumbent instead of scoring.
local function fresh()
 local ss={};for k,v in pairs(s)do if k~='_shop_scoring'then ss[k]=copy(v)end end
 ss._shop_scoring={truncated=false}
 local cc=copy(candidates)
 for i,c in ipairs(cc)do
  c.card=ss.pack_cards[i]
  for _,kind in ipairs({'before_finishing','after_finishing'})do
   local f=c.scoring_evidence[kind]
   for _,p in ipairs(f.policies)do if p.name==f.selected.name then f.selected=p;break end end
  end
 end
 return ss,cc,{}
end
local function worlds(cc,index,fn)
 for _,p in ipairs(cc[index].scoring_evidence.after_finishing.policies)do
  for i,w in ipairs(p.worlds)do fn(w,i,p)end
  p.clearing_samples=0;for _,w in ipairs(p.worlds)do p.clearing_samples=p.clearing_samples+(w.clear and 1 or 0)end
 end
end
local function reject(label,fn)
 local ss,cc,dd=fresh();fn(ss,cc,dd)
 local c,d=Pack.choose(ss,cc,cc[1],dd)
 check(not c,label..': '..tostring(d.reason));check(type(d.reason)=='string',label..' carries explicit reason')
end
reject('incomplete existing budget',function(ss)ss._shop_scoring.truncated=true end)
reject('incomplete candidate diagnostics',function(ss,cc,dd)dd.incomplete=true end)
reject('missing fourth offer',function(ss)ss.pack_cards[3]=copy(ss.pack_cards[1])end)
reject('unsupported offer identity',function(ss)ss.pack_cards[1].key='j_cloud_9'end)
reject('unknown extra Joker callback',function(ss)ss.jokers[2].key='j_cloud_9'end)
reject('full ordinary row',function(ss)ss.joker_limit=2 end)
reject('multi-choice pack',function(ss)ss.pack_choices=2 end)
reject('non-pack scope',function(ss)ss.phase='shop'end)
reject('non-Joker pack scope',function(ss)ss.pack_type='ARCANA_PACK'end)
reject('owned nonempty Perkeo copy pool',function(ss)ss.consumeables={{id='death',key='c_death'}}end)
reject('owned uncertain card',function(ss)ss.playing_cards[1].id=nil end)
reject('owned duplicate physical identity',function(ss)ss.playing_cards[2].id=ss.playing_cards[1].id end)
reject('new root cash cannot be omitted',function(ss)ss.dollars=100 end)
reject('missing common world',function(ss,cc)cc[2].scoring_evidence.common_worlds.world_ids[4]=nil end)
reject('mismatched family',function(ss,cc)cc[2].scoring_evidence.common_worlds.family_key='other'end)
reject('mismatched discard contract',function(ss,cc)cc[2].scoring_evidence.common_worlds.discard_policy='ordinary'end)
reject('mismatched before resources',function(ss,cc)cc[2].scoring_evidence.before_finishing.policies[1].worlds[1].dollars_after=999 end)
reject('unpriced temporal uncertainty',function(ss,cc)cc[2].scoring_evidence.temporal={repeat_hand=true}end)
reject('unsupported stochastic scoring',function(ss,cc)cc[2].scoring_evidence.uncertain=true;cc[2].scoring_evidence.generation_only_uncertainty=false end)
reject('missing all endpoint data',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources=nil end)end)
reject('missing finish reward components',function(ss,cc)worlds(cc,2,function(w)w.finish_details=nil end)end)
reject('unknown end-round Joker',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.jokers[3].key='j_golden'end)end)
reject('rental not silently cash neutral',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.jokers[3].ability.rental=true end)end)
reject('perishable not silently retained',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.jokers[3].ability.perishable=true end)end)
reject('edition cash/scoring scope',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.jokers[3].edition={foil=true}end)end)
reject('finite cashout required',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.interest_amount=0/0 end)end)
reject('whole inventory changed',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.inventory={{key='c_mercury'}}end)end)
reject('Observatory scope retained',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.used_vouchers={v_observatory=true}end)end)
reject('missing initial physical survivor',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.population['string:p1']=nil end)end)
reject('changed developed rank',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.population['string:p1'].rank=3 end)end)
reject('lost permanent card bonus',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.population['string:p1'].ability.perma_bonus=-1 end)end)
reject('changed Steel identity',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.population['string:p1'].enhancement='m_steel'end)end)
reject('lost owned hand level',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.hands.Pair.level=0 end)end)
reject('lost owned hand chips',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.hands.Pair.chips=19 end)end)
reject('lost owned hand multiplier',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.hands.Pair.mult=0 end)end)
reject('lost owned Yorick multiplier',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.jokers[1].ability.x_mult=0 end)end)
reject('invalid negative countdown',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.jokers[1].ability.yorick_discards=-1 end)end)
reject('unrecognized Yorick development mutation',function(ss,cc)worlds(cc,2,function(w)w.endpoint_resources.jokers[1].ability.other_bonus=1 end)end)
reject('forged wrong composition ordinal',function(ss,cc)worlds(cc,2,function(w,i)if i==4 then w.composition_world_id=3 end end)end)
reject('unsupported missing policy',function(ss,cc)cc[2].scoring_evidence.after_finishing.policies[2]=nil end)
reject('false clearing count',function(ss,cc)cc[2].scoring_evidence.after_finishing.policies[1].clearing_samples=3 end)
reject('score threshold inconsistency',function(ss,cc)worlds(cc,2,function(w)w.score=99 end)end)
reject('unmodeled action cost',function(ss,cc)worlds(cc,2,function(w)w.action_count=w.action_count+1 end)end)
reject('no per-world policy cherry picking',function(ss,cc)
 worlds(cc,2,function(w,i,p)if i==(p.name=='play_only'and 1 or 2)then
  w.score=99;w.shortfall=1;w.progress=.99;w.clear=false
 end end)
end)
-- Give only the first incumbent world a supported clear, retaining failed
-- worlds elsewhere; the override must now protect that successful endpoint.
local function incumbent_clear(cc)
 local f=cc[1].scoring_evidence.after_finishing
 for _,p in ipairs(f.policies)do
  p.worlds[1]=copy(cc[2].scoring_evidence.after_finishing.policies[1].worlds[1])
  p.worlds[1].endpoint_resources.jokers[3]=copy(cc[1].card)
  p.clearing_samples=1
 end
 return f
end
do
 local ss,cc,dd=fresh();incumbent_clear(cc)
 local selected=Pack.choose(ss,cc,cc[1],dd)
 check(selected==cc[2],'survival upgrade can preserve an already-clearing incumbent world')
end
do
 local ss,cc,dd=fresh()
 cc[1].scoring_evidence.after_finishing=copy(cc[2].scoring_evidence.after_finishing)
 local f=cc[1].scoring_evidence.after_finishing;f.selected=f.policies[1]
 local selected,d=Pack.choose(ss,cc,cc[1],dd)
 check(not selected and d.complete,'already-clearing incumbent retains development preference')
end
reject('Blue count cannot be traded for scalar utility',function(ss,cc)
 incumbent_clear(cc);worlds(cc,1,function(w,i)if i==1 then w.finish_details.blue_planets=1;w.finish_details.slots_after_blue=1 end end)
 worlds(cc,2,function(w)w.finish_reward=1000000 end)
end)
reject('Blue hand cannot be changed',function(ss,cc)
 incumbent_clear(cc)
 for c=1,2 do worlds(cc,c,function(w,i)if i==1 then
  w.finish_details.blue_planets=1;w.finish_details.slots_after_blue=1
  if c==1 then w.finish_details.planet_hand='Pair';w.finish_details.planet_key='c_mercury'end
 end end)end
end)
reject('extra Blue cannot silently consume protected room',function(ss,cc)
 incumbent_clear(cc);worlds(cc,2,function(w,i)if i==1 then w.finish_details.blue_planets=1;w.finish_details.slots_after_blue=1 end end)
end)
reject('less cash cannot be offset by hypothetical Planet utility',function(ss,cc)
 incumbent_clear(cc);worlds(cc,1,function(w,i)if i==1 then w.finish_details.held_dollars=3 end end)
 worlds(cc,2,function(w)w.finish_reward=1000000 end)
end)
reject('surviving incumbent Yorick growth protected',function(ss,cc)
 incumbent_clear(cc);worlds(cc,1,function(w,i)if i==1 then w.endpoint_resources.jokers[1].ability.yorick_discards=1 end end)
end)
reject('surviving incumbent hand history leader protected',function(ss,cc)
 incumbent_clear(cc);worlds(cc,1,function(w,i)if i==1 then w.endpoint_resources.hands.Pair.played=99 end end)
end)
reject('surviving incumbent hand level protected',function(ss,cc)
 incumbent_clear(cc);worlds(cc,1,function(w,i)if i==1 then w.endpoint_resources.hands.Pair.level=2 end end)
end)
reject('malformed evidence does not crash the advisor',function(ss,cc)cc[2].scoring_evidence.after_finishing.policies[1].worlds=false end)
local bad={playing_cards={{id='bad',ability={}}}};bad.playing_cards[1].ability.loop=bad
check(Pack.capture(bad)==nil,'cyclic capture declines without mutating or evaluating')
eq(ctx.evaluations,before_calls,'all corruption checks are zero-score receipt comparisons')
eq(Snap.fingerprint(Pack.capture(s)),initial_assets,'public assets unchanged by comparison/advice')
eq(Snap.fingerprint(s.pack_cards),initial_offers,'offered cards unchanged')
for _,name in ipairs({'runtime','strategy','blind_finishing','pack_survival'})do check(loadfile(Q..name..'.lua'),'detached '..name..' parses')end
print('Pack survival: '..checks..' checks; '..ctx.evaluations..' charged synthetic scores; no source attempt')
math.random,math.randomseed=old_random,old_seed

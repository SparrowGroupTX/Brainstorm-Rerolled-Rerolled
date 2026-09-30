-- Manufactured public states only. No original source execution or save data.
local P='Brainstorm/Advisor/'
local C=dofile(P..'certificate.lua')
local Snap=dofile(P..'snapshot.lua');Snap.certificate=C
local Shop=dofile(P..'shop_scoring.lua')
local Q='tools/advisor_eval/development300/pack_compare314/'
local Finish=dofile(P..'blind_finishing.lua')
local Pack=dofile(Q..'pack_survival.lua');Finish.pack_survival=Pack
local Discard=dofile(P..'multi_discard.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile(P..'strategy.lua');Strategy.pack_survival=Pack
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


-- Manufactured full standard rank/suit population with ordinary rich metadata.
-- No captured game state or preserved C05 action is replayed here.
local s=state();s.phase='pack';s.pack_type='BUFFOON_PACK';s.pack_choices=1
s.interest_amount=1;s.interest_cap=25;s.next_blind.chips=150;s.next_blind_chips=150
s.playing_cards={}
for suit_index,suit in ipairs({'Clubs','Diamonds','Hearts','Spades'})do for rank=2,14 do
 local id=#s.playing_cards+1;local nominal=rank==14 and 11 or math.min(rank,10)
 local ability={name='Default Base',set='Default',effect='Base',mult=0,h_mult=0,h_x_mult=0,h_dollars=0,p_dollars=0,
  t_mult=0,t_chips=0,bonus=0,x_mult=1,perma_bonus=0,order=1,extra_value=0,eternal=false,perishable=false,
  rental=false,consumeable=false,played_this_ante=false,face_nominal=0,h_size=0,d_size=0,hands_played_at_create=0,type=''}
 s.playing_cards[id]={id='physical'..id,key='c_base',rank=rank,nominal=nominal,suit=suit,face_down=false,debuff=false,
  ability=ability,base={id=rank,value=tostring(rank),suit=suit,nominal=nominal,face_nominal=rank>=11 and rank<=13 and .1 or 0,
    suit_nominal=suit_index,suit_nominal_original=suit_index,name='ordinary '..rank,colour={.2,.3,.4,1},original_value=tostring(rank),times_played=0}}
end end
s.jokers={joker('j_yorick','Yorick',{x_mult=1,yorick_discards=23,extra={discards=23,xmult=1}}),joker('j_perkeo','Perkeo')}
s.pack_cards={joker('j_certificate','Certificate'),joker('j_card_sharp','Card Sharp',{extra={Xmult=3}})}
local cert,sharp=copy(s),copy(s);cert.jokers[3]=copy(s.pack_cards[1]);sharp.jokers[3]=copy(s.pack_cards[2])
local ctx=Shop.new(s,Score,nil,{max_evaluations=50000});s._shop_scoring=ctx
local ce=ctx:compare(s,cert);local se=ctx:compare(s,sharp)
check(ce and se and ce.complete_finishing and se.complete_finishing,'full52 rich-metadata whole-blind families complete')
local candidates={{index=1,card=s.pack_cards[1],score=100,scoring_evidence=ce},{index=2,card=s.pack_cards[2],score=50,scoring_evidence=se}}
local before_calls=ctx.evaluations
local function nodes(v)
 if type(v)~='table'then return 1 end
 local total=1;for k,x in pairs(v)do total=total+nodes(k)+nodes(x)end;return total
end
print('Rich synthetic: forecast '..nodes(ce.before_finishing)..', selected '..nodes(ce.before_finishing.selected)..', world '..nodes(ce.before_finishing.selected.worlds[1]))
print('Certificate '..ce.after_finishing.selected.clearing_samples..' / Sharp '..se.after_finishing.selected.clearing_samples)
local old=dofile('tools/advisor_eval/runs/perkeo312_installed/policy/Brainstorm/Advisor/pack_survival.lua')
local original,old_d=old.choose(s,candidates,candidates[1],{})
check(not original and not old_d.complete and old_d.reason:find('root family',1,true),'frozen312 rejects identical aggregate rich evidence')
local chosen,d=Pack.choose(s,candidates,candidates[1],{})
check(chosen==candidates[2]and d.complete,'partitioned complete comparison admits supported full52 choice: '..tostring(d.reason))
eq(ctx.evaluations,before_calls,'new comparison adds zero scores')

check(#s.playing_cards==52,'realistic full deck rather than the previous24-card fixture')
check(nodes(ce.before_finishing)>20000 and nodes(ce.before_finishing.selected)>20000,'both aggregate boundaries are actually exercised')
for _,e in ipairs({ce,se})do for _,f in ipairs({e.before_finishing,e.after_finishing})do for _,p in ipairs(f.policies)do
 eq(#p.worlds,4,'fixed four worlds retained')
 for _,w in ipairs(p.worlds)do check(nodes(w)<20000,'each complete individual world remains within original20k limit')end
end end end
local owned_before=Snap.fingerprint(Pack.capture(s));local cards_before=Snap.fingerprint(s.pack_cards)
local function fresh()
 local ss={};for k,v in pairs(s)do if k~='_shop_scoring'then ss[k]=copy(v)end end
 ss._shop_scoring={truncated=false}
 local cc=copy(candidates);for i,c in ipairs(cc)do c.card=ss.pack_cards[i]end
 return ss,cc
end
local function reject(label,fn)
 local ss,cc=fresh();fn(ss,cc)
 local a,r=Pack.choose(ss,cc,cc[1],{})
 check(not a,label..': '..tostring(r.reason));check(type(r.reason)=='string',label..' has an explicit reason')
end
reject('selected-policy scalar metadata is not dropped',function(ss,cc)
 cc[2].scoring_evidence.after_finishing.selected.mean_score=999
end)
reject('selected-policy world4 is compared',function(ss,cc)
 cc[2].scoring_evidence.after_finishing.selected.worlds[4].endpoint_resources.population['string:physical52'].rank=3
end)
reject('selected-policy action details are compared',function(ss,cc)
 cc[2].scoring_evidence.after_finishing.selected.worlds[3].actions[1].new_field=false
end)
reject('selected-policy extra metadata is compared',function(ss,cc)
 cc[2].scoring_evidence.after_finishing.selected.opaque={supported=true}
end)
reject('before-policy second world4 is compared',function(ss,cc)
 cc[2].scoring_evidence.before_finishing.policies[2].worlds[4].endpoint_resources.population['string:physical52'].rank=3
end)
reject('before selected policy is compared separately',function(ss,cc)
 cc[2].scoring_evidence.before_finishing.selected.worlds[4].actions[1].score=123
end)
reject('before forecast metadata is compared',function(ss,cc)
 cc[2].scoring_evidence.before_finishing.reason='a different comparison'
end)
reject('all original policy metadata survives partitioning',function(ss,cc)
 cc[2].scoring_evidence.before_finishing.policies[2].mean_hands_used=123
end)
reject('unknown metadata cannot be silently discarded',function(ss,cc)
 cc[2].scoring_evidence.before_finishing.additional_fact={x=false}
end)
reject('key type remains meaningful',function(ss,cc)
 local f=cc[2].scoring_evidence.after_finishing
 f.policies[1].extra={[1]=true};f.selected.extra={['1']=true}
end)
reject('policy array cannot have a hidden extra key',function(ss,cc)
 for _,c in ipairs(cc)do c.scoring_evidence.before_finishing.policies.extra={}end
end)
reject('world array cannot have a hidden extra key',function(ss,cc)
 for _,c in ipairs(cc)do c.scoring_evidence.before_finishing.policies[2].worlds.extra={}end
end)
reject('third policy cannot bypass fixed family',function(ss,cc)
 cc[2].scoring_evidence.after_finishing.policies[3]=copy(cc[2].scoring_evidence.after_finishing.policies[1])
end)
reject('fifth world cannot bypass fixed family',function(ss,cc)
 cc[2].scoring_evidence.after_finishing.policies[2].worlds[5]=copy(cc[2].scoring_evidence.after_finishing.policies[2].worlds[1])
end)
reject('sparse world list is incomplete',function(ss,cc)cc[2].scoring_evidence.after_finishing.policies[2].worlds[2]=nil end)
reject('individual selected world still bounded at20k nodes',function(ss,cc)
 local f=cc[2].scoring_evidence.after_finishing
 f.policies[1].worlds[1].padding={};for i=1,10001 do f.policies[1].worlds[1].padding[i]=0 end
 f.selected=copy(f.policies[1])
end)
reject('individual unselected world also bounded at20k nodes',function(ss,cc)
 local w=cc[2].scoring_evidence.after_finishing.policies[2].worlds[4]
 w.padding={};for i=1,10001 do w.padding[i]=0 end
end)
reject('endpoint population is still capped at120 physical cards',function(ss,cc)
 for _,p in ipairs(cc[2].scoring_evidence.after_finishing.policies)do for _,w in ipairs(p.worlds)do
  local population=w.endpoint_resources.population
  for i=1,69 do population['extra'..i]={}end
 end end
 cc[2].scoring_evidence.after_finishing.selected=copy(cc[2].scoring_evidence.after_finishing.policies[1])
end)
reject('oversized common metadata is not unlimited',function(ss,cc)
 for _,c in ipairs(cc)do c.scoring_evidence.common_worlds.padding={};for i=1,10001 do c.scoring_evidence.common_worlds.padding[i]=0 end end
end)
reject('cyclic per-world resource receipt remains unsupported',function(ss,cc)
 local w=cc[2].scoring_evidence.after_finishing.policies[2].worlds[4];w.extra=w
end)
reject('cyclic forecast metadata remains unsupported',function(ss,cc)
 for _,c in ipairs(cc)do local f=c.scoring_evidence.before_finishing;f.extra=f end
end)
reject('functions in extra metadata remain unsupported',function(ss,cc)
 for _,c in ipairs(cc)do c.scoring_evidence.before_finishing.extra=function()error('never invoke')end end
end)
reject('metatables remain unsupported',function(ss,cc)
 for _,c in ipairs(cc)do setmetatable(c.scoring_evidence.before_finishing,{})end
end)
reject('protected metatables cannot invoke field access',function(ss,cc)
 for _,c in ipairs(cc)do c.scoring_evidence.before_finishing.extra=setmetatable({},{__metatable=false,__index=function()error('Must not invoke metadata')end})end
end)
reject('non-finite metadata remains unsupported',function(ss,cc)
 for _,c in ipairs(cc)do c.scoring_evidence.before_finishing.extra=0/0 end
end)
reject('scalar type difference does not compare equal',function(ss,cc)
 cc[2].scoring_evidence.before_finishing.samples='4'
end)
do
 local ss,cc=fresh()
 for _,c in ipairs(cc)do
  local extra={supported=false};c.scoring_evidence.before_finishing.extra_a=extra;c.scoring_evidence.before_finishing.extra_b=extra
 end
 local selected=Pack.choose(ss,cc,cc[1],{})
 check(selected==cc[2],'equal additional acyclic metadata remains supported without a whitelist shortcut')
end
for _,limit in ipairs({19999,20001})do
 local ss,cc=fresh()
 for _,c in ipairs(cc)do
  local w=c.scoring_evidence.common_worlds;local n=(limit-nodes(w)-2)/2
  check(n%1==0,'exact canonical node count for comparison boundary')
  w.padding={};for i=1,n do w.padding[i]=0 end
  eq(nodes(w),limit,'controlled per-receipt node limit')
 end
 local selected=Pack.choose(ss,cc,cc[1],{})
 check((selected==cc[2])==(limit<20000),'20k limit is preserved, not raised for the aggregate repair')
end
-- A complete comparison may legitimately preserve its existing choice. Give
-- the incumbent one synthetic clearing endpoint with strictly more Yorick
-- progress; the serialization repair must not weaken that independent guard.
do
 local ss,cc=fresh();local f=cc[1].scoring_evidence.after_finishing
 for _,p in ipairs(f.policies)do
  p.worlds[4]=copy(cc[2].scoring_evidence.after_finishing.policies[1].worlds[4])
  p.worlds[4].endpoint_resources.jokers[3]=copy(cc[1].card)
  p.worlds[4].endpoint_resources.jokers[1].ability.yorick_discards=1
  p.clearing_samples=1
 end
 f.selected=copy(f.policies[1])
 local selected,r=Pack.choose(ss,cc,cc[1],{})
 check(not selected and r.complete,'complete-but-Yorick-growth-rejected is an allowed result')
 check(r.reason:find('preserves',1,true)~=nil,'growth rejection remains resource scope, not false family incompleteness')
end
local too_rich=copy(s);too_rich._shop_scoring=nil;too_rich.playing_cards[1].ability.padding={}
for i=1,10001 do too_rich.playing_cards[1].ability.padding[i]=i end
check(Pack.capture(too_rich)==nil,'capture itself still enforces its20k resource receipt ceiling')
eq(Snap.fingerprint(Pack.capture(s)),owned_before,'all public physical resources remain unchanged')
eq(Snap.fingerprint(s.pack_cards),cards_before,'offered cards remain unchanged')
eq(ctx.evaluations,before_calls,'all structural corruption/boundary checks add zero score calls')
math.random,math.randomseed=old_random,old_seed
print('Rich pack comparison: '..checks..' checks; '..ctx.evaluations..' synthetic score calls; no captured-state evaluation')

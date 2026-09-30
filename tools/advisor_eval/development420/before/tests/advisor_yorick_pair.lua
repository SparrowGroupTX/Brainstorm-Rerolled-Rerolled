-- Manufactured complete families only. No captured state, source run or seed.
local Growth=dofile('Brainstorm/Advisor/growth.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local modules={growth=Growth,scoring=Scoring,strategy=Strategy,search=Search}
local checks=0
local function check(x,label) checks=checks+1;assert(x,label) end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function clone(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=clone(x) end;return r end
local function card(id,rank,suit,key)
  local names={c_base={'Default Base','Default','Base'},m_mult={'Mult','Enhanced','Mult Card'},
    m_bonus={'Bonus','Enhanced','Bonus Card'},m_steel={'Steel Card','Enhanced','Steel Card'}}
  key=key or 'c_base';local shape=names[key];local nominal=rank==14 and 11 or math.min(10,rank)
  return {id=id,key=key,name=shape[1],enhancement=key,rank=rank,suit=suit,nominal=nominal,debuff=false,face_down=false,
    base={id=rank,suit=suit,nominal=nominal},ability={name=shape[1],set=shape[2],effect=shape[3],
      mult=key=='m_mult' and 4 or 0,bonus=key=='m_bonus' and 30 or 0,perma_bonus=0,x_mult=1,
      h_x_mult=key=='m_steel' and 1.5 or 0,h_mult=0,h_dollars=0,p_dollars=0,t_mult=0,t_chips=0,h_size=0,d_size=0}}
end
local function joker(key,name)
  return {id=key,key=key,name=name,blueprint_compat=true,ability={name=name,set='Joker',x_mult=1,mult=0}}
end
local function state()
  local s={phase='hand',ante=3,win_ante=8,deck_key='b_zodiac',stake=8,
    blind={key='bl_big',name='Big Blind',boss=false,debuff={},chips=14000},chips=0,
    hands_left=4,hands_played=0,discards_used=1,discards_left=3,current_round={discards_left=3,discards_used=1},
    hand_size=8,hand_limit=5,dollars=14,interest_cap=25,interest_amount=1,consumeable_buffer=0,consumable_limit=2,
    hand={},deck={},playing_cards={},jokers={},consumeables={},hands={},modifiers={scaling=3},probabilities={normal=1}}
  s.hands.Flush={chips=50,mult=6,level=2,l_chips=15,l_mult=2,s_chips=35,s_mult=4,played=3,played_this_round=0}
  local ranks={14,13,11,8,3}
  for i=1,5 do s.hand[i]=card('held:'..i,ranks[i],'Hearts',i<=2 and 'm_steel' or 'm_mult') end
  for i=6,8 do s.hand[i]=card('held:'..i,i-4,'Clubs','m_mult') end
  for i=1,6 do s.deck[i]=card('deck:'..i,2+i,'Diamonds',i%2==0 and 'm_mult' or 'c_base');s.deck[i].face_down=true end
  local y=joker('j_yorick','Yorick');y.ability.x_mult=3;y.ability.yorick_discards=6;y.ability.extra={discards=23,xmult=1}
  local nova=joker('j_supernova','Supernova');nova.ability.extra=1
  local copy=joker('j_brainstorm','Brainstorm');copy.ability.eternal=true
  local droll=joker('j_droll','Droll Joker');droll.ability.type='Flush';droll.ability.t_mult=10;droll.ability.eternal=true
  s.jokers={y,nova,copy,droll,joker('j_perkeo','Perkeo')}
  s.consumeables={{id='tarot:1',key='c_empress',ability={name='The Empress',set='Tarot'},edition={negative=true,type='negative'}}}
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  return s
end
local selected={1,2,3,4,5}
local function clear(s) local p=Scoring.score(s,selected);p.indices=clone(selected);return p end
local function suggest(s,cap,known) return Growth.suggest(s,modules,known or clear(s),{max_evaluations=cap or 12}) end
local function fp(s) return Snapshot.fingerprint(s) end
-- Independent exact same-row endpoints for the copied marginal utility. The
-- production qualifier is not called here; the known manufactured row has one
-- Brainstorm resolving to the first physical Yorick.
local function copy_factor(s)
  local before=clear(s);local after=clone(s)
  local a=after.jokers[1].ability;a.x_mult=a.x_mult+a.extra.xmult
  return math.max(1,math.min(2,(clear(after).score/before.score-1)*s.jokers[1].ability.x_mult/a.extra.xmult))
end
local s=state();local original=fp(s);local known=clear(s)
check(known.legal and not known.uncertain and known.score>3300,'manufactured physical clear has margin')
local g,n,d=suggest(s);check(g and g.growth.two_discard_threshold,'two-discard threshold is qualified')
local proof=g.growth.two_discard_threshold
eq(g.action.kind,'discard','only first discard is recommended');eq(#g.action.indices,3,'first batch is three spare cards')
eq(table.concat(g.action.indices,','),'6,7,8','physical finishing cards retained')
eq(proof.first_count,3,'first count');eq(proof.second_count,3,'second count');eq(proof.total_discarded,6,'complete threshold count')
eq(proof.guaranteed_second_capacity,3,'complete finite-population capacity')
eq(proof.remaining_discards,1,'both planned discards charged');eq(proof.remaining_deck,0,'both full replacement draws charged')
eq(proof.first_cost,4,'first action cost');eq(proof.second_cost,4,'second action cost')
check(math.abs(proof.merit-(80*6/23/3*copy_factor(s)+15-8))<1e-10,'same-row copied partial utility and exact physical threshold bonus')
eq(proof.second_threshold_growth,1,'one physical Yorick increment despite Brainstorm')
eq(#proof.future_yoricks,1,'copy does not create physical growth');eq(proof.future_yoricks[1].x_mult,4,'exact terminal multiplier')
eq(proof.future_yoricks[1].discard_count,23,'exact reset countdown')
eq(g.growth.effects.yorick_growth,0,'first discard alone does not grow Yorick')
eq(g.play.score,known.score,'neutral removed cards preserve actual score before any draw')
eq(proof.future_action_dispatched,false,'no future action dispatched');check(proof.requires_fresh_observation,'fresh observation required')
eq(fp(s),original,'full input unchanged');check(n<=6 and n==d.evaluations,'existing shortlist score limit')

-- All720 orders of the six-card manufactured population. Both actual draw
-- batches and both supported discard transitions occur in every permutation.
local trajectories=0;local signatures={}
local function drawn(t,ids)
  local wanted,found={},{};for _,id in ipairs(ids) do wanted[id]=true end
  local left={}
  for _,c in ipairs(t.deck) do
    if wanted[c.id] then found[c.id]=c
    else left[#left+1]=c end
  end
  for _,id in ipairs(ids) do local c=assert(found[id]);c.face_down=false;t.hand[#t.hand+1]=c end
  t.deck=left
  for i,c in ipairs(t.playing_cards) do
    for _,h in ipairs(t.hand) do if h.id==c.id then t.playing_cards[i]=h end end
  end
end
local function permutation(order,used)
  if #order==6 then
    local signature=table.concat(order,',');check(not signatures[signature],'distinct ordered draw trajectory');signatures[signature]=true
    local first,e1=Scoring.after_discard(s,g.action.indices)
    local ids={};for i=1,3 do ids[i]='deck:'..order[i] end;drawn(first,ids)
    local before_second=Scoring.score(first,selected)
    eq(before_second.score,known.score,'any first replacement batch preserves the clear')
    local second,e2=Scoring.after_discard(first,{6,7,8})
    ids={};for i=4,6 do ids[#ids+1]='deck:'..order[i] end;drawn(second,ids)
    local scored=Scoring.score(second,selected)
    check(scored.legal and not scored.uncertain and scored.score>=g.play.score,'every completed trajectory retains certified clear floor')
    eq(second.jokers[1].ability.x_mult,proof.future_yoricks[1].x_mult,'actual count-only XMult endpoint')
    eq(second.jokers[1].ability.yorick_discards,proof.future_yoricks[1].discard_count,'actual count-only countdown endpoint')
    eq(second.dollars,proof.future_dollars,'cash endpoint');eq(second.discards_left,proof.remaining_discards,'discard endpoint')
    eq(#second.playing_cards,#s.playing_cards,'no population loss');eq(fp(second.consumeables),fp(s.consumeables),'whole Negative Perkeo inventory preserved')
    local marked={};for _,i in ipairs(g.action.indices) do marked[s.hand[i].id]=true end
    for i=1,3 do marked['deck:'..order[i]]=true end
    for _,c in ipairs(second.playing_cards) do
      eq(c.ability.discarded,marked[c.id] or nil,'only actual six physical IDs gain discarded history')
    end
    eq(e1.yorick_growth,0,'no first threshold');eq(e2.yorick_growth,1,'exact second threshold')
    trajectories=trajectories+1;return
  end
  for i=1,6 do if not used[i] then used[i]=true;order[#order+1]=i;permutation(order,used);order[#order]=nil;used[i]=nil end end
end
permutation({},{});eq(trajectories,720,'complete manufactured finite-population order family')

-- All120 physical scoring-card orders include both played canonical Steel.
local orders=0
local function selected_order(order,used)
  if #order==5 then
    local t=clone(s);for i,k in ipairs(order) do t.hand[i]=clone(s.hand[k]) end
    local p=clear(t);eq(p.score,known.score,'played Steel has no card-stage XMult under every card order')
    orders=orders+1;return
  end
  for i=1,5 do if not used[i] then used[i]=true;order[#order+1]=i;selected_order(order,used);order[#order]=nil;used[i]=nil end end
end
selected_order({},{});eq(orders,120,'complete scoring-card permutation family')

local function reject(label,change,all)
  local t=state();local p=clear(t);change(t,p)
  local ok,result,count,diag=pcall(suggest,t,12,p)
  check(ok,label..' does not throw')
  check(not result or not result.growth.two_discard_threshold,label..' declines new pair proof')
  if all then eq(result,nil,label..' declines entire growth');eq(count,0,label..' uses no scores') end
end
for _,seal in ipairs({'Blue','Gold','Purple','Red'}) do
  reject('future '..seal,function(t)t.deck[1].seal=seal end)
  reject('current spare '..seal,function(t)t.hand[6].seal=seal end)
  reject('reserved '..seal,function(t)t.hand[1].seal=seal end,true)
end
for _,area in ipairs({'deck','hand'}) do
  reject(area..' future held Steel',function(t)local i=area=='hand' and 6 or 1;t[area][i].ability.h_x_mult=1.5 end)
  reject(area..' unknown held arithmetic',function(t)local i=area=='hand' and 6 or 1;t[area][i].ability.h_mult=1 end)
end
reject('noncanonical Steel factor',function(t)t.hand[1].ability.h_x_mult=2 end,true)
reject('played Steel XMult',function(t)t.hand[1].ability.x_mult=2 end,true)
reject('Steel has custom passive field',function(t)t.hand[1].ability.mod_unknown=1 end,true)
reject('one discard left',function(t)t.discards_left=1 end)
reject('no hand remains',function(t)t.hands_left=0 end)
reject('fractional hand resource',function(t)t.hands_left=1.5 end)
reject('not selecting a hand',function(t)t.phase='shop' end)
reject('Yorick expires before future benefit',function(t)t.jokers[1].ability.perishable=true;t.jokers[1].ability.perish_tally=1 end)
reject('insufficient full second draw',function(t)table.remove(t.deck) end)
reject('hand not full',function(t)t.hand_size=9 end)
reject('discard capacity two',function(t)t.hand_limit=2 end)
reject('no threshold within two discards',function(t)t.jokers[1].ability.yorick_discards=7 end)
-- A full three-card action would cross now, but copied partial-progress value
-- can favor two cards then three instead. The selected first action must still
-- miss the threshold; the copy never adds a second physical increment.
do
  local t=state();t.jokers[1].ability.yorick_discards=3
  local result=suggest(t);local p=result and result.growth.two_discard_threshold
  check(p~=nil,'copied growth can prefer a smaller first action before the threshold')
  eq(#result.action.indices,2,'selected first discard does not cross the three-card countdown')
  eq(p.first_count,2,'selected pair starts with two cards');eq(p.second_count,3,'selected pair follows with three cards')
  eq(p.total_discarded,5,'complete selected pair charges five actual cards')
  eq(p.second_threshold_growth,1,'selected pair has exactly one physical threshold')
  eq(result.growth.effects.yorick_growth,0,'selected first action has no physical threshold')
  eq(p.future_yoricks[1].x_mult,4,'one physical multiplier increase')
  eq(p.future_yoricks[1].discard_count,21,'five cards from countdown three reset then advance twice')
  eq(p.remaining_discards,1,'selected pair spends two discard actions')
  eq(p.remaining_deck,1,'selected pair charges all five future draws')
  eq(p.first_cost,4,'smaller first action still pays a whole action cost')
  eq(p.second_cost,4,'second action pays another whole action cost')
  local single=80*3/23/3*copy_factor(t)+15-4
  local pair=80*5/23/3*copy_factor(t)+15-8
  check(pair>single,'independent copied utility explains why two then three beats immediate three')
  check(math.abs(result.merit-pair)<1e-10,'selected merit matches independent complete pair cost')
end
reject('Burnt first discard',function(t)t.jokers[5]=joker('j_burnt','Burnt Joker');t.discards_used=0 end)
reject('Burnt missing observed round count',function(t)t.jokers[5]=joker('j_burnt','Burnt Joker');t.current_round.discards_used=nil end)
for _,key in ipairs({'bl_serpent','bl_final_bell','bl_fish','bl_hook','bl_pillar','mod_blind'}) do
  reject(key..' remains outside pair scope',function(t)t.blind.key=key end)
end
for _,key in ipairs({'flipped_cards','minus_hand_size_per_X_dollar','chips_dollar_cap','mod_unknown'}) do
  reject(key..' modifier excluded',function(t)t.modifiers[key]=1 end)
end
reject('unknown deck',function(t)t.deck_key='b_modded' end)
reject('unknown voucher',function(t)t.used_vouchers={v_modded=true} end)
reject('challenge rules',function(t)t.challenge={id='c_custom'} end)
reject('whole population unknown effect',function(t)local c=card('discard:1',3,'Hearts');c.ability.h_mult=1;t.playing_cards[#t.playing_cards+1]=c end)
reject('unknown future identity',function(t)t.deck[1].unknown=true end)
reject('unknown future rank',function(t)t.deck[1].rank=nil;t.deck[1].base.id=nil end)
reject('mismatched population metadata',function(t)t.playing_cards[1]=clone(t.playing_cards[1]);t.playing_cards[1].metadata='changed' end)
reject('duplicate population ID',function(t)t.playing_cards[2].id=t.playing_cards[1].id end)
reject('unknown owned consumable',function(t)t.consumeables[1].key='c_modded' end)
reject('cash cost makes investment negative',function(t)t.modifiers.discard_cost=3 end)
reject('cannot afford both discards',function(t)t.modifiers.discard_cost=8 end)
reject('discard interest/reward cost can outweigh copied growth',function(t)t.modifiers.money_per_discard=4 end)
reject('out of bounded multiplier range',function(t)t.jokers[1].ability.x_mult=1048576 end)
reject('out of bounded countdown range',function(t)t.jokers[1].ability.yorick_discards=24 end)
reject('fractional Yorick interval',function(t)t.jokers[1].ability.extra.discards=23.5 end,true)
reject('nonfinite input',function(t)t.metadata=0/0 end,true)
reject('cyclic input',function(t)t.metadata=t end,true)
reject('metatable input',function(t)setmetatable(t,{}) end,true)
reject('callback input',function(t)t.metadata=function()end end,true)
reject('oversized string',function(t)t.metadata=string.rep('x',4097) end,true)
reject('over node budget',function(t)t.metadata={};for i=1,65536 do t.metadata[i]=true end end,true)
reject('over whole inventory bound',function(t)for i=2,65 do t.consumeables[i]={id='tarot:'..i,key='c_empress',ability={set='Tarot'}} end end,true)
reject('over whole population bound',function(t)for i=#t.playing_cards+1,257 do t.playing_cards[i]=card('excess:'..i,2,'Spades') end end,true)
reject('overdeep metadata',function(t)local v=t;for i=1,18 do v.metadata={};v=v.metadata end end,true)
reject('hybrid hand array',function(t)t.hand.extra=true end,true)
reject('sparse deck array',function(t)t.deck[2]=nil end,true)

s=state();s.modifiers.discard_cost=1;s.dollars=21
g=suggest(s);check(g and g.growth.two_discard_threshold,'small exact paid investment can remain useful')
proof=g.growth.two_discard_threshold
eq(proof.first_cost,7,'first discard cash+action cost');eq(proof.second_cost,10,'second discard loses interest at20 to19')
eq(proof.future_dollars,19,'both paid discards charged')
for _,reward in ipairs({1,3}) do
  s=state();s.modifiers.money_per_discard=reward
  g=suggest(s);check(g and g.growth.two_discard_threshold,'unused-discard reward loss can remain worthwhile')
  local p=g.growth.two_discard_threshold
  eq(p.first_cost,3*reward+4,'first forgone discard reward is fully charged')
  eq(p.second_cost,3*reward+4,'second forgone reward is fully charged')
  check(math.abs(p.merit-(80*6/23/3*copy_factor(s)+15-2*(3*reward+4)))<1e-10,
    'independent copy utility retains both exact reward/action costs')
end

-- Complete count classes are checked against independent exact discard
-- transitions for every nonempty current and next spare subset (7x7).
local subsets={}
for mask=1,7 do local indices={};for bit=0,2 do if math.floor(mask/2^bit)%2==1 then indices[#indices+1]=6+bit end end;subsets[#subsets+1]=indices end
local count_cases=0
for _,xmult in ipairs({1,3,8}) do for distance=2,9 do
  local t=state();t.jokers[1].ability.x_mult=xmult;t.jokers[1].ability.yorick_discards=distance;t.blind.chips=1
  local best_single,best_pair=-math.huge,-math.huge
  for _,first_indices in ipairs(subsets) do
    local first,e1=assert(Scoring.after_discard(t,first_indices))
    local n1=#first_indices;local u1=80*n1/23/xmult*copy_factor(t)+15*e1.yorick_growth
    best_single=math.max(best_single,u1-4)
    local ids={};for i=1,n1 do ids[i]='deck:'..i end;drawn(first,ids)
    for _,second_indices in ipairs(subsets) do
      local second,e2=assert(Scoring.after_discard(first,second_indices))
      if e1.yorick_growth==0 and e2.yorick_growth>0 then
        local u2=80*#second_indices/23/first.jokers[1].ability.x_mult*copy_factor(t)+15*e2.yorick_growth
        best_pair=math.max(best_pair,u1+u2-8)
        check(Scoring.score(second,selected).score>=Scoring.score(first,selected).score,'all qualifying physical subset endpoints preserve score floor')
      end
    end
  end
  local actual=suggest(t)
  if best_pair>math.max(0,best_single) then
    check(actual and actual.growth.two_discard_threshold,'best complete count family admits threshold opportunity')
    check(math.abs(actual.merit-best_pair)<1e-10,'candidate merit equals independent complete physical-subset comparison')
  else check(not actual or not actual.growth.two_discard_threshold,'pair does not displace a better immediate alternative') end
  count_cases=count_cases+1
end end
eq(count_cases,24,'all24 multiplier/distance count-family cases checked')

s=state();s.used_vouchers={v_observatory=true}
s.consumeables[2]={id='planet:1',key='c_jupiter',ability={set='Planet',consumeable={hand_type='Flush'}},edition={negative=true,type='negative'}}
g=suggest(s);check(g and g.growth.two_discard_threshold,'whole Negative Observatory pool remains valid')
local before_inventory=fp(s.consumeables);local held=Scoring.after_discard(s,g.action.indices)
eq(fp(held.consumeables),before_inventory,'every owned Negative card survives projected first action')
eq(g.play.score,clear(s).score,'Observatory contributes through the complete owned inventory')
s=state();s.hand[1].ability.discarded=true;s.hand[6].ability.discarded=false;s.deck[1].ability.discarded=false
g=suggest(s);check(g and g.growth.two_discard_threshold,'ordinary mixed discarded history is admitted')
held=Scoring.after_discard(s,g.action.indices)
eq(held.playing_cards[1].ability.discarded,true,'reserved true history is retained')
eq(held.playing_cards[6].ability.discarded,true,'actual first discard changes false to true')
eq(held.playing_cards[9].ability.discarded,false,'undrawn deck history remains false')

s=state();local real=Scoring.score;local calls=0;known=clear(s)
Scoring.score=function(...)calls=calls+1;return real(...)end
g,n=suggest(s,1,known);Scoring.score=real
check(g and g.growth.two_discard_threshold,'one exact score certifies the complete symbolic pair')
eq(calls,1,'one score used');eq(n,calls,'all calls reported')
g,n=suggest(s,0,known);eq(g,nil,'zero caller cap yields no action');eq(n,0,'zero caller cap preserved')
-- Fresh observations remain authoritative; the product never enqueues a second discard.
local first=Scoring.after_discard(s,{6,7,8});drawn(first,{'deck:1','deck:2','deck:3'})
g=suggest(first);check(g and g.action.kind=='discard','fresh second observation supports immediate exact threshold')
eq(g.growth.effects.yorick_growth,1,'the second actual recommendation crosses threshold')
eq(g.growth.two_discard_threshold,nil,'fresh second action needs no future-pair credit')

calls=0;Scoring.score=function(...)calls=calls+1;return real(...)end
local result=Decision.run(s,modules);Scoring.score=real
check(result.fast_clear and result.growth and result.growth.growth.two_discard_threshold,'full decision integrates the pair proof')
check(calls<=70 and result.evaluations<=70,'full decision fast-clear ceiling unchanged');eq(calls,result.evaluations,'full decision call ledger exact')
print('advisor Yorick paired threshold: '..checks..' checks passed; '..trajectories..' complete draw orders; '..count_cases..' complete count families')

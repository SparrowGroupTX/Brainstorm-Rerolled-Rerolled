-- Manufactured mechanics fixtures only. No saved/captured run, source worker or seed search.
local Growth=dofile('Brainstorm/Advisor/growth.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local modules={scoring=Scoring,strategy=Strategy,search=Search,growth=Growth}
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function clone(v) if type(v)~='table' then return v end;local r={};for k,x in pairs(v) do r[k]=clone(x) end;return r end
local function card(id,rank,suit,mult)
  return {id=id,rank=rank,suit=suit,nominal=rank==14 and 11 or math.min(rank,10),
    base={id=rank,nominal=rank==14 and 11 or math.min(rank,10)},
    key=mult and 'm_mult' or 'c_base',name=mult and 'Mult' or 'Default Base',
    enhancement=mult and 'm_mult' or 'c_base',debuff=false,
    ability={name=mult and 'Mult' or 'Default Base',set=mult and 'Enhanced' or 'Default',
      effect=mult and 'Mult Card' or 'Base',
      bonus=0,mult=mult and 4 or 0,x_mult=1,h_mult=0,h_x_mult=0,p_dollars=0,h_dollars=0,t_mult=0,t_chips=0}}
end
local function enhance(c,key)
  local names={m_bonus='Bonus',m_mult='Mult',m_steel='Steel Card',m_gold='Gold Card',m_glass='Glass Card',c_base='Default Base'}
  local effects={m_bonus='Bonus Card',m_mult='Mult Card',m_steel='Steel Card',m_gold='Gold Card',m_glass='Glass Card',c_base='Base'}
  c.key=key;c.enhancement=key;c.name=names[key];c.ability.name=c.name
  c.ability.set=key=='c_base' and 'Default' or 'Enhanced';c.ability.effect=effects[key]
  c.ability.mult=key=='m_mult' and 4 or 0;c.ability.bonus=key=='m_bonus' and 30 or 0
  c.ability.x_mult=key=='m_glass' and 2 or 1;c.ability.extra=key=='m_glass' and 4 or nil
  c.ability.h_x_mult=key=='m_steel' and 1.5 or 0;c.ability.h_dollars=key=='m_gold' and 3 or 0
end
local function joker(key,name)
  return {id=key,key=key,blueprint_compat=true,debuff=false,ability={name=name,set='Joker',mult=0,x_mult=1}}
end
local function state()
  local s={phase='hand',ante=2,win_ante=8,blind={key='bl_big',name='Big Blind',chips=5000},chips=0,
    hands_left=4,hands_played=0,discards_left=3,discards_used=0,current_round={},dollars=25,
    hand_size=8,hand_limit=5,modifiers={},jokers={joker('j_yorick','Yorick')},
    hand={},deck={},playing_cards={},hands={},consumeables={},consumable_limit=2,probabilities={normal=1}}
  s.jokers[1].ability.x_mult=2;s.jokers[1].ability.yorick_discards=23
  s.jokers[1].ability.extra={discards=23,xmult=1}
  for i=1,5 do s.hand[i]=card('hand'..i,15-i,'Hearts',true) end
  for i=6,8 do s.hand[i]=card('hand'..i,i-4,'Spades',false) end
  for i=1,10 do s.deck[i]=card('draw'..i,2+i%10,'Clubs',i%2==0) end
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  return s
end
local indices={1,2,3,4,5}
local function clear(s)
  local p=Scoring.score(s,indices);p.indices=clone(indices);return p
end
local function suggest(s,limit) return Growth.suggest(s,modules,clear(s),{max_evaluations=limit or 12}) end
local s=state();local original=Snapshot.fingerprint(s);local p=clear(s)
eq(p.score,8456,'151 chips times (8 base plus20 additive Mult) times Yorick2')
local g,n,d=suggest(s)
check(g~=nil,'ordinary additive-only cards admit a complete retained-hand comparison')
eq(g.action.kind,'discard','growth selects a supported discard')
eq(#g.action.indices,3,'keeps the five-card physical clear and discards the three spares')
eq(table.concat(g.action.indices,','),'6,7,8','only non-clearing cards discarded')
eq(g.play.score,8456,'exact retained clear needs no replacement cards')
eq(g.growth.effects.yorick_growth,0,'partial growth does not fabricate a threshold')
eq(g.growth.remaining_discards,2,'one real discard resource spent')
check(n<=12 and d.max_evaluations==12,'growth remains within original12-score cap')
eq(Snapshot.fingerprint(s),original,'input and full population untouched')
local after=Scoring.after_discard(s,g.action.indices)
eq(#after.hand,5,'exact transition has no replacement draw')
eq(#after.deck,#s.deck,'known deck remains unchanged')
eq(#after.playing_cards,#s.playing_cards,'ordinary discard conserves population')
eq(after.jokers[1].ability.yorick_discards,20,'exact physical Yorick progress')
eq(after.dollars,s.dollars,'cash preserved')
eq(Snapshot.fingerprint(after.consumeables),Snapshot.fingerprint(s.consumeables),'inventory preserved')

-- All120 permutations of the SAME retained five cards use the actual scorer.
-- Additive card operations commute; this does not assert equivalence for XMult.
local permutations=0
local function permute(order,used)
  if #order==5 then
    local changed=clone(after);for i,k in ipairs(order) do changed.hand[i]=after.hand[k] end
    local score=Scoring.score(changed,indices)
    eq(score.score,g.play.score,'all retained-card orders preserve the exact additive score')
    eq(score.hand,g.play.hand,'all retained-card orders preserve classification')
    permutations=permutations+1;return
  end
  for i=1,5 do if not used[i] then used[i]=true;order[#order+1]=i;permute(order,used);order[#order]=nil;used[i]=nil end end
end
permute({},{})
eq(permutations,120,'complete five-card permutation family')

-- A known row with two Joker-stage multipliers also remains card-order independent.
s=state();s.jokers[#s.jokers+1]=joker('j_brainstorm','Brainstorm')
s.jokers[#s.jokers+1]=joker('j_supernova','Supernova');s.jokers[#s.jokers].ability.extra=1
s.jokers[#s.jokers+1]=joker('j_droll','Droll Joker');s.jokers[#s.jokers].ability.type='Flush';s.jokers[#s.jokers].ability.t_mult=10
s.jokers[#s.jokers+1]=joker('j_perkeo','Perkeo')
check(suggest(s)~=nil,'known Brainstorm/Yorick stage multipliers do not make card additions order-sensitive')
s.jokers[2]=joker('j_blueprint','Blueprint')
check(suggest(s)~=nil,'known Blueprint route remains an additive-card order scope')
s.jokers[2]=joker('j_burnt','Burnt Joker')
s.jokers[2].ability.extra=4;s.jokers[2].ability.effect=''
check(suggest(s)~=nil,'ordinary Burnt uses existing exact first-discard transition')

local function reject(label,change)
  local t=state();change(t)
  local result,_,diag=suggest(t)
  eq(result,nil,label)
  return diag
end
for _,case in ipairs({{'Glass','m_glass'},{'Lucky','m_lucky'},{'unknown enhancement','mod_mult'}}) do
  reject(case[1]..' remains excluded',function(t)t.hand[1].enhancement=case[2] end)
end
for _,edition in ipairs({{polychrome=true},{holo=true},{mod_edition=true},{}}) do
  reject('scored edition remains outside narrow exception',function(t)t.hand[1].edition=edition end)
end
reject('scored XMult remains excluded',function(t)t.hand[1].ability.x_mult=2 end)
reject('nonstandard Mult ability remains excluded',function(t)t.hand[1].ability.mult=5 end)
reject('missing Mult mechanics remain excluded',function(t)t.hand[1].ability={} end)
reject('unknown card effect remains excluded',function(t)t.hand[1].ability.mod_effect=1 end)
reject('nonstandard card hand-size effect remains excluded',function(t)t.hand[1].ability.h_size=1 end)
reject('nonstandard Joker draw-size effect remains excluded',function(t)t.jokers[1].ability.d_size=1 end)
reject('unknown seal remains excluded',function(t)t.hand[1].seal='ModSeal' end)
reject('card metatable remains excluded',function(t)setmetatable(t.hand[1],{}) end)
reject('unknown active Joker remains excluded',function(t)t.jokers[#t.jokers+1]=joker('j_modded','Modded') end)
reject('unknown inactive Joker remains outside narrow scope',function(t)local j=joker('j_modded','Modded');j.debuff=true;t.jokers[#t.jokers+1]=j end)
reject('unknown Joker ability remains excluded',function(t)t.jokers[1].ability.mod_effect=true end)
reject('Joker edition remains excluded',function(t)t.jokers[1].edition={foil=true} end)
reject('unknown Yorick nested effect remains excluded',function(t)t.jokers[1].ability.extra.mod_growth=1 end)
for _,item in ipairs({{'j_photograph','Photograph'},{'j_hanging_chad','Hanging Chad'},{'j_blackboard','Blackboard'},
  {'j_raised_fist','Raised Fist'},{'j_shoot_the_moon','Shoot the Moon'},{'j_blue_joker','Blue Joker'}}) do
  reject(item[2]..' draw/order dependency remains excluded',function(t)t.jokers[#t.jokers+1]=joker(item[1],item[2]) end)
end
for _,item in ipairs({{'bl_final_bell','Cerulean Bell'},{'bl_fish','The Fish'},{'bl_hook','The Hook'}}) do
  reject(item[2]..' hazard remains excluded',function(t)t.blind.key=item[1];t.blind.name=item[2] end)
end
reject('randomly concealed draws remain excluded',function(t)t.modifiers.flipped_cards=1 end)
reject('unknown held arithmetic remains excluded',function(t)t.hand[8].ability.h_mult=10 end)
reject('unsupported generated Tarot remains excluded',function(t)for i=6,8 do t.hand[i].seal='Purple' end end)
reject('Blue and Gold resource values remain protected',function(t)for i=6,8 do t.hand[i].seal='Blue';enhance(t.hand[i],'m_gold') end end)
reject('paid-discard cost remains charged',function(t)t.modifiers.discard_cost=10 end)
reject('final boss has no development horizon',function(t)t.ante=8;t.blind.boss=true end)
--353 admits this previously excluded105.7% current clear, while the exact
-- retained finish still has to exceed the unchanged105% final requirement.
s=state();s.blind.chips=8000
g=suggest(s)
check(g and g.play.score==8456 and g.play.score>=s.blind.chips*1.05,
  'additive retained clear in the repaired admission band stays above final floor')
reject('below105percent score does not loosen safety',function(t)t.blind.chips=8100 end)
reject('single-step utility is unchanged',function(t)t.jokers[1].ability.x_mult=3 end)

-- The additive exception does not permit spending held finish resources.
s=state();s.jokers[1].ability.yorick_discards=1;s.hand[6].seal='Blue'
g=suggest(s)
check(g~=nil,'near-threshold growth can retain a Blue seal')
for _,i in ipairs(g.action.indices) do check(i~=6,'Blue seal remains held') end
after=Scoring.after_discard(s,g.action.indices)
check(after.hand[#after.hand].seal=='Blue','exact transition retains the physical Blue card')
eq(#after.consumeables,0,'discard never invents a Blue Planet')
s=state();s.jokers[1].ability.yorick_discards=1;enhance(s.hand[6],'m_gold')
g=suggest(s)
check(g~=nil,'near-threshold growth can retain Gold')
for _,i in ipairs(g.action.indices) do check(i~=6,'held Gold remains unspent') end

s=state();s.jokers[1].ability.x_mult=10;s.jokers[1].ability.yorick_discards=1
enhance(s.hand[6],'m_steel');s.blind.chips=55000
local before_steel=clear(s)
eq(before_steel.score,63420,'manufactured retained clear depends on held Steel')
local lost_steel=Scoring.after_discard(s,{6})
check(Scoring.score(lost_steel,indices).score<s.blind.chips,'growing Yorick does not compensate for lost Steel')
g=suggest(s)
check(g~=nil,'same-count physical alternative preserves the Steel-dependent clear')
for _,i in ipairs(g.action.indices) do check(i~=6,'selected investment retains Steel') end
after=Scoring.after_discard(s,g.action.indices)
check(Scoring.score(after,g.play.indices).score>=s.blind.chips,'retained Steel clear is exact with no draw')

s=state();local real=Scoring.score;local calls=0
local known=clear(s)
Scoring.score=function(...)calls=calls+1;return real(...) end
local capped,reported=Growth.suggest(s,modules,known,{max_evaluations=1})
Scoring.score=real
check(capped~=nil and calls==reported and calls<=1,'caller one-score cap still certifies full retained score')
local none,zero_calls=Growth.suggest(s,modules,known,{max_evaluations=0})
eq(none,nil,'zero budget cannot grant a new action');eq(zero_calls,0,'zero budget uses no scores')
local again=suggest(s)
eq(Snapshot.fingerprint(again),Snapshot.fingerprint(suggest(s)),'same manufactured input deterministically repeats')

calls=0;Scoring.score=function(...)calls=calls+1;return real(...) end
local result=Decision.run(s,modules)
Scoring.score=real
check(result.fast_clear and result.growth,'real decision integration admits additive growth after a fast clear')
eq(result.action,result.growth.action,'complete growth action becomes product recommendation')
check(calls<=70 and result.evaluations<=70,'whole fast clear remains under70 scores')
eq(calls,result.evaluations,'whole decision reports every score')

-- The new guard rejects malformed inputs BEFORE any candidate score call.
-- The prior clear here is a manufactured control, not captured-game evidence.
local function guard_reject(label,change)
  local t=state();local known=clear(t);change(t,known)
  local action,count,diag=Growth.suggest(t,modules,known,{max_evaluations=12})
  eq(action,nil,label);eq(count,0,label..' uses no scores')
  check(table.concat(diag.reasons,' '):find('sorting',1,true)~=nil,label..' fails the sorting qualification')
end
for _,field in ipairs({'bonus','perma_bonus'}) do
  for _,value in ipairs({-1,0.5,1048577,2^53,math.huge,0/0,'30'}) do
    guard_reject('selected '..field..' rejects malformed or inexact value',function(t)t.hand[1].ability[field]=value end)
  end
end
guard_reject('missing chip bonus is not source ordinary',function(t)t.hand[1].ability.bonus=nil end)
for _,field in ipairs({'chips','mult','s_chips','s_mult','l_chips','l_mult','level','played','played_this_round','order'}) do
  for _,value in ipairs({-1,0.5,1048577,math.huge,'10'}) do
    guard_reject('hand '..field..' rejects malformed or inexact value',function(t)t.hands.Flush={[field]=value} end)
  end
end
for _,value in ipairs({-1,0.5,1048577,math.huge,'2'}) do
  guard_reject('first hand level bound',function(t)t.first_used_hand_level=value end)
end
for _,value in ipairs({-1,1.5,15,2^53,'14'}) do
  guard_reject('canonical integer rank',function(t)t.hand[1].rank=value end)
  guard_reject('canonical base id',function(t)t.hand[1].base.id=value end)
end
for _,value in ipairs({-1,10.5,12,2^53,'11'}) do
  guard_reject('canonical nominal',function(t)t.hand[1].nominal=value end)
  guard_reject('canonical base nominal',function(t)t.hand[1].base.nominal=value end)
end
for _,value in ipairs({0.5,1048577,-1048577,math.huge,'25'}) do
  guard_reject('cash-cap arithmetic bound',function(t)t.modifiers.chips_dollar_cap=true;t.dollars=value end)
end
guard_reject('unknown hand definition',function(t)t.hands.ModHand={chips=10,mult=1} end)
guard_reject('malformed hand definition',function(t)t.hands.Flush=false end)
guard_reject('nonfinite supplied score',function(_,known)known.score=math.huge end)
guard_reject('fractional hand size',function(t)t.hand_size=8.5 end)
guard_reject('oversize hand size',function(t)t.hand_size=13 end)
for _,effect in ipairs({'Lucky Card','Stone Card','Mult','Mod Card'}) do
  guard_reject('contradictory scored effect '..effect,function(t)t.hand[1].ability.effect=effect end)
end
guard_reject('contradictory top-level card key',function(t)t.hand[1].key='m_lucky' end)
guard_reject('contradictory top-level card name',function(t)t.hand[1].name='Lucky Card' end)
guard_reject('contradictory scored ability name',function(t)t.hand[1].ability.name='Lucky Card' end)
guard_reject('contradictory Joker effect',function(t)t.jokers[1].ability.effect='Suit Mult' end)
guard_reject('unknown Burnt extra',function(t)local j=joker('j_burnt','Burnt Joker');j.ability.extra=5;t.jokers[2]=j end)
for _,area in ipairs({'hand','deck'}) do
  for _,value in ipairs({1.1,2,0.5,math.huge}) do
    guard_reject('noncanonical '..area..' held multiplier',function(t)t[area][#t[area]].ability.h_x_mult=value end)
  end
  guard_reject('contradictory '..area..' held effect',function(t)t[area][#t[area]].ability.effect='Steel Card' end)
  guard_reject('unknown '..area..' ability',function(t)t[area][#t[area]].ability.mod_effect=true end)
  guard_reject('nonordinary '..area..' held cash',function(t)t[area][#t[area]].ability.h_dollars=-3 end)
end
for _,field in ipairs({'chips','mult','x_mult'}) do
  for _,value in ipairs({-1,math.huge,0/0,'2'}) do
    guard_reject('nonmonotone inventory edition '..field,function(t)
      t.consumeables={{id='owned',key='c_jupiter',ability={set='Planet'},edition={[field]=value}}} end)
  end
end
guard_reject('inventory zero multiplier',function(t)t.consumeables={{edition={x_mult=0}}} end)
guard_reject('unknown inventory edition',function(t)t.consumeables={{edition={mod_effect=true}}} end)
s=state();s.used_vouchers={v_observatory=true}
s.consumeables={{id='negative_owned_planet',key='c_jupiter',ability={set='Planet',consumeable={hand_type='Flush'}},edition={negative=true}}}
g=suggest(s)
check(g~=nil,'whole Negative Observatory inventory is admitted and retained')
after=Scoring.after_discard(s,g.action.indices)
eq(Snapshot.fingerprint(after.consumeables),Snapshot.fingerprint(s.consumeables),'full Negative inventory remains unchanged')
s=state();for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do
  c.ability.discarded=true;c.ability.played_this_ante=false;c.base.times_played=3
end end
for _,c in ipairs(s.deck) do c.face_down=true end
check(suggest(s)~=nil,'ordinary deck backs and ability-level historical flags remain visible identities')
for _,c in ipairs(s.hand) do c.ability.played_this_ante=true end
check(suggest(s)~=nil,'source-recorded played-this-Ante true and base times_played remain admitted')
guard_reject('malformed discarded history',function(t)t.hand[6].ability.discarded=1 end)
guard_reject('malformed played history',function(t)t.deck[1].ability.played_this_ante='true' end)
s=state();enhance(s.hand[6],'m_glass');enhance(s.deck[1],'m_glass')
g=suggest(s);check(g~=nil,'ordinary unscored Glass extra4 is a known held identity')
eq(table.concat(g.action.indices,','),'6,7,8','unscored Glass can join the existing safe discard')
after=Scoring.after_discard(s,g.action.indices)
eq(#after.playing_cards,#s.playing_cards,'discarding ordinary Glass conserves the population')
eq(#after.deck,#s.deck,'future held Glass is not treated as played or shattered')
eq(g.play.glass_loss,0,'unscored Glass creates no scoring destruction exposure')
guard_reject('unknown held Glass extra',function(t)enhance(t.hand[6],'m_glass');t.hand[6].ability.extra=5 end)

-- Mixed additions, explicit source-normal metadata, and the numeric boundary.
-- Each case covers all120 permutations using the real scorer after the exact
-- discard transition. No replacement draw is evaluated or required.
local function mixed()
  local t=state()
  enhance(t.hand[2],'c_base');enhance(t.hand[3],'m_bonus');enhance(t.hand[5],'m_bonus')
  t.hand[1].ability.perma_bonus=17;t.hand[2].ability.perma_bonus=3;t.hand[4].ability.bonus=7
  t.hands['Straight Flush']={chips=100,mult=8,s_chips=100,s_mult=8,l_chips=40,l_mult=4,
    level=1,played=2,played_this_round=0,order=2}
  t.blind.chips=1000
  return t
end
local mixed_cases={
  {'mixed',function()return mixed() end},
  {'Arm',function()local t=mixed();t.blind={key='bl_arm',name='The Arm',boss=true,chips=1000};t.hands['Straight Flush'].level=2;return t end},
  {'Flint',function()local t=mixed();t.blind={key='bl_flint',name='The Flint',boss=true,chips=500};return t end},
  {'bounded maximum chips/levels',function()
    local t=mixed();t.hands['Straight Flush']={chips=1048576,mult=1048576,s_chips=1048576,s_mult=1048576,
      l_chips=1048576,l_mult=1048576,level=1048576,played=1048576,played_this_round=0,order=2}
    t.first_used_hand_level=1048576
    for i=1,5 do t.hand[i].ability.bonus=1048576;t.hand[i].ability.perma_bonus=1048576 end
    return t
  end},
  {'Steel Red equal factors',function()local t=mixed();enhance(t.hand[6],'m_steel');t.hand[6].seal='Red';
    enhance(t.hand[7],'m_steel');t.jokers[1].ability.yorick_discards=1;return t end}}
for _,item in ipairs(mixed_cases) do
  local t=item[2]();local action=suggest(t)
  check(action~=nil,item[1]..' permits a complete comparison')
  local transitioned=Scoring.after_discard(t,action.action.indices)
  local expected=Scoring.score(transitioned,action.play.indices)
  if item[1]=='Steel Red equal factors' then
    local swapped=clone(transitioned)
    swapped.hand[6],swapped.hand[7]=swapped.hand[7],swapped.hand[6]
    eq(Scoring.score(swapped,action.play.indices).score,expected.score,'unequal Red repetition counts still apply identical1.5 factors')
  end
  local count=0
  local function visit(order,used)
    if #order==5 then
      local changed=clone(transitioned)
      for i,k in ipairs(order) do changed.hand[action.play.indices[i]]=transitioned.hand[action.play.indices[k]] end
      local evaluated=Scoring.score(changed,action.play.indices)
      eq(evaluated.chips,expected.chips,item[1]..' identical chips for every permutation')
      eq(evaluated.mult,expected.mult,item[1]..' identical Mult for every permutation')
      eq(evaluated.score,expected.score,item[1]..' identical score for every permutation')
      count=count+1;return
    end
    for i=1,5 do if not used[i] then used[i]=true;order[#order+1]=i;visit(order,used);order[#order]=nil;used[i]=nil end end
  end
  visit({},{});eq(count,120,item[1]..' complete permutation family')
end
print('advisor additive growth: '..checks..' checks passed')

-- Manufactured public-state fixtures, not captured player/source execution.
local Phase=dofile('Brainstorm/Advisor/phase_copy.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Growth=dofile('Brainstorm/Advisor/growth.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Gold=dofile('Brainstorm/Advisor/gold_stickers.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local Ordering=dofile('Brainstorm/Advisor/ordering.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local modules={scoring=Score,growth=Growth,search=Search,strategy=Strategy,gold_stickers=Gold,ordering=Ordering,phase_copy=Phase,
  consumables=Consumables}
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function fp(s) return Snapshot.fingerprint(s) end
local function joker(key,name,a)
  a=a or {};a.name=name;a.set='Joker'
  return {id=key,key=key,name=name,ability=a,blueprint_compat=true}
end
local function card(id,rank,suit)
  return {id=id,rank=rank,nominal=rank==14 and 11 or math.min(rank,10),suit=suit or 'Spades',enhancement='c_base',ability={}}
end
local function state(bonus)
  local s={phase='hand',ante=2,blind={chips=100000,key='bl_small',name='Small Blind'},chips=0,hands_left=4,hands_played=0,
    discards_left=4,discards_used=0,current_round={},dollars=25,hand_size=8,hand_limit=5,modifiers={},
    jokers={joker('j_yorick','Yorick',{x_mult=8,yorick_discards=23,extra={discards=23,xmult=1}}),
      joker('j_brainstorm','Brainstorm'),joker('j_burnt','Burnt Joker'),joker('j_perkeo','Perkeo')},
    hand={card('a',14),card('b',2,'Hearts'),card('c',2,'Clubs'),card('d',2,'Diamonds'),card('e',5,'Hearts'),
      card('f',7),card('g',9),card('h',10)},deck={},hands={},consumeables={},probabilities={normal=1},
    consumeable_buffer=0,consumable_limit=3}
  -- A legal scalar permanent chip bonus makes only the retained Ace clear.
  -- This avoids another large clearing subset hiding the admission regression.
  s.hand[1].ability.perma_bonus=bonus or 1641
  for i=1,20 do s.deck[i]=card('d'..i,i<=12 and 2 or 6,i%2==0 and 'Hearts' or 'Spades') end
  s.playing_cards={};for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  s.hands['Three of a Kind']={level=3,chips=70,mult=6,l_chips=20,l_mult=2,played=5,visible=true}
  s.consumeables={{id='t1',key='c_hermit',ability={name='The Hermit',set='Tarot'},edition={negative=true}}}
  return s
end
local function base(s)
  local play=Score.score(s,{1});play.indices={1}
  return {kind='play',action={kind='play',area='hand',indices={1}},play=play}
end
local function call(s,cap,b) return Phase.suggest(s,modules,b or base(s),{max_evaluations=cap or 30}) end
local function decision(s)
  local old=Score.score;local calls=0
  Score.score=function(...) calls=calls+1;return old(...) end
  local result=Decision.run(s,modules,nil,{search={samples=0}})
  Score.score=old
  check(result.evaluations<=140000 and calls<=140000,'shared ordinary score ceiling holds')
  if result.fast_clear then check(result.evaluations<=70 and calls<=70,'all fast-clear and setup work stays within70') end
  eq(result.evaluations,calls,'actual score work is fully charged')
  return result,calls
end
math.random=function() error('retained Burnt setup must not access RNG') end
pseudorandom=function() error('retained Burnt setup must not access game RNG') end
local total,stage_counts=0,{}
for _,bonus in ipairs({1641,1657,1672,1687}) do
  local s=state(bonus);local before=fp(s);local known=base(s).play
  check(known.legal and not known.uncertain and known.score>=106000 and known.score<=109000,
    'manufactured known singleton lies in106-109percent band')
  local p,n,d=call(s)
  check(p and p.action.kind=='reorder_jokers' and d.complete,
    'a106-109percent retained clear admits the complete reversible Burnt-copy comparison')
  check(n<=18 and d.score_calls==n,'every admitted order/subset and Growth score fits the existing allowance')
  eq(d.events_before,1,'baseline has one physical Burnt callback')
  eq(d.events_after,2,'the actual Brainstorm arrangement gives two callbacks')
  eq(d.burnt_hand,'Three of a Kind','the copied first discard upgrades the viable rank hand')
  eq(#d.discard_indices,5,'Burnt hand is padded to a supported five-card Yorick discard')
  check(d.retained_finish.score>=105000,'unchanged exact retained-finish safety floor')
  eq(fp(s),before,'detached proposal preserves full input')
  local first,c1=decision(s);total=total+c1
  check(first.action.kind=='reorder_jokers' and first.phase_copy and first.phase_copy.complete,
    'production Decision publishes the same reversible setup')
  eq(fp(first.action),fp(p.action),'production and complete standalone setup agree')
  local prepared=Phase.reorder(s,first.action.order)
  local prepared_hash=fp(prepared)
  local second,c2=decision(prepared);total=total+c2
  check(second.action.kind=='discard' and second.phase_copy and second.phase_copy.complete,
    'fresh production advice discards rather than reversing the Burnt setup')
  eq(fp(prepared),prepared_hash,'fresh comparison preserves the prepared observation')
  local after,effects=assert(Score.after_discard(prepared,second.action.indices))
  eq(effects.burnt_hand,'Three of a Kind','actual supported discard classification')
  eq(effects.burnt_levels,2,'actual supported discard receives both Burnt levels')
  eq(effects.discarded_count,5,'only five physical cards were discarded')
  eq(after.discards_left,3,'only one discard action spent')
  eq(after.dollars,s.dollars,'setup and discard preserve cash')
  eq(#after.playing_cards,#s.playing_cards,'ordinary discard conserves physical population')
  eq(fp(after.consumeables),fp(s.consumeables),'whole Negative Perkeo inventory remains intact')
  local y;for _,j in ipairs(after.jokers) do if j.key=='j_yorick' then y=j end end
  eq(y.ability.yorick_discards,18,'copy effects do not multiply physical Yorick progress')
  eq(y.ability.x_mult,8,'no fabricated Yorick threshold')
  -- Manufactured public post-draw observation. Its order is fixed fixture data,
  -- never exposed to the earlier policy or treated as a predicted replacement.
  while #after.hand<after.hand_size do after.hand[#after.hand+1]=table.remove(after.deck,1) end
  local third,c3=decision(after);total=total+c3
  stage_counts[#stage_counts+1]=c1..'/'..c2..'/'..c3
  check(third.action.kind=='reorder_jokers','fresh post-discard production advice restores useful scoring order')
  local restored=Phase.reorder(after,third.action.order)
  local score=Score.score(restored,second.growth.play.indices)
  check(score.legal and not score.uncertain and score.score>=105000,
    'retained physical Ace still clears at the exact final safety floor after restoration')
  check(not call(after),'Burnt setup cannot repeat after the first actual discard')
  eq(fp(s),before,'the original complete input remains unchanged after every detached stage')
end
local boundary=state(1643);boundary.blind.chips=101120
local boundary_plan,_,boundary_proof=call(boundary)
check(boundary_plan and boundary_proof.complete and boundary_proof.retained_finish.score==106176,
  'exact105percent retained score is admitted and verified after the copied discard')
local s=state();s.blind.chips=101000
local rejected=call(s)
check(not rejected,'below105percent held score cannot start a copy setup')
local function reject(label,change)
  local x=state();change(x);check(not call(x),label)
end
reject('Bell replacement forcing still blocks the growth proof',function(x)x.blind.key='bl_final_bell' end)
reject('randomly concealed replacement cards remain blocked',function(x)x.modifiers.flipped_cards=4 end)
reject('unknown Purple generation stays unsupported',function(x)for _,c in ipairs(x.hand) do c.seal='Purple' end end)
reject('paid discard costs retain their development tradeoff',function(x)x.modifiers.discard_cost=100 end)
reject('unknown Joker effects cannot earn copy credit',function(x)x.jokers[#x.jokers+1]=joker('j_modded','Unknown') end)
reject('hidden physical Joker identities cannot be inspected',function(x)x.jokers[1].facing='back' end)
reject('unsettled Joker movement remains blocked',function(x)x.ordering_safe=false end)
reject('pinned row cannot invent a free arrangement',function(x)for _,j in ipairs(x.jokers) do j.pinned=true end end)
reject('last boss has no further Burnt development horizon',function(x)x.ante=8;x.blind.boss=true end)
local b=base(state());local r,n,d=call(state(),12,b)
check(not r and n==0 and not d.complete,'insufficient full-family budget scores no favorable partial prefix')
local cutoff=base(state());cutoff.fast_clear={};cutoff.evaluations=69
local unchanged=Phase.apply(state(),modules,cutoff)
eq(unchanged.action.kind,'play','exhausted fast-clear budget preserves incumbent')
eq(unchanged.evaluations,69,'fast-clear total is not expanded')
cutoff.fast_clear=nil;cutoff.evaluations=139999
unchanged=Phase.apply(state(),modules,cutoff)
eq(unchanged.action.kind,'play','exhausted ordinary budget preserves incumbent')
eq(unchanged.evaluations,139999,'ordinary total is not expanded')
check(type(Phase.concealed_order)=='function','the current concealed-order API remains present')
print('advisor_burnt_margin: '..checks..' checks passed; twelve production stages '..total..' score evaluations')
print('production stage counts (reorder/discard/restore): '..table.concat(stage_counts,', '))

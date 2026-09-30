local B=dofile('Brainstorm/Advisor/concealed_belief.lua')
local S=dofile('Brainstorm/Advisor/scoring.lua')
local D=dofile('Brainstorm/Advisor/draws.lua')
local O=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function check(v,label) checks=checks+1;assert(v,label) end
local function c(id,rank,down,suit) return {id=id,rank=rank,suit=suit or 'Spades',nominal=rank==14 and 11 or math.min(rank,10),enhancement='c_base',face_down=down,ability={}} end
local function fixture(hands,target)
  local s={phase='hand',hand={c('a',2,true),c('b',3,false),c('c',4,false)},
    deck={c('d',14,true),c('e',14,true),c('f',14,true),c('g',13,true),c('h',13,true),c('i',13,true)},playing_cards={},
    jokers={},consumeables={},hands={},hands_left=hands,discards_left=2,hand_limit=3,hand_size=3,
    blind={key='bl_house',chips=target},chips=0,dollars=20,modifiers={}}
  for _,area in ipairs({s.hand,s.deck}) do for _,card in ipairs(area) do s.playing_cards[#s.playing_cards+1]=card end end
  return s
end
local options={draws=D,sampled_outcomes=O}
local s=fixture(2,60);local frozen=Snapshot.fingerprint(s)
local r=B.run(s,S,options);local d=r.concealed_belief.continuation
check(d.complete,'actual two-hand comparison completes');eq(r.kind,'discard');eq(table.concat(r.action.indices,','),'1,2,3')
check(d.sampled_finish>d.comparisons[1].clear,'actual complete continuation improves the four-world finish estimate')
eq(d.first_discard_only,true);eq(d.horizon,2);eq(d.outer_worlds,4);eq(d.inner_worlds,4)
check(r.evaluations<=8000);check(d.observations>0);eq(Snapshot.fingerprint(s),frozen,'input not changed')
-- Hidden payloads, physical identities and deck order cannot alter any action,
-- future candidate, probability, budget use or rejection reason.
local p=Snapshot.copy(s);p.hand[1],p.deck[3]=p.deck[3],p.hand[1]
p.deck[1],p.deck[6]=p.deck[6],p.deck[1]
eq(Snapshot.fingerprint(B.run(p,S,options)),Snapshot.fingerprint(r),'full multi-hand result is invariant to latent permutation')
for _,card in ipairs(p.playing_cards) do card.id='renamed:'..card.id end
-- Hand/deck/population aliases are copied separately by Snapshot, so rename
-- every occurrence consistently, as an actual snapshot would.
for _,area in ipairs({p.hand,p.deck}) do for _,card in ipairs(area) do card.id='renamed:'..card.id end end
eq(Snapshot.fingerprint(B.run(p,S,options)),Snapshot.fingerprint(r),'physical identity spelling cannot affect the policy')
local routed=Decision.run(s,{concealed_belief=B,scoring=S,draws=D,sampled_outcomes=O,
  search={run=function()error('latent ordinary search')end},strategy={advise=function()error('latent strategy')end}})
eq(Snapshot.fingerprint(routed),Snapshot.fingerprint(r),'runtime route supplies exact continuation dependencies')
for _,hands in ipairs({1,3,4}) do
 local value=B.run(fixture(hands,60),S,options)
 check(value.concealed_belief.continuation.complete,'full '..hands..'-play horizon')
 eq(value.concealed_belief.continuation.horizon,hands);check(value.evaluations<=8000)
end
-- A hidden discard remains hidden in the original source. Its actual identity
-- cannot be subtracted from the deck. This includes fully visible held hands:
-- they still must not enter ordinary latent-deck search for later draws.
local discarded=fixture(2,60)
local unknown=c('discarded',7,true,'Hearts');unknown.ability.discarded=true
 discarded.playing_cards[#discarded.playing_cards+1]=unknown
local posterior=assert(B.observe(discarded));eq(posterior.hidden_outside_count,1)
eq(#posterior.pool,#discarded.deck+2,'held and discarded hidden slots share the unseen pool')
for i=1,16 do
 local world=assert(B.world(posterior,i));eq(#world.deck,#discarded.deck,'unknown discarded assignments remain nondrawable')
 local next_observation=assert(B.observe(world));eq(next_observation.hidden_outside_count,1,'reobserving internal outside masks retains uncertainty')
end
local swapped=Snapshot.copy(discarded)
local deck_card=swapped.deck[1];local outside=swapped.playing_cards[#swapped.playing_cards]
local outside_id=outside.id;local deck_id=deck_card.id
for _,area in ipairs({swapped.deck,swapped.playing_cards}) do for i,card in ipairs(area) do
 if card.id==deck_id then
  local value=Snapshot.copy(outside);value.id=deck_id;value.ability.discarded=nil;area[i]=value
 elseif card.id==outside_id then
  local value=Snapshot.copy(deck_card);value.id=outside_id;value.ability.discarded=true;value.face_down=true;area[i]=value
 end
end end
local original_decision=B.run(discarded,S,options)
eq(Snapshot.fingerprint(B.run(swapped,S,options)),Snapshot.fingerprint(original_decision),'unknown discarded/deck assignments cannot change any recommendation')
for _,state in ipairs({discarded,swapped}) do state.hand[1].face_down=false end
check(B.has_hidden(discarded),'visible held cards still retain unknown discarded composition')
local visible=Decision.run(discarded,{concealed_belief=B,scoring=S,draws=D,sampled_outcomes=O,
 search={run=function()error('ordinary search must not inspect hidden discarded identities')end}})
eq(Snapshot.fingerprint(visible),Snapshot.fingerprint(B.run(swapped,S,options)),'visible-hand boundary remains invariant')
eq(visible.concealed_belief.hidden_outside_count,1)
local witnessed=0
local watch=setmetatable({after_discard=function(before,indices,context)
 local after,effects=S.after_discard(before,indices,context)
 if after then
  -- The transition itself uses exposed copies; future_fill must receive the
  -- restored original masks, including hidden cards just moved to discard.
  witnessed=witnessed+1
 end
 return after,effects
end},{__index=S})
local inspected=setmetatable({fill=function(state,ordered,opts)
 local ids={};for _,a in ipairs({state.hand,state.deck}) do for _,card in ipairs(a) do ids[card.id]=true end end
 local backs=0;for _,card in ipairs(state.playing_cards) do if not ids[card.id] and card.face_down then backs=backs+1 end end
 if (state.discards_used or 0)>0 then check(backs>0,'fresh policy sees unknown discarded masks') end
 return D.fill(state,ordered,opts)
end},{__index=D})
check(B.run(fixture(2,60),watch,{draws=inspected,sampled_outcomes=O}).concealed_belief.continuation.complete);check(witnessed>0)
-- The exhaustive immediate baseline is retained when dependencies, mechanics or
-- the continuation allowance fail. Incomplete branches cannot win by omission.
local immediate=B.run(s,S)
check(not immediate.concealed_belief.continuation.complete)
local bounded=B.run(s,S,{draws=D,sampled_outcomes=O,max_evaluations=120})
eq(bounded.kind,'play');eq(Snapshot.fingerprint(bounded.action),Snapshot.fingerprint(immediate.action))
eq(bounded.evaluations,120);check(not bounded.concealed_belief.continuation.complete)
check(bounded.strategy.lines[3]:find('fallback',1,true))
local uncertain=setmetatable({after_play=function()return nil,'synthetic unsupported transition'end},{__index=S})
local stopped=B.run(s,uncertain,options)
eq(Snapshot.fingerprint(stopped.action),Snapshot.fingerprint(immediate.action));check(not stopped.concealed_belief.continuation.complete)
local long=fixture(5,60);eq(B.run(long,S,options).kind,'play');check(not B.run(long,S,options).concealed_belief.continuation.complete)
-- Holding consumables affects scoring but this route never spends them. The
-- last Perkeo source, Negative capacity and Observatory inventory remain intact.
local owned=fixture(2,60);owned.consumeables={{key='c_pluto',edition={negative=true},ability={set='Planet',name='Pluto',hand_type='High Card'}}}
owned.jokers={{key='j_perkeo',ability={name='Perkeo'}}};owned.used_vouchers={v_observatory=true};owned.consumable_limit=3
local owned_before=Snapshot.fingerprint(owned);local held=B.run(owned,S,options)
check(held.action.kind~='use');eq(Snapshot.fingerprint(owned),owned_before)
-- Public future-action families cannot inspect face-down ranks, suits, edition,
-- enhancement or ability data. Only public slot constraints remain visible.
local public=fixture(4,90);public.hand[2].face_down=true;public.hand[3].face_down=true
local changed=Snapshot.copy(public);for i,card in ipairs(changed.hand) do card.rank=14-i;card.suit='Hearts';card.enhancement='m_glass';card.ability.mult=100 end
for _,discard in ipairs({false,true}) do
 eq(Snapshot.fingerprint(B.public_candidates(public,discard)),Snapshot.fingerprint(B.public_candidates(changed,discard)))
end
public.hand[2].ability.forced_selection=true
for _,discard in ipairs({false,true}) do for _,indices in ipairs(B.public_candidates(public,discard)) do
 local found=false;for _,i in ipairs(indices) do if i==2 then found=true end end;check(found,'forced public slot retained')
end end
-- Exact discard payment and spent resources enter each transition. Scoring is
-- still called only on detached exposed internal copies, without hidden warnings.
local paid=fixture(2,60);paid.modifiers.discard_cost=4
local transitions=0
local tracking=setmetatable({after_discard=function(before,indices,context)
 local after,effects=S.after_discard(before,indices,context)
 if after then transitions=transitions+1;eq(after.dollars,before.dollars-4);eq(after.discards_left,before.discards_left-1)
   eq(#after.hand,#before.hand-#indices);eq(#after.playing_cards,#before.playing_cards)
 end
 return after,effects
end},{__index=S})
check(B.run(paid,tracking,options).concealed_belief.continuation.complete);check(transitions>0)
-- Growth and physical conservation use the existing exact transitions on each
-- admitted branch, including latent ranks that become observed when discarded.
local growth=fixture(2,100);growth.jokers={
 {key='j_yorick',ability={name='Yorick',x_mult=1,yorick_discards=1,extra={discards=23,xmult=1}}}}
local growth_count=0
local growing=setmetatable({after_discard=function(before,indices,context)
 local after,effects=S.after_discard(before,indices,context)
 if after then growth_count=growth_count+1
  eq(after.jokers[1].ability.x_mult,2,'Yorick exact threshold')
  eq(after.jokers[1].ability.yorick_discards,24-#indices,'Yorick per-card progress')
 end
 return after,effects
end},{__index=S})
check(B.run(growth,growing,options).concealed_belief.continuation.complete);check(growth_count>0)
local fragile=fixture(3,180);fragile.hand[1].enhancement='m_glass';fragile.modifiers.debuff_played_cards=true
local glass_count=0
local physical=setmetatable({after_play=function(before,indices,context)
 local after,effects,result=S.after_play(before,indices,context)
 if after then glass_count=glass_count+1
  eq(#after.playing_cards,#before.playing_cards+effects.population_delta,'exact finite population')
  local gone={};for _,card in ipairs(effects.destroyed_cards) do gone[card.id]=true end
  local ids={};for _,area in ipairs({after.hand,after.deck}) do for _,card in ipairs(area) do
   check(not gone[card.id],'shattered card never returns');check(not ids[card.id],'physical copies remain unique');ids[card.id]=true
  end end
 end
 return after,effects,result
end},{__index=S})
check(B.run(fragile,physical,options).concealed_belief.continuation.complete);check(glass_count>0)
-- Random expected income is not exact future liquidity. In particular Luxury
-- Tax can alter draw counts without Bull or Bootstraps marking score uncertain.
for _,name in ipairs({'Business Card','Reserved Parking'}) do
 local cash=fixture(2,60);cash.dollars=19;cash.modifiers.minus_hand_size_per_X_dollar=5
 cash.jokers={{key='j_blueprint',ability={name='Blueprint'}},{ability={name=name,extra=2}}}
 local calls=0;local guard=setmetatable({after_play=function()calls=calls+1;error('random cash cannot enter exact transition')end},{__index=S})
 local value=B.run(cash,guard,options)
 eq(value.kind,'play');eq(calls,0);check(not value.concealed_belief.continuation.complete)
 check(value.concealed_belief.continuation.reason:find('random income',1,true))
 cash.jokers[2].debuff=true
 check(B.run(cash,S,options).concealed_belief.continuation.complete,'inactive copy target has no random income')
end
-- Identity-dependent discard callbacks expose public constraints that the
-- visibility-only posterior does not reconstruct. Never combine their actual
-- outcomes with independently reassigned hidden discarded identities.
for _,entry in ipairs({{'j_burnt','Burnt Joker'},{'j_mail','Mail-In Rebate'},
 {'j_faceless','Faceless Joker'},{'j_castle','Castle'},{'j_hit_the_road','Hit the Road'}}) do
 local signal=fixture(2,60);signal.jokers={{key=entry[1],ability={name=entry[2],x_mult=1,extra={chips=0,chip_mod=3}}}}
 local value=B.run(signal,S,options)
 eq(value.kind,'play');check(not value.concealed_belief.continuation.complete)
 check(value.concealed_belief.continuation.reason:find('observation history',1,true))
 signal.playing_cards[#signal.playing_cards+1]=c('unseen-outside',8,true)
 value=B.run(signal,S,options);eq(value.kind,'unsupported');eq(value.action,nil);eq(value.evaluations,0)
 signal.hand[1].face_down=false;signal.jokers[1].debuff=true
 value=B.run(signal,S,options);eq(value.kind,'unsupported','a current debuff does not erase unknown prior signals')
end
-- All retained hidden cards stay concealed through exact replacements. House
-- replacements after the first discard are visible, even when deck payloads had
-- synthetic face_down=false before entering the detached draw wrapper.
local fill=fixture(2,60);fill.hand={fill.hand[1]};fill.discards_used=1;fill.hand_size=3
for _,card in ipairs(fill.deck) do card.face_down=false end
local drawn=assert(B.future_fill(fill,S,D,O,19,1))
eq(drawn.hand[1].face_down,true);eq(drawn.hand[2].face_down,false);eq(drawn.hand[3].face_down,false)
eq(#drawn.hand+#drawn.deck,#fill.hand+#fill.deck)
local mark=Snapshot.copy(fill);mark.blind={key='bl_mark',chips=60};mark.modifiers.flipped_cards=2
local mark_draw=assert(B.future_fill(mark,S,D,O,19,1))
eq(mark_draw.hand[1].face_down,true)
for i=2,#mark_draw.hand do local card=mark_draw.hand[i];local face=card.rank>=11 and card.rank<=13
 eq(card.face_down,face or O.roll(19,1,'challenge-visibility',card.id)<.5,'Mark and independent challenge flips')
end
-- Same private streams on repeated calls; never advance global/game RNG.
math.randomseed(7003);local expected=math.random();math.randomseed(7003);B.run(s,S,options);eq(math.random(),expected)
eq(Snapshot.fingerprint(B.run(s,S,options)),Snapshot.fingerprint(r),'deterministic repeated decision')
print('concealed continuation: '..checks..' checks passed')

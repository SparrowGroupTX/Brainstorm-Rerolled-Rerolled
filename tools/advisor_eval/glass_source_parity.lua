local scoring=dofile('Brainstorm/Advisor/scoring.lua')
local copy=dofile('Brainstorm/Advisor/snapshot.lua').copy
local checks,cases=0,0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(id,r,e) return {id=id,rank=r,suit='Spades',enhancement=e or 'm_glass',ability={extra=4}} end
local function joker(n,a) a=a or {};a.name=n;a.set='Joker';return {name=n,ability=a,blueprint_compat=true} end
local function snap(normal)
  local s={hand={card('king',13),card('low',2),card('held',3)},deck={card('draw',7)},hands={},hands_left=3,hands_played=1,
    dollars=10,current_round={hands_played=1},probabilities={normal=normal or 4},jokers={
      joker('Glass Joker',{x_mult=1,extra=0.75}),joker('Caino',{caino_xmult=1,extra=1}),
      joker('Blueprint'),joker('Caino',{caino_xmult=2,extra=2}),joker('Brainstorm')}}
  s.playing_cards=copy(s.hand);s.playing_cards[#s.playing_cards+1]=copy(s.deck[1]);return s
end
local queue={}
local noop=function() end
Event=function(e) return e end
highlight_card=noop;card_eval_status_text=noop;localize=function() return 'test' end
eval_card=function(card,context) return card:calculate_joker(context) end
local function parity(s,selected,label,rolls)
  cases=cases+1
  local context={glass_outcomes={}}
  local transition={};local score=scoring.score(s,selected,transition)
  for k,x in ipairs(score.glass_exposure) do context.glass_outcomes[x.index]=(rolls and rolls[k] or 0.99)<x.probability end
  local actual,metadata=assert(scoring.after_play(s,selected,context))
  queue={}
  G={C={BLUE={},RED={}},GAME={probabilities=copy(s.probabilities),current_round=copy(s.current_round)},
    E_MANAGER={add_event=function(_,e) queue[#queue+1]=e end},jokers={cards=copy(s.jokers)},consumeables={cards={}},play={cards={}},playing_cards={}}
  local byid={}
  for _,c in ipairs(copy(s.playing_cards)) do
    c.base={id=c.rank};c.ability.name=c.enhancement=='m_glass' and 'Glass Card' or 'Default Base';c.ability.effect=c.ability.name
    setmetatable(c,{__index=Card});G.playing_cards[#G.playing_cards+1]=c;byid[c.id]=c
  end
  for _,i in ipairs(selected) do G.play.cards[#G.play.cards+1]=byid[s.hand[i].id] end
  for _,j in ipairs(G.jokers.cards) do setmetatable(j,{__index=Card}) end
  local scoring_hand={}
  -- This is specifically post-scoring destruction parity; card enhancement
  -- changes and the classifier are verified by their separate model fixtures.
  for _,i in ipairs(score.scoring_indices) do
    local c=byid[s.hand[i].id];local updated=transition.cards[i]
    c.debuff=updated.debuff;c.enhancement=updated.enhancement
    c.ability.name=updated.enhancement=='m_glass' and 'Glass Card' or 'Default Base';c.ability.effect=c.ability.name
    scoring_hand[#scoring_hand+1]=c
  end
  local rolled=0
  pseudorandom=function(key) assert(key=='glass');rolled=rolled+1;return rolls and rolls[rolled] or 0.99 end
  local destroyed=source_destroy(scoring_hand)
  local n=1;while queue[n] do assert(n<100,'event bound');if queue[n].func then queue[n].func() end;n=n+1 end
  for _,c in ipairs(destroyed) do source_population_remove(c) end
  eq(#metadata.destroyed_cards,#destroyed,label..' destroyed count')
  eq(#actual.playing_cards,#G.playing_cards,label..' population count')
  for i,c in ipairs(G.playing_cards) do eq(actual.playing_cards[i].id,c.id,label..' population identity '..i) end
  for i,j in ipairs(G.jokers.cards) do
    for _,field in ipairs({'x_mult','caino_xmult'}) do eq(actual.jokers[i].ability[field],j.ability[field],label..' joker '..i..' '..field) end
  end
  eq(rolled,#score.glass_exposure,label..' one roll per exposed Glass')
end
local s=snap();parity(s,{1,2},'certain selected and unscored')
s.jokers[#s.jokers+1]=joker('Splash');parity(s,{1,2},'Splash both break')
s=snap();s.jokers[#s.jokers+1]=joker('Pareidolia');parity(s,{2},'Pareidolia low counts as face')
s.jokers[#s.jokers].debuff=true;parity(s,{2},'debuffed Pareidolia')
s=snap();s.jokers[1].debuff=true;s.jokers[2].debuff=true;parity(s,{1},'debuffed destruction jokers')
s=snap();s.hand[1].debuff=true;parity(s,{1},'debuffed Glass does not roll')
s=snap(0);parity(s,{1},'zero probability')
s=snap(1);parity(s,{1},'sampled survivor',{0.9});parity(s,{1},'sampled break',{0.1})
s=snap(2);s.hand[1].ability.extra=2;s.playing_cards[1].ability.extra=2;parity(s,{1},'live odds certainty')
s=snap(4);s.hand[1].ability.extra=8;s.playing_cards[1].ability.extra=8;parity(s,{1},'live odds stochastic survivor',{0.8})
s=snap();s.modifiers={debuff_played_cards=true};parity(s,{1},'Double or Nothing callback before debuff')
print('Glass source parity: '..cases..' cases, '..checks..' checks passed (post-scoring boundary only; no run-win estimate)')

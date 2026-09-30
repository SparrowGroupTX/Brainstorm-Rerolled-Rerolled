-- Appended after unmodified installed-source functions by the Python wrapper.
local scoring=dofile('Brainstorm/Advisor/scoring.lua')
local checks,cases=0,0
local function eq(a,b,label) checks=checks+1; assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function clone(value)
  if type(value)~='table' then return value end
  local t={}; for k,v in pairs(value) do t[k]=clone(v) end; return t
end
local defaults={['High Card']={5,1,10,1},Pair={10,2,15,1},['Two Pair']={20,2,20,1},
  ['Three of a Kind']={30,3,20,2},Straight={30,4,30,3},Flush={35,4,15,2},['Full House']={40,4,25,2},
  ['Four of a Kind']={60,7,30,3},['Straight Flush']={100,8,40,4},['Five of a Kind']={120,12,35,3},
  ['Flush House']={140,14,40,4},['Flush Five']={160,16,50,3}}
local function card(rank,suit,enhancement)
  return {rank=rank,suit=suit or 'Spades',enhancement=enhancement or 'c_base',ability={}}
end
local function joker(name,ability)
  ability=ability or {}; ability.name=name; ability.set='Joker'
  return {name=name,ability=ability,blueprint_compat=true}
end
local function snap(cards,jokers)
  local s={hand=cards,jokers=jokers,playing_cards=cards,deck={},hands={},hand_size=8,
    dollars=20,discards_left=3,discards_used=0,current_round={},modifiers={}}
  for name,d in pairs(defaults) do s.hands[name]={level=1,s_chips=d[1],s_mult=d[2],chips=d[1],mult=d[2],l_chips=d[3],l_mult=d[4],played=0,played_this_round=0} end
  return s
end
local function yorick(left,threshold,gain)
  return joker('Yorick',{x_mult=1,yorick_discards=left,extra={discards=threshold or 23,xmult=gain or 1}})
end
local queue={}
Event=function(e) return e end
local noop=function() end
localize=function() return 'test' end
card_eval_status_text=noop;update_hand_text=noop;play_sound=noop;delay=noop;check_for_unlock=noop
stop_use=noop;inc_career_stat=noop
ease_dollars=function(amount) G.GAME.dollars=G.GAME.dollars+amount end
ease_discard=function(amount) G.GAME.current_round.discards_left=G.GAME.current_round.discards_left+amount end
local function remove_card(area,card)
  for i,c in ipairs(area.cards) do if c==card then table.remove(area.cards,i);return end end
end
draw_card=function(from,to,_,_,_,card)
  remove_card(from,card); to.cards[#to.cards+1]=card
end
local function setup(s,selected)
  local funcs=G.FUNCS
  G={FUNCS=funcs,C={FILTER={},CHIPS={},MONEY={},RED={},BLUE={}},CONTROLLER={interrupt={},focused={},save_cardarea_focus=noop},
    E_MANAGER={add_event=function(_,e) queue[#queue+1]=e end},STATES={DRAW_TO_HAND=1},
    GAME={hands=clone(s.hands),dollars=s.dollars,current_round=clone(s.current_round),modifiers=clone(s.modifiers),
      round_scores={cards_discarded={amt=0}}},consumeables={cards={}},play={cards={}},discard={cards={},config={card_limit=52}}}
  G.GAME.current_round.discards_used=s.discards_used;G.GAME.current_round.discards_left=s.discards_left
  G.hand={cards=clone(s.hand),highlighted={}};G.playing_cards=G.hand.cards
  G.jokers={cards=clone(s.jokers),remove_card=remove_card}
  for i,c in ipairs(G.hand.cards) do
    local effects={m_stone='Stone Card',m_wild='Wild Card',m_glass='Glass Card'}
    c.ability.name=effects[c.enhancement] or 'Default Base';c.ability.effect=c.ability.name
    c.base={id=c.rank,suit=c.suit,nominal=c.rank==14 and 11 or math.min(c.rank,10),suit_nominal=0,face_nominal=0}
    c.unique_val=i;c.T={x=i};c.calculate_seal=noop
    setmetatable(c,{__index=Card})
  end
  for _,i in ipairs(selected) do G.hand.highlighted[#G.hand.highlighted+1]=G.hand.cards[i] end
  for _,j in ipairs(G.jokers.cards) do
    j.T={};j.states={drag={}};j.children={center={pinch={}}};j.juice_up=noop;j.remove=function(self) self.removed=true end
    setmetatable(j,{__index=Card})
  end
  queue={}
end
local function parity(s,selected,label,context)
  cases=cases+1
  local actual,metadata=assert(scoring.after_discard(s,selected,context))
  setup(s,selected)
  G.FUNCS.discard_cards_from_highlighted(nil,context and context.hook)
  local next_event=1
  while queue[next_event] do
    assert(next_event<200,'event test bound exceeded')
    local e=queue[next_event];next_event=next_event+1
    if e.func then e.func() end
  end
  eq(actual.discards_left,G.GAME.current_round.discards_left,label..' discard resource')
  eq(actual.discards_used,G.GAME.current_round.discards_used,label..' discard used')
  eq(actual.dollars,G.GAME.dollars,label..' dollars')
  eq(#actual.hand,#G.hand.cards,label..' remaining hand')
  eq(#actual.jokers,#G.jokers.cards,label..' remaining jokers')
  for hand,h in pairs(G.GAME.hands) do
    for _,field in ipairs({'level','chips','mult','played','played_this_round'}) do
      eq(actual.hands[hand][field],h[field],label..' '..hand..' '..field)
    end
  end
  for i,j in ipairs(G.jokers.cards) do
    for _,field in ipairs({'yorick_discards','x_mult','mult'}) do eq(actual.jokers[i].ability[field],j.ability[field],label..' '..j.name..' '..field) end
    if type(j.ability.extra)=='table' then eq(actual.jokers[i].ability.extra.chips,j.ability.extra.chips,label..' '..j.name..' chips') end
  end
  return actual,metadata
end

local s=snap({card(2),card(14)},{joker('Blueprint'),yorick(1)})
local t=parity(s,{1},'Yorick threshold copied scoring')
eq(scoring.score(s,{2}).score,16,'source-verified losing original score')
eq(scoring.score(t,{1}).score,64,'source-verified growth clears 30')
s=snap({card(2),card(3),card(4),card(5),card(6)},{joker('Blueprint'),yorick(1,2,0.5),joker('Brainstorm')})
s.hand[1].debuff=true
parity(s,{5,3,1,4,2},'Yorick multiple thresholds and debuffed card')
s.jokers[2].debuff=true
parity(s,{1,2,3},'debuffed Yorick')
s.jokers[2].debuff=false;s.modifiers.discard_cost=2
parity(s,{1,2},'Hook Yorick grows without paid discard',{hook=true})
s=snap({card(7),card(7,'Hearts'),card(7,'Clubs'),card(2),card(2,'Hearts')},
  {joker('Blueprint'),joker('Burnt Joker'),joker('Brainstorm')})
parity(s,{5,4,3,2,1},'Burnt Full House copied chain')
s.discards_used=1
parity(s,{1,2},'Burnt second discard')
s.discards_used=0
parity(s,{1,2},'Burnt Hook',{hook=true})
s.jokers[2].debuff=true
parity(s,{1,2},'debuffed Burnt')
s.jokers[2].debuff=false;s.jokers[1].debuff=true
parity(s,{1,2},'debuffed copy intermediate')
s.jokers={joker('Blueprint'),joker('Brainstorm')}
parity(s,{1,2},'copy cycle')
s.jokers={joker('Burnt Joker')};s.hand={card(10),card(11),card(12),card(13),card(14)}
parity(s,{1,2,3,4,5},'Royal category')
s.jokers={joker('Burnt Joker'),joker('Four Fingers')};s.hand={card(2),card(3),card(4),card(5,'Hearts'),card(10)}
parity(s,{1,2,3,4,5},'Four Fingers actual category')
s=snap({card(11),card(11,'Hearts'),card(12)}, {joker('Blueprint'),joker('Green Joker',{mult=5,extra={discard_sub=2}}),joker('Ramen',{x_mult=1.015,extra=0.01})})
s.modifiers.discard_cost=2
parity(s,{1,2},'Green once and Ramen expiry')
s=snap({card(11,'Hearts'),card(11,'Diamonds'),card(12,'Hearts')},
  {joker('Blueprint'),joker('Mail-In Rebate',{extra=5}),joker('Castle',{extra={chips=0,chip_mod=3}}),
    joker('Hit the Road',{x_mult=1,extra=0.5}),joker('Faceless Joker',{extra={faces=3,dollars=5}}),joker('Smeared Joker')})
s.current_round={mail_card={id=11},castle_card={suit='Hearts'}}
parity(s,{1,2,3},'Mail Castle Hit Road Faceless')
s.hand[2].debuff=true
parity(s,{1,2,3},'per-card debuff guards')
s.jokers={joker('Blueprint'),joker('Faceless Joker',{extra={faces=2,dollars=7}}),joker('Pareidolia')}
parity(s,{1,3},'copied Faceless and Pareidolia')
print('discard source parity: '..cases..' cases, '..checks..' checks passed (function-level source parity; no run-win estimate)')

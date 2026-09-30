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
      consumeable_buffer=s.consumeable_buffer or 0,round_scores={cards_discarded={amt=0}}},consumeables={cards=clone(s.consumeables or {}),config={card_limit=s.consumable_limit or 2}},play={cards={}},discard={cards={},config={card_limit=52}}}
  G.GAME.current_round.discards_used=s.discards_used;G.GAME.current_round.discards_left=s.discards_left
  G.hand={cards=clone(s.hand),highlighted={}};G.playing_cards={}
  for _,c in ipairs(G.hand.cards) do G.playing_cards[#G.playing_cards+1]=c end
  G.jokers={cards=clone(s.jokers),remove_card=remove_card}
  for i,c in ipairs(G.hand.cards) do
    local effects={m_stone='Stone Card',m_wild='Wild Card',m_glass='Glass Card'}
    c.ability.name=effects[c.enhancement] or 'Default Base';c.ability.effect=c.ability.name
    c.base={id=c.rank,suit=c.suit,nominal=c.rank==14 and 11 or math.min(c.rank,10),suit_nominal=0,face_nominal=0}
    c.id=i;c.unique_val=i;c.T={x=i}
    c.start_dissolve=function(self) self.to_remove=true end
    c.shatter=function(self) self.shattered=true;self.to_remove=true end
    setmetatable(c,{__index=Card})
  end
  for _,i in ipairs(selected) do G.hand.highlighted[#G.hand.highlighted+1]=G.hand.cards[i] end
  for _,j in ipairs(G.jokers.cards) do
    j.T={};j.states={drag={}};j.children={center={pinch={}}};j.juice_up=noop;j.remove=function(self) self.removed=true end
    setmetatable(j,{__index=Card})
  end
  queue={}
end

local function parity_hook(s,selected,rolled,label,generated)
 cases=cases+1
 for i,c in ipairs(s.hand) do c.id=i end
 local predicted,remapped,metadata=assert(scoring.prepare_play(s,selected,{hook_indices=rolled,generated_consumables=generated}))
 setup(s,{})
 local selected_cards={};for _,i in ipairs(selected) do selected_cards[#selected_cards+1]=G.hand.cards[i] end
 for _,c in ipairs(selected_cards) do draw_card(G.hand,G.play,nil,nil,nil,c) end
 G.hand.add_to_highlighted=function(area,c) area.highlighted[#area.highlighted+1]=c end
 G.consumeables.emplace=function(area,c) area.cards[#area.cards+1]=c end
 eval_card=function(c,context) return c:calculate_joker(context) end
 local generated_order={};for _,i in ipairs(rolled) do if generated and generated[i] then generated_order[#generated_order+1]=i end end
 table.sort(generated_order)
 local generated_count=0
 create_card=function(set,area)
  eq(set,'Tarot',label..' generation set');generated_count=generated_count+1
  local card=clone(assert(generated[generated_order[generated_count]]));card.add_to_deck=noop;return card
 end
 local rng=0
 pseudoseed=function(key) return key end
 pseudorandom_element=function(cards,key)
  eq(key,'hook',label..' source RNG key');rng=rng+1
  for i,c in ipairs(cards) do if c.id==rolled[rng] then return c,i end end
  error('specified Hook outcome absent')
 end
 local blind=setmetatable({name='The Hook'},{__index=Blind})
 blind:press_play()
 local event=1;while queue[event] do assert(event<150,'bounded Hook events');if queue[event].func then queue[event].func() end;event=event+1 end
 local held={};for _,c in ipairs(G.hand.cards) do if not c.to_remove then held[#held+1]=c end end
 local population={};for _,c in ipairs(G.playing_cards) do if not c.to_remove then population[#population+1]=c end end
 local played={};for _,i in ipairs(remapped) do played[i]=true end
 local predicted_held={};for i,c in ipairs(predicted.hand) do if not played[i] then predicted_held[#predicted_held+1]=c end end
 eq(#predicted_held,#held,label..' remaining held count');eq(#predicted.playing_cards,#population,label..' population')
 for i,c in ipairs(held) do eq(predicted_held[i].id,c.id,label..' held identity') end
 eq(predicted.dollars,G.GAME.dollars,label..' dollars');eq(predicted.discards_left,G.GAME.current_round.discards_left,label..' discards')
 eq(predicted.discards_used,G.GAME.current_round.discards_used,label..' discards used')
 eq(#(predicted.consumeables or {}),#G.consumeables.cards,label..' inventory')
 for i,c in ipairs(G.consumeables.cards) do eq(predicted.consumeables[i].key,c.key,label..' generated identity') end
 for i,j in ipairs(G.jokers.cards) do for _,field in ipairs({'x_mult','caino_xmult','yorick_discards','mult'}) do eq(predicted.jokers[i].ability[field],j.ability[field],label..' '..j.name..' '..field) end end
end
local s=snap({card(13),card(11),card(2),card(3),card(5)},{joker('Yorick',{x_mult=1,yorick_discards=2,extra={discards=23,xmult=1}}),joker('Burnt Joker')})
s.blind={key='bl_hook'}
parity_hook(s,{1},{2,4},'Hook growth and unspent Burnt')
s.jokers={joker('Trading Card',{extra=3}),joker('Caino',{caino_xmult=1,extra=1}),joker('Glass Joker',{x_mult=1,extra=0.75})}
s.hand={card(13),card(11,'Spades','m_glass')};s.playing_cards=s.hand
parity_hook(s,{1},{2},'one held card Trading removal')
s.hand={card(13)};s.playing_cards=s.hand
parity_hook(s,{1},{},'zero held cards')
s.hand={card(13),card(2),card(3),card(4)};s.playing_cards=s.hand;s.jokers={};s.hand[2].seal='Purple';s.hand[3].seal='Purple'
local outcomes={[2]={key='c_death',ability={set='Tarot'}},[3]={key='c_strength',ability={set='Tarot'}}}
parity_hook(s,{1},{3,2},'Purple explicit Tarot identities',outcomes)
s.consumable_limit=1
parity_hook(s,{1},{3,2},'Purple capacity follows sorted discard order',outcomes)
s.consumeables={{key='c_fool',ability={set='Tarot'}}}
parity_hook(s,{1},{3,2},'full inventory suppresses Purple')
s.consumeables={};s.hand[2].debuff=true
parity_hook(s,{1},{3,2},'debuffed Purple suppressed',{[3]=outcomes[3]})
print('Hook/Purple source parity: '..cases..' cases / '..checks..' comparisons passed')

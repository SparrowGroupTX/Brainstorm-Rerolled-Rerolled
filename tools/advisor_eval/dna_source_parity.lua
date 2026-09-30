local S=dofile('Brainstorm/Advisor/scoring.lua')
local checks,cases=0,0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function clone(v) if type(v)~='table' then return v end;local t={};for k,x in pairs(v) do t[k]=clone(x) end;return t end
local noop=function() end
local queue={}
Event=function(e) return e end
stop_use=noop;set_consumeable_usage=noop;update_hand_text=noop;play_sound=noop;delay=noop;card_eval_status_text=noop
localize=function() return 'test' end;check_for_unlock=noop
copy_table=clone
local function remove(area,c) for i,v in ipairs(area.cards) do if v==c then table.remove(area.cards,i);return end end end
local function card(id,r,e,debuff)
 local n=({m_stone='Stone Card',m_glass='Glass Card',m_steel='Steel Card'})[e] or 'Default Base'
 return {id=id,rank=r,nominal=math.min(r,10),suit='Spades',enhancement=e or 'c_base',debuff=debuff,
  ability={name=n,effect=n},base={id=r,nominal=math.min(r,10),suit='Spades'}}
end
local function joker(key,n,a,debuff) a=a or {};a.name=n;a.set='Joker';return {key=key,name=n,ability=a,debuff=debuff} end
Card.set_ability=function(self,center) self.config.center=center;self.ability=clone(center.config or {});self.ability.name=center.name end
Card.set_edition=function(self,edition) self.edition=next(edition or {}) and clone(edition) or nil end
Card.set_cost=noop;Card.set_sprites=noop;Card.juice_up=noop;Card.add_to_deck=noop;Card.start_materialize=noop
setmetatable(Card,{__call=function(_,x,y,_,_,_,center,params)
 return setmetatable({T={x=x,y=y},config={center=center},ability={},base={},states={},playing_card=params.playing_card},{__index=Card})
end})

card_eval_status_text=function(_,_,_,_,_,effect) if effect and effect.playing_cards_created then playing_card_joker_effects(effect.playing_cards_created) end end
local function parity(source,jokers,label)
 cases=cases+1
 source.base.times_played=9;source.base.original_value='Queen';source.base.suit_nominal_original=0.123;source.ability.perma_bonus=17
 local cards={source,card('other',2)}
 local s={hand=cards,playing_cards=cards,jokers=jokers,hands_left=4,hands_played=0}
 local predicted,meta=assert(S.after_play(s,{1}))
 queue={}
 G={CARD_W=1,CARD_H=1,P_CARDS={},P_CENTERS={c_base={}},C={FILTER={},CHIPS={},MULT={},RED={},SUITS={Spades={}}},CONTROLLER={locks={}},
  E_MANAGER={add_event=function(_,e) queue[#queue+1]=e end},GAME={current_round={hands_played=0},blind={debuff_card=noop}},
  hand={cards={},highlighted={}},play={cards={}},deck={config={card_limit=52}},playing_card=2,
  jokers={cards=clone(jokers)},consumeables={cards={}}}
 G.hand.emplace=function(area,c) area.cards[#area.cards+1]=c end
 G.playing_cards={}
 for i,c in ipairs(clone(cards)) do
  c.T={x=i,y=0};c.unique_val=i;c.playing_card=i
  local value=({[11]='Jack',[12]='Queen',[13]='King',[14]='Ace'})[c.rank] or tostring(c.rank)
  c.config={center={name=c.ability.name,config={}},card={name=value..' of Spades',suit='Spades',value=value}}
  setmetatable(c,{__index=Card});G.playing_cards[i]=c
  if i==1 then c.base.times_played=c.base.times_played+1;c.ability.played_this_ante=true;G.play.cards[1]=c
  else G.hand.cards[#G.hand.cards+1]=c end
 end
 for _,j in ipairs(G.jokers.cards) do setmetatable(j,{__index=Card}) end
 for _,j in ipairs(G.jokers.cards) do
  local effect=j:calculate_joker({cardarea=G.jokers,full_hand=G.play.cards,scoring_hand=G.play.cards,scoring_name='High Card',poker_hands={},before=true})
  if effect then card_eval_status_text(j,'jokers',nil,nil,nil,effect) end
 end
 local event=1;while queue[event] do assert(event<100,'bounded DNA events');local e=queue[event];event=event+1;if e.func then e.func() end end
 eq(#predicted.hand,#G.hand.cards,label..' hand count');eq(#predicted.playing_cards,#G.playing_cards,label..' full count')
 for i=2,#G.hand.cards do local c=G.hand.cards[i];local pc=predicted.hand[i]
  eq(pc.rank,c.base.id,label..' rank');eq(pc.seal,c.seal,label..' seal')
  eq(pc.debuff,c.debuff,label..' debuff');eq(pc.base.times_played,c.base.times_played,label..' played history')
  eq(pc.base.original_value,c.base.original_value,label..' original rank metadata')
  eq(pc.base.suit_nominal_original,c.base.suit_nominal_original,label..' original suit metadata')
  eq(pc.ability.perma_bonus,c.ability.perma_bonus,label..' bonus')
  eq(pc.ability.played_this_ante,c.ability.played_this_ante,label..' played ante')
  for _,edition in ipairs({'foil','holo','polychrome'}) do eq((pc.edition or {})[edition],(c.edition or {})[edition],label..' '..edition) end
 end
 for i,j in ipairs(G.jokers.cards) do eq(predicted.jokers[i].ability.x_mult,j.ability.x_mult,label..' '..j.name..' permanent growth') end
end
local c=card('copy',13,'m_steel');c.seal='Red';c.edition={polychrome=true}
parity(c,{joker('j_dna','DNA'),joker('j_hologram','Hologram',{x_mult=1,extra=0.25})},'upgraded DNA copy')
parity(c,{joker('j_blueprint','Blueprint'),joker('j_dna','DNA'),joker('j_brainstorm','Brainstorm'),joker('j_hologram','Hologram',{x_mult=1,extra=0.25})},'three copies grow Hologram')
c.debuff=true
parity(c,{joker('j_dna','DNA'),joker('j_hologram','Hologram',{x_mult=1,extra=0.25})},'debuffed copy')
parity(c,{joker('j_dna','DNA'),joker('j_hologram','Hologram',{x_mult=1,extra=0.25},true)},'inactive Hologram')
parity(c,{joker('j_blueprint','Blueprint'),joker('j_dna','DNA',nil,true),joker('j_hologram','Hologram',{x_mult=1,extra=0.25})},'inactive DNA')
parity(c,{joker('j_blueprint','Blueprint'),joker('j_brainstorm','Brainstorm')},'copy cycle')
print('DNA source parity: '..cases..' cases / '..checks..' comparisons passed')



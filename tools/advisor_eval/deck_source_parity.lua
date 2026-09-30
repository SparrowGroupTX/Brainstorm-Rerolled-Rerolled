local C=dofile('Brainstorm/Advisor/consumables.lua')
C.deck_development=dofile('Brainstorm/Advisor/deck_development.lua')
C.deck_development.spectral=dofile('Brainstorm/Advisor/spectral_development.lua')
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
local function parity(cards,jokers,selected,label)
 cases=cases+1
 local s={hand=cards,playing_cards=cards,jokers=jokers,consumeables={{key='c_hanged_man',ability={name='The Hanged Man',set='Tarot',consumeable={remove_card=true,max_highlighted=2}}}},consumeable_usage_total={}}
 local predicted=assert(C.apply(s,1,selected))
 queue={}
 G={E_MANAGER={add_event=function(_,e) queue[#queue+1]=e end},GAME={consumeable_usage_total={}},C={FILTER={}},
  hand={cards=clone(cards),highlighted={},unhighlight_all=noop},jokers={cards=clone(jokers)},consumeables={cards={}}}
 G.playing_cards={};for i,c in ipairs(G.hand.cards) do
  G.playing_cards[i]=c;c.unique_val=i;c.T={x=i};c.juice_up=noop
  c.start_dissolve=function(self) remove(G.hand,self);remove({cards=G.playing_cards},self) end
  c.shatter=function(self) self.shattered=true;self:start_dissolve() end
  setmetatable(c,{__index=Card})
 end
 for _,i in ipairs(selected) do G.hand.highlighted[#G.hand.highlighted+1]=G.hand.cards[i] end
 for _,j in ipairs(G.jokers.cards) do setmetatable(j,{__index=Card}) end
 local owned=clone(s.consumeables[1]);owned.juice_up=noop;setmetatable(owned,{__index=Card})
 -- Runtime routes using_consumeable before the delayed destruction runs.
 for _,j in ipairs(G.jokers.cards) do j:calculate_joker({using_consumeable=true,consumeable=owned}) end
 owned:use_consumeable()
 local next_event=1
 while queue[next_event] do assert(next_event<100,'bounded events');local e=queue[next_event];next_event=next_event+1;if e.func then e.func() end end
 eq(#predicted.hand,#G.hand.cards,label..' hand count');eq(#predicted.playing_cards,#G.playing_cards,label..' full count')
 for i,c in ipairs(G.hand.cards) do eq(predicted.hand[i].id,c.id,label..' physical survivor') end
 for i,j in ipairs(G.jokers.cards) do for _,field in ipairs({'caino_xmult','x_mult'}) do eq(predicted.jokers[i].ability[field],j.ability[field],label..' '..j.name..' '..field) end end
end
local a={card('a',13),card('b',12,'m_glass'),card('c',2),card('d',14)}
parity(a,{joker('j_caino','Caino',{caino_xmult=1,extra=1}),joker('j_glass','Glass Joker',{x_mult=1,extra=0.75})},{1,2},'two faces and Glass')
a[1].debuff=true
parity(a,{joker('j_caino','Caino',{caino_xmult=2,extra=0.5}),joker('j_glass','Glass Joker',{x_mult=1,extra=0.75})},{1,2},'debuff face')
a[1]=card('a',2,'m_stone')
parity(a,{joker('j_caino','Caino',{caino_xmult=1,extra=1}),joker('j_pareidolia','Pareidolia')},{1,3},'Pareidolia Stone')
parity(a,{joker('j_caino','Caino',{caino_xmult=1,extra=1}),joker('j_pareidolia','Pareidolia',nil,true)},{1,3},'inactive Pareidolia')
parity(a,{joker('j_blueprint','Blueprint'),joker('j_caino','Caino',{caino_xmult=1,extra=1}),joker('j_brainstorm','Brainstorm')},{2},'copy Jokers do not duplicate growth')
parity(a,{joker('j_caino','Caino',{caino_xmult=1,extra=1},true),joker('j_glass','Glass Joker',{x_mult=1,extra=0.75},true)},{2},'inactive growth')
-- Source copy_card/set_base/set_seal run unchanged. Constructor, enhancement
-- presentation, edition display and card-area emplace are explicit test doubles.
Card.set_ability=function(self,center) self.config.center=center;self.ability=clone(center.config or {});self.ability.name=center.name end
Card.set_edition=function(self,edition) self.edition=next(edition or {}) and clone(edition) or nil end
Card.set_cost=noop;Card.set_sprites=noop;Card.juice_up=noop;Card.add_to_deck=noop;Card.start_materialize=noop
setmetatable(Card,{__call=function(_,x,y,_,_,_,center,params)
 return setmetatable({T={x=x,y=y},config={center=center},ability={},base={},playing_card=params.playing_card},{__index=Card})
end})
local function spectral_parity(key,n,extra,source,jokers,label)
 cases=cases+1
 local cards={source,card('other',2)}
 source.base.times_played=9;source.base.original_value='Queen';source.base.suit_nominal_original=0.123;source.ability.perma_bonus=17
 local owned={key=key,ability={name=n,set='Spectral',extra=extra,consumeable={max_highlighted=1}}}
 local s={hand=cards,playing_cards=cards,jokers=jokers,consumeables={owned},consumeable_usage_total={}}
 local predicted=assert(C.apply(s,1,{1}))
 queue={}
 G={CARD_W=1,CARD_H=1,P_CARDS={},P_CENTERS={c_base={}},C={FILTER={},SUITS={Spades={}}},CONTROLLER={locks={}},
  E_MANAGER={add_event=function(_,e) queue[#queue+1]=e end},GAME={blind={debuff_card=noop}},
  hand={cards=clone(cards),highlighted={},unhighlight_all=noop},deck={config={card_limit=52}},playing_card=2,
  jokers={cards=clone(jokers)},consumeables={cards={}}}
 G.hand.emplace=function(area,c) area.cards[#area.cards+1]=c end
 G.playing_cards={}
 for i,c in ipairs(G.hand.cards) do
  c.T={x=i,y=0};c.unique_val=i;c.playing_card=i
  local value=({[11]='Jack',[12]='Queen',[13]='King',[14]='Ace'})[c.rank] or tostring(c.rank)
  c.config={center={name=c.ability.name,config={}},card={name=value..' of Spades',suit='Spades',value=value}}
  setmetatable(c,{__index=Card});G.playing_cards[i]=c
 end
 G.hand.highlighted={G.hand.cards[1]}
 for _,j in ipairs(G.jokers.cards) do setmetatable(j,{__index=Card}) end
 local actual=clone(owned);setmetatable(actual,{__index=Card})
 for _,j in ipairs(G.jokers.cards) do j:calculate_joker({using_consumeable=true,consumeable=actual}) end
 actual:use_consumeable()
 local event=1;while queue[event] do assert(event<100,'bounded Spectral events');local e=queue[event];event=event+1;if e.func then e.func() end end
 eq(#predicted.hand,#G.hand.cards,label..' hand count');eq(#predicted.playing_cards,#G.playing_cards,label..' full count')
 for i,c in ipairs(G.hand.cards) do
  eq(predicted.hand[i].rank,c.base.id,label..' rank');eq(predicted.hand[i].seal,c.seal,label..' seal')
  eq(predicted.hand[i].debuff,c.debuff,label..' debuff');eq(predicted.hand[i].base.times_played,c.base.times_played,label..' played history')
  eq(predicted.hand[i].base.original_value,c.base.original_value,label..' original rank metadata')
  eq(predicted.hand[i].base.suit_nominal_original,c.base.suit_nominal_original,label..' original suit metadata')
  eq(predicted.hand[i].ability.perma_bonus,c.ability.perma_bonus,label..' bonus')
  for _,edition in ipairs({'foil','holo','polychrome'}) do eq((predicted.hand[i].edition or {})[edition],(c.edition or {})[edition],label..' '..edition) end
 end
 for i,j in ipairs(G.jokers.cards) do eq(predicted.jokers[i].ability.x_mult,j.ability.x_mult,label..' '..j.name..' permanent growth') end
end
for _,spec in ipairs({{'c_talisman','Talisman','Gold'},{'c_deja_vu','Deja Vu','Red'},{'c_trance','Trance','Blue'},{'c_medium','Medium','Purple'}}) do
 local c=card('sealed',13,'m_steel');c.seal='Gold';c.edition={polychrome=true}
 spectral_parity(spec[1],spec[2],spec[3],c,{},spec[2]..' replacement')
end
local c=card('copy',13,'m_steel');c.seal='Red';c.edition={polychrome=true}
spectral_parity('c_cryptid','Cryptid',2,c,{joker('j_hologram','Hologram',{x_mult=1,extra=0.25})},'upgraded copies grow Hologram')
c.debuff=true
spectral_parity('c_cryptid','Cryptid',2,c,{joker('j_blueprint','Blueprint'),joker('j_hologram','Hologram',{x_mult=2,extra=0.5}),joker('j_brainstorm','Brainstorm')},'debuffed copies with copy Jokers')
spectral_parity('c_cryptid','Cryptid',2,c,{joker('j_hologram','Hologram',{x_mult=1,extra=0.25},true)},'inactive Hologram')
print('deck source parity: '..cases..' cases / '..checks..' comparisons passed')

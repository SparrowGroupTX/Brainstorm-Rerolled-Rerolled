local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Pack=dofile('Brainstorm/Advisor/pack_scoring.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Development=dofile('Brainstorm/Advisor/deck_development.lua')
Development.spectral=dofile('Brainstorm/Advisor/spectral_development.lua')
Consumables.deck_development=Development
Strategy.consumables=Consumables;Strategy.deck_development=Development;Strategy.pack_scoring=Pack
Shop.paired_deck=dofile('Brainstorm/Advisor/paired_deck.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local modules={strategy=Strategy,scoring=Scorer,shop_scoring=Shop,pack_scoring=Pack,consumables=Consumables}
local checks=0
local function check(x,s) checks=checks+1;assert(x,s) end
local function state()
  local s={phase='pack',pack_kind='Celestial',pack_choices=1,pack_cards={},playing_cards={},hand={},deck={},jokers={},
    dollars=20,hand_size=8,hand_limit=5,joker_limit=5,consumable_limit=2,consumeables={},hands={},
    modifiers={},probabilities={normal=1},round_resets={hands=4,discards=3},current_round={},
    next_blind={key='bl_small',chips=500},blind={disabled=true}}
  for i,r in ipairs({2,2,4,4,6,6,8,8}) do
    s.playing_cards[i]={id='p:'..i,key='c_base',rank=r,nominal=r,suit=({'Hearts','Clubs','Spades','Diamonds'})[(i-1)%4+1],ability={set='Default'}}
    s.hand[i]=s.playing_cards[i]
  end
  return s
end
local function planet(key,label,hand)
  return {id=key,key=key,name=label,cost=3,ability={name=label,set='Planet',consumeable={hand_type=hand}}}
end
local s=state();s.pack_cards={planet('c_mercury','Mercury','Pair'),planet('c_pluto','Pluto','High Card')}
local original=Snapshot.fingerprint(s)
local r=Decision.run(s,modules)
check(r.action.kind=='choose' and r.pack_diagnostics and #r.pack_diagnostics.offers==2,'All revealed Planet options are recorded')
check(#r.pack_diagnostics.comparisons==2 and not r.pack_diagnostics.tactical_fallback,'Every usable offered Planet gets a complete tactical comparison')
check(r.strategy.scoring_evidence and r.strategy.scoring_evidence.samples==4,'Selected pack action exposes paired evidence')
check(Snapshot.fingerprint(s)==original,'Pack scoring does not mutate live-shaped input')
local p=Pack.project(s,s.pack_cards[1],{},nil,modules)
check(p.dollars==s.dollars and #p.consumeables==0 and p.hands.Pair.level==2,'Free pack Planet immediately levels its hand without paying printed price')
s.consumeables={planet('c_eris','Eris','Flush Five'),planet('c_eris','Eris','Flush Five')}
p=Pack.project(s,s.pack_cards[1],{},nil,modules)
check(#p.consumeables==2 and p.consumable_limit==2,'Full held inventory survives immediate pack use')
local death={key='c_death',name='Death',ability={set='Tarot',consumeable={max_highlighted=2,min_highlighted=2}}}
s=state();s.hand[2].rank=13;s.hand[2].nominal=10
p=Pack.project(s,death,{1,2},nil,modules)
check(p and p.playing_cards[1].rank==13 and p.playing_cards[1].id=='p:1','Death preserves destination identity and exact full-deck transformation')
check(Shop.new(s,Scorer):compare(s,p)~=nil,'Exact Death changes use common population samples')
s.hand[1].face_down=true
check(not Pack.project(s,death,{1,2},nil,modules),'Hidden target identities are outside the exact pack projection')
s.hand[1].face_down=false
local cryptid={key='c_cryptid',ability={name='Cryptid',set='Spectral',extra=2}}
s.jokers={{key='j_hologram',ability={name='Hologram',x_mult=2,extra=0.25}}}
p=Pack.project(s,cryptid,{2},nil,modules)
check(p and #p.playing_cards==10 and p.jokers[1].ability.x_mult==2.5,'Cryptid applies real population and Hologram effects')
check(Shop.new(s,Scorer):compare(s,p)~=nil,'Exact copied population is tactically comparable')
local offered={id='pack:9',key='m_bonus',enhancement='m_bonus',rank=13,nominal=10,suit='Spades',ability={set='Enhanced',bonus=30}}
p=Pack.project(s,offered,nil,nil,modules)
check(p and #p.playing_cards==9 and p.jokers[1].ability.x_mult==2.25,'Standard pack addition triggers Hologram exactly once')
check(Shop.new(s,Scorer):compare(s,p)~=nil,'Standard pack additions use paired population samples')
check(not Pack.project(s,s.playing_cards[1],nil,nil,modules),'Cannot add an already-owned identity')
s=state();s.pack_cards={planet('c_mercury','Mercury','Pair'),{key='c_soul',name='The Soul',ability={set='Spectral'}}}
r=Decision.run(s,modules)
check(r.pack_diagnostics.tactical_fallback and #r.pack_diagnostics.attempted_comparisons==2,'Unknown legal generation keeps whole-pack tactical fallback with attempted evidence')
s=state();s.pack_cards={planet('c_mercury','Mercury','Pair'),planet('c_pluto','Pluto','High Card')}
r=Decision.run(s,modules,nil,{shop_scoring={max_evaluations=1}})
check(r.pack_diagnostics.tactical_fallback and r.shop_diagnostics.truncated,'Insufficient common budget never publishes partial pack comparisons')
print('advisor_nonjoker_pack_scoring: '..checks..' checks passed')

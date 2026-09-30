local P=dofile('Brainstorm/Advisor/blind_prep.lua')
P.blind_start=dofile('Brainstorm/Advisor/blind_start.lua')
local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local checks=0
local function eq(a,b,label) checks=checks+1;assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function check(value,label) checks=checks+1;assert(value,label) end
local function j(key,ability,extra)
  local value={key=key,ability=ability or {},sell_cost=2};for k,v in pairs(extra or {}) do value[k]=v end;return value
end
local function state(row,count)
  local s={phase='blind',jokers=row,joker_limit=5,ante=2,win_ante=8,dollars=20,
    hand_size=8,hands_left=4,discards_left=3,current_round={hands_left=4,discards_left=3},
    playing_cards={},consumeables={},modifiers={},hands={},blind={key='bl_small',boss=false}}
  for i=1,count or 52 do s.playing_cards[i]={id='card'..i,rank=2+(i-1)%13,suit='Spades',ability={}} end
  for i,c in ipairs(row) do c.id='joker'..i end
  return s
end
local function burglar() return j('j_burglar',{name='Burglar',extra=3}) end
local function bp() return j('j_blueprint',{name='Blueprint'}) end
local function bs() return j('j_brainstorm',{name='Brainstorm'}) end
local function marble() return j('j_marble',{name='Marble Joker'}) end
local function hologram(x) return j('j_hologram',{name='Hologram',x_mult=x or 1,extra=.25}) end
local function apply(s,proposal)
  local t=Snap.copy(s);t.jokers={}
  for i,index in ipairs(proposal.action.order) do t.jokers[i]=Snap.copy(s.jokers[index]) end
  return t
end
local s=state({burglar(),bp()});local before=Snap.fingerprint(s)
local r,d=P.suggest(s,S)
check(r,'inactive Blueprint can copy Burglar');eq(r.action.order[1],2);eq(r.action.order[2],1)
eq(d.scope,'startup_copy');eq(d.projected_hand_counter_before,7);eq(d.projected_hand_counter_after,10)
eq(d.additional_hands,3);eq(d.complete,true)
eq(r.preparation.setup_actions,1);eq(r.preparation.post_entry_restore_required,false)
eq(P.suggest(apply(s,r),S),nil,'second refresh stable');eq(Snap.fingerprint(s),before,'input detached')
local after=P.blind_start.project(apply(s,r));eq(after.hands_left,10);eq(after.discards_left,0)
-- Brainstorm can move a currently inactive leftmost self reference behind Burglar.
s=state({bs(),burglar()});r=P.suggest(s,S);check(r);eq(r.action.order[1],2)
-- Strictly improving clicks converge with several copies; no counter or queued
-- state is needed, and each intermediate order has a real extra startup effect.
s=state({bs(),burglar(),bp(),bp()})
local seen={};local steps=0;local previous=0
while true do
  local proposal,diagnostics=P.suggest(s,S);if not proposal then break end
  local signature=Snap.fingerprint(s.jokers);check(not seen[signature],'no setup loop');seen[signature]=true
  s=apply(s,proposal);steps=steps+1;check(steps<=4,'bounded improving chain')
  local projected=P.blind_start.project(s);check(projected.hands_left>previous,'each step adds hands');previous=projected.hands_left
  check(diagnostics.orders<=64,'complete admitted insertion family')
end
check(steps>=1);eq(previous,16,'three copies plus native Burglar')
-- Pinned positions and native/scoring-copy order are constraints, not utility.
s=state({burglar(),bp()});s.jokers[2].pinned=true;eq(P.suggest(s,S),nil,'pins honored')
s=state({burglar(),bp(),hologram()});eq(P.suggest(s,S),nil,'do not take Blueprint away from existing scoring')
s=state({burglar(),j('j_joker',{name='Joker',mult=4}),bs()});eq(P.suggest(s,S),nil,'already copied Burglar stable')
s=state({j('j_joker',{name='Joker',mult=4}),burglar(),bs()});eq(P.suggest(s,S),nil,'scoring Brainstorm requires a real restore policy')
for _,key in ipairs({'j_dusk','j_acrobat'}) do
  s=state({burglar(),j(key,{name=key=='j_dusk' and 'Dusk' or 'Acrobat'}),bp()})
  eq(P.suggest(s,S),nil,'extra hands must not delay '..key)
end
-- Extra Stones need a supported engine, with conservative deck dilution.
s=state({marble(),hologram(),bp()});r,d=P.suggest(s,S)
check(r,'Marble/Hologram benefit admits idle copy');check(d.continuous_opening_ratio>1.01)
eq(d.opening_ratio_floor,nil,'continuous ratio is not a rounded score floor')
after=P.blind_start.project(apply(s,r));eq(#after.playing_cards,54)
for _,joker in ipairs(after.jokers) do if joker.key=='j_hologram' then eq(joker.ability.x_mult,1.5) end end
eq(P.suggest(apply(s,r),S),nil,'Marble copy reaches stable setup')
s=state({marble(),bp()});eq(P.suggest(s,S),nil,'Stone count alone is not a benefit')
s=state({marble(),hologram(100),bp()});eq(P.suggest(s,S),nil,'mature engine gain cannot pay dilution')
s=state({marble(),hologram(),bp()},8);eq(P.suggest(s,S),nil,'thin deck dilution retained')
s=state({marble(),hologram(),j('j_erosion',{name='Erosion'}),bp()});eq(P.suggest(s,S),nil,'Erosion population loss remains explicit')
s=state({marble(),hologram(),j('j_joker',{name='Joker',mult=20}),bp()})
eq(P.suggest(s,S),nil,'later additive Mult invalidates Hologram ratio')
local additive=state({hologram(1.25),j('j_joker',{name='Joker',mult=20})})
additive.hand={{rank=14,suit='Spades',ability={}}}
local before_addition=Score.score(additive,{1}).score
additive.jokers[1].ability.x_mult=1.5
check(Score.score(additive,{1}).score/before_addition<1.5/1.25,'growth ratio is not score ratio across later additions')
s=state({marble(),j('j_joker',{name='Joker',mult=20}),hologram(),bp()})
check(P.suggest(s,S),'additions before the terminal Hologram retain the supported ratio')
for _,mod in ipairs({'balance','chips_dollar_cap','minus_hand_size_per_X_dollar'}) do
  s=state({marble(),hologram(),bp()});s.modifiers[mod]=true;eq(P.suggest(s,S),nil,'nonlinear modifier '..mod)
end
s=state({marble(),hologram(),bp()});s.deck_key='b_plasma';eq(P.suggest(s,S),nil,'Plasma scoring nonlinear')
s=state({marble(),hologram(),bp()});s.consumeables={{key='c_mercury',edition={holo=true}}}
eq(P.suggest(s,S),nil,'later held-consumable addition')
s=state({marble(),hologram(),bp()});s.jokers[1].blueprint_compat=false
eq(P.suggest(s,S),nil,'explicitly incompatible source target')
s=state({marble(),hologram(),bp()});s.jokers[3].edition={holo=true}
s.jokers[1].edition={polychrome=true}
eq(P.suggest(s,S),nil,'copy edition scoring order is not free to move')
-- Existing copied growth is not silently exchanged for extra hands.
s=state({bp(),marble(),burglar(),hologram()});eq(P.suggest(s,S),nil,'preserve copied Marble investment')
-- Dagger still protects valuable engines first, and copying never introduces
-- a different destruction just to increase its callback count.
s=state({j('j_ceremonial',{mult=0}),bp(),burglar(),j('j_egg',{name='Egg'}, {sell_cost=6})})
s.jokers[1].pinned=true;r=P.suggest(s,S);eq(r.preparation.scope,'dagger_only','Dagger protection first')
s=apply(s,r);local original=P.blind_start.project(s);r=P.suggest(s,S)
if r then
  local projected=P.blind_start.project(apply(s,r));eq(#projected.jokers,#original.jokers,'same sacrifices after setup')
end
s=state({j('j_ceremonial',{mult=0}),burglar(),bp()});s.jokers[1].ability.eternal=true
r=P.suggest(s,S);check(not r or r.preparation.scope=='dagger_only','do not exploit startup from a sacrificed engine')
-- Unknown generation and unresolved rows are not optimistic forecasts.
s=state({burglar(),j('j_certificate'),bp()});eq(P.suggest(s,S),nil,'unknown startup effect')
for _,key in ipairs({'bl_final_acorn','bl_final_leaf','bl_final_heart'}) do
  s=state({burglar(),bp()});s.next_blind={key=key,boss=true};eq(P.suggest(s,S),nil,'unsupported upcoming Joker alteration')
end
s=state({burglar(),bp()});s.jokers[1].face_down=true;eq(P.suggest(s,S),nil)
s=state({burglar(),bp()});s.phase='shop';eq(P.suggest(s,S),nil)
s=state({burglar(),bp()});P.blind_start=nil;eq(P.suggest(s,S),nil,'missing source model')
print('blind copy setup: '..checks..' checks passed')

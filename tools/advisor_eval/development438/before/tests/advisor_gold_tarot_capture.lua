-- Manufactured integration through the real Snapshot.capture/card hooks.
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local H=F.Hold
Snapshot.gold_tarot_hold=H
local checks=0
local function check(v,why) checks=checks+1;assert(v,why) end
local function eq(a,b,why) check(a==b,why..': '..tostring(a)..' ~= '..tostring(b)) end
local function area(cards,limit) return {cards=cards or {},config={card_limit=limit or 5,highlighted_limit=5}} end
local function raw_joker(key,name,sort_id)
  return {sort_id=sort_id,config={center={key=key,name=name,set='Joker',blueprint_compat=true}},
    base={},ability={set='Joker',name=name},facing='front',sprite_facing='front',debuff=false,
    pinned=false,cost=4,sell_cost=2}
end
local function fixture()
  local cards,catalog={},{}
  for i=1,14 do
    local c=F.raw(i%2==0 and 'c_hermit' or 'c_magician',i,true)
    catalog[c.config.center.key]=catalog[c.config.center.key] or c.config.center
    c.config.center=catalog[c.config.center.key]
    c.calculate_joker=function() error('Live callback invoked') end
    cards[i]=c
  end
  return {STAGES={RUN=1,MAIN_MENU=2},STAGE=1,
    STATES={SELECTING_HAND=1,SHOP=2,BLIND_SELECT=3,ROUND_EVAL=4},STATE=2,STATE_COMPLETE=true,
    hand=area({},8),deck=area({}),jokers=area({raw_joker('j_perkeo','Perkeo',20),raw_joker('j_brainstorm','Brainstorm',21)}),
    consumeables=area(cards,16),shop_jokers=area({}),shop_vouchers=area({}),shop_booster=area({}),
    playing_cards={},P_CENTERS=catalog,
    GAME={round=21,dollars=170,chips=0,bankrupt_at=0,hands={},modifiers={},
      current_round={hands_left=4,discards_left=3,hands_played=0,discards_used=0,reroll_cost=5},
      round_resets={ante=8,blind_choices={Small='bl_small',Big='bl_big',Boss='bl_final_heart'},
        blind_states={Small='Defeated',Big='Select',Boss='Upcoming'}},
      blind={name='',chips=0,debuff={},disabled=true,config={}},consumeable_buffer=0,
      probabilities={normal=1},selected_back={effect={center={key='b_red'}}}}}
end
math.random=function() error('Snapshot hook used RNG') end
pseudorandom=math.random;pseudoseed=math.random
G=fixture()
local before=Snapshot.fingerprint(Snapshot.copy(G))
local s=Snapshot.capture(G)
eq(s.phase,'shop','actual Snapshot reports shop')
eq(#s.consumeables,14,'all original cards present through real capture')
eq(s.ordering_safe,nil,'actual shape has no invented positive ordering flag')
for _,c in ipairs(s.consumeables) do check(c.tarot_hold_source and c.tarot_hold_source.supported,'real Snapshot hook adds qualified public certificate') end
local receipt,why=H.certify(s)
check(receipt,why or 'real captured 14-card inventory qualifies')
eq(receipt.copy_events,2,'real captured Perkeo/Brainstorm chain count')
eq(receipt.capacity_after,18,'capacity preserved and symbolic generation explicit')
eq(Snapshot.fingerprint(Snapshot.copy(G)),before,'real capture/hook leaves source-shaped game unchanged')
s.consumeables[1].tarot_hold_source.ability.extra_value=100
eq(G.consumeables.cards[1].ability.extra_value,0,'certificate contents detached from raw game')

G=fixture();G.consumeables.cards[1].facing='back';G.consumeables.cards[1].sprite_facing='back'
s=Snapshot.capture(G)
check(not s.consumeables[1].tarot_hold_source.supported,'hidden held card obtains no certificate')
check(not H.certify(s),'hidden inventory rejects full endpoint proof')

G=fixture();G.consumeables.cards[1].states={drag={is=true}}
s=Snapshot.capture(G)
check(not s.consumeables[1].tarot_hold_source.supported,'drag state is checked before capture certificate')
check(not H.certify(s),'captured dragging card cannot become false settled proof')

G=fixture();G.consumeables.cards[1].ability.h_size=1
s=Snapshot.capture(G)
check(not s.consumeables[1].tarot_hold_source.supported,'source mutation is rejected by actual hook')

G=fixture();local hidden={facing='back',sprite_facing='back',pinch={x=false},
  config=setmetatable({},{__index=function() error('Hidden Joker identity read') end}),
  ability=setmetatable({},{__index=function() error('Hidden Joker ability read') end})}
G.jokers.cards[1]=hidden
s=Snapshot.capture(G)
check(s.jokers[1].identity_redacted,'existing hidden Joker redaction precedes new hook')
eq(s.jokers[1].tarot_hold_source,nil,'concealed Joker receives no source certificate')
check(not H.certify(s),'redacted row cannot enter Tarot equivalence proof')

G=fixture();G.P_CENTERS.c_magician={}
s=Snapshot.capture(G)
check(not s.consumeables[1].tarot_hold_source.supported,'stale registry reference rejected through real hook')
print('PASS real Snapshot Tarot hook '..checks..' checks')

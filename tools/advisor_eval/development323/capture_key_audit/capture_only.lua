-- Manufactured metadata capture only: no scorer, Decision, source execution,
-- game, player file or RNG. This preserves the current production behavior.
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Gold=dofile('Brainstorm/Advisor/gold_stickers.lua')
local Perkeo=dofile('Brainstorm/Advisor/perkeo_inventory.lua')
Snapshot.perkeo_inventory=Perkeo
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,label) end
local function area(cards,n) return {cards=cards or {},config={card_limit=n or 5,highlighted_limit=5}} end
local function state()
  local g={STAGES={RUN=1},STAGE=1,STATES={SELECTING_HAND=1,SHOP=2,BLIND_SELECT=3,ROUND_EVAL=4},STATE=1,
    SETTINGS={profile=1},PROFILES={[1]={joker_usage={}}},P_CENTERS={},P_STAKES={},sticker_map={},
    GAME={stake=8,seeded=false,won=false,win_ante=8,round=1,dollars=25,consumeable_buffer=0,
      hands={Pair={level=2,chips=25,mult=3,played=1}},modifiers={},
      current_round={hands_left=4,discards_left=3,hands_played=0,discards_used=0,
        current_hand={chips=0,mult=0,handname='',chip_total=0,hand_level=''}},
      round_resets={ante=2},blind={chips=1000,config={blind={key='bl_small'}}},
      selected_back={effect={center={key='b_red'}}}},hand=area({},8),deck=area(),jokers=area(),consumeables=area({},2),playing_cards={}}
  for _,key in ipairs(Gold.target_keys()) do g.P_CENTERS[key]={key=key,set='Joker'} end
  for level,name in ipairs({'White','Red','Green','Black','Blue','Purple','Orange','Gold'}) do
    g.P_STAKES['stake_'..name:lower()]={set='Stake',order=level,stake_level=level};g.sticker_map[level]=name
  end
  local center={key='c_mercury',name='Mercury',set='Planet',effect='Hand Upgrade',consumeable=true,cost=3,order=2,config={hand_type='Pair'}}
  g.P_CENTERS.c_mercury=center
  g.consumeables.cards[1]={sort_id=31,config={center=center,card={}},params={bypass_discovery_center=true},
    base={nominal=0,suit_nominal=0,face_nominal=0,times_played=0},
    ability={name='Mercury',effect='Hand Upgrade',set='Planet',order=2,type='',mult=0,h_mult=0,h_x_mult=0,
      h_dollars=0,p_dollars=0,t_mult=0,t_chips=0,x_mult=1,h_size=0,d_size=0,extra_value=0,bonus=0,perma_bonus=0,
      hands_played_at_create=0,consumeable={hand_type='Pair'}},
    facing='front',debuff=false,pinned=false,base_cost=3,cost=3,sell_cost=1}
  for i=1,3 do
    local c={playing_card=i,config={center={key='c_base',name='Default Base',set='Default'}},
      base={id=i+2,nominal=i+2,suit='Spades'},ability={},facing='front',debuff=false}
    g.playing_cards[i]=c;if i<=2 then g.hand.cards[i]=c else g.deck.cards[1]=c end
  end
  g.P_CENTERS.j_brainstorm.name='Brainstorm';g.P_CENTERS.j_brainstorm.blueprint_compat=true
  g.jokers.cards[1]={sort_id=20,config={center=g.P_CENTERS.j_brainstorm,center_key='j_brainstorm'},
    ability={set='Joker',name='Brainstorm'},facing='front',debuff=false}
  return g
end
local function capture(g)
  G=g -- match production runtime's current global registry
  local s=Snapshot.capture(g);s.completionist_goal=Gold.capture(g,{enabled=true});return s
end
local function key(g) return Snapshot.fingerprint(capture(g)) end
local function scrub_known_hud(s)
  s=Snapshot.copy(s)
  for _,field in ipairs({'chips','mult','handname','chip_total','hand_level'}) do s.current_round.current_hand[field]=nil end
  return Snapshot.fingerprint(s)
end
math.random=function() error('Metadata capture must not draw RNG') end
pseudorandom=math.random
local g=state();local first=capture(g);local original=key(g)
check(first.consumeables[1].copy_source.supported,'qualified Planet capture source is supported')
check(first.completionist_goal.eligibility.eligible,'synthetic Gold public metadata qualified')
for _=1,12 do eq(key(g),original,'repeated unchanged capture stays deterministic') end
first.hand[1].rank=14;first.completionist_goal.by_key.j_brainstorm.status='complete'
first.consumeables[1].copy_source.ability.mult=99
eq(key(g),original,'mutating returned snapshot/Gold/copy-source cannot mutate future captures')
g.jokers.cards[1].ability.blueprint_compat_ui='Compatible';g.jokers.cards[1].ability.blueprint_compat_check=true
g.jokers.cards[1].T={x=123,y=789,r=4};g.jokers.cards[1].VT={x=42,y=12};g.jokers.cards[1].hovered=true
g.hand.cards[1].juice={r=42};g.hand.cards[1].states={hover={is=true}}
g.P_CENTERS.j_brainstorm.alerted=true;g.P_CENTERS.j_brainstorm.name='Presentation label';g.P_CENTERS.j_brainstorm.hover_cache={time=1}
-- Catalog names are part of ordinary card identity, unlike Gold metadata;
-- keep the physical center name unchanged for the full-snapshot comparison.
g.P_CENTERS.j_brainstorm.name='Brainstorm'
g.consumeables.cards[1].hovered=true;g.consumeables.cards[1].T={x=7,y=8}
eq(key(g),original,'ordinary transforms/hover/cache fields do not restart capture keys')
for _,entry in ipairs({{'chips',50},{'mult',9},{'handname','Pair'},{'chip_total',450},{'hand_level',' lvl.2'}}) do
  local before=capture(g);local fingerprint=Snapshot.fingerprint(before)
  g.GAME.current_round.current_hand[entry[1]]=entry[2]
  local after=capture(g)
  check(Snapshot.fingerprint(after)~=fingerprint,'current capture includes HUD-only '..entry[1]..' change')
  eq(scrub_known_hud(before),scrub_known_hud(after),'all non-HUD inputs remain identical for '..entry[1])
  eq(after.hands.Pair.level,before.hands.Pair.level,'actual hand level unchanged')
  eq(after.chips,before.chips,'actual accumulated blind chips unchanged')
end
local before=scrub_known_hud(capture(g));g.GAME.current_round.current_hand.unknown_mod_rule=1
check(scrub_known_hud(capture(g))~=before,'a prospective narrow HUD exclusion must retain unknown fields')
for _,mutation in ipairs({
  function(x)x.GAME.current_round.hands_left=x.GAME.current_round.hands_left-1 end,
  function(x)x.GAME.hands.Pair.level=x.GAME.hands.Pair.level+1 end,
  function(x)x.GAME.dollars=x.GAME.dollars-1 end,
  function(x)x.hand.cards[1],x.hand.cards[2]=x.hand.cards[2],x.hand.cards[1] end,
}) do
  local before=scrub_known_hud(capture(g));mutation(g)
  check(scrub_known_hud(capture(g))~=before,'real action/resource/order changes remain distinct')
end
print('Capture-only audit: '..checks..' manufactured checks passed; current HUD key sensitivity reproduced, no solver/source/player execution')

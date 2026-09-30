local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local B=dofile('Brainstorm/Advisor/concealed_belief.lua')
local S=dofile('Brainstorm/Advisor/scoring.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local checks=0
local function eq(a,b,why) checks=checks+1;assert(a==b,(why or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function check(v,why) checks=checks+1;assert(v,why) end
local function area(cards,limit) return {cards=cards or {},config={card_limit=limit or 8,highlighted_limit=5}} end
local function fixture(glass)
  local g={STAGES={RUN=1},STAGE=1,STATES={SELECTING_HAND=1},STATE=1,
    hand=area(),deck=area(),discard=area(),jokers=area({},5),consumeables=area({},2),playing_cards={},
    GAME={hands={},current_round={hands_left=4,discards_left=2,discards_used=1},round_resets={ante=1},
      blind={name='Small Blind',chips=300,config={blind={key='bl_small'}}},modifiers={},probabilities={normal=glass and 4 or 1}}}
  for i=1,52 do
    local rank=2+(i-1)%13
    local c={playing_card=i,base={id=rank,nominal=rank==14 and 11 or math.min(rank,10),suit='Spades'},
      ability={effect=glass and 'Glass Card' or 'Base'},facing=i<=8 and 'front' or 'back',
      config={center={key=glass and 'm_glass' or 'c_base',set=glass and 'Enhanced' or 'Default'}}}
    g.playing_cards[i]=c
    local into=i<=8 and g.hand or i==9 and g.discard or g.deck
    into.cards[#into.cards+1]=c;c.area=into
  end
  if glass then
    g.jokers.cards={{config={center={key='j_glass'}},ability={name='Glass Joker',x_mult=1,extra=.75}},
      {config={center={key='j_oops'}},ability={name='Oops! All 6s',eternal=true},edition={negative=true}},
      {config={center={key='j_oops'}},ability={name='Oops! All 6s',eternal=true},edition={negative=true}}}
  end
  return g
end
for _,glass in ipairs({false,true}) do
  local g=fixture(glass);local before=Snapshot.fingerprint(Snapshot.copy(g))
  local s=Snapshot.capture(g)
  eq(s.playing_cards[9].face_down,false,'ordinary discard back is a known identity')
  eq(s.deck[1].face_down,true,'unseen draw-pile backs remain unchanged')
  eq(Snapshot.card(g.discard.cards[1]).face_down,true,'raw card capture still reports its physical facing')
  eq(B.has_hidden(s),false,'visible hand after ordinary discard uses ordinary search')
  eq(B.run(s,{score=function()error('concealed score must not run')end}),nil)
  local result=Decision.run(s,{concealed_belief=B,scoring=S,search=dofile('Brainstorm/Advisor/search.lua')})
  check(result.action and result.action.kind=='play','real scoring/search restores executable advice')
  eq(result.concealed_belief,nil,'no spurious concealed refusal')
  eq(Snapshot.fingerprint(Snapshot.copy(g)),before,'capture and advice do not alter live inputs')
  eq(#s.hand+#s.deck+1,#s.playing_cards,'discard stays nondrawable and total population conserved')
  if glass then
    local score=S.lower_bound(s,result.action.indices)
    check(not score.uncertain and score.glass_loss>0,'supported certain Glass loss remains accounted for')
  end
  -- Removing membership evidence must never infer that an arbitrary outside
  -- back is public, even if its source area pointer or numeric ID looks known.
  g.discard.cards={}
  eq(B.has_hidden(Snapshot.capture(g)),true,'unknown outside location retains guard')
  g.discard.cards={Snapshot.copy(g.playing_cards[9])}
  eq(B.has_hidden(Snapshot.capture(g)),true,'matching ID is not actual discard membership')
  g.discard.cards={g.playing_cards[9]}
  g.discard.cards[1].ability.wheel_flipped=true
  s=Snapshot.capture(g)
  eq(s.playing_cards[9].face_down,true,'truly concealed discard remains unknown')
  eq(B.has_hidden(s),true)
  local refused=B.run(s,S)
  eq(refused.kind,'unsupported','unknown conceal origin is not silently bypassed')
  eq(refused.action,nil)
  g.GAME.blind={name='The House',chips=300,config={blind={key='bl_house'}}}
  s=Snapshot.capture(g)
  local o=assert(B.observe(s))
  eq(o.hidden_outside_count,1,'known boss admits joint hidden discard posterior')
  eq(#o.pool,#s.deck+1,'concealed discarded identity is not subtracted from unseen composition')
  for i=1,8 do
    local world=assert(B.world(o,i))
    eq(#world.deck,#s.deck,'hidden discard assignments remain nondrawable')
    eq(#world.playing_cards,#s.playing_cards,'conditioned population conserved')
  end
  g.GAME.blind.disabled=true
  eq(Snapshot.capture(g).playing_cards[9].face_down,true,'disabled flag alone cannot reveal a discard')
  g.discard.cards[1].ability.wheel_flipped=nil
  eq(B.has_hidden(Snapshot.capture(g)),false,'source-cleared public marker restores known discard')
  g.hand.cards[1].facing='back'
  eq(B.has_hidden(Snapshot.capture(g)),true,'held backs are never normalized as discarded')
end
print('advisor_discard_visibility: '..checks..' checks passed')

local Snapshot=dofile(PROBE_DIRECTORY..'/snapshot.lua')
local Belief=dofile(PROBE_DIRECTORY..'/concealed_belief.lua')
local checks,cases=0,0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
function check_for_unlock() end
function Event(e) return e end
local roll=0
function pseudoseed(k) return k end
function pseudorandom() return roll end
local function area(kind,limit)
 return setmetatable({cards={},highlighted={},children={},config={type=kind,card_limit=limit or 52,
  highlighted_limit=5},is=function()return true end,set_ranks=function()end,
  remove_from_highlighted=function()end},{__index=CardArea})
end
local function card(id,rank,glass)
 return setmetatable({playing_card=id,facing='front',pinch={},states={drag={is=true}},
  T={x=id,w=1},ability={name=glass and 'Glass Card' or 'Base',effect=glass and 'Glass Card' or 'Base'},
  config={center={key=glass and 'm_glass' or 'c_base',set=glass and 'Enhanced' or 'Default'}},
  base={id=rank,suit='Spades',nominal=rank}},{__index=Card})
end
local function setup(name,flip)
 G={STAGES={RUN=1},STAGE=1,STATES={SELECTING_HAND=1,TAROT_PACK=2,SPECTRAL_PACK=3,PLANET_PACK=4},STATE=1,
  hand=area('hand',8),deck=area('deck'),discard=area('discard'),play=area('play'),
  jokers=area('joker',5),consumeables=area('consumeable',2),
  GAME={modifiers=flip>0 and {flipped_cards=flip} or {},probabilities={normal=1},
   current_round={hands_played=0,discards_used=0,hands_left=4,discards_left=3},chips=0,
   blind=setmetatable({name=name,config={blind={key='fixture'}},chips=300,boss=true,
    debuff_card=function()end,set_text=function()end,wiggle=function()end},{__index=Blind})},
  E_MANAGER={add_event=function(_,e) if e.func then e.func() end end}}
end
local function observed(id)
 local s=assert(Snapshot.capture(G))
 for _,c in ipairs(s.playing_cards) do if c.id=='playing:'..id then return c,s end end
 error('missing population card')
end
for _,name in ipairs({'Small Blind','The House','The Fish','The Wheel','The Mark'}) do
 for _,flip in ipairs({0,2}) do for _,value in ipairs({0,0.99}) do for _,glass in ipairs({false,true}) do
  cases=cases+1;setup(name,flip);roll=value
  local c,held,remaining=card(1,11,glass),card(2,2,glass),card(3,14,glass)
  G.playing_cards={c,held,remaining}
  G.deck:emplace(c);eq(c.facing,'back','source deck alignment flips face down')
  G.deck:emplace(remaining);G.hand:emplace(held)
  -- Put c at the source draw end without using its latent rank to choose it.
  eq(G.hand:draw_card_from(G.deck),true,'source initial draw succeeds')
  eq(c.area,G.hand,'initial draw identity moved to hand')
  local concealed=not not c.ability.wheel_flipped
  eq(c.facing=='back',concealed,'source initial draw facing matches conceal marker')
  local captured,first=observed(1)
  eq(captured.face_down,concealed,'capture preserves genuine held concealment')
  eq(Belief.has_hidden(first),concealed,'initial draw hidden dispatch')
  G.hand:remove_card(c);G.discard:emplace(c)
  eq(c.facing,'back','source discard align always displays card back')
  eq(not not c.ability.wheel_flipped,concealed,'discard alignment preserves observation marker')
  eq(source_unknown_population(c),concealed,'source deck preview agrees on unknown identity')
  captured,first=observed(1)
  eq(captured.face_down,concealed,'captured discard uses observation provenance')
  eq(Snapshot.card(c).face_down,true,'raw card capture retains display facing')
  eq(Belief.has_hidden(first),concealed,'visible hand dispatch preserves unknown discarded identities only')
  eq(#first.hand+#first.deck+1,#first.playing_cards,'discard capture conserves physical population')
  eq(c.facing,'back','capture leaves source orientation untouched')
  if concealed then
   G.discard:remove_card(c);G.play:emplace(c)
   eq(c.facing,'front','actual source play reveals hidden identity')
   eq(c.ability.wheel_flipped,nil,'actual reveal clears unknown marker')
   G.play:remove_card(c);G.discard:emplace(c)
   captured,first=observed(1)
   eq(captured.face_down,false,'known played card remains known after discard alignment')
   eq(Belief.has_hidden(first),false,'revealed discard does not block ordinary advice')
  end
 end end end
end
-- Disabling a supported concealing boss clears markers in original source.
-- Its deck view then publicly removes the formerly hidden discarded identity
-- from the unknown population even though its display remains a card back.
for _,name in ipairs({'The House','The Fish','The Wheel','The Mark'}) do
 cases=cases+1;setup(name,0)
 local c,held,remaining=card(1,11,true),card(2,2,true),card(3,14,true)
 c.facing='back';c.ability.wheel_flipped=true
 G.playing_cards={c,held,remaining};G.discard:emplace(c);G.hand:emplace(held);G.deck:emplace(remaining)
 eq(source_unknown_population(c),true,'hidden discard included in source public unknown pool')
 G.GAME.blind:disable()
 eq(c.facing,'back','disable leaves discard rendering on back')
 eq(c.ability.wheel_flipped,nil,'source disable clears discard conceal marker')
 eq(source_unknown_population(c),false,'source public deck now excludes discarded identity')
 local captured,s=observed(1)
 eq(captured.face_down,false,'capture agrees with disabled source public deck')
 eq(Belief.has_hidden(s),false,'disabled source public visibility restores ordinary dispatch')
end
print('discard visibility source parity: '..cases..' cases, '..checks..' comparisons')

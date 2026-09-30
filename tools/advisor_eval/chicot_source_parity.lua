-- Original callback methods and EventManager are loaded above. Only rendering,
-- source-card construction and final area removal are explicit fixture glue.
local Start=dofile(PROBE_POLICY..'/Brainstorm/Advisor/blind_start.lua')
local Snapshot=dofile(PROBE_POLICY..'/Brainstorm/Advisor/snapshot.lua')
local checks,cases=0,0
local function eq(a,b,label) checks=checks+1;assert(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local copy=Snapshot.copy
local noop=function() end
localize=function() return 'fixture' end
number_format=tostring;get_blind_amount=function() return 300 end
play_sound=noop;attention_text=noop;card_eval_status_text=noop;calculate_reroll_cost=noop
discover_card=noop;check_for_unlock=noop;HEX=function() return {} end
Particles=function() return {fade=noop} end
Card.juice_up=noop
Card.flip=function(self) self.facing=self.facing=='front' and 'back' or 'front' end
Card.remove=function(self)
  self:remove_from_deck()
  for i=#G.jokers.cards,1,-1 do if G.jokers.cards[i]==self then table.remove(G.jokers.cards,i) end end
end
Blind.get_type=function() return 'Boss' end
Blind.set_text=noop;Blind.change_colour=noop;Blind.alert_debuff=noop;Blind.wiggle=noop;Blind.juice_up=noop
local names={j_ceremonial='Ceremonial Dagger',j_chicot='Chicot',j_joker='Joker'}
local function joker(key,extra)
  local j={key=key,sell_cost=4,pinned=false,debuff=false,
    ability={name=names[key],set='Joker',mult=key=='j_ceremonial' and 6 or 0,h_size=0,d_size=0}}
  for k,v in pairs(extra or {}) do j[k]=v end
  return j
end
local function dagger(debuff) local j=joker('j_ceremonial',{pinned=true,debuff=not not debuff});j.ability.eternal=true;return j end
local function chicot() return joker('j_chicot',{sell_cost=10}) end
local function fodder() return joker('j_joker') end
local bosses={wall={key='bl_wall',name='The Wall',mult=4,boss={}},
  heart={key='bl_final_heart',name='Crimson Heart',mult=2,boss={showdown=true}},
  water={key='bl_water',name='The Water',mult=2,boss={}},
  needle={key='bl_needle',name='The Needle',mult=1,boss={}}}
local function hud()
  local node={states={visible=true},config={object={update=noop,pop_in=noop}},alignment={offset={x=0,y=0}},recalculate=noop,juice_up=noop}
  node.parent={parent={states={visible=true}}}
  node.get_UIE_by_ID=function() return node end
  return node
end
local function pending()
  for _,queue in pairs(G.E_MANAGER.queues) do if #queue>0 then return true end end
end
local function run(label,row,boss_key)
  cases=cases+1
  local definition=copy(bosses[boss_key]);definition.debuff={};definition.dollars=5;definition.pos={x=0,y=0}
  for i,j in ipairs(row) do j.id=i end
  local input={jokers=copy(row),playing_cards={},hand_size=8,joker_limit=5,
    current_round={hands_left=4,discards_left=3,free_rerolls=0},round_resets={ante=2,hands=4,discards=3},
    hands_left=4,discards_left=3,probabilities={normal=1},dollars=10,bankrupt_at=0,interest_amount=1,
    blind={key=definition.key,name=definition.name,boss=true,disabled=false,chips=300*definition.mult,mult=definition.mult,debuff={}}}
  if boss_key=='water' then input.blind.discards_sub=3;input.discards_left=0;input.current_round.discards_left=0 end
  if boss_key=='needle' then input.blind.hands_sub=3;input.hands_left=1;input.current_round.hands_left=1 end
  local before=Snapshot.fingerprint(input)
  local predicted,diagnostics=Start.project(input)
  assert(predicted,label..' projection unavailable: '..tostring(diagnostics))
  eq(Snapshot.fingerprint(input),before,label..' immutable input')
  G={SETTINGS={paused=false,reduced_motion=true},TIMERS={REAL=0,TOTAL=0},ARGS={spin={}},ROOM={jiggle=0},
    C={RED={},GREEN={},BLUE={},BLACK={}},STATES={NEW_ROUND=1},STATE=0,
    GAME={chips=0,modifiers={},starting_params={ante_scaling=1},round_resets={ante=2,hands=4,discards=3},
      current_round={hands_left=4,discards_left=3,free_rerolls=0},probabilities={normal=1},joker_buffer=0,
      bankrupt_at=0,interest_amount=1,dollars=10},HUD=hud(),HUD_blind=hud(),
    jokers={cards={},config={card_limit=5}},consumeables={cards={},config={card_limit=2}},
    hand={cards={},size=8,change_size=function(self,n) self.size=self.size+n end},
    playing_cards={},P_CENTERS={e_base={discovered=true}},I={CARD={}}}
  G.E_MANAGER=EventManager()
  local blind=setmetatable({config={},children={animatedSprite={set_sprite_pos=noop}}},{__index=Blind})
  G.GAME.blind=blind
  for i,j in ipairs(row) do
    local c=copy(j);c.area=G.jokers;c.facing='front';c.added_to_deck=not c.debuff
    c.config={center={key=c.key,discovered=true}};setmetatable(c,{__index=Card});G.jokers.cards[i]=c
  end
  blind:set_blind(definition,false,true)
  for _,j in ipairs(G.jokers.cards) do j:calculate_joker({setting_blind=true,blind=definition}) end
  local frames=0
  while pending() do
    frames=frames+1;assert(frames<=1200,'Source callback frame allowance exceeded')
    G.TIMERS.REAL=G.TIMERS.REAL+1/60;G.TIMERS.TOTAL=G.TIMERS.TOTAL+1/60
    G.E_MANAGER:update(1/60)
  end
  eq(#predicted.jokers,#G.jokers.cards,label..' retained count')
  for i,j in ipairs(predicted.jokers) do
    local actual=G.jokers.cards[i]
    eq(j.id,actual.id,label..' retained order '..i)
    eq(j.ability.mult,actual.ability.mult,label..' Mult '..i)
    eq(not not j.debuff,not not actual.debuff,label..' debuff '..i)
    eq(not not j.pinned,not not actual.pinned,label..' pin '..i)
  end
  eq(not not predicted.blind.disabled,not not blind.disabled,label..' disabled')
  eq(predicted.blind.chips,blind.chips,label..' chips')
  eq(predicted.hands_left,G.GAME.current_round.hands_left,label..' hands')
  eq(predicted.discards_left,G.GAME.current_round.discards_left,label..' discards')
  eq(predicted.hand_size,G.hand.size,label..' hand size')
  eq(predicted.joker_limit,G.jokers.config.card_limit,label..' Joker slots')
  eq(predicted.round_resets.hands,G.GAME.round_resets.hands,label..' next hands')
  eq(predicted.round_resets.discards,G.GAME.round_resets.discards,label..' next discards')
  eq(predicted.dollars,G.GAME.dollars,label..' destruction is not sale')
  print('chicot case '..label..' frames='..frames..' row='..#G.jokers.cards..' chips='..blind.chips)
end
local function quoted(text)
  return '"'..tostring(text):gsub('[%z\1-\31\\"]',function(c)
    local escapes={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
    return escapes[c] or string.format('\\u%04x',string.byte(c)) end)..'"'
end
local rows={
  {'dagger_eats_chicot',{dagger(),chicot(),fodder()},'wall'},
  {'retained_chicot',{dagger(),fodder(),chicot()},'wall'},
  {'chicot_before_dagger',{chicot(),dagger(),fodder()},'wall'},
  {'debuffed_dagger',{dagger(true),fodder(),chicot()},'heart'},
  {'duplicate_chicot_wall',{chicot(),chicot()},'wall'},
  {'retained_chicot_water',{dagger(),fodder(),chicot()},'water'},
  {'retained_chicot_needle',{dagger(),fodder(),chicot()},'needle'},
  {'duplicate_chicot_water',{chicot(),chicot()},'water'}}
local passed=0
for _,spec in ipairs(rows) do
  local before=checks;local ok,reason=pcall(run,unpack(spec))
  if ok then passed=passed+1 end
  print('chicot case_result {"case":'..quoted(spec[1])..',"status":'..quoted(ok and 'passed' or 'error')..
    ',"comparison_assertions_attempted":'..(checks-before)..',"reason":'..(ok and 'null' or quoted(reason))..'}')
end
print('chicot source parity: '..passed..' cases, '..checks..' comparisons')
assert(passed==#rows,'One or more registered source cases failed; all independent cases were retained')

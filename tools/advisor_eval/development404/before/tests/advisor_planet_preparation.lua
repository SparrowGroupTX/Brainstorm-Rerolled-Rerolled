local Prep=dofile('Brainstorm/Advisor/blind_prep.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
Strategy.consumables=Consumables
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local copy=Snapshot.copy
local function planet(key,name,hand)
  return {id=key,key=key,name=name,ability={name=name,set='Planet',consumeable={hand_type=hand}}}
end
local function state()
  return {phase='blind',ante=8,blind_on_deck='Boss',dollars=11,hand_size=10,joker_limit=0,
    hand={},deck={},playing_cards={},jokers={},consumeables={planet('c_saturn','Saturn','Straight'),planet('c_saturn','Saturn','Straight')},
    consumable_limit=2,consumeable_buffer=0,modifiers={},used_vouchers={v_telescope=true,v_palette=true,v_paint_brush=true},
    current_round={},round_resets={hands=5,discards=4},probabilities={normal=1},
    hands={Straight={played=21,level=19,chips=570,mult=58,l_chips=30,l_mult=3,s_chips=30,s_mult=4}},
    next_blind={key='bl_final_bell',chips=100000,boss=true},blind={key='bl_big',chips=20000},
    last_tarot_planet='c_death',shop_jokers={},shop_booster={},shop_vouchers={}}
end
local modules={strategy=Strategy,consumables=Consumables,blind_prep=Prep,
  scoring={score=function() error('Exact Planet preparation must not score cards') end},
  shop_scoring={new=function() error('Exact Planet preparation must not depend on uncertain boss scoring') end}}
local random,randomseed=math.random,math.randomseed
math.random=function() error('Planet preparation must not sample global RNG') end
math.randomseed=function() error('Planet preparation must not reseed global RNG') end
do
  local s=state();local original=Snapshot.fingerprint(s)
  local result=Decision.run(s,modules)
  check(result.action.kind=='use' and result.action.area=='consumeables' and result.action.index==1,
    'actual decision uses the held main-hand Planet before entering an unsupported random boss')
  check(result.evaluations==0 and result.preparation_diagnostics.complete and
    result.preparation_diagnostics.score_forecast_required==false and result.preparation_diagnostics.readiness_claim==false,
    'the recommendation proves only an exact level-up and makes no readiness or clear claim')
  local after=Consumables.apply(s,result.action.index,{})
  check(after.hands.Straight.level==20 and after.hands.Straight.chips==600 and after.hands.Straight.mult==61,
    'first source-shaped Saturn gives the exact next public hand level')
  local next_result=Decision.run(after,modules)
  check(next_result.action.kind=='use' and next_result.action.index==1,'refresh consumes the second useful Planet at its actual shifted slot')
  local done=Consumables.apply(after,next_result.action.index,{})
  check(done.hands.Straight.level==21 and done.hands.Straight.chips==630 and done.hands.Straight.mult==64 and #done.consumeables==0,
    'two sequential user-clickable uses raise level nineteen to twenty-one and free two slots')
  check(not Prep.suggest(done,Strategy),'preparation stops when its concrete inventory is exhausted')
  check(Snapshot.fingerprint(s)==original,'planning leaves source hand levels and inventory unchanged')
  check(Snapshot.fingerprint(result)==Snapshot.fingerprint(Decision.run(s,modules)),
    'the recommendation is deterministic and consumes no RNG')
end
for _,case in ipairs({
  {'Four of a Kind','c_mars','Mars',4,60,7,30,3},
  {'Five of a Kind','c_planet_x','Planet X',3,120,12,35,3},
  {'Flush','c_jupiter','Jupiter',7,35,4,15,2},
}) do
  local s=state();s.phase='shop';s.hands={[case[1]]={played=9,level=case[4],
    chips=case[5]+case[7]*(case[4]-1),mult=case[6]+case[8]*(case[4]-1),l_chips=case[7],l_mult=case[8]}}
  s.consumeables={planet(case[2],case[3],case[1])}
  local r=Decision.run(s,modules)
  check(r.action.kind=='use' and r.preparation_diagnostics.hand==case[1],
    'exact preparation generalizes to '..case[1]..' and runs before shop spending')
end
for _,case in ipairs({
  {'owned Perkeo',function(s) s.jokers={{key='j_perkeo',ability={name='Perkeo'}}} end},
  {'debuffed future Joker',function(s) s.jokers={{key='j_perkeo',debuff=true,ability={name='Perkeo'}}} end},
  {'ordinary owned Joker',function(s) s.jokers={{key='j_joker',ability={name='Joker'}}} end},
  {'Observatory voucher',function(s) s.used_vouchers.v_observatory=true end},
  {'alternative Observatory field',function(s) s.vouchers={v_observatory=true} end},
  {'unplayed hand',function(s) s.hands.Straight.played=0 end},
  {'unknown hand chips',function(s) s.hands.Straight.chips=nil end},
  {'nonfinite level',function(s) s.hands.Straight.level=math.huge end},
  {'negative level gain',function(s) s.hands.Straight.l_mult=-3 end},
  {'pending generation',function(s) s.consumeable_buffer=1 end},
  {'unrelated hand',function(s) s.consumeables={planet('c_mercury','Mercury','Pair')} end},
  {'all Negative Planets',function(s) for _,c in ipairs(s.consumeables) do c.edition={negative=true} end end},
  {'debuffed Planets',function(s) for _,c in ipairs(s.consumeables) do c.debuff=true end end},
  {'concealed inventory',function(s) for _,c in ipairs(s.consumeables) do c.face_down=true end end},
  {'modified Planet identity',function(s) for _,c in ipairs(s.consumeables) do c.ability.name='The Hermit' end end},
  {'modified Planet config',function(s) for _,c in ipairs(s.consumeables) do c.ability.consumeable.extra=10 end end},
  {'hand tactical phase',function(s) s.phase='hand' end},
  {'pack choice phase',function(s) s.phase='pack' end},
}) do
  local s=state();case[2](s)
  check(not Prep.planet_preparation(s,Strategy),case[1]..' keeps existing protected planning')
end
do
  local s=state();s.consumeables[1].edition={negative=true};s.consumable_limit=3
  local r=Prep.planet_preparation(s,Strategy)
  check(r and r.action.index==2,'ordinary Planet is used while the existing Negative card remains protected')
  local after=Consumables.apply(s,2,{})
  check(#after.consumeables==1 and after.consumeables[1].edition.negative and after.consumable_limit==3,
    'the other Negative card and its supplied inventory slot remain intact')
  s=state();s.consumeables[2]={id='fool',key='c_fool',ability={name='The Fool',set='Tarot',consumeable={}}}
  check(not Prep.planet_preparation(s,Strategy),'using a Planet must not overwrite the owned Fool copy identity')
  s.last_tarot_planet='c_saturn'
  check(Prep.planet_preparation(s,Strategy)~=nil,'Fool remains usable when its exact previous identity is unchanged')
  local guarded=setmetatable({preservation_cost=function() return 1,'Protected future inventory',false end},{__index=Strategy})
  check(not Prep.planet_preparation(state(),guarded),'the whole-inventory preservation hook still vetoes spending')
  guarded=setmetatable({preservation_cost=function() return 0,'Protected final source',true end},{__index=Strategy})
  check(not Prep.planet_preparation(state(),guarded),'a protected last source cannot be spent by this preparation')
end
do
  local s=state();s.ante=2;s.hands.Pair={played=2,level=1,chips=10,mult=2,l_chips=15,l_mult=1}
  s.consumeables={planet('c_mercury','Mercury','Pair')}
  local original=Snapshot.fingerprint(s)
  local result=Decision.run(s,modules)
  check(result.action.kind=='use' and result.action.index==1 and result.evaluations==0,
    'actual blind-entry decision uses the known played secondary-hand Planet with no score forecast')
  check(result.preparation_diagnostics.scope=='exact_played_hand_planet' and result.preparation_diagnostics.main_hand==false and
    result.preparation_diagnostics.profile_hand=='Straight' and result.preparation_diagnostics.played==2,
    'secondary-hand preparation explicitly records the observed history and existing main build')
  local after=Consumables.apply(s,1,{})
  check(after.hands.Pair.level==2 and after.hands.Pair.chips==25 and after.hands.Pair.mult==3 and
    after.hands.Straight.level==19 and #after.consumeables==0,
    'secondary Mercury applies exactly one Pair level and frees its actual inventory slot')
  check(Snapshot.fingerprint(s)==original,'secondary preparation leaves the original hand levels and inventory intact')
  s.phase='shop'
  check(not Prep.planet_preparation(s,Strategy),'secondary hand does not bypass fresh-shop purchase or financing decisions')
  s.phase='blind';s.hands.Pair.played=0
  check(not Prep.planet_preparation(s,Strategy),'unplayed secondary hand receives no speculative upgrade')
  s.hands.Pair.played=0/0
  check(not Prep.planet_preparation(s,Strategy),'nonfinite secondary-hand history is unsupported')
  s.hands.Pair.played=2;s.consumeables[2]=planet('c_saturn','Saturn','Straight')
  result=Decision.run(s,modules)
  check(result.action.index==2 and result.preparation_diagnostics.main_hand and result.preparation_diagnostics.hand=='Straight',
    'main-hand Planet keeps priority even behind a valid secondary Planet in inventory')
end
for _,case in ipairs({
  {'secondary Perkeo',function(s) s.jokers={{key='j_perkeo',ability={name='Perkeo'}}} end},
  {'secondary Observatory',function(s) s.used_vouchers.v_observatory=true end},
  {'secondary alternative Observatory',function(s) s.vouchers={v_observatory=true} end},
  {'secondary Negative',function(s) s.consumeables[1].edition={negative=true};s.consumable_limit=3 end},
  {'secondary Fool identity',function(s) s.consumeables[2]={key='c_fool',ability={name='The Fool',set='Tarot'}} end},
  {'secondary unknown chips',function(s) s.hands.Pair.chips=nil end},
  {'secondary negative growth',function(s) s.hands.Pair.l_mult=-1 end},
  {'secondary concealed card',function(s) s.consumeables[1].face_down=true end},
}) do
  local s=state();s.hands.Pair={played=2,level=1,chips=10,mult=2,l_chips=15,l_mult=1}
  s.consumeables={planet('c_mercury','Mercury','Pair')};case[2](s)
  check(not Prep.planet_preparation(s,Strategy),case[1]..' retains the full existing preparation safeguard')
end
do
  local s=state();s.hands.Pair={played=2,level=1,chips=10,mult=2,l_chips=15,l_mult=1}
  s.consumeables={planet('c_mercury','Mercury','Pair'),{key='c_fool',ability={name='The Fool',set='Tarot'}}}
  s.last_tarot_planet='c_mercury'
  check(Prep.planet_preparation(s,Strategy)~=nil,'secondary use preserves an owned Fool when its previous identity is already that Planet')
  s.consumeables[2]=planet('c_saturn','Saturn','Straight');s.consumeables[2].edition={negative=true};s.consumable_limit=3
  local result=Prep.planet_preparation(s,Strategy)
  check(result and result.action.index==1,'secondary ordinary Planet may be used while the main-hand Negative remains protected')
  local after=Consumables.apply(s,1,{})
  check(#after.consumeables==1 and after.consumeables[1].edition.negative and after.consumable_limit==3,
    'secondary preparation preserves the other Negative Planet and whole-inventory capacity')
  local protected=setmetatable({preservation_cost=function() return 1,'Protected future inventory',false end},{__index=Strategy})
  check(not Prep.planet_preparation(s,protected),'secondary preparation retains the whole-inventory preservation veto')
end
math.random,math.randomseed=random,randomseed
print('advisor_planet_preparation: '..checks..' checks passed')

-- Manufactured module-boundary witnesses, not live timing or policy evidence.
-- No scorer, policy, original game source, native worker, filesystem/profile
-- callbacks or captured state. These assertions describe current gaps, not fixes.
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Draws=dofile('Brainstorm/Advisor/draws.lua')
local checks=0
local function check(value,label) checks=checks+1;assert(value,label) end
math.random=function() error('Visibility probes must not use RNG.') end

local function card(rank,facing,sprite,flipping,pinch)
  return {playing_card=1,base={id=rank,nominal=10,suit='Clubs'},
    config={center={key='c_base',set='Default'}},ability={},
    facing=facing,sprite_facing=sprite,flipping=flipping,pinch=pinch}
end
local a=card(13,'front','back','b2f',{x=true})
local b=card(2,'front','back','b2f',{x=true})
local before=Snapshot.fingerprint(a)
local captured_a,captured_b=Snapshot.card(a),Snapshot.card(b)
check(captured_a.face_down==false and captured_b.face_down==false,
  'CURRENT GAP: front facing/back sprite is classified as visible')
check(captured_a.rank==13 and captured_b.rank==2,
  'unsettled capture carries different hidden identities as visible')
check(Snapshot.fingerprint(captured_a)~=Snapshot.fingerprint(captured_b),
  'capture differs despite identical manufactured public backs')
check(Snapshot.fingerprint(a)==before,'capture does not mutate source')
check(Snapshot.card(card(13,'back','back',nil)).face_down==true,'settled back remains concealed')
check(Snapshot.card(card(13,'front','front','b2f',{x=false})).face_down==false,'settled reveal is visible')

for _,key in ipairs({'bl_fish','bl_wheel'}) do
  local state={blind={key=key,prepped=true},probabilities={normal=1},jokers={}}
  local source={id='playing:1',rank=13,face_down=true,ability={}}
  local original=Snapshot.fingerprint(source)
  local backed=assert(Draws.card(state,source,0))
  check(backed.face_down==true and backed.ability.wheel_flipped==true,key..' samples concealed draw')
  check(Snapshot.fingerprint(source)==original,key..' source remains unchanged')
  source.face_down=false
  local front=assert(Draws.card(state,source,0))
  check(front.face_down==false and front.ability.wheel_flipped==true,
    'CURRENT GAP: '..key..' incoming face_down=false defeats sampled concealment')
  source.face_down=nil
  check(assert(Draws.card(state,source,0)).face_down==true,key..' missing orientation honors concealment')
  local visible=assert(Draws.card({blind={key=key,disabled=true}},source,0))
  check(visible.face_down==false,key..' disabled blind produces visible draw')
end
local unknown,why=Draws.card({blind={key='bl_wheel'}},{ability={}})
check(unknown==nil and why:find('sampled outcome',1,true),'Wheel without supplied outcome remains unsupported')
print('visibility_contract_probe: '..checks..' checks passed; two current gaps reproduced, no fix applied')

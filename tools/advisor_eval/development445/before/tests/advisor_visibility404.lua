local P='Brainstorm/Advisor/';local S=dofile(P..'snapshot.lua');local D=dofile(P..'draws.lua');local J=dofile(P..'player_journal.lua')
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local function live(rank)
 return {playing_card=1,base={id=rank,nominal=10,suit='Clubs'},config={center={key='c_base',set='Default'}},
 ability={},facing='front',sprite_facing='back',flipping='b2f',pinch={x=true}}
end
local a,b=live(13),live(2)
local ca,cb=S.card(a),S.card(b)
check(ca.face_down and cb.face_down and not S.presentation_settled(a),'unsettled backs stay concealed')
check(S.fingerprint(J.public_snapshot({hand={ca}}))==S.fingerprint(J.public_snapshot({hand={cb}})),'same visible backs have identical public observations')
a.sprite_facing='front';a.pinch.x=false
check(S.presentation_settled(a) and not S.card(a).face_down,'settled front may expose identity')
for _,key in ipairs({'bl_fish','bl_wheel','bl_house','bl_mark'}) do
 local s={blind={key=key,prepped=true},hands_played=0,discards_used=0,jokers={},probabilities={normal=1}}
 local first
 for _,orientation in ipairs({true,false,'missing'}) do
  local source={id='draw404',rank=13,suit='Clubs',ability={}}
  if orientation~='missing' then source.face_down=orientation end
  local before=S.fingerprint(source);local drawn=assert(D.card(s,source,0))
  check(drawn.face_down and drawn.ability.wheel_flipped,key..' concealment owns new orientation')
  check(S.fingerprint(source)==before,'draw input unchanged')
  if first then check(S.fingerprint(first)==S.fingerprint(drawn),'equivalent draw-source orientations agree') end;first=drawn
 end
 s.blind.disabled=true
 check(not D.card(s,{rank=13,face_down=true,ability={}},0).face_down,'disabled blind permits reveal')
end
check(not D.card({blind={key='bl_wheel'}},{ability={}}),'unknown Wheel outcome remains unsupported')
local retained={id='retained',rank=2,face_down=true,ability={}}
local filled=assert(D.fill({hand={retained},hand_size=2,blind={},jokers={}},{{id='new',rank=3,face_down=true,ability={}}}))
check(filled.hand[1].face_down and not filled.hand[2].face_down,'retained hidden cards are not revealed by new-draw fix')
print('advisor_visibility404: '..checks..' checks passed')

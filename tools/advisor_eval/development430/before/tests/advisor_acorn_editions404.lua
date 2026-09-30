-- Small manufactured snapshot-to-Acorn integration; hidden identity is poisoned.
local P='Brainstorm/Advisor/'
local Snap=dofile(P..'snapshot.lua');local B=dofile(P..'acorn_belief.lua')
local O=dofile(P..'acorn_ordering.lua');local S=dofile(P..'scoring.lua');local D=dofile(P..'decision.lua')
local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
local function forbidden()error('Hidden identity or ordinary fallback was accessed')end
local belief=assert(B.start({{key='j_joker',ability={name='Joker',mult=4},blueprint_compat=true}},'synthetic404',{public_before_shuffle=true}))
local function state(edition)
 local live={playing_card=1,base={id=4,nominal=4,suit='Clubs'},ability={},edition=edition,
  config={center={key='c_base',set='Default'}},facing='front',sprite_facing='front'}
 return {phase='hand',hand={Snap.card(live)},hands={},deck={},playing_cards={},
  jokers={setmetatable({face_down=true},{__index=forbidden})},public_joker_belief=belief,
  hands_left=2,discards_left=1,hand_limit=5,chips=0,dollars=0,
  blind={key='bl_final_acorn',chips=1000000},consumeables={},probabilities={normal=1},modifiers={}}
end
for _,case in ipairs({{'holo','mult',10},{'foil','chips',50},{'polychrome','x_mult',1.5}}) do
 local flag,field,value=case[1],case[2],case[3]
 local plain=state({[flag]=true,type=flag})
 local canonical=assert(O.suggest(plain,belief,S,B,{max_evaluations=8,max_order_evaluations=0}))
 for _,e in ipairs({{[flag]=true,type=flag,[field]=value},{type=flag},flag}) do
  local s=state(e);local before=Snap.fingerprint(s.hand)
  local result,work,diag=O.suggest(s,belief,S,B,{max_evaluations=8,max_order_evaluations=0})
  check(result and diag.complete and work==1,'equivalent '..flag..' representation admitted completely')
  check(Snap.fingerprint(result.play)==Snap.fingerprint(canonical.play),'representation has identical score evidence')
  check(Snap.fingerprint(s.hand)==before,'public snapshot preserved')
 end
end
for _,bad in ipairs({{holo=true,mult=11},{holo=true,mult=0/0},{holo=true,mult=math.huge},
 {holo=true,mult='10'},{holo=true,foil=true},{holo=true,type='foil'},
 {holo=false,type='holo'},{holo=true,custom=1},{holo=true,chips=50},{mult=10},{type='custom'}}) do
 local result,work=O.suggest(state(bad),belief,S,B,{max_evaluations=8,max_order_evaluations=0})
 check(not result and work==0,'malformed/custom edition refused before scoring')
end
local modules={acorn_belief=B,acorn_ordering=O,scoring=S,search={run=forbidden},
 concealed_belief={run=forbidden},score_cache={new=forbidden},strategy={advise=forbidden}}
local result=D.run(state({holo=true,mult=10,type='holo'}),modules,function()end,{acorn_ordering={max_evaluations=8,max_order_evaluations=0}})
check(result and result.action and result.action.kind=='play','real captured edition reaches public-belief decision action')
local missing=state({holo=true,mult=10});missing.public_joker_belief=nil
check(not D.run(missing,modules).action,'missing public belief still refuses hidden fallback')
print('advisor_acorn_editions404: '..checks..' checks passed')

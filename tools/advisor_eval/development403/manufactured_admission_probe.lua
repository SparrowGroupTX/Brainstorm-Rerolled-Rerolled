-- Fresh small manufactured abstractions, never reconstructed captured states.
-- Existing-gap witnesses only; no runtime repair or full-run claim.
local p='Brainstorm/Advisor/'
local B=dofile(p..'acorn_belief.lua')
local O=dofile(p..'acorn_ordering.lua')
local S=dofile(p..'scoring.lua')
local Q=dofile(p..'search.lua')
local Snap=dofile(p..'snapshot.lua')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function forbidden() error('No live RNG or hidden identity access permitted') end
math.random,math.randomseed=forbidden,forbidden
local function card(id,rank,suit,enh)
 return {id='synthetic403:'..id,rank=rank,nominal=math.min(rank,10),suit=suit,
   enhancement=enh or 'c_base',ability=enh=='m_lucky' and {mult=20,p_dollars=20} or {}}
end
local b=assert(B.start({{key='j_joker',ability={name='Joker',mult=4},blueprint_compat=true}},
 'manufactured403',{public_before_shuffle=true}))
local hidden=setmetatable({face_down=true},{__index=forbidden})
local acorn={phase='hand',hand={card('a',4,'Clubs')},deck={},playing_cards={},hands={},jokers={hidden},
 public_joker_belief=b,hands_left=2,discards_left=1,hand_limit=5,chips=0,dollars=10,
 blind={key='bl_final_acorn',chips=1000000},probabilities={normal=1},consumeables={},modifiers={}}
for _,case in ipairs({{'holo','mult',10},{'foil','chips',50},{'polychrome','x_mult',1.5}}) do
 local flag,field,value=case[1],case[2],case[3]
 acorn.hand[1].edition={[flag]=true,type=flag}
 local original=Snap.fingerprint(acorn.hand)
 local result,work,diag=O.suggest(acorn,b,S,B,{max_evaluations=8,max_order_evaluations=0})
 check(result and diag.complete and work>0,flag..' flag representation admitted')
 check(Snap.fingerprint(acorn.hand)==original,'comparison preserves manufactured hand')
 acorn.hand[1].edition[field]=value
 local rejected,count,why=O.suggest(acorn,b,S,B,{max_evaluations=8,max_order_evaluations=0})
 check(not rejected and count==0 and why.reason=='Unknown playing-card edition effect.',
  'CURRENT GAP: source-shaped '..flag..' rejected before scoring')
end
acorn.hand[1].edition={holo=true,custom_unknown=1}
local rejected,_,diag=O.suggest(acorn,b,S,B,{max_evaluations=8,max_order_evaluations=0})
check(not rejected and diag.reason=='Unknown playing-card edition effect.','unknown edition remains declined')

-- Pair nines has an independent deterministic score (10+9+9)*2=56.
-- The Lucky King mean is (5+10)*(1+20/5)=75, but its no-trigger score is15.
-- Three inert held cards allow three possible Hook pairs; none affect scoring.
local hook={phase='hand',hand={card('k',13,'Spades','m_lucky'),card('n1',9,'Clubs'),
 card('n2',9,'Diamonds'),card('four',4,'Hearts'),card('two',2,'Spades')},
 deck={},playing_cards={},hands={},jokers={},consumeables={},hands_left=1,discards_left=0,
 hand_limit=5,hand_size=5,chips=0,dollars=0,blind={key='bl_hook',chips=50},
 probabilities={normal=1},modifiers={},current_round={}}
for i,c in ipairs(hook.hand) do hook.playing_cards[i]=c end
local original=Snap.fingerprint(hook)
local pair=S.score(hook,{2,3});local king=S.score(hook,{1});local floor=S.lower_bound(hook,{2,3})
check(pair.score==56 and king.score==75,'independent arithmetic agrees with detached means')
check(not floor.reliable_bound and floor.uncertain,'CURRENT GAP: inert Hook still blocks Pair certification')
local result=Q.run(hook,S,{max_evaluations=1000,fast_clear=false},function() end)
check(result and result.kind=='play' and result.play and #result.play.indices==1 and result.play.indices[1]==1,
 'CURRENT GAP: Lucky average beats invariant clearing Pair')
check(result.evaluations<=1000,'manufactured search respects caller allowance')
check(Snap.fingerprint(hook)==original,'manufactured input unchanged')
print('manufactured_admission_probe: '..checks..' checks passed; Acorn metadata and Hook floor gaps reproduced, no fix applied')

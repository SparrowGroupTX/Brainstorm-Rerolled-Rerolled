-- Manufactured states only; no captured policy/scorer evaluation or source game.
local D=dofile(ADVISOR_DECISION_PATH or 'Brainstorm/Advisor/decision.lua')
local C=dofile('Brainstorm/Advisor/consumables.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local S=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function state(n)
 local s={phase='hand',ante=4,chips=0,dollars=20,hand={},deck={},playing_cards={},jokers={},
  consumeables={{id='empress',key='c_empress',ability={consumeable={}}}},
  blind={key='bl_serpent',name='The Serpent',chips=1000000},hands={},modifiers={},current_round={},
  probabilities={normal=1},hand_limit=5,hand_size=8,hands_left=3,hands_played=1,
  discards_left=3,discards_used=0,consumable_limit=2}
 for i=1,n do s.hand[i]={id='h'..i,rank=2+(i-1)%13,nominal=math.min(10,2+(i-1)%13),
  suit=({'Spades','Hearts','Clubs','Diamonds'})[(i-1)%4+1],enhancement='c_base',ability={}}
  s.playing_cards[#s.playing_cards+1]=s.hand[i] end
 for i=1,16 do s.deck[i]={id='d'..i,rank=2+(i-1)%13,nominal=math.min(10,2+(i-1)%13),
  suit=({'Hearts','Clubs','Diamonds','Spades'})[(i-1)%4+1],enhancement='c_base',ability={}}
  s.playing_cards[#s.playing_cards+1]=s.deck[i] end
 return s
end
local function cost(n,k)local t,v=1,0;for i=1,math.min(n,k)do t=t*(n-i+1)/i;v=v+t end;return v end
math.random=function()error('uncontrolled RNG')end
pseudorandom=math.random

local old=dofile('tools/advisor_eval/development360/decision.before.lua')
for _,n in ipairs({8,12,14,20})do
 for _,mode in ipairs({'owned','empty','unsupported'})do
  local s=state(n)
  if mode=='empty' then s.consumeables={} elseif mode=='unsupported' then s.consumeables[1].ability.consumeable.mod_conv='m_bonus' end
  local fingerprint=Snapshot.fingerprint(s)
  for _,policy in ipairs({{'before',old},{'after',D}})do
   local start=os.clock()
   local result=policy[2].run(s,{search=Search,scoring=Score,consumables=C,strategy=S})
   local diag=result.consumable_diagnostics or {}
   local selected=result.consumable and result.consumable.play or result.play or {}
   print(table.concat({n,mode,policy[1],string.format('%.6f',os.clock()-start),result.evaluations or 0,
    result.action and result.action.kind or 'none',selected.score or 0,diag.evaluated_candidates or 0,
    result.discard and result.discard.mean or 0,result.discard and result.discard.probability or 0},'|'))
   check(result.evaluations<=140000,'fixed total budget')
   eq(Snapshot.fingerprint(s),fingerprint,'unchanged manufactured state')
  end
 end
end

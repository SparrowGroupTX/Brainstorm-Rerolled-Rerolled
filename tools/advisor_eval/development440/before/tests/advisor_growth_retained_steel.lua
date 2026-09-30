local Growth=dofile('Brainstorm/Advisor/growth.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local modules={scoring=Scoring,strategy=Strategy,search=Search}
local checks=0
local function check(value,label) checks=checks+1;assert(value,label) end
local function eq(actual,expected,label) check(actual==expected,label..': '..tostring(actual)..' ~= '..tostring(expected)) end

-- Yorick is one card from a level, but the clear depends on held Steel.
-- Every largest low-index batch removes Steel. A physically different discard
-- of the same category/count can retain it; category equality is not a score
-- certificate. These are complete synthetic states, not sampled source runs.
local s={phase='hand',ante=1,blind={chips=32000},chips=0,hands_left=3,hands_played=0,
  discards_left=3,discards_used=0,current_round={},dollars=20,hand_size=8,hand_limit=5,
  modifiers={},jokers={{key='j_yorick',ability={name='Yorick',x_mult=10,
    yorick_discards=1,extra={discards=23,xmult=1}}}},hand={},deck={},playing_cards={},
  hands={['High Card']={level=21,chips=105,mult=21,l_chips=5,l_mult=1,played=20}},
  consumeables={},probabilities={normal=1}}
for i=1,8 do
  local c={id='h'..i,rank=i==1 and 14 or i,suit='Spades',
    enhancement=i==2 and 'm_steel' or 'c_base',ability={}}
  s.hand[i]=c;s.playing_cards[i]=c
end
local before=Snapshot.fingerprint(s)
local clear=Scoring.score(s,{1});clear.indices={1}
eq(clear.score,36540,'exact initial Steel-dependent clear')
local without_steel=Scoring.after_discard(s,{2})
check(Scoring.score(without_steel,{1}).score<s.blind.chips,
  'even exact Yorick growth does not replace lost Steel')
local safe=Scoring.after_discard(s,{3})
eq(Scoring.score(safe,{1}).score,40194,'same-count alternative keeps the exact clear')

local score,calls=Scoring.score,0
Scoring.score=function(...) calls=calls+1;return score(...) end
local growth,evaluations,diagnostics=Growth.suggest(s,modules,clear,{max_evaluations=6})
Scoring.score=score
check(growth~=nil,'bounded shortlist retains a safe physical discard alternative')
eq(growth.action.kind,'discard','selected action invests the actual remaining discard')
eq(#growth.action.indices,1,'one card reaches Yorick threshold while holding Steel')
for _,index in ipairs(growth.action.indices) do
  check(index~=1 and index~=2,'reserve both the clearing Ace and held Steel')
end
eq(growth.growth.effects.yorick_growth,1,'exact single Yorick increment')
eq(growth.growth.remaining_discards,2,'actual remaining discards')
local after=Scoring.after_discard(s,growth.action.indices)
eq(after.jokers[1].ability.x_mult,11,'physical Yorick multiplier advances once')
eq(after.jokers[1].ability.yorick_discards,23,'physical Yorick counter resets exactly')
eq(Scoring.score(after,growth.play.indices).score,40194,'retained finish requires no replacement draw')
eq(#after.deck,0,'no favorable replacement population exists')
eq(Snapshot.fingerprint(s),before,'input is unchanged')
check(calls<=6 and evaluations<=6 and diagnostics.max_evaluations==6,'caller cap is unchanged')
eq(calls,evaluations,'all exact score calls are reported')
local again=Growth.suggest(s,modules,clear,{max_evaluations=6})
eq(Snapshot.fingerprint(again),Snapshot.fingerprint(growth),'same input has deterministic action and evidence')
local capped,capped_calls=Growth.suggest(s,modules,clear,{max_evaluations=0})
eq(capped,nil,'zero caller budget cannot bypass exact retained-score verification')
eq(capped_calls,0,'zero caller budget performs no scores')
print('advisor growth retained Steel: '..checks..' checks passed')

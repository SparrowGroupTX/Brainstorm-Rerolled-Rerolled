-- Optional development comparison; not a production regression dependency.
-- Only manufactured ordinary Lua tables and an instrumented zero-score mock.
local baseline=dofile('tools/advisor_eval/development334/before/consumables.lua')
local candidate=dofile('Brainstorm/Advisor/consumables.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local hand,inventory={},{}
for i=1,8 do hand[i]={id='hand:'..i,rank=i+1,nominal=i+1,suit='Spades',enhancement='c_base',ability={}} end
for i=1,10 do inventory[i]={id='death:'..i,key='c_death',name='Death',
  edition={negative=true,type='negative'},cost=8,sell_cost=4,debuff=false,face_down=false,
  ability={name='Death',set='Tarot',consumeable={}}} end
local s={phase='hand',hand=hand,playing_cards=hand,deck={},jokers={},consumeables=inventory,
  hands={},blind={chips=130},chips=0,dollars=20,hands_left=1,hands_played=0,
  hand_limit=5,hand_size=8,discards_left=0,discards_used=0,modifiers={},ante=2,
  consumable_limit=12,probabilities={normal=1},current_round={hands_left=1,hands_played=0,discards_left=0},
  consumeable_usage_total={tarot=0,planet=0,spectral=0,all=0,tarot_planet=0}}
local before=Snapshot.fingerprint(s)
local function run(module)
  local calls,seen=0,{}
  local scorer={score=function(after)
    calls=calls+1
    local left,right
    for i,c in ipairs(after.hand) do if c.rank~=s.hand[i].rank then left=i;right=c.rank-1 end end
    seen[left..':'..right]=true
    return {score=0,hand='High Card',legal=true,uncertain=false,warnings={}}
  end}
  local action,evaluations,d=module.suggest(s,scorer,{play={score=0,hand='High Card',indices={1},legal=true}},nil,{sequences=false})
  assert(action==nil and evaluations==calls and Snapshot.fingerprint(s)==before)
  local targets=0;for _ in pairs(seen) do targets=targets+1 end
  return evaluations,targets,d
end
local old_calls,old_targets,old_d=run(baseline)
local new_calls,new_targets,new_d=run(candidate)
assert(old_calls==24852 and old_targets==12 and old_d.evaluated_candidates==114 and old_d.truncated)
assert(new_calls==6104 and new_targets==28 and new_d.evaluated_candidates==28 and not new_d.truncated)
print('duplicate_death_comparison: baseline_scores='..old_calls..' candidate_scores='..new_calls..
  ' baseline_distinct_targets='..old_targets..' candidate_distinct_targets='..new_targets..
  ' baseline_complete_candidates='..old_d.evaluated_candidates..' candidate_complete_candidates='..new_d.evaluated_candidates)

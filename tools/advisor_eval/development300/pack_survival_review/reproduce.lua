-- Counterexamples to the frozen reviewed draft, not desired production tests.
-- Synthetic receipts only; no game/source/native/scoring work.
local M=dofile('tools/advisor_eval/development300/pack_survival_review/reviewed_pack_survival.lua')
local checks=0
local function check(v,label)checks=checks+1;assert(v,label)end
local function copy(t)if type(t)~='table'then return t end;local out={};for k,v in pairs(t)do out[k]=copy(v)end;return out end
local function row(clear,reward)
  local score=clear and 100 or 90
  return {clear=clear,score=score,shortfall=100-score,progress=score/100,hands_used=1,discards_used=0,
    setup_actions=0,action_count=1,dollars_after=20,population_loss=0,finish_reward=reward,
    actions={{kind='play'}},resources={cash_components=25,blue_planets=1,planet_hand='Pair',planet_utility=10,
      survivors={one=true,two=true},levels={Pair={level=2,chips=25,mult=3}},played={Pair=true},leaders='Pair'}}
end
local function finishing(clears,reward)
  local f={complete=true,supported=true,known_mechanics=true,policies={}}
  for _,name in ipairs({'play_only','one_targeted_discard'})do
    local p={name=name,worlds={},clearing_samples=clears}
    for i=1,4 do p.worlds[i]=row(i<=clears,reward)end
    f.policies[#f.policies+1]=p
  end
  f.selected=f.policies[1];return f
end
local function fixture(change)
  local before=finishing(0,0)
  local a={index=1,score=100,card={key='j_joker',ability={set='Joker'}}}
  local b={index=2,score=10,card={key='j_zany',ability={set='Joker'}}}
  for _,c in ipairs({a,b})do
    c.scoring_evidence={complete_finishing=true,samples=4,before_target=100,after_target=100,
      before_finishing=copy(before),after_finishing=finishing(c==a and 3 or 4,c==a and 10 or 12)}
  end
  for _,p in ipairs(b.scoring_evidence.after_finishing.policies)do for _,world in ipairs(p.worlds)do change(world)end end
  local s={phase='pack',pack_type='BUFFOON_PACK',pack_choices=1,_shop_scoring={},
    pack_cards={a.card,b.card},joker_limit=5,jokers={},consumeables={},consumeable_buffer=0,
    dollars=20,bankrupt_at=0,next_blind={chips=100}}
  local selected,d=M.choose(s,{a,b},a,{})
  return selected,b,d
end
for _,case in ipairs({
  {'lost Blue count',function(w)w.resources.blue_planets=0;w.resources.planet_utility=0 end},
  {'changed Blue target hand',function(w)w.resources.planet_hand='High Card' end},
  {'lost physical survivor',function(w)w.resources.survivors.two=nil end},
  {'lost developed hand level',function(w)w.resources.levels.Pair.level=1 end},
  {'worse known cash component',function(w)w.resources.cash_components=15 end},
  {'missing resource receipt',function(w)w.resources=nil end},
})do
  local selected,expected,d=fixture(case[2])
  check(selected==expected and d.complete==true,'Reviewed draft accepts unsupported no-worse-resource claim: '..case[1])
end
print('Pack survival review: '..checks..' resource counterexamples reproduced in frozen draft')

local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Ordering=dofile('Brainstorm/Advisor/ordering.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local checks=0
local function check(value,label) assert(value,label);checks=checks+1 end
local function state(hands,inventory,target)
  local hand={{id='order-a',rank=14,suit='Hearts',nominal=11,ability={}},
    {id='order-b',rank=14,suit='Spades',nominal=11,ability={}}}
  return {phase='hand',hand=hand,playing_cards=hand,deck={},hands={},
    jokers={{key='j_duo',name='The Duo',ability={name='The Duo',type='Pair',x_mult=2}},
      {key='j_joker',name='Joker',ability={name='Joker',mult=4}}},
    consumeables=inventory or {},consumable_limit=2,joker_limit=5,
    blind={chips=target or 1000},chips=0,dollars=10,hands_left=hands,discards_left=0,
    hand_limit=5,hand_size=2,ante=3,modifiers={},probabilities={normal=1},
    current_round={hands_left=hands,discards_left=0,hands_played=0}}
end
local s=state(1)
local base=Search.run(s,Scoring)
check(base.play.score==256,'the current row has a supported losing play')
local suggested,_,diag=Ordering.suggest(s,Scoring,base)
check(suggested and suggested.play.score==384,'a losing score alone does not certify every joint reorder outcome')
check(diag.completed_orders==2,'both legal Joker orders are completely compared')
s=state(2);base=Search.run(s,Scoring)
suggested=Ordering.suggest(s,Scoring,base)
check(suggested and suggested.play.score==384,'a useful nonfinal score improvement is retained')
s=state(1,nil,300);base=Search.run(s,Scoring)
suggested=Ordering.suggest(s,Scoring,base)
check(suggested and suggested.play.score==384,'a final-hand reorder that clears is retained')
s=state(1);s.jokers[2]={key='j_misprint',name='Misprint',ability={name='Misprint',extra={min=0,max=23}}}
base=Search.run(s,Scoring);suggested=Ordering.suggest(s,Scoring,base)
check(suggested and suggested.play.uncertain,'a losing random mean is not treated as a certain final loss')
s=state(1,nil,1200);s.jokers[3]={key='j_mr_bones',name='Mr. Bones',ability={name='Mr. Bones'}}
base=Search.run(s,Scoring);suggested=Ordering.suggest(s,Scoring,base)
check(base.play.score<300 and suggested and suggested.play.score>=300,
  'an active death-save Joker retains a reorder that reaches its quarter-target survival threshold')
local modules={scoring=Scoring,score_cache=dofile('Brainstorm/Advisor/score_cache.lua'),
  search=Search,consumables=dofile('Brainstorm/Advisor/consumables.lua'),
  strategy=dofile('Brainstorm/Advisor/strategy.lua'),ordering=Ordering,
  hand_ordering=dofile('Brainstorm/Advisor/hand_ordering.lua'),
  boss_rescue=dofile('Brainstorm/Advisor/boss_rescue.lua'),
  mixed_rescue=dofile('Brainstorm/Advisor/mixed_rescue.lua')}
s=state(1,{{key='c_emperor',name='The Emperor',ability={name='The Emperor',set='Tarot',consumeable={tarots=2}}}})
local result=Decision.run(s,modules)
check(result.consumable and result.consumable.generator,'the full decision has a complete losing-play certificate')
check(result.action.kind=='use','an ineffective rearrangement does not displace the public generator reveal')
check(not result.ordering,'no ineffective reorder action is presented')
s=state(1);s.hand[1].enhancement='m_glass';s.hand[2].enhancement='m_mult'
check(Scoring.score(s,{1,2}).score==640 and Scoring.score(s,{2,1}).score==896,
  'neither current-row played-card order clears the joint-reorder counterexample')
result=Decision.run(s,modules)
check(result.action.kind=='reorder_jokers' and result.ordering.play.score==768,
  'a nonclearing Joker reorder remains available when it enables a later card-order rescue')
s.jokers={s.jokers[2],s.jokers[1]}
check(Scoring.score(s,{2,1}).score==1024,'the joint Joker and played-card reorder clears')
result=Decision.run(s,modules)
check(result.action.kind=='reorder_hand' and result.hand_ordering.play.score==1024,
  'normal refreshed advice exposes the second step of the supported joint rescue')
s=state(1,nil,1);result=Decision.run(s,modules)
check(result.fast_clear and result.evaluations<=70,'fast-clear work stays within its existing allowance')
print('advisor_final_order_priority: '..checks..' checks passed')

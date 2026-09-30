-- Regression for C01's stacked ordinary/search/owned-consumable/order work.
-- No original game source, profile, RNG state, or captured state is loaded.
local D=dofile('tools/advisor_eval/development299/drafts/decision_budget/decision.lua')
local checks=0
local function check(v,message) assert(v,message);checks=checks+1 end
local function copy(t) local out={};for k,v in pairs(t) do out[k]=v end;return out end

do
  -- A complete incumbent must survive when later comparisons do not fit.
  -- Their normal independent caps previously took 140,000 past the limit.
  local requested,spent={},0
  local incumbent={kind='play',area='hand',indices={1}}
  local base_work=139997
  local modules={scoring={},search={run=function()
    spent=base_work
    return {kind='play',play={indices={1},score=1},evaluations=base_work}
  end}}
  local function specialist(name,required)
    return {suggest=function(_,_,_,_,options)
      requested[name]=copy(options)
      if options.max_evaluations<required then return nil,0,{complete=false} end
      spent=spent+required;return nil,required,{complete=true}
    end}
  end
  modules.consumables=specialist('consumables',2)
  modules.ordering=specialist('ordering',2)
  modules.hand_ordering=specialist('hand_ordering',2)
  modules.boss_rescue=specialist('boss_rescue',2)
  modules.mixed_rescue=specialist('mixed_rescue',2)
  modules.multi_discard=specialist('multi_discard',1)
  local state={phase='hand',hand={{}},consumeables={{}},jokers={{},{}},hands_left=1}
  local options={ordering={max_orders=23},consumables={max_evaluations=25000,max_development_evaluations=6}}
  local result=D.run(state,modules,nil,options)
  check(result.action.kind==incumbent.kind and result.action.indices[1]==1,'incomplete specialists preserve the fully evaluated incumbent')
  check(result.evaluations==140000 and spent==140000,'all admitted specialist work stays within one ordinary allowance')
  check(requested.consumables.max_evaluations==3 and requested.consumables.max_development_evaluations==3,
    'owned consumable subset and known-clear development paths share the same remainder')
  check(requested.ordering.max_evaluations==1 and requested.ordering.max_orders==23,'ordering keeps caller shortlist options but cannot renew the budget')
  check(requested.hand_ordering.max_evaluations==1 and requested.boss_rescue.max_evaluations==1 and
    requested.mixed_rescue.max_evaluations==1 and requested.multi_discard.max_evaluations==1,'every late specialist sees only remaining work')
  check(options.ordering.max_evaluations==nil and options.consumables.max_development_evaluations==6,'caller configuration remains unchanged')

  base_work=140000;requested={};result=D.run(state,modules)
  check(spent==140000 and result.evaluations==140000,'a full ordinary search starts no additional scored comparison')
  check(requested.consumables.max_development_evaluations==0,'known-clear consumable development cannot bypass an exhausted shared cap')
  base_work=0;requested={};result=D.run(state,modules,nil,{consumables={max_evaluations=1},ordering={max_evaluations=999999}})
  check(requested.consumables.max_evaluations==1 and requested.ordering.max_evaluations==30000,'smaller user limits and existing local maximums remain enforced')
  check(requested.hand_ordering.max_evaluations==10000 and requested.boss_rescue.max_evaluations==10000 and
    requested.mixed_rescue.max_evaluations==1500 and requested.multi_discard.max_evaluations==12000,'independent specialist limits are not increased')

  modules.resource_finish=specialist('resource_finish',1)
  modules.resource_finish.admits=function(s) return s.hands_left==5 end
  modules.two_hand_finish=specialist('two_hand_finish',1)
  base_work=139999;state.consumeables={};state.jokers={};modules.hand_ordering=nil;modules.boss_rescue=nil;modules.mixed_rescue=nil
  state.hands_left=5;requested={};result=D.run(state,modules)
  check(requested.resource_finish.max_evaluations==1 and not requested.two_hand_finish and not requested.multi_discard,
    'broader resource branch shares the remainder without stacking old finishing branches')
  state.hands_left=2;requested={};result=D.run(state,modules)
  check(requested.two_hand_finish.max_evaluations==1 and not requested.resource_finish and not requested.multi_discard,
    'two-hand branch receives the same shared remaining allowance')
end

do
  -- Exercise the real complete common-subset order comparison at its boundary.
  local scoring=dofile('Brainstorm/Advisor/scoring.lua')
  local ordering=dofile('Brainstorm/Advisor/ordering.lua')
  local calls=0;local base_score=scoring.score
  scoring.score=function(...) calls=calls+1;return base_score(...) end
  local s={phase='hand',hand={{id='a',rank=10,nominal=10,suit='Spades',ability={}},
    {id='b',rank=10,nominal=10,suit='Hearts',ability={}}},deck={},playing_cards={},consumeables={},
    jokers={{key='j_cavendish',ability={name='Cavendish',extra={Xmult=3}}},
      {key='j_joker',ability={name='Joker',mult=4}},{key='j_popcorn',ability={name='Popcorn',mult=20}}},
    hands={Pair={level=1,chips=10,mult=2},['High Card']={level=1,chips=5,mult=1}},
    hands_left=4,discards_left=0,hand_size=2,hand_limit=5,chips=0,dollars=0,blind={key='bl_small',chips=10000},
    probabilities={normal=1},current_round={},modifiers={},round_resets={}}
  local work=139995
  local modules={scoring=scoring,ordering=ordering,search={run=function(state)
    local play=base_score(state,{1,2});play.indices={1,2}
    return {kind='play',play=play,evaluations=work}
  end}}
  local result=D.run(s,modules)
  check(calls==0 and not result.ordering,'five remaining scores cannot start two complete three-subset orders')
  check(result.evaluations==139995 and result.ordering_diagnostics.completed_orders==0,'no partial order outcome can displace the incumbent')
  work=139982;calls=0;result=D.run(s,modules)
  check(calls==18 and result.evaluations==140000,'six actual orders each score the same three subsets exactly at the shared limit')
  check(result.ordering_diagnostics.completed_orders==6 and result.ordering_diagnostics.partial_orders==0,
    'the complete feasible order comparison is still available')
  check(result.action.kind=='reorder_jokers' and result.ordering.play.score>result.play.score,'a fully compared useful copy/scoring order can still win')
end

print('advisor_decision_budget: '..checks..' checks passed')

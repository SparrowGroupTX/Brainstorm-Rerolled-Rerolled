local D=dofile('Brainstorm/Advisor/decision.lua')
local modules={scoring=dofile('Brainstorm/Advisor/scoring.lua'),search=dofile('Brainstorm/Advisor/search.lua'),
  consumables=dofile('Brainstorm/Advisor/consumables.lua'),ordering=dofile('Brainstorm/Advisor/ordering.lua')}
modules.hand_ordering=dofile('Brainstorm/Advisor/hand_ordering.lua')
modules.boss_rescue=dofile('Brainstorm/Advisor/boss_rescue.lua')
local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
local s={phase='hand',hand={{id='ace',rank=14,suit='Spades',ability={}}},deck={},playing_cards={},
  jokers={{key='j_cavendish',ability={extra=3}},{key='j_popcorn',ability={mult=12}}},
  joker_limit=5,consumeables={{key='c_pluto',ability={set='Planet',consumeable={hand_type='High Card'}}},
    {key='c_empress',ability={set='Tarot',consumeable={max_highlighted=2}}}},
  hand_size=1,hand_limit=5,hands_left=1,discards_left=0,dollars=0,chips=0,
  hands={['High Card']={level=1,chips=5,mult=1,l_chips=10,l_mult=1}},
  blind={key='bl_small',chips=700},probabilities={normal=1},modifiers={},current_round={},round_resets={}}
s.playing_cards={s.hand[1]}
local result=D.run(s,modules)
check(result.consumable and result.consumable.sequence,'real decision discovers the two-consumable rescue')
check(result.consumable.play.score<700 and result.consumable.sequence.play.score>=700,
  'immediate and completed-sequence scores are correctly distinguished')
check(not result.ordering,'a nonclearing Joker reorder cannot displace the consumable sequence clear')
check(result.action.kind=='use' and result.action.index==1,'only first consumable is executed')
local after=assert(modules.consumables.apply(s,1,{}))
local next=D.run(after,modules)
check(next.ordering and next.ordering.play.score>=700,
  'fresh advice may save the second consumable when reordering now clears immediately')
check(#after.consumeables==1,'the projected second use is never automatically executed')
s.jokers={};s.blind.chips=100
result=D.run(s,modules)
check(result.consumable and result.consumable.sequence,'without the reorder shortcut the two-use plan is retained')
after=assert(modules.consumables.apply(s,result.action.index,result.action.targets))
next=D.run(after,modules)
check(next.action.kind=='use' and next.action.index==1 and next.action.targets[1]==1,
  'fresh advice performs the shifted second consumable action before playing')
after=assert(modules.consumables.apply(after,next.action.index,next.action.targets))
next=D.run(after,modules)
check(next.action.kind=='play' and next.play.score>=100,'completed sequence actually yields its clearing play')
modules.mixed_rescue=dofile('Brainstorm/Advisor/mixed_rescue.lua')
modules.strategy=dofile('Brainstorm/Advisor/strategy.lua')
s.hand[1].rank=14;s.hand[1].nominal=11;s.blind.chips=350
s.jokers={{key='j_cavendish',id='j1',ability={name='Cavendish',extra={Xmult=3}}},
  {key='j_joker',id='j2',ability={name='Joker',mult=4}}}
s.consumeables={{key='c_pluto',ability={set='Planet',consumeable={hand_type='High Card'}}}}
result=D.run(s,modules)
check(result.mixed_rescue and result.action.kind=='reorder_jokers','whole decision discovers joint use/reorder rescue')
s.jokers={s.jokers[result.action.order[1]],s.jokers[result.action.order[2]]}
next=D.run(s,modules)
check(not next.mixed_rescue and next.action.kind=='use','fresh decision advances from reorder to use')
after=assert(modules.consumables.apply(s,next.action.index,next.action.targets))
next=D.run(after,modules)
check(next.action.kind=='play' and next.play.score>=350,'fresh final step plays the proven joint clear')
do
  local called=0
  local route={advice=function(state)
    if state.filter_info then return {title='Verified route',action={kind='skip_blind',blind='Small'}} end
  end}
  local dependencies={jokerless_opening=route,blind_prep={suggest=function() called=called+1 end},
    strategy={advise=function() return {title='ordinary',action={kind='select_blind',blind='Big'}} end}}
  local routed=D.run({phase='blind',filter_info={}},dependencies)
  check(routed.action.kind=='skip_blind' and called==0,'explicit opening advice is authoritative before generic preparation')
  local ordinary=D.run({phase='blind'},dependencies)
  check(ordinary.action.kind=='select_blind' and called==1,'absent recipe preserves ordinary strategy path')
end
do
  local counts={resource=0,old=0,multi=0}
  local first={kind='play',area='hand',indices={1}}
  local dependencies={scoring={},search={run=function()
      return {kind='discard',play={score=1,indices={1}},discard={indices={1}},evaluations=7}
    end},resource_finish={admits=function(state) return state.hands_left==5 end,
      suggest=function() counts.resource=counts.resource+1
        return {action=first,indices={1},horizon=5},11,{complete=true}
      end},two_hand_finish={suggest=function() counts.old=counts.old+1;return nil,3,{} end},
    multi_discard={suggest=function() counts.multi=counts.multi+1;return nil,2,{} end}}
  local observed={phase='hand',hands_left=5,consumeables={},jokers={}}
  local result=D.run(observed,dependencies)
  check(result.action==first and result.two_hand_finish.horizon==5,'general resource plan publishes only its first action through protected specialist field')
  check(result.evaluations==18 and counts.resource==1 and counts.old==0 and counts.multi==0,
    'resource planner replaces the old specialist allowance instead of stacking calls')
  observed.hands_left=2;D.run(observed,dependencies)
  check(counts.old==1 and counts.resource==1 and counts.multi==0,'unadmitted small scope retains existing owned-upgrade finishing')
  observed.hands_left=1;D.run(observed,dependencies)
  check(counts.multi==1 and counts.resource==1,'last-hand redraw keeps its existing route')
  observed.hands_left=5;dependencies.search.run=function()
    return {kind='play',play={score=10,indices={1}},evaluations=1,fast_clear={}}
  end
  result=D.run(observed,dependencies)
  check(counts.resource==1 and result.fast_clear.specialists_skipped,'reliable fast clear never enters the new resource planner')
end
do
  local replace=true
  local original={kind='use',area='consumeables',index=1,targets={1}}
  local alternate={kind='discard',area='hand',indices={2}}
  local dependencies={scoring={},search={run=function()
      return {kind='discard',play={score=1,indices={1}},discard={indices={2}},evaluations=3}
    end},consumables={suggest=function() return {action=original},5,{} end},
    resource_finish={admits=function(_,passed)
        check(passed.consumables~=nil,'targeted admission receives the same ordinary consumable dependency')
        return true
      end,suggest=function(_,_,result)
        check(result.consumable.action==original,'resource comparison receives exact incumbent use')
        return {action=alternate,indices={2},replaces_consumable=replace},7,{complete=true}
      end}}
  local observed={phase='hand',hands_left=3,consumeables={{}},jokers={}}
  local r=D.run(observed,dependencies)
  check(r.action==alternate and r.consumable.action==original,'certified replacement publishes its first action and retains incumbent evidence')
  check(r.evaluations==15,'use and resource comparisons are charged once')
  replace=false;r=D.run(observed,dependencies)
  check(r.action==original,'unflagged specialist cannot displace the existing consumable priority')
end
do
  local calls,ordinary_calls=0,0
  local context={evaluations=7,max_evaluations=50000,truncated=false}
  local incumbent={title='Complete ordinary sequence',action={kind='sell',area='jokers',index=1}}
  local dependencies={strategy={advise=function()
      ordinary_calls=ordinary_calls+1;return {title='Base',action={kind='leave_shop'}}
    end,shortfall_reroll=function(_,base)
      check(base==incumbent,'goal integration follows the existing complete sequence and reroll decision')
    end},shop_scoring={new=function() return context end},
    shop_sequences={suggest=function() return incumbent,{complete=true} end},
    gold_goal={suggest=function(state,passed,base,shared)
      calls=calls+1
      check(base==incumbent and shared==context and passed.shop_sequences~=nil,'goal receives actual incumbent and shared context')
      shared.evaluations=shared.evaluations+5
      return {title='Goal',action={kind='buy',area='shop_jokers',index=1}},{complete=true}
    end}}
  local state={phase='shop'}
  local result=D.run(state,dependencies)
  check(calls==0 and result.strategy==incumbent,'opt-out source snapshots retain ordinary advice')
  state.completionist_goal={}
  result=D.run(state,dependencies)
  check(calls==1 and result.action.kind=='buy' and result.gold_diagnostics.complete,'completed goal first action enters the normal execution result')
  check(result.evaluations==12,'goal comparisons share the existing shop charge')
  dependencies.gold_goal.suggest=function()
    return {action={kind='buy'}},{complete=false}
  end
  result=D.run(state,dependencies)
  check(result.strategy==incumbent,'incomplete goal cannot replace the completed incumbent')
  dependencies.gold_goal.suggest=function(_,_,_,shared)
    shared.truncated=true;return {action={kind='buy'}},{complete=false}
  end
  result=D.run(state,dependencies)
  check(result.action.kind=='leave_shop' and result.strategy.warnings[1],'truncated goal retains the existing whole-decision fallback')
  check(result.evaluations<=50000,'integration never allocates another score allowance')
end
print('advisor_decision_integration: '..checks..' checks passed')

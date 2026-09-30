-- Synthetic common worlds; every selected play, discard and draw uses the real
-- detached mechanics. These are fixtures, not episodes or statistical samples.
local Finish=dofile('Brainstorm/Advisor/blind_finishing.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
for _,name in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do
  Finish[name]=dofile('Brainstorm/Advisor/'..name..'.lua')
end
Finish.strategy=Strategy
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function card(id,rank,suit)
  return {id=id,rank=rank,suit=suit,ability={},base={id=rank,nominal=rank==14 and 11 or math.min(10,rank)}}
end
local function worlds(options)
  options=options or {};local out={}
  for i=1,4 do
    local s={phase='hand',ante=2,dollars=options.cash or 4,bankrupt_at=0,hand_size=5,hand_limit=5,
      hands_left=4,discards_left=1,hands_played=0,hands_played_total=10,consumeables={},consumable_limit=2,
      jokers={},modifiers={},current_round={},round_resets={hands=4,discards=1},
      probabilities={normal=1},blind={key='bl_small',name='Small Blind',chips=60},chips=0,
      hands={['High Card']={level=1,chips=5,mult=1,l_chips=10,l_mult=1,played=10,visible=true},
        Flush={level=1,chips=35,mult=4,l_chips=15,l_mult=2,played=100,visible=true}}}
    s.hand={card('h1',2,'Hearts'),card('h2',4,'Hearts'),card('h3',6,'Hearts'),
      card('h4',8,'Hearts'),card('h5',12,'Clubs')}
    s.deck={card('d1',10,'Hearts'),card('d2',2,'Clubs'),card('d3',4,'Spades'),
      card('d4',6,'Diamonds'),card('d5',8,'Clubs'),card('d6',14,'Diamonds'),card('d7',11,'Spades')}
    s.playing_cards={};for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do
      s.playing_cards[#s.playing_cards+1]=Snapshot.copy(c)
    end end
    if options.change then options.change(s,i) end
    local opening=Scorer.score(s,{1,2,3,4,5});opening.indices={1,2,3,4,5}
    out[i]={state=s,opening_play=opening}
  end
  return out
end
-- Bound fixture work without changing the production module's family/budget.
local function run(input,limit)
  local calls=0
  local result=Finish.forecast(input,Scorer,function()
    if calls>=(limit or 10000) then return false end
    calls=calls+1;return true
  end)
  return result,calls
end
local old_random,old_seed=math.random,math.randomseed
math.random=function() error('Resource comparison touched game RNG') end
math.randomseed=function() error('Resource comparison reseeded game RNG') end
do
  local input=worlds();local before=Snapshot.fingerprint(input)
  local result,calls=run(input)
  check(result.complete and result.supported and #result.policies==2,'both fixed policies complete all common worlds')
  local baseline,changed=result.policies[1],result.policies[2]
  check(baseline.clearing_samples==4 and changed.clearing_samples==4,'both policies clear every world')
  check(baseline.mean_hands_used==4 and baseline.mean_discards_used==0,'baseline actually plays four hands')
  check(changed.mean_hands_used==1 and changed.mean_discards_used==1,'alternative actually discards once and plays once')
  check(result.selected.name=='one_targeted_discard','two actual actions and better cash beat four plays despite using a free discard')
  check(result.selection_basis=='per_world_resource_dominance','new selection publishes its narrow evidence basis')
  for i=1,4 do
    local a,b=baseline.worlds[i],changed.worlds[i]
    check(a.resources.cash_components==4 and b.resources.cash_components==7,'unused hands add $3 without inventing same-round interest')
    check(#a.actions==4 and #b.actions==2,'action count comes from executed detached transitions')
    check(a.population_loss==0 and b.population_loss==0,'actual surviving deck is conserved')
  end
  check(Snapshot.fingerprint(input)==before,'comparison does not mutate the public worlds')
  local again,again_calls=run(input)
  check(Snapshot.fingerprint(again)==Snapshot.fingerprint(result) and calls==again_calls,'policy selection and work are deterministic')
  print('resource dominance fixture: '..calls..' score/transition charges')
end
do
  local input=worlds({change=function(s) s.modifiers.discard_cost=4 end})
  local result=run(input)
  check(result.complete and result.policies[2].clearing_samples==4,'paid alternative still legally clears every world')
  check(result.policies[2].worlds[1].resources.cash_components==3,'actual $4 discard payment is carried into cash comparison')
  check(result.selected.name=='play_only','fewer actions cannot buy a worse supported cash endpoint')
end
do
  local input=worlds({change=function(s) s.modifiers.discard_cost=3 end})
  local result=run(input)
  check(result.complete and result.selected.name=='one_targeted_discard','equal supported cash permits a strict actual-action improvement')
  check(result.policies[2].worlds[1].resources.cash_components==4,'the paid-discard and unused-hand dollars cancel exactly')
end
do
  local input=worlds({change=function(s,i) if i==4 then s.modifiers.discard_cost=4 end end})
  local result=run(input)
  check(result.complete and result.policies[2].clearing_samples==4,'all four worlds finish before the tradeoff is judged')
  check(result.selected.name=='play_only','three richer worlds cannot compensate for one poorer world in a resource tie-break')
end
do
  local original=Finish.finish_rewards;Finish.finish_rewards=nil
  local result=run(worlds());Finish.finish_rewards=original
  check(result.complete and result.selected.name=='play_only','missing reward support preserves the prior ordering')
  check(result.policies[2].worlds[1].resources==nil,'unknown rewards are not represented as zero cash or zero Blue value')
end
do
  local input=worlds({change=function(s)
    s.deck[2].seal='Blue';s.playing_cards[7].seal='Blue'
  end})
  local result=run(input)
  check(result.complete and result.policies[2].clearing_samples==4,'the Blue tradeoff receives both complete legal continuations')
  check(result.policies[1].worlds[1].resources.blue_planets==1 and result.policies[2].worlds[1].resources.blue_planets==0,
    'the actual final held Blue card generates a Planet only on the play-only route')
  check(result.selected.name=='play_only','extra cash and fewer actions cannot buy away a known Blue generation')
end
do
  local input=worlds({change=function(s) s.modifiers.no_extra_hand_money=true end})
  local result=run(input)
  check(result.complete and result.selected.name=='one_targeted_discard','equal cash still permits a strict actual-action improvement')
  check(result.policies[2].worlds[1].resources.hand_dollars==0 and result.policies[2].worlds[1].resources.cash_components==4,
    'a no-hand-money modifier never creates fictitious cash')
end
do
  local input=worlds({change=function(s)
    s.deck[1].enhancement='m_glass';s.playing_cards[6].enhancement='m_glass'
  end})
  local result=run(input)
  check(result.complete and result.policies[1].clearing_samples==4 and result.policies[2].clearing_samples==4,
    'all Glass transition worlds complete before resource comparison')
  local lost_survivor=false
  for i=1,4 do
    local a,b=result.policies[1].worlds[i],result.policies[2].worlds[i]
    if a.resources.survivors.d1 and not b.resources.survivors.d1 then lost_survivor=true end
  end
  check(lost_survivor,'real sampled Glass destruction exposes a lost incumbent physical survivor')
  check(result.selected.name=='play_only','equal expected population cost cannot hide a worse physical survivor world')
end
do
  local changes={
    function(s) s.used_vouchers={v_observatory=true} end,
    function(s) s.modifiers.minus_hand_size_per_X_dollar=5 end,
    function(s) s.blind.key='bl_arm';s.blind.name='The Arm' end,
    function(s) s.jokers={{id='golden',key='j_golden',name='Golden Joker',ability={name='Golden Joker',set='Joker',extra=4}}} end,
  }
  for i,change in ipairs(changes) do
    local result=run(worlds({change=change}))
    check(result.complete and result.selected.name=='play_only','unsupported resource scope keeps the previous complete policy '..i)
    check(result.policies[2].worlds[1].resources==nil,'unsupported resource scope remains explicit '..i)
  end
end
do
  local result,calls=run(worlds(),5)
  check(not result.complete and not result.selected and calls==5,'a partial family never publishes a resource winner and respects its cap')
end
math.random,math.randomseed=old_random,old_seed
print('advisor_blind_resource_value: '..checks..' checks passed')

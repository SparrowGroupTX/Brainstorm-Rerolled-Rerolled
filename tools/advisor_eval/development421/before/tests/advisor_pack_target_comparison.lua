local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Scorer=dofile('Brainstorm/Advisor/scoring.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Finish=dofile('Brainstorm/Advisor/blind_finishing.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
Strategy.consumables=dofile('Brainstorm/Advisor/consumables.lua')
Strategy.pack_scoring=dofile('Brainstorm/Advisor/pack_scoring.lua')
Shop.paired_deck=dofile('Brainstorm/Advisor/paired_deck.lua')
for _,name in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do
  Finish[name]=dofile('Brainstorm/Advisor/'..name..'.lua')
end
Finish.strategy=Strategy;Shop.blind_finishing=Finish;Shop.strategy=Strategy
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local copy=Snapshot.copy
local function state()
  local s={phase='pack',ante=2,dollars=5,bankrupt_at=0,pack_kind='Arcana',pack_choices=1,
    jokers={},joker_limit=0,consumeables={},consumable_limit=2,hand={},deck={},playing_cards={},
    hands={},hand_size=8,hand_limit=5,round_resets={hands=1,discards=0},current_round={},
    modifiers={},probabilities={normal=1},blind={disabled=true},
    next_blind={key='bl_goad',boss=true,chips=150,debuff={suit='Spades'}},next_blind_chips=150,
    pack_cards={{key='c_chariot',name='The Chariot',ability={set='Tarot',consumeable={max_highlighted=1}}}}}
  for i,pair in ipairs({{12,'Spades'},{12,'Hearts'},{13,'Clubs'},{13,'Diamonds'},
      {14,'Clubs'},{14,'Diamonds'},{2,'Hearts'},{3,'Diamonds'}}) do
    local c={id='target:'..i,key='c_base',rank=pair[1],nominal=pair[1]==14 and 11 or math.min(10,pair[1]),
      suit=pair[2],ability={set='Default'}}
    s.hand[i]=c;s.playing_cards[i]=c
  end
  return s
end
local function finish(progress)
  local worlds={};for i=1,4 do worlds[i]={progress=progress,hands_used=1,discards_used=0,
    dollars_after=5,population_loss=0,finish_reward=0} end
  return {complete=true,supported=true,known_mechanics=true,samples=4,selected={worlds=worlds}}
end
local function paired(s,change)
  local calls=0
  local ctx={compare=function(self,before,after)
    calls=calls+1;local target
    for i,c in ipairs(after.hand) do if c.enhancement=='m_steel' then target=i end end
    local e={samples=4,complete_finishing=true,before_target=150,after_target=150,blind='bl_goad',
      before_finishing=finish(.3),after_finishing=finish(target==2 and .7 or .3),
      adjustment=target==2 and 20 or 0,reason='Complete controlled next-blind outcomes.'}
    if change then change(e,target,self) end
    return e
  end}
  return Strategy.advise(s,{shop_scoring=ctx}),function() return calls end
end
local random,randomseed=math.random,math.randomseed
math.random=function() error('Target comparison cannot sample game RNG') end
math.randomseed=function() error('Target comparison cannot seed game RNG') end
do
  local s=state();local before=Snapshot.fingerprint(s)
  check(Strategy.advise(s).action.targets[1]==1,'unscored default uses original development tie order')
  local result,calls=paired(s);local d=result.pack_diagnostics.offers[1].target_comparison
  check(result.action.targets[1]==2,'complete next-blind effects select an equally valued useful target')
  check(calls()==8 and d.complete and d.considered==8 and #d.targets==8,'every plain target is fully compared within one bounded family')
  check(d.original_target==1 and d.selected_target==2,'old and selected target are explicit')
  check(Snapshot.fingerprint(s)==before,'target trials preserve every input card, inventory, cash and counter')
  check(Snapshot.fingerprint(result)==Snapshot.fingerprint(paired(s)),'target comparison is deterministic')
end
do
  local r,calls=paired(state(),function(e,i) if i==2 then e.after_finishing.supported=false end end)
  local d=r.pack_diagnostics.offers[1].target_comparison
  check(not d.complete and d.considered==2 and d.target_count==8 and calls()==2,
    'early unsupported target preserves actual comparison count and unexamined family size')
end
for _,case in ipairs({
  {'later unsupported target',function(e,i) if i==8 then e.after_finishing.supported=false end end},
  {'late cutoff',function(e,i,ctx) if i==8 then ctx.truncated=true end end},
  {'unequal baseline',function(e,i) if i==2 then e.before_finishing.selected.worlds[1].progress=.2 end end},
  {'crossed progress',function(e,i) if i==2 then e.after_finishing.selected.worlds[4].progress=.2 end end},
  {'additional hands',function(e,i) if i==2 then e.after_finishing.selected.worlds[1].hands_used=2 end end},
  {'additional discards',function(e,i) if i==2 then e.after_finishing.selected.worlds[1].discards_used=1 end end},
  {'lost cash',function(e,i) if i==2 then e.after_finishing.selected.worlds[1].dollars_after=4 end end},
  {'Glass population loss',function(e,i) if i==2 then e.after_finishing.selected.worlds[1].population_loss=1 end end},
  {'lost finishing reward',function(e,i) if i~=2 then e.after_finishing.selected.worlds[1].finish_reward=1 end end},
  {'Arm permanent damage',function(e) e.blind='bl_arm' end},
  {'unknown original evidence',function(e,i) if i==1 then e.after_finishing.known_mechanics=false end end},
}) do
  local r=paired(state(),case[2]);check(r.action.targets[1]==1,case[1]..' keeps original target')
end
for _,case in ipairs({
  {'protected Joker',function(s) s.jokers={{key='j_baron',ability={}}} end},
  {'Observatory',function(s) s.used_vouchers={v_observatory=true} end},
  {'existing Steel',function(s) s.hand[8].key='m_steel';s.hand[8].enhancement='m_steel' end},
  {'existing seal',function(s) s.hand[8].seal='Red' end},
  {'existing edition',function(s) s.hand[8].edition={foil=true} end},
  {'concealed target',function(s) s.hand[8].face_down=true end},
}) do
  local s=state();case[2](s);local r,calls=paired(s)
  check(not r.pack_diagnostics.offers[1].target_comparison,case[1]..' retains existing target policy without an added target family')
end
do
  local s=state();s.consumeables={{key='c_mercury',edition={negative=true},ability={set='Planet',consumeable={hand_type='Pair'}}}};s.consumable_limit=3
  local before=Snapshot.fingerprint(s.consumeables)
  check(paired(s).action.targets[1]==2 and Snapshot.fingerprint(s.consumeables)==before and s.consumable_limit==3,
    'direct pack use retains held Negative inventory and its capacity')
end
-- Original scorer/next-blind projection, on an independent complete eight-card
-- synthetic population. Spade debuff suppresses the first target's held effect.
do
  local s=state();local context=Shop.new(s,Scorer);local r=Strategy.advise(s,{shop_scoring=context})
  check(not context.truncated and r.action.targets[1]~=1,'real Goad forecast avoids the inactive enhancement target')
  local d=r.pack_diagnostics.offers[1].target_comparison
  check(d and d.complete and d.considered==8,'real complete scorer covers every target')
  for i=1,4 do check(d.targets[d.selected_target].progress[i]>d.targets[1].progress[i],
    'real selected target improves common world '..i) end
  local other=state();other.next_blind.debuff.suit='Hearts';other.next_blind.key='bl_head'
  local control=Shop.new(other,Scorer);local safe=Strategy.advise(other,{shop_scoring=control})
  check(not control.truncated and safe.action.targets[1]==1,'opposite known suit restriction retains original active target')
  local modules={strategy=Strategy,scoring=Scorer,shop_scoring=Shop,pack_scoring=Strategy.pack_scoring,consumables=Strategy.consumables}
  local cutoff=Decision.run(s,modules,nil,{shop_scoring={max_evaluations=1}})
  check(cutoff.pack_diagnostics.tactical_fallback and cutoff.action.targets[1]==1,'shared budget cutoff falls back as a whole decision')
  print('advisor_pack_target_comparison real score calls: '..context.evaluations..'/'..control.evaluations)
end
math.random,math.randomseed=random,randomseed
print('advisor_pack_target_comparison: '..checks..' checks passed')

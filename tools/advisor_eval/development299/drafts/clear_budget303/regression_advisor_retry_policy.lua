local Retry=dofile('tools/advisor_eval/development299/drafts/clear_budget303/retry_policy.lua')
local Memory=dofile('Brainstorm/Advisor/retry_memory.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Search=dofile('tools/advisor_eval/development299/drafts/clear_budget303/search.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
Strategy.consumables=dofile('Brainstorm/Advisor/consumables.lua')
Strategy.pack_scoring=dofile('Brainstorm/Advisor/pack_scoring.lua')
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local copy=Snapshot.copy
local modules={retry_memory=Memory,scoring={score=function() error('Retry must never rescore') end}}
local function planet(key,hand)
  return {key=key,name=key,cost=3,ability={set='Planet',consumeable={hand_type=hand}}}
end
local function state(phase)
  local s={phase=phase or 'pack',ante=2,round=3,dollars=20,bankrupt_at=0,chips=0,
    jokers={},consumeables={},joker_limit=0,consumable_limit=2,hand={},deck={},playing_cards={},
    hands={},hand_limit=5,hand_size=3,hands_left=2,discards_left=1,modifiers={},
    blind={key='bl_small',chips=1000},next_blind={key='bl_small',chips=1000},
    next_blind_chips=1000,round_resets={hands=2,discards=1},current_round={},probabilities={normal=1},
    pack_cards={planet('c_mercury','Pair'),planet('c_venus','Three of a Kind'),planet('c_uranus','Two Pair')},
    shop_jokers={},shop_vouchers={},shop_booster={}}
  for i=1,6 do
    local card={id='retry:'..i,key='c_base',rank=i+2,nominal=i+2,suit='Spades',ability={}}
    s.playing_cards[i]=card
    if phase=='hand' and i<=3 then s.hand[i]=card else s.deck[#s.deck+1]=card end
  end
  return s
end
local function key(s,a) local k,why=Memory.action_key(s,a);assert(k,why);return k end
local function context(s,a)
  return {active=true,failed_actions={[key(s,a)]=true},reloads_used=1,reloads_remaining=4}
end
local function finishing(progress)
  local out={complete=true,supported=true,known_mechanics=true,samples=4,selected={worlds={}}}
  for i=1,4 do out.selected.worlds[i]={progress=progress,hands_used=2,discards_used=0,
    dollars_after=20,population_loss=0,finish_reward=0} end
  return out
end
local function evidence(progress)
  return {complete_finishing=true,samples=4,blind='bl_small',before_target=1000,after_target=1000,
    before_finishing=finishing(.2),after_finishing=finishing(progress),adjustment=0,reason='Complete synthetic paired outcomes.'}
end
local function pack_result()
  local r={kind='strategy',action={kind='choose',area='pack_cards',index=1},evaluations=123,
    strategy={title='Original'},pack_diagnostics={complete=true,offers={}}}
  r.strategy.action=r.action
  for i=1,3 do r.pack_diagnostics.offers[i]={index=i,legal=true,known=true,score=40-i,
    action={kind='choose',area='pack_cards',index=i,targets={}},scoring_evidence=evidence(.5-i*.02)} end
  return r
end
local function apply(s,r,c) return Retry.apply(s,r,c or context(s,r.action),modules) end
local function blocked(s,r,label,c)
  local out=apply(s,r,c)
  check(out.action==nil and out.retry.review_only and out.retry.status=='review_only',label)
  if out.strategy then check(out.strategy.action==nil,label..' clears strategy execution') end
  return out
end
local random,randomseed=math.random,math.randomseed
math.random=function() error('Retry must not draw RNG') end
math.randomseed=function() error('Retry must not seed RNG') end
do
  local s,r=state(),pack_result();local c=context(s,r.action)
  local before=Snapshot.fingerprint({s,r,c})
  check(Retry.apply(s,r,nil,modules)==r,'inactive retry preserves exact result identity')
  c.active=false;check(apply(s,r,c)==r,'inactive ledger does not alter ordinary advice');c.active=true
  local out=apply(s,r,c)
  check(out.action.index==2 and out.kind=='strategy','complete revealed Planet alternatives choose next existing rank')
  check(out.retry.rescored==false and out.evaluations==123 and out.retry.failed_line_only,'retry reports no rescoring and contextual failure')
  check(Snapshot.fingerprint({s,r,c})==before,'snapshot result and failure ledger remain detached')
  check(Snapshot.fingerprint(out)==Snapshot.fingerprint(apply(s,r,c)),'retry is deterministic')
  check(key(s,{kind='choose',index=1})==key(s,r.action),'canonical defaults match original pack action')
  c.failed_actions[key(s,out.action)]=true
  check(apply(s,r,c).action.index==3,'second reported branch advances to next untried choice')
  c.reloads_used=5;c.reloads_remaining=0
  check(apply(s,r,c).action.index==3,'fifth admitted reload still receives its active alternative')
  c.failed_actions[key(s,{kind='choose',index=3})]=true
  blocked(s,r,'all tried choices become review only',c)
  c.failed_actions={};check(apply(s,r,c)==r,'a newly recommended untried incumbent is not globally banned')
end
for _,case in ipairs({
  {'incomplete pack',function(s,r) r.pack_diagnostics.complete=false end},
  {'unsupported later offer',function(s,r) r.pack_diagnostics.offers[3].scoring_evidence.after_finishing.supported=false end},
  {'missing legal action export',function(s,r) r.pack_diagnostics.offers[2].action=nil end},
  {'tactical fallback',function(s,r) r.pack_diagnostics.tactical_fallback=true end},
  {'Perkeo inventory',function(s,r) s.jokers={{key='j_perkeo',ability={set='Joker'}}} end},
  {'Observatory inventory',function(s,r) s.used_vouchers={v_observatory=true} end},
  {'Arm permanent damage',function(s,r) for _,o in ipairs(r.pack_diagnostics.offers) do o.scoring_evidence.blind='bl_arm' end end},
  {'different target',function(s,r) for i=2,3 do r.pack_diagnostics.offers[i].scoring_evidence.after_target=900 end end},
  {'different baseline worlds',function(s,r) for i=2,3 do r.pack_diagnostics.offers[i].scoring_evidence.before_finishing.selected.worlds[4].dollars_after=19 end end},
  {'supported clears retained',function(s,r) r.pack_diagnostics.offers[1].scoring_evidence.after_finishing.selected.worlds[4].progress=1 end},
  {'population damage retained',function(s,r) for i=2,3 do r.pack_diagnostics.offers[i].scoring_evidence.after_finishing.selected.worlds[1].population_loss=1 end end},
  {'finishing rewards retained',function(s,r) r.pack_diagnostics.offers[1].scoring_evidence.after_finishing.selected.worlds[3].finish_reward=1 end},
  {'269 strict dominance retained',function(s,r) for i=2,3 do r.pack_diagnostics.offers[i].planet_dominated_by=1 end end},
  {'targeted Tarot incumbent protected',function(s,r) s.pack_cards[1]={key='c_strength',ability={set='Tarot'}} end},
  {'nonfinite outcome',function(s,r) r.pack_diagnostics.offers[3].scoring_evidence.after_finishing.selected.worlds[1].progress=0/0 end}
}) do local s,r=state(),pack_result();case[2](s,r);blocked(s,r,case[1]) end
local function plan(actions,value,progress)
  return {actions=actions,titles={'Planet plan'},cash_after=17,utility=value,complete=true,
    liquidity={purchase_floor=5},scoring_evidence=evidence(progress or .4)}
end
local function shop_state()
  local s=state('shop');s.shop_jokers={s.pack_cards[1],s.pack_cards[2],s.pack_cards[3]};s.pack_cards={}
  local r={kind='strategy',action={kind='buy',area='shop_jokers',index=1},strategy={title='Buy'},
    shop_diagnostics={sequences={complete=true,best_by_first_action={}}}}
  r.strategy.action=r.action
  for i=1,3 do r.shop_diagnostics.sequences.best_by_first_action['buy:shop_jokers:'..i]=
    plan({{kind='buy',area='shop_jokers',index=i},{kind='use',area='consumeables',index=1,targets={}}},4-i) end
  r.shop_diagnostics.sequences.best_by_first_action['leave_shop::']=plan({},0,.2)
  return s,r
end
do
  local s,r=shop_state();local out=apply(s,r)
  check(out.action.index==2 and out.action.kind=='buy','complete graph reuses next Planet first action')
  check(#out.strategy.shop_sequence.actions==2,'follow-up stays reviewable while only first action is executable')
  local c=context(s,r.action)
  c.failed_actions[key(s,{kind='buy',area='shop_jokers',index=2})]=true
  c.failed_actions[key(s,{kind='buy',area='shop_jokers',index=3})]=true
  check(apply(s,r,c).action.kind=='leave_shop','complete safe leave endpoint is an admissible untried branch')
  local plans=r.shop_diagnostics.sequences.best_by_first_action
  plans['buy:shop_jokers:2'].cash_after=4
  check(apply(s,r).action.index==3,'retained liquidity floor rejects underfunded retry endpoint')
  plans['buy:shop_jokers:3'].scoring_evidence.after_finishing.selected.worlds[1].population_loss=2
  check(apply(s,r).action.kind=='leave_shop','population protection applies across shop endpoints')
end
for _,case in ipairs({
  {'incomplete shop graph',function(s,r) r.shop_diagnostics.sequences.complete=false end},
  {'truncated shop graph',function(s,r) r.shop_diagnostics.truncated=true end},
  {'unknown later graph endpoint',function(s,r) r.shop_diagnostics.sequences.best_by_first_action['buy:shop_jokers:3'].scoring_evidence.incomplete=true end},
  {'Planet first action with later Joker growth',function(s,r)
    s.shop_jokers[2]={key='j_constellation',ability={set='Joker'}}
    r.shop_diagnostics.sequences.best_by_first_action['buy:shop_jokers:1'].actions[2]={kind='buy',area='shop_jokers',index=1}
  end}
}) do local s,r=shop_state();case[2](s,r);blocked(s,r,case[1]) end
do
  local s,r=shop_state();s.consumeables={planet('c_pluto','High Card')}
  r.action={kind='use',area='consumeables',index=1,targets={}}
  r.shop_diagnostics.sequences.best_by_first_action['use:consumeables:1']=plan({r.action},5)
  check(apply(s,r).action.kind=='buy','failed owned-Planet use can select a complete different purchase')
  s.consumeables[1].edition={negative=true};s.consumable_limit=3
  check(apply(s,r).action.kind=='buy','whole-inventory graph evidence remains authoritative for a Negative Planet')
end
local function hand_result()
  local r={kind='play',action={kind='play',indices={1}},play_complete=true,alternatives={},evaluations=7}
  for i=1,3 do r.alternatives[i]={indices={i},score=100-i,legal=true,hand='High Card',scoring_indices={i}} end
  r.play=r.alternatives[1];return r
end
do
  local s,r=state('hand'),hand_result();local out=apply(s,r)
  check(out.kind=='play' and out.action.indices[1]==2 and out.play.score==98,'complete plain plays select next legal ranked action')
  check(out.evaluations==7 and not out.retry.rescored,'hand retry cannot spend a scoring call')
  s.hand[1].ability.forced_selection=true
  blocked(s,r,'forced selection cannot be omitted by an alternative')
end
for _,case in ipairs({
  {'partial play family',function(s,r) r.play_complete=false end},
  {'unsupported late play',function(s,r) r.alternatives[3].uncertain=true end},
  {'truncated search',function(s,r) r.truncated=true end},
  {'fast clear budget',function(s,r) r.fast_clear={} end},
  {'later enumeration clear',function(s,r) r.clear_shortcut={} end},
  {'immediate clear',function(s,r) r.play.score=1000 end},
  {'known immediate loss on final play',function(s,r) s.hands_left=1 end},
  {'Arm hand damage',function(s,r) s.blind.key='bl_arm' end},
  {'Glass held population',function(s,r) s.hand[2].key='m_glass';s.hand[2].enhancement='m_glass' end},
  {'Glass drawable population',function(s,r) s.deck[1].key='m_glass';s.deck[1].enhancement='m_glass' end},
  {'string edition robustness',function(s,r) s.hand[2].edition='negative' end},
  {'permanent card growth',function(s,r) s.deck[1].ability.perma_bonus=5 end},
  {'owned consumable continuation',function(s,r) s.consumeables={planet('c_mercury','Pair')} end},
  {'deeper resource continuation',function(s,r) r.resource_comparison={samples=4} end},
  {'protected growth investment',function(s,r) r.growth={action={kind='play',indices={1}}} end},
  {'paid discard modifier',function(s,r) s.modifiers.discard_cost=1 end}
}) do local s,r=state('hand'),hand_result();case[2](s,r);blocked(s,r,case[1]) end
do
  local s,r=state('hand'),hand_result();s.hands_left=1;r.play.uncertain=true
  local out=blocked(s,r,'unknown final-play scoring remains review only')
  check(out.retry.lines[1]:find('unsupported') and not out.retry.lines[1]:find('immediately lose'),
    'unsupported final-hand evidence is never described as a certain loss')
end
do
  local s,r=state('hand'),hand_result();r.kind='discard';r.action={kind='discard',indices={1}}
  r.discard_comparison_complete=true;r.discard_alternatives={}
  for i=1,3 do r.discard_alternatives[i]={indices={i},count=4,mean=200-i,probability=.25,
    value=4-i,growth=0} end
  r.discard=r.discard_alternatives[1]
  check(apply(s,r).action.indices[1]==2,'complete matched discard alternatives reuse existing values')
  s.hands_left=1;r.discard_alternatives[3].probability=.5
  check(apply(s,r).action.indices[1]==3,'final-hand survival ordering precedes generic discard utility')
  r.discard_alternatives[3].count=5;blocked(s,r,'different sample counts cannot rank retry discards')
  r.discard_alternatives[3].count=4;r.discard_comparison_complete=false
  blocked(s,r,'adaptive incumbent-only certificate cannot rank remaining alternatives')
end
-- Exercise both new source exports through the existing deterministic modules.
do
  local s=state('hand');s.hand={s.playing_cards[1],s.playing_cards[2]};s.deck={s.playing_cards[3],s.playing_cards[4]}
  s.playing_cards={s.hand[1],s.hand[2],s.deck[1],s.deck[2]};s.hand_size=2;s.hands_left=1;s.blind.chips=100
  local scorer={after_discard=Score.after_discard,score=function(t,indices)
    local score=10
    if (t.discards_used or 0)>0 then for _,i in ipairs(indices) do if t.hand[i].id=='retry:1' then score=100 end end end
    return {score=score,legal=true,hand='High Card',scoring_indices=indices}
  end}
  local full=Search.run(s,scorer,{adaptive_samples=false})
  local reduced=Search.run(s,scorer,{})
  check(full.discard_comparison_complete and #full.discard_alternatives>1,'fully matched source discard rows are exported')
  check(full.discard_alternatives[1].prepared==nil,'retry export does not retain full prepared snapshots')
  check(not reduced.discard_comparison_complete and not reduced.discard_alternatives,'uncomputed adaptive rivals are not exported as retry-complete')
  check(full.kind==reduced.kind and table.concat(full.discard.indices,',')==table.concat(reduced.discard.indices,','),
    'evidence export preserves default adaptive winner')
  local source=state();source.hand={};source.deck={};source.hands={Pair={played=1,level=1}}
  local calls=0
  local context={compare=function() calls=calls+1;return evidence(.4) end}
  local result=Strategy.advise(source,{shop_scoring=context})
  check(result.pack_diagnostics.complete and #result.pack_diagnostics.offers==3 and calls==3,
    'pack evidence export uses only the already completed comparisons')
  for _,offer in ipairs(result.pack_diagnostics.offers) do
    check(offer.action and offer.action.kind=='choose' and offer.action.index==offer.index,
      'pack source action export identifies the exact legal untargeted offer')
  end
  check(not Strategy.advise(source).pack_diagnostics.complete,'strategy-only advice cannot masquerade as complete scoring')
end
math.random,math.randomseed=random,randomseed
print('advisor_retry_policy: '..checks..' checks passed')

-- Synthetic bounded comparison: an owned use must not grant exclusive access
-- to an otherwise legal free first play. No captured/source state is replayed.
local Finish=dofile('tools/advisor_eval/development291/resource_finish.lua')
local Before=dofile('tools/advisor_eval/development291/resource_finish_base.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Development=dofile('Brainstorm/Advisor/deck_development.lua')
local Outcomes=dofile('Brainstorm/Advisor/sampled_outcomes.lua')
Consumables.deck_development=Development;Strategy.deck_development=Development;Strategy.consumables=Consumables
local checks=0
local function check(v,why) checks=checks+1;assert(v,why) end
local function eq(a,b,why) check(a==b,(why or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function copy(t) return Snapshot.copy(t) end
local function card(id,rank,suit) return {id=id,rank=rank,nominal=math.min(rank,10),suit=suit or 'Spades',ability={}} end
local function state(removal)
  local s={phase='hand',ante=2,hand_size=5,hand_limit=5,hands_left=2,discards_left=1,hands_played=0,discards_used=0,
    chips=0,dollars=4,bankrupt_at=0,blind={key='bl_small',chips=400},hands={},current_round={},jokers={},
    modifiers={},probabilities={normal=1},consumable_limit=2,deck={},playing_cards={}}
  s.hand=removal and {card('h1',2),card('h2',13),card('h3',13,'Hearts'),card('h4',13,'Clubs'),card('h5',3)} or
    {card('h1',13),card('h2',13,'Hearts'),card('h3',13,'Clubs'),card('h4',2),card('h5',3)}
  s.consumeables={{id='owned',key=removal and 'c_hanged_man' or 'c_justice',ability={set='Tarot',consumeable={}}}}
  for i=1,20 do s.deck[i]=card(string.format('d%02d',i),2+i%11,({'Spades','Hearts','Clubs','Diamonds'})[i%4+1]) end
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  return s
end
local function incumbent(s,use)
  local result={kind='discard',play=Score.score(s,{1}),discard={indices={4,5}}};result.play.indices={1}
  if use then result.consumable={action={kind='use',area='consumeables',index=1,targets={1,5}}} end
  return result
end
local strategy={};for k,v in pairs(Strategy) do strategy[k]=v end
-- A declared public target heuristic, isolated from the actual score/transition
-- module. It deliberately proposes a non-scoring Glass target in the toy.
strategy.development_targets=function(s,c) return c.key=='c_hanged_man' and {1,5} or {5} end
strategy.development_gain=function() return 1 end
local controlled={};for k,v in pairs(Outcomes) do controlled[k]=v end
function controlled.after_play(s,indices,scorer,seed,turn)
  local after,why,actual=Outcomes.after_play(s,indices,scorer,seed,turn)
  if not after then return after,why,actual end
  -- Controlled threshold outcome tests comparison coverage, not win odds:
  -- only preserving all three Kings for the first action can clear this tape.
  local kings=0;for _,i in ipairs(indices) do if s.hand[i].rank==13 then kings=kings+1 end end
  local clears=s.hands_left==2 and s.discards_used==0 and #indices==3 and kings==3
  actual.score=clears and 400 or 1;after.chips=s.chips+actual.score
  return after,why,actual
end
local modules={scoring=Score,search=Search,consumables=Consumables,strategy=strategy,
  draws=dofile('Brainstorm/Advisor/draws.lua'),sampled_outcomes=controlled,
  multi_discard=dofile('Brainstorm/Advisor/multi_discard.lua'),
  blind_finishing=dofile('Brainstorm/Advisor/blind_finishing.lua'),finish_rewards=dofile('Brainstorm/Advisor/finish_rewards.lua')}

do
  local s=state();local result=incumbent(s);local original=Snapshot.fingerprint(s);local original_result=Snapshot.fingerprint(result)
  local old,_,old_diag=Before.suggest(s,modules,result)
  check(old and old_diag.complete and old.action.kind=='use','old family spends a use to reach the missing free first-play selection')
  for _,plan in ipairs(old_diag.candidates) do
    if plan.kind~='use' then eq(plan.probability,0,'every old free first-action schedule fails the controlled threshold') end
  end
  local advice,count,diag=Finish.suggest(s,modules,result)
  check(advice and diag.complete and diag.completed_outer==4,'new entire family completes')
  eq(diag.first_actions,5,'one distinct counterpart extends the four old first actions')
  eq(#diag.candidates,50,'all five first actions cross five discard and two use policies')
  eq(advice.action.kind,'play','keeping the item can now win the declared comparison')
  eq(table.concat(advice.action.indices,','),'1,2,3','new free first play uses the same physical Kings')
  eq(diag.best.uses,0,'free counterpart does not spend the owned item')
  eq(diag.best.probability,1,'all four controlled worlds clear')
  eq(diag.free_play_counterpart.added,true,'counterpart receipt records an actual new family member')
  eq(diag.free_play_counterpart.score,180,'counterpart independently receives its actual pre-use score')
  check(count<=12000 and diag.classifications<=150000,'score and classification caps are unchanged')
  local counterpart_plans=0
  for _,plan in ipairs(diag.candidates) do
    eq(#plan.worlds,4,'every declared plan completes all common worlds')
    if plan.key==diag.free_play_counterpart.key then
      counterpart_plans=counterpart_plans+1
      eq(plan.key,diag.free_play_counterpart.key,'counterpart is a declared free family, not a hidden preference')
      for _,world in ipairs(plan.worlds) do
        eq(world.actions[1].kind,'play','free counterpart stays the fixed first action')
        eq(table.concat(world.actions[1].card_ids,','),'h1,h2,h3','exact physical order remains fixed')
        eq(#world.inventory_before_finish_rewards,1,'free clear retains the consumable')
        eq(world.inventory_before_finish_rewards[1].id,'owned','the original consumable identity remains owned')
        eq(world.inventory_before_finish_rewards[1].key,'c_justice','the original Justice remains owned')
      end
    end
  end
  eq(counterpart_plans,10,'all five discard schedules and two use schedules include the free counterpart')
  eq(Snapshot.fingerprint(s),original,'root cards, inventory, cash and population remain unchanged')
  eq(Snapshot.fingerprint(result),original_result,'incumbent public action is not mutated')
  local reversed=copy(s);reversed.deck={};for i=#s.deck,1,-1 do reversed.deck[#reversed.deck+1]=s.deck[i] end
  local alternate,_,other=Finish.suggest(reversed,modules,result)
  eq(Snapshot.fingerprint(alternate.action),Snapshot.fingerprint(advice.action),'hidden input deck order does not choose the free play')
  eq(Snapshot.fingerprint(other.free_play_counterpart),Snapshot.fingerprint(diag.free_play_counterpart),'counterpart declaration is based on public cards before sampling')
  local duplicate=incumbent(s);duplicate.play=Score.score(s,{1,2,3});duplicate.play.indices={1,2,3}
  local _,_,dedup=Finish.suggest(s,modules,duplicate)
  check(dedup.complete and not dedup.free_play_counterpart.added,'an already declared free first play is deduplicated')
  eq(dedup.first_actions,4,'deduplication does not inflate the family')
  local none,_,cut=Finish.suggest(s,modules,result,nil,{max_evaluations=3})
  check(not none and not cut.complete and cut.evaluations==3,'score exhaustion rejects the entire family')
  none,_,cut=Finish.suggest(s,modules,result,nil,{max_classifications=3})
  check(not none and not cut.complete and cut.classifications==3,'classification exhaustion rejects the entire family')
end
do
  local s=state(true);local result=incumbent(s,true);local original=Snapshot.fingerprint(s)
  local _,_,diag=Finish.suggest(s,modules,result)
  check(diag.complete,'Hanged Man removal has a complete independent counterpart comparison')
  eq(diag.baseline.key,'use:1:1,5','exact incumbent removal targets remain the baseline')
  eq(table.concat(diag.free_play_counterpart.post_use_indices,','),'1,2,3','post-removal indices refer to the reduced hand')
  eq(table.concat(diag.free_play_counterpart.indices,','),'2,3,4','mapping restores unchanged-hand physical positions')
  eq(table.concat(diag.free_play_counterpart.card_ids,','),'h2,h3,h4','no removed identity is substituted')
  eq(Snapshot.fingerprint(s),original,'removal projections preserve the full input population')
  -- A known legal use can remove the forced card; its free play cannot omit
  -- that still-owned card. Keep every original legal plan without inventing
  -- a free counterpart for this legal rescue.
  s.hand[1].ability.forced_selection=true
  local forced_result=copy(result);forced_result.discard.indices={1,5}
  local none,_,declined=Finish.suggest(s,modules,forced_result)
  check(declined.complete and declined.counterpart_declined.kind=='unchanged_play_illegal' and not declined.free_play_counterpart,
    'known original forced-selection illegality preserves the original complete legal family: '..tostring(declined.reason))
  eq(declined.baseline.key,'use:1:1,5','a known use rescue keeps its exact baseline after the free counterpart is declined')
  s.hand[1].ability.forced_selection=nil
  local actual_apply=Consumables.apply
  Consumables.apply=function(before,index,targets)
    local after,why=actual_apply(before,index,targets)
    if after then after.hand[1].id='unregistered-generated-card' end
    return after,why
  end
  none,_,declined=Finish.suggest(s,modules,result)
  check(not none and not declined.complete and declined.reason:find('physical cards',1,true),'unmappable new identity aborts the whole family')
  Consumables.apply=actual_apply
  local unknown={};for k,v in pairs(Score) do unknown[k]=v end
  unknown.score=function(before,indices)
    local p=Score.score(before,indices)
    if #before.consumeables==1 and table.concat(indices,',')=='2,3,4' then p.uncertain=true;p.warnings={'Unmodeled free counterpart'} end
    return p
  end
  modules.scoring=unknown
  none,_,declined=Finish.suggest(s,modules,result)
  check(not none and not declined.complete and declined.reason:find('unsupported scoring',1,true),'unknown unchanged-inventory scoring cannot establish a free alternative')
  modules.scoring=Score
  s.blind={key='bl_psychic',chips=400};s.hand[1].ability.forced_selection=nil
  local psychic=incumbent(s,true);psychic.play=Score.score(s,{1,2,3,4,5});psychic.play.indices={1,2,3,4,5}
  none,_,declined=Finish.suggest(s,modules,psychic)
  check(declined.complete and declined.counterpart_declined.kind=='no_immediate_post_use_legal_play' and not declined.free_play_counterpart,
    'known absence of an immediate Psychic play retains full original use/discard rescue coverage')
  eq(declined.baseline.key,'use:1:1,5','the exact Hanged Man baseline remains after complete no-legal-play enumeration')
end
do
  local s=state();s.hand[1].suit='Clubs';s.hand[2].suit='Clubs'
  s.consumeables[1].key='c_moon';s.blind={key='bl_eye',chips=400,hands={['Three of a Kind']=true}}
  local result=incumbent(s);result.consumable={action={kind='use',area='consumeables',index=1,targets={3,4,5}}}
  local after=Consumables.apply(s,1,{3,4,5})
  check(after and Score.classify(after,{1,2,3,4,5})=='Flush','Moon makes a new legal category in the projected hand')
  eq(Score.classify(s,{1,2,3,4,5}),'Three of a Kind','the same physical cards retain their original category without use')
  local none,_,declined=Finish.suggest(s,modules,result)
  check(declined.complete and declined.counterpart_declined.kind=='unchanged_play_illegal' and not declined.free_play_counterpart,
    'The Eye must exclude the repeated original category while retaining the complete legal use rescue family')
  eq(declined.baseline.key,'use:1:3,4,5','Moon keeps its exact rescue baseline when the original category is illegal')
end
print('resource_free_counterpart291: '..checks..' checks passed; controlled synthetic outcomes only')

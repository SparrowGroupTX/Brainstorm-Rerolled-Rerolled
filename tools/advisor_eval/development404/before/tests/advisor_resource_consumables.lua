-- Routine synthetic helper fixture; no captured or original-source states.
local C=dofile('Brainstorm/Advisor/consumables.lua')
local P=C.resource_policy
local S=dofile('Brainstorm/Advisor/strategy.lua')
local D=dofile('Brainstorm/Advisor/deck_development.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
C.deck_development=D;S.deck_development=D;S.consumables=C
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(id,r,s) return {id=id,key='c_base',rank=r,nominal=math.min(10,r),suit=s or 'Spades',ability={}} end
local function state()
  local s={phase='hand',ante=2,hand={},deck={},playing_cards={},jokers={},consumeables={
    {id='moon',key='c_moon',ability={set='Tarot',consumeable={suit_conv='Clubs',max_highlighted=3}}},
    {id='justice',key='c_justice',ability={set='Tarot',consumeable={mod_conv='m_glass',max_highlighted=1}}}},
    hands={},hand_size=8,hand_limit=5,hands_left=4,discards_left=3,hands_played=0,discards_used=0,
    blind={key='bl_small',chips=2000},chips=0,dollars=2,consumable_limit=2,modifiers={},probabilities={normal=1}}
  local ranks={13,12,10,9,8,6,4,2};local suits={'Hearts','Clubs','Hearts','Spades','Clubs','Hearts','Clubs','Diamonds'}
  for i,r in ipairs(ranks) do s.hand[i]=card('held'..i,r,suits[i]) end
  for i=12,1,-1 do s.deck[#s.deck+1]=card(string.format('deck%02d',i),2+i%12) end
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do s.playing_cards[#s.playing_cards+1]=c end end
  return s
end
local function best(s)
  local chosen,out={},nil
  local function walk(start)
    if #chosen>0 then local p=Score.score(s,chosen);if p.legal~=false and (not out or p.score>out.score) then out=p end end
    if #chosen==5 then return end
    for i=start,#s.hand do chosen[#chosen+1]=i;walk(i+1);chosen[#chosen]=nil end
  end
  walk(1);return out,not out
end
local function result(index,targets) return {consumable={action={kind='use',area='consumeables',index=index,targets=targets}}} end
do
  local s=state();local before=Snapshot.fingerprint(s)
  local ctx=P.prepare(s,{strategy=S},result(1,{1,3,4}))
  check(ctx and ctx.maximum_uses==2,'two ordinary owned cards enter one bounded inventory context')
  eq(ctx.first.key,'use:1:1,3,4','incumbent target order is preserved exactly')
  local after,details=ctx.project(s,1,{1,3,4})
  eq(#after.hand,8,'suit use does not draw or remove held cards')
  eq(#after.consumeables,1,'exact use removes one inventory card')
  eq(after.last_tarot_planet,'c_moon','usage identity follows the actual consumed card')
  eq(details.card_id,'moon','receipt preserves consumed physical identity')
  eq(table.concat(details.target_card_ids,','),'held1,held3,held4','receipt preserves targeted physical identities')
  local next_use,why=ctx.propose(after,best)
  check(next_use and next_use.index==1 and next_use.after.consumeables and #next_use.after.consumeables==0,'ordinary Justice can follow Moon: '..tostring(why))
  check(next_use.score>best(after).score,'second use is selected from observed scoring benefit')
  eq(next_use.details.card_id,'justice','shifted inventory index retains the right physical card')
  eq(Snapshot.fingerprint(s),before,'helper preserves input and full original inventory')
  local reordered=Snapshot.copy(s);reordered.consumeables[1].edition={negative=true};reordered.consumable_limit=3
  local negative=P.prepare(reordered,{strategy=S},result(1,{1,3,4}));local used=negative.project(reordered,1,{1,3,4})
  eq(used.consumable_limit,2,'Negative consumption removes its real extra capacity')
end
do
  local s=state();local seen=0;local fake={}
  for k,v in pairs(S) do fake[k]=v end
  fake.development_targets=function(public,owned)
    for i=2,#public.deck do check(public.deck[i-1].id<public.deck[i].id,'target rule sees canonical public deck, not its future tail') end
    seen=seen+1;return owned.key=='c_moon' and {1,3,4} or {1}
  end
  local ctx=P.prepare(s,{strategy=fake},{})
  local proposed=ctx.propose(s,best);check(proposed and seen==2,'every admitted owned public proposal is compared')
  local reverse=Snapshot.copy(s);reverse.deck={};for i=#s.deck,1,-1 do reverse.deck[#reverse.deck+1]=s.deck[i] end
  local other=ctx.propose(reverse,best)
  eq(other.index,proposed.index,'future deck order does not choose an owned card')
  eq(table.concat(other.targets,','),table.concat(proposed.targets,','),'future deck order does not choose targets')
  fake.development_targets=function() return {1},nil,{2,1,3,4,5,6,7,8} end
  local uncertain,why=ctx.propose(s,best)
  check(not uncertain and why:find('ordering',1,true),'unsupported later ordering remains explicit')
  fake.development_targets=function() return {1} end
  local no_score,reason=ctx.propose(s,function() return nil,false end)
  check(not no_score and reason:find('incomplete',1,true),'unknown observed scoring does not become no-use evidence')
  fake.preservation_cost=function() return 1,'protected source',true end
  local no_use,message=ctx.project(s,1,{1})
  check(not no_use and message=='protected source','whole-inventory last-source guard rejects consumption')
end
do
  local s=state();s.consumeables={{id='hanged',key='c_hanged_man',ability={set='Tarot',consumeable={remove_card=true,max_highlighted=2}}}}
  local ctx=P.prepare(s,{strategy=S},result(1,{6,8}));local after,details=ctx.project(s,1,{6,8})
  eq(#after.hand,6,'Hanged Man removal does not refill the hand')
  eq(#after.deck,#s.deck,'Hanged Man does not consume unknown draws')
  eq(#after.playing_cards,#s.playing_cards-2,'Hanged Man removes exact physical population')
  eq(details.population_before-details.population_after,2,'removal has an explicit population receipt')
  local rejected=P.prepare(s,{strategy=S},result(1,{8,6}))
  check(not rejected,'reversed incumbent targets cannot silently become a different action')
  s.consumeables[1].key='c_emperor';check(not P.prepare(s,{strategy=S},{}),'unknown generated future identities excluded')
  s=state();s.jokers={{key='j_perkeo'}};check(not P.admits(s),'Perkeo remains outside this ordinary scope')
  s=state();s.used_vouchers={v_observatory=true};check(not P.admits(s),'Observatory remains outside this ordinary scope')
  s=state();s.hand_size=9;check(not P.admits(s),'future hand size cannot exceed the eight-card use family')
  for _,value in ipairs({-1,0,1,1.5,0/0}) do
    s=state();s.consumable_limit=value;check(not P.admits(s),'invalid or overfull inventory capacity is declined')
  end
  s=state();s.consumable_limit=nil;check(not P.admits(s),'missing inventory capacity cannot silently default for Negative use')
  s=state();s.consumeables[1].ability.consumeable.suit_conv='Diamonds'
  ctx=P.prepare(s,{strategy=S},result(1,{1}));local rejected,why=ctx.project(s,1,{1})
  check(not rejected and why:find('Modified',1,true),'modified ordinary identity fails exact transition rather than inventing an effect')
end
do
  local Finish=dofile('Brainstorm/Advisor/resource_finish.lua')
  local Search=dofile('Brainstorm/Advisor/search.lua')
  local modules={scoring=Score,search=Search,draws=dofile('Brainstorm/Advisor/draws.lua'),
    sampled_outcomes=dofile('Brainstorm/Advisor/sampled_outcomes.lua'),
    multi_discard=dofile('Brainstorm/Advisor/multi_discard.lua'),
    blind_finishing=dofile('Brainstorm/Advisor/blind_finishing.lua'),
    finish_rewards=dofile('Brainstorm/Advisor/finish_rewards.lua'),consumables=C,strategy=S}
  local s=state();s.blind.chips=400
  local original=Snapshot.fingerprint(s)
  local incumbent=result(1,{1,3,4});incumbent.kind='discard'
  incumbent.play=Score.score(s,{1});incumbent.play.indices={1}
  incumbent.discard={indices={2,3,4,5}}
  local original_result=Snapshot.fingerprint(incumbent)
  local suggestion,count,diag=Finish.suggest(s,modules,incumbent)
  check(diag.complete and diag.completed_outer==4,'eight-card two-consumable full family completes: '..tostring(diag.reason))
  eq(#diag.candidates,diag.first_actions*10,'every fixed first action crosses all discard and use policies')
  check(diag.first_actions<=5 and #diag.candidates<=50,'the complete extended family remains bounded')
  eq(diag.baseline.key,'use:1:1,3,4','whole-family baseline is the exact existing tactical use')
  check(count<=12000 and diag.classifications<=150000,'whole family retains existing score/classification caps')
  local saw_later,saw_two=false,false
  for _,plan in ipairs(diag.candidates) do
    eq(#plan.worlds,4,'every use and hold plan covers the same four worlds')
    for _,world in ipairs(plan.worlds) do
      local used,identities=0,{}
      for index,action in ipairs(world.actions) do
        if action.kind=='use' then
          used=used+1;check(not identities[action.card_id],'an owned physical card is consumed only once per policy world')
          identities[action.card_id]=true
          eq(action.inventory_before-action.inventory_after,1,'each modeled use consumes exactly one inventory item')
          eq(action.dollars_after,action.dollars_before,'ordinary target use preserves actual cash')
          if index>1 then saw_later=true end
        end
      end
      eq(used,world.uses,'all uses are included in the policy action count')
      check(used<=2,'initial plus later uses share the original two-item limit')
      saw_two=saw_two or used==2
      if plan.kind=='use' then
        eq(world.actions[1].kind,'use','incumbent-use first action is never preceded by a play or discard')
        eq(table.concat(world.actions[1].targets,','),'1,3,4','incumbent-use targets remain exact in every world')
      end
    end
  end
  check(saw_later and saw_two,'whole family compares Moon/Justice interaction after public actions')
  eq(Snapshot.fingerprint(s),original,'joint planning preserves the complete input snapshot')
  eq(Snapshot.fingerprint(incumbent),original_result,'joint planning does not mutate or erase the existing tactical action')
  local reversed=Snapshot.copy(s);reversed.deck={};for i=#s.deck,1,-1 do reversed.deck[#reversed.deck+1]=s.deck[i] end
  local _,reverse_count,reverse_diag=Finish.suggest(reversed,modules,incumbent)
  eq(reverse_count,count,'input deck order does not change joint work or choices')
  eq(Snapshot.fingerprint(reverse_diag),Snapshot.fingerprint(diag),'all joint common worlds are invariant to hidden input deck order')
  local none,used,cut=Finish.suggest(s,modules,incumbent,nil,{max_evaluations=2})
  check(not none and not cut.complete and used<=2,'score cap aborts the whole family without a partial override')
  none,used,cut=Finish.suggest(s,modules,incumbent,nil,{max_classifications=1})
  check(not none and not cut.complete and cut.classifications<=1,'classification cap aborts the whole family')
  local protected=Snapshot.copy(incumbent);protected.consumable.play={score=400,legal=true}
  none,used,cut=Finish.suggest(s,modules,protected)
  check(not none and used==0,'reliable incumbent consumable clear keeps its existing priority')
  protected=Snapshot.copy(incumbent);protected.consumable.sequence={{index=1,targets={1,3,4}},{index=1,targets={1}}}
  none,used,cut=Finish.suggest(s,modules,protected)
  check(not none and used==0 and not cut.complete,'existing compound consumable continuation keeps its complete known sequence')
  local old=modules.sampled_outcomes;local controlled={}
  for key,value in pairs(old) do controlled[key]=value end
  controlled.after_play=function(before,indices,scorer,seed,turn)
    local after,why,actual=old.after_play(before,indices,scorer,seed,turn)
    if not after then return after,why,actual end
    local moon_used=false
    for _,c in ipairs(before.playing_cards) do if c.id=='held1' then moon_used=c.suit=='Clubs' end end
    local winning=moon_used and seed==2718281 or not moon_used and seed~=2718281
    actual.score=winning and 400 or 1;after.chips=before.chips+actual.score
    return after,why,actual
  end
  modules.sampled_outcomes=controlled
  none,used,cut=Finish.suggest(s,modules,incumbent)
  check(not none and cut.complete and cut.override_rejected,'crossed worlds cannot displace the exact owned-use baseline')
  eq(cut.baseline.probability,.25,'exact-use winning common world is retained')
  eq(cut.aggregate_best.probability,.75,'rejected aggregate benefit remains visible as development evidence')
  controlled.after_play=function(before,indices,scorer,seed,turn)
    local after,why,actual=old.after_play(before,indices,scorer,seed,turn)
    if not after then return after,why,actual end
    local moon_used=false
    for _,c in ipairs(before.playing_cards) do if c.id=='held1' then moon_used=c.suit=='Clubs' end end
    actual.score=(not moon_used or seed==2718281) and 400 or 1;after.chips=before.chips+actual.score
    return after,why,actual
  end
  local improved,_,complete=Finish.suggest(s,modules,incumbent)
  check(improved and complete.complete and improved.replaces_consumable,'complete noncrossed comparison can replace the exact use with a supported first action')
  eq(improved.action.kind,'play','positive integration example publishes only its first resource action')
  eq(complete.baseline.probability,.25,'positive comparison retains the original use as its baseline')
  eq(complete.best.probability,1,'synthetic supported alternative clears all four paired worlds')
  controlled.after_play=function(before,indices,scorer,seed,turn)
    local after,why,actual=old.after_play(before,indices,scorer,seed,turn)
    if not after then return after,why,actual end
    local early=before.fixture_early_use
    if early==nil then
      early=#before.consumeables<2 and before.hands_played==0 and before.discards_used==0
    end
    after.fixture_early_use=early
    local winning=early and seed~=2718281 or not early and seed==2718281
    actual.score=winning and 400 or 1;after.chips=before.chips+actual.score
    return after,why,actual
  end
  local no_hint=Snapshot.copy(incumbent);no_hint.consumable=nil
  local no_hint_state=Snapshot.copy(s);no_hint_state.hands_left=2
  none,used,cut=Finish.suggest(no_hint_state,modules,no_hint)
  check(not none and cut.complete and cut.override_rejected,'new use-first action without an old hint cannot bypass crossed-world protection: '..tostring(cut.reason))
  eq(cut.aggregate_best.kind,'use','no-hint negative covers a genuinely new use first action')
  eq(cut.aggregate_best.probability,.75,'crossed no-hint use benefit remains diagnostic only')
  modules.sampled_outcomes=old
  local unsupported={};for key,value in pairs(S) do unsupported[key]=value end
  unsupported.development_targets=function() return {1},nil,{2,1,3,4,5,6,7,8} end
  modules.strategy=unsupported
  none,used,cut=Finish.suggest(s,modules,incumbent)
  check(not none and not cut.complete,'unsupported later owned target invalidates the complete family without an override')
  eq(Snapshot.fingerprint(incumbent),original_result,'unsupported future proposal preserves the exact incumbent action')
  modules.strategy=S
  local missing={};for key,value in pairs(C) do missing[key]=value end
  missing.resource_policy={admits=function() return true end,prepare=function() return nil,'missing exact use dependency' end}
  modules.consumables=missing
  none,used,cut=Finish.suggest(s,modules,no_hint)
  check(not none and used==0 and not cut.complete and cut.reason=='missing exact use dependency',
    'admitted no-hint use family cannot silently fall back to a hold-only partial family')
  modules.consumables=C
  s.hands_left=2;check(Finish.admits(s,modules),'two-hand ordinary targeted inventory reaches the integrated specialist')
  s.consumeables={{id='planet',key='c_mercury',ability={set='Planet'}}}
  check(not Finish.admits(s,modules),'small owned-Planet route retains the existing specialist')
  print('resource consumables full family: '..count..' scores / '..diag.classifications..' classifications')
end
print('resource consumables: '..checks..' checks passed; synthetic public-rule coverage only')

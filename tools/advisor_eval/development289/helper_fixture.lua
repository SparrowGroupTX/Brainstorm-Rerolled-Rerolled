-- Routine synthetic helper fixture; no captured or original-source states.
local C=dofile('Brainstorm/Advisor/consumables.lua')
local P=dofile('tools/advisor_eval/development289/resource_policy_helper.lua')(C)
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
print('resource consumable helper: '..checks..' checks passed; synthetic public-rule coverage only')

-- Offline synthetic workloads. No game source, game callbacks, windows or saves.
local root,workload,mode,repetitions=PROFILE_ROOT,PROFILE_WORKLOAD,PROFILE_MODE,PROFILE_REPETITIONS
local function load_module(name,optional)
  local path=root..'/Brainstorm/Advisor/'..name..'.lua'
  local f=io.open(path,'rb');if not f then assert(optional,'Missing '..path);return end;f:close()
  return dofile(path)
end
local modules={}
for _,name in ipairs({'snapshot','scoring','search','strategy','consumables','deck_development','spectral_development',
  'economy','shop_scoring','ordering','hand_ordering','boss_rescue','mixed_rescue','multi_discard','growth',
  'finish_rewards','score_cache','draws','sampled_outcomes','policy_weights','blind_prep','blind_routing','decision',
  'blind_start','paired_deck','shop_sequences','pack_scoring','two_hand_finish','resource_finish','concealed_belief','acorn_belief','acorn_ordering','work_cost','liquidity','blind_finishing'}) do
  modules[name]=load_module(name,true)
end
modules.strategy.synergies=load_module('synergies')
modules.strategy.paid_reroll=load_module('paid_reroll',true)
modules.strategy.conditional_value=load_module('conditional_value',true)
modules.strategy.consumables=modules.consumables
modules.strategy.deck_development=modules.deck_development
modules.shop_scoring.blind_start=modules.blind_start
modules.shop_scoring.paired_deck=modules.paired_deck
modules.shop_scoring.blind_prep=modules.blind_prep
if modules.blind_prep then modules.blind_prep.blind_start=modules.blind_start end
modules.shop_scoring.strategy=modules.strategy
modules.strategy.pack_scoring=modules.pack_scoring
modules.consumables.deck_development=modules.deck_development
modules.deck_development.spectral=modules.spectral_development
modules.search.policy_weights=modules.policy_weights
modules.growth.policy_weights=modules.policy_weights
modules.shop_scoring.work_cost=modules.work_cost
modules.shop_scoring.policy_weights=modules.policy_weights
if modules.strategy.paid_reroll then modules.strategy.paid_reroll.policy_weights=modules.policy_weights end
modules.strategy.liquidity=modules.liquidity
modules.shop_scoring.liquidity=modules.liquidity
if modules.liquidity then modules.liquidity.snapshot=modules.snapshot end
if modules.blind_finishing then
  for _,key in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards','strategy'}) do
    modules.blind_finishing[key]=modules[key]
  end
  modules.shop_scoring.blind_finishing=modules.blind_finishing
end
if modules.strategy.paid_reroll then modules.strategy.paid_reroll.liquidity=modules.liquidity end
if modules.strategy.conditional_value then modules.strategy.conditional_value.liquidity=modules.liquidity end
local profile,stack={},{}
local function packed(...) return {n=select('#',...),...} end
local function timed(object,key,label)
  local original=object and object[key];if type(original)~='function' then return end
  object[key]=function(...)
    local frame={child=0};stack[#stack+1]=frame
    local start=os.clock();local output=packed(pcall(original,...));local elapsed=os.clock()-start
    stack[#stack]=nil
    if stack[#stack] then stack[#stack].child=stack[#stack].child+elapsed end
    local entry=profile[label] or {calls=0,inclusive_seconds=0,self_seconds=0};profile[label]=entry
    entry.calls=entry.calls+1;entry.inclusive_seconds=entry.inclusive_seconds+elapsed
    entry.self_seconds=entry.self_seconds+math.max(0,elapsed-frame.child)
    if not output[1] then error(output[2],0) end
    return unpack(output,2,output.n)
  end
end
for _,name in ipairs({'search','decision'}) do timed(modules[name],'run',name) end
for _,name in ipairs({'economy','ordering','hand_ordering','boss_rescue','mixed_rescue','multi_discard','growth','blind_prep','blind_routing'}) do
  timed(modules[name],'suggest',name)
end
timed(modules.strategy,'advise','strategy')
timed(modules.consumables,'suggest','consumables')
timed(modules.consumables,'develop','consumables_develop')
timed(modules.scoring,'score','score')
timed(modules.scoring,'lower_bound','score_lower_bound')
timed(modules.blind_start,'project','blind_start_projection')
timed(modules.paired_deck,'new','paired_population_setup')
timed(modules.shop_sequences,'suggest','shop_sequences')
timed(modules.two_hand_finish,'suggest','two_hand_finish')
timed(modules.resource_finish,'suggest','resource_finish')
timed(modules.strategy.conditional_value,'assess','conditional_value')
local shop_new=modules.shop_scoring.new
modules.shop_scoring.new=function(...)
  local context=shop_new(...)
  timed(context,'compare','shop_compare');timed(context,'readiness','shop_readiness')
  return context
end
local function joker(key,name,ability,cost)
  ability=ability or {};ability.name=name;ability.set='Joker'
  return {key=key,name=name,ability=ability,cost=cost or 4,sell_cost=2}
end
local s={phase='shop',ante=2,dollars=12,bankrupt_at=0,joker_limit=5,consumable_limit=2,
  jokers={},consumeables={},hand={},deck={},playing_cards={},shop_jokers={},shop_booster={},shop_vouchers={},
  hand_size=8,hand_limit=5,hands={Pair={level=1,played=6}},
  round_resets={hands=4,discards=3},current_round={},hands_left=0,discards_left=0,chips=0,
  blind={key='bl_small'},next_blind={key='bl_small',name='Small Blind',chips=400},
  modifiers={},probabilities={normal=1},interest_cap=25,reroll_cost=5}
local suits={'Spades','Hearts','Clubs','Diamonds'}
for i=1,40 do s.playing_cards[i]={id='profile:'..i,rank=2+(i*3)%13,suit=suits[i%4+1],ability={}} end
if workload=='shop_safe' then
  s.jokers={joker('j_joker','Joker',{mult=40})}
  s.shop_jokers={joker('j_popcorn','Popcorn',{mult=20}),joker('j_blackboard','Blackboard',{extra=3}),joker('j_golden','Golden Joker',{extra=4})}
elseif workload=='shop_weak_full' then
  s.joker_limit=2;s.bankrupt_at=-20;s.dollars=4
  s.jokers={joker('j_joker','Joker',{mult=4,eternal=true}),joker('j_credit_card','Credit Card',{extra=20})}
  s.shop_jokers={joker('j_popcorn','Popcorn',{mult=20}),joker('j_blackboard','Blackboard',{extra=3})}
  s.next_blind.chips=800;s.round_resets.hands=1
elseif workload=='shop_dagger' or workload=='shop_marble' or workload=='shop_dagger_marble' then
  s.ante=3;s.dollars=18;s.joker_limit=4;s.next_blind.chips=2400;s.round_resets.hands=3
  local dagger=joker('j_ceremonial','Ceremonial Dagger',{mult=12,eternal=true});dagger.pinned=true
  local marble=joker('j_marble','Marble Joker',{eternal=true});marble.edition={negative=true}
  local hologram=joker('j_hologram','Hologram',{x_mult=1.5,extra=.25})
  local canio=joker('j_caino','Caino',{extra=1,caino_xmult=2})
  local egg=joker('j_egg','Egg',{extra=3,extra_value=12});egg.sell_cost=14
  if workload=='shop_dagger' then s.jokers={dagger,egg,canio,hologram}
  elseif workload=='shop_marble' then
    s.jokers={marble,joker('j_stone','Stone Joker',{extra=25,stone_tally=0}),hologram,egg}
  else s.jokers={dagger,egg,marble,hologram} end
  s.shop_jokers={joker('j_popcorn','Popcorn',{mult=20},5),
    joker('j_stencil','Joker Stencil',{x_mult=1},8),joker('j_runner','Runner',{extra={chips=30,chip_mod=15}},5)}
elseif workload=='nonclear' or workload=='nonclear9' or workload=='nonclear10' or workload=='nonclear12' then
  s.phase='hand';s.hands_left=1;s.discards_left=3;s.blind={key='bl_small',name='Small Blind',chips=550}
  s.current_round={hands_left=1,discards_left=3};s.jokers={joker('j_joker','Joker',{mult=4})}
  s.hand_size=tonumber(workload:match('%d+')) or 8
  for i,c in ipairs(s.playing_cards) do if i<=s.hand_size then s.hand[#s.hand+1]=c else s.deck[#s.deck+1]=c end end
else error('Unknown workload') end
local function json(value)
  if value==nil then return 'null' end
  if type(value)=='boolean' or type(value)=='number' then return tostring(value) end
  if type(value)=='string' then return '"'..value:gsub('[%z\1-\31\\"]',function(c)
    local e={['"']='\\"',['\\']='\\\\',['\n']='\\n',['\r']='\\r',['\t']='\\t'}
    return e[c] or string.format('\\u%04x',string.byte(c)) end)..'"' end
  local out={}
  if #value>0 then for _,v in ipairs(value) do out[#out+1]=json(v) end;return '['..table.concat(out,',')..']' end
  local keys={};for key in pairs(value) do keys[#keys+1]=key end;table.sort(keys)
  for _,key in ipairs(keys) do out[#out+1]=json(key)..':'..json(value[key]) end
  return '{'..table.concat(out,',')..'}'
end
local rows={};local initial=modules.snapshot.fingerprint(s)
for repetition=1,repetitions do
  profile={};stack={}
  local options={prepared_scoring=mode=='prepared',search={samples=8,candidates=8,resource_samples=4,max_evaluations=40000}}
  if workload:match('^nonclear%d+$') then options.search={} end
  local start=os.clock();local result=modules.decision.run(s,modules,nil,options);local elapsed=os.clock()-start
  assert(modules.snapshot.fingerprint(s)==initial,'Profile mutated its input')
  local cache=result.score_cache;result.score_cache=nil
  rows[#rows+1]={repetition=repetition,workload=workload,mode=mode,elapsed_seconds=elapsed,
    input_fingerprint=initial,decision_fingerprint=modules.snapshot.fingerprint(result),action=result.action,
    action_fingerprint=modules.snapshot.fingerprint(result.action),evaluations=result.evaluations,
    search_truncated=result.truncated or false,shop_diagnostics=result.shop_diagnostics,
    readiness_status=result.strategy and result.strategy.readiness and result.strategy.readiness.status,
    readiness_reason=result.strategy and result.strategy.readiness and result.strategy.readiness.reason,
    score_cache=cache,components=profile}
end
return json(rows)

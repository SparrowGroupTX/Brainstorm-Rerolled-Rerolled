-- Manufactured states only: no game callbacks, source archive, saves or RNG.
local Consumables=dofile('Brainstorm/Advisor/consumables.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local checks=0
local function check(v,message) checks=checks+1;assert(v,message) end
local function equal(a,b,message) check(a==b,message..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(rank,id)
  return {id=id or 'rank:'..rank,rank=rank,nominal=rank==14 and 11 or math.min(10,rank),
    suit='Spades',enhancement='c_base',ability={}}
end
local function owned(key,name,id,set)
  return {key=key,name=name,id=id,cost=3,sell_cost=1,debuff=false,face_down=false,
    ability={name=name,set=set or 'Tarot',consumeable={}}}
end
local function empress(id) return owned('c_empress','The Empress',id) end
local function pluto(id) return owned('c_pluto','Pluto',id,'Planet') end
local function negative(c) c.edition={negative=true,type='negative'};c.cost=8;c.sell_cost=4;return c end
local function state(inventory,hand)
  hand=hand or {card(14)}
  return {phase='hand',hand=hand,playing_cards=hand,deck={},jokers={},consumeables=inventory,
    hands={},blind={chips=130},chips=0,dollars=20,hands_left=1,hands_played=0,
    hand_limit=5,hand_size=#hand,discards_left=0,discards_used=0,modifiers={},ante=2,
    consumable_limit=2+#inventory,probabilities={normal=1},
    current_round={hands_left=1,hands_played=0,discards_left=0},
    consumeable_usage_total={tarot=0,planet=0,spectral=0,all=0,tarot_planet=0}}
end
local function losing() return {play={score=0,hand='High Card',indices={1},legal=true}} end
local function zero_scorer(visit)
  return {score=function(s,indices)
    if visit then visit(s,indices) end
    return {score=0,hand='High Card',legal=true,uncertain=false,warnings={}}
  end}
end
local function suggest(s,options,scorer)
  return Consumables.suggest(s,scorer or zero_scorer(),losing(),nil,options or {sequences=false})
end
local function inventory_ids(s)
  local out={};for i,c in ipairs(s.consumeables) do out[i]=c.id end
  return table.concat(out,',')
end

do
  local inventory,hand={},{}
  for i=1,10 do inventory[i]=negative(owned('c_death','Death','death:'..i)) end
  for i=1,8 do hand[i]=card(i+1,'hand:'..i) end
  local s=state(inventory,hand);local before=Snapshot.fingerprint(s)
  local calls,seen,retained=0,{},true
  local scorer=zero_scorer(function(after)
    calls=calls+1
    retained=retained and #after.consumeables==9 and after.consumable_limit==11 and
      inventory_ids(after)=='death:2,death:3,death:4,death:5,death:6,death:7,death:8,death:9,death:10'
    local left,right
    for i,c in ipairs(after.hand) do if c.rank~=s.hand[i].rank then left=i;right=c.rank-1 end end
    assert(left and right and left<right,'Each transformed state preserves directed Death targets')
    local key=left..':'..right;seen[key]=(seen[key] or 0)+1
  end)
  local result,evaluations,d=suggest(s,{sequences=false},scorer)
  equal(result,nil,'Zero-scoring transformations do not invent a useful action')
  equal(calls,6104,'Ten identical Death copies share 28 complete 218-play comparisons')
  equal(evaluations,calls,'All full score calls remain charged')
  equal(d.physical_supported_candidates,280,'Diagnostics retain the original physical target count')
  equal(d.supported_candidates,28,'All distinct Death target pairs remain supported')
  equal(d.duplicate_copies_skipped,9,'Nine redundant physical copies are skipped')
  equal(d.duplicate_candidates_skipped,252,'Only redundant target comparisons are removed')
  equal(d.evaluated_candidates,28,'Every distinct target receives a complete comparison')
  check(not d.truncated,'The entire distinct family fits the unchanged 25,000 cap')
  check(retained,'Every projected score retains all nine unused copies, physical IDs and capacity')
  for i=1,7 do for j=i+1,8 do equal(seen[i..':'..j],218,'Each legal target pair receives every play subset') end end
  equal(Snapshot.fingerprint(s),before,'The full source snapshot is unchanged')
  local again,again_calls,again_d=suggest(s)
  equal(again,result,'Repeated recommendation is deterministic')
  equal(again_calls,evaluations,'Repeated score work is deterministic')
  equal(Snapshot.fingerprint(again_d),Snapshot.fingerprint(d),'Repeated diagnostics are deterministic')
  local _,bounded,limited=suggest(s,{sequences=false,max_evaluations=6103})
  equal(bounded,5886,'A one-score-short budget admits only 27 whole comparisons')
  equal(limited.evaluated_candidates,27,'No partial 28th target is reported')
  check(limited.truncated,'An incomplete distinct target family remains explicit')
  local after=assert(Consumables.apply(s,7,{1,8}))
  equal(inventory_ids(after),'death:1,death:2,death:3,death:4,death:5,death:6,death:8,death:9,death:10',
    'Applying a nonrepresentative physical use still removes exactly that copy')
  equal(after.consumable_limit,11,'A Negative use removes exactly one capacity slot')
  equal(after.hand[1].id,'hand:1','Death preserves the target physical identity')
  equal(after.hand[1].rank,9,'Death applies its actual right-to-left transformation')
  equal(#after.playing_cards,8,'Duplicate planning and use preserve the playing population')
end

local function pair_case(label,edit,expected)
  local a,b=empress('first'),empress('second')
  if edit then edit(a,b) end
  local s=state({a,b});local before=Snapshot.fingerprint(s)
  local _,evaluations,d=suggest(s)
  equal(evaluations,expected,label..' complete scoring count')
  equal(d.supported_candidates,expected,label..' distinct target count')
  equal(d.physical_supported_candidates,2,label..' original physical count')
  equal(d.duplicate_copies_skipped,2-expected,label..' duplicate diagnostic')
  equal(Snapshot.fingerprint(s),before,label..' leaves public input untouched')
end
pair_case('Plain equivalent copies',nil,1)
pair_case('Negative equivalent copies',function(a,b) negative(a);negative(b) end,1)
pair_case('Ordinary versus Negative',function(_,b) negative(b) end,2)
pair_case('Holographic versus Polychrome',function(a,b) a.edition={holo=true};b.edition={polychrome=true} end,2)
pair_case('Different purchase price',function(_,b) b.cost=4 end,2)
pair_case('Different resale price',function(_,b) b.sell_cost=2 end,2)
pair_case('Different complete ability',function(_,b) b.ability.extra_value=1 end,2)
pair_case('Different copied source metadata',function(a,b)
  a.copy_source={supported=true,params={bypass_discovery_center=true}}
  b.copy_source={supported=true,params={bypass_discovery_center=false}}
end,2)
pair_case('Nested IDs remain significant',function(a,b) a.copy_source={id='nested:a'};b.copy_source={id='nested:b'} end,2)
pair_case('Equal plain nested metadata',function(a,b)
  a.copy_source={supported=true,params={bypass_discovery_center=true},ability={id='same'}}
  b.copy_source={ability={id='same'},params={bypass_discovery_center=true},supported=true}
end,1)
pair_case('Function metadata is not equated',function(a,b)
  local fn=function() end;a.callback=fn;b.callback=fn
end,2)
pair_case('Metatable metadata is not equated',function(a,b)
  a.extra=setmetatable({value=1},{});b.extra=setmetatable({value=1},{})
end,2)
pair_case('Nonfinite numeric metadata is not equated',function(a,b) a.extra=math.huge;b.extra=math.huge end,2)
pair_case('Overlong metadata is not equated',function(a,b) a.extra=string.rep('x',8193);b.extra=a.extra end,2)
pair_case('Concealed metadata is not equated',function(a,b) a.face_down=true;b.face_down=true end,2)
pair_case('Redacted identities are not equated',function(a,b) a.identity_redacted=true;b.identity_redacted=true end,2)
pair_case('Unknown cards are not equated',function(a,b) a.unknown=true;b.unknown=true end,2)
pair_case('Concealed flag is not equated',function(a,b) a.concealed=true;b.concealed=true end,2)
pair_case('Name-only identity is not equated',function(a,b) a.key=nil;b.key=nil end,2)
pair_case('Excessive nesting is not equated',function(a,b)
  local function nested()
    local value={};local cursor=value
    for _=1,17 do cursor.child={};cursor=cursor.child end
    return value
  end
  a.extra=nested();b.extra=nested()
end,2)

do
  local a,b=empress('cycle:a'),empress('cycle:b')
  a.extra={};a.extra.self=a.extra;b.extra={};b.extra.self=b.extra
  local s=state({a,b});local _,calls,d=suggest(s)
  equal(calls,2,'Cyclic metadata retains separate complete comparisons')
  equal(d.duplicate_copies_skipped,0,'A cyclic comparison does not qualify duplicate equivalence')
  check(a.extra.self==a.extra and b.extra.self==b.extra,'Cyclic public metadata remains untouched')
end

do
  local first,second,third=empress('holo:first'),empress('poly'),empress('holo:last')
  first.edition={holo=true};second.edition={polychrome=true};third.edition={holo=true}
  local s=state({first,second,third});local seen={}
  local _,calls,d=suggest(s,nil,zero_scorer(function(after) seen[inventory_ids(after)]=true end))
  equal(calls,3,'Separated copies are not merged across meaningful inventory order')
  equal(d.duplicate_copies_skipped,0,'Noncontiguous equal metadata does not erase physical choices')
  check(seen['poly,holo:last'] and seen['holo:first,holo:last'] and seen['holo:first,poly'],
    'Each distinct post-removal ordered inventory is scored')
  local a=empress('ordinary');local b=negative(empress('negative'))
  local normal=state({a,b});local used_a=assert(Consumables.apply(normal,1,{1}))
  local used_b=assert(Consumables.apply(normal,2,{1}))
  equal(used_a.consumable_limit,4,'Ordinary use preserves current capacity')
  equal(used_b.consumable_limit,3,'Negative use releases its added capacity')
end

do
  local inventory={}
  for i=1,10 do inventory[i]=negative(empress('empress:'..i)) end
  inventory[11]=owned('c_hermit','The Hermit','hermit')
  local s=state(inventory)
  s.jokers={{key='j_perkeo',id='perkeo',name='Perkeo',ability={name='Perkeo'},blueprint_compat=true}}
  local observed={}
  local strategy={build_profile=Strategy.build_profile,development_gain=Strategy.development_gain,
    preservation_cost=function(before,after,index)
      equal(#before.consumeables,11,'Preservation sees the entire starting copying pool')
      equal(#after.consumeables,10,'Preservation sees every retained physical copy')
      local _,info=Strategy.inventory_value(after)
      observed[before.consumeables[index].key]=info.probabilities
      return Strategy.preservation_cost(before,after,index)
    end}
  local before=Snapshot.fingerprint(s)
  local _,calls,d=suggest(s,{sequences=false,strategy=strategy})
  equal(calls,2,'A full Perkeo copying pool still shares duplicate one-use scoring')
  equal(d.duplicate_copies_skipped,9,'Perkeo duplicate counts are not mistaken for separate choices')
  check(observed.c_empress and observed.c_hermit,'Both distinct inventory effects reach preservation valuation')
  equal(observed.c_empress.c_empress,0.9,'Using one Empress retains the true nine-of-ten copy probability')
  equal(observed.c_empress.c_hermit,0.1,'The other retained source remains in the copying pool')
  equal(observed.c_hermit.c_empress,1,'Using Hermit leaves every one of the ten Empress copies')
  equal(Snapshot.fingerprint(s),before,'Perkeo source inventory and copying fields are unchanged')
end

for _,reversed in ipairs({false,true}) do
  local planets={negative(pluto('pluto:1')),negative(pluto('pluto:2'))}
  local tarots={negative(empress('empress:1')),negative(empress('empress:2'))}
  local inventory=reversed and {planets[1],planets[2],tarots[1],tarots[2]} or
    {tarots[1],tarots[2],planets[1],planets[2]}
  local s=state(inventory);local before=Snapshot.fingerprint(s)
  local prior=Search.run(s,Scoring,{max_evaluations=100,samples=0})
  local use,calls,d=Consumables.suggest(s,Scoring,prior)
  check(use and use.sequence,'Distinct upgrade and Tarot remain a jointly evaluated rescue')
  equal(calls,3,'Two equivalent groups need two singles plus one complete joint comparison')
  equal(d.physical_supported_candidates,4,'Sequence diagnostics retain all four physical sources')
  equal(d.supported_candidates,2,'Sequence starts are distinct physical-effect representatives')
  equal(d.duplicate_copies_skipped,2,'Two redundant sequence sources are skipped')
  equal(d.evaluated_sequences,1,'Only one equivalent upgrade-then-Tarot sequence is scored')
  equal(use.action.index,reversed and 1 or 3,'The concrete first action selects the earliest Planet')
  equal(use.sequence.second_index,reversed and 2 or 1,'Follow-up index reflects the actual removed Planet')
  equal(use.play.score,52,'First-use score remains separate from the combined result')
  equal(use.sequence.play.score,156,'Actual scorer verifies the combined clearing play')
  local repeated=Consumables.suggest(s,Scoring,prior)
  equal(Snapshot.fingerprint(use),Snapshot.fingerprint(repeated),'Joint recommendation repeats deterministically')
  equal(Snapshot.fingerprint(s),before,'Joint planning leaves the full source state unchanged')
  local after=assert(Consumables.apply(s,use.action.index,use.action.targets))
  equal(#after.consumeables,3,'The first use consumes just one of four cards')
  local next_prior=Search.run(after,Scoring,{max_evaluations=100,samples=0})
  local next_use=Consumables.suggest(after,Scoring,next_prior)
  check(next_use and not next_use.sequence,'Recalculation yields a single concrete Tarot follow-up')
  equal(next_use.action.index,use.sequence.second_index,'Recalculated inventory index agrees with projection')
  equal(after.consumeables[next_use.action.index].id,'empress:1','Follow-up consumes its earliest physical representative')
  local final=assert(Consumables.apply(after,next_use.action.index,next_use.action.targets))
  equal(#final.consumeables,2,'The two unused physical duplicates remain after the rescue')
  equal(final.consumable_limit,s.consumable_limit-2,'Each of two Negative uses removes exactly one capacity slot')
  local remaining_ids=inventory_ids(final)
  equal(remaining_ids,reversed and 'pluto:2,empress:2' or 'empress:2,pluto:2','Surviving physical order is preserved')
  equal(Scoring.score(final,{1}).score,156,'Actual final state independently supports the projected score')
end

print('advisor_consumable_duplicates: '..checks..' checks passed')

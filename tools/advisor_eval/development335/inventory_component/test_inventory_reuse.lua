-- Manufactured detached states only. No game callbacks, archives, saves or RNG.
local root='tools/advisor_eval/development335/inventory_component/'
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function equal(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end
local function same(a,b,m)
  local function compare(x,y,path)
    if type(x)~='table' or type(y)~='table' then
      assert(x==y,m..' at '..path..': '..tostring(x)..' ~= '..tostring(y));return
    end
    for key,value in pairs(x) do compare(value,y[key],path..'.'..tostring(key)) end
    for key in pairs(y) do assert(x[key]~=nil,m..' unexpected field '..path..'.'..tostring(key)) end
  end
  checks=checks+1;compare(a,b,'result')
end
local function clone(v) if type(v)~='table' then return v end;local out={};for k,x in pairs(v) do out[k]=clone(x) end;return out end
local function load_strategy(path)
  local f=assert(io.open(path,'rb'));local source=f:read('*a');f:close();source=source:gsub('\r\n','\n')
  local markers={
    {'local function build_profile(snapshot, stats)\n','profiles'},
    {'local function deck_stats(snapshot)\n','deck_scans'},
    {'inventory_value=function(snapshot,inventory,options)\n','inventory'},
    {'local function development_gain(before,after,targets,profile)\n','development'},
  }
  for _,entry in ipairs(markers) do
    local start,finish=assert(source:find(entry[1],1,true));
    source=source:sub(1,finish)..'    audit_counts.'..entry[2]..'=audit_counts.'..entry[2]..'+1\n'..source:sub(finish+1)
  end
  local marker='inventory_value=function(snapshot,inventory,options)\n'
  local start,finish=assert(source:find(marker,1,true))
  source=source:sub(1,finish)..'    if inventory==nil then audit_counts.original_inventory=audit_counts.original_inventory+1 else audit_counts.retained_inventory=audit_counts.retained_inventory+1 end\n'..source:sub(finish+1)
  local counts={profiles=0,deck_scans=0,inventory=0,original_inventory=0,retained_inventory=0,development=0}
  local strategy=assert(loadstring('local audit_counts=...\n'..source,'@'..path))(counts)
  return strategy,counts
end
local function wire(path)
  local c=dofile(path);c.deck_development=dofile('Brainstorm/Advisor/deck_development.lua')
  c.deck_development.spectral=dofile('Brainstorm/Advisor/spectral_development.lua')
  return c
end
local function item(key,id,negative)
  local names={c_death='Death',c_empress='The Empress',c_heirophant='The Hierophant',c_strength='Strength',
    c_hanged_man='The Hanged Man',c_hermit='The Hermit',c_temperance='Temperance',c_chariot='The Chariot',
    c_justice='Justice',c_pluto='Pluto',c_mercury='Mercury',c_talisman='Talisman',c_cryptid='Cryptid',c_trance='Trance'}
  local spectral=key=='c_talisman' or key=='c_cryptid' or key=='c_trance'
  local set=(key=='c_pluto' or key=='c_mercury') and 'Planet' or spectral and 'Spectral' or 'Tarot'
  return {key=key,name=names[key],id=id,edition=negative and {negative=true} or nil,cost=3,sell_cost=1,
    ability={name=names[key],set=set,consumeable={}}}
end
local function card(rank,id)
  return {id=id,rank=rank,nominal=rank==14 and 11 or math.min(10,rank),suit='Spades',enhancement='c_base',ability={}}
end
local function joker(key)
  local n=({j_perkeo='Perkeo',j_blueprint='Blueprint',j_brainstorm='Brainstorm',j_baron='Baron',j_caino='Caino'})[key] or key
  return {key=key,name=n,ability={name=n},blueprint_compat=true,sell_cost=10}
end
local function state(inventory,n)
  local hand={};for i=1,n or 5 do hand[i]=card(i<4 and 13 or 12,'hand:'..i) end
  local population={};for i,c in ipairs(hand) do population[i]=c end
  for i=#hand+1,28 do population[i]=card(i<=20 and 13 or 12,'deck:'..i) end
  return {phase='hand',ante=2,win_ante=8,hand=hand,playing_cards=population,deck={},jokers={},
    consumeables=inventory or {},consumable_limit=2+#(inventory or {}),dollars=20,chips=0,
    blind={chips=100000},hands={Pair={played=9,level=4,chips=55,mult=5,l_chips=15,l_mult=1}},
    hand_limit=5,hand_size=#hand,hands_left=3,discards_left=0,hands_played=0,discards_used=0,
    current_round={hands_left=3,discards_left=0},modifiers={},probabilities={normal=1},
    consumeable_usage_total={all=0,tarot=0,planet=0,spectral=0,tarot_planet=0}}
end
local metrics={}
local function compare(label,s,opts,mode)
  opts=opts or {};local before=Snapshot.fingerprint(s)
  local results,counts={},{}
  for i,kind in ipairs({'base','candidate'}) do
    local suffix=kind=='base' and '.base.lua' or '.lua'
    local strategy,count=load_strategy(root..'strategy'..suffix)
    local cons=wire(root..'consumables'..suffix)
    local options=clone(opts);options.strategy=strategy
    local score_calls,development_gains,preservation_results=0,{},{}
    local gain=strategy.development_gain
    strategy.development_gain=function(...)
      local value=gain(...);development_gains[#development_gains+1]=value;return value
    end
    local preservation=strategy.preservation_cost
    strategy.preservation_cost=function(before,after,index,context)
      local loss,reason,last=preservation(before,after,index,context)
      preservation_results[#preservation_results+1]={loss=loss,reason=reason,last=last,index=index}
      return loss,reason,last
    end
    local scorer={score=function(public,indices)
      score_calls=score_calls+1
      if mode=='zero' then return {score=0,hand='High Card',legal=true,uncertain=false,warnings={}} end
      return Scoring.score(public,indices)
    end}
    local search={play={score=0,hand='High Card',indices={1},legal=true}}
    if mode=='develop' then search.play=Scoring.score(s,{1,2,3});search.play.indices={1,2,3};check(search.play.score>=s.blind.chips,label..' starts with clearing play') end
    local action,evaluations,diagnostics=cons.suggest(s,scorer,search,nil,options)
    results[i]={action=action,evaluations=evaluations,diagnostics=diagnostics,development=development_gains,preservation=preservation_results}
    counts[i]=count;count.score_calls=score_calls
    equal(Snapshot.fingerprint(s),before,label..' '..kind..' leaves full source snapshot unchanged')
  end
  same(results[1],results[2],label..' full recommendation, diagnostics, development and preservation outputs match')
  equal(counts[1].score_calls,counts[2].score_calls,label..' complete scorer calls preserved')
  equal(counts[1].retained_inventory,counts[2].retained_inventory,label..' every retained inventory remains valued')
  equal(counts[1].development,counts[2].development,label..' every target development remains valued')
  check(counts[2].profiles<=counts[1].profiles,label..' no added profile build')
  if counts[1].retained_inventory>0 then
    equal(counts[2].profiles,1,label..' one decision profile')
    equal(counts[2].original_inventory,1,label..' one complete original inventory value')
  end
  metrics[#metrics+1]={label=label,baseline=counts[1],candidate=counts[2]}
  return results[2],counts[2]
end

-- Eight-card duplicate family: all 28 Death targets and their complete play
-- comparisons survive while full population/profile and starting urn repeat less.
do
  local inv={};for i=1,10 do inv[i]=item('c_death','death:'..i,true) end
  local s=state(inv,8);for i,c in ipairs(s.hand) do c.rank=i+1;c.nominal=i+1 end
  s.jokers={joker('j_blueprint'),joker('j_perkeo'),joker('j_brainstorm')}
  s.used_vouchers={v_observatory=true}
  local r,c=compare('ten Negative Death, 28 complete targets',s,{sequences=false},'zero')
  equal(c.score_calls,6104,'All 28 distinct transformations retain all 218 play subsets')
  equal(c.retained_inventory,28,'All 28 retained inventories recalculated')
  equal(r.diagnostics.duplicate_copies_skipped,9,'Release 334 adjacent grouping preserved')
  equal(r.diagnostics.evaluated_candidates,28,'No distinct Death target lost')
end

local scenarios={
  {'mixed Perkeo Observatory',{ 'c_strength','c_mercury','c_death','c_pluto','c_empress'},true,true},
  {'ordinary inventory',{ 'c_strength','c_death','c_empress'},false,false},
  {'Observatory without Perkeo',{ 'c_mercury','c_pluto','c_death'},false,true},
  {'last useful Perkeo source',{ 'c_strength'},true,false},
  {'last matching Planet source',{ 'c_mercury'},true,true},
  {'different after ranks',{ 'c_death','c_strength'},true,false},
  {'changed population and generated cards',{ 'c_hanged_man','c_cryptid','c_trance','c_talisman'},true,true},
  {'cash payouts with full inventory',{ 'c_hermit','c_temperance','c_empress','c_mercury'},true,true},
}
for _,case in ipairs(scenarios) do
  local inv={};for i,key in ipairs(case[2]) do inv[i]=item(key,key..':'..i,i%2==0) end
  local s=state(inv,5)
  if case[3] then s.jokers={joker('j_blueprint'),joker('j_perkeo'),joker('j_brainstorm')} end
  if case[4] then s.used_vouchers={v_observatory=true} end
  compare(case[1],s,{sequences=false})
end

-- Metadata-distinct and separated copies preserve physical order, capacity and
-- independent candidates; score effects differ with held edition ordering.
do
 local inv={item('c_empress','holo:first'),item('c_mercury','planet'),item('c_empress','poly'),item('c_empress','holo:last')}
 inv[1].edition={holo=true};inv[3].edition={polychrome=true};inv[4].edition={holo=true}
 local s=state(inv,4);s.used_vouchers={v_observatory=true};s.jokers={joker('j_perkeo')}
 local r=compare('ordered metadata-distinct copies',s,{sequences=false})
 equal(r.diagnostics.duplicate_copies_skipped,0,'Distinct inventory order remains unmerged')
end

-- Existing bounded Planet/Tarot sequence: no candidate or score budget change.
for _,reversed in ipairs({false,true}) do
 local inv={item('c_pluto','pluto:1',true),item('c_pluto','pluto:2',true),item('c_empress','empress:1',true),item('c_empress','empress:2',true)}
 if reversed then inv={inv[3],inv[4],inv[1],inv[2]} end
 local s=state(inv,1);s.hand[1].rank=14;s.hand[1].nominal=11;s.hands={};s.blind.chips=130;s.hands_left=1
 local r=compare('Planet Tarot sequence '..tostring(reversed),s)
 check(r.action and r.action.sequence,'Sequence still enables the manufactured rescue')
 equal(r.evaluations,3,'Two single comparisons and one complete sequence preserved')
end

-- Already-clearing branch shares its existing target profile with preservation.
for _,perkeo in ipairs({false,true}) do
 local inv={item('c_strength','strength'),item('c_empress','empress'),item('c_mercury','mercury'),item('c_chariot','chariot')}
 local s=state(inv,5);s.blind.chips=20
 if perkeo then s.jokers={joker('j_perkeo')} end
 compare('bounded clear development '..tostring(perkeo),s,nil,'develop')
end

-- No work is added where no target reaches valuation.
do
 local s=state({},5)
 local _,c=compare('empty inventory',s,{sequences=false})
 equal(c.profiles,0,'Empty inventory does not eagerly build strategic context')
 s.consumeables={item('c_death','death')};s.hand={}
 local _,d=compare('empty hand',s,{sequences=false})
 equal(d.profiles,0,'Invalid target family does not eagerly build context')
end

-- The context is local to each invocation: same table may change between
-- actual advice decisions, including rank commitment, horizon and inventory.
do
 local s=state({item('c_strength','strength'),item('c_empress','empress')},5)
 local strategy,count=load_strategy(root..'strategy.lua');local cons=wire(root..'consumables.lua')
 local function advice()
   return {cons.suggest(s,Scoring,{play={score=0,indices={1},hand='High Card',legal=true}},nil,{strategy=strategy,sequences=false})}
 end
 local first=advice();local saved=Snapshot.fingerprint(first);equal(count.profiles,1,'First call builds one profile')
 for _,c in ipairs(s.playing_cards) do c.rank=2;c.nominal=2 end
 s.hands={['High Card']={level=8,played=50,chips=75,mult=8,l_chips=10,l_mult=1}}
 s.jokers={joker('j_perkeo')};s.used_vouchers={v_observatory=true};s.consumeables[3]=item('c_pluto','fresh',true)
 s.ante=8;s.blind.boss=true
 local second=advice();equal(count.profiles,2,'Next advice rebuilds after public state changes on same table')
 local baseline=wire(root..'consumables.base.lua');local old=load_strategy(root..'strategy.base.lua')
 local expected={baseline.suggest(s,Scoring,{play={score=0,indices={1},hand='High Card',legal=true}},nil,{strategy=old,sequences=false})}
 same(second,expected,'Changed state advice exactly matches fresh uncached baseline')
 equal(Snapshot.fingerprint(first),saved,'Later decisions cannot mutate previous returned advice')
end

-- Optional new API is absent on old/custom strategies. Existing three-argument
-- preservation and generic development callbacks continue to run unchanged.
do
 local s=state({item('c_strength','strength'),item('c_empress','empress')},4)
 local outputs={}
 for i,suffix in ipairs({'.base.lua','.lua'}) do
   local calls=0
   local custom={preservation_cost=function(...)
       equal(select('#',...),3,'Legacy preservation gets exactly its prior three arguments')
       local before,after,index=...;calls=calls+1;return index*2,nil,false
     end,development_gain=function(...)
       equal(select('#',...),3,'Legacy generic development gets exactly its prior three arguments')
       local before,after,targets=...;return #targets*7
     end}
   local cons=wire(root..'consumables'..suffix)
   outputs[i]={cons.suggest(s,Scoring,{play={score=0,hand='High Card',indices={1},legal=true}},nil,{strategy=custom,sequences=false})}
   outputs[i].calls=calls
 end
 same(outputs[1],outputs[2],'Custom strategy without context/profile functions retains fallback behavior')
end

-- Context helper recomputes retained states and ignores context bound to a
-- different starting object. Returned profile/inventory are not advice output.
do
 local original=load_strategy(root..'strategy.base.lua')
 local candidate,counts=load_strategy(root..'strategy.lua')
 local s=state({item('c_mercury','a'),item('c_mercury','b',true),item('c_strength','c'),item('c_empress','d')},5)
 s.used_vouchers={v_observatory=true};s.jokers={joker('j_perkeo'),joker('j_perkeo')}
 local ctx=candidate.preservation_context(s);local ctx_before=Snapshot.fingerprint(ctx)
 for index=1,#s.consumeables do
   local after=clone(s);table.remove(after.consumeables,index)
   for variation=1,3 do
     if variation==2 then after.consumeables[#after.consumeables+1]=item('c_pluto','new') end
     if variation==3 then after.consumeables[1].debuff=true;after.hands.Pair.level=20;after.dollars=0 end
     same({original.preservation_cost(s,after,index)},{candidate.preservation_cost(s,after,index,ctx)},'Every changed retained pool uses original before profile')
   end
 end
 equal(Snapshot.fingerprint(ctx),ctx_before,'Preservation use does not mutate shared context')
 equal(counts.original_inventory,1,'Explicit context reuses original pool once')
 equal(counts.retained_inventory,12,'All twelve candidate inventories are recomputed')
 local other=clone(s);other.ante=8;other.blind.boss=true
 local after=clone(other);table.remove(after.consumeables,1)
 same({original.preservation_cost(other,after,1)},{candidate.preservation_cost(other,after,1,ctx)},'Context from a different snapshot falls back to a fresh before profile')
 equal(counts.original_inventory,2,'Different snapshot cannot reuse prior inventory')
end

for _,m in ipairs(metrics) do
 print(string.format('METRIC %s | profiles %d -> %d | original inventory %d -> %d | retained inventory %d -> %d | score calls %d -> %d',
   m.label,m.baseline.profiles,m.candidate.profiles,m.baseline.original_inventory,m.candidate.original_inventory,
   m.baseline.retained_inventory,m.candidate.retained_inventory,m.baseline.score_calls,m.candidate.score_calls))
end
print('inventory decision reuse: '..checks..' checks passed')

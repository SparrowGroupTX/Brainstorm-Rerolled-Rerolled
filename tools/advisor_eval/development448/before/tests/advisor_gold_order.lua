-- Manufactured pure row family; no scoring, RNG, source or game execution.
local O=dofile('Brainstorm/Advisor/gold_order.lua')
local S=dofile('Brainstorm/Advisor/snapshot.lua')
local Gold=dofile('Brainstorm/Advisor/gold_goal.lua')
local Perkeo=dofile('Brainstorm/Advisor/gold_perkeo.lua')
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function eq(a,b,m)check(a==b,m..': '..tostring(a)..' ~= '..tostring(b))end
local function fail()error('Pure physical enumeration must not score or use RNG')end
math.random=fail;pseudorandom=fail;pseudoseed=fail
local modules={gold_goal=Gold,gold_perkeo=Perkeo,scoring={score=fail,lower_bound=fail},phase_copy={target_order=fail,reorder=fail}}
local function state()
 local s=F.state()
 s.jokers={F.joker('j_blueprint','Blueprint','bp:2'),F.joker('j_brainstorm','Brainstorm','bs'),
  F.joker('j_perkeo','Perkeo','perkeo'),F.joker('j_blueprint','Blueprint','bp:1'),
  F.joker('j_mime','Mime','mime'),F.joker('j_baron','Baron','baron')}
 return s
end
local function target_map(f)
 local map={};for _,t in ipairs(f.targets)do map[t.id]={row=t.selected_row_key,count=t.maximum_effects}end;return map
end
local function find_row(f,key)for _,r in ipairs(f.rows)do if r.key==key then return r end end end
local function reordered(s,order)
 local out=S.copy(s);out.jokers={};for i,index in ipairs(order)do out.jokers[i]=S.copy(s.jokers[index])end;return out
end
do
 local s=state();local before=S.fingerprint(s);local f,why=O.family(s,modules)
 check(f and f.complete,why or 'complete six-card family')
 eq(f.permutation_count,720,'every legal physical permutation participates in target maximization')
 eq(#f.targets,3,'each physical non-copy compatible target is separate')
 check(#f.rows<=4,'only current plus three canonical targets are exposed for scoring')
 eq(f.score_calls,0,'no score work is hidden in enumeration')
 eq(f.max_rows,6,'strict public candidate bound')
 eq(f.max_permutations,720,'strict internal permutation bound')
 check(not f.score_optimized and not f.all_scoring_orders_enumerated,'limited family does not claim exhaustive scoring optimization')
 eq(f.rows[1].action_count,0,'current physical row always appears first at zero action cost')
 local seen={}
 for _,r in ipairs(f.rows)do
  check(not seen[r.key],'candidate physical rows deduplicate');seen[r.key]=true
  local after=assert(O.apply(s,r))
  for i,index in ipairs(r.order)do
   eq(after.jokers[i].id,s.jokers[index].id,'receipt applies the exact physical permutation')
   eq(r.physical_ids[i],after.jokers[i].id,'physical IDs bind every target slot')
  end
  eq(S.fingerprint(after.consumeables),S.fingerprint(s.consumeables),'reordering preserves whole inventory exactly')
  check(after.jokers[1]~=s.jokers[r.order[1]],'applied Joker fields are detached')
  after.consumeables[1].ability.extra_value=77
  eq(s.consumeables[1].ability.extra_value,0,'other endpoint arrays are detached too')
  if r.moved>0 then
   eq(r.action_count,1,'one explicit reorder is charged')
   eq(r.action.kind,'reorder_jokers','changed row supplies an actual action')
  else check(r.action==nil,'current row does not invent an action')end
 end
 for _,t in ipairs(f.targets)do
  eq(t.maximum_effects,4,'all three physical copies can reach each supported target')
  check(find_row(f,t.selected_row_key),'every maximizer receipt belongs to the exposed family')
 end
 eq(S.fingerprint(s),before,'complete enumeration and all applies preserve input')
 local canonical=target_map(f)
 for _,order in ipairs({{6,5,4,3,2,1},{3,2,1,6,5,4},{2,3,4,5,6,1},{5,4,3,2,1,6},
  {4,1,6,2,5,3},{1,3,5,2,4,6},{2,4,6,1,3,5},{3,6,2,5,1,4}})do
  local changed=reordered(s,order);local family=assert(O.family(changed,modules))
  eq(S.fingerprint(target_map(family)),S.fingerprint(canonical),'canonical target rows are independent of current movable order')
 end
 for _,t in ipairs(f.targets)do
  local changed=assert(O.apply(s,find_row(f,t.selected_row_key)))
  eq(S.fingerprint(target_map(assert(O.family(changed,modules)))),S.fingerprint(canonical),'fresh advice after a candidate reorder preserves the same canonical family')
 end
end
do
 local s=state();s.jokers[2].pinned=true;s.jokers[5].ability.pinned=true
 local f=assert(O.family(s,modules));eq(f.permutation_count,24,'two pinned slots leave exactly four-factorial permutations')
 for _,r in ipairs(f.rows)do
  eq(r.order[2],2,'physical pin is never moved');eq(r.order[5],5,'ability pin is never moved')
  check(O.apply(s,r),'every pinned-family candidate is executable as a legal permutation')
 end
 local canonical=target_map(f)
 local changed=reordered(s,{6,2,4,3,5,1})
 eq(S.fingerprint(target_map(assert(O.family(changed,modules)))),S.fingerprint(canonical),'canonical ties remain stable with fixed pinned positions')
 s=state();for _,j in ipairs(s.jokers)do j.pinned=true end
 f=assert(O.family(s,modules));eq(f.permutation_count,1,'fully pinned row has one legal permutation');eq(#f.rows,1,'all targets deduplicate onto the only legal row')
 s=state();s.jokers[1].blueprint_compat=false
 f=assert(O.family(s,modules));for _,t in ipairs(f.targets)do eq(t.maximum_effects,4,'an incompatible copy can still start a compatible chain through Brainstorm')end
 s.jokers[2].blueprint_compat=false
 f=assert(O.family(s,modules));for _,t in ipairs(f.targets)do eq(t.maximum_effects,3,'incompatible intermediate targets prevent unsupported upstream copy effects')end
 s=state();s.jokers[1].debuff=true
 f=assert(O.family(s,modules));for _,t in ipairs(f.targets)do eq(t.maximum_effects,3,'debuffed copy supplies no forwarded effect')end
 s=state();s.jokers[1].ability.perishable=true;s.jokers[1].ability.perish_tally=0
 f=assert(O.family(s,modules));for _,t in ipairs(f.targets)do eq(t.maximum_effects,3,'expired copy supplies no forwarded effect')end
 s=state();s.jokers[1].ability.perma_debuff=true
 f=assert(O.family(s,modules));for _,t in ipairs(f.targets)do eq(t.maximum_effects,3,'permanently debuffed copy supplies no forwarded effect')end
 s=state();s.jokers={F.joker('j_brainstorm','Brainstorm','a'),F.joker('j_brainstorm','Brainstorm','b')}
 f=assert(O.family(s,modules));eq(#f.rows,1,'copy-only cycle has no invented target');eq(#f.targets,0,'cycles do not become a source identity')
 s=state();s.jokers={F.joker('j_baron','Baron','a'),F.joker('j_mime','Mime','b')}
 f=assert(O.family(s,modules));eq(#f.rows,1,'without an active copy only current row is exposed')
 s=state();s.jokers={F.joker('j_blueprint','Blueprint','bp'),F.joker('j_baron','Baron','a'),F.joker('j_baron','Baron','b')}
 f=assert(O.family(s,modules));eq(#f.targets,2,'duplicate Joker keys retain distinct physical copy targets')
 check(f.targets[1].id~=f.targets[2].id,'target IDs do not collapse equal names')
end
do
 local changes={
  function(s)s.phase='hand'end,function(s)s.ordering_safe=false end,function(s)s.jokers_shuffling=true end,
  function(s)s.jokers[1].id=s.jokers[2].id end,function(s)s.jokers[1].id=nil end,
  function(s)s.jokers[1].ability.perishable=true;s.jokers[1].ability.perish_tally=nil end,
  function(s)s.jokers[1].debuff=nil end,function(s)s.jokers[1].blueprint_compat=nil end,
  function(s)s.jokers[1].pinned='false'end,function(s)s.jokers[1].ability.pinned='false'end,
  function(s)s.jokers[1].ability.name='Joker'end,function(s)s.jokers[3].ability.name='Blueprint'end,
  function(s)s.jokers[3].key='j_unknown'end,function(s)s.jokers[3]=F.joker('j_ceremonial','Ceremonial Dagger','dagger')end,
  function(s)s.jokers[3].states={drag={is=true}}end,function(s)s.jokers[7]=F.joker('j_joker','Joker','extra')end,
  function(s)s.jokers[3].states=setmetatable({},{__index=fail})end,
  function(s)s.blind=setmetatable({},{__index=fail})end,
 }
 for i,change in ipairs(changes)do local s=state();change(s);check(not O.family(s,modules),'unknown/unsupported boundary '..i)end
 local s=state();s.jokers[1]={face_down=true,key=setmetatable({},{__index=fail}),ability=setmetatable({},{__index=fail})}
 check(not O.family(s,modules),'hidden whole-row rejection precedes identity inspection')
 s=state();local f=assert(O.family(s,modules));local row=f.rows[#f.rows]
 local bad=S.copy(row);bad.order[2]=bad.order[1];check(not O.apply(s,bad),'duplicate slot cannot execute')
 bad=S.copy(row);bad.physical_ids[1]='other';check(not O.apply(s,bad),'changed target identity cannot execute')
 bad=S.copy(row);bad.input_ids[1]='other';check(not O.apply(s,bad),'changed input identity cannot execute')
 bad=S.copy(row);bad.key='imagined';check(not O.apply(s,bad),'changed stable row signature cannot execute')
 bad=S.copy(row);bad.action_count=99;check(not O.apply(s,bad),'inconsistent action count cannot execute')
 bad=S.copy(row);bad.action.order[1]=bad.action.order[2];check(not O.apply(s,bad),'a different published action cannot reuse the candidate projection')
 bad=S.copy(f.rows[1]);bad.action={kind='reorder_jokers',area='jokers',order=S.copy(bad.order)};check(not O.apply(s,bad),'current row cannot invent a redundant reorder')
 local altered=S.copy(s);altered.jokers[1].debuff=true;check(not O.apply(altered,row),'changed activity invalidates the old copy receipt')
 altered=S.copy(s);altered.jokers[1].pinned=true;check(not O.apply(altered,row),'changed pin metadata invalidates the old physical family')
 altered=reordered(s,{6,5,4,3,2,1});check(not O.apply(altered,row),'old indices cannot be reused after a physical reorder')
 check(not O.family(s,{}),'unknown mechanical row classifier cannot silently admit targets')
end
print('advisor_gold_order: '..checks..' pure physical-family checks; zero scores or RNG')

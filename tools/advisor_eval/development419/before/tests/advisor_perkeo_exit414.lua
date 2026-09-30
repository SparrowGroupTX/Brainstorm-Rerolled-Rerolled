-- Independently invented public states; no captured-state replay or RNG.
local Phase=dofile('Brainstorm/Advisor/phase_copy.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Gold=dofile('Brainstorm/Advisor/gold_stickers.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks,failures=0,0
local function check(v,label) checks=checks+1;if not v then failures=failures+1;print('FAIL: '..label) end end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b,label) check(type(a)=='number' and math.abs(a-b)<0.000001,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function joker(id,key,name) return {id=id,key=key,blueprint_compat=true,ability={name=name,set='Joker'},sell_cost=4} end
local function tarot(key) return {key=key,ability={name=key,set='Tarot'},edition={negative=true}} end
local function state()
 local s={phase='shop',teacher_profile='perkeo_yorick_win_v1',ante=3,win_ante=8,dollars=20,
  jokers={joker('y','j_yorick','Yorick'),joker('b','j_brainstorm','Brainstorm'),joker('p','j_perkeo','Perkeo')},
  consumeables={tarot('c_death')},hand={},deck={},playing_cards={},hands={},blind={chips=1000},
  next_blind={chips=2000},shop_jokers={},shop_vouchers={},shop_booster={},modifiers={},current_round={},
  consumable_limit=2,consumeable_buffer=0,joker_limit=5,hand_size=8}
 s.jokers[1].ability.x_mult=4
 for i=1,32 do s.playing_cards[i]={id='card'..i,rank=i%13+2,nominal=5,suit='Clubs',enhancement='c_base',ability={}} end
 return s
end
local modules={phase_copy=Phase,strategy=Strategy,gold_stickers=Gold}
local leave={kind='strategy',action={kind='leave_shop'},strategy={action={kind='leave_shop'}},evaluations=50000}
local function mixed(s)
 s.consumeables={}
 for _,key in ipairs({'c_death','c_strength','c_hanged_man','c_empress','c_heirophant','c_chariot','c_justice','c_devil','c_temperance'}) do
  s.consumeables[#s.consumeables+1]=tarot(key)
 end
end
math.random=function()error('RNG forbidden')end
pseudorandom=function()error('game RNG forbidden')end

do
 local s=state();mixed(s)
 local before=Snapshot.fingerprint(s)
 local _,old=Strategy.inventory_value(s,nil,{events=2})
 check(old.approximate,'ordinary large mixed-stock estimate remains explicitly approximate')
 local result=Phase.apply(s,modules,leave)
 check(result.action.kind=='reorder_jokers','nine distinct useful held keys do not suppress the immediate Perkeo setup')
 if result.action.kind=='reorder_jokers' then
  local changed=Phase.reorder(s,result.action.order)
  eq(Phase.copy_effects(changed,'j_perkeo'),2,'published row physically adds one Perkeo copy')
  eq(Phase.apply(changed,modules,leave).action.kind,'leave_shop','fresh arranged row leaves without a reorder bounce')
 end
 eq(result.evaluations,50000,'shop setup does not enlarge exhausted score allowance')
 eq(Snapshot.fingerprint(s),before,'input cash, physical row and whole inventory remain intact')
end

do
 local s=state()
 s.jokers={s.jokers[1],s.jokers[3],joker('b1','j_blueprint','Blueprint'),joker('b2','j_blueprint','Blueprint'),
  joker('r1','j_brainstorm','Brainstorm'),joker('r2','j_brainstorm','Brainstorm')}
 local result=Phase.apply(s,modules,leave)
 check(result.action.kind=='reorder_jokers','five immediate Perkeo effects are not rejected by the four-event strategic horizon')
 if result.action.kind=='reorder_jokers' then eq(Phase.copy_effects(Phase.reorder(s,result.action.order),'j_perkeo'),5,'all four copy Jokers resolve to Perkeo') end
end

-- Exact separable expectation: two groups start at one each. After two urn
-- draws, 0/1/2 additions to either group have equal probability. One held Death
-- has unbounded useful stock and one Chariot can enhance the sole base card.
do
 local s=state();s.consumeables={tarot('c_death'),tarot('c_chariot')};s.playing_cards={s.playing_cards[1]}
 local profile=Strategy.build_profile(s);profile.horizon=2
 local direct=Strategy.inventory_value(s,nil,{events=0,profile=profile})
 local deathOnly=Snapshot.copy(s);deathOnly.consumeables={tarot('c_death')}
 local deathUtility=Strategy.inventory_value(deathOnly,nil,{events=0,profile=profile})
 local value,info=Strategy.inventory_value(s,nil,{events=2,profile=profile,immediate_exit=true})
 near(value,direct+deathUtility,'saturated Chariot contributes no new utility; Death expected gain is exactly one copy')
 check(not info.approximate,'immediate urn value is exact, not a mean-stock substitution')
end
-- Independent exhaustive draws: evaluate only terminal stock utility with zero
-- future draws. The new DP must agree without sharing its marginal recurrence.
local function exhaustive(s,profile,events)
 local function visit(pool,left)
  if left==0 then return Strategy.inventory_value(s,pool,{events=0,profile=profile}) end
  local value=0
  for _,c in ipairs(pool) do
   local more={};for i,x in ipairs(pool) do more[i]=x end;more[#more+1]=c
   value=value+visit(more,left-1)/#pool
  end
  return value
 end
 return visit(s.consumeables,events)
end
do
 local s=state();s.consumeables={tarot('c_death'),tarot('c_chariot')}
 s.playing_cards={s.playing_cards[1],s.playing_cards[2],s.playing_cards[3]}
 local profile=Strategy.build_profile(s);profile.horizon=2
 for events=0,4 do
  near(Strategy.inventory_value(s,nil,{events=events,profile=profile,immediate_exit=true}),
   exhaustive(s,profile,events),'exact mixed-stock expectation agrees with exhaustive draws, events '..events)
  near(Strategy.inventory_value(s,nil,{events=events,profile=profile,immediate_exit=true}),
   Strategy.inventory_value(s,nil,{events=events,profile=profile}),'small-family old and immediate estimates agree, events '..events)
 end
 local planet={key='c_jupiter',ability={name='Jupiter',set='Planet',consumeable={hand_type='Flush'}}}
 s.consumeables={planet,tarot('c_chariot')};s.used_vouchers={v_observatory=true};profile.hand='Flush'
 for events=1,4 do near(Strategy.inventory_value(s,nil,{events=events,profile=profile,immediate_exit=true}),
  exhaustive(s,profile,events),'matching-Planet marginal preserves nonlinear Observatory utility '..events) end
 s.consumeables={planet,planet,planet,planet,planet,planet,planet,planet,tarot('c_chariot')}
 near(Strategy.inventory_value(s,nil,{events=2,profile=profile,immediate_exit=true}),exhaustive(s,profile,2),
  'Observatory strategic cap crossed mid-exit agrees with exhaustive outcomes')
 s.consumeables={};eq(Strategy.inventory_value(s,nil,{events=8,profile=profile,immediate_exit=true}),0,'empty pools invent no stock')
end
do
 local s=state();local profile=Strategy.build_profile(s)
 local unit=Strategy.inventory_value(s,nil,{events=0,profile=profile})
 for events=5,8 do
  near(Strategy.inventory_value(s,nil,{events=events,profile=profile,immediate_exit=true}),(events+1)*unit,
   'homogeneous useful stock handles '..events..' immediate events')
 end
 local _,ordinary=Strategy.inventory_value(s,nil,{events=8,profile=profile})
 eq(ordinary.events,4,'default strategic event bound remains four')
 local _,immediate=Strategy.inventory_value(s,nil,{events=100,profile=profile,immediate_exit=true})
 eq(immediate.events,8,'immediate valuation is bounded to eight events')
 mixed(s);s.teacher_profile=nil;profile=Strategy.build_profile(s)
 local direct=Strategy.inventory_value(s,nil,{events=0,profile=profile})
 near(Strategy.inventory_value(s,nil,{events=8,profile=profile,immediate_exit=true}),direct*(1+8/#s.consumeables),
  'nine uncapped types have the exact additive Polya mean')
end
do
 local s=state();mixed(s);s.ante=8;s.next_blind.boss=true
 check(Phase.apply(s,modules,leave).action.kind=='reorder_jokers','final pre-boss immediate mixed-stock copies still count')
 s=state();s.consumeables={tarot('c_chariot')};s.playing_cards={s.playing_cards[1]}
 local r=Phase.apply(s,modules,leave)
 eq(r.action.kind,'reorder_jokers','win-first exact utility tie prefers extra free options despite strategic stock saturation')
 check(r.phase_copy_diagnostics.inventory_value_tie,'saturated utility is explicitly distinguished from a positive gain')
 s.teacher_profile=nil
 -- Generic stock caps differ; use an explicitly saturated Observatory-only
 -- valuation to check that the new tie preference is teacher-scoped.
 local zero={gold_stickers=Gold,strategy={build_profile=Strategy.build_profile,
  inventory_value=function(_,_,o)return 10,{events=o.events,valuation='exact_immediate_urn',approximate=false}end}}
 eq(Phase.apply(s,zero,leave).action.kind,'leave_shop','generic profile retains its strict positive-gain admission')
 s.teacher_profile='perkeo_yorick_win_v1'
 zero.strategy.inventory_value=function(_,_,o)return 10-o.events,{events=o.events,valuation='exact_immediate_urn',approximate=false}end
 eq(Phase.apply(s,zero,leave).action.kind,'leave_shop','teacher tie-break cannot waive a lower qualified inventory value')
 for _,blocked in ipairs({'empty','pinned','hidden','unknown','moving','debuff'}) do
  s=state();mixed(s)
  if blocked=='empty' then s.consumeables={}
  elseif blocked=='pinned' then for _,j in ipairs(s.jokers) do j.pinned=true end
  elseif blocked=='hidden' then s.jokers[1].face_down=true
  elseif blocked=='unknown' then s.jokers[1].key='j_custom'
  elseif blocked=='moving' then s.ordering_safe=false
  else s.jokers[3].debuff=true end
  eq(Phase.apply(s,modules,leave).action.kind,'leave_shop','existing '..blocked..' boundary remains')
 end
 s=state();mixed(s)
 local buy={kind='strategy',action={kind='buy',area='shop_jokers',index=1}}
 eq(Phase.apply(s,modules,buy).action,buy.action,'active purchase is preserved')
 local unqualified={strategy={inventory_value=function()return 5,{approximate=true}end,build_profile=Strategy.build_profile},gold_stickers=Gold}
 eq(Phase.apply(s,unqualified,leave).action.kind,'leave_shop','unqualified valuation cannot manufacture a setup proof')
end
-- Full production decision arbitration with ordinary empty-shop strategy.
do
 local s=state();s.dollars=0;s.reroll_cost=5
 local before=Snapshot.fingerprint(s)
 local result=Decision.run(s,modules)
 check(result.action and result.action.kind=='reorder_jokers','real teacher shop decision selects Perkeo before exit')
 if result.action and result.action.kind=='reorder_jokers' then
  local next_state=Phase.reorder(s,result.action.order)
  local fresh=Decision.run(next_state,modules)
  eq(fresh.action.kind,'leave_shop','fresh real teacher strategy leaves after separate physical reorder')
  eq(fresh.evaluations,0,'fresh exit uses no score calls')
 end
 eq(Snapshot.fingerprint(s),before,'real decision preserves source inventory and cash')
 local retained={suggest=function(_,_,base)return {action=base.action,gold_retention={}},0,{complete=true}end}
 local scoped={phase_copy=Phase,strategy=Strategy,gold_stickers=Gold,gold_retention=retained}
 eq(Decision.run(s,scoped).action.kind,'leave_shop','existing certified fixed-row retention boundary remains authoritative')
end
-- Independently invented tie case, distinct from the archived run: a played
-- Flush plan holding Pair and Straight Planets, with both copy Joker kinds.
for _,key in ipairs({'j_blueprint','j_brainstorm'}) do
 local s=state();s.hands.Flush={played=17,level=5,chips=95,mult=12}
 s.consumeables={{key='c_mercury',ability={name='Mercury',set='Planet'}},
  {key='c_saturn',ability={name='Saturn',set='Planet'},edition={negative=true}}}
 s.jokers[2]=joker('copy',key,key=='j_blueprint' and 'Blueprint' or 'Brainstorm')
 -- Place Blueprint at the right edge so neither copy initially targets Perkeo.
 if key=='j_blueprint' then s.jokers[2],s.jokers[3]=s.jokers[3],s.jokers[2] end
 local value,info=Strategy.inventory_value(s,nil,{events=1,immediate_exit=true})
 local profile=Strategy.build_profile(s)
 eq(profile.hand,'Flush','invented plan is established independently')
 local r=Phase.apply(s,modules,leave)
 check(r.action.kind=='reorder_jokers' and r.phase_copy.inventory_value_tie,'off-plan Planet saturation cannot veto free '..key..' copies')
 if r.action.kind=='reorder_jokers' then
  local ready=Phase.reorder(s,r.action.order)
  eq(Phase.copy_effects(ready,'j_perkeo'),2,'physical tie-break row has both copy effects')
  near(Strategy.inventory_value(ready,nil,{events=2,immediate_exit=true}),value,'bounded stock utility genuinely ties')
  eq(Phase.apply(ready,modules,leave).action.kind,'leave_shop','tied setup exits after one reorder')
 end
end
do
 local Journal=dofile('Brainstorm/Advisor/player_journal.lua')
 local s=state();mixed(s);local r=Phase.apply(s,modules,leave)
 local receipt=Journal.compact_phase_copy_review(r)
 check(receipt.selected and receipt.valuation=='exact_immediate_urn' and receipt.events_after==2,'selected public receipt names exact immediate utility and event gain')
 check(not receipt.profile and not receipt.inventory and Journal.encode(receipt),'receipt contains bounded public scalars only')
 r.action={kind='leave_shop'}
 check(not Journal.compact_phase_copy_review(r).selected,'superseded action is not falsely marked selected')
 local bad={phase_copy_diagnostics={scope='shop_perkeo',reason=string.rep('x',257),events_before=0/0,inventory={secret=true}}}
 receipt=Journal.compact_phase_copy_review(bad)
 check(not receipt.reason and not receipt.events_before and not receipt.inventory,'long, nonfinite and nested fields are excluded')
 eq(Journal.compact_phase_copy_review(setmetatable({},{})),nil,'metatable-bearing result is not traversed')
end
print('advisor_perkeo_exit414: '..checks..' checks, '..failures..' failures')
assert(failures==0,'Perkeo exit regressions failed')

-- Manufactured public compositions only; no captured states or game execution.
local Search=dofile(PURPLE_SEARCH_PATH or 'Brainstorm/Advisor/search.lua')
local Before=PURPLE_BEFORE_PATH and dofile(PURPLE_BEFORE_PATH)
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Snap=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function eq(a,b,m) check(a==b,(m or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function card(id,r,suit)
 return {id=id,rank=r,nominal=r==14 and 11 or math.min(r,10),suit=suit or 'Spades',ability={},enhancement='c_base'}
end
local function state()
 local s={phase='hand',ante=1,hand={card('ace',14),card('king',13,'Hearts'),card('purple',2,'Clubs')},
  deck={},hand_size=3,hand_limit=5,hands_left=4,hands_played=0,discards_left=3,discards_used=0,
  current_round={hands_left=4,hands_played=0,discards_left=3,discards_used=0},probabilities={normal=1},
  modifiers={},hands={},jokers={{id='banner',key='j_banner',name='Banner',ability={name='Banner',extra=30}}},
  blind={key='bl_small',chips=800},chips=0,dollars=20,consumeables={},consumeable_buffer=0,consumable_limit=2}
 s.hand[3].seal='Purple'
 for i=1,12 do s.deck[i]=card('draw'..i,13,i%2==0 and 'Spades' or 'Hearts') end
 s.playing_cards={};for _,area in ipairs({s.hand,s.deck})do for _,c in ipairs(area)do s.playing_cards[#s.playing_cards+1]=c end end
 return s
end
local options={samples=24,candidates=16,resource_samples=8,max_evaluations=140000}
local s=state();local original=Snap.fingerprint(s)
local legacy=Before and Before.run(s,Score,options)
local r=Search.run(s,Score,options)
if legacy then
 check(legacy.search_diagnostics.continuation_skipped,'old global Purple guard reproduces')
 eq(legacy.kind,'discard','one-draw incumbent spends Banner resource')
end
check(not r.search_diagnostics.continuation_skipped,'retained Purple no longer globally blocks exact continuation')
check(r.resource_comparison,'all admitted common-world branches finish')
eq(r.resource_comparison.future_discards,false,'no later Purple discard is assumed')
eq(r.resource_comparison.samples,8,'eight complete common worlds')
eq(Snap.fingerprint(s),original,'public input remains unchanged')
check(r.evaluations<=options.max_evaluations,'unchanged shared hard score cap')
eq(r.kind,'play','complete continuation preserves current-blind survival')
eq(r.resource_comparison.play.probability,1,'every manufactured play-first world clears')
eq(r.resource_comparison.prior_discard.probability,0,'every manufactured discard-first world fails')
for _,alt in ipairs(r.discard_alternatives or {})do
 for _,index in ipairs(alt.indices)do check(index~=3,'unsupported selected Purple never enters committed discard evidence')end
end
check(r.search_diagnostics.discard_transition_warnings and #r.search_diagnostics.discard_transition_warnings>0,'unsupported selected generation remains explicit')
local repeat_result=Search.run(s,Score,options)
eq(Snap.fingerprint(r),Snap.fingerprint(repeat_result),'private sampling and final decision deterministic')

local approximate={score=Score.score,after_play=Score.after_play,classify=Score.classify}
local a=Search.run(s,approximate,options)
check(a.search_diagnostics.continuation_skipped and not a.resource_comparison,'legacy approximate discard still cannot claim Purple continuation')

local forced=state();forced.hand[3].ability.forced_selection=true
local f=Search.run(forced,Score,options)
check(not f.discard and not f.resource_comparison,'forced unsupported Purple cannot supply an alternative')
check(f.search_diagnostics.discard_transition_warnings and #f.search_diagnostics.discard_transition_warnings>0,'forced rejection is explained')

local full=state();full.consumeables={{id='planet1',key='c_mercury'},{id='planet2',key='c_jupiter'}}
local inventory=Snap.fingerprint(full.consumeables)
local t,effects=Score.after_discard(full,{3})
check(t and #effects.generated_consumables==0,'full ordinary inventory makes no Tarot generation')
eq(#t.consumeables,2,'whole full inventory preserved exactly')
eq(Snap.fingerprint(t.consumeables),inventory,'existing inventory identities and metadata preserved')
local all=Search.run(full,Score,options)
check(all.resource_comparison and not all.search_diagnostics.continuation_skipped,'exact full-slot suppression can support selected Purple branch')

local negative=state();negative.consumable_limit=3
negative.consumeables={{id='negative',key='c_death',edition={negative=true}},{id='ordinary',key='c_mercury'}}
local before_negative=Snap.fingerprint(negative)
check(not Score.after_discard(negative,{3}),'Negative extra capacity must not be mistaken for full inventory')
local n=Search.run(negative,Score,options)
check(n.resource_comparison,'holding Negative inventory does not block supported retained-Purple comparisons')
for _,alt in ipairs(n.discard_alternatives or {})do
 for _,index in ipairs(alt.indices)do check(index~=3,'free extra slot still rejects selected Purple generation')end
end
eq(Snap.fingerprint(negative),before_negative,'Negative inventory/limit remains unchanged')

local occupied=state();occupied.consumeable_buffer=2
local buffered,generated=Score.after_discard(occupied,{3})
check(buffered and #generated.generated_consumables==0,'reserved buffer suppresses generation by the exact transition')
eq(buffered.consumeable_buffer,2,'buffer reservation is retained')

local unsupported={score=Score.score,classify=Score.classify,after_discard=Score.after_discard,
 after_play=function(st,indices)
  if (st.hands_played or 0)>0 then return nil,'Manufactured later effect is unsupported.' end
  return Score.after_play(st,indices)
 end}
local u=Search.run(state(),unsupported,options)
check(not u.resource_comparison,'one unsupported later branch invalidates the whole comparison')
check(u.search_diagnostics.continuation_skipped=='Manufactured later effect is unsupported.','unsupported-family reason stays explicit')

local limited=Search.run(state(),Score,{samples=4,candidates=16,resource_samples=8,max_evaluations=100})
check(limited.evaluations<=100,'small cap is not raised for new comparison')
check(not limited.resource_comparison,'insufficient budget cannot promote a partial family')

local old_random,old_randomseed=math.random,math.randomseed
math.random=function()error('Touched game RNG')end;math.randomseed=function()error('Reseeded game RNG')end
local private=Search.run(state(),Score,options)
math.random,math.randomseed=old_random,old_randomseed
eq(Snap.fingerprint(r),Snap.fingerprint(private),'no global RNG access')
print('advisor_purple_continuation: '..checks..' checks passed')

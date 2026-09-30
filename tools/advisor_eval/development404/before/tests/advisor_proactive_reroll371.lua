-- Independent source-catalog shop; no captured seed, state or RNG use.
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Reroll=dofile('Brainstorm/Advisor/paid_reroll.lua')
local Catalog=dofile('Brainstorm/Advisor/catalog_joker.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Score=dofile('Brainstorm/Advisor/scoring.lua')
local Finish=dofile('Brainstorm/Advisor/blind_finishing.lua')
local Liquidity=dofile('Brainstorm/Advisor/liquidity.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Decision=dofile('Brainstorm/Advisor/decision.lua')
local Journal=dofile('Brainstorm/Advisor/player_journal.lua')
for _,module in ipairs({'search','draws','sampled_outcomes','multi_discard','finish_rewards'}) do
  Finish[module]=dofile('Brainstorm/Advisor/'..module..'.lua')
end
Finish.strategy=Strategy;Shop.blind_finishing=Finish;Shop.strategy=Strategy;Shop.liquidity=Liquidity
Liquidity.snapshot=Snapshot;Strategy.liquidity=Liquidity
Reroll.catalog=Catalog;Reroll.liquidity=Liquidity;Strategy.paid_reroll=Reroll
local checks=0
local function check(v,why) checks=checks+1;assert(v,why) end
local function joker(key,name,a,sell)
  a=a or {};a.set='Joker';a.name=name
  return {id='manufactured:'..key,key=key,ability=a,blueprint_compat=true,sell_cost=sell or 2,cost=0}
end
local function entry(key,name,cost,rarity,config)
  return {key=key,name=name,cost=cost,rarity=rarity,source_set='Joker',source_config=config,
    source_effect='',source_order=10,blueprint_compat=true}
end
local function state()
  local s={phase='shop',ante=2,win_ante=8,teacher_profile='perkeo_yorick_win_v1',dollars=60,bankrupt_at=0,
    joker_limit=5,consumable_limit=2,jokers={
      joker('j_yorick','Yorick',{x_mult=2,extra={discards=23,xmult=1},yorick_discards=15}),
      joker('j_perkeo','Perkeo',{})},
    consumeables={},hand={},deck={},playing_cards={},hands={Flush={level=2,played=4,chips=50,mult=6}},
    shop_jokers={},shop_vouchers={},shop_booster={},hand_size=8,hand_limit=5,
    round_resets={hands=3,discards=3},current_round={reroll_cost_increase=0},modifiers={},
    probabilities={normal=1},blind={key='bl_small',name='Small Blind'},
    next_blind={key='bl_small',name='Small Blind',chips=100},next_blind_chips=100,
    interest_cap=25,reroll_cost=5,shop_forecast={slots=2,inflation=0,discount_percent=0,
      edition_rate=1,rental_rate=3,used={},rates={joker=20,tarot=0,planet=0,playing=0,spectral=0},
      pools={
        {entry('j_droll','Droll Joker',5,1,{t_mult=10,type='Flush'})},
        {entry('j_blackboard','Blackboard',6,2,{Xmult=3})},
        {entry('j_blueprint','Blueprint',10,3,{})}}}}
  for i=1,16 do s.playing_cards[i]={id='manufactured:card:'..i,rank=(i-1)%13+2,
    nominal=math.min(10,(i-1)%13+2),suit='Hearts',ability={}} end
  return s
end
local modules={strategy=Strategy,scoring=Score,shop_scoring=Shop}
local function run(s,limit)
  return Decision.run(s,modules,nil,{shop_scoring={max_evaluations=limit or 50000}})
end
local random,seed=math.random,math.randomseed
math.random=function() error('proactive reroll used game RNG') end
math.randomseed=function() error('proactive reroll reseeded game RNG') end
local s=state();local original=Snapshot.fingerprint(s)
local result=run(s)
check(result.action.kind=='reroll' and result.strategy.reroll_forecast.mode=='durable_engine_development',
  'safe current blind can invest surplus cash in a supported future Joker option')
local reroll_receipt=Journal.compact_reroll_review(result)
check(reroll_receipt and reroll_receipt.status=='admitted' and
  reroll_receipt.expected_development_utility>0 and
  reroll_receipt.credited_first_slot_mass>0,
  'public scalar receipt distinguishes an admitted engine investment')
local private=Snapshot.copy(result)
private.shop_diagnostics.reroll_development.hidden_worlds={secret='must not serialize'}
local redacted=Journal.compact_reroll_review(private)
check(redacted.hidden_worlds==nil and redacted.status=='admitted',
  'public reroll receipt excludes arbitrary private comparison data')
check(result.evaluations<=50000 and result.strategy.reroll_forecast.complete and
  result.strategy.reroll_forecast.credited_slots==1,'whole option fits the old shop cap and credits only first slot')
check(Snapshot.fingerprint(s)==original and Snapshot.fingerprint(result)==Snapshot.fingerprint(run(s)),
  'the new option is deterministic and leaves public state unchanged')
local full=Snapshot.copy(s)
full.jokers[#full.jokers+1]=joker('j_credit_card','Credit Card',{},1)
full.jokers[#full.jokers+1]=joker('j_egg','Egg',{extra=3},1)
full.jokers[#full.jokers+1]=joker('j_mr_bones','Mr. Bones',{},1)
local full_result=run(full)
check(full_result.action.kind=='reroll' and full_result.strategy.reroll_forecast.complete and
  full_result.strategy.reroll_forecast.comparison_count<=12,
  'a full row can value a complete supported replacement family inside the fixed cap')
for _,candidate in ipairs(full_result.strategy.reroll_forecast.shortlist) do
  if candidate.status=='complete' then check(candidate.sold_index>=3,
    'proactive full-row investments preserve Yorick and Perkeo') end
end
local synthetic_context=Shop.new(s,Score,nil,{max_evaluations=50000})
local synthetic_baseline=synthetic_context:compare(s,s)
local rank_droll=function(e) return e.key=='j_droll' and 76 or false end
local function miss(cash_after)
  local paired=Snapshot.copy(synthetic_baseline)
  paired.cash_after=cash_after;paired.development_utility=0;paired.refresh_penalty=1
  return paired
end
local hit=function() return {evidence=synthetic_baseline,merit=100,cash_after=40} end
check(not Reroll.development_suggest(s,rank_droll,synthetic_baseline,
  {compare_miss=function() return miss(nil) end,compare=hit}),
  'a miss without an attested paid refresh cannot earn future opportunity')
check(not Reroll.development_suggest(s,rank_droll,synthetic_baseline,
  {compare_miss=function() return miss(55) end,
   compare=function() return {evidence=synthetic_baseline,merit=100,cash_after=0} end}),
  'an attractive hit that breaks the stated purchase reserve earns no credit')
local credit=Snapshot.copy(s);credit.dollars=5;credit.bankrupt_at=-20
credit.jokers[#credit.jokers+1]=joker('j_credit_card','Credit Card',{},1)
local credit_context=Shop.new(credit,Score,nil,{max_evaluations=50000})
local credit_baseline=credit_context:compare(credit,credit)
check(credit_baseline and credit_baseline.before_readiness.status=='sampled_safe',
  'the low-cash Credit Card contrast has a supported safe blind')
check(not Reroll.development_suggest(credit,function() error('debt funded a speculative refresh') end,
  credit_baseline,{compare_miss=function() error('debt funded a miss') end,compare=hit}),
  'Credit Card borrowing cannot fund optional future-engine rerolls')
local floor_case=Snapshot.copy(full);floor_case.dollars=38
floor_case.jokers[4].sell_cost=3
floor_case.shop_forecast.pools[1][1].cost=10
local floor_result=run(floor_case)
check(floor_result.action.kind=='reroll' and floor_result.strategy.reroll_forecast.complete and
  floor_result.strategy.reroll_forecast.shortlist[2].sold_index==4 and
  floor_result.strategy.reroll_forecast.shortlist[2].cash_after==26,
  'an interest-safe full-row victim remains eligible beside a $24 sale endpoint')
local mixed=Snapshot.copy(s)
mixed.shop_forecast.pools[1][2]=entry('j_unknown','Unknown Joker',5,1,{})
mixed.modifiers.enable_perishables_in_shop=true
local mixed_context=Shop.new(mixed,Score,nil,{max_evaluations=50000})
local mixed_baseline=mixed_context:compare(mixed,mixed)
local function synthetic_miss(e,utility)
  local out=Snapshot.copy(e);out.cash_after=55;out.development_utility=utility
  out.refresh_penalty=1;return out
end
local mixed_options={compare_miss=function() return synthetic_miss(mixed_baseline,0) end,
  compare=function() return {evidence=mixed_baseline,merit=100,cash_after=40} end}
local mixed_result=Reroll.development_suggest(mixed,rank_droll,mixed_baseline,mixed_options)
check(mixed_result and math.abs(mixed_result.reroll_forecast.credited_first_slot_mass-0.2352)<0.000001,
  'unknown common centers, edition and sticker mass dilute the first-slot credit')
check(not Reroll.development_suggest(mixed,rank_droll,mixed_baseline,
  {compare_miss=mixed_options.compare_miss,
   compare=function() return {evidence=synthetic_baseline,merit=100,cash_after=40} end}),
  'a complete-looking hit from another common-world family receives no credit')
check(not Reroll.development_suggest(mixed,rank_droll,mixed_baseline,
  {compare_miss=function() return synthetic_miss(mixed_baseline,-50) end,
   compare=mixed_options.compare}),
  'cash-sensitive loss on a miss can overturn an attractive supported hit')
local bull=Snapshot.copy(s);bull.jokers[#bull.jokers+1]=joker('j_bull','Bull',{extra=2})
local bull_context=Shop.new(bull,Score,nil,{max_evaluations=50000})
Strategy.shortfall_reroll(bull,{action={kind='leave_shop'}},bull_context)
local bull_miss=bull_context.reroll_development_diagnostics
check(bull_miss and bull_miss.cash_after==55 and bull_miss.utility<0,
  'an actual Bull row loses build value when the refresh spends cash')
local no_cash=Snapshot.copy(s);no_cash.dollars=34
local no_cash_result=run(no_cash)
check(no_cash_result.action.kind~='reroll','interest and real purchase reserve block speculative refresh')
check((Journal.compact_reroll_review(no_cash_result) or {}).status=='cash_floor',
  'cash rejection is distinguishable from an unattempted refresh')
local mature=Snapshot.copy(s);mature.jokers[#mature.jokers+1]=joker('j_blueprint','Blueprint',{})
local mature_result=run(mature)
check(mature_result.action.kind~='reroll','an already-owned durable copy ends this acquisition mode')
check((Journal.compact_reroll_review(mature_result) or {}).status=='copy_already_owned',
  'already-owned copy is explicit in the public admission receipt')
local late=Snapshot.copy(s);late.ante=7
local late_result=run(late)
check(late_result.action.kind=='reroll' and
  late_result.strategy.reroll_forecast.mode=='surplus_catalog_opportunity',
  'late win-first cash may buy a source-supported offer despite the short development horizon')
local surplus=Snapshot.copy(full);surplus.ante=7;surplus.dollars=150
local surplus_result=run(surplus)
check(surplus_result.action.kind=='reroll' and
  surplus_result.strategy.reroll_forecast.mode=='surplus_catalog_opportunity',
  'large cash reserve can fund a source-supported late upgrade search with a full replaceable row')
local surplus_review=Journal.compact_reroll_review(surplus_result)
check(surplus_review and surplus_review.status=='admitted' and surplus_review.scoring_claim==false and
  surplus_review.credited_first_slot_mass>0,'public receipt labels surplus search as an opportunity, not a scoring claim')
check(surplus_review.surplus and surplus_review.surplus.status=='admitted' and
  surplus_review.selected_action=='reroll' and
  surplus_review.selected_mode=='surplus_catalog_opportunity' and
  surplus_review.surplus.cash_after==145 and surplus_review.surplus.required_after>=37,
  'public receipt identifies the selected route and exact late cash gate')
local masked=Journal.compact_reroll_review({action={kind='leave_shop'},shop_diagnostics={
  reroll_development={status='baseline_not_sampled_safe',hidden_worlds={secret='private'}},
  reroll_surplus={status='cost_cap',cost=21,cost_cap=20,
    source_catalog={secret='private'}}}})
check(masked and masked.development.status=='baseline_not_sampled_safe' and
  masked.surplus.status=='cost_cap' and masked.surplus.cost==21 and
  masked.selected_action=='leave_shop' and masked.surplus.source_catalog==nil and
  masked.development.hidden_worlds==nil,
  'distinct public rejection reasons survive selection without private catalog or worlds')
local unresolved=Snapshot.copy(surplus);unresolved.hand_size=9
local unresolved_result=run(unresolved)
check(unresolved_result.action.kind=='reroll' and
  unresolved_result.strategy.reroll_forecast.mode~='durable_engine_development',
  'a public nine-card hand can seek an upgrade without a fabricated all-clear blind certificate')
local scaling=Snapshot.copy(surplus);scaling.jokers[3]=joker('j_bull','Bull',{extra=2})
local scaling_result=run(scaling)
check(scaling_result.action.kind~='reroll' and
  (Journal.compact_reroll_review(scaling_result) or {}).status=='cash_scaling_row',
  'cash-scaling Joker row blocks heuristic surplus spending')
local short=Snapshot.copy(surplus);short.dollars=41
check(run(short).action.kind~='reroll','surplus route preserves interest and purchase reserves')
local exact_floor=Snapshot.copy(surplus);exact_floor.dollars=42
local exact_floor_result=run(exact_floor)
check(exact_floor_result.action.kind=='reroll' and
  (Journal.compact_reroll_review(exact_floor_result).surplus or {}).cash_after==37,
  'late paid refresh can spend exactly to the interest, survival and purchase floor')
local reserved=Snapshot.copy(surplus);reserved.dollars=71;reserved.modifiers.discard_cost=15
reserved.round_resets.discards=3;reserved.bankrupt_at=-20
check(run(reserved).action.kind~='reroll',
  'elective refresh cannot borrow debt or spend dollars reserved for paid discards and interest')
local costly=Snapshot.copy(surplus);costly.reroll_cost=20
check(run(costly).action.kind=='reroll','late supported surplus can fund one $20 refresh')
costly.reroll_cost=21
check(run(costly).action.kind~='reroll' and
  (Journal.compact_reroll_review(run(costly)).surplus or {}).status=='cost_cap',
  'late surplus still has a fixed per-refresh escalation cap')
local early_costly=Snapshot.copy(surplus);early_costly.ante=5;early_costly.reroll_cost=13
check(run(early_costly).action.kind~='reroll' and
  (Journal.compact_reroll_review(run(early_costly)).surplus or {}).status=='cost_cap',
  'early surplus retains its stricter $12 per-refresh cap')
local rare_only=Snapshot.copy(surplus)
rare_only.shop_forecast.pools[1]={};rare_only.shop_forecast.pools[2]={}
for i=1,100 do rare_only.shop_forecast.pools[3][i+1]=
  entry('j_unknown_rare_'..i,'Unknown',5,3,{}) end
local rare_review=Journal.compact_reroll_review(run(rare_only))
check(rare_review.surplus and rare_review.surplus.credited_first_slot_mass>0 and
  rare_review.surplus.credited_first_slot_mass<0.005 and
  rare_review.surplus.status=='admitted',
  'late surplus accepts a diluted but source-supported rare upgrade witness')
rare_only.dollars=57;rare_only.reroll_cost=20
local rare_floor=Journal.compact_reroll_review(run(rare_only))
check(rare_floor.surplus and rare_floor.surplus.status=='admitted' and
  rare_floor.surplus.cash_after==rare_floor.surplus.required_after and
  rare_floor.surplus.funded_endpoints>0,
  'diluted source witness at the maximum fee still preserves exact purchase capacity')
rare_only.dollars=56
check((Journal.compact_reroll_review(run(rare_only)).surplus or {}).status=='cash_floor',
  'one dollar below the late miss reserve rejects even a supported rare option')
rare_only.dollars=150;rare_only.reroll_cost=5
rare_only.ante=5
local early_rare=Journal.compact_reroll_review(run(rare_only))
check(early_rare.surplus and early_rare.surplus.status=='insufficient_supported_opportunity',
  'earlier shops retain the stronger 0.005 supported-opportunity threshold')
local charged=Snapshot.copy(surplus);charged.dollars=147;charged.reroll_cost=5
local paid,total=0,0
for _=1,20 do
  local before=Snapshot.fingerprint(charged)
  local context={}
  local proposal=Strategy.surplus_reroll(charged,{action={kind='leave_shop'}},context)
  check(Snapshot.fingerprint(charged)==before,'a charged miss proposal never mutates public input')
  if not proposal then
    check(context.reroll_surplus_diagnostics.status=='cash_floor' or
      context.reroll_surplus_diagnostics.status=='cost_cap',
      'charged misses stop at an explicit cash or cost boundary')
    break
  end
  check(proposal.action.kind=='reroll' and charged.dollars-charged.reroll_cost>=37,
    'each independent miss preserves the actual cash reserve')
  paid=paid+1;total=total+charged.reroll_cost
  charged.dollars=charged.dollars-charged.reroll_cost
  charged.reroll_cost=charged.reroll_cost+1
end
check(paid>1 and paid<20 and charged.dollars>=37 and total==147-charged.dollars,
  'successive charged misses have a finite cash-funded cumulative boundary')
local locked=Snapshot.copy(surplus);locked.modifiers.all_eternal=true
check(run(locked).action.kind~='reroll','an irreplaceable full row has no speculative replacement witness')
local empty_pool=Snapshot.copy(surplus);empty_pool.shop_forecast.pools={{},{},{}}
check(run(empty_pool).action.kind~='reroll','unsupported catalog opportunity does not authorize a paid refresh')
local unknown=Snapshot.copy(s);unknown.shop_forecast.pools={
  {entry('j_unknown','Unknown',5,1,{})},{entry('j_unknown2','Unknown2',5,2,{})},
  {entry('j_unknown3','Unknown3',5,3,{})}}
check(run(unknown).action.kind~='reroll','unsupported source outcomes receive zero opportunity credit')
local capped=run(s,500)
check((not capped.strategy.reroll_forecast or
  capped.strategy.reroll_forecast.mode~='durable_engine_development') and capped.evaluations<=500,
  'incomplete common-world work cannot select a favorable proactive prefix')
local robust=Snapshot.copy(surplus)
robust.jokers[3]=joker('j_jolly','Jolly Joker',{t_mult=8})
robust.jokers[4]=joker('j_square','Square Joker',{extra={chips=200}})
local budgeted_before=Snapshot.fingerprint(robust)
local budgeted=run(robust,500)
check(budgeted.shop_diagnostics.truncated and budgeted.action.kind=='reroll' and
  budgeted.strategy.reroll_forecast.mode=='surplus_catalog_opportunity' and budgeted.evaluations<=500,
  'actual shop-budget exhaustion retains an independent surplus reroll after whole-decision fallback: '..
  tostring(budgeted.shop_diagnostics.truncated)..'/'..tostring(budgeted.action.kind)..'/'..
  tostring(budgeted.strategy.reroll_forecast and budgeted.strategy.reroll_forecast.mode)..'/'..tostring(budgeted.evaluations)..'/'..
  tostring(budgeted.strategy.title)..'/'..tostring((Journal.compact_reroll_review(budgeted) or {}).status))
check((Journal.compact_reroll_review(budgeted) or {}).status=='admitted' and
  Snapshot.fingerprint(robust)==budgeted_before,
  'the real truncated comparison publishes the final receipt and does not mutate input')
local function after_truncated_shop(public, fallback_action)
  local bounded={strategy={surplus_reroll=Strategy.surplus_reroll,
    advise=function(_,options)
      if options and options.shop_scoring then
        local context=options.shop_scoring
        context.truncated=true
        context.reroll_development_diagnostics={status='admitted'}
        context.reroll_surplus_diagnostics={status='admitted'}
        return {action={kind='buy',area='shop_jokers',index=1},warnings={},lines={}}
      end
      return {action=fallback_action,warnings={},lines={}}
    end},
    shop_scoring={new=function() return {truncated=false,evaluations=4} end}}
  return Decision.run(public,bounded,nil,{shop_scoring={max_evaluations=50000}})
end
local recovered=after_truncated_shop(surplus,{kind='leave_shop'})
check(recovered.action.kind=='reroll' and recovered.strategy.reroll_forecast.mode=='surplus_catalog_opportunity' and
  recovered.evaluations==4 and recovered.shop_diagnostics.truncated,
  'a complete unscored surplus witness survives the whole-decision fallback without more score calls')
check((Journal.compact_reroll_review(recovered) or {}).status=='admitted',
  'the post-fallback receipt describes the selected reroll')
local preferred=after_truncated_shop(surplus,{kind='buy',area='shop_jokers',index=1})
check(preferred.action.kind=='buy' and Journal.compact_reroll_review(preferred)==nil,
  'a strategic fallback purchase is retained and an abandoned admission receipt is cleared')
local blocked=after_truncated_shop(scaling,{kind='leave_shop'})
check(blocked.action.kind=='leave_shop' and
  (Journal.compact_reroll_review(blocked) or {}).status=='cash_scaling_row',
  'the independent fallback still honors the cash-scaling exclusion')
local unsupported=after_truncated_shop(empty_pool,{kind='leave_shop'})
check(unsupported.action.kind=='leave_shop' and
  (Journal.compact_reroll_review(unsupported) or {}).status=='insufficient_supported_opportunity',
  'a truncated score comparison cannot make an unsupported catalog promising')
local collection=Snapshot.copy(surplus);collection.teacher_profile='collection_progress'
check(after_truncated_shop(collection,{kind='leave_shop'}).action.kind=='leave_shop',
  'post-fallback surplus spending is confined to the win-first teacher')
math.random,math.randomseed=random,seed
print('advisor_proactive_reroll371: '..checks..' checks passed')

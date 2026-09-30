local Route=dofile('Brainstorm/Advisor/blind_routing.lua')
local Scoring=dofile('Brainstorm/Advisor/scoring.lua')
local Shop=dofile('Brainstorm/Advisor/shop_scoring.lua')
local Strategy=dofile('Brainstorm/Advisor/strategy.lua')
local Rewards=dofile('Brainstorm/Advisor/finish_rewards.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local modules={scoring=Scoring,shop_scoring=Shop,strategy=Strategy,finish_rewards=Rewards}
local checks=0
local function check(v,l) checks=checks+1;assert(v,l) end
local function eq(a,b,l) check(a==b,l..': '..tostring(a)..' ~= '..tostring(b)) end
local function joker(k,n,a) a=a or {};a.name=n;a.set='Joker';return {key=k,name=n,ability=a} end
local function state(label)
  local s={phase='blind',blind_on_deck=label or 'Big',blind_states={Small='Defeated',Big='Select',Boss='Upcoming'},
    route_blinds={Small={key='bl_small',name='Small Blind',chips=300,dollars=3},
      Big={key='bl_big',name='Big Blind',chips=500,dollars=4},Boss={key='bl_wall',name='The Wall',chips=1000,dollars=5,boss=true}},
    route_tags={Big={key='tag_economy',name='Economy Tag',config={max=40}},Small={key='tag_investment',name='Investment Tag',config={dollars=25}}},
    dollars=30,ante=6,hand_size=8,hand_limit=5,round_resets={hands=4,discards=3},round_bonus={},modifiers={},
    hand={},deck={},playing_cards={},jokers={joker('j_joker','Joker',{mult=100}),joker('j_caino','Caino',{caino_xmult=20,extra=1})},
    consumeables={},consumable_limit=2,active_tags={},hands={},probabilities={normal=1},skips=2}
  for i=1,32 do s.playing_cards[i]={id=tostring(i),rank=2+i%13,suit='Spades',enhancement='c_base',ability={}} end
  if label=='Small' then s.blind_states.Small='Select';s.blind_states.Big='Upcoming' end
  return s
end
local s=state();local out,diag=Route.suggest(s,modules)
local Decision=dofile('Brainstorm/Advisor/decision.lua')
modules.blind_routing=Route
local original_strategy=modules.strategy
modules.strategy=setmetatable({advise=function() return {action={kind='select_blind'}} end},{__index=Strategy})
local decision=Decision.run(s,modules)
check(decision.action.kind=='skip_blind' and decision.evaluations>0,'whole decision publishes executable route and counts work')
modules.strategy=setmetatable({advise=function() return {action={kind='sell',area='jokers',index=1}} end},{__index=Strategy})
check(Decision.run(s,modules).action.kind=='sell','mandatory setup remains ahead of routing')
modules.strategy=original_strategy
check(out and out.action.kind=='skip_blind','mature deck gets executable cash-tag skip')
eq(out.action.blind,'Big','actual currently selected blind')
check(diag.checked_blinds.Boss,'Big skip explicitly checks boss')
check(diag.minimum_capacity>=2,'every checked sample has required capacity margin')
check(diag.evaluations<=5000,'route stays inside hard score budget')
check(diag.foregone_income>0 and diag.shop_cost>0,'lost income and shop explicitly costed')
eq(diag.foregone_income,12,'forgone full interest included in addition to marginal clearing-hand rewards')
eq(s.dollars,30,'route does not mutate bankroll');eq(s.skips,2,'route does not perform skip')
s=state('Small');out,diag=Route.suggest(s,modules)
check(out~=nil,'small Investment skip can qualify with mature capacity and net value')
check(diag.checked_blinds.Big and diag.checked_blinds.Boss,'Small skip checks both Big and Boss')
check(diag.evaluations<=5000,'two-blind route remains bounded')
s.route_blinds.Boss.chips=1e9
eq(Route.suggest(s,modules),nil,'easy Big cannot hide impossible boss')
s=state();s.route_blinds.Boss={key='bl_final_heart',name='Crimson Heart',chips=1000,boss=true}
eq(Route.suggest(s,modules),nil,'unknown random boss start fails closed')
s.route_blinds.Boss={key='bl_house',name='The House',chips=1000,boss=true}
eq(Route.suggest(s,modules),nil,'known but concealed opening draw fails closed')
s=state();s.jokers[2].ability.caino_xmult=1;s.jokers[1].ability.mult=1
eq(Route.suggest(s,modules),nil,'weak build keeps access to played blind and shop')
s=state();s.route_tags.Big={key='tag_double'};s.ante=1
eq(Route.suggest(s,modules),nil,'early no-cash skip loses to income and shop opportunity')
s.ante=8;out,diag=Route.suggest(s,modules)
check(out~=nil,'late mature deck may skip for time even without immediate tag cash')
s=state();s.jokers[#s.jokers+1]=joker('j_perkeo','Perkeo')
s.consumeables={{key='c_mercury',ability={set='Planet',consumeable={hand_type='Pair'}}}}
_,diag=Route.suggest(s,modules);check(diag.growth_cost>0,'forgone Perkeo shop copying opportunity valued')
s=state();s.jokers[#s.jokers+1]=joker('j_egg','Egg',{extra=30})
eq(Route.suggest(s,modules),nil,'high Egg growth can reverse otherwise profitable skip')
s=state();s.jokers[#s.jokers+1]=joker('j_satellite','Satellite',{extra=10})
s.consumeable_usage={c_mercury={set='Planet'},c_pluto={set='Planet'},c_death={set='Tarot'}}
_,diag=Route.suggest(s,modules);eq(diag.foregone_income,32,'Satellite distinct Planet payout included in opportunity cost')
s=state();s.jokers[1].ability.rental=true
_,diag=Route.suggest(s,modules);eq(diag.foregone_income,9,'skipping avoids rental expense counted exactly once')
s=state();s.jokers[#s.jokers+1]=joker('j_ceremonial','Ceremonial Dagger',{mult=200})
eq(Route.suggest(s,modules),nil,'preblind irreversible setup left to existing advisor')
s=state();s.jokers[1].ability.perishable=true;s.jokers[1].ability.perish_tally=1
eq(Route.suggest(s,modules),nil,'expiring engine does not establish boss route')
s=state();s.active_tags={{key='tag_boss'}}
eq(Route.suggest(s,modules),nil,'pending boss reroll cannot use old boss samples')
s=state();out,diag=Route.suggest(s,modules,{max_evaluations=3})
eq(out,nil,'budget cannot be exceeded to complete a route');eq(diag.evaluations,3,'strict evaluation budget')
s=state('Small');s.probabilities.normal=4
for _,c in ipairs(s.playing_cards) do c.enhancement='m_glass';c.ability.extra=4 end
out,diag=Route.suggest(s,modules)
check(out~=nil and diag.glass_saved>0,'certain Glass attrition contributes to useful skip')
s.playing_cards={s.playing_cards[1],s.playing_cards[2],s.playing_cards[3],s.playing_cards[4],s.playing_cards[5],s.playing_cards[6],s.playing_cards[7],s.playing_cards[8]}
eq(Route.suggest(s,modules),nil,'intermediate destruction cannot invent a full boss hand')
s=state('Small');s.playing_cards[1].enhancement='m_glass';s.playing_cards[1].ability.extra=4
out,diag=Route.suggest(s,modules);check(out~=nil,'single random Glass outcome route remains bounded')
s=state('Small');for _,c in ipairs(s.playing_cards) do c.enhancement='m_glass';c.ability.extra=4 end
out,diag=Route.suggest(s,modules)
check(out and diag.outcome_branches==8,'every intermediate random Glass survivor and break branch is checked')
s=state();s.modifiers.debuff_played_cards=true
out,diag=Route.suggest(s,modules)
check(out and diag.population_saved>0,'permanent scoring-card depletion contributes to attrition value')
s=state();s.jokers[1].key='j_modded_unknown'
eq(Route.suggest(s,modules),nil,'known-looking ability cannot hide unknown modded Joker identity')
s=state();s.modifiers.minus_hand_size_per_X_dollar=5
eq(Route.suggest(s,modules),nil,'cash-based hand size requires exact route capacity transition')
s=state();s.route_tags.Big={key='tag_economy',config={max=40}};s.active_tags={{key='tag_double'},{key='tag_double'}}
local changed,meta=Route.project_skip(s)
eq(changed.dollars,140,'copied Economy tags compound sequentially to live caps')
eq(meta.cash,110,'copied Economy cash total');eq(meta.tag_copies,3,'two Double tags add two copies')
s.route_tags.Big={key='tag_skip',config={skip_bonus=7}};changed,meta=Route.project_skip(s)
eq(meta.cash,63,'Skip tag pays after increment with live bonus and copies')
s.route_tags.Big={key='tag_handy',config={dollars_per_hand=2}};s.hands_played_total=12
_,meta=Route.project_skip(s);eq(meta.cash,72,'Handy counts total played hands')
s.route_tags.Big={key='tag_garbage',config={dollars_per_discard=3}};s.unused_discards=9
_,meta=Route.project_skip(s);eq(meta.cash,81,'Garbage counts unused discards over run')
s.route_tags.Big={key='tag_investment',config={dollars=25}}
_,meta=Route.project_skip(s);eq(meta.cash,0,'Investment does not fund next blind');eq(meta.deferred_cash,75,'Investment pays only after boss')
s.jokers[#s.jokers+1]=joker('j_throwback','Throwback',{x_mult=99,extra=0.5})
changed,meta=Route.project_skip(s);eq(changed.jokers[3].ability.x_mult,2.5,'Throwback derives actual multiplier from new skip count')
eq(meta.throwback_growth,0.5,'physical Throwback growth does not multiply for Double tags')
s.route_tags.Big={key='tag_boss'}
eq(Route.project_skip(s),nil,'unsupported tag cannot fabricate a projected route')
s.route_tags.Big={key='tag_economy',config={type='eval'}}
eq(Route.project_skip(s),nil,'changed tag timing cannot create immediate cash')

-- Snapshot captures only plain route/tag fields; no live callback or UI tree.
local g={STAGES={RUN=1},STAGE=1,STATES={BLIND_SELECT=3},STATE=3,
  GAME={round_resets={ante=2,blind_choices={Boss='bl_wall'},blind_states={Small='Select'},blind_tags={Small='tag_skip'}},
    blind_on_deck='Small',current_round={},modifiers={no_blind_reward={Small=true}},
    tags={{key='tag_double',name='Double Tag',config={type='tag_add'},HUD_tag={giant='unneeded'}}},skips=3,unused_discards=14},
  P_BLINDS={bl_small={name='Small Blind',mult=1,dollars=3},bl_big={name='Big Blind',mult=1.5,dollars=4},bl_wall={name='The Wall',mult=4,dollars=5,boss={min=2}}},
  P_TAGS={tag_skip={name='Skip Tag',config={skip_bonus=5,type='immediate'}}}}
local snap=Snapshot.capture(g)
eq(snap.route_blinds.Small.dollars,0,'route captures challenge blind payout restriction')
eq(snap.route_blinds.Big.chips,1200,'actual Big target captured from source ante table')
eq(snap.route_blinds.Boss.chips,3200,'actual boss definition multiplier captured')
eq(snap.route_tags.Small.config.skip_bonus,5,'live tag config captured')
eq(snap.active_tags[1].HUD_tag,nil,'tag snapshot omits UI tree')
eq(snap.skips,3,'source skip counter captured');eq(snap.unused_discards,14,'source unused discard counter captured')
print('Blind routing: '..checks..' checks passed (bounded composition evidence and time heuristic; no win probability)')

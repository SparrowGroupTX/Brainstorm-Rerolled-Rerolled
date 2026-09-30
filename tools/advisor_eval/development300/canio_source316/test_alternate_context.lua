local base='tools/advisor_eval/runs/legendary313_installed/policy/Brainstorm/Advisor/'
local Context=dofile('tools/advisor_eval/development300/canio_source316/gold_objective_context.lua')
local Gold=dofile(base..'gold_stickers.lua')
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function copy(t)if type(t)~='table'then return t end;local o={};for k,v in pairs(t)do o[k]=copy(v)end;return o end
local function setup()
  local g={SETTINGS={profile=1},PROFILES={[1]={joker_usage={}}},STAGES={RUN=1},STAGE=1,
    GAME={stake=8,seeded=false,won=false,round_resets={ante=1},win_ante=8,
      filter_info={collection_search={primary_legendary_key='j_caino',minimum_distinct=1,
        missing_names='Canio',quota_mode='auto',opening_adapted=true}}},
    jokers={cards={}},P_CENTERS={},P_STAKES={},sticker_map={[8]='Gold'}}
  for _,key in ipairs(Gold.target_keys())do g.P_CENTERS[key]={key=key,set='Joker'}end
  for i=1,8 do g.P_STAKES[i==8 and'stake_gold'or'stake_'..i]={set='Stake',stake_level=i,order=i}end
  local s={schema=1,mode='synthetic_only_canio_missing_v1',enabled=true,profile='all_unlocked_discovered_v1',
    initial_history='explicit_synthetic_149_gold_rows_before_first_decision',qualification=false,actual_player_profile=false,
    missing_keys={'j_caino'},missing_population='only_j_caino',synthetic_gameplay_wins_created=false,player_achievement_credit=false,
    initial_counts={total=150,complete=149,missing=1,unknown=0},
    synthetic_history_row={count=1,order='canonical_key_order_1_based',wins={['8']=1},losses={}}}
  local events={};local raw=function()return{phase='shop',dollars=17}end
  local modules={snapshot={capture=raw,copy=copy},gold_stickers=Gold,gold_goal={suggest=function()error('No decisions in fixture')end}}
  return g,s,modules,events,function()return Context.attach(s,modules,g,function(e)events[#events+1]=e end)end
end
do
  local g,s,m,events,attach=setup();local c=attach();local goal=c.capture()
  check(goal.counts.complete==149 and goal.counts.missing==1 and goal.counts.unknown==0,'loaded product capture recognizes explicit149-row prior history')
  check(goal.by_key.j_caino.status=='missing'and g.PROFILES[1].joker_usage.j_caino==nil,'Canio remains the only missing target')
  check(goal.eligibility.eligible==true and not g.GAME.won,'history initialization does not win or end the run')
  check(events[1].synthetic_history_initialized and events[1].game_or_profile_mutated and
    events[1].history_before_initialization.counts.complete==0,'receipt discloses exact synthetic mutation and old natural empty history')
  check(m.snapshot.capture(g).dollars==17 and m.snapshot.capture(g).completionist_goal.counts.missing==1,'snapshot decorator preserves all previous fields')
  local n=0;for _,row in pairs(g.PROFILES[1].joker_usage)do n=n+1;check(row.count==1 and row.wins[8]==1,'each synthetic prior row uses source-supported counters')end
  check(n==149,'exactly149 synthetic prior rows')
  g.jokers.cards={{config={center_key='j_caino'},ability={set='Joker'}}}
  g.PROFILES[1].joker_usage.j_caino={count=1,order=150,wins={}}
  check(c.capture().counts.missing==1 and c.capture().held_target_count==1,'buying and retaining Canio is not an award')
  -- Unit fixture only: imitate a later original callback write, not gameplay.
  g.PROFILES[1].joker_usage.j_caino.wins[8]=1;g.GAME.won=true
  check(c.capture().counts.complete==150 and c.capture().eligibility.eligible==false,'later capture sees callback changes and terminal ineligibility')
  check(events[1].initial_goal.counts.complete==149,'earlier evidence remains prior history')
end
for _,mutate in ipairs({
  function(g,s)g.PROFILES[1].joker_usage.j_joker={count=1,order=1,wins={}}end,
  function(g,s)g.P_CENTERS.j_joker=nil end,
  function(g,s)g.P_STAKES=nil end,
  function(g,s)g.GAME.seeded=true end,
  function(g,s)g.GAME.filter_info.collection_search.primary_legendary_key='j_yorick'end,
  function(g,s)s.missing_keys={'j_triboulet'}end,
  function(g,s)s.initial_counts=nil end,
  function(g,s)s.synthetic_history_row.wins['8']=2 end,
  function(g,s)s.synthetic_history_row.wins['1']=1 end,
  function(g,s)s.actual_player_profile=true end,
})do
  local g,s,m,events,attach=setup();mutate(g,s)
  local before=g.PROFILES[1].joker_usage;local raw=m.snapshot.capture
  local ok,why=pcall(attach)
  check(not ok and tostring(why):find('HEADLESS_BOUNDARY',1,true),'unsupported metadata/specification rejected explicitly')
  check(g.PROFILES[1].joker_usage==before and m.snapshot.capture==raw and #events==0,'failure leaves existing profile/capture unchanged')
end
do
  local g,s,m,_,attach=setup();s.mode='synthetic_fresh_all_missing_v1';s.initial_history='natural_empty_loaded_joker_usage'
  local history=g.PROFILES[1].joker_usage;check(attach().capture().counts.missing==150,'legacy fresh mode stays allmissing')
  check(g.PROFILES[1].joker_usage==history and next(history)==nil,'legacy mode never seeds history')
end
print('alternate_context: '..checks..' checks passed')

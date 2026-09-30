local Context=dofile('tools/advisor_eval/development299/drafts/gold_source/gold_objective_context.lua')
local Gold=dofile('Brainstorm/Advisor/gold_stickers.lua')
local Goal=dofile('Brainstorm/Advisor/gold_goal.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,reason)checks=checks+1;assert(v,reason)end
local function fails(fn,reason)local ok,error=pcall(fn);check(not ok and tostring(error):find('HEADLESS_BOUNDARY',1,true),reason)end
local function setup()
  local g={SETTINGS={profile=1},PROFILES={[1]={joker_usage={}}},STAGES={RUN=1},STAGE=1,
    GAME={stake=8,seeded=false,won=false,round_resets={ante=1},win_ante=8},
    jokers={cards={}},P_CENTERS={},P_STAKES={},P_CENTER_POOLS={Stake={}},sticker_map={[8]='Gold'}}
  for _,key in ipairs(Gold.target_keys())do g.P_CENTERS[key]={key=key,set='Joker'}end
  for i=1,8 do
    local key=i==8 and 'stake_gold'or'stake_'..i
    local stake={key=key,set='Stake',stake_level=i,order=i}
    g.P_STAKES[key]=stake;g.P_CENTER_POOLS.Stake[i]=stake
  end
  local events={};local raw=function()return{phase='shop',dollars=17}end
  local modules={snapshot={capture=raw,copy=Snapshot.copy},gold_stickers=Gold,gold_goal=Goal}
  local spec={schema=1,mode='synthetic_fresh_all_missing_v1',enabled=true,profile='all_unlocked_discovered_v1',
    initial_history='natural_empty_loaded_joker_usage',qualification=false,actual_player_profile=false}
  local function attach()return Context.attach(spec,modules,g,function(e)events[#events+1]=e end)end
  return g,modules,spec,events,attach,raw
end
do
  local bomb=setmetatable({},{__index=function()error('Off mode inspected game state')end})
  check(Context.attach(nil,nil,bomb,nil)==nil,'default absent flag leaves source capture untouched')
  check(Context.attach({schema=1,mode='off',enabled=false},nil,bomb,nil)==nil,'explicit off never inspects supplied profile state')
end
do
  local g,m,spec,events,attach,raw=setup();local before=Snapshot.fingerprint(g)
  local c=attach();local observed=m.snapshot.capture(g)
  check(observed.completionist_goal.counts.missing==150 and observed.completionist_goal.counts.complete==0,'actual product capture sees all 150 naturally missing')
  check(observed.phase=='shop'and observed.dollars==17 and raw().completionist_goal==nil,'decorator preserves detached policy fields and original capture')
  check(before==Snapshot.fingerprint(g),'objective initialization and capture never mutate loaded synthetic game/profile')
  check(events[1].initial_empty_history_verified and events[1].initialized_before_decision and events[1].qualification==false,'actual context receipt separately verifies initialization')
  g.jokers.cards={{config={center_key='j_yorick'},ability={set='Joker'}}}
  g.PROFILES[1].joker_usage.j_yorick={count=1,order=1,wins={}}
  local held=c.capture();check(held.held_target_count==1 and held.counts.complete==0,'buying and holding are not sticker awards')
  g.PROFILES[1].joker_usage.j_yorick.wins[8]=1 -- Synthetic original-callback effect in this unit fixture only.
  g.GAME.won=true;g.GAME.round_resets.ante=9
  local ended=m.snapshot.capture(g).completionist_goal
  check(ended.counts.complete==1 and ended.counts.missing==149,'later capture reads the actual changed loaded counter')
  check(ended.eligibility.eligible==false and events[1].initial_goal.counts.missing==150,'terminal eligibility changes without rewriting initial evidence')
  observed.completionist_goal.targets[1].status='complete'
  check(c.capture().counts.complete==1,'mutating a detached earlier observation never changes loaded counts')
end
for _,mutation in ipairs({
  function(g)g.PROFILES[1].joker_usage=nil end,
  function(g)g.PROFILES[1].joker_usage.j_yorick={count=1,order=1,wins={}}end,
  function(g)g.P_STAKES=nil end,
  function(g)g.P_STAKES.stake_gold.stake_level=7 end,
  function(g)g.sticker_map[8]='gold'end,
  function(g)g.P_CENTERS.j_yorick=nil end,
  function(g)g.P_CENTERS.j_yorick.mod={}end,
  function(g)g.GAME.seeded=true end,
  function(g)g.GAME.challenge='c_jokerless_1'end,
  function(g)g.GAME.stake=7 end,
})do
  local g,m,_,events,attach,raw=setup();mutation(g);local before=Snapshot.fingerprint(g)
  fails(attach,'unknown, nonfresh or ineligible initialization fails explicitly')
  check(#events==0 and m.snapshot.capture==raw and before==Snapshot.fingerprint(g),'failed initialization neither repairs metadata nor enables partial context')
end
for _,mutation in ipairs({
  function(g)g.PROFILES[1]={joker_usage={}}end,
  function(g)g.SETTINGS.profile=2 end,
  function(g)g.GAME=Snapshot.copy(g.GAME)end,
  function(g)g.P_STAKES=nil end,
  function(g)g.PROFILES[1].joker_usage.j_yorick={wins={[8]=1}}end,
})do
  local g,m,_,_,attach=setup();attach();mutation(g)
  fails(function()m.snapshot.capture(g)end,'later missing metadata or replaced profile/game stops before the next decision')
end
do
  local _,m,spec,_,attach=setup();spec.mode='player_subset'
  fails(attach,'undeclared player subset cannot be inferred')
  local _,n,_,_,other=setup();n.gold_goal=nil
  fails(other,'enabled source mode requires the actual frozen Gold decision module')
end
print('test_gold_objective_context: '..checks..' checks passed')

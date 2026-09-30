-- Pure synthetic preparation only: no actual UI, native search or game action.
local Search=dofile('Brainstorm/Advisor/gold_search.lua')
local Gold=dofile('Brainstorm/Advisor/gold_stickers.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local function eq(a,b,why)check(a==b,(why or '')..': '..tostring(a)..' ~= '..tostring(b))end
local function copy(t)return Snapshot.copy(t)end
local function same(a,b,why)eq(Snapshot.fingerprint(a),Snapshot.fingerprint(b),why)end
local function goal()
  local g={schema=1,goal='gold_stickers',profile_id=1,metadata_status='complete',catalog_status='complete',stake_status='complete',
    counts={total=150,complete=0,missing=150,unknown=0},by_key={},eligibility={status='ineligible',eligible=false,reasons={'outside_run_stage'}}}
  for _,key in ipairs(Gold.target_keys())do g.by_key[key]={key=key,status='missing'}end
  return g
end
local function set(g,key,status)
  local row=g.by_key[key];g.counts[row.status]=g.counts[row.status]-1;row.status=status;g.counts[status]=g.counts[status]+1
end
local function original()
  return {pack={'prior_pack'},pack_id=3,voucher_name='v_telescope',voucher_id=8,tag_name='tag_charm',tag_id=2,soul_count=3,
    inst_observatory=true,observatory_deadline=8,inst_perkeo=true,no_perishable_jokers=true,copy_money=true,bean=true,burglar=true,retcon=true,
    custom_filter_name='Negative Perkeo',custom_filter_id=3,rank_min=8,rank_min_id=9,any_rank_min=7,any_rank_min_id=8,
    joker_targets={'Perkeo','Blueprint','Baron','Mime','Brainstorm'},joker_target_editions={'Negative'},joker_target_locations={'by_ante_8'},
    rank_name='Ace',rank_id=14,suit_name='Hearts',suit_id=4,future_metadata={keep=false,words='original',array={2,5,9}}}
end
local click={explicit_click=true,active_search=false}
local blocked={j_stone=true,j_steel_joker=true,j_glass=true,j_ticket=true,j_lucky_cat=true,j_cavendish=true}
local legendary={j_caino=true,j_triboulet=true,j_yorick=true,j_chicot=true,j_perkeo=true}
local random,randomseed=math.random,math.randomseed
math.random=function()error('Preparing filters must not sample RNG')end
math.randomseed=function()error('Preparing filters must not reseed RNG')end
do
  local g=goal();local untouched=Snapshot.fingerprint(g);local choices,info=Search.choices(g)
  eq(#choices,150,'all known missing vanilla targets appear, including six prerequisite explanations')
  eq(info.profile_id,1,'choice list identifies the captured active profile')
  eq(info.unknown_count,0,'complete absence is distinguished from unknown progress')
  for i,row in ipairs(choices)do
    check(i==1 or choices[i-1].key<row.key,'target choices are stable and sorted by source key')
    eq(row.binding.profile_id,1,'each rendered selection is explicitly profile-bound')
    eq(row.binding.target_key,row.key,'choice identity and bound key agree')
    eq(row.binding.expected_status,'missing','a choice binds only observed missing progress')
    eq(row.direct_supported,not blocked[row.key],'fresh locked predicates cannot be silently advertised as direct targets')
    eq(row.label,Search.name(row.key),'the displayed and configured native name come from the same canonical mapping')
  end
  eq(Snapshot.fingerprint(g),untouched,'listing choices does not modify goal progress')
  choices[1].binding.target_key='j_fake';check(Search.choices(g)[1].binding.target_key~='j_fake','returned binding mutations cannot affect a future capture')
  set(g,'j_joker','complete');set(g,'j_egg','unknown');choices,info=Search.choices(g)
  eq(#choices,148,'completed and unknown targets are excluded from choices')
  eq(info.unknown_count,1,'excluded unknown progress remains explicit')
  for _,row in ipairs(choices)do check(row.key~='j_joker' and row.key~='j_egg','neither complete nor unknown is imputed missing')end
  for _,key in ipairs(Gold.target_keys())do set(g,key,'complete')end
  choices=Search.choices(g);eq(#choices,0,'zero missing targets is allowed only with a complete consistent context')
  eq(Search.name('j_caino'),'Canio','native Canio spelling is explicit')
  eq(Search.name('j_seance'),'Séance','native accented Seance spelling is explicit')
  eq(Search.name('j_riff_raff'),'Riff-Raff','native Riff-Raff spelling is explicit')
  eq(Search.name('j_ring_master'),'Showman','source key does not get guessed from the display name')
  eq(Search.name('j_selzer'),'Seltzer','source typo key maps to the accepted native name')
end
do
  local g=goal();local current=original();local before=Snapshot.fingerprint(current);local source=Snapshot.fingerprint(g)
  local ordinary,souls,declined=0,0,0
  for _,key in ipairs(Gold.target_keys())do
    local selection=assert(Search.bind(g,key));local p,reason=Search.prepare(g,selection,current,nil,click)
    if blocked[key]then
      eq(p,nil,'direct unsupported prerequisite search is never configured');check(type(reason)=='string' and #reason>20,'prerequisite rejection explains why');declined=declined+1
    else
      check(p,'a supported source target produces a complete settings patch')
      eq(p.profile_id,1,'prepared patch retains its profile binding');eq(p.target_key,key,'original missing target is explicit')
      eq(p.search_key,key,'direct search never substitutes another Joker')
      eq(p.filters.joker_targets[1],Search.name(key),'native target is the canonical source-compatible name')
      eq(p.starts_search,false,'preparation never starts a search')
      eq(p.saved_previous,true,'the first explicit preparation saves a full previous filter copy')
      same(p.previous_filters,current,'the complete original filter configuration is retained')
      same(p.filters.future_metadata,current.future_metadata,'unknown unrelated filter metadata survives')
      eq(p.filters.rank_name,'Ace','inactive rank selection is preserved');eq(p.filters.suit_name,'Hearts','inactive suit selection is preserved')
      for _,field in ipairs({'inst_observatory','inst_perkeo','no_perishable_jokers','copy_money','bean','burglar','retcon'})do eq(p.filters[field],false,'unrelated required route is cleared')end
      for _,field in ipairs({'rank_min','any_rank_min','observatory_deadline'})do eq(p.filters[field],0,'additional target constraints are cleared')end
      eq(p.filters.voucher_name,'','no voucher requirement is invented');eq(#p.filters.pack,0,'no booster requirement is invented')
      eq(p.filters.custom_filter_name,'No Filter','old custom route does not leak into the new target')
      for i=2,5 do eq(p.filters.joker_targets[i],'','unrelated Joker targets are cleared')end
      for i=1,5 do eq(p.filters.joker_target_editions[i],'Any Edition','no unnecessary edition condition is introduced')end
      if legendary[key]then
        souls=souls+1;eq(p.filters.soul_count,1,'one Legendary uses one supported Soul')
        eq(p.filters.tag_name,'tag_charm','Legendary uses the existing starting Charm route');eq(p.filters.tag_id,2,'Charm selector matches existing UI ID')
        eq(p.filters.joker_target_locations[1],'soul_pack','Legendary does not enter an impossible ordinary shop route')
      else
        ordinary=ordinary+1;eq(p.filters.soul_count,0,'ordinary search does not retain a Soul requirement')
        eq(p.filters.tag_name,'','ordinary early search has no skip requirement');eq(p.filters.tag_id,1,'empty tag selector matches existing UI ID')
        eq(p.filters.joker_target_locations[1],'ante_1','ordinary route uses existing early timeline')
      end
      check(table.concat(p.instructions,' '):find('Gold%-sticker win'),'result does not equate an offer with completion')
      check(table.concat(p.instructions,' '):find('This search assumes all profile unlocks; Gold history alone does not verify them.',1,true),
        'every supported route discloses the inherited complete-profile assumption')
      check(p.assumes_complete_profile_unlocks and p.profile_unlocks_verified==false,'profile assumptions are explicitly separate from verified Gold history')
    end
    eq(Snapshot.fingerprint(current),before,'each preparation preserves the original current filters')
    eq(Snapshot.fingerprint(g),source,'each preparation preserves loaded completion data')
  end
  eq(ordinary,139,'all139 direct ordinary vanilla targets are covered');eq(souls,5,'allfive Legendary Soul routes are covered');eq(declined,6,'allsix permanently fresh-locked direct targets are declined')
end
do
  local g=goal();set(g,'j_marble','complete');local current=original()
  local direct=assert(Search.bind(g,'j_stone'));check(not Search.prepare(g,direct,current,nil,click),'direct Stone remains declined even when Marble already has Gold')
  local binding=assert(Search.bind(g,'j_stone','marble_prerequisite'))
  local p=assert(Search.prepare(g,binding,current,nil,click))
  eq(p.target_key,'j_stone','prerequisite preserves the actual missing goal identity')
  eq(p.search_key,'j_marble','explicit prerequisite prepares only Marble')
  eq(p.filters.joker_targets[1],'Marble Joker','Stone is never passed to fresh native search')
  check(p.message:find('Stone Joker is not searched or guaranteed',1,true),'prerequisite copy states the actual search limitation')
  check(table.concat(p.instructions,' '):find('find Stone Joker separately',1,true),'actual future acquisition remains a separate user task')
  check(not Search.bind(g,'j_perkeo','marble_prerequisite'),'unsupported prerequisite substitutions are rejected')
  check(not Search.bind(g,'j_fake'),'nonvanilla keys cannot enter settings')
end
do
  local g=goal();local filters=original();local before=copy(filters)
  local first=assert(Search.prepare(g,assert(Search.bind(g,'j_joker')),filters,nil,click))
  first.filters.future_metadata.words='later user edit'
  local saved=copy(first.previous_filters)
  local second=assert(Search.prepare(g,assert(Search.bind(g,'j_perkeo')),first.filters,first.previous_filters,click))
  eq(second.saved_previous,false,'repeat preparation never renews or overwrites the original filter backup')
  same(second.previous_filters,before,'shared Collection backup survives another target preset')
  local restored=assert(Search.restore(second.filters,second.previous_filters,click))
  same(restored.filters,before,'explicit restore returns every original filter field')
  eq(restored.clear_previous,true,'only successful explicit restoration consumes backup')
  eq(restored.starts_search,false,'restoring never starts a search')
  restored.filters.future_metadata.words='changed result'
  same(first.previous_filters,saved,'returned data cannot mutate a retained original backup')
  for _,opts in ipairs({{}, {explicit_click=false,active_search=false},{explicit_click=true},{explicit_click=true,active_search=true}})do
    check(not Search.prepare(g,assert(Search.bind(g,'j_joker')),filters,nil,opts),'missing click or unknown/active search blocks preparation')
    check(not Search.restore(filters,saved,opts),'missing click or unknown/active search blocks restoration')
  end
  check(not Search.restore(filters,nil,click),'missing backup is not a reset-to-default action')
end
do
  local g=goal();local selected=assert(Search.bind(g,'j_joker'));local filters=original()
  local later=copy(g);later.profile_id=2
  check(not Search.prepare(later,selected,filters,nil,click),'profile switch invalidates a rendered binding at click time')
  local current=copy(g);set(current,'j_joker','complete')
  check(not Search.prepare(current,selected,filters,nil,click),'newly completed selected Joker is not searched from stale UI')
  current=copy(g);set(current,'j_joker','unknown')
  check(not Search.prepare(current,selected,filters,nil,click),'newly unknown selected progress is not imputed missing')
  for _,change in ipairs({
    function(x)x.metadata_status='unavailable'end,function(x)x.catalog_status='incomplete'end,function(x)x.stake_status='unknown'end,
    function(x)x.counts.missing=0 end,function(x)x.counts=nil end,function(x)x.by_key=nil end,
    function(x)x.by_key.j_joker.status='made_up'end,function(x)x.by_key.j_joker=nil end,function(x)x.profile_id=false end,
    function(x)x.schema=2 end,function(x)x.goal='other'end
  })do
    current=copy(g);change(current)
    local choices,reason=Search.choices(current);eq(choices,nil,'invalid metadata is not returned as zero remaining targets')
    check(type(reason)=='string','invalid metadata explanation is explicit')
    check(not Search.prepare(current,selected,filters,nil,click),'invalid fresh metadata cannot configure filters')
  end
  local wrong=copy(selected);wrong.expected_status='complete';check(not Search.prepare(g,wrong,filters,nil,click),'binding status is validated')
  wrong=copy(selected);wrong.route=nil;check(not Search.prepare(g,wrong,filters,nil,click),'missing route is not an implicit prerequisite or direct action')
end
do
  local g=goal();local binding=assert(Search.bind(g,'j_joker'));local filters=original();local calls=0
  local function forbidden()calls=calls+1;error('No callback execution')end
  G=setmetatable({GAME={seeded=true,stake=7},SETTINGS={profile=99}},{__index=forbidden})
  Brainstorm={writeConfig=forbidden,autoReroll=forbidden,startChallengeOpeningSearch=forbidden}
  local game_before=Snapshot.fingerprint(G);local progress_before=Snapshot.fingerprint(g)
  check(Search.prepare(g,binding,filters,nil,click),'pure preparation does not depend on the global game')
  eq(calls,0,'no config/game/search/native callback is invoked')
  eq(Snapshot.fingerprint(G),game_before,'profile, stake, seeded flags and game state are not modified')
  eq(Snapshot.fingerprint(g),progress_before,'Gold flags are not changed')
  filters.future_metadata.callback=forbidden
  check(not Search.prepare(g,binding,filters,nil,click),'callback-bearing filter backups are declined without dropping existing data')
  filters=original();filters.loop=filters;check(not Search.prepare(g,binding,filters,nil,click),'cycles are declined without partial settings')
  filters=original();local p=filters;for _=1,40 do p.deep={};p=p.deep end
  check(not Search.prepare(g,binding,filters,nil,click),'copy depth is bounded without stack exhaustion')
  filters=original();filters.future_metadata.number=0/0;check(not Search.prepare(g,binding,filters,nil,click),'nonfinite metadata is not silently rewritten')
  eq(calls,0,'declining unsupported metadata never invokes its callback')
end
math.random,math.randomseed=random,randomseed
print('advisor_gold_search296: '..checks..' pure synthetic preparation checks passed')

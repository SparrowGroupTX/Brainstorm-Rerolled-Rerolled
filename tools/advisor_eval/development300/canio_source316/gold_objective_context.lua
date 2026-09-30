-- Optional source-only context. The alternate mode explicitly seeds synthetic
-- prior history in memory; it is never a gameplay result or player achievement.
local M={}
local function plain(v)return type(v)=='table'and not getmetatable(v)end
local function integer(v)return type(v)=='number'and v==v and v>=0 and v<math.huge and v%1==0 end
local function validate(goal)
  if not plain(goal)or goal.schema~=1 or goal.goal~='gold_stickers'or
    goal.metadata_status~='complete'or goal.catalog_status~='complete'or
    goal.stake_status~='complete'or goal.held_status~='complete'then
    return false,'Loaded Gold profile/catalog/stake/inventory metadata is not complete.'
  end
  local c=goal.counts
  if not plain(c)or c.total~=150 or not integer(c.complete)or not integer(c.missing)or
    c.unknown~=0 or c.complete+c.missing~=150 then return false,'Loaded Gold counts are unknown or inconsistent.'end
  local targets,seen,count=goal.targets,{},0
  if not plain(targets)then return false,'Loaded Gold target list is unavailable.'end
  for _,target in ipairs(targets)do
    if not plain(target)or type(target.key)~='string'or seen[target.key]or
      target.status~='missing'and target.status~='complete'then return false,'Loaded Gold target identities are inconsistent.'end
    seen[target.key]=true;count=count+1
  end
  if count~=150 then return false,'Loaded Gold target list is incomplete.'end
  return true
end
function M.attach(spec,modules,g,trace)
  if spec==nil or plain(spec)and spec.enabled==false and spec.mode=='off'then return nil end
  local alternate=plain(spec)and spec.mode=='synthetic_only_canio_missing_v1'
  assert(plain(spec)and spec.schema==1 and (spec.mode=='synthetic_fresh_all_missing_v1'or alternate)and spec.enabled==true and
    spec.profile=='all_unlocked_discovered_v1'and spec.initial_history==(alternate and
      'explicit_synthetic_149_gold_rows_before_first_decision'or'natural_empty_loaded_joker_usage')and
    spec.actual_player_profile==false and spec.qualification==false,'HEADLESS_BOUNDARY unsupported Gold objective specification')
  assert(type(trace)=='function','HEADLESS_BOUNDARY Gold objective receipt output is required')
  local snap=assert(modules.snapshot,'HEADLESS_BOUNDARY frozen snapshot module unavailable')
  local gold=assert(modules.gold_stickers,'HEADLESS_BOUNDARY frozen Gold capture module unavailable')
  assert(modules.gold_goal and type(modules.gold_goal.suggest)=='function','HEADLESS_BOUNDARY frozen Gold objective policy unavailable')
  local profile_id=g.SETTINGS and g.SETTINGS.profile
  local profile=g.PROFILES and g.PROFILES[profile_id]
  assert(type(profile)=='table'and plain(profile.joker_usage)and next(profile.joker_usage)==nil,
    'HEADLESS_BOUNDARY synthetic fresh Gold objective requires natural empty loaded Joker history')
  local game=g.GAME
  assert(game and game.stake==8 and not game.challenge and game.seeded==false,
    'HEADLESS_BOUNDARY Gold objective requires an ordinary filtered Gold run')
  local function capture(loaded)
    assert(loaded==g and loaded.GAME==game and loaded.SETTINGS.profile==profile_id and loaded.PROFILES[profile_id]==profile,
      'HEADLESS_BOUNDARY Gold objective game/profile binding changed')
    local goal=gold.capture(loaded,{enabled=true});local okay,reason=validate(goal)
    assert(okay,'HEADLESS_BOUNDARY Gold objective metadata: '..tostring(reason))
    assert(goal.profile_id==profile_id,'HEADLESS_BOUNDARY Gold objective capture profile differs')
    return goal
  end
  local before=capture(g)
  assert(before.counts.complete==0 and before.counts.missing==150 and before.counts.unknown==0 and
    before.eligibility and before.eligibility.eligible==true,
    'HEADLESS_BOUNDARY fresh all-missing Gold context is ineligible or inconsistent')
  local initial=before
  if alternate then
    assert(plain(spec.missing_keys)and #spec.missing_keys==1 and spec.missing_keys[1]=='j_caino'and
      spec.missing_population=='only_j_caino'and spec.synthetic_gameplay_wins_created==false and
      spec.player_achievement_credit==false and plain(spec.initial_counts)and spec.initial_counts.complete==149 and spec.initial_counts.missing==1 and
      spec.initial_counts.total==150 and spec.initial_counts.unknown==0,
      'HEADLESS_BOUNDARY alternate history population differs from its explicit specification')
    local row=spec.synthetic_history_row
    assert(plain(row)and row.count==1 and row.order=='canonical_key_order_1_based'and
      plain(row.wins)and row.wins['8']==1 and next(row.wins)=='8'and next(row.wins,'8')==nil and
      plain(row.losses)and next(row.losses)==nil,
      'HEADLESS_BOUNDARY alternate history row differs from its explicit specification')
    local filtered=game.filter_info;local collection=filtered and filtered.collection_search
    assert(plain(collection)and collection.primary_legendary_key=='j_caino'and collection.minimum_distinct==1 and
      collection.missing_names=='Canio'and collection.quota_mode=='auto'and collection.opening_adapted==true,
      'HEADLESS_BOUNDARY alternate synthetic history requires the declared Canio Auto route')
    local keys=gold.target_keys();assert(#keys==150,'HEADLESS_BOUNDARY alternate history catalog unavailable')
    local history,count={},0
    for index,key in ipairs(keys)do
      if key~='j_caino'then history[key]={count=1,order=index,wins={[8]=1},losses={}};count=count+1 end
    end
    assert(count==149 and history.j_caino==nil,'HEADLESS_BOUNDARY alternate history did not leave only Canio missing')
    local original=profile.joker_usage;profile.joker_usage=history
    local ok,value=pcall(capture,g)
    if not ok or value.counts.complete~=149 or value.counts.missing~=1 or value.counts.unknown~=0 or
      not value.by_key or not value.by_key.j_caino or value.by_key.j_caino.status~='missing'then
      profile.joker_usage=original
      error('HEADLESS_BOUNDARY synthetic alternate history failed exact loaded product classification')
    end
    initial=value
  end
  local raw=assert(snap.capture,'HEADLESS_BOUNDARY frozen capture function unavailable')
  local function decorated(loaded)
    local value=raw(loaded)
    if value then value.completionist_goal=capture(loaded)end
    return value
  end
  trace({type='engine_gold_objective_context',spec=snap.copy(spec),initial_goal=snap.copy(initial),
    initial_empty_history_verified=true,initialized_before_decision=true,
    game_or_profile_mutated=alternate,synthetic_history_initialized=alternate,
    history_before_initialization=alternate and snap.copy(before)or nil,
    synthetic_prior_history_is_not_gameplay_result=alternate,qualification=false,actual_player_profile=false})
  snap.capture=decorated
  return {capture=function()return snap.copy(capture(g))end,validate=validate}
end
return M

-- Optional source-only context. Never fabricates wins, missing statuses, stake
-- metadata or a player profile. The frozen product capture owns classification.
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
  assert(plain(spec)and spec.schema==1 and spec.mode=='synthetic_fresh_all_missing_v1'and spec.enabled==true and
    spec.profile=='all_unlocked_discovered_v1'and spec.initial_history=='natural_empty_loaded_joker_usage'and
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
  local initial=capture(g)
  assert(initial.counts.complete==0 and initial.counts.missing==150 and initial.counts.unknown==0 and
    initial.eligibility and initial.eligibility.eligible==true,
    'HEADLESS_BOUNDARY fresh all-missing Gold context is ineligible or inconsistent')
  local raw=assert(snap.capture,'HEADLESS_BOUNDARY frozen capture function unavailable')
  local function decorated(loaded)
    local value=raw(loaded)
    if value then value.completionist_goal=capture(loaded)end
    return value
  end
  trace({type='engine_gold_objective_context',spec=snap.copy(spec),initial_goal=snap.copy(initial),
    initial_empty_history_verified=true,initialized_before_decision=true,
    game_or_profile_mutated=false,qualification=false,actual_player_profile=false})
  snap.capture=decorated
  return {capture=function()return snap.copy(capture(g))end,validate=validate}
end
return M

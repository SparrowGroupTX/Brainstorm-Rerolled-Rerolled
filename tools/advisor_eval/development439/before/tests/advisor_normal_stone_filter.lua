-- Execute the actual normal-filter validation and target normalizers only.
-- No native loader, seed search, game startup, profile or save access.
local file=assert(io.open('Brainstorm/Core/Brainstorm.lua','rb'))
local core=file:read('*a');file:close()
local function section(first,last)
  local start=assert(core:find(first,1,true));local finish=assert(core:find(last,start+1,true))
  return core:sub(start,finish-1)
end
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0;local function check(v,label)assert(v,label);checks=checks+1 end
local environment={type=type,ipairs=ipairs,math=math,
  MAX_JOKER_TARGETS=5,DEFAULT_JOKER_TARGET_LOCATION='ante_1',
  joker_target_location_ids={ante_1=true,soul_pack=true,ante_2=true,by_ante_8=true},
  legendary_jokers={Canio=true,Triboulet=true,Yorick=true,Chicot=true,Perkeo=true},
  soul_custom_filters={},later_ante_joker_target_locations={ante_2=true,by_ante_8=true},
  flexible_joker_target_locations={},vanilla_deck_name_set={['Red Deck']=true},
  getCurrentDeckName=function()return 'Red Deck'end,
  getRequiredLegendaryTargetCount=function()return 0 end,
  orderedJokerTargetTimingsPossible=function()return true end,
  orderedJokerTargetRoutePossible=function()return true end,
  deterministicRankFiltersPossible=function()return true end,
  normalizeObservatoryDeadline=function()return 0 end}
local settings={joker_targets={},joker_target_locations={},joker_target_editions={},voucher_name='',tag_name=''}
local game={seeded=true,used_filter=false,challenge=nil}
environment.G={GAME=game}
environment.Brainstorm={config={ar_filters=settings},getRequiredSoulCount=function()return 0 end}
local code=section('local function normalizeJokerTargets(', 'local function normalizeJokerTargetEditions(')..
  section('local function normalizeJokerTargetLocations(', 'local function serializeJokerTargets(')..
  section('function Brainstorm.validateAutoRerollFilters()', 'local function findBrainstormDirectory(')
local chunk=assert(loadstring(code));setfenv(chunk,environment);chunk()
local validate=environment.Brainstorm.validateAutoRerollFilters
local function preserves_input()
  local old_settings=Snapshot.fingerprint(settings);local old_game=Snapshot.fingerprint(game)
  local valid,reason=validate()
  check(Snapshot.fingerprint(settings)==old_settings and Snapshot.fingerprint(game)==old_game,'validation preserves all selected settings and seeded/filter flags')
  return valid,reason
end
check(preserves_input(),'empty ordinary filter remains valid')
for _,joker in ipairs({'Marble Joker','Blueprint','Joker','None'})do
  settings.joker_targets={joker}
  check(preserves_input(),'supported ordinary target remains valid: '..joker)
end
for slot=1,5 do
  settings.joker_targets={};settings.joker_targets[slot]='Stone Joker'
  settings.joker_target_locations={[slot]=slot%2==0 and 'by_ante_8' or 'ante_1'}
  settings.joker_target_editions={[slot]=slot%2==0 and 'Negative' or 'Any Edition'}
  local valid,reason=preserves_input()
  check(not valid and reason:find('Stone Card prerequisite',1,true) and reason:find('Marble Joker first',1,true),'every Stone slot/timing/edition is explicitly rejected before a search')
end
settings.joker_targets={'Marble Joker','Stone Joker'}
settings.joker_target_locations={'ante_1','by_ante_8'}
local valid,reason=preserves_input()
check(not valid and reason:find('cannot yet model',1,true),'Marble followed by later Stone cannot bypass the missing native transition')
settings.joker_targets={'Showman','Stone Joker'}
check(not preserves_input(),'Showman does not certify the missing Stone prerequisite model')
for _,target in ipairs({'Steel Joker','Glass Joker','Golden Ticket','Lucky Cat','Cavendish'}) do
  for slot=1,5 do
    settings.joker_targets={};settings.joker_targets[slot]=target
    settings.joker_target_locations={[slot]=slot%2==0 and 'by_ante_8' or 'ante_1'}
    local valid,reason=preserves_input()
    check(not valid and reason:find('cannot yet model',1,true) and reason:find(target,1,true),
      'fresh locked target cannot launch a fruitless direct search: '..target)
  end
end
local calls=0
environment.Brainstorm.validateChallengeOpening=function()calls=calls+1;return true,'separate challenge validation'end
environment.getCurrentDeckName=function()error('normal validation must not run for a challenge')end
game.challenge='c_medusa_1'
valid,reason=preserves_input()
check(valid and reason=='separate challenge validation' and calls==1,'Medusa retains its separate challenge validation despite persisted normal Stone target')
environment.Brainstorm.validateChallengeOpening=function()calls=calls+1;return false,'challenge unavailable'end
valid,reason=preserves_input()
check(not valid and reason=='challenge unavailable' and calls==2,'challenge rejection is propagated unchanged')
environment.Brainstorm.validateChallengeOpening=nil
valid,reason=preserves_input()
check(not valid and reason=='Challenge opening search is unavailable','missing challenge validator keeps its original fallback')
print('advisor_normal_stone_filter: '..checks..' checks passed')

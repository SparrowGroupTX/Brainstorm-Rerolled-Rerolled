-- Execute the real product dispatcher against detached callbacks. No game
-- startup, global RNG or native search is permitted in the Jokerless branch.
local file=assert(io.open('Brainstorm/Core/Brainstorm.lua','rb'));local source=file:read('*a');file:close()
local first=assert(source:find('function Brainstorm.autoReroll()',1,true))
local last=assert(source:find('function create_UIBox_round_scores_row',first,true))
local checks=0;local function check(v,m) assert(v,m);checks=checks+1 end
local started,stopped,alerts,random=0,0,0,0
Brainstorm={ar_active=true,ar_frames=3,JokerlessOpeningSearch={searching=true},
  validateAutoRerollFilters=function()return true end,
  challengeOpeningSearch=function(...)check(select('#',...)==0,'private search receives no cursor-derived RNG seed');started=started+1;return 'MATCH' end,
  stopChallengeOpeningSearch=function(status,reason)stopped=stopped+1;check(status=='invalidated' and reason=='changed','explicit invalidation');Brainstorm.JokerlessOpeningSearch.searching=false end}
G={GAME={challenge='c_jokerless_1'}}
saveManagerAlert=function()alerts=alerts+1 end
random_string=function()random=random+1;error('global random search must not run') end
assert(loadstring(source:sub(first,last-1)))()
check(Brainstorm.autoReroll()=='MATCH' and started==1 and random==0,'Jokerless dispatch bypasses native/global random seed path')
Brainstorm.validateAutoRerollFilters=function()return false,'changed' end
Brainstorm.autoReroll()
check(stopped==1 and alerts==1 and not Brainstorm.ar_active and not Brainstorm.JokerlessOpeningSearch.searching,'invalid fresh state cancels both scheduler and search session')
check(started==1 and random==0,'invalidated search performs no seed work')
print('advisor_jokerless_runtime_integration: '..checks..' checks passed')

local M=dofile('tools/advisor_eval/development300/adaptive_quota_rebased/Brainstorm/Advisor/collection_search.lua')
local Gold=dofile('Brainstorm/Advisor/gold_stickers.lua')
local Search=dofile('Brainstorm/Advisor/gold_search.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(v,s)checks=checks+1;assert(v,s)end
local function goal()
  local g={schema=1,goal='gold_stickers',profile_id=1,metadata_status='complete',catalog_status='complete',stake_status='complete',
    counts={total=150,complete=0,missing=150,unknown=0},by_key={}}
  for _,key in ipairs(Gold.target_keys())do g.by_key[key]={key=key,status='missing'}end
  return g
end
local g=goal();local before=Snapshot.fingerprint(g)
local request=assert(M.prepare(g,Search,{}))
check(request.native_api_version==9 and request.budget_ms==30000,'bounded v9 request')
check(request.minimum_distinct==0,'unnecessary missing targets do not constrain fresh roster')
check(request.supported_missing_count==141 and #request.excluded_missing_keys==9,'fresh locked targets stay explicit')
check(request.interchangeable_copies and request.reject_perishable_targets,'copy alternatives and no-Perishable criteria')
check(request.native_cpu_mode=='maximum' and request.deck=='Red Deck' and request.stake_level==8,'requested native deck/stake/mode')
check(request.target_jokers=='Yorick\31Brainstorm\31Burnt Joker\31Perkeo\31','exact original target order')
check(request.target_locations=='soul_pack\31by_ante_5\31by_ante_5\31soul_pack\31ante_1','matching timing columns')
check(request.tag=='Charm Tag' and request.souls==2,'native display tag and two Souls')
check(request.starts_search==false,'pure preparation does not start a worker')
check(request.estimate_status=='unavailable','no invented rarity estimate for compound query')
check(Snapshot.fingerprint(g)==before,'progress is immutable')
request=assert(M.prepare(g,Search,{minimum_distinct=4,first_ante=5,last_ante=8,deck_name='Zodiac Deck',interchangeable_copies=false,budget_ms=12000}))
check(request.minimum_distinct==4 and request.first_ante==5 and request.last_ante==8,'late quota')
check(request.deck=='Zodiac Deck' and not request.interchangeable_copies and request.budget_ms==12000,'explicit choices preserved')
for _,options in ipairs({{minimum_distinct=145},{minimum_distinct=-1},{minimum_distinct=0/0},
  {first_ante=0},{first_ante=4,last_ante=3},{last_ante=9},{budget_ms=0},{budget_ms=30001},
  {budget_ms=math.huge},{deck_name='Challenge Deck'},{minimum_distinct=false},
  {first_ante=false},{budget_ms=false},{interchangeable_copies='false'}}) do
  local value,reason=M.prepare(g,Search,options);check(value==nil and type(reason)=='string','invalid criterion rejected')
end
g.by_key.j_joker.status='unknown';g.counts.missing=149;g.counts.unknown=1
check(M.prepare(g,Search,{})==nil,'unknown progress never imputed missing')
g=goal();for _,row in pairs(g.by_key)do row.status='complete'end;g.counts.complete=150;g.counts.missing=0
check(M.prepare(g,Search,{})==nil,'finished profile does not launch redundant collection job')
print('collection_search fixture: '..checks..' checks passed')

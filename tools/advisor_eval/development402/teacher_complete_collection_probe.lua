-- Bounded manufactured request construction only. No game state, native search,
-- scorer, policy replay, original game source, save/profile I/O or live callbacks.
local Query=dofile('Brainstorm/Advisor/collection_search.lua')
local Gold=dofile('Brainstorm/Advisor/gold_search.lua')
local Stickers=dofile('Brainstorm/Advisor/gold_stickers.lua')
local checks=0
local function check(value,label) checks=checks+1;assert(value,label) end
local goal={schema=1,goal='gold_stickers',profile_id=1,
  metadata_status='complete',catalog_status='complete',stake_status='complete',
  counts={total=150,complete=150,missing=0,unknown=0},by_key={}}
for _,key in ipairs(Stickers.target_keys()) do goal.by_key[key]={key=key,status='complete'} end
local options={deck_name='Red Deck',interchangeable_copies=true,quota_mode='strict',
  minimum_distinct=0,first_ante=1,last_ante=8,budget_ms=30000,
  burnt_fallback=true,legendary_fallback=false}
math.random=function() error('Request construction must not use RNG.') end
local choices,detail=Gold.choices(goal)
check(choices and #choices==0 and detail.unknown_count==0,'real metadata validator accepts all-complete synthetic ledger')
local result,reason=Query.prepare(goal,Gold,options)
check(result==nil and reason=='Every vanilla Joker already has a Gold sticker.',
  'CURRENT GAP reproduced: zero-quota teacher recipe rejected on complete ledger')
print('CURRENT GAP: '..reason)

goal.by_key.j_joker.status='missing';goal.counts.complete=149;goal.counts.missing=1
local ordinary=assert(Query.prepare(goal,Gold,options))
check(ordinary.minimum_distinct==0 and ordinary.burnt_fallback and ordinary.interchangeable_copies,
  'same zero-quota request works with one irrelevant missing sticker')
check(options.quota_mode=='strict' and options.minimum_distinct==0 and options.budget_ms==30000,
  'request options were not mutated')

goal.by_key.j_joker.status='unknown';goal.counts.missing=0;goal.counts.unknown=1
local unknown,why=Query.prepare(goal,Gold,options)
check(unknown==nil and why:find('unknown records',1,true),'unknown metadata is correctly rejected')
print('teacher_complete_collection_probe: '..checks..' checks passed; current gap reproduced, no fix applied')

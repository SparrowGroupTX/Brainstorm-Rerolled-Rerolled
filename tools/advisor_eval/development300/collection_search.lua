-- Detached request construction only. The runtime owns consent, threading,
-- query cancellation, launch safety, profile refresh and event logging.
local M={}
local function integer(v,lo,hi) return type(v)=='number' and v==v and v%1==0 and v>=lo and v<=hi end
local function option(t,key,fallback)local value=rawget(t,key);if value==nil then return fallback end;return value end
function M.prepare(goal,gold,options)
  if options==nil then options={} end
  if type(options)~='table' or getmetatable(options) then return nil,'Search options must be plain data.' end
  if type(gold)~='table' or type(gold.choices)~='function' then return nil,'Gold search metadata is unavailable.' end
  local choices,detail=gold.choices(goal)
  if not choices then return nil,detail end
  if detail.unknown_count~=0 then return nil,'Gold progress has unknown records; refresh the active profile.' end
  local minimum=option(options,'minimum_distinct',0)
  local first,last=option(options,'first_ante',1),option(options,'last_ante',8)
  local budget=option(options,'budget_ms',30000)
  if not integer(minimum,0,150) or not integer(first,1,8) or not integer(last,first,8)
    or not integer(budget,1,30000) then return nil,'Choose a valid target count, Ante window and search budget up to 30 seconds.' end
  local missing,excluded={},{}
  for _,row in ipairs(choices) do
    if row.direct_supported then missing[#missing+1]=row.label else excluded[#excluded+1]=row.key end
  end
  if #choices==0 then return nil,'Every vanilla Joker already has a Gold sticker.' end
  if minimum>#missing then return nil,'Too few supported missing targets remain for that encounter count.' end
  local copies=option(options,'interchangeable_copies',true)
  if type(copies)~='boolean' then return nil,'The copy alternative option must be true or false.' end
  local deck=option(options,'deck_name','Red Deck')
  if deck~='Red Deck' and deck~='Zodiac Deck' then return nil,'This opening preset supports Red or Zodiac Deck.' end
  return {
    schema=1,profile_id=detail.profile_id,native_api_version=9,
    voucher='',pack='',tag='Charm Tag',souls=2,observatory=false,
    observatory_deadline=0,perkeo=false,copymoney=false,retcon=false,
    bean=false,burglar=false,custom_filter='No Filter',target_rank='Kings',
    target_suit='Any Suit',specific_rank_min=0,any_rank_min=0,
    target_jokers=table.concat({'Yorick','Brainstorm','Burnt Joker','Perkeo',''},'\31'),
    target_locations=table.concat({'soul_pack','by_ante_5','by_ante_5','soul_pack','ante_1'},'\31'),
    deck=deck,stake_level=8,reject_perishable_targets=true,
    interchangeable_copies=copies,missing_names=table.concat(missing,'\31'),
    minimum_distinct=minimum,first_ante=first,last_ante=last,budget_ms=budget,
    native_cpu_mode='maximum',supported_missing_count=#missing,excluded_missing_keys=excluded,
    starts_search=false,assumes_complete_profile_unlocks=true,profile_unlocks_verified=false,
    estimate_status='unavailable',
    route='conditional_no_reroll_stock_and_buffoon',
    route_note='Take both starting Souls; inspect initial shop stock and open displayed Buffoon packs in order without rerolls. Other Joker acquisitions can change later offers.',
    limitation='Encounter counts are conditional offers, not affordable acquisition, retention, survival or wins.',
  }
end
return M

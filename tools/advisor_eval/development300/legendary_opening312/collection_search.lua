-- Detached request construction only. The runtime owns consent, threading,
-- query cancellation, launch safety, profile refresh and event logging.
local M={}
local legendary={j_caino='Canio',j_triboulet='Triboulet',j_chicot='Chicot',j_yorick='Yorick',j_perkeo='Perkeo'}
local function unavailable(row,first,primary)
  if not row.direct_supported then return row.reason or 'This prerequisite is outside the modeled fresh-run route.' end
  if legendary[row.key] and row.key~=primary and row.key~='j_perkeo' then
    return 'The two starting Souls are reserved for '..legendary[primary]..' and Perkeo; this route has no later Legendary source.'
  end
  if (row.key==primary or row.key=='j_perkeo') and first>1 then return 'This opening Legendary is produced in Ante 1, before the requested counting window.' end
end
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
  -- Standalone/manual callers retain strict numeric semantics, including zero.
  -- The explicit auto-run facade/UI choose automatic mode separately.
  local mode=option(options,'quota_mode','strict')
  if mode~='auto' and mode~='strict' then return nil,'Choose Automatic or a strict numeric missing-target count.' end
  local first,last=option(options,'first_ante',1),option(options,'last_ante',8)
  local budget=option(options,'budget_ms',30000)
  if not integer(minimum,0,150) or not integer(first,1,8) or not integer(last,first,8)
    or not integer(budget,1,30000) then return nil,'Choose a valid target count, Ante window and search budget up to 30 seconds.' end
  local legendary_fallback=option(options,'legendary_fallback',false)
  if type(legendary_fallback)~='boolean' then return nil,'Choose whether automatic runs may change the first Legendary when the fixed route is exhausted.' end
  local primary,adapted='j_yorick',false
  local missing,excluded,excluded_reasons={},{},{}
  local function collect()
    missing,excluded,excluded_reasons={},{},{}
    for _,row in ipairs(choices) do
      local reason=unavailable(row,first,primary)
      if reason then
        excluded[#excluded+1]=row.key
        excluded_reasons[#excluded_reasons+1]={key=row.key,label=row.label,reason=reason}
      else missing[#missing+1]=row.label end
    end
  end
  collect()
  if mode=='auto' and legendary_fallback and #missing==0 and first==1 then
    local eligible={}
    for _,row in ipairs(choices)do
      if row.direct_supported and legendary[row.key] and row.key~='j_yorick' and row.key~='j_perkeo' then eligible[#eligible+1]=row.key end
    end
    table.sort(eligible)
    if eligible[1]then primary=eligible[1];adapted=true;collect()end
  end
  if #choices==0 then return nil,'Every vanilla Joker already has a Gold sticker.' end
  if mode=='auto' and #missing==0 then
    local why=excluded_reasons[1]and excluded_reasons[1].reason or 'The selected Ante window has no modeled source.'
    local rest=#excluded_reasons>1 and (' '..tostring(#excluded_reasons-1)..' other missing targets are also outside this route.')or ''
    return nil,'This opening has no reachable missing Jokers. '..why..rest
  end
  local requested=minimum
  if mode=='auto' then minimum=1 end
  if minimum>#missing then return nil,'Only '..#missing..' missing Jokers are reachable on this opening route in that Ante window; the strict count is '..minimum..'.' end
  local copies=option(options,'interchangeable_copies',true)
  if type(copies)~='boolean' then return nil,'The copy alternative option must be true or false.' end
  local fallback=option(options,'burnt_fallback',false)
  if type(fallback)~='boolean' then return nil,'Choose whether Burnt may be relaxed after the first search phase.' end
  local deck=option(options,'deck_name','Red Deck')
  if deck~='Red Deck' and deck~='Zodiac Deck' then return nil,'This opening preset supports Red or Zodiac Deck.' end
  return {
    schema=1,profile_id=detail.profile_id,native_api_version=9,
    voucher='',pack='',tag='Charm Tag',souls=2,observatory=false,
    observatory_deadline=0,perkeo=false,copymoney=false,retcon=false,
    bean=false,burglar=false,custom_filter='No Filter',target_rank='Kings',
    target_suit='Any Suit',specific_rank_min=0,any_rank_min=0,
    target_jokers=table.concat({legendary[primary],'Brainstorm','Burnt Joker','Perkeo',''},'\31'),
    target_locations=table.concat({'soul_pack','by_ante_5','by_ante_5','soul_pack','ante_1'},'\31'),
    deck=deck,stake_level=8,reject_perishable_targets=true,
    interchangeable_copies=copies,missing_names=table.concat(missing,'\31'),
    burnt_fallback=fallback,burnt_required=true,
    legendary_fallback=legendary_fallback,primary_legendary_key=primary,primary_legendary_name=legendary[primary],
    opening_adapted=adapted,opening_note=adapted and ('The fixed Yorick route has no reachable missing target; use missing '..legendary[primary]..' with Perkeo. Survival on this alternate opening is unverified.') or 'Yorick and Perkeo opening.',
    quota_mode=mode,minimum_distinct=minimum,requested_minimum_distinct=requested,
    first_ante=first,last_ante=last,budget_ms=budget,
    native_cpu_mode='maximum',supported_missing_count=#missing,excluded_missing_keys=excluded,
    excluded_missing_reasons=excluded_reasons,
    quota_scope='Distinct reachable conditional offers on this fixed opening and Ante window; no acquisition or win credit.',
    starts_search=false,assumes_complete_profile_unlocks=true,profile_unlocks_verified=false,
    estimate_status='unavailable',
    route='conditional_no_reroll_stock_and_buffoon',
    route_note='Take both starting Souls; inspect initial shop stock and open displayed Buffoon packs in order without rerolls. Other Joker acquisitions can change later offers.',
    limitation='Encounter counts are conditional offers, not affordable acquisition, retention, survival or wins.',
  }
end
return M

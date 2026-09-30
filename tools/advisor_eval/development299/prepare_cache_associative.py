"""Prepare a distinct dense two-way classification cache; never stage runtime."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3]
D=Path(__file__).resolve().parent/'drafts/cache_associative'
D.mkdir(exist_ok=False)
source=ROOT/'Brainstorm/Advisor/score_cache.lua'
s=source.read_text()
old='local entries,cache=0,{}'
new='''local entries,cache,victims=0,{},{}
  local ways=max_entries>=2 and 2 or 1
  local buckets=math.max(1,math.floor(max_entries/ways))
  -- A prime modulus spreads the ordered packed card tokens across dense
  -- slots. Every hit still checks the complete exact key, so collisions only
  -- change work, never classification. Capacity never exceeds the old bound.
  local function prime(n)
    if n<2 then return false end
    for divisor=2,math.floor(math.sqrt(n)) do if n%divisor==0 then return false end end
    return true
  end
  while buckets>1 and not prime(buckets) do buckets=buckets-1 end'''
assert s.count(old)==1;s=s.replace(old,new)
old='flag_builds=0,row_builds=0}'
assert s.count(old)==1;s=s.replace(old,'flag_builds=0,row_builds=0,evictions=0}')
old='''    local found=cache[key]
    if found then'''
new='''    local slot=(key%buckets)*ways+1
    local found=cache[slot]
    if not (found and found.key==key) then
      local other=ways==2 and cache[slot+1]
      found=other and other.key==key and other or nil
    end
    if found then'''
assert s.count(old)==1;s=s.replace(old,new)
old='''    if entries<max_entries then
      local positions={};for i,index in ipairs(selected) do positions[index]=i end
      local relative={};for i,index in ipairs(scoring) do relative[i]=positions[index] end
      entries=entries+1;stats.stored=entries
      cache[key]={category=category,scoring=relative,contains=contains}
    end'''
new='''    if max_entries>0 then
      local positions={};for i,index in ipairs(selected) do positions[index]=i end
      local relative={};for i,index in ipairs(scoring) do relative[i]=positions[index] end
      local target=slot
      if cache[slot] then
        if ways==2 and not cache[slot+1] then target=slot+1
        else
          if ways==2 and victims[slot] then target=slot+1 end
          victims[slot]=not victims[slot]
        end
      end
      local entry=cache[target]
      if entry then stats.evictions=stats.evictions+1
      else entry={};cache[target]=entry;entries=entries+1;stats.stored=entries end
      entry.key=key;entry.category=category;entry.scoring=relative;entry.contains=contains
    end'''
assert s.count(old)==1;s=s.replace(old,new)
(D/'score_cache.lua').write_text(s)
test=(D.parent/'cache_eviction/test_cache.lua').read_text().replace('drafts/cache_eviction/','drafts/cache_associative/')
test=test.replace('FIFO eviction:', 'Dense associative eviction:')
(D/'test_cache.lua').write_text(test)
(D/'manifest.json').write_text(json.dumps({'base_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
 'candidate_sha256':hashlib.sha256((D/'score_cache.lua').read_bytes()).hexdigest(),
 'hypothesis':'Dense prime-indexed two-way cache with exact full-key checks avoids repeated sparse numeric-key table deletion/insertion while retaining later classifications. Same capacity and score budgets; no speed benefit assumed.',
 'prior_negative_evidence':'gold299_20260914/M19 FIFO preserved semantics but was slower on both captured hands; it is not installed.'},indent=2))
print(D)

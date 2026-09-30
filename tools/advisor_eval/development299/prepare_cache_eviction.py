"""Detached bounded-cache candidate and synthetic validation; no runtime staging."""
from pathlib import Path
import hashlib,json
ROOT=Path(__file__).resolve().parents[3]
D=Path(__file__).resolve().parent/'drafts/cache_eviction'
D.mkdir(exist_ok=False)
source=ROOT/'Brainstorm/Advisor/score_cache.lua'
s=source.read_text()
old='local entries,cache=0,{}'
assert s.count(old)==1
s=s.replace(old,'local entries,cache,slots,next_slot=0,{},{},1')
old='flag_builds=0,row_builds=0}'
assert s.count(old)==1
s=s.replace(old,'flag_builds=0,row_builds=0,evictions=0}')
old='''    if entries<max_entries then
      local positions={};for i,index in ipairs(selected) do positions[index]=i end
      local relative={};for i,index in ipairs(scoring) do relative[i]=positions[index] end
      entries=entries+1;stats.stored=entries
      cache[key]={category=category,scoring=relative,contains=contains}
    end'''
new='''    if max_entries>0 then
      local positions={};for i,index in ipairs(selected) do positions[index]=i end
      local relative={};for i,index in ipairs(scoring) do relative[i]=positions[index] end
      -- Replace the oldest inserted classification after saturation. The exact
      -- ordered key still gates every hit; eviction changes work only.
      local evicted=slots[next_slot]
      if evicted then cache[evicted]=nil;stats.evictions=stats.evictions+1
      else entries=entries+1;stats.stored=entries end
      slots[next_slot]=key;next_slot=next_slot%max_entries+1
      cache[key]={category=category,scoring=relative,contains=contains}
    end'''
assert s.count(old)==1
s=s.replace(old,new)
(D/'score_cache.lua').write_text(s)
test=(ROOT/'tests/advisor_score_cache.lua').read_text().replace("dofile('Brainstorm/Advisor/score_cache.lua')", "dofile('tools/advisor_eval/development299/drafts/cache_eviction/score_cache.lua')")
test+='''
-- Capacity stays fixed and exact keys still remap relative positions after
-- saturation. A working set arriving late can now acquire cache entries.
local wrapped,measure=Cache.new(C,{max_entries=2})
local smallstates={}
for rank=2,6 do smallstates[#smallstates+1]={hand={card(rank,rank,'Spades')},jokers={}} end
for _,state in ipairs(smallstates) do eq(classified(state,{1},wrapped),classified(state,{1},C),'eviction parity') end
local hits=measure().hits
for _,state in ipairs({smallstates[4],smallstates[5]}) do eq(classified(state,{1},wrapped),classified(state,{1},C),'late working set parity') end
assert(measure().stored==2 and measure().evictions==3 and measure().hits==hits+2)
print('FIFO eviction: exact bounded late-working-set reuse passed')
'''
(D/'test_cache.lua').write_text(test)
(D/'manifest.json').write_text(json.dumps({'base_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
 'candidate_sha256':hashlib.sha256((D/'score_cache.lua').read_bytes()).hexdigest(),
 'hypothesis':'Bounded FIFO replacement retains classifications from later common worlds after the same8192-entry cache saturates; no decision, cap or sampled-world change.'},indent=2))
print(D)

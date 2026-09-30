-- Manufactured constructor/default regression. No player replay or source run.
local F=dofile('tests/fixtures/gold_tarot_hold_support.lua')
local H,S=F.Hold,F.Snapshot
S.gold_tarot_hold=H
local checks=0
local function check(v,why) checks=checks+1;assert(v,why) end
local function observe(raw)
  G={P_CENTERS={[raw.config.center.key]=raw.config.center}}
  return S.card(raw)
end
math.random=function() error('No RNG in Tarot capture qualification') end
pseudorandom=math.random;pseudoseed=math.random
for _,key in ipairs({'c_magician','c_hermit'}) do
  for _,negative in ipairs({false,true}) do
    local raw=F.raw(key,1,negative)
    raw.pinned=nil
    local before=S.fingerprint(raw)
    local absent=observe(raw)
    check(absent.pinned==false,'Snapshot exposes absent raw pin as unpinned')
    check(absent.tarot_hold_source.supported,'raw absent pin qualifies '..key)
    check(S.fingerprint(raw)==before,'capture must leave the absent pin absent')
    raw.pinned=false
    local explicit=observe(raw)
    check(explicit.tarot_hold_source.supported,'explicit false pin still qualifies')
    check(S.fingerprint(absent)==S.fingerprint(explicit),'absent/false have one public meaning')
    for _,invalid in ipairs({true,0,1,'false','',{},function() end}) do
      raw.pinned=invalid
      check(not observe(raw).tarot_hold_source.supported,'pinned and malformed raw pins reject')
    end
  end
end
-- A complete mixed pool captured through Snapshot retains every original.
local state=F.state();state.consumeables={}
for i=1,14 do
  local raw=F.raw(i%2==0 and 'c_hermit' or 'c_magician',i,true)
  raw.pinned=nil;state.consumeables[i]=observe(raw)
end
local original=S.fingerprint(state)
local receipt,why=H.certify(state)
check(receipt,why or 'the real capture hook qualifies all fourteen source-shaped originals')
check(receipt.copy_events==2,'copy-chain count is unchanged')
check(receipt.inventory_count_before==14 and receipt.inventory_count_after==16,'all originals and copies counted')
check(S.fingerprint(state)==original,'complete certificate preserves original input')
print('PASS Tarot raw pin default '..checks..' checks')

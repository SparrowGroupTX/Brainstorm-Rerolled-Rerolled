local Catalog=dofile(PROBE_MODULE)
function copy_table(v)
  if type(v)~='table' then return v end
  local c={};for k,x in pairs(v) do c[k]=copy_table(x) end;return c
end
function find_joker() return {} end
local function equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
  for k,v in pairs(b) do if not equal(v,a[k]) then return false end end
  return true
end
G={P_CENTERS=PROBE_CENTERS,GAME={hands_played=7,used_jokers={},inflation=0,discount_percent=0,modifiers={},round_resets={ante=1}},
  SETTINGS={tutorial_complete=true}}
local count,checks=0,0
for key,center in pairs(PROBE_CENTERS) do
  local entry={key=key,name=center.name,cost=center.cost,rarity=center.rarity,
    source_config=copy_table(center.config),source_set=center.set,source_effect=center.effect,
    source_order=center.order,blueprint_compat=center.blueprint_compat}
  if Catalog.supports(entry) then
    count=count+1
    for _,terms in ipairs({{0,0},{2,25}}) do
      G.GAME.inflation,G.GAME.discount_percent=terms[1],terms[2]
      local live=setmetatable({T={x=0,y=0,w=1,h=1},params={},config={card={}},
        set_sprites=function() end,bypass_discovery_center=true,facing='front'},{__index=Card})
      live:set_ability(center,true);live:set_cost()
      local detached=assert(Catalog.create(entry,live.cost,{hands_played_total=7}))
      assert(equal(live.ability,detached.ability),'Ability mismatch: '..key)
      checks=checks+1
      assert(detached.cost==live.cost and detached.sell_cost==live.sell_cost,'Cost mismatch: '..key)
      checks=checks+1
      if type(detached.ability.extra)=='table' then
        detached.ability.extra.probe_mutation=true
        assert(not entry.source_config.extra.probe_mutation,'Factory mutated source config: '..key)
        checks=checks+1
      end
    end
  end
end
assert(count>=50,'Unexpected supported-catalog coverage')
local edition_poll
function pseudoseed(key) return key end
function pseudorandom() return edition_poll end
for _,rate in ipairs({0,1,2,4,25,30}) do
  G.GAME.edition_rate=rate
  local probability=assert(Catalog.no_edition_probability(rate))
  if probability>0 then
    edition_poll=probability-0.00000001
    assert(poll_edition('fixture')==nil,'No-edition lower boundary disagrees at rate '..rate)
    checks=checks+1
  end
  edition_poll=math.min(1,probability+0.00000001)
  assert(poll_edition('fixture')~=nil,'Edition upper boundary disagrees at rate '..rate)
  checks=checks+1
end
print('catalog source parity: '..count..' Jokers, '..checks..' comparisons')

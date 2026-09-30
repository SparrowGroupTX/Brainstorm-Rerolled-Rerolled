-- Original-source opening generation only; no blind actions, saves or policy.
local function json(v)
  if v==nil then return 'null' end
  if type(v)=='boolean' or type(v)=='number' then return tostring(v) end
  if type(v)=='string' then return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r')..'"' end
  local keys,out={},{}
  for k in pairs(v) do keys[#keys+1]=k end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
  if #v>0 then for i=1,#v do out[i]=json(v[i]) end;return '['..table.concat(out,',')..']' end
  for _,k in ipairs(keys) do out[#out+1]=json(k)..':'..json(v[k]) end
  return '{'..table.concat(out,',')..'}'
end
assert(G.GAME.challenge=='c_jokerless_1' and #G.jokers.cards==0 and G.jokers.config.card_limit==0)
local prototype_keys={}
for _,set in ipairs({'Tag','Voucher','Tarot','Planet','Enhanced','Booster'}) do prototype_keys[set]={}
 for _,p in ipairs(G.P_CENTER_POOLS[set]) do prototype_keys[set][#prototype_keys[set]+1]=p.key end
end
local initial={used=copy_table(G.GAME.used_jokers),modifiers=copy_table(G.GAME.modifiers),
 stake=G.GAME.stake,rates={joker=G.GAME.joker_rate,tarot=G.GAME.tarot_rate,planet=G.GAME.planet_rate,
 playing=G.GAME.playing_card_rate,spectral=G.GAME.spectral_rate},shop=copy_table(G.GAME.shop)}
local detached_catalog,detached_reason=require('jokerless_opening').catalog(G)
initial.detached_catalog=detached_catalog;initial.detached_reason=detached_reason
local function pool(set)
  local p,k=get_current_pool(set);local out={};for i,v in ipairs(p) do out[i]=v end;return out,k
end
local tags,tag_key=pool('Tag');local vouchers,voucher_key=pool('Voucher');local enhanced,enhanced_key=pool('Enhanced')
local tarots=pool('Tarot');local planets=pool('Planet');local boosters={}
for _,p in ipairs(G.P_CENTER_POOLS.Booster) do if not G.GAME.banned_keys[p.key] then
 boosters[#boosters+1]={key=p.key,kind=p.kind,weight=p.weight or 1,choose=p.config.choose,extra=p.config.extra,cost=p.cost}
end end
local fronts={};for key,v in pairs(G.P_CARDS) do fronts[#fronts+1]={key=key,sort_id=v.sort_id,rank=v.id,suit=v.suit} end
table.sort(fronts,function(a,b)if a.sort_id and b.sort_id then return a.sort_id<b.sort_id end;return a.key<b.key end)
local result={kind='source_jokerless_opening',seed=PROBE_SEED,prototype_keys=prototype_keys,initial=initial,small_tag=G.GAME.round_resets.blind_tags.Small,
 big_tag=G.GAME.round_resets.blind_tags.Big,voucher=G.GAME.current_round.voucher,
 catalog={tags=tags,vouchers=vouchers,enhancements=enhanced,fronts=fronts,tarots=tarots,planets=planets,boosters=boosters,tag_key=tag_key,
 voucher_key=voucher_key,enhancement_key=enhanced_key,edition_rate=G.GAME.edition_rate,
 pack=G.P_CENTERS.p_standard_mega_1.config},packs={},shop={},banned=copy_table(G.GAME.banned_keys),qualification=false}
-- Actual source shop generation; only display decoration is omitted. No blind
-- is played and no affordability or survival is claimed by this probe.
require('functions/UI_definitions')
create_shop_card_ui=function()end
G.shop_jokers=CardArea(0,0,5*G.CARD_W,G.CARD_H,{card_limit=2,type='shop'})
for i=1,2 do local c=create_card_for_shop(G.shop_jokers);G.shop_jokers:emplace(c)
 result.shop[i]={key=c.config.center.key,set=c.ability.set}
end
for i=1,2 do local p=get_pack('shop_pack')
 result.packs[i]={key=p.key,kind=p.kind,choose=p.config.choose,extra=p.config.extra,cost=p.cost}
end
for _,p in ipairs(result.packs) do if p.kind=='Standard' then
G.pack_cards=CardArea(0,0,5*G.CARD_W,G.CARD_H,{card_limit=p.extra,type='consumeable'});p.cards={}
for i=1,p.extra do
  local c=create_card((pseudorandom(pseudoseed('stdset1'))>0.6) and 'Enhanced' or 'Base',G.pack_cards,nil,nil,nil,true,nil,'sta')
  c:set_edition(poll_edition('standard_edition1',2,true))
  if pseudorandom(pseudoseed('stdseal1'))>0.8 then
    local poll=pseudorandom(pseudoseed('stdsealtype1'))
    c:set_seal(poll>0.75 and 'Red' or poll>0.5 and 'Blue' or poll>0.25 and 'Gold' or 'Purple')
  end
  G.pack_cards:emplace(c)
  p.cards[i]={front=c.config.card_key,key=c.config.center.key,seal=c.seal or 'none',
    edition=c.edition and (c.edition.polychrome and 'polychrome' or c.edition.holo and 'holo' or c.edition.foil and 'foil') or 'base'}
end
end end
result.predicted=require('jokerless_opening').predict(PROBE_SEED,result.catalog)
PROBE_RESULT_JSON=json(result)

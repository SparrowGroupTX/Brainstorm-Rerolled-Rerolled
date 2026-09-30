local O=assert(loadstring(PROBE_CORE))()
assert(G.GAME.challenge==PROBE_CHALLENGE)
local target
for _,key in ipairs(O.rare_keys) do
 local c=G.P_CENTERS[key]
 if c.unlocked~=false and not G.GAME.banned_keys[key] and not G.GAME.used_jokers[key] then target=target or key end
end
assert(target,'source fixture has no available Rare target')
local request,reason=O.later_request(G,{later_enabled=true,later_target=target,later_ante=8})
assert(request,PROBE_CHALLENGE..': '..tostring(reason))
local expected={}
for i,key in ipairs(O.rare_keys) do
 expected[i]=(G.P_CENTERS[key].unlocked~=false and not G.GAME.banned_keys[key] and not G.GAME.used_jokers[key]) and '1' or '0'
end
assert(request.rare_pool_mask==table.concat(expected),'mask differs from original source pool membership')
assert(request.shop_slots==G.GAME.shop.joker_max)
for field,value in pairs(request.shop_rates) do assert(G.GAME[field]==value,'shop profile differs: '..field) end
PROBE_CORE_ADMISSION=target..'|'..request.rare_pool_mask

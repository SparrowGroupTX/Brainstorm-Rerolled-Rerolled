local count=0
local function check(actual,expected)
  count=count+1;assert(actual==expected,tostring(actual)..' ~= '..tostring(expected))
end
function EMPTY(t) for key in pairs(t) do t[key]=nil end;return t end
function find_joker() return {} end
local function reset()
  G={ARGS={TEMP_POOL={}},GAME={challenge='source_profile_fixture',round_resets={ante=1},used_jokers={},
    used_vouchers={},pool_flags={},banned_keys={},hands={['Five of a Kind']={played=0}}},
    P_CENTERS={},P_JOKER_RARITY_POOLS={},P_CENTER_POOLS={},playing_cards={}}
end
local function joined(kind,rarity,legendary) return table.concat(get_current_pool(kind,rarity,legendary,'audit'),',') end
reset()
local open={key='j_open_fixture',set='Joker',unlocked=true,rarity=1}
local locked={key='j_locked_fixture',set='Joker',unlocked=false,rarity=1}
G.P_JOKER_RARITY_POOLS[1]={open,locked}
check(joined('Joker',0),'j_open_fixture,UNAVAILABLE') -- challenge mode does not bypass unlock gates
locked.unlocked=true
check(joined('Joker',0),'j_open_fixture,j_locked_fixture')
G.GAME.used_jokers[locked.key]=true
check(joined('Joker',0),'j_open_fixture,UNAVAILABLE')
G.GAME.used_jokers={};G.GAME.banned_keys[locked.key]=true
check(joined('Joker',0),'j_open_fixture,UNAVAILABLE')
G.P_JOKER_RARITY_POOLS[4]={{key='j_legend_fixture',set='Joker',unlocked=false,rarity=4}}
check(joined('Joker',0,true),'j_legend_fixture')
reset()
G.P_CENTERS.j_requirement={discovered=false}
G.P_CENTER_POOLS.Tag={{key='tag_basic_fixture'},{key='tag_require_fixture',requires='j_requirement'}}
check(joined('Tag'),'tag_basic_fixture,UNAVAILABLE')
G.P_CENTERS.j_requirement.discovered=true
check(joined('Tag'),'tag_basic_fixture,tag_require_fixture')
G.P_CENTER_POOLS.Tag[2].min_ante=2
check(joined('Tag'),'tag_basic_fixture,UNAVAILABLE')
reset()
G.P_CENTER_POOLS.Voucher={{key='v_base_fixture',set='Voucher',unlocked=true},
  {key='v_child_fixture',set='Voucher',unlocked=true,requires={'v_base_fixture'}}}
check(joined('Voucher'),'v_base_fixture,UNAVAILABLE')
G.GAME.used_vouchers.v_base_fixture=true
check(joined('Voucher'),'UNAVAILABLE,v_child_fixture')
reset()
G.P_CENTER_POOLS.Planet={{key='c_base_fixture',set='Planet',unlocked=true,config={}},
 {key='c_softlock_fixture',set='Planet',unlocked=true,config={softlock=true,hand_type='Five of a Kind'}}}
check(joined('Planet'),'c_base_fixture,UNAVAILABLE')
G.GAME.hands['Five of a Kind'].played=1
check(joined('Planet'),'c_base_fixture,c_softlock_fixture')
print('unlock profile original-source gate audit: '..count..' comparisons passed')

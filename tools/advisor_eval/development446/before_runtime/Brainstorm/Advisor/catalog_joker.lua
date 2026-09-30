-- Construct only supported ordinary prospective Jokers from detached original
-- center metadata. No future offer, edition, sticker or random state is guessed.
local M={}
local supported={
  j_joker=true,j_greedy_joker=true,j_lusty_joker=true,j_wrathful_joker=true,j_gluttenous_joker=true,
  j_jolly=true,j_zany=true,j_mad=true,j_crazy=true,j_droll=true,j_sly=true,j_wily=true,
  j_clever=true,j_devious=true,j_crafty=true,j_half=true,j_banner=true,j_mystic_summit=true,
  j_raised_fist=true,j_fibonacci=true,j_scary_face=true,j_abstract=true,j_even_steven=true,
  j_odd_todd=true,j_scholar=true,j_supernova=true,j_blackboard=true,j_hack=true,j_baron=true,
  j_photograph=true,j_arrowhead=true,j_onyx_agate=true,j_popcorn=true,j_ice_cream=true,
  j_turtle_bean=true,j_stuntman=true,j_juggler=true,j_troubadour=true,j_sock_and_buskin=true,
  j_hanging_chad=true,j_smiley=true,j_flower_pot=true,j_duo=true,j_trio=true,j_family=true,
  j_order=true,j_tribe=true,j_stencil=true,j_steel_joker=true,j_stone=true,j_blueprint=true,
  j_brainstorm=true,j_mime=true,j_four_fingers=true,j_shortcut=true,j_smeared=true,j_splash=true,
}
local function finite(x) return type(x)=='number' and x==x and x~=math.huge and x~=-math.huge end
function M.no_edition_probability(rate)
  if not finite(rate) or rate<0 then return nil end
  -- Original ordinary create_card calls poll_edition with mod=1. The negative
  -- branch remains 0.003 even when the other edition-rate thresholds are zero.
  return math.max(0,math.min(1,1-math.max(0.003,0.04*rate)))
end
local function copy(v)
  if type(v)~='table' then return v end
  local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out
end
function M.supports(entry)
  return type(entry)=='table' and supported[entry.key] and entry.source_set=='Joker'
    and type(entry.source_config)=='table' and type(entry.name)=='string' and entry.name~=''
end
function M.create(entry,price,snapshot)
  if not M.supports(entry) then return nil,'Original center metadata or supported immediate effect is missing.' end
  if not finite(price) or price<0 then return nil,'The prospective price is invalid.' end
  local c=entry.source_config
  -- Mirrors the corresponding base assignments in original Card:set_ability.
  -- Stateful/random initialization (e.g. To Do List, Loyalty) is not in support.
  local a={name=entry.name,effect=entry.source_effect,set='Joker',
    mult=c.mult or 0,h_mult=c.h_mult or 0,h_x_mult=c.h_x_mult or 0,
    h_dollars=c.h_dollars or 0,p_dollars=c.p_dollars or 0,t_mult=c.t_mult or 0,
    t_chips=c.t_chips or 0,x_mult=c.Xmult or 1,h_size=c.h_size or 0,d_size=c.d_size or 0,
    extra=copy(c.extra),extra_value=0,type=c.type or '',order=entry.source_order,
    perma_bonus=0,bonus=c.bonus or 0,hands_played_at_create=(snapshot or {}).hands_played_total or 0}
  for _,key in ipairs({'mult','h_mult','h_x_mult','h_dollars','p_dollars','t_mult','t_chips',
    'x_mult','h_size','d_size','bonus','hands_played_at_create'}) do
    if not finite(a[key]) then return nil,'A source scoring field is invalid.' end
  end
  return {id='catalog:'..entry.key,key=entry.key,name=entry.name,rarity=entry.rarity,
    ability=a,cost=price,sell_cost=math.max(1,math.floor(price/2)),debuff=false,
    blueprint_compat=entry.blueprint_compat,pinned=false}
end
return M

local H=dofile('Brainstorm/Advisor/gold_tarot_hold.lua')
local S=dofile('Brainstorm/Advisor/snapshot.lua')
local M={Hold=H,Snapshot=S}
function M.raw(key,id,is_negative)
  local magician=key=='c_magician'
  local config=magician and {mod_conv='m_lucky',mod_num=2,max_highlighted=2} or {extra=20}
  local center={key=key,name=magician and 'The Magician' or 'The Hermit',set='Tarot',consumeable=true,
    effect=magician and 'Enhance' or 'Dollar Doubler',cost=3,order=magician and 2 or 10,config=config}
  local a={name=center.name,set='Tarot',effect=center.effect,order=center.order,type='',x_mult=1,
    extra=not magician and 20 or nil,extra_value=0,hands_played_at_create=7,consumeable=S.copy(config)}
  for _,k in ipairs({'mult','h_mult','h_x_mult','h_dollars','p_dollars','t_mult','t_chips',
      'h_size','d_size','bonus','perma_bonus'}) do a[k]=0 end
  -- create_card supplies all three discovery flags plus the selected back's
  -- cosmetic sprite coordinates; copy_card preserves that parameters table.
  return {sort_id=id,config={center=center,card={}},params={bypass_discovery_center=true,
      bypass_discovery_ui=true,discover=false,bypass_back={x=0,y=0}},
    base={nominal=0,suit_nominal=0,face_nominal=0,times_played=0},ability=a,
    facing='front',sprite_facing='front',debuff=false,pinned=false,base_cost=3,cost=is_negative and 8 or 3,
    sell_cost=is_negative and 4 or 1,edition=is_negative and {negative=true,type='negative'} or nil}
end
function M.observe(raw)
  local c=S.card(raw);c.tarot_hold_source=H.capture(raw,{[raw.config.center.key]=raw.config.center});return c
end
function M.joker(key,name,id)
  return {key=key,name=name,id=id or key,ability={set='Joker',name=name},
    cost=4,sell_cost=2,debuff=false,pinned=false,blueprint_compat=true,face_down=false}
end
function M.state()
  local inventory={};for i=1,14 do inventory[i]=M.observe(M.raw(i%2==0 and 'c_hermit' or 'c_magician',i,true)) end
  return {phase='shop',jokers={M.joker('j_perkeo','Perkeo'),M.joker('j_brainstorm','Brainstorm')},
    consumeables=inventory,consumeable_buffer=0,consumable_limit=16,dollars=170,
    ordering_safe=true,jokers_shuffling=false,playing_cards={},used_vouchers={},blind={disabled=true}}
end
return M

local Execution=dofile('Brainstorm/Advisor/execution.lua')
local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function equal(actual,expected,message) check(actual==expected,(message or 'Mismatch')..': '..tostring(actual)..' ~= '..tostring(expected)) end
local function area(n,kind)
  local a={cards={},highlighted={},config={type=kind or 'hand',highlighted_limit=5,card_limit=5},shuffle_amt=0}
  for i=1,n do a.cards[i]={id=i,area=a,ability={},states={drag={can=true}},facing='front'} end
  function a:unhighlight_all()
    for i=#self.highlighted,1,-1 do
      local c=self.highlighted[i]
      if not c.ability.forced_selection then c.highlighted=false;table.remove(self.highlighted,i) end
    end
  end
  function a:add_to_highlighted(c)
    if #self.highlighted<self.config.highlighted_limit then self.highlighted[#self.highlighted+1]=c;c.highlighted=true end
  end
  function a:align_cards() self.aligns=(self.aligns or 0)+1;for i,c in ipairs(self.cards) do c.x=i end end
  function a:set_ranks() self.ranks=(self.ranks or 0)+1;for i,c in ipairs(self.cards) do c.rank=i end end
  return a
end
local function box(elements)
  local b={elements=elements or {}}
  function b:get_UIE_by_ID(id) return self.elements[id] end
  for _,e in pairs(b.elements) do e.UIBox=b end
  return b
end
local function button(callback,reference) return {config={button=callback,ref_table=reference},states={visible=true}} end
local function game(state)
  local g={STATES={},STATE=state or 'SELECTING_HAND',GAME={current_round={hands_left=4,discards_left=3},
    blind={block_play=false},STOP_USE=0,pack_choices=1,blind_on_deck='Small',
    round_resets={blind_states={Small='Select',Big='Upcoming',Boss='Upcoming'},blind_choices={Small='bl_small'}}},
    CONTROLLER={locked=false,locks={}},SETTINGS={},FUNCS={},calls={},hand=area(13),jokers=area(2,'joker'),
    consumeables=area(1,'joker'),shop_jokers=area(1,'shop'),shop_booster=area(1,'shop'),
    shop_vouchers=area(1,'shop'),pack_cards=area(1,'consumeable'),play=area(0,'play')}
  for _,name in ipairs({'SELECTING_HAND','SHOP','BLIND_SELECT','ROUND_EVAL','TAROT_PACK','PLANET_PACK','SPECTRAL_PACK','STANDARD_PACK','BUFFOON_PACK'}) do g.STATES[name]=name end
  local callbacks={'play_cards_from_highlighted','discard_cards_from_highlighted','use_card','sell_card','buy_from_shop',
    'reroll_shop','skip_booster','toggle_shop','cash_out','select_blind','skip_blind'}
  for _,name in ipairs(callbacks) do
    g.FUNCS[name]=function(e)
      local call={name=name,e=e,selected={}}
      for _,c in ipairs(g.hand.highlighted) do call.selected[#call.selected+1]=c.id end
      g.calls[#g.calls+1]=call
    end
  end
  local checks={can_play='play_cards_from_highlighted',can_discard='discard_cards_from_highlighted',
    can_use_consumeable='use_card',can_select_card='use_card',can_sell_card='sell_card',can_buy='buy_from_shop',
    can_buy_and_use='buy_from_shop',can_redeem='use_card',can_open='use_card',can_reroll='reroll_shop',can_skip_booster='skip_booster'}
  for name,callback in pairs(checks) do g.FUNCS[name]=function(e) e.config.button=callback end end
  g.FUNCS.check_for_buy_space=function() return true end
  g.shop=box({next_round_button=button('toggle_shop')})
  g.round_eval=box({cash_out_button=button('cash_out')})
  g.P_BLINDS={bl_small={key='bl_small'}}
  local tagbutton=button('skip_blind');local container={config={ref_table={key='tag_coupon'}},states={visible=true}}
  local b=box({select_blind_button=button('select_blind',g.P_BLINDS.bl_small),
    tag_container=container,tag_Small={children={{},tagbutton}}})
  tagbutton.UIBox=b;g.blind_select_opts={small=b};g.blind_select={}
  g.consumeables.cards[1].ability={name='Justice',consumeable={max_highlighted=1}}
  g.shop_jokers.cards[1].ability={set='Joker'}
  g.shop_vouchers.cards[1].ability={set='Voucher'}
  g.shop_booster.cards[1].ability={set='Booster'}
  g.pack_cards.cards[1].ability={set='Joker'}
  return g
end
local function executed(g,action,callback)
  local ok,reason=Execution.execute(g,action)
  check(ok,reason);equal(#g.calls,1,'Exactly one source callback');equal(g.calls[1].name,callback)
  return g.calls[1]
end
local function rejected(g,action,needle,may_have_started)
  local ok,reason,started=Execution.execute(g,action)
  check(not ok,'Expected action rejection');equal(#g.calls,0,'No action callback on rejection')
  equal(started,not not may_have_started,'Whether an action may have started')
  check(type(reason)=='string' and #reason>0,'Readable rejection reason')
  if needle then check(reason:find(needle,1,true),'Reason does not contain '..needle..': '..reason) end
  return reason
end

do
  local g=game();g.hand:add_to_highlighted(g.hand.cards[2])
  local action={kind='play',area='hand',indices={1,13}}
  local call=executed(g,action,'play_cards_from_highlighted')
  equal(table.concat(call.selected,','),'1,13','Select exact recommendation including expanded-hand index')
  equal(action.indices[2],13,'Input action is unchanged')
  local h=game();executed(h,{kind='discard',indices={3,7}},'discard_cards_from_highlighted')
end
for _,indices in ipairs({{1,1},{0},{14},{1.5},{'1'},{1,2,3,4,5,6},{}}) do
  local g=game();g.hand:add_to_highlighted(g.hand.cards[4])
  rejected(g,{kind='play',indices=indices});equal(g.hand.highlighted[1],g.hand.cards[4],'Bad indices preserve selection')
end
do
  local g=game();rejected(g,{kind='play',indices={[1]=1,[3]=3}},'dense')
  g=game();g.hand:add_to_highlighted(g.hand.cards[4]);g.FUNCS.can_play=function(e) e.config.button=nil end
  rejected(g,{kind='play',indices={13}},'can_play');equal(g.hand.highlighted[1],g.hand.cards[4],'Rejected play restores selection')
  g=game();g.hand:add_to_highlighted(g.hand.cards[4]);g.FUNCS.can_discard=function() error('source check failed') end
  rejected(g,{kind='discard',indices={13}},'source check failed');equal(g.hand.highlighted[1],g.hand.cards[4])
  g=game();g.hand:add_to_highlighted(g.hand.cards[4]);g.FUNCS.can_play=function(e) e.config.button='sell_card' end
  rejected(g,{kind='play',indices={13}},'can_play');equal(g.hand.highlighted[1],g.hand.cards[4],'No callback substitution')
  g=game();g.FUNCS.play_cards_from_highlighted=nil;g.hand:add_to_highlighted(g.hand.cards[4])
  rejected(g,{kind='play',indices={13}},'unavailable');equal(g.hand.highlighted[1],g.hand.cards[4])
end
do
  local g=game();g.hand.cards[2].ability.forced_selection=true;g.hand:add_to_highlighted(g.hand.cards[2])
  rejected(g,{kind='play',indices={13}},'forced');equal(#g.hand.highlighted,1)
  local call=executed(g,{kind='discard',indices={2,13}},'discard_cards_from_highlighted')
  equal(table.concat(call.selected,','),'2,13','Forced selection is not duplicated')
end
do
  local g=game();local c=g.consumeables.cards[1]
  c.check_use=function() return false end
  local call=executed(g,{kind='use',area='consumeables',index=1,targets={13}},'use_card')
  equal(call.e.config.ref_table,c);equal(call.selected[1],13)
  g=game();rejected(g,{kind='use',area='consumeables',index=1},'number')
  g=game();g.consumeables.cards[1].ability={name='Death',consumeable={max_highlighted=2,min_highlighted=2}}
  rejected(g,{kind='use',area='consumeables',index=1,targets={13}},'number')
  g=game();g.consumeables.cards[1].ability={name='Aura',consumeable={}}
  executed(g,{kind='use',area='consumeables',index=1,targets={13}},'use_card')
  g=game();g.consumeables.cards[1].ability={name='The Hermit',consumeable={}}
  g.hand.cards[2].ability.forced_selection=true;g.hand:add_to_highlighted(g.hand.cards[2]);g.hand:add_to_highlighted(g.hand.cards[4])
  local call=executed(g,{kind='use',area='consumeables',index=1},'use_card')
  equal(table.concat(call.selected,','),'2','Untargeted consumable retains only required selection')
  g=game();g.consumeables.cards[1].check_use=function() return true end
  rejected(g,{kind='use',area='consumeables',index=1,targets={13}},'cannot use')
end
do
  local g=game('TAROT_PACK');g.pack_cards.cards[1].ability={name='Medium',consumeable={max_highlighted=1}}
  local c=executed(g,{kind='choose',area='pack_cards',index=1,targets={13}},'use_card')
  equal(c.selected[1],13);equal(c.e.config.ref_table,g.pack_cards.cards[1],'Pack card itself is used')
  g=game('STANDARD_PACK');g.pack_cards.cards[1].ability.set='Enhanced'
  executed(g,{kind='choose',area='pack_cards',index=1},'use_card')
  g=game('BUFFOON_PACK');g.FUNCS.can_select_card=function(e) e.config.button=nil end
  rejected(g,{kind='choose',area='pack_cards',index=1},'can_select_card')
  g=game('BUFFOON_PACK');g.GAME.pack_choices=0
  rejected(g,{kind='choose',area='pack_cards',index=1},'no pack choices')
end
for _,test in ipairs({{'buy','shop_jokers','buy_from_shop'},{'buy','shop_vouchers','use_card'},{'open','shop_booster','use_card'}}) do
  local g=game('SHOP');local call=executed(g,{kind=test[1],area=test[2],index=1},test[3])
  equal(call.e.config.ref_table,g[test[2]].cards[1],'Correct source card reference')
end
do
  local g=game('SHOP');g.FUNCS.check_for_buy_space=function() return false end
  rejected(g,{kind='buy',area='shop_jokers',index=1},'no room')
  g=game('SHOP');g.FUNCS.can_buy=function(e) e.config.button=nil end
  rejected(g,{kind='buy',area='shop_jokers',index=1},'can_buy')
  g=game('SHOP');g.shop_jokers.cards[1].area=g.hand
  rejected(g,{kind='buy',area='shop_jokers',index=1},'no longer')
  g=game('SHOP');rejected(g,{kind='sell',area='shop_jokers',index=1},'invalid card area')
  g=game('SHOP');g.jokers.cards[1].ability.eternal=true
  rejected(g,{kind='sell',area='jokers',index=1},'Eternal')
  g=game('SHOP');executed(g,{kind='sell',area='consumeables',index=1},'sell_card')
  g=game();g.FUNCS.can_sell_card=function(e) e.config.button=nil end
  rejected(g,{kind='sell',area='jokers',index=1},'can_sell_card')
end
do
  local g=game('SHOP');local card=g.shop_jokers.cards[1]
  card.ability={name='The Hermit',consumeable={}}
  local e=button('buy_from_shop',card);e.config.id='buy_and_use';local b=box({buy_and_use=e})
  card.children={buy_and_use_button=b}
  local call=executed(g,{kind='buy_and_use',area='shop_jokers',index=1},'buy_from_shop')
  equal(call.e,e,'Buy-and-use uses the real element');equal(call.e.config.id,'buy_and_use')
end
for _,test in ipairs({{'SHOP','reroll','reroll_shop'},{'SHOP','leave_shop','toggle_shop'},
  {'ROUND_EVAL','cash_out','cash_out'},{'PLANET_PACK','skip_pack','skip_booster'},
  {'BLIND_SELECT','select_blind','select_blind'},{'BLIND_SELECT','skip_blind','skip_blind'}}) do
  local g=game(test[1]);local call=executed(g,{kind=test[2]},test[3])
  if test[2]=='skip_blind' then equal(call.e.UIBox,g.blind_select_opts.small,'Skip reward uses the original UIBox') end
end
do
  local g=game('ROUND_EVAL');g.round_eval.elements.cash_out_button=nil
  rejected(g,{kind='cash_out'},'not ready')
  g=game('BLIND_SELECT');rejected(g,{kind='select_blind',blind='Big'},'current blind')
  g=game('BLIND_SELECT');g.GAME.blind_on_deck='Boss';g.GAME.round_resets.blind_states.Boss='Select'
  rejected(g,{kind='skip_blind',blind='Boss'},'Boss')
  g=game('BLIND_SELECT');g.blind_select_opts.small.elements.tag_container.states.visible=false
  rejected(g,{kind='skip_blind'},'reward')
  g=game('BLIND_SELECT');g.blind_select_opts.small.elements.tag_Small.children[2].config.button=nil
  rejected(g,{kind='skip_blind'},'not ready')
  g=game('SHOP');rejected(g,{kind='play',indices={1}},'different game phase')
  g=game();g.CONTROLLER.locks.use=true;rejected(g,{kind='play',indices={1}},'finish')
  g=game();g.SETTINGS.paused=true;rejected(g,{kind='play',indices={1}},'menu')
  g=game();g.GAME.current_round.hands_left=0;rejected(g,{kind='play',indices={1}},'no hands')
  g=game();rejected(g,{kind='start_new_run'},'Unsupported')
end
do
  local g=game();local first,second=g.jokers.cards[1],g.jokers.cards[2]
  local ok,reason=Execution.execute(g,{kind='reorder_jokers',order={2,1}})
  check(ok,reason);equal(#g.calls,0);equal(g.jokers.cards[1],second);equal(g.jokers.cards[2],first)
  equal(first.rank,2);equal(second.rank,1);equal(g.jokers.aligns,1);equal(g.jokers.ranks,1)
  g=game();g.jokers.cards[1].pinned=true
  rejected(g,{kind='reorder_jokers',order={2,1}},'pinned');equal(g.jokers.cards[1].id,1)
  g=game();g.jokers.cards[1].facing='back';rejected(g,{kind='reorder_jokers',order={2,1}},'Face-down')
  g=game();g.jokers.shuffle_amt=0.5;rejected(g,{kind='reorder_jokers',order={2,1}},'shuffling')
  g=game();rejected(g,{kind='reorder_jokers',order={1,1}},'repeated')
  g=game();g.jokers.align_cards=function(self) self.cards[1],self.cards[2]=self.cards[2],self.cards[1];self.align_cards=function() end end
  rejected(g,{kind='reorder_jokers',order={2,1}},'did not accept',true);equal(g.jokers.cards[1].id,1,'Rejected order restored')
  g=game('TAROT_PACK');local order={};for i=1,13 do order[i]=14-i end
  local first=g.hand.cards[1];check(Execution.execute(g,{kind='reorder_hand',area='hand',order=order}))
  equal(g.hand.cards[13],first);equal(first.rank,13);equal(#g.calls,0)
end
do
  local g=game();g.hand:add_to_highlighted(g.hand.cards[2])
  g.FUNCS.play_cards_from_highlighted=function() error('source action failed after starting') end
  local ok,reason,started=Execution.execute(g,{kind='play',indices={13}})
  equal(started,true,'Source callback error cannot safely retry the same publication')
  check(not ok);check(reason:find('source action failed',1,true));equal(g.hand.highlighted[1],g.hand.cards[13],
    'Never undo selection after a source callback may already have changed game state')
end
do
  local g=game();g.hand:add_to_highlighted(g.hand.cards[2])
  g.hand.add_to_highlighted=function() end
  rejected(g,{kind='play',indices={13}},'complete selection',true)
  equal(#g.hand.highlighted,0,'Failed selection rollback conservatively prevents duplicate retry')
  g=game();g.FUNCS.play_cards_from_highlighted=function() return false end
  rejected(g,{kind='play',indices={13}},'rejected this action',true)
  g=game();g.FUNCS.can_play=function(e) g.hand=nil;e.config.button=nil end
  rejected(g,{kind='play',indices={13}},'can_play',true)
  g=game('ROUND_EVAL');local element=g.round_eval.elements.cash_out_button
  element.config.button=nil
  rejected(g,{kind='cash_out'},'not ready')
  element.config.button='cash_out'
  executed(g,{kind='cash_out'},'cash_out')
end
print('advisor_execution: '..checks..' checks passed')

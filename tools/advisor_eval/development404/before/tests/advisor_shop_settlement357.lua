-- Manufactured asynchronous callback effects only. No game source, RNG, saves,
-- captured states, or live matches execute in this fixture.
local Product=dofile('Brainstorm/Core/auto_run_product.lua')
local Settlement=dofile('Brainstorm/Core/auto_run_settlement.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local checks=0
local function check(value,label) checks=checks+1;assert(value,label) end
local function area() return {cards={}} end
local function card(id,cost,set)
  return {id=id,cost=cost,ability={set=set or 'Joker'},config={center={key=id}}}
end
local function put(where,c) where.cards[#where.cards+1]=c;c.area=where end
local function remove(where,c)
  for i,v in ipairs(where.cards) do if v==c then table.remove(where.cards,i);c.area=nil;return end end
  error('Manufactured card missing')
end
local function harness(dollars)
  local h={events={},calls=0}
  local g={GAME={dollars=dollars or 7,marker=0,used_vouchers={}},SETTINGS={profile=1},PROFILES={[1]={}},
    STATE=1,STATE_COMPLETE=true,STATES={SHOP=1,TAROT_PACK=2,BLIND_SELECT=3},
    CONTROLLER={locks={}},E_MANAGER={queues={base={}}},play=area(),jokers=area(),consumeables=area(),
    shop_jokers=area(),shop_vouchers=area(),shop_booster=area(),deck=area(),pack_cards=area()}
  local B={config={advisor={enabled=true,player_logging=true}}}
  local A={retry_generation=0,display={title='Manufactured shop recommendation'},lines={}}
  A.snapshot={fingerprint=Snapshot.fingerprint,capture=function()
    local s={phase=g.STATE,dollars=g.GAME.dollars,marker=g.GAME.marker,used_vouchers=Snapshot.copy(g.GAME.used_vouchers)}
    for _,name in ipairs({'shop_jokers','shop_vouchers','shop_booster','jokers','consumeables','deck','pack_cards'}) do
      s[name]={};for i,c in ipairs(g[name].cards) do s[name][i]={id=c.id,cost=c.cost} end
    end
    return s
  end}
  A.player_log={enabled=function()return true end,event=function(_,kind,data)
    h.events[#h.events+1]={kind=kind,data=data};return true,#h.events end}
  A.gold_stickers={capture=function()return {} end}
  A.can_execute=function()
    local a=A.result.action
    if a.kind=='buy' or a.kind=='open' then
      local c=g[a.area].cards[a.index]
      return c and (type(c.cost)~='number' or g.GAME.dollars-(g.GAME.bankrupt_at or 0)>=c.cost) or false,'Not affordable.'
    end
    return true
  end
  A.execute=function()
    h.calls=h.calls+1
    h.action=Snapshot.copy(A.result.action)
    if h.on_execute then h.on_execute() end
    return true
  end
  local controller={new=function(cb)
    h.callbacks=cb
    return {status=function()return {} end,engaged=function()return true end}
  end}
  local terminal={attach=function()return {poll=function()end,owned_overlay=function()end,
    in_win_callback=function()return false end,install_hooks=function()end} end}
  h.api=Product.attach(B,{advisor=A,game=function()return g end,controller=controller,terminal=terminal,settlement=Settlement,now=function()return 0 end})
  h.g,h.A=g,A
  function h.publish(action)
    A.result={action=action};A.published_key=A.snapshot.fingerprint(A.snapshot.capture())
    A.published_generation=0
    h.observation=h.callbacks.observe();return h.observation
  end
  function h.dispatch()
    local obs=h.observation
    return h.callbacks.execute(obs.fingerprint,obs.action_token)
  end
  function h.blocking() g.E_MANAGER.queues.base={{blocking=true}} end
  function h.drain() g.E_MANAGER.queues.base={} end
  function h.buy(a) return {kind='buy',area=a or 'shop_jokers',index=1} end
  return h
end

do
  local h=harness(7);local g=h.g
  local first,second,pack=card('first',3,'Tarot'),card('second',4),card('pack',4,'Booster')
  put(g.shop_jokers,first);put(g.shop_jokers,second);put(g.shop_booster,pack)
  h.on_execute=h.blocking
  check(h.publish(h.buy()).ready and h.dispatch(),'first purchase callback accepted once')
  -- The live bug allowed an unrelated state change to acknowledge this request.
  g.GAME.marker=1
  check(not h.publish(h.buy()).ready,'unrelated snapshot change cannot acknowledge queued purchase')
  check(not h.dispatch() and h.calls==1,'execution gate separately prevents duplicate callback')
  remove(g.shop_jokers,first);put(g.consumeables,first)
  check(not h.publish(h.buy()).ready,'transfer alone with old cash cannot dispatch next purchase')
  h.drain()
  check(not h.publish(h.buy()).ready,'missing or nonblocking queued cash still requires actual debit')
  g.GAME.dollars=4
  check(h.publish(h.buy()).ready and h.dispatch() and h.calls==2,'next purchase starts only after first transfer and debit')
  g.GAME.marker=2;h.drain()
  check(not h.publish(h.buy()).ready,'new unrelated change cannot acknowledge second purchase')
  g.GAME.dollars=0
  check(not h.publish(h.buy()).ready,'debit alone cannot repeat still-visible purchased card')
  remove(g.shop_jokers,second);put(g.jokers,second)
  local open={kind='open',area='shop_booster',index=1}
  check(h.publish(open).ready,'both purchase effects permit fresh readiness')
  check(not h.dispatch() and h.calls==2 and g.GAME.dollars==0,'unaffordable pack is rejected; no duplicate debit or overdraft')
end

do
  local h=harness(1);local g=h.g;g.GAME.bankrupt_at=-20
  local c=card('credit-eligible',4);put(g.shop_jokers,c)
  check(h.publish(h.buy()).ready and h.dispatch(),'existing signed borrowing limit still allows legal purchase')
  remove(g.shop_jokers,c);put(g.jokers,c);g.GAME.dollars=-3
  check(h.publish({kind='leave_shop'}).ready,'negative cash settles at legitimate borrowed total')
end

do
  local h=harness(0);local g=h.g;local c=card('free',0,'Planet');put(g.shop_jokers,c)
  check(h.publish(h.buy()).ready and h.dispatch(),'free ordinary Planet purchase accepted')
  check(not h.publish(h.buy()).ready,'zero cost does not bypass physical transfer')
  remove(g.shop_jokers,c);put(g.consumeables,c)
  check(h.publish({kind='sell',area='consumeables',index=1}).ready,'free purchase can settle without cash changing')
end

do
  local h=harness(10);local g=h.g;local c=card('v_test',10,'Voucher');put(g.shop_vouchers,c)
  check(h.publish(h.buy('shop_vouchers')).ready and h.dispatch(),'voucher callback accepted')
  remove(g.shop_vouchers,c);g.GAME.dollars=0
  check(not h.publish({kind='leave_shop'}).ready,'voucher removal and debit do not imply redeemed effect')
  g.GAME.used_vouchers.v_test=true
  check(h.publish({kind='leave_shop'}).ready,'voucher public redemption finishes purchase')
end

do
  local h=harness(4);local g=h.g;local c=card('pack',4,'Booster');put(g.shop_booster,c)
  check(h.publish({kind='open',area='shop_booster',index=1}).ready and h.dispatch(),'pack callback accepted')
  remove(g.shop_booster,c);g.GAME.dollars=0;g.STATE=g.STATES.TAROT_PACK
  check(not h.publish({kind='skip_pack'}).ready,'new pack phase without populated choices is not completion')
  put(g.pack_cards,card('choice',0,'Tarot'))
  check(h.publish({kind='skip_pack'}).ready,'pack cost and actual choices release barrier')
end

do
  local h=harness();local g=h.g
  -- Price and buy-and-use effects need not move the selected card immediately;
  -- vanilla serializes them with blocking base events, unlike visual effects.
  h.blocking()
  check(not h.publish({kind='reroll'}).ready,'shop repricing blocks all automatic shop decisions')
  g.E_MANAGER.queues.base={{blocking=false},{blocking=false,complete=true}}
  check(h.publish({kind='reroll'}).ready,'decorative nonblocking base events do not delay settled shop')
  g.E_MANAGER.queues.base={{complete=true,blocking=true}}
  check(not h.publish({kind='reroll'}).ready,'completed before-event still waits for its queued delay')
  g.E_MANAGER.queues.base={unexpected=true}
  check(not h.publish({kind='reroll'}).ready,'unknown queue shape cannot claim settlement')
  h.drain();g.STATE=g.STATES.BLIND_SELECT;h.blocking()
  check(h.publish({kind='select_blind'}).ready,'no purchase in flight leaves unrelated phase readiness unchanged')
end

do
  local h=harness();local g=h.g;local c=card('interrupted',3);put(g.shop_jokers,c)
  check(h.publish(h.buy()).ready and h.dispatch(),'interrupted purchase accepted')
  check(not h.publish(h.buy()).ready,'interrupted card remains blocked')
  -- Explicit verified checkpoint notification, not ordinary mouse input, clears
  -- receipts from the previous timeline; controller continuation keeps its caps.
  h.api:manual('ordinary input')
  check(not h.publish(h.buy()).ready,'ordinary input cannot clear purchase receipt')
  h.api:manual('restored','checkpoint_loaded')
  check(h.publish(h.buy()).ready,'checkpoint timeline notification clears obsolete receipt')
  check(h.dispatch(),'restored timeline may issue its current eligible action')
  g.GAME={dollars=7,marker=0,used_vouchers={}}
  check(h.publish(h.buy()).ready,'new run identity does not inherit previous purchase receipt')
end

do
  local h=harness();local c=card('unknown-cost',3);put(h.g.shop_jokers,c);c.cost=nil
  h.publish(h.buy())
  check(not h.dispatch() and h.calls==0,'unknown cost is rejected before callback')
end

do
  local h=harness();put(h.g.shop_jokers,card('preflight',3))
  h.A.execute=function()return false,'Manufactured preflight rejection' end
  h.publish(h.buy())
  check(not h.dispatch(),'confirmed preflight failure is rejected')
  check(h.publish(h.buy()).ready,'confirmed preflight failure has no imaginary pending transaction')
  h.A.execute=function()h.A.execution_key='pending';return false,'Manufactured callback rejection after queuing' end
  check(not h.dispatch(),'uncertain callback failure remains rejected')
  h.A.execution_key=nil
  check(not h.publish(h.buy()).ready,'later generic runtime latch release does not clear uncertain purchase receipt')
end
print('advisor shop settlement357: '..checks..' checks passed')

local Settlement=dofile('Brainstorm/Core/auto_run_settlement.lua')
local checks=0
local function check(value,why)checks=checks+1;assert(value,why)end
local function reason(api,g,expected)
  local blocked,why=api:check(g)
  check(blocked==true and why==expected,expected)
end
local function game(area,kind)
  local card={cost=4,config={center_key='v_synthetic'}}
  local g={GAME={dollars=10,used_vouchers={}},STATES={SHOP=1,TAROT_PACK=2,PLANET_PACK=3,
    SPECTRAL_PACK=4,STANDARD_PACK=5,BUFFOON_PACK=6},STATE=1,
    shop_jokers={cards={}},shop_vouchers={cards={}},shop_booster={cards={}},
    jokers={cards={}},consumeables={cards={}},deck={cards={}}}
  g[area].cards[1]=card
  return g,card,{kind=kind or 'buy',area=area,index=1}
end

do
  local s=Settlement.new();local g,card,action=game('shop_jokers')
  check(s:capture(g,{kind='play'})==nil,'nonpurchase actions have no purchase receipt')
  local receipt=s:capture(g,action)
  check(receipt.game==g.GAME and receipt.card==card and receipt.source==g.shop_jokers and
    receipt.expected_dollars==6,'receipt binds exact pre-dispatch game, card, source and debit')
  s:bind(receipt)
  reason(s,g,'Waiting for the purchase cost to settle.')
  g.GAME.dollars=6
  reason(s,g,'Waiting for the purchased card to leave the shop.')
  g.shop_jokers.cards={}
  reason(s,g,'Waiting for the purchased card to enter the owned inventory.')
  g.jokers.cards={card}
  check(s:check(g)==false and s:check(g)==false,'purchase releases only after debit, transfer and ownership settle')
end

do
  local s=Settlement.new();local g,card,action=game('shop_vouchers')
  local receipt=s:capture(g,action);s:bind(receipt)
  g.GAME.dollars=6;g.shop_vouchers.cards={}
  reason(s,g,'Waiting for the voucher to be redeemed.')
  g.GAME.used_vouchers.v_synthetic=true
  check(s:check(g)==false,'redeemed voucher releases its exact receipt')
  card.config={};g.shop_vouchers.cards[1]=card
  check(s:capture(g,action)==false,'voucher without a public key is rejected')
end

do
  local s=Settlement.new();local g,_,action=game('shop_booster','open')
  s:bind(s:capture(g,action));g.GAME.dollars=6;g.shop_booster.cards={}
  reason(s,g,'Waiting for the opened pack to become available.')
  g.STATE=g.STATES.TAROT_PACK;g.pack_cards={cards={}}
  reason(s,g,'Waiting for the opened pack to become available.')
  g.pack_cards.cards={{synthetic=true}}
  check(s:check(g)==false,'open receipt releases only with populated pack')
end

do
  local s=Settlement.new();local g,card,action=game('shop_jokers')
  g.E_MANAGER={queues={base={{blocking=true}}}}
  reason(s,g,'Shop actions are still settling.')
  g.E_MANAGER.queues.base={{blocking=false}}
  check(s:check(g)==false,'nonblocking decorative events do not hold up a settled shop')
  g.E_MANAGER.queues.base={[0]={blocking=false}}
  reason(s,g,'The shop event queue cannot be verified.')
  g.E_MANAGER.queues=nil
  reason(s,g,'Shop event completion is unavailable.')
  g.E_MANAGER=nil
  s:bind(s:capture(g,action))
  g.E_MANAGER={queues={base={{blocking=true}}}}
  reason(s,g,'Shop actions are still settling.')
  g.E_MANAGER.queues.base={}
  reason(s,g,'Waiting for the purchase cost to settle.')
  check(card==g.shop_jokers.cards[1],'queue checks do not mutate live card objects')
end

do
  local s=Settlement.new();local g,_,action=game('shop_jokers')
  local receipt=s:capture(g,action);s:bind(receipt)
  s:release_on_rejection(false,'latched')
  reason(s,g,'Waiting for the purchase cost to settle.')
  s:release_on_rejection(false,nil)
  check(s:check(g)==false,'only confirmed preflight rejection without an execution latch clears receipt')
  s:bind(receipt);s:clear()
  check(s:check(g)==false,'explicit new-run or checkpoint clear discards stale receipt')
  s:bind(receipt);g.GAME={dollars=10}
  check(s:check(g)==false,'game identity replacement clears old transaction')
  local no_card={kind='buy',area='shop_jokers',index=2}
  check(s:capture(g,no_card)==false,'unavailable exact source card is rejected')
end

print('advisor_auto_run_settlement: '..checks..' checks passed')

local base='Brainstorm/Advisor/'
local public=dofile(base..'acorn_public.lua')
local hooks=dofile(base..'acorn_public_hooks.lua')
local belief=dofile(base..'acorn_belief.lua')
local execute=dofile(base..'execution.lua')
local snapshot=dofile(base..'snapshot.lua')
local gold=dofile(base..'gold_stickers.lua')
local checks=0
local function eq(a,b,label)checks=checks+1;assert(a==b,(label or 'check')..': '..tostring(a)..' ~= '..tostring(b))end
local function yes(x,label)eq(not not x,true,label)end
local function localize(args)
  return ({a_chips='+%s Chips',a_mult='+%s Mult',a_xmult='X%s Mult'})[args.key]:format(tostring(args.vars[1]))
end
local colors={CHIPS={0.1,0.2,1,1},MULT={1,0.2,0.1,1},XMULT={1,0.2,0.1,1}}
local function fixture(source_shaped)
  local emitted,raw_reads,vanilla_calls={},0,{}
  local g={GAME={round=7,round_resets={ante=3},current_round={hands_left=4,hands_played=0,discards_left=4,discards_used=0}},
    jokers={cards={},config={card_limit=5}},hand={cards={},highlighted={},config={card_limit=8,highlighted_limit=5}},play={cards={}},C=colors,
    STATES={SELECTING_HAND=1,ROUND_EVAL=2,GAME_OVER=3},STATE=1,STATE_COMPLETE=true,CONTROLLER={locks={},dragging={}},FUNCS={}}
  local function joker(key,a,x)
    a.name=({j_yorick='Yorick',j_blueprint='Blueprint',j_joker='Joker',j_green_joker='Green Joker'})[key]
    local card={facing='front',sprite_facing='front',VT={x=x},T={x=x},states={visible=true},sort_id=x,
      config={center={key=key}},ability=a,blueprint_compat=true}
    card.public_key=key -- fixture construction only, never passed to tracker
    return card
  end
  g.jokers.cards={joker('j_green_joker',{mult=10,extra={hand_add=1,discard_sub=1}},1),
    joker('j_blueprint',{},2),joker('j_joker',{mult=4},3)}
  local fronts={};for _,card in ipairs(g.jokers.cards)do
    fronts[card]={config=card.config,ability=card.ability,public_key=card.public_key,sort_id=card.sort_id}
    if source_shaped then card.pinch={x=false};card.VT.w=1 end
  end
  local env={G=g,Card={},CardArea={},Game={}}
  env.attention_text=function(args)vanilla_calls.text=(vanilla_calls.text or 0)+1;return 'shown',nil,3 end
  env.Card.juice_up=function()vanilla_calls.juice=(vanilla_calls.juice or 0)+1;return 'juice' end
  env.Card.flip=function(card)
    if source_shaped then
      card.flipping=card.facing=='front' and 'f2b' or 'b2f'
      card.facing=card.facing=='front' and 'back' or 'front';card.pinch.x=true
    else card.facing=card.facing=='front' and 'back' or 'front';card.sprite_facing=card.facing end
  end
  -- Manufactured presentation lifecycle matching the preserved Card callbacks:
  -- the sprite changes at zero width, pinch clears, and direction stays set.
  env.Card.update=function(card)
    if card.VT.w<=0 and (card.flipping=='f2b' or card.flipping=='b2f') then
      card.sprite_facing=card.flipping=='f2b' and 'back' or 'front';card.pinch.x=false
    end
  end
  local function settle(card)card.VT.w=0;env.Card.update(card);card.VT.w=1 end
  local function restore_front(card)
    setmetatable(card,nil);for key,value in pairs(fronts[card])do card[key]=value end
  end
  env.Card.drag=function(card)
    if card.destination then
      local from;for i,c in ipairs(g.jokers.cards)do if c==card then from=i end end
      table.insert(g.jokers.cards,card.destination,table.remove(g.jokers.cards,from));card.destination=nil
      for i,c in ipairs(g.jokers.cards)do c.VT.x=i end
    end
  end
  env.CardArea.shuffle=function(area)
    area.cards[1],area.cards[3]=area.cards[3],area.cards[1]
    for i,c in ipairs(area.cards)do c.VT.x=i end
  end
  env.Game.start_run=function()return 'started'end
  env.Game.delete_run=function()return 'deleted'end
  g.FUNCS.play_cards_from_highlighted=function()g.STATE_COMPLETE=false;return 'play' end
  g.FUNCS.discard_cards_from_highlighted=function()g.STATE_COMPLETE=false;return 'discard' end
  g.FUNCS.use_card=function()return true end
  local tracker=public.new({belief=belief,localize=localize,emit=function(event)emitted[#emitted+1]=event end,
    card=function(card)
      assert(card.facing=='front','Hidden identity accessed');raw_reads=raw_reads+1
      return {id='fixture:'..card.sort_id,key=card.config.center.key,ability=card.ability,
        blueprint_compat=card.blueprint_compat,card=card,sort_id=card.sort_id,T=card.T}
    end})
  local installed=hooks.attach(tracker,{env=env,game=function()return g end})
  local function conceal()
    for _,card in ipairs(g.jokers.cards)do env.Card.flip(card)end
    env.CardArea.shuffle(g.jokers)
    if source_shaped then for _,card in ipairs(g.jokers.cards)do settle(card)end end
    installed:update()
    for _,card in ipairs(g.jokers.cards)do
      card.config=nil;card.ability=nil;card.public_key=nil;card.sort_id=nil
      setmetatable(card,{__index=function(_,key)
        if key=='config' or key=='ability' or key=='sort_id' or key=='id' or key=='key' or key=='public_key'then error('Forbidden hidden '..key)end
      end})
    end
  end
  return g,tracker,env,installed,conceal,emitted,function()return raw_reads end,vanilla_calls,
    {settle=settle,restore_front=restore_front}
end
local D=dofile(base..'decision.lua');local Score=dofile(base..'scoring.lua');local Order=dofile(base..'acorn_ordering.lua')
local g,t,env,h,conceal,events,reads=fixture(true);conceal()
local function mult()for _,j in ipairs(t.belief.inventory)do if j.key=='j_green_joker' then return j.ability.mult end end end
local before=reads();g.FUNCS.play_cards_from_highlighted()
env.attention_text({text='+11 Mult',backdrop_colour=colors.MULT,major=g.jokers.cards[3]})
yes(t.belief.supported,'Growth popup retains compatible worlds before completion');eq(mult(),10)
h:update();eq(mult(),10,'Incomplete callback does not advance')
g.GAME.current_round.hands_left=3;g.GAME.current_round.hands_played=1;g.STATE_COMPLETE=true
h:update();eq(mult(),11,'Settled play advances once');h:update();eq(mult(),11,'Duplicate settled observation cannot advance twice')
local s={phase='hand',hands_left=3,discards_left=4,hand_limit=5,chips=0,dollars=20,
 blind={key='bl_final_acorn',name='Amber Acorn',chips=1000000},hands={},consumeables={},modifiers={},probabilities={normal=1},
 hand={{id='p',rank=8,nominal=8,suit='Clubs',ability={}}},jokers={}}
t:capture(g,s);local r=D.run(s,{scoring=Score,acorn_ordering=Order,acorn_belief=belief})
yes(r.action and r.acorn_diagnostics.complete,'Tracker-derived next decision stays executable');eq(reads(),before,'No concealed recapture')
g.hand.highlighted={{},{},{},{},{}};g.FUNCS.discard_cards_from_highlighted()
g.GAME.current_round.discards_left=3;g.GAME.current_round.discards_used=1;g.STATE_COMPLETE=true
h:update();eq(mult(),10,'Full five-card discard decrements once');h:update();eq(mult(),10)
print('advisor_acorn_tracker408: '..checks..' checks passed')

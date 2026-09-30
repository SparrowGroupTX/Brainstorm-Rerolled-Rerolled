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
local function fixture()
  local emitted,raw_reads,vanilla_calls={},0,{}
  local g={GAME={round=7,round_resets={ante=3},current_round={hands_left=4,hands_played=0,discards_left=4,discards_used=0}},
    jokers={cards={},config={card_limit=5}},hand={cards={},highlighted={},config={card_limit=8,highlighted_limit=5}},play={cards={}},C=colors,
    STATES={SELECTING_HAND=1,ROUND_EVAL=2,GAME_OVER=3},STATE=1,STATE_COMPLETE=true,CONTROLLER={locks={},dragging={}},FUNCS={}}
  local function joker(key,a,x)
    a.name=({j_yorick='Yorick',j_blueprint='Blueprint',j_joker='Joker'})[key]
    local card={facing='front',sprite_facing='front',VT={x=x},T={x=x},states={visible=true},sort_id=x,
      config={center={key=key}},ability=a,blueprint_compat=true}
    card.public_key=key -- fixture construction only, never passed to tracker
    return card
  end
  g.jokers.cards={joker('j_yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=3},1),
    joker('j_blueprint',{},2),joker('j_joker',{mult=4},3)}
  local env={G=g,Card={},CardArea={},Game={}}
  env.attention_text=function(args)vanilla_calls.text=(vanilla_calls.text or 0)+1;return 'shown',nil,3 end
  env.Card.juice_up=function()vanilla_calls.juice=(vanilla_calls.juice or 0)+1;return 'juice' end
  env.Card.flip=function(card)card.facing=card.facing=='front' and 'back' or 'front';card.sprite_facing=card.facing end
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
    env.CardArea.shuffle(g.jokers);installed:update()
    for _,card in ipairs(g.jokers.cards)do
      card.config=nil;card.ability=nil;card.public_key=nil;card.sort_id=nil
      setmetatable(card,{__index=function(_,key)
        if key=='config' or key=='ability' or key=='sort_id' or key=='id' or key=='key' or key=='public_key'then error('Forbidden hidden '..key)end
      end})
    end
  end
  return g,tracker,env,installed,conceal,emitted,function()return raw_reads end,vanilla_calls
end
do
  local clean=public.sanitize({id='old',sort_id=5,key='j_joker',ability={mult=4},T={x=7},card={key='hidden'}})
  eq(clean.id,nil,'No pre-hide ID retained');eq(clean.sort_id,nil);eq(clean.T,nil);eq(clean.card,nil);eq(clean.ability.mult,4)
  local n=public.rendered_number('X4 Mult',colors.MULT,colors,localize)
  eq(n.channel,'x_mult');eq(n.amount,4)
  eq(public.rendered_number('+4 Mult',colors.CHIPS,colors,localize),nil,'Wrong visible color cannot qualify')
  eq(public.rendered_number('roughly X4 Mult',colors.MULT,colors,localize),nil,'Exact localized rendering required')
  eq(public.rendered_number('Upgraded!',colors.MULT,colors,localize),nil,'Non-numeric activation stays ambiguous')
  eq(public.rendered_number('Xnan Mult',colors.MULT,colors,localize),nil)
end
do
  local g,t,env,h,conceal,events,reads,calls=fixture()
  h:update();h:update();eq(reads(),0,'Idle frames do not recapture inventory')
  conceal();yes(t.belief.supported);eq(#t.belief.worlds,6,'Every pre-shuffle permutation retained')
  eq(reads(),3,'Read public fronts only once before concealment')
  local initial=t.epoch
  for _,item in ipairs(t.belief.inventory)do eq(item.id,nil);eq(item.sort_id,nil);eq(item.card,nil)end
  env.FUNCS=nil
  g.FUNCS.play_cards_from_highlighted()
  local a,b,c=env.attention_text({text='X4 Mult',backdrop_colour=colors.MULT,major=g.jokers.cards[3]})
  eq(a,'shown');eq(b,nil);eq(c,3,'Vanilla multiple returns preserved')
  eq(calls.text,1);yes(#t.belief.worlds<6,'Visible XMult narrows compatible placements')
  local narrowed=#t.belief.worlds
  env.Card.juice_up(g.jokers.cards[1]);eq(#t.belief.worlds,narrowed,'Juice alone never identifies a card')
  local s={jokers={{key='forbidden1'},{key='forbidden2'},{key='forbidden3'}}}
  t:capture(g,s)
  for _,card in ipairs(s.jokers)do eq(card.key,nil);eq(card.id,nil);yes(card.identity_redacted)end
  yes(s.public_joker_belief.supported);eq(reads(),3,'Hidden capture did not revisit identity')
  h:install();env.attention_text({text='+4 Mult',backdrop_colour=colors.MULT,major=g.jokers.cards[1]})
  eq(calls.text,2,'Idempotent installation retains one original invocation')
  eq(t.event_count,3,'One event per real status/juice call')
  env.CardArea.shuffle(g.jokers);g.STATE_COMPLETE=true;h:update()
  yes(t.epoch>initial);eq(#t.belief.worlds,6,'Repeated shuffle discards all previous slot narrowing')
  eq(t.event_count,0);eq(reads(),3)
end
do
  local g,t,env,h,conceal=fixture();conceal()
  for i=1,5 do g.hand.highlighted[i]={}end
  g.FUNCS.discard_cards_from_highlighted()
  eq(t.belief.inventory[3] and t.belief.supported,true)
  local function yorick()for _,j in ipairs(t.belief.inventory)do if j.key=='j_yorick'then return j.ability end end end
  eq(yorick().x_mult,4,'Discard callback alone does not advance growth')
  g.GAME.current_round.discards_left=3;g.GAME.current_round.discards_used=1;g.STATE_COMPLETE=true
  h:update();eq(yorick().x_mult,5,'Completed public five-card discard advances physical Yorick once')
  eq(yorick().yorick_discards,21);h:update();eq(yorick().yorick_discards,21,'Idle frame cannot apply growth twice')
  env.CardArea.shuffle(g.jokers);h:update();eq(yorick().x_mult,5,'Later shuffle retains derived public ability but forgets position')
  g.FUNCS.play_cards_from_highlighted()
  env.attention_text({text='X5 Mult',backdrop_colour=colors.MULT,major=g.jokers.cards[1]})
  yes(t.belief.supported,'New displayed growth amount uses public transition')
  g.GAME.current_round.hands_left=3;g.GAME.current_round.hands_played=1;g.STATE_COMPLETE=true;h:update()
  local prior=t.event_count
  env.attention_text({text='X5 Mult',backdrop_colour=colors.MULT,major=g.jokers.cards[3]})
  eq(t.event_count,prior,'Idle popups cannot masquerade as played effects')
end
do
  local g,t,env,h,conceal=fixture();conceal();g.FUNCS.play_cards_from_highlighted()
  env.attention_text({text='X4 Mult',backdrop_colour=colors.MULT,major=g.jokers.cards[3]})
  local before=public.copy(t.belief.worlds)
  local card=g.jokers.cards[3];card.destination=1;g.CONTROLLER.dragging.target=card
  env.Card.drag(card);h:update()
  g.CONTROLLER.dragging.target=nil;h:update()
  for k,w in ipairs(t.belief.worlds)do eq(w[1],before[k][3]);eq(w[2],before[k][1]);eq(w[3],before[k][2])end
  local n=t.event_count;g.jokers.cards[1].VT.x=5
  env.attention_text({text='X4 Mult',backdrop_colour=colors.MULT,major=g.jokers.cards[1]})
  eq(t.event_count,n,'Unsettled visual slot order is not inferred from raw row')
end
do
  local g,t,env,h,conceal=fixture();conceal();g.FUNCS.play_cards_from_highlighted()
  env.attention_text({text='X999 Mult',backdrop_colour=colors.MULT,major=g.jokers.cards[1]})
  eq(t.belief.supported,false,'Contradictory qualified display does not guess')
  env.Game.start_run();eq(t.belief,nil,'New-run request expires remembered identities')
  h:update();eq(t.belief.supported,false,'Attaching to concealed state cannot recover hidden inventory')
end
do
  local g,t,env,h,conceal=fixture();conceal()
  g.GAME={round=7,round_resets={ante=3},current_round={}}
  h:update();eq(t.belief.supported,false,'Restored/new game object expires prior memory even at matching public counters')
end
do
  local g,t,env,h,conceal=fixture();conceal();g.FUNCS.use_card()
  eq(t.belief.supported,false,'Unmodelled consumable mutations invalidate hidden values')
  env.CardArea.shuffle(g.jokers);eq(t.belief.supported,false,'Shuffle cannot erase a prior model gap')
end
do
  local g,t,env,h,conceal=fixture();conceal()
  g.CONTROLLER.dragging.target=g.jokers.cards[1];h:update()
  eq(t.belief.supported,false,'A drag with a missed origin cannot reuse old slot knowledge')
end
do
  local g,t,env,h,conceal=fixture();conceal()
  env.attention_text=function()error('vanilla error marker')end;h:install()
  local ok,err=pcall(env.attention_text,{text='X4 Mult',backdrop_colour=colors.MULT,major=g.jokers.cards[3]})
  eq(ok,false);yes(tostring(err):find('vanilla error marker',1,true));eq(t.belief,nil,'Vanilla callback failure clears pending inference')
end
do
  local g,t,env,h,conceal=fixture();conceal();g.FUNCS.play_cards_from_highlighted()
  for i=1,public.MAX_EVENTS do env.Card.juice_up(g.jokers.cards[1])end
  eq(t.event_count,public.MAX_EVENTS);env.Card.juice_up(g.jokers.cards[1])
  eq(t.belief.supported,false,'Observation cap is explicit, never silent evidence truncation')
end
do
  local g,t,env,h,conceal=fixture();conceal();g.FUNCS.play_cards_from_highlighted()
  env.attention_text({text='X4 Mult',backdrop_colour=colors.MULT,major=g.jokers.cards[3]})
  local before=public.copy(t.belief.worlds);local receipt=t:prepare_reorder(g,{3,1,2})
  yes(receipt,'Explicit Product Execute gets one transient public-slot receipt')
  local old=g.jokers.cards;g.jokers.cards={old[3],old[1],old[2]}
  yes(t:finish_reorder(g,receipt,true,true),'Verified direct row movement transports the belief')
  for k,w in ipairs(t.belief.worlds)do eq(w[1],before[k][3]);eq(w[2],before[k][1]);eq(w[3],before[k][2])end
  receipt=t:prepare_reorder(g,{2,1,3});eq(t:finish_reorder(g,receipt,false,false),false)
  yes(t.belief.supported,'Unchanged preflight rejection preserves prior belief')
  receipt=t:prepare_reorder(g,{2,1,3});eq(t:finish_reorder(g,receipt,true,true),false)
  eq(t.belief.supported,false,'Claimed successful movement without matching visible slots invalidates')
end
do
  local g,t,env,h,conceal=fixture();conceal()
  eq(t:prepare_reorder(g,{1,1,3}),nil,'Duplicate slot cannot obtain a receipt')
  local receipt=t:prepare_reorder(g,{2,1,3});env.CardArea.shuffle(g.jokers)
  eq(t:finish_reorder(g,receipt,true,true),false);eq(t.belief.supported,false,'Shuffle between requested/finished movement invalidates receipt')
end
do
  local g,t,env,h,conceal=fixture();conceal()
  for _,card in ipairs(g.jokers.cards)do card.states.drag={can=true}end
  function g.jokers:align_cards()for i,c in ipairs(self.cards)do c.VT.x=i end end
  function g.jokers:set_ranks()end
  execute.public_joker_reorder_check=function(live,proof)return t:authorize_reorder(live,proof)end
  local b=t.belief
  local proof={schema=1,complete=true,complete_order_comparison=true,all_world_clear=true,
    epoch=b.epoch,revision=b.revision,worlds=#b.worlds,bound_kind='public_joker_world_floor'}
  local action={kind='reorder_jokers',order={3,1,2},public_belief=proof}
  local receipt=t:prepare_reorder(g,action.order)
  local accepted,why=execute.execute(g,action);yes(accepted,why)
  yes(t:finish_reorder(g,receipt,accepted,true),'Actual production executor accepts only the public proof gate')
  local ok,_,started=execute.execute(g,action);eq(ok,false);eq(started,false,'Old revision cannot authorize another hidden reorder')
  proof.revision=t.belief.revision;proof.worlds=proof.worlds-1
  eq(execute.execute(g,action),false,'Partial world certificate is rejected')
  proof.worlds=#t.belief.worlds;g.jokers.cards[1].flipping='b2f'
  eq(execute.execute(g,action),false,'Revealing animation cannot bypass the public back-order gate')
  g.jokers.cards[1].flipping=nil;g.jokers.cards[1].sprite_facing='back';g.jokers.cards[1].facing='front'
  local snapshot={jokers={{key='still_hidden'},{},{}}};t:capture(g,snapshot)
  eq(snapshot.jokers[1].key,nil,'Logical facing front does not expose a still-rendered back')
  execute.public_joker_reorder_check=nil
end
do
  local g,t,env,h,conceal=fixture();conceal()
  g.STAGES={RUN=1};g.STAGE=1
  snapshot.certificate={capture=function()error('Certificate must not scan hidden Joker identities')end}
  snapshot.perkeo_inventory={capture=function()error('Copy-source inspection must not see hidden Jokers')end}
  local raw=snapshot.capture(g)
  for _,card in ipairs(raw.jokers)do eq(card.key,nil);eq(card.id,nil);yes(card.identity_redacted)end
  eq(raw.certificate_pool,nil,'Certificate metadata is unavailable during unobserved Joker concealment')
  local goal=gold.capture(g,{enabled=true})
  eq(goal.held_status,'unavailable');eq(#goal.held_keys,0,'Hidden actual keys never fill an unobserved Gold inventory')
  goal=gold.capture(g,{enabled=true,public_held=t:public_held(g)})
  eq(goal.held_status,'complete');eq(table.concat(goal.held_keys,','),'j_blueprint,j_joker,j_yorick')
  eq(goal.held_scope,'remembered_public_unordered_inventory')
  t:invalidate('Unmodelled hidden replacement')
  goal=gold.capture(g,{enabled=true,public_held=t:public_held(g)})
  eq(goal.held_status,'unavailable','Invalidated memory cannot claim current held identity')
end
do
  local g,t,env,h,conceal=fixture();conceal()
  g.FUNCS.play_cards_from_highlighted=function()return false end;h:install()
  eq(g.FUNCS.play_cards_from_highlighted(),false)
  eq(t.belief.supported,false,'Explicitly rejected callback invalidates its pending observation context')
end
do
  local g,t,env,h,conceal=fixture();conceal()
  local target=g.jokers.cards[2];target.VT.x=0;g.CONTROLLER.dragging.target=target
  env.Card.drag(target);eq(t.belief.supported,false,'A visually unsettled origin cannot begin a certified drag')
end
print('advisor_acorn_public: '..checks..' checks passed')

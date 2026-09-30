local Opening=dofile('tools/advisor_eval/development299/drafts/normal_route/normal_opening.lua')
local Snapshot=dofile('Brainstorm/Advisor/snapshot.lua')
local Execution=dofile('Brainstorm/Advisor/execution.lua')
Opening.gold_search=dofile('Brainstorm/Advisor/gold_search.lua')
Opening.gold_stickers=dofile('Brainstorm/Advisor/gold_stickers.lua')
local checks=0
local function check(v,label) checks=checks+1;assert(v,label) end
local function eq(a,b,label) check(a==b,label..': '..tostring(a)..' ~= '..tostring(b)) end
local function copy(v) return Snapshot.copy(v) end
local function area(limit)
  local a={cards={},highlighted={},config={card_limit=limit or 5,highlighted_limit=5}}
  function a:unhighlight_all() self.highlighted={} end
  function a:add_to_highlighted(c) self.highlighted[#self.highlighted+1]=c end
  return a
end
local function card(key,name,set,owner)
  local c={config={center={key=key,name=name,set=set}},ability={name=name,set=set},facing='front',area=owner}
  if set=='Spectral' or set=='Tarot' then c.ability.consumeable={} end
  return c
end
local function game()
  local names=table.concat({'Yorick','Brainstorm','Burnt Joker','Perkeo',''},'\31')
  local locations=table.concat({'soul_pack','by_ante_5','by_ante_5','soul_pack','ante_1'},'\31')
  local f={native_api_version=8,stake_level=8,soul_count=2,required_soul_count=2,joker_targets=names,
    joker_target_locations=locations,no_perishable_jokers=true,deck_name='Red Deck',multi_soul_pack_consumed=false,
    filter_params={'DEMO123','None','None','tag_charm',2,false,1,false,false,false,false,false,'None','','',0,0,names,'Red Deck',locations,8,true}}
  local g={STAGES={RUN=1},STAGE=1,STATES={},STATE='BLIND_SELECT',STATE_COMPLETE=true,SETTINGS={},CONTROLLER={locks={}},FUNCS={},
    GAME={round=0,stake=8,used_filter=true,filter_info=f,pseudorandom={seed='DEMO123'},skips=0,
      selected_back={effect={center={key='b_red'}}},blind_on_deck='Small',
      round_resets={ante=1,blind_states={Small='Select',Big='Upcoming',Boss='Upcoming'},blind_tags={Small='tag_charm'}},
      current_round={},modifiers={},dollars=4,pack_choices=0,joker_buffer=0},
    jokers=area(5),consumeables=area(2),hand=area(8),deck=area(52),pack_cards=area(5),play=area(0),playing_cards={}}
  for _,name in ipairs({'BLIND_SELECT','SELECTING_HAND','TAROT_PACK','SPECTRAL_PACK','PLANET_PACK','STANDARD_PACK','BUFFOON_PACK','SHOP','ROUND_EVAL'}) do g.STATES[name]=name end
  local tagbutton={config={button='skip_blind'},states={visible=true}}
  local box={elements={tag_Small={children={{},tagbutton}},tag_container={config={ref_table={key='tag_charm'}},states={visible=true}}}}
  function box:get_UIE_by_ID(id) return self.elements[id] end
  tagbutton.UIBox=box;g.blind_select_opts={small=box};g.blind_select={}
  return g
end
local function capture(g)
  local s=Snapshot.capture(g)
  -- Root's three-line snapshot integration supplies exactly these two fields.
  s.stake=g.GAME.stake;s.normal_opening=Opening.capture(g)
  return s
end
local function advise(g) return Opening.advice(capture(g)) end
local function enter_pack(g)
  g.STATE='TAROT_PACK';g.GAME.blind_on_deck='Big';g.GAME.round_resets.blind_states.Small='Skipped'
  g.GAME.round_resets.blind_states.Big='Select';g.GAME.skips=1;g.GAME.pack_choices=2
  g.GAME.filter_info.multi_soul_pack_consumed=true;g.pack_cards.brainstorm_normal_opening=true
  g.pack_cards.cards={card('c_soul','The Soul','Spectral',g.pack_cards),card('c_soul','The Soul','Spectral',g.pack_cards),card('c_fool','The Fool','Tarot',g.pack_cards)}
end
math.random=function() error('normal opening touched RNG') end
pseudorandom=function() error('normal opening touched game RNG') end

do
  local g=game();local source=Snapshot.fingerprint(g.GAME.filter_info)
  local s=capture(g);check(s.normal_opening,'complete native receipt is captured')
  eq(s.normal_opening.deck_key,'b_red','actual deck binding')
  eq(s.normal_opening.stake,8,'actual Gold stake binding')
  eq(#s.normal_opening.targets,4,'all four declared targets and their timing are retained')
  eq(s.normal_opening.targets[2].location,'by_ante_5','later deadline is descriptive metadata')
  check(not Snapshot.fingerprint(s.normal_opening):find('DEMO123',1,true),'run seed is omitted from deterministic policy inputs')
  eq(s.normal_opening.search,nil,'search clocks and timings are absent')
  eq(Snapshot.fingerprint(g.GAME.filter_info),source,'capture leaves receipt untouched')
  local action=Opening.advice(s);eq(action.action.kind,'skip_blind','fresh visible Charm route skips only first Small')
  eq(action.action.blind,'Small','actual first blind selected')
  check(not action.normal_opening.future_acquisition_verified,'later targets are not claimed acquired')
  g.FUNCS.skip_blind=function() enter_pack(g) end
  local ok,reason=Execution.execute(g,action.action);check(ok,'existing skip callback accepts real action: '..tostring(reason))
  action=advise(g);eq(action.action.kind,'choose','next fresh action chooses the first visible Soul')
  eq(action.action.index,1,'choose a visible physical pack card')
  local used=0
  g.FUNCS.can_use_consumeable=function(e) e.config.button='use_card' end
  g.FUNCS.use_card=function(e)
    used=used+1
    local key=used==1 and 'j_yorick' or 'j_perkeo'
    g.jokers.cards[#g.jokers.cards+1]=card(key,used==1 and 'Yorick' or 'Perkeo','Joker',g.jokers)
    for i,c in ipairs(g.pack_cards.cards) do if c==e.config.ref_table then table.remove(g.pack_cards.cards,i);break end end
    g.GAME.pack_choices=g.GAME.pack_choices-1
  end
  ok,reason=Execution.execute(g,action.action);check(ok,'existing pack-use callback accepts Soul: '..tostring(reason))
  action=advise(g);eq(action.action.kind,'choose','observed correct first Legendary allows second Soul')
  ok,reason=Execution.execute(g,action.action);check(ok,'second actual callback is accepted: '..tostring(reason))
  eq(used,2,'exactly two fixture use callbacks, no auto generation by the advisor')
  eq(advise(g),nil,'exhausted opening returns to ordinary strategy')
  g.STATE='BLIND_SELECT';eq(advise(g),nil,'Big blind cannot be skipped by opening route')
end

do
  local g=game();local f=g.GAME.filter_info
  f.search={seconds=1,misses=9};local first=Snapshot.fingerprint(capture(g).normal_opening)
  f.search={seconds=500,misses=0};eq(Snapshot.fingerprint(capture(g).normal_opening),first,'search timing cannot seed different policy samples')
  f.filter_params[1]='OLD123';eq(Opening.capture(g),nil,'stale receipt seed rejected')
  g=game();g.GAME.stake=7;eq(Opening.capture(g),nil,'changed stake rejected')
  g=game();g.GAME.selected_back.effect.center.key='b_zodiac';eq(Opening.capture(g),nil,'changed deck rejected')
  g=game();g.GAME.used_filter=false;eq(Opening.capture(g),nil,'ordinary unfiltered run is not hijacked')
  g=game();g.GAME.challenge='c_city_1';eq(Opening.capture(g),nil,'challenge route remains separate')
  for _,position in ipairs({5,18,19,20,21,22}) do
    g=game();g.GAME.filter_info.filter_params[position]='inconsistent';eq(Opening.capture(g),nil,'mismatched repeated native argument '..position)
  end
  for _,value in ipairs({'j_unknown','Yorick\30BAD','Some Future Joker'}) do
    g=game();f=g.GAME.filter_info;f.joker_targets=table.concat({'Yorick','Brainstorm','Burnt Joker',value,''},'\31');f.filter_params[18]=f.joker_targets
    eq(Opening.capture(g),nil,'unknown target or malformed edition '..value)
  end
  g=game();f=g.GAME.filter_info;f.joker_target_locations=f.joker_target_locations:gsub('by_ante_5','after_ante_8');f.filter_params[20]=f.joker_target_locations
  eq(Opening.capture(g),nil,'unimplemented timing is explicit')
  g=game();f=g.GAME.filter_info;f.joker_targets=f.joker_targets:gsub('Perkeo','Yorick');f.filter_params[18]=f.joker_targets
  eq(Opening.capture(g),nil,'duplicate Legendary impossible opening rejected')
  g=game();f=g.GAME.filter_info;f.required_soul_count=3;eq(Opening.capture(g),nil,'three Souls cannot fit two choices')
end

do
  local g=game();g.GAME.round_resets.blind_tags.Small='tag_coupon';eq(advise(g),nil,'a mismatched visible tag is never skipped')
  g=game();g.GAME.round_resets.blind_tags.Small={key='tag_charm'};check(advise(g),'public tag-table encoding is supported')
  for _,change in ipairs({'round','ante','skips','slots','used','pending'}) do
    g=game()
    if change=='round' then g.GAME.round=1 elseif change=='ante' then g.GAME.round_resets.ante=2
    elseif change=='skips' then g.GAME.skips=1 elseif change=='slots' then g.jokers.config.card_limit=1
    elseif change=='used' then g.GAME.filter_info.multi_soul_pack_consumed=true else g.GAME.joker_buffer=1 end
    eq(advise(g),nil,'do not begin route with changed '..change)
  end
  g=game();g.consumeables.cards={card('c_fool','The Fool','Tarot',g.consumeables),card('c_fool','The Fool','Tarot',g.consumeables)}
  check(advise(g),'a full held consumable inventory does not block an immediate pack Soul')
  enter_pack(g);check(advise(g),'full Tarot slots remain unchanged while using a pack Soul')
  g.consumeables.cards[1]=card('c_soul','The Soul','Spectral',g.consumeables);eq(advise(g),nil,'an already owned Soul invalidates the pristine duplicate history')
end

do
  for _,change in ipairs({'unmarked','consumed','slots','choices','hidden','unknown','edition','wrong_pack','later','mismatch','pending','not_soul'}) do
    local g=game();enter_pack(g)
    if change=='unmarked' then g.pack_cards.brainstorm_normal_opening=false
    elseif change=='consumed' then g.GAME.filter_info.multi_soul_pack_consumed=false
    elseif change=='slots' then g.jokers.config.card_limit=0
    elseif change=='choices' then g.GAME.pack_choices=0
    elseif change=='hidden' then for _,c in ipairs(g.pack_cards.cards) do c.facing='back' end
    elseif change=='unknown' then for _,c in ipairs(g.pack_cards.cards) do c.ability.name='Unknown' end
    elseif change=='edition' then for _,c in ipairs(g.pack_cards.cards) do c.edition={negative=true} end
    elseif change=='wrong_pack' then g.STATE='BUFFOON_PACK'
    elseif change=='later' then g.GAME.round=1
    elseif change=='pending' then g.GAME.joker_buffer=1
    elseif change=='not_soul' then g.pack_cards.cards={card('c_fool','The Fool','Tarot',g.pack_cards)}
    else g.GAME.pack_choices=1;g.jokers.cards={card('j_chicot','Chicot','Joker',g.jokers)} end
    eq(advise(g),nil,'pack guard preserves ordinary fallback: '..change)
  end
  local g=game();enter_pack(g);g.GAME.pack_choices=1
  g.jokers.cards={card('j_yorick','Yorick','Joker',g.jokers)};g.jokers.cards[1].ability.perishable=true
  eq(advise(g),nil,'observed Perishable target invalidates requested nonperishable recipe')
end

do
  local g=game();local f=g.GAME.filter_info
  f.normal_opening={schema=1,kind='normal_two_soul_v1',seed='DEMO123',deck_key='b_red',stake=8,required_souls=2,no_perishable_targets=true,
    targets={{key='j_yorick',location='soul_pack'},{key='j_perkeo',location='soul_pack'},
      {key='j_blueprint',location='by_ante_5'},{key='j_burnt',location='by_ante_5'}}}
  check(advise(g),'an explicit seed-bound normal opening recipe is accepted')
  f.normal_opening.seed='DIFFERENT';eq(advise(g),nil,'explicit recipe must also belong to this exact run')
  f.normal_opening.seed='DEMO123';f.normal_opening.targets[3].location='soul_pack';eq(advise(g),nil,'a third explicit starting choice is rejected')
end
print('advisor_normal_opening: '..checks..' checks passed')

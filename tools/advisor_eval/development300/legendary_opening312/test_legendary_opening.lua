local P='tools/advisor_eval/development300/legendary_opening312/'
local path=P
local M=dofile(path..'collection_search_product.lua')
local query=dofile(P..'collection_search.lua')
local gold=dofile('Brainstorm/Advisor/gold_search.lua')
local stickers=dofile('Brainstorm/Advisor/gold_stickers.lua')
local opening=dofile('Brainstorm/Advisor/normal_opening.lua')
opening.gold_stickers=stickers;opening.gold_search=gold
local checks=0
local function check(value,label)checks=checks+1;assert(value,label)end
local function copy(t)if type(t)~='table'then return t end;local out={};for k,v in pairs(t)do out[k]=copy(v)end;return out end
local function env()
  local e={starts=0,deletes=0,searches=0,cancels=0,changed=0,closed=0,input=0,events={},now=0,calls={}}
  e.g={GAME={round=1,pseudorandom={seed='OLD'},selected_back={effect={center={key='b_blue'}}}},
    STAGE=2,STAGES={MAIN_MENU=1,RUN=2},STATE=3,STATES={SELECTING_HAND=3,SHOP=4,BLIND_SELECT=5,ROUND_EVAL=6,GAME_OVER=7},
    STATE_COMPLETE=true,CONTROLLER={locks={},dragging={}},SETTINGS={profile=1},P_CENTERS={
      b_red={key='b_red',set='Back'},b_zodiac={key='b_zodiac',set='Back'}},FUNCS={}}
  e.goal={schema=1,goal='gold_stickers',profile_id=1,metadata_status='complete',catalog_status='complete',stake_status='complete',
    counts={total=150,complete=0,missing=150,unknown=0},by_key={}}
  for _,key in ipairs(stickers.target_keys())do e.goal.by_key[key]={key=key,status='missing'}end
  e.B={collection_search_cursor=100,config={ar_filters={keep='existing'},advisor={enabled=false}},Checkpoints={},
    Advisor={settings_changed=function()e.changed=e.changed+1 end}}
  e.runtime={busy=function()return e.live end,
    start=function(q,seed,token)
      e.calls[#e.calls+1]=copy(q)
      e.searches=e.searches+1;e.live=true;e.B.native_search_busy=true
      e.request=copy(q);e.seed=seed;e.token=token;e.generation=e.searches
      if e.start_error then return nil,'start error'end
      return e.generation
    end,
    poll=function(token)
      e.last_poll_token=token
      if e.ready then local r=e.ready;e.ready=nil;e.live=false;e.B.native_search_busy=false;return r end
    end,
    stop=function(reason)e.cancels=e.cancels+1;e.cancel_reason=reason;return true end}
  e.api=M.attach(e.B,{game=function()return e.g end,runtime=e.runtime,query=query,gold=gold,stickers=stickers,
    progress=function()return e.goal end,input_token=function()return e.input end,
    now=function()return e.now end,pending=function()return e.pending end,
    exit_overlay=function()e.closed=e.closed+1;if not e.delay_close then e.g.OVERLAY_MENU=nil;e.g.SETTINGS.paused=false end end,
    back=function(center)return {effect={center=center}}end,
    delete_run=function(g)e.deletes=e.deletes+1;if e.delete_error then error('delete error')end end,
    start_run=function(g,args)
      e.starts=e.starts+1;e.start_args=copy(args)
      if e.start_error_game then error('start error')end
      g.GAME={selected_back=g.GAME.selected_back,pseudorandom={seed=args.seed},round=0,stake=args.stake}
    end,on_event=function(kind,data)e.events[#e.events+1]={kind=kind,data=data}end})
  function e.finish(status,seed)
    e.ready={generation=e.generation,status=status or 'found',profile_id=e.request.profile_id,profile_token=e.token,
      request=copy(e.request),result={schema=1,status=status or 'found',seed=seed or M.seed_at(200),screened=50,
        exact_candidates=1,seconds=.01,budget_ms=e.request.budget_ms,threads=2,route=e.request.route},starts_run=false}
  end
  function e.begin(options,owner)
    local r=assert(e.api.prepare(options));assert(e.api.begin(r,owner or 'owner'));return r
  end
  function e.found(options,owner)
    local r=e.begin(options,owner);e.finish();return assert(e.api.poll(owner or 'owner')).found,r
  end
  function e.complete(key)
    e.goal.by_key[key].status='complete';e.goal.counts.missing=e.goal.counts.missing-1;e.goal.counts.complete=e.goal.counts.complete+1
  end
  return e
end

local names={j_caino='Canio',j_chicot='Chicot',j_triboulet='Triboulet'}
local function only(e,keys)
 local keep={};for _,key in ipairs(keys)do keep[key]=true end
 for _,key in ipairs(stickers.target_keys())do if not keep[key]then e.complete(key)end end
end
local function has(q,name)
 for part in (q.missing_names..'\31'):gmatch('([^\31]*)\31')do if part==name then return true end end
 return false
end
local opts={quota_mode='auto',legendary_fallback=true,burnt_fallback=true}
for key,name in pairs(names)do
 local e=env();only(e,{key})
 local q=assert(query.prepare(e.goal,gold,opts))
 check(q.primary_legendary_key==key and q.primary_legendary_name==name and q.opening_adapted,'actual missing Legendary replaces completed Yorick: '..name)
 check(q.minimum_distinct==1 and q.supported_missing_count==1 and q.missing_names==name,'only declared starting Legendary counts: '..name)
 check(q.target_jokers==name..'\31Brainstorm\31Burnt Joker\31Perkeo\31'and q.first_ante==1,'native two-Soul target string matches alternate recipe')
 check(q.reject_perishable_targets and q.souls==2 and q.tag=='Charm Tag'and q.stake_level==8,'same acquisition/search constraints retained')
 check(not query.prepare(e.goal,gold,{quota_mode='auto'}),'manual automatic quota does not silently change opening')
 check(not query.prepare(e.goal,gold,{quota_mode='auto',legendary_fallback=false}),'explicit alternate-opening opt-out honored')
 check(not query.prepare(e.goal,gold,{quota_mode='auto',legendary_fallback=true,first_ante=2}),'later window cannot count starting Legendary')
 local strict=assert(query.prepare(e.goal,gold,{quota_mode='strict',legendary_fallback=true,minimum_distinct=0}))
 check(strict.primary_legendary_key=='j_yorick'and not strict.opening_adapted and strict.supported_missing_count==0,'strict Off remains original preset')
 check(not query.prepare(e.goal,gold,{quota_mode='strict',legendary_fallback=true,minimum_distinct=1}),'strict positive count never rewritten')
 local before=copy(e.goal)
 local request=e.begin(opts)
 check(e.api.status:find(name..' + Perkeo',1,true),'UI status announces actual alternate pair')
 check(request.query.budget_ms==27000 and e.request.budget_ms==9000,'same30s outer/27s native split')
 e.now=1;e.finish('not_found','');local pending=e.api.poll('owner')
 check(not pending.exited and e.searches==2 and e.request.budget_ms==18000,'one bounded request may relax Burnt')
 check(e.request.target_jokers==name..'\31Brainstorm\31\31Perkeo\31'and e.request.primary_legendary_key==key,'relaxing Burnt preserves actual missing Legendary')
 check(e.api.status:find(name..' + Perkeo',1,true)and e.api.status:find('without required Burnt',1,true),'relaxed status preserves both decisions')
 e.now=2;e.finish();local done=e.api.poll('owner')
 check(done.exited and done.found.receipt.total_native_reserved_ms==27000,'unchanged cumulative native ceiling')
 check(e.api.launch(done.found,'owner'),'owned alternate match launches once through injected callbacks')
 local f=e.g.GAME.filter_info
 check(f.joker_targets==name..'\31Brainstorm\31\31Perkeo\31'and f.filter_params[18]==f.joker_targets,'native launch receipt is actual alternate query')
 check(f.normal_opening.targets[1].key==key and f.normal_opening.targets[3].key=='j_perkeo','explicit recipe cannot falsely claim Yorick')
 check(f.collection_search.primary_legendary_key==key and f.collection_search.opening_adapted and not f.collection_search.future_acquisition_verified,'separate collection provenance records alternate/unverified acquisition')
 local route=assert(opening.capture(e.g))
 check(route.legendary_targets[1]==key and route.legendary_targets[2]=='j_perkeo','real normal parser binds the exact requested pair')
 check(not e.api.launch(done.found,'owner')and e.starts==1,'alternate result is one-use')
 check(e.goal.counts.missing==before.counts.missing and e.goal.by_key[key].status=='missing','search and start do not award a Gold sticker')
 local s={normal_opening=route,deck_key='b_red',stake=8,round=0,ante=1,joker_limit=5,jokers={},consumeables={},
  phase='blind',blind_on_deck='Small',blind_states={Small='Select'},skips=0,skip_tags={Small='tag_charm'}}
 local a=opening.advice(s)
 check(a and a.action.kind=='skip_blind','actual visible Charm first skip is still recommended for alternate')
 s.phase='pack';s.normal_opening.pack_marked=true;s.normal_opening.multi_soul_pack_consumed=true
 s.skips=1;s.blind_on_deck='Big';s.blind_states.Small='Skipped';s.pack_type='TAROT_PACK';s.pack_choices=1
 s.jokers={{key=key,ability={}}};s.pack_cards={{key='c_soul',ability={name='The Soul',set='Spectral',consumeable={}}}}
 check(opening.advice(s).action.kind=='choose','second visible Soul requires correctly acquired first alternate')
 for _,field in ipairs({'debuff','unknown','face_down'})do
  s.jokers[1][field]=true;check(not opening.advice(s),'inactive or concealed acquired target blocks second Soul: '..field);s.jokers[1][field]=nil
 end
 for _,field in ipairs({'perishable','perma_debuff'})do
  s.jokers[1].ability[field]=true;check(not opening.advice(s),'invalid acquired target blocks second Soul: '..field);s.jokers[1].ability[field]=nil
 end
 s.jokers[1].key='j_yorick';check(not opening.advice(s),'wrong first Legendary cannot be treated as the searched target')
end
for _,keys in ipairs({{'j_joker','j_caino'},{'j_yorick','j_chicot'},{'j_perkeo','j_triboulet'}})do
 local e=env();only(e,keys);local q=assert(query.prepare(e.goal,gold,opts))
 check(q.primary_legendary_key=='j_yorick'and not q.opening_adapted,'reachable fixed-route progress keeps the strong original opening')
 check(not has(q,'Canio')and not has(q,'Chicot')and not has(q,'Triboulet'),'unrequested Legendaries never count')
end
do
 local e=env();only(e,{'j_triboulet','j_chicot','j_caino','j_glass'})
 for _,key in ipairs({'j_caino','j_chicot','j_triboulet'})do
  local q=assert(query.prepare(e.goal,gold,opts))
  check(q.primary_legendary_key==key and q.supported_missing_count==1,'fresh missing population picks deterministic next opening: '..key)
  check(q.missing_names==names[key],'only one actual declared Legendary is quota eligible')
  e.complete(key)
 end
 local q,why=query.prepare(e.goal,gold,opts)
 check(not q and why:find('no reachable missing Jokers',1,true),'remaining enhancement prerequisite still stops explicitly')
end
for _,key in ipairs({'j_stone','j_steel_joker','j_glass','j_ticket','j_lucky_cat','j_cavendish'})do
 local e=env();only(e,{key});local q,why=query.prepare(e.goal,gold,opts);check(not q,'new route does not invent prerequisite eligibility: '..key)
 local choices=assert(gold.choices(e.goal));check(why:find(choices[1].reason,1,true),'stop gives the specific in-run prerequisite without awarding hypothetical offers: '..key)
end
for _,v in ipairs({'yes',1,{}})do
 local e=env();check(not query.prepare(e.goal,gold,{legendary_fallback=v}),'invalid alternate-opening permission rejected')
end
do
 local e=env();only(e,{'j_caino'});e.goal.by_key.j_caino.status='unknown';e.goal.counts.missing=0;e.goal.counts.unknown=1
 check(not e.api.prepare(opts),'unknown population still blocks before search')
end
do
 local e=env();only(e,{'j_caino'});local r=e.begin(opts);e.complete('j_caino');e.finish()
 local done=e.api.poll('owner');check(not done.found and e.starts==0,'changed Gold population rejects late alternate match')
end
do
 local e=env();only(e,{'j_caino'});e.begin(opts);e.api.cancel('owner','manual stop');e.finish()
 local done=e.api.poll('owner');check(not done.found and e.starts==0,'cancelled alternate match cannot launch')
end
do
 local e=env();only(e,{'j_caino'});local r=assert(e.api.prepare(opts));r.query.primary_legendary_key='j_chicot'
 check(not e.api.begin(r,'owner')and e.searches==0,'modified alternate metadata rejected before worker')
end
print('Legendary alternate opening: '..checks..' checks; synthetic workers and callbacks only')

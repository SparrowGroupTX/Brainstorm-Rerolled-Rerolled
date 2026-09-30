local path='Brainstorm/Advisor/'
local B=dofile(path..'acorn_belief.lua')
local O=dofile(path..'acorn_ordering.lua')
local S=dofile('Brainstorm/Advisor/scoring.lua')
local checks=0
local function check(x,m) checks=checks+1;assert(x,m) end
local function eq(a,b,m) check(a==b,(m or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function j(key,name,a) a=a or {};a.name=name;return {key=key,ability=a,blueprint_compat=true} end
local function flat() return j('j_joker','Joker',{mult=4}) end
local function cav() return j('j_cavendish','Cavendish',{extra={Xmult=3}}) end
local function copyjoker() return j('j_blueprint','Blueprint',{}) end
local function start(row) return assert(B.start(row,'e',{public_before_shuffle=true})) end
local function event(slot,channel,amount) return {epoch='e',slot=slot,channel=channel,amount=amount,type='rendered_status',phase='play',qualified_render=true,text='public'} end
local function at(b,w,slot) return b.inventory[w[slot]].key end
do
  local a,b=flat(),cav();a.id='SECRET:1';b.id='SECRET:2';a.T={x=99};a.sort_id=5
  local belief=start({a,b});eq(#belief.worlds,2,'complete initial worlds')
  for _,card in ipairs(belief.inventory) do check(card.id==nil and card.sort_id==nil and card.T==nil,'physical joins stripped') end
  local inferred,info=B.observe(belief,event(1,'x_mult',3))
  eq(#belief.worlds,2,'input belief unchanged');eq(#inferred.worlds,1,'distinct numeric signature narrows')
  eq(at(inferred,inferred.worlds[1],1),'j_cavendish','inference identifies visible slot')
  check(info.filtered,'inference receipt')
  local moved=B.reorder(inferred,{2,1},'e');eq(at(moved,moved.worlds[1],2),'j_cavendish','public reorder transports belief')
  eq(B.reorder(inferred,{1,1},'e'),nil,'duplicate slot order rejected')
  eq(B.reorder(inferred,{2,1},'other'),nil,'stale epoch rejected')
  local ignored=B.observe(belief,{epoch='e',slot=1,type='activation'});eq(#ignored.worlds,2,'juice does not identify')
  ignored=B.observe(belief,event(1,'x_mult',3));check(ignored~=belief,'observations detached')
  local contradiction=B.observe(inferred,event(1,'x_mult',99));check(not contradiction.supported,'contradiction remains explicit')
end
do
  local belief=start({cav(),cav()});eq(#belief.worlds,1,'identical public payloads exchangeable')
  local b=start({flat(),cav(),copyjoker()});local inferred=B.observe(b,event(1,'x_mult',3))
  local sources={};for _,w in ipairs(inferred.worlds) do sources[at(inferred,w,1)]=true end
  check(sources.j_cavendish and sources.j_blueprint,'copy activation does not falsely identify original')
  check(#inferred.worlds>1,'copied signatures preserve ambiguity')
  local unknown=j('j_unmodeled','Unknown',{});local u=start({unknown,cav()});local observed=B.observe(u,event(1,'x_mult',3))
  eq(#observed.worlds,2,'unsupported card remains wildcard')
  local foil=flat();foil.edition={polychrome=true};local e=start({foil,cav()});local r=B.observe(e,event(1,'x_mult',1.5))
  eq(at(r,r.worlds[1],1),'j_joker','own edition signature retained')
end
do
  local y=j('j_yorick','Yorick',{x_mult=3,yorick_discards=2,extra={discards=23,xmult=1}})
  local b=start({y,copyjoker(),flat()});local advanced=B.advance_public(b,{epoch='e',kind='discard',discarded_count=5,observed_complete=true})
  for _,v in ipairs(advanced.inventory) do if v.key=='j_yorick' then eq(v.ability.x_mult,4,'physical Yorick grows once');eq(v.ability.yorick_discards,20,'public discard counter exact') end end
  local invalid=B.advance_public(advanced,{epoch='e',kind='use',observed_complete=true});check(not invalid.state_valid,'unqualified ability changes invalidate values')
  local worlds=B.observe(invalid,event(1,'x_mult',99));check(#worlds.worlds>0,'invalid dynamic value is wildcard')
  eq(B.advance_public(b,{epoch='e',kind='discard',discarded_count=5}),nil,'unobserved intended action never advances')
end
local function state()
  return {phase='hand',hand={{rank=14,suit='Spades',nominal=11,enhancement='c_base',ability={}}},
    jokers=setmetatable({},{__index=function() error('raw concealed row inspected') end}),
    hands={},deck={},playing_cards={},hands_left=1,discards_left=0,hand_limit=5,chips=0,dollars=10,
    consumeables={},blind={key='bl_final_acorn',name='Amber Acorn',chips=200},modifiers={},probabilities={normal=1}}
end
do
  local s=state();local b=start({cav(),flat()});b=B.observe(b,event(1,'x_mult',3))
  local action,calls,diag=O.suggest(s,b,S,B)
  check(action~=nil,'complete public inference permits saving reorder')
  eq(action.kind,'reorder_jokers','first action reorder');eq(table.concat(action.action.order,','),'2,1','slot-only order')
  eq(action.minimum_score,240,'production score from public belief');eq(calls,2,'all worlds and orders counted');check(diag.complete,'complete evidence')
  local moved=B.reorder(b,{2,1},'e');local play=O.suggest(s,moved,S,B)
  eq(play.kind,'play','after actual reorder a common play is selected');eq(play.action.indices[1],1,'fixed public subset')
  local ambiguous=start({cav(),flat()});local none,n,why=O.suggest(s,ambiguous,S,B)
  eq(none.kind,'play','different winning reorder per hidden world forbidden');eq(n,4,'same complete order/play family')
  check(not none.immediate_clear_all_worlds,'immediate scoring choice does not claim a clear')
  local cap,capped,cd=O.suggest(s,b,S,B,{max_evaluations=0});eq(cap,nil,'cap refuses whole family');eq(capped,0,'no partial family started');check(not cd.complete,'cap explicit')
  s.consumeables={j('c_pluto','Pluto')};check(O.suggest(s,b,S,B)~=nil,'held consumables remain in actual state without consuming them')
  s.consumeables={};s.hand[1].face_down=true;eq(O.suggest(s,b,S,B),nil,'hidden playing cards decline')
  s.hand[1].face_down=false;local bad={score=function() return {score=500,uncertain=true} end}
  eq(O.suggest(s,b,bad,B),nil,'uncertain scorer cannot certify order')
  local warned={score=function() return {score=500,warnings={'unknown'}} end}
  eq(O.suggest(s,b,warned,B),nil,'warnings cannot certify order')
  s.hand[1].ability.forced_selection=true;local forced=O.suggest(s,b,S,B);check(forced~=nil,'forced selection retained')
end
do
  local s=state();s.hands_left=4;s.discards_left=3;s.blind.chips=1000
  local b=start({cav(),flat()})
  local action,calls,diag=O.suggest(s,b,S,B,{max_evaluations=2})
  eq(action.kind,'play','initial ambiguous row has a supported observation-producing action')
  eq(calls,2,'ordinary common-world family fits shared cap')
  check(diag.complete and not diag.order_complete,'order cap leaves completed ordinary evidence')
  eq(s.discards_left,3,'remaining discards untouched');eq(s.hands_left,4,'remaining hands untouched in planning')
  s.used_vouchers={v_observatory=true};s.consumeables={{key='c_pluto',ability={name='Pluto',set='Planet',consumeable={hand_type='High Card'}}}}
  local boosted=O.suggest(s,b,S,B,{max_evaluations=2})
  check(boosted~=nil,'Observatory held inventory is scored')
  eq(boosted.minimum_score,action.minimum_score*1.5,'held Planet multiplier carried in every world')
  eq(#s.consumeables,1,'inventory unchanged')
  s.hand[1].enhancement='m_bonus';s.hand[1].ability.bonus=30
  local bonus=O.suggest(s,b,S,B,{max_evaluations=2});check(bonus and bonus.minimum_score>boosted.minimum_score,'deterministic Bonus card supported')
  s.hand[1].seal='Red';check(O.suggest(s,b,S,B,{max_evaluations=2})~=nil,'exact Red retrigger supported')
  s.hand[1].seal='Blue';eq(O.suggest(s,b,S,B),nil,'uncompared Blue reward scope remains explicit')
  s.hand[1].seal=nil;s.hand[1].enhancement='m_glass';eq(O.suggest(s,b,S,B),nil,'Glass exposure not silently dropped')
  s.hand[1].enhancement='c_base';s.used_vouchers={};s.consumeables={}
  local guard=O.suggest(s,b,S,B,{max_evaluations=2,public_incumbent={supported=true,action={kind='discard'}}})
  eq(guard,nil,'non-clearing information play cannot override supported public discard')
end
do
  local s=state();local poison=setmetatable({},{__index=function() error('hidden payload accessed') end})
  s.jokers={poison,poison};local b=start({cav(),flat()})
  local wrapped={score=function(projected,indices)
    check(projected.jokers~=s.jokers and projected.jokers[1]~=poison,'scorer never receives concealed objects')
    for _,card in ipairs(projected.jokers) do check(card.id:sub(1,14)=='public-belief:','only synthetic public identifiers enter scorer') end
    return S.score(projected,indices)
  end}
  check(O.suggest(s,b,wrapped,B)~=nil,'poisoned nested hidden payload never inspected')
  s.blind={key='bl_psychic',name='The Psychic',chips=200}
  eq(O.suggest(s,b,S,B),nil,'five-card boss legality enforced in all worlds')
end
do
  local b=start({cav(),flat(),j('j_egg','Egg',{})});b=B.observe(b,event(1,'x_mult',3))
  eq(#b.worlds,2,'two unobserved identities remain ambiguous')
  local action,n,diag=O.suggest(state(),b,S,B)
  check(action and action.kind=='reorder_jokers','a common order can work without identifying every Joker')
  eq(action.action.order[3],1,'known XMult slot goes last in every world')
  eq(n,12,'complete ambiguous family cost is exact');check(diag.complete,'complete ambiguous evidence')
  for _,profile in ipairs(diag.profiles) do eq(#profile,1,'every order has same public hand family') end
end
do
  local a,b=flat(),cav();b.edition={type='unqualified_edition'}
  local belief=start({a,b});local inferred=B.observe(belief,event(1,'mult',4))
  eq(#inferred.worlds,2,'unknown edition cannot exclude a world')
  local stale=event(1,'mult',4);stale.epoch='old';inferred=B.observe(belief,stale)
  eq(#inferred.worlds,2,'old epoch observations ignored')
  eq(B.start({flat()},'e',{public_before_shuffle=true,max_worlds=0}),nil,'invalid world cap rejected')
end
check(B.start({flat()},'e')==nil,'explicit public pre-shuffle capture required')
do local concealed=flat();concealed.face_down=true;eq(B.start({concealed},'e',{public_before_shuffle=true}),nil,'hidden payload cannot initialize public belief')end
do
  local y=j('j_yorick','Yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=10})
  local row={j('j_fortune_teller','Fortune Teller',{extra=1}),j('j_swashbuckler','Swashbuckler',{}),
    copyjoker(),y,j('j_scary_face','Scary Face',{extra=30})}
  local b=start(row);eq(#b.worlds,120,'complete five-Joker initial family')
  local nextb=B.advance_public(b,{epoch='e',kind='play',observed_complete=true});check(nextb.state_valid,'known stable scoring row survives ordinary play')
  nextb=B.advance_public(nextb,{epoch='e',kind='discard',discarded_count=5,observed_complete=true});check(nextb.state_valid,'same row supports exact public discard growth')
  local observed=B.observe(nextb,event(1,'x_mult',4));check(#observed.worlds<120,'known channel restrictions narrow while additive amounts remain unknown')
  local last=B.advance_public(nextb,{epoch='e',kind='use',observed_complete=true});check(not last.state_valid,'Tarot-dependent mutation cannot silently preserve old state')
end
do
  local y=j('j_yorick','Yorick',{x_mult=3.333333,extra={discards=23,xmult=1},yorick_discards=3})
  local b=start({y,flat()});local e=event(1,'x_mult',3.33);e.text='X3.33'
  local rounded=B.observe(b,e,{render=function(channel,n)return 'X'..string.format('%.2f',n)end})
  eq(#rounded.worlds,1,'visible rounded number matched by renderer, not inferred exact scalar')
  eq(at(rounded,rounded.worlds[1],1),'j_yorick','rounding cannot falsely exclude genuine compatible identity')
  local gap=B.observe(b,e,{render=function()error('unavailable')end})
  eq(#gap.worlds,1,'unavailable renderer retains possible same-channel Joker')
end
check(B.start({flat(),cav(),copyjoker()},'e',{public_before_shuffle=true,max_worlds=5})==nil,'cannot sample initial worlds')
do
  local D=dofile(path..'decision.lua')
  local s=state();s.jokers={setmetatable({face_down=true},{__index=function(_,key)error('raw hidden field '..key)end})}
  local b=start({cav(),flat()});s.public_joker_belief=b
  local function forbidden()error('raw ordinary decision path entered')end
  local modules={acorn_belief=B,acorn_ordering=O,scoring=S,
    search={run=forbidden},concealed_belief={run=forbidden},score_cache={new=forbidden},
    phase_copy={apply=forbidden},retry_policy={apply=forbidden},strategy={advise=forbidden},
    consumables={suggest=forbidden},ordering={suggest=forbidden}}
  local fingerprint=dofile('Brainstorm/Advisor/snapshot.lua').fingerprint
  local unchanged=fingerprint(s)
  local r=D.run(s,modules,nil,{search={max_evaluations=2}})
  eq(fingerprint(s),unchanged,'entire supplied snapshot unchanged by detached decision')
  eq(r.action.kind,'play','decision supplies complete initial public information action')
  eq(r.evaluations,2,'dispatcher counts actual score calls')
  eq(r.bound_kind,'public_joker_world_floor','bound type explicit')
  check(r.play.uncertain and not r.deterministic_exact and r.conservative,'world floor never presented as deterministic exact score')
  check(r.public_information_fallback,'non-clearing play clearly scoped as fallback')
  eq(#s.public_joker_belief.worlds,2,'public belief input unchanged')
  s.public_joker_belief=B.observe(b,event(1,'x_mult',3))
  r=D.run(s,modules);eq(r.action.kind,'reorder_jokers','certified public reorder through entry point')
  check(r.action.public_belief.complete_order_comparison and r.action.public_belief.all_world_clear,'executor proof requires complete all-world clear')
  eq(r.action.public_belief.epoch,'e','reorder proof has current epoch')
  local capped=D.run(s,modules,nil,{acorn_belief={max_evaluations=0}})
  eq(capped.kind,'unsupported','zero score allowance stays explicit');eq(capped.action,nil,'no raw fallback at cap')
  local retry=D.run(s,modules,nil,{retry={active=true,reloads_used=5}})
  eq(retry.action,nil,'retry protection survives early public interception');eq(retry.retry.reloads_used,5,'persistent count retained')
  s.public_joker_belief=nil;local missing=D.run(s,modules)
  eq(missing.action,nil,'missing public belief never resolves raw row');eq(missing.evaluations,0,'no hidden-row scores')
  s.phase='shop';local shop=D.run(s,modules)
  eq(shop.kind,'unsupported','nonhand hidden phase intercepted before shop scoring')
end
do
  -- Manufactured fresh-copy reference: current complete production planner,
  -- with a separate scoring input per call. No historical implementation reads.
  local old={suggest=function(s,b,scorer,belief,options)
    return O.suggest(s,b,{score=function(projected,indices)
      return scorer.score(belief.copy(projected),indices)
    end},belief,options)
  end}
  local s=state();s.blind.chips=100000;s.hands_left=4;s.discards_left=3;s.hand={}
  for rank=4,7 do s.hand[#s.hand+1]={rank=rank,nominal=rank,suit='Spades',enhancement='c_base',ability={}} end
  local row={j('j_fortune_teller','Fortune Teller',{extra=1}),j('j_swashbuckler','Swashbuckler',{}),
    copyjoker(),j('j_yorick','Yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=10}),j('j_scary_face','Scary Face',{extra=30})}
  for _,v in ipairs(row)do v.sell_cost=2 end
  local b=start(row);local fingerprint=dofile('Brainstorm/Advisor/snapshot.lua').fingerprint
  local old_seen,old_count={},0
  local old_scorer={score=function(projected,indices)
    if not old_seen[projected] then old_seen[projected]=true;old_count=old_count+1 end
    return S.score(projected,indices)
  end}
  local baseline,basecalls,basediag=old.suggest(s,b,old_scorer,B)
  local seen,count,pure={},0,true
  local wrapped={score=function(projected,indices)
    if not seen[projected] then seen[projected]=true;count=count+1 end
    local before=fingerprint(projected);local scored=S.score(projected,indices)
    pure=pure and fingerprint(projected)==before;return scored
  end}
  local actual,calls,diag=O.suggest(s,b,wrapped,B)
  eq(fingerprint(actual),fingerprint(baseline),'reuse preserves exact selected action and bounds')
  eq(calls,basecalls,'reuse preserves every scoring call');eq(calls,1800,'all120worlds and15subsets remain')
  eq(fingerprint(diag.profiles),fingerprint(basediag.profiles),'every world score and profile preserved exactly')
  check(pure,'production scorer leaves every reused state unchanged')
  eq(count,120,'same world state reused for all subsets');eq(diag.projected_state_allocations,120,'allocation diagnostic exact')
  eq(old_count,1800,'baseline observed state allocation count');eq(old_count/count,15,'measured allocation reduction matches subset count')
end
do
  local s=state();s.blind.chips=100000;s.hand={};s.hands_left=4;s.discards_left=3
  for rank=2,10 do s.hand[#s.hand+1]={rank=rank,nominal=rank,suit='Spades',enhancement='c_base',ability={}} end
  local b=start({flat(),cav()});local action,calls,diag=O.suggest(s,b,S,B)
  check(action~=nil,'nine visible cards admitted when full family fits')
  eq(diag.subsets,381,'all one-to-five-card subsets of nine cards covered')
  eq(calls,1524,'both orders and both worlds complete')
  local none,n,cd=O.suggest(s,b,S,B,{max_evaluations=761})
  eq(none,nil,'nine-card family declines inadequate shared allowance');eq(n,0,'no partial nine-card comparison')
  s.hand[9].ability.forced_selection=true;local forced=O.suggest(s,b,S,B);local found=false
  for _,index in ipairs(forced.action.indices)do found=found or index==9 end;check(found,'ninth forced card remains mandatory')
end
print('advisor_acorn_belief: '..checks..' checks passed')

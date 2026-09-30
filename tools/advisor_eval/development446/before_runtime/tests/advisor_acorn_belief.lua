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
  local y=j('j_yorick','Yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=10})
  local b=start({j('j_banner','Banner',{effect='Discard Chips',extra=30}),
    j('j_odd_todd','Odd Todd',{effect='Odd Card Buff',extra=31}),copyjoker(),
    j('j_perkeo','Perkeo',{}),y,flat()})
  b=B.advance_public(b,{epoch='e',kind='play',observed_complete=true})
  local s=state();s.hands_left=3;s.discards_left=3;s.blind.chips=400000
  local choice,calls,diag=O.suggest(s,b,S,B,{max_evaluations=720})
  check(choice and choice.kind=='play','six-Joker public row still yields bounded advice after a completed play')
  eq(calls,720,'ordinary play compares every six-Joker world')
  check(diag.complete,'post-play public comparison remains complete')
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
  s.hand[1].seal='Blue';check(O.suggest(s,b,S,B)~=nil,'Blue immediate score supported without a future reward forecast')
  s.hand[1].seal=nil;s.hand[1].enhancement='m_glass';check(O.suggest(s,b,S,B)~=nil,'Glass immediate scoring is supported; future destruction is not projected')
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
  -- Publicly captured base-game fields are stable through a completed play or
  -- discard, but these effects do not give a safe hidden-slot popup signature.
  local opaque={
    j('j_raised_fist','Raised Fist',{effect='Socialized Mult'}),
    j('j_card_sharp','Card Sharp',{extra={Xmult=3}}),
    j('j_banner','Banner',{effect='Discard Chips',extra=30}),
    j('j_odd_todd','Odd Todd',{effect='Odd Card Buff',extra=31}),
  }
  local y=j('j_yorick','Yorick',{x_mult=4,extra={discards=23,xmult=1},yorick_discards=10})
  local five=start({y,copyjoker(),opaque[1],flat(),cav()})
  eq(#five.worlds,120,'complete five-Joker row before public play')
  local after=B.advance_public(five,{epoch='e',kind='play',observed_complete=true})
  check(after.state_valid and #after.worlds==120,'Raised Fist keeps complete public order belief after play')
  local six=start({y,copyjoker(),opaque[3],opaque[4],opaque[2],flat()})
  eq(#six.worlds,720,'complete six-Joker row before public play')
  after=B.advance_public(six,{epoch='e',kind='play',observed_complete=true})
  check(after.state_valid and #after.worlds==720,'Banner, Odd Todd and Card Sharp keep complete belief after play')
  after=B.advance_public(after,{epoch='e',kind='discard',discarded_count=5,observed_complete=true})
  check(after.state_valid and #after.worlds==720,'qualified opaque row survives public discard without dropping worlds')
  for _,card in ipairs(after.inventory) do if card.key=='j_yorick' then
    eq(card.ability.x_mult,4,'one physical discard transition, no copy multiplier')
    eq(card.ability.yorick_discards,5,'five discarded cards counted once')
  end end
  for _,card in ipairs(opaque) do
    local two=start({card,flat()});local narrowed=B.observe(two,event(1,'x_mult',99))
    eq(#narrowed.worlds,1,'opaque popup cannot exclude the base-game card')
    eq(at(narrowed,narrowed.worlds[1],1),card.key,'opaque identity remains possible in visible slot')
  end
  local changed=j('j_banner','Banner',{effect='Discard Chips',extra=31})
  local invalid=B.advance_public(start({changed,flat()}),{epoch='e',kind='play',observed_complete=true})
  check(not invalid.state_valid,'changed ability shape still stops unsupported hidden transitions')
  changed=j('j_banner','Banner',{effect='Discard Chips',extra=30,unqualified_counter=1})
  invalid=B.advance_public(start({changed,flat()}),{epoch='e',kind='play',observed_complete=true})
  check(not invalid.state_valid,'unexpected top-level ability state cannot silently carry through play')
  local unknown=B.advance_public(start({j('j_unmodeled','Unknown',{}),flat()}),
    {epoch='e',kind='play',observed_complete=true})
  check(not unknown.state_valid,'unmodeled Joker still stops hidden-value continuation')
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
  local row={j('j_perkeo','Perkeo',{}),
    j('j_yorick','Yorick',{x_mult=5,yorick_discards=11,extra={discards=23,xmult=1}}),
    j('j_arrowhead','Arrowhead',{effect='',extra=50}),
    j('j_red_card','Red Card',{extra=3,mult=6,eternal=true}),
    j('j_brainstorm','Brainstorm',{effect='Copycat'})}
  local b=start(row);eq(#b.worlds,120,'five distinct public effects retain every slot world')
  local played=B.advance_public(b,{epoch='e',kind='play',observed_complete=true})
  check(played.state_valid,'fixed Arrowhead and booster-only Red Card remain qualified after play')
  eq(#played.worlds,120,'post-play carries every world without guessing a slot')
  local observed=B.observe(played,event(3,'chips',50))
  local arrow_possible=false
  for _,world in ipairs(observed.worlds) do arrow_possible=arrow_possible or at(observed,world,3)=='j_arrowhead' end
  check(arrow_possible and #observed.worlds>0,'opaque Arrowhead status never excludes its true public slot')
  local discarded=B.advance_public(played,{epoch='e',kind='discard',discarded_count=5,observed_complete=true})
  check(discarded.state_valid,'same row remains qualified after a public discard')
  local x;for _,card in ipairs(discarded.inventory) do if card.key=='j_yorick' then x=card.ability.x_mult end end
  eq(x,5,'physical Yorick counter remains exact without phantom copy growth')
  local changed=j('j_arrowhead','Arrowhead',{effect='',extra=51})
  check(not B.advance_public(start({changed,flat()}),{epoch='e',kind='play',observed_complete=true}).state_valid,
    'modified Arrowhead is outside exact source shape')
  changed=j('j_red_card','Red Card',{extra=3,mult=3,unknown_counter=1})
  check(not B.advance_public(start({changed,flat()}),{epoch='e',kind='play',observed_complete=true}).state_valid,
    'unknown Red Card state remains unsupported')
  local used=B.advance_public(b,{epoch='e',kind='use',observed_complete=true})
  check(not used.state_valid,'booster/use transitions are never certified as play')
end
do
  -- Independently manufactured rows exercise the public ability classes that
  -- previously invalidated otherwise complete Amber Acorn beliefs after play.
  local opaque={
    j('j_mystic_summit','Mystic Summit',{effect='No Discard Mult',extra={mult=15,d_remaining=0}}),
    j('j_popcorn','Popcorn',{mult=8,extra=4}),
    j('j_blue_joker','Blue Joker',{extra=2}),
    j('j_golden','Golden Joker',{effect='Bonus dollars',extra=4}),
  }
  opaque[1].ability.eternal=true;opaque[2].ability.rental=true
  opaque[3].ability.eternal=true;opaque[3].edition={type='foil',foil=true,chips=50}
  opaque[4].ability.eternal=true;opaque[4].edition={type='foil',foil=true,chips=50}
  opaque[4].blueprint_compat=false
  local y=j('j_yorick','Yorick',{x_mult=7,yorick_discards=22,extra={discards=23,xmult=1}})
  local six=start({j('j_perkeo','Perkeo',{}),y,copyjoker(),opaque[1],opaque[2],flat()})
  eq(#six.worlds,720,'all synthetic six-Joker Acorn orders begin possible')
  local after=B.advance_public(six,{epoch='e',kind='play',observed_complete=true})
  check(after.state_valid and #after.worlds==720,'Mystic Summit and Popcorn preserve all worlds after play')
  after=B.advance_public(after,{epoch='e',kind='discard',discarded_count=5,observed_complete=true})
  check(after.state_valid and #after.worlds==720,'conditional Mult and end-round decay do not mutate on discard')
  local s=state();s.hands_left=3;s.discards_left=2;s.blind.chips=400000
  local action,calls,diag=O.suggest(s,after,S,B,{max_evaluations=720})
  check(action and action.kind=='play' and diag.complete and calls==720,
    'post-play six-Joker public row retains a complete bounded scoring comparison')
  local five=start({j('j_perkeo','Perkeo',{}),y,opaque[3],opaque[4],flat()})
  eq(#five.worlds,120,'all synthetic five-Joker Acorn orders begin possible')
  after=B.advance_public(five,{epoch='e',kind='play',observed_complete=true})
  check(after.state_valid and #after.worlds==120,'Blue Joker and Golden Joker preserve all worlds after play')
  after=B.advance_public(after,{epoch='e',kind='discard',discarded_count=5,observed_complete=true})
  check(after.state_valid and #after.worlds==120,'public deck count and end-round payout do not stale ability values')
  action,calls,diag=O.suggest(s,after,S,B,{max_evaluations=120})
  check(action and action.kind=='play' and diag.complete and calls==120,
    'post-play five-Joker public row retains a complete bounded scoring comparison')
  local public=state();public.jokers={opaque[1]};public.discards_left=1
  local before_summit=S.score(public,{1}).score
  public.discards_left=0
  check(S.score(public,{1}).score>before_summit,
    'Mystic Summit condition reads fresh public discards, not retained ability state')
  public.jokers={opaque[3]};public.deck={{rank=2,suit='Hearts',enhancement='c_base',ability={}}}
  local before_draw=S.score(public,{1}).score
  public.deck={}
  check(before_draw>S.score(public,{1}).score,
    'Blue Joker reads fresh public deck size after a draw')
  for _,card in ipairs(opaque) do
    local two=start({card,flat()})
    local inferred=B.observe(two,event(1,'x_mult',99))
    eq(#inferred.worlds,1,'opaque activation never rules out a possible public identity')
    eq(at(inferred,inferred.worlds[1],1),card.key,'opaque identity remains possible in that slot')
    check(not B.advance_public(two,{epoch='e',kind='cash_out',observed_complete=true}).state_valid,
      'round settlement still invalidates captured abilities')
    local mutated=B.copy(card);mutated.ability.unsupported_counter=1
    check(not B.advance_public(start({mutated,flat()}),{epoch='e',kind='play',observed_complete=true}).state_valid,
      'unexpected ability field is never certified')
  end
  local mutated=B.copy(opaque[1]);mutated.ability.extra.unknown=1
  check(not B.advance_public(start({mutated,flat()}),{epoch='e',kind='play',observed_complete=true}).state_valid,
    'Mystic Summit extra fields must match the exact public source shape')
  mutated=B.copy(opaque[2]);mutated.ability.extra=5
  check(not B.advance_public(start({mutated,flat()}),{epoch='e',kind='play',observed_complete=true}).state_valid,
    'nonstandard Popcorn decay remains outside the transition')
  mutated=B.copy(opaque[3]);mutated.ability.extra=3
  check(not B.advance_public(start({mutated,flat()}),{epoch='e',kind='play',observed_complete=true}).state_valid,
    'nonstandard Blue Joker scaling remains outside the transition')
  mutated=B.copy(opaque[4]);mutated.ability.extra=5
  check(not B.advance_public(start({mutated,flat()}),{epoch='e',kind='play',observed_complete=true}).state_valid,
    'nonstandard Golden Joker payout remains outside the transition')
end
do
  -- Bull reads fresh public cash; Scholar has a fixed Ace effect. Neither
  -- changes its captured ability on a completed play or discard.
  local bull=j('j_bull','Bull',{extra=2})
  local scholar=j('j_scholar','Scholar',{effect='Ace Buff',extra={chips=20,mult=4}})
  local row=start({bull,scholar,cav(),copyjoker(),flat()})
  eq(#row.worlds,120,'independent five-Joker Bull/Scholar row keeps all orders')
  local after=B.advance_public(row,{epoch='e',kind='play',observed_complete=true})
  check(after.state_valid and #after.worlds==120,'Bull and Scholar remain qualified after public play')
  after=B.advance_public(after,{epoch='e',kind='discard',discarded_count=4,observed_complete=true})
  check(after.state_valid and #after.worlds==120,'same fixed abilities survive an observed public discard')
  local s=state();s.hand[2]={rank=13,suit='Hearts',nominal=10,enhancement='c_base',ability={}}
  s.hands_left=3;s.discards_left=2;s.dollars=17;s.blind.chips=500000
  local advised,calls,diag=O.suggest(s,after,S,B,{max_evaluations=1200})
  check(advised and advised.kind=='play' and diag.complete and calls==360,
    'post-play advice compares every public row for all three legal hands')
  local known=state();known.jokers={bull,scholar};known.blind.chips=500000
  known.dollars=7;local low=S.score(known,{1})
  known.dollars=17;local high=S.score(known,{1})
  check(high.score>low.score and not high.uncertain,'Bull reads fresh public cash, not retained cash')
  known.hand[1].rank=13;known.hand[1].nominal=10
  local no_ace=S.score(known,{1})
  check(high.score>no_ace.score,'Scholar uses the fresh selected Ace rather than a retained activation')
  local observed=B.observe(after,event(1,'x_mult',99))
  check(#observed.worlds>0,'opaque Bull and Scholar cannot falsely eliminate every public row')
  local altered=B.copy(bull);altered.ability.extra=3
  check(not B.advance_public(start({altered,flat()}),{epoch='e',kind='play',observed_complete=true}).state_valid,
    'modified Bull coefficient remains outside qualified scope')
  altered=B.copy(scholar);altered.ability.extra.mult=5
  check(not B.advance_public(start({altered,flat()}),{epoch='e',kind='play',observed_complete=true}).state_valid,
    'modified Scholar coefficient remains outside qualified scope')
  altered=B.copy(scholar);altered.ability.extra.custom=1
  check(not B.advance_public(start({altered,flat()}),{epoch='e',kind='play',observed_complete=true}).state_valid,
    'unknown Scholar state remains unsupported')
  check(not B.advance_public(row,{epoch='e',kind='use',observed_complete=true}).state_valid,
    'other public actions still invalidate the captured row')
end
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

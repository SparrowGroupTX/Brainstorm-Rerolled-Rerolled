-- Detached, narrow evaluation adapter. No game callbacks or private features.
local M={}
-- Caller injects exact frozen reporting code; no filesystem or runner here.
local function evidence()return assert(M.evidence,"Evidence module required")end
local function copy(x)if type(x)~='table'then return x end;local r={};for k,v in pairs(x)do r[k]=copy(v)end;return r end
local function n(x,d)return type(x)=='number'and x or d or 0 end
local function integer(x)return type(x)=='number'and x==x and x%1==0 and math.abs(x)<1e9 end
local function dense(x,size)
 if type(x)~='table'or #x~=size then return false end
 local seen={};for _,i in ipairs(x)do if not integer(i)or i<1 or i>size or seen[i]then return false end;seen[i]=true end;return true
end
function M.canonical(s)
 local b=s.blind or{};local concealed=not b.disabled and
  (b.key=='bl_final_acorn'or b.name=='Amber Acorn')and type(s.public_joker_belief)=='table'
 local r={};for k,v in pairs(s)do if k~='jokers'or not concealed then r[k]=copy(v)end end
 if concealed then
  -- Preserve the observable slot count without traversing any concealed
  -- payload. The runner separately rejects a stale inventory/count mismatch.
  r.jokers={};for i=1,(type(s.jokers)=='table'and #s.jokers or 0)do r.jokers[i]={face_down=true,identity_redacted=true}end
 end
 for _,area in ipairs({'deck','playing_cards'})do
  local seen={};for _,c in ipairs(r[area]or{})do
   assert(type(c.id)=='string'and c.id~=''and not seen[c.id],'Missing/duplicate public card ID');seen[c.id]=true
   assert(not(c.unknown or c.identity_redacted or c.identity_unknown),'Unknown public composition')
  end
  table.sort(r[area]or{},function(a,b)return a.id<b.id end)
 end
 return r
end
function M.legal(s,a)
 if type(a)~='table'then return false end
 if a.kind~='discard'and a.kind~='play'then return false end
 local ix=a.indices;local used={}
 if type(ix)~='table'or #ix<1 or #ix>math.min(5,n(s.hand_limit,5))then return false end
 for _,i in ipairs(ix)do if not integer(i)or not s.hand[i]or used[i]then return false end;used[i]=true end
 for i,c in ipairs(s.hand)do if (c.ability or{}).forced_selection and not used[i]then return false end end
 return (a.kind=='discard'and n(s.discards_left)or n(s.hands_left))>0
end
local function decide(A,s)
 local before=A.snapshot.fingerprint(s);local r=A.decision.run(s,A,nil,nil)
 assert(A.snapshot.fingerprint(s)==before,'Policy input mutation')
 assert(n(r.evaluations)<=140000,'Ordinary cap exceeded');return r
end
local function summary(A,r)
 return {action=copy(r.action),evaluations=r.evaluations,title=r.title,
  discard_before_clear=r.discard_before_clear,yorick_review=A.player_journal.compact_yorick_review(r),
  resource_comparison=copy(r.resource_comparison),search_diagnostics=copy(r.search_diagnostics),
  play=r.play and {score=r.play.score,hand=r.play.hand,uncertain=r.play.uncertain},warnings=r.warnings}
end
function M.admission(A,s)
 s=M.canonical(s);local r=decide(A,s);local best
 local direct=r.action and r.action.kind=='discard'and #(r.action.indices or{})==5 and M.legal(s,r.action)
 if direct then best={indices=copy(r.action.indices)}
 elseif r.discard_comparison_complete then
  local last=n(s.hands_left)==1
  for _,c in ipairs(r.discard_alternatives or{})do
   if #c.indices==5 and n(c.count)>=4 and M.legal(s,{kind='discard',indices=c.indices})then
    local prefer=not best or last and c.probability~=best.probability and c.probability>best.probability or
     (not last or c.probability==best.probability)and (c.value>best.value or c.value==best.value and table.concat(c.indices,',')<table.concat(best.indices,','))
    if prefer then best=c end
   end
  end
 end
 local five=best and {kind='discard',area='hand',indices=copy(best.indices)}
 if five then local after=A.scoring.after_discard(s,five.indices);if not after then five=nil end end
 return {status='complete',admitted=five~=nil and r.action~=nil,default=copy(r.action),five=five,
  default_ids=r.action and M.card_ids(s,r.action),five_ids=five and M.card_ids(s,five),
  reason=direct and 'already_full_five' or five and 'complete_existing_family' or 'no_complete_legal_five',
  initial_fingerprint=A.snapshot.fingerprint(s),diagnostic=summary(A,r),
  alternatives_complete=r.discard_comparison_complete,alternatives=copy(r.discard_alternatives)}
end
function M.card_ids(s,a)
 local out={};for _,i in ipairs(a.indices or{})do out[#out+1]=s.hand[i]and s.hand[i].id or 'invalid' end;return out
end
local function pack_endpoint(A,s,key)
 assert(s.phase=='pack'and s.pack_type=='BUFFOON_PACK'and s.pack_choices==1,'Unsupported pack contract')
 assert(#s.jokers==2 and #(s.consumeables or{})==0 and next(s.active_tags or{})==nil,'Unsupported shop-closure effects')
 local known={j_yorick=true,j_perkeo=true};local present={}
 for _,j in ipairs(s.jokers)do
  assert(known[j.key]and not present[j.key]and not j.debuff and not j.face_down,'Unsupported startup row');present[j.key]=true
  assert(not(j.ability or{}).perishable,'Perishable startup outside scope')
 end
 assert(key=='j_sly'or key=='j_trio','Unsupported pack intervention')
 local offer
 for _,j in ipairs(s.pack_cards)do if j.key==key then offer=j end end
 assert(offer and not offer.debuff and not offer.edition and not offer.face_down,'Canonical offer required')
 local a=offer.ability or{}
 assert(not(a.rental or a.eternal or a.perishable or a.perma_debuff),'Sticker startup outside scope')
 assert((key=='j_sly'and a.name=='Sly Joker'and a.type=='Pair'and a.t_chips==50)or
  (key=='j_trio'and a.name=='The Trio'and a.type=='Three of a Kind'and a.x_mult==3),'Modified offer outside scope')
 assert(#s.jokers<n(s.joker_limit,5),'Free Joker capacity required')
 local after=copy(A.strategy.shop_sequence_api.after_joker_purchase(s,copy(offer)))
 assert(after.dollars==s.dollars and #after.jokers==#s.jokers+1,'Free pack acquisition/capacity conservation')
 return after
end
function M.pack_start(A,s,key)
 local out=pack_endpoint(A,M.canonical(s),key);local b=out.next_blind
 assert(b and b.key=='bl_goad'and b.boss and b.chips>0 and (b.debuff or{}).suit=='Spades','Only public Goad startup qualified')
 assert(out.teacher_profile=='perkeo_yorick_win_v1','Teacher context required')
 local allowed={enable_eternals_in_shop=true,enable_perishables_in_shop=true,enable_rentals_in_shop=true,no_blind_reward=true,scaling=true}
 for k,v in pairs(out.modifiers or{})do assert(allowed[k]or v==false or v==0,'Unsupported startup modifier '..k)end
 local bonus=out.round_bonus or{};local reset=out.round_resets or{}
 assert(integer(reset.hands)and integer(reset.discards)and n(bonus.next_hands)==0 and n(bonus.discards)==0,'Exact reset resources required')
 out.phase='hand';out.state=nil;out.chips=0;out.round=n(out.round)+1;out.hands_played=0;out.discards_used=0
 out.hands_left=reset.hands;out.discards_left=reset.discards
 out.current_round=copy(out.current_round or{})
 for k,v in pairs({hands_left=out.hands_left,discards_left=out.discards_left,hands_played=0,discards_used=0,round_dollars=0})do out.current_round[k]=v end
 out.last_hand_played=nil;out.pack_cards={};out.pack_choices=nil;out.pack_kind=nil;out.pack_type=nil;out.opening_pack=false
 out.shop_jokers={};out.shop_vouchers={};out.shop_booster={};out.hand={};out.deck={}
 out.blind_on_deck='Boss';out.blind_states=copy(out.blind_states or{});out.blind_states.Boss='Current'
 out.round_resets.blind=copy(b);out.round_resets.blind_states=copy(out.blind_states)
 for _,h in pairs(out.hands or{})do h.played_this_round=0 end
 for _,c in ipairs(out.playing_cards)do
  c.face_down=false;c.debuff=not not(c.ability or{}).perma_debuff;c.vampired=nil
  c.ability=c.ability or{};c.ability.forced_selection=nil;c.ability.wheel_flipped=nil
 end
 A.shop_scoring.apply_blind(out,b,false,false)
 for i,c in ipairs(out.playing_cards)do out.deck[i]=copy(c)end
 out.next_blind=nil;out.next_blind_chips=nil
 return M.canonical(out)
end
local function resources(s)
 local row={dollars=s.dollars,hand_size=s.hand_size,hands_left=s.hands_left,discards_left=s.discards_left,
  population=#(s.playing_cards or{}),deck_remaining=#(s.deck or{}),held={},jokers={},hands={},consumables={}}
 for _,c in ipairs(s.hand or{})do row.held[#row.held+1]={id=c.id,rank=c.rank,suit=c.suit,seal=c.seal,
  enhancement=c.enhancement,edition=copy(c.edition),debuff=c.debuff}end
 for _,j in ipairs(s.jokers or{})do row.jokers[#row.jokers+1]={id=j.id,key=j.key,ability=copy(j.ability),debuff=j.debuff}end
 for k,h in pairs(s.hands or{})do row.hands[k]={level=h.level,chips=h.chips,mult=h.mult,played=h.played}end
 for _,c in ipairs(s.consumeables or{})do row.consumables[#row.consumables+1]={id=c.id,key=c.key,edition=copy(c.edition)}end
 if s.public_joker_belief then row.public_joker_inventory=copy(s.public_joker_belief.inventory)end
 return row
end
function M.refill(A,s,remaining,seed,step,sorting)
 local pool={};for _,c in ipairs(s.deck or{})do assert(c.id and not pool[c.id],'Duplicate draw identity');pool[c.id]=c end
 local ordered={};for _,id in ipairs(remaining)do if pool[id]then ordered[#ordered+1]=pool[id];pool[id]=nil end end
 if next(pool)then return nil,'New unregistered draw identity' end
 local b=s.blind or {};local bell_roll
 if not b.disabled and (b.key=='bl_final_bell'or b.name=='Cerulean Bell')then
  local count=#(s.hand or{})+math.min(#ordered,math.max(0,n(s.hand_size,8)-#(s.hand or{})))
  if count>0 then bell_roll=math.floor(A.sampled_outcomes.roll(seed,step,'bell',0)*count)end
 end
 local next_state,why=A.sampled_outcomes.fill(s,ordered,A.scoring,A.draws,seed,step,bell_roll)
 if not next_state then return nil,tostring(why)end
 local next_ids={};for _,c in ipairs(next_state.deck)do next_ids[#next_ids+1]=c.id end
 local suits={Spades=4,Hearts=3,Clubs=2,Diamonds=1}
 table.sort(next_state.hand,function(a,b)
  local ar,br=n(a.rank),n(b.rank);local as,bs=suits[a.suit]or 0,suits[b.suit]or 0
  if sorting=='suit'then if as~=bs then return as>bs end;if ar~=br then return ar>br end
  else if ar~=br then return ar>br end;if as~=bs then return as>bs end end
  return a.id<b.id
 end)
 return M.canonical(next_state),next_ids
end
local function reorder(s,a)
 local area=a.kind=='reorder_hand'and 'hand'or 'jokers';local old=s[area]
 if not dense(a.order,#old)then return nil,'Malformed reorder'end
 local out=copy(s);out[area]={}
 for i,k in ipairs(a.order)do if (old[k].pinned or(old[k].ability or{}).pinned)and i~=k then return nil,'Pinned reorder'end;out[area][i]=copy(old[k])end
 return out
end
function M.run(A,input)
 local s=M.canonical(input.snapshot);local before=A.snapshot.fingerprint(s)
 local function finish(r)assert(A.snapshot.fingerprint(M.canonical(input.snapshot))==before,'Input mutation');r.input_unchanged=true;r.case=input.case;r.role=input.role;r.full_run=false;return r end
 if input.mode=='admission'then return finish(M.admission(A,s))end
 if input.mode=='pack_diagnostic'then
  local sly,trio=pack_endpoint(A,s,'j_sly'),pack_endpoint(A,s,'j_trio')
  local ctx=A.shop_scoring.new(s,A.scoring,nil,{max_evaluations=50000});local e=ctx:compare(sly,trio)
  return finish({status=e and 'complete'or 'unsupported',comparison=e,reason=ctx.unavailable_reason,
   evaluations=ctx.evaluations,truncated=ctx.truncated,cash={sly=sly.dollars,trio=trio.dollars}})
 end
 assert(input.mode=='continuation','Unknown mode')
 assert(integer(input.action_cap)and input.action_cap>=1 and input.action_cap<=16,'Invalid bounded action cap')
 local remaining=copy(input.world_order);local steps={};local row={status='action_cap',world=input.world,steps=steps,
  discards=0,cards_discarded=0,five_card_discards=0,plays=0,score_evaluations=0,round_rewards_modeled=false}
 if input.pack then
  s=M.pack_start(A,s,input.role);local state,ids=M.refill(A,s,remaining,input.world_seed,0,input.sorting)
  if not state then return finish({status='unsupported',reason=ids})end;s,remaining=state,ids
 elseif not input.policy_first then
  assert(input.admission and input.admission.admitted,'Missing completed first-action admission')
  assert(A.snapshot.fingerprint(s)==input.admission.initial_fingerprint,'First-action admission state mismatch')
 end
 row.initial=resources(s);local seen={}
 local function stop(status,reason,complete,diagnostic)
  row.unsupported=diagnostic
  row.status=status;row.reason=reason;row.chips=s.chips;row.target=s.blind.chips
  row.remaining_discards=s.discards_left;row.resources=resources(s);row.resources_prefix_supported=complete==true
  row.final_resources_supported=complete==true and(status=='supported_clear'or status=='modeled_failure')
  return finish(row)
 end
 local acorn
 local function materialize(public)
  if not acorn then return public end
  local raw=copy(public);raw.public_joker_belief=nil;raw.public_joker_observations=nil;raw.jokers={}
  for slot,ordinal in ipairs(acorn.world)do
   local j=copy(public.public_joker_belief.inventory[ordinal]);j.face_down=false
   local ok,edition=A.acorn_belief.public_edition(j.edition)
   if not ok then return nil,'Unsupported remembered edition'end
   j.edition=edition;j.id='private-acorn:'..ordinal;raw.jokers[slot]=j
  end
  return raw
 end
 local function advanced(action)
  if not acorn then return true end
  local b=s.public_joker_belief
  local next_b,why=A.acorn_belief.advance_public(b,{epoch=b.epoch,kind=action.kind,observed_complete=true,
   discarded_count=action.kind=='discard'and #action.indices or nil,
   discarded_jacks=action.kind=='discard'and A.acorn_belief.discarded_jacks(s.hand,action.indices)or nil})
  if not next_b or not next_b.state_valid then return nil,why or next_b and next_b.value_gap or 'Invalid public advancement'end
  return next_b
 end
 local function publish(raw,next_b)
  if not acorn then return raw end
  if #(raw.jokers or{})~=#next_b.inventory then return nil,'Acorn transition changes the retained Joker inventory'end
  for slot,ordinal in ipairs(acorn.world)do
   local actual,expected=raw.jokers[slot],next_b.inventory[ordinal]
   if actual.key~=expected.key or A.snapshot.fingerprint(actual.ability)~=A.snapshot.fingerprint(expected.ability)or
     not not actual.debuff~=not not expected.debuff then
    return nil,'Acorn physical transition disagrees with public ability advancement'
   end
  end
  raw.public_joker_belief=next_b
  raw.public_joker_observations=copy(s.public_joker_observations)
  return M.canonical(raw)
 end
 if s.public_joker_belief and not (s.blind or{}).disabled and
   ((s.blind or{}).key=='bl_final_acorn'or(s.blind or{}).name=='Amber Acorn')and
   (#s.jokers==0 or #s.jokers~=#(s.public_joker_belief.inventory or{}))then
  return stop('unsupported','Public Acorn slot count does not match the remembered inventory.',false,
   evidence().unsupported('initial_public_belief','Public Acorn slot count does not match the remembered inventory.'))
 end
 for _,j in ipairs(s.jokers or {})do
  if j.face_down or j.unknown or j.identity_unknown or j.identity_redacted then
   local b=s.public_joker_belief;local B=A.acorn_belief;local blind=s.blind or{}
   if not B or not B.validate(b)or not B.qualified_values(b)or
     blind.disabled or blind.key~='bl_final_acorn'and blind.name~='Amber Acorn'or not integer(input.world_seed)then
    return stop('unsupported','Concealed Joker belief transitions require a complete qualified Acorn belief.',false,
     evidence().unsupported('initial_public_belief','Concealed Joker belief transitions require a complete qualified Acorn belief.'))
   end
   local index=math.floor(A.sampled_outcomes.roll(input.world_seed,0,'acorn-order',0)*#b.worlds)+1
   acorn={world=copy(b.worlds[index])}
   row.acorn={scope='One private retained permutation from the public belief; public values advanced after every completed action.',
    initial_worlds=#b.worlds,popup_filtering=false,private_order_exported=false}
   break
  end
 end
 for step=1,input.action_cap do
  local fp=A.snapshot.fingerprint(s);if seen[fp]then return stop('loop','Repeated public state',true)end;seen[fp]=true
  if n(s.hands_left)<=0 then return stop('modeled_failure','Hands exhausted',true)end
  local r,a
  if step==1 and not input.pack and not input.policy_first then a=copy(input.role=='default'and input.admission.default or input.admission.five)
  else r=decide(A,s);a=r.action;row.score_evaluations=row.score_evaluations+n(r.evaluations)end
  steps[#steps+1]={action=copy(a),card_ids=a and M.card_ids(s,a),before_chips=s.chips,before_discards=s.discards_left,
   decision=r and summary(A,r),intervention=step==1 and not input.pack and not input.policy_first and input.role or nil}
  if not a then return stop('no_advice','No selected action',true)end
  if a.kind=='reorder_hand'or a.kind=='reorder_jokers'then
   local x,why=reorder(s,a);if not x then return stop('unsupported',why,true)end
   if acorn and a.kind=='reorder_jokers'then
    local b=s.public_joker_belief;local reordered,reason=A.acorn_belief.reorder(b,a.order,b.epoch)
    if not reordered then return stop('unsupported',reason,true)end
    local world={};for i,k in ipairs(a.order)do world[i]=acorn.world[k]end;acorn.world=world
    x.public_joker_belief=reordered
   end;s=x
  elseif(a.kind=='use'or a.kind=='use_consumable')and a.area=='consumeables'then
   if acorn then return stop('unsupported','Acorn consumable transitions need separate public-belief qualification.',true)end
   local x,why=A.consumables.apply(s,a.index,a.targets or{});if not x then return stop('unsupported',tostring(why),true)end;s=M.canonical(x)
  elseif a.kind=='discard'then
   if not M.legal(s,a)then return stop('invalid','Illegal discard',true)end
   local next_b,reason=advanced(a);if not next_b then return stop('unsupported',reason,true)end
   local raw,why=materialize(s);if not raw then return stop('unsupported',why,true)end
   local x,why=A.scoring.after_discard(raw,a.indices);if not x then return stop('unsupported',tostring(why),true)end
   x,why=publish(x,next_b);if not x then return stop('unsupported',why,false)end
   assert(x.discards_left==s.discards_left-1,'Discard counter conservation')
   row.discards=row.discards+1;row.cards_discarded=row.cards_discarded+#a.indices
   if #a.indices==5 then row.five_card_discards=row.five_card_discards+1 end;s=x
   local filled,ids=M.refill(A,s,remaining,input.world_seed,step,input.sorting)
   if not filled then return stop('unsupported',ids,true)end;s,remaining=filled,ids
  elseif a.kind=='play'then
   if not M.legal(s,a)then return stop('invalid','Illegal play',true)end
   local next_b,reason=advanced(a);if not next_b then return stop('unsupported',reason,true)end
   local raw,why=materialize(s);if not raw then return stop('unsupported',why,true)end
   local x,e,actual=A.sampled_outcomes.after_play(raw,a.indices,A.scoring,input.world_seed,step)
   if not x or not actual or actual.uncertain or not actual.legal then
    local diagnostic=evidence().unsupported('play',e,actual)
    local floor=not acorn and A.scoring.lower_bound(s,a.indices)
    if floor and floor.legal and not floor.uncertain and floor.reliable_bound and floor.score>=s.blind.chips-n(s.chips)then
     row.plays=row.plays+1;row.clear_floor=floor.score;return stop('supported_clear_floor','Final transition/resources unresolved: '..diagnostic.reason,false,diagnostic)
    end
    return stop('unsupported',diagnostic.reason,false,diagnostic)
   end
   x,why=publish(x,next_b);if not x then return stop('unsupported',why,false)end
   row.plays=row.plays+1;s=x
   if s.chips>=s.blind.chips then return stop('supported_clear','Actual supported play reaches target',true)end
   if s.hands_left<=0 then return stop('modeled_failure','Hands exhausted',true)end
   local filled,ids=M.refill(A,s,remaining,input.world_seed,step,input.sorting)
   if not filled then return stop('unsupported',ids,true)end;s,remaining=filled,ids
  else return stop('unsupported','Unsupported action '..tostring(a.kind),true)end
 end
 return stop('action_cap','Sixteen-action cap',true)
end
-- Produce all bounded frames before a caller writes any of the result.
function M.run_frames(A,input)
 return evidence().frames(M.run(A,input),A.player_journal.encode)
end
M.copy=copy
return M

-- Concealed cards are observations of slots, never an invitation to inspect
-- their physical identities. A complete immediate comparison is the fallback;
-- bounded continuations use public observations to choose every later action.
local M={}
local function copy(v)
  if type(v)~='table' then return v end
  local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r
end
local function encode(v)
  if type(v)~='table' then return type(v)..':'..tostring(v) end
  local keys,parts={},{};for k in pairs(v) do keys[#keys+1]=k end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b) end)
  for _,k in ipairs(keys) do parts[#parts+1]=encode(k)..'='..encode(v[k]) end
  return '{'..table.concat(parts,';')..'}'
end
local function hidden(c)
  return c.face_down or c.facing=='back' or not (c.rank or (c.base or {}).id) or
    not (c.suit or (c.base or {}).suit)
end
function M.has_hidden(s)
  local occupied={}
  for _,c in ipairs(s.hand or {}) do if hidden(c) then return true end;if c.id then occupied[c.id]=true end end
  for _,c in ipairs(s.deck or {}) do if c.id then occupied[c.id]=true end end
  for _,c in ipairs(s.playing_cards or {}) do if not occupied[c.id] and hidden(c) then return true end end
  return false
end
local function payload(c)
  local r=copy(c);r.id=nil;r.face_down=false;r.facing=nil
  r.ability=r.ability or {};r.ability.forced_selection=nil;r.ability.wheel_flipped=nil;r.ability.discarded=nil
  return r
end
local function is_face(s,c)
  for _,area in ipairs({s.jokers or {},s.consumeables or {}}) do
    for _,j in ipairs(area) do if not j.debuff and
      (j.key=='j_pareidolia' or (j.ability or {}).name=='Pareidolia') then return true end end
  end
  local stone=c.enhancement=='m_stone' or (c.ability or {}).effect=='Stone Card'
  local r=c.rank or (c.base or {}).id
  return not (stone and not c.vampired) and (r==11 or r==12 or r==13)
end
-- Likelihood of a hidden observation for a newly unknown identity. House,
-- Fish and Wheel conceal independently of identity, including retained cards
-- from an earlier draw. Mark plus challenge flips has unequal likelihoods.
function M.hidden_weight(s,c)
  local b=s.blind or {};local key=b.key
  local flip=(s.modifiers or {}).flipped_cards
  if flip~=nil and (type(flip)~='number' or flip<=0) then
    return nil,'The challenge concealment probability is unsupported.'
  end
  local p=flip and math.min(1,1/flip) or 0
  if not b.disabled then
    if key=='bl_mark' or b.name=='The Mark' then return is_face(s,c) and 1 or p end
    if key=='bl_house' or b.name=='The House' or key=='bl_fish' or b.name=='The Fish' then return 1 end
    if key=='bl_wheel' or b.name=='The Wheel' then
      return math.max(0,math.min(1,((s.probabilities or {}).normal or 1)/7))*(1-p)+p
    end
  end
  if p>0 then return p end
  return nil,'The origin of the concealed cards is not supported.'
end
local identity_discard_keys={j_burnt=true,j_mail=true,j_faceless=true,j_castle=true,j_hit_the_road=true}
local identity_discard_names={['Burnt Joker']=true,['Mail-In Rebate']=true,['Faceless Joker']=true,
  Castle=true,['Hit the Road']=true}
local function discard_signal_history(s)
  -- Even a currently debuffed target may have emitted an earlier signal. A
  -- snapshot cannot reconstruct that history, so unknown outside identities
  -- cannot be reassigned while retaining an unconditioned identity-derived
  -- hand level, cash payout or Joker growth value.
  for _,j in ipairs(s.jokers or {}) do
    local name=(j.ability or {}).name or j.name
    if identity_discard_keys[j.key] or identity_discard_names[name] then return name or j.key end
  end
end
local function random_income(s)
  -- Active Blueprint/Brainstorm routes necessarily reach an active physical
  -- target in the same row. Checking every target covers copies without
  -- trusting UI copy-compatibility hints or forgetting name-only snapshots.
  for _,j in ipairs(s.jokers or {}) do if not j.debuff then
    local name=(j.ability or {}).name or j.name
    if j.key=='j_business' or j.key=='j_reserved_parking' or name=='Business Card' or name=='Reserved Parking' then return true end
  end end
  return false
end
local function random(seed)
  local x=seed%2147483647;if x<=0 then x=1 end
  return function() x=(x*16807)%2147483647;return (x-1)/2147483646 end
end
local function fingerprint(text)
  local h=17;for i=1,#text do h=(h*131+text:byte(i))%2147483647 end;return h
end
-- Observe total unseen composition only. Both hidden slot identities and deck
-- order disappear before sampling or candidate generation. Already observed
-- cards outside hand/deck remain fixed only when face up. Discarded backs
-- join the same posterior as nondrawable unknown slots; their actual identities
-- must never be subtracted from the remaining deck as though they were revealed.
function M.observe(s)
  if not M.has_hidden(s) then return nil,'No concealed held or nondrawable cards.' end
  if not s.playing_cards or #s.playing_cards==0 then return nil,'A complete known playing-card population is required.' end
  local population,occupied,pool,slots,seen={},{},{},{},{}
  for _,c in ipairs(s.playing_cards) do
    if not c.id or population[c.id] then return nil,'Known population identities are missing or duplicated.' end
    population[c.id]=c
  end
  local observation=copy(s);observation.hand={};observation.deck={};observation.playing_cards={}
  for _,area in ipairs({'hand','deck'}) do
    for i,c in ipairs(s[area] or {}) do
      if not c.id or occupied[c.id] or not population[c.id] then return nil,'Held/deck identities do not partition the known population.' end
      occupied[c.id]=true
      if not (c.rank or (c.base or {}).id) or not (c.suit or (c.base or {}).suit) then
        return nil,'Unknown rank or suit has no complete composition assignment.'
      end
      if area=='deck' or hidden(c) then
        local card=payload(c)
        if encode(card)~=encode(payload(population[c.id])) then return nil,'Unseen composition disagrees with the known population.' end
        pool[#pool+1]=card
        if area=='hand' then
          slots[#slots+1]={area='hand',index=i,forced=not not (c.ability or {}).forced_selection}
          observation.hand[i]={id='observation:hand:'..i,face_down=true,
            ability={forced_selection=(c.ability or {}).forced_selection}}
        end
      else
        local card=copy(c);card.id='belief:hand:'..i;observation.hand[i]=card
      end
    end
  end
  local hidden_outside=0
  for _,c in ipairs(s.playing_cards) do if not occupied[c.id] then
    if hidden(c) then
      if not (c.rank or (c.base or {}).id) or not (c.suit or (c.base or {}).suit) then return nil,'Unknown discarded composition is incomplete.' end
      hidden_outside=hidden_outside+1;pool[#pool+1]=payload(c)
      slots[#slots+1]={area='outside',index=hidden_outside}
    else seen[#seen+1]=payload(c) end
  end end
  local function sort(cards) table.sort(cards,function(a,b)return encode(a)<encode(b) end) end
  sort(pool);sort(seen)
  if hidden_outside>0 then
    local signal=discard_signal_history(s)
    if signal then return nil,'Hidden discarded identities have unmodeled observation history from '..signal..'.' end
  end
  if #pool>160 then return nil,'The complete unseen held/deck/discarded population exceeds 160 cards.' end
  local weights={}
  for i,c in ipairs(pool) do
    local w,why=M.hidden_weight(s,c);if w==nil then return nil,why end;weights[i]=w
  end
  -- Elementary symmetric polynomial: each unordered k-subset has weight
  -- product(w). Sequential PPS sampling is biased here when Mark is combined
  -- with independent challenge flips; this suffix DP conditions jointly.
  local count=#slots;local suffix={[#pool+1]={[0]=1}}
  for i=#pool,1,-1 do
    suffix[i]={[0]=1}
    for k=1,count do suffix[i][k]=(suffix[i+1][k] or 0)+weights[i]*(suffix[i+1][k-1] or 0) end
  end
  if (suffix[1][count] or 0)<=0 then return nil,'Known composition cannot explain the concealed observations.' end
  local key=encode({hand=observation.hand,pool=pool,seen=seen,weights=weights,hidden_outside=hidden_outside>0 and hidden_outside or nil})
  return {state=observation,pool=pool,seen=seen,slots=slots,weights=weights,suffix=suffix,
    fingerprint=tostring(fingerprint(key)),seed=fingerprint(key),unseen_count=#pool,hidden_outside_count=hidden_outside}
end
function M.world(observation,index)
  local o=observation;local rng=random(o.seed+index*104729)
  local selected,remaining={},#o.slots
  for i=1,#o.pool do
    local probability=remaining>0 and o.weights[i]*(o.suffix[i+1][remaining-1] or 0)/o.suffix[i][remaining] or 0
    if rng()<probability then selected[#selected+1]=i;remaining=remaining-1 end
  end
  if remaining~=0 then return nil,'The conditioned assignment could not be completed.' end
  for i=#selected,2,-1 do local j=math.floor(rng()*i)+1;selected[i],selected[j]=selected[j],selected[i] end
  local s=copy(o.state);local chosen,outside={},{};s.playing_cards={}
  for i,slot in ipairs(o.slots) do
    local source=selected[i];chosen[source]=true
    local c=copy(o.pool[source]);c.ability.forced_selection=slot.forced or nil
    if slot.area=='outside' then
      c.id='belief:unseen_outside:'..slot.index;c.face_down=true;c.ability.discarded=true;outside[#outside+1]=c
    else c.id='belief:hand:'..slot.index;s.hand[slot.index]=c end
  end
  for _,c in ipairs(s.hand) do s.playing_cards[#s.playing_cards+1]=c end
  for i,c in ipairs(o.pool) do if not chosen[i] then
    local card=copy(c);card.id='belief:deck:'..(#s.deck+1);s.deck[#s.deck+1]=card
    s.playing_cards[#s.playing_cards+1]=card
  end end
  for _,c in ipairs(outside) do s.playing_cards[#s.playing_cards+1]=c end
  for i,c in ipairs(o.seen) do local card=copy(c);card.id='belief:observed:'..i;s.playing_cards[#s.playing_cards+1]=card end
  return s
end
local function unsupported(reason,diagnostics)
  diagnostics=diagnostics or {};diagnostics.supported=false;diagnostics.reason=reason
  local lines={reason,'Concealed identities were not used to choose an action.'}
  return {kind='unsupported',title='Concealed-card advice unavailable',lines=lines,evaluations=diagnostics.evaluations or 0,
    strategy={title='Concealed-card advice unavailable',lines=lines,warnings={}},concealed_belief=diagnostics}
end
local function combinations(n,limit,visit)
  local selected={};local function walk(start)
    if #selected>0 then visit(selected) end
    if #selected>=limit then return end
    for i=start,n do selected[#selected+1]=i;walk(i+1);selected[#selected]=nil end
  end;walk(1)
end
function M.run(s,scorer,options)
  if not M.has_hidden(s) then return nil end
  options=options or {};local d={supported=false,evaluations=0,complete=false,scope='immediate_fixed_play',comparisons={}}
  local hands=s.hands_left or (s.current_round or {}).hands_left or 0
  if hands<1 then return unsupported('No playable hands remain.',d) end
  if #(s.hand or {})<1 or #s.hand>9 or #(s.deck or {})>120 then
    return unsupported('The concealed immediate-play comparison requires at most nine held cards and a bounded deck.',d)
  end
  for _,j in ipairs(s.jokers or {}) do if j.face_down or j.facing=='back' then return unsupported('A concealed Joker row is not supported.',d) end end
  local o,why=M.observe(s);if not o then return unsupported(why,d) end
  local count=math.max(4,math.min(32,math.floor(options.samples or 16)))
  local candidates={};combinations(#s.hand,math.min(5,s.hand_limit or 5),function(indices)
    local selected={};for _,i in ipairs(indices) do selected[i]=true end
    for i,c in ipairs(o.state.hand) do if (c.ability or {}).forced_selection and not selected[i] then return end end
    candidates[#candidates+1]=copy(indices)
  end)
  if #candidates*count>math.min(8000,options.max_evaluations or 8000) then return unsupported('The complete concealed comparison exceeds its score budget.',d) end
  local worlds={};for i=1,count do local world,reason=M.world(o,i);if not world then return unsupported(reason,d) end;worlds[i]=world end
  d.observation_fingerprint=o.fingerprint;d.worlds=count;d.candidates=#candidates;d.unseen_count=o.unseen_count;d.hidden_outside_count=o.hidden_outside_count
  d.method='Conditioned composition; fixed actions across common worlds; supported random score floors.'
  local target=math.max(0,((s.blind or {}).chips or 0)-(s.chips or 0));local best
  for _,indices in ipairs(candidates) do
    local c={indices=indices,mean=0,clipped_mean=0,clear_count=0,loss=0,blocked_count=0}
    for _,world in ipairs(worlds) do
      local result=(scorer.lower_bound or scorer.score)(world,indices);d.evaluations=d.evaluations+1
      if options.progress and d.evaluations%32==0 then options.progress() end
      if not result or result.uncertain then return unsupported('A concealed comparison encountered unsupported scoring mechanics.',d) end
      local score=result.legal==false and 0 or result.score
      if type(score)~='number' or score~=score or score==math.huge then return unsupported('A concealed score is not finite.',d) end
      c.mean=c.mean+score/count;c.clipped_mean=c.clipped_mean+math.min(target,score)/count
      c.clear_count=c.clear_count+(score>=target and 1 or 0)
      if result.legal==false then c.blocked_count=c.blocked_count+1 end
      local loss=result.glass_loss or 0
      if (s.modifiers or {}).debuff_played_cards then
        for _,i in ipairs(result.scoring_indices or {}) do if not (world.hand[i].ability or {}).perma_debuff then loss=loss+1 end end
      end
      c.loss=c.loss+loss/count
    end
    d.comparisons[#d.comparisons+1]=c
    local better=not best or c.clear_count>best.clear_count or c.clear_count==best.clear_count and
      (c.clipped_mean>best.clipped_mean or c.clipped_mean==best.clipped_mean and
      (c.loss<best.loss or c.loss==best.loss and (#c.indices<#best.indices or #c.indices==#best.indices and c.mean>best.mean)))
    if better then best=c end
  end
  if not best then return unsupported('No observable card selection meets the selection constraints.',d) end
  d.supported=true;d.complete=true;d.sampled_clear=best.clear_count/count
  -- Known Joker order is public even while playing-card identities are not.
  -- Compare only the already selected fixed slots, in the SAME worlds, before
  -- continuations spend the remaining allowance. Every transition attempt is
  -- charged here; a helper cannot enlarge or silently renew the 8,000 cap.
  if type(options.copy_order)=='function' and type(scorer.after_play)=='function' then
    local cap=math.min(8000,options.max_evaluations or 8000)
    local start=d.evaluations
    local context={remaining=math.max(0,cap-start),seed=o.seed,progress=options.progress}
    context.after_play=function(world,indices,transition)
      if d.evaluations>=cap then return nil,'The concealed score allowance is exhausted.' end
      d.evaluations=d.evaluations+1
      if options.progress and d.evaluations%32==0 then options.progress() end
      return scorer.after_play(world,indices,transition)
    end
    local proposal,receipt=options.copy_order(o.state,worlds,best,context)
    d.ordering=receipt
    if receipt then receipt.score_calls=d.evaluations-start end
    if proposal and receipt and receipt.complete and proposal.action and proposal.action.kind=='reorder_jokers' then
      return {kind='reorder_jokers',action=proposal.action,evaluations=d.evaluations,
        reorder_only=true,needs_refresh=true,ordering=proposal,concealed_belief=d,
        strategy={title=proposal.title,lines=proposal.lines,warnings=proposal.warnings or {}},
        play={indices=copy(best.indices),hand='Concealed hand',score=best.mean,legal=true,uncertain=true,
          warnings={'This is the current-row sampled incumbent; the next play requires fresh advice.'}}}
    end
  end
  local selected,continuation=M.continue(s,o,best,scorer,options,d)
  d.continuation=continuation
  if continuation and continuation.complete then d.scope='bounded_observation_continuation' end
  local lines={'The same selected slots were compared across '..count..' possible hidden assignments.',
    'This sample is not a guaranteed clear or a measured win probability.'}
  if continuation and continuation.complete then
    lines[#lines+1]='Compared one current play and '..continuation.discard_candidates..' current discards through '..continuation.horizon..' plays in four common worlds.'
    lines[#lines+1]='Later choices use a small public-slot family and fresh conditioned beliefs; discard again only after a new recommendation.'
  elseif continuation and continuation.reason then lines[#lines+1]='Immediate-play fallback: '..continuation.reason end
  if #(s.consumeables or {})>0 then lines[#lines+1]='Held consumables remain in scoring; spending them is outside this comparison.' end
  local action=selected or {kind='play',area='hand',indices=copy(best.indices)}
  local title=(action.kind=='discard' and 'Discard ' or 'Play ')..#action.indices..' cards from concealed observations'
  return {kind=action.kind,action=action,evaluations=d.evaluations,
    play={indices=copy(best.indices),hand='Concealed hand',score=best.mean,legal=true,uncertain=true,warnings=lines},
    strategy={title=title,lines=lines,warnings={}},concealed_belief=d}
end

-- Public candidate construction is deliberately independent of internal sampled
-- identities. This family is bounded, not an exhaustive future-hand optimizer.
function M.public_candidates(state,discard)
  local hand={};for i,c in ipairs(state.hand or {}) do
    hand[i]=hidden(c) and {face_down=true,ability={forced_selection=(c.ability or {}).forced_selection}} or c
  end
  local limit=math.min(5,state.hand_limit or 5,#hand)
  local out,seen={},{}
  local function add(indices)
    local selected={};for _,i in ipairs(indices) do if hand[i] then selected[i]=true end end
    for i,c in ipairs(hand) do if (c.ability or {}).forced_selection then selected[i]=true end end
    local list={};for i=1,#hand do if selected[i] then list[#list+1]=i end end
    if #list==0 or #list>limit then return end
    local key=table.concat(list,',');if not seen[key] then seen[key]=true;out[#out+1]=list end
  end
  local concealed,visible,ranks,suits={},{},{},{}
  for i,c in ipairs(hand) do
    if hidden(c) then concealed[#concealed+1]=i else
      visible[#visible+1]=i
      local r=c.rank or (c.base or {}).id;local suit=c.suit or (c.base or {}).suit
      ranks[r]=ranks[r] or {};ranks[r][#ranks[r]+1]=i
      suits[suit]=suits[suit] or {};suits[suit][#suits[suit]+1]=i
    end
  end
  table.sort(visible,function(a,b)
    local ar=hand[a].rank or (hand[a].base or {}).id;local br=hand[b].rank or (hand[b].base or {}).id
    return ar==br and a<b or ar>br
  end)
  local groups={};for _,g in pairs(ranks) do groups[#groups+1]=g end
  table.sort(groups,function(a,b)
    if #a~=#b then return #a>#b end
    local ar=hand[a[1]].rank or (hand[a[1]].base or {}).id;local br=hand[b[1]].rank or (hand[b[1]].base or {}).id
    return ar==br and a[1]<b[1] or ar>br
  end)
  local flushes={};for _,g in pairs(suits) do flushes[#flushes+1]=g end
  table.sort(flushes,function(a,b)return #a==#b and a[1]<b[1] or #a>#b end)
  local function first(list,n) local r={};for i=1,math.min(n or limit,#list) do r[#r+1]=list[i] end;return r end
  if discard then
    add(first(concealed))
    local keep={};local group=groups[1] or {}
    if flushes[1] and #flushes[1]>=4 and #flushes[1]>#group then group=flushes[1] end
    if #group>=2 then for _,i in ipairs(group) do keep[i]=true end end
    local reject={};for i=1,#hand do if not keep[i] and #reject<limit then reject[#reject+1]=i end end
    add(reject)
    local all={};for i=1,limit do all[i]=i end;add(all)
    return out
  end
  if #hand<=3 then
    combinations(#hand,limit,add);return out
  end
  -- Each family member is fixed from visible rank/suit groups and slot order.
  -- Hidden cards can fill an observable group, but cannot select that group.
  local function fill(group)
    local r=first(group);local used={};for _,i in ipairs(r) do used[i]=true end
    for _,i in ipairs(concealed) do if #r<limit and not used[i] then r[#r+1]=i end end
    add(r)
  end
  if groups[1] then add(first(groups[1]));fill(groups[1]) end
  if groups[2] then local two=first(groups[1]);for _,i in ipairs(groups[2]) do if #two<limit then two[#two+1]=i end end;add(two) end
  if flushes[1] then fill(flushes[1]) end
  local high=first(visible);for _,i in ipairs(concealed) do if #high<limit then high[#high+1]=i end end;add(high)
  if visible[1] then add({visible[1]}) end
  add(first(concealed))
  local all={};for i=1,limit do all[i]=i end;add(all)
  return out
end
local function exposed(state)
  local s=copy(state)
  for _,area in ipairs({'hand','deck','playing_cards'}) do
    for _,c in ipairs(s[area] or {}) do c.face_down=false;c.facing=nil end
  end
  return s
end
local function restore_visibility(state,prior)
  local flags={};for _,c in ipairs(prior.playing_cards or {}) do if hidden(c) then flags[c.id]=true end end
  for _,c in ipairs(prior.deck or {}) do flags[c.id]=nil end
  for _,c in ipairs(prior.hand or {}) do flags[c.id]=hidden(c) end
  for _,area in ipairs({'hand','playing_cards'}) do for _,c in ipairs(state[area] or {}) do
    c.face_down=not not flags[c.id];c.facing=nil
  end end
  return state
end
-- Newly drawn physical deck cards start on their backs. Boss and challenge
-- flips are separate source events. Retained concealed cards never turn face up
-- merely because an internal scoring copy exposed their sampled assignment.
function M.future_fill(state,scorer,draws,outcomes,seed,turn)
  if not draws or not draws.fill or not outcomes or not outcomes.fill or not outcomes.roll then return nil,'Conditional draw dependencies are unavailable.' end
  local order=copy(state.deck or {})
  table.sort(order,function(a,b)return tostring(a.id)<tostring(b.id) end)
  local rng=random(seed+turn*104729)
  for i=#order,2,-1 do local j=math.floor(rng()*i)+1;order[i],order[j]=order[j],order[i] end
  for _,c in ipairs(order) do c.face_down=true;c.facing=nil end
  local adapter={fill=function(s,cards,opts)
    local flip=(s.modifiers or {}).flipped_cards
    if flip~=nil and (type(flip)~='number' or flip<=0) then return nil,'Challenge replacement visibility is unsupported.' end
    local clean=copy(s);clean.modifiers=copy(s.modifiers or {});clean.modifiers.flipped_cards=nil
    local next_state,why=draws.fill(clean,cards,opts)
    if not next_state then return nil,why end
    next_state.modifiers=copy(s.modifiers or {})
    for i=#(s.hand or {})+1,#next_state.hand do
      local c=next_state.hand[i];local b=s.blind or {}
      -- Use source Card:is_face(true), including Pareidolia in either inventory
      -- and the Stone/Vampire exception, rather than an approximate rank check.
      if not b.disabled and (b.key=='bl_mark' or b.name=='The Mark') then c.face_down=is_face(s,c) end
      if flip and outcomes.roll(seed,turn,'challenge-visibility',c.id or i)<math.min(1,1/flip) then c.face_down=true end
      c.ability=c.ability or {};c.ability.wheel_flipped=c.face_down and true or nil
    end
    return next_state
  end}
  local bell=math.floor(outcomes.roll(seed,turn,'concealed-bell',0)*1000000)
  return outcomes.fill(state,order,scorer,adapter,seed,turn,bell)
end
function M.continue(s,observation,immediate,scorer,options,diagnostics)
  local hands=s.hands_left or (s.current_round or {}).hands_left or 0
  local discards=s.discards_left or (s.current_round or {}).discards_left or 0
  local d={complete=false,horizon=hands,outer_worlds=4,inner_worlds=4,first_discard_only=true,
    future_candidate_limit=8,comparisons={},evaluations=0,observations=0}
  local function no(reason) d.reason=reason;return nil,d end
  if hands==1 and discards==0 then return nil,nil end
  if hands>4 or hands<1 then return no('The full remaining horizon exceeds four plays.') end
  if random_income(s) then return no('Conditional random income cannot be used as exact future cash or hand size.') end
  local outcomes,draws=options.sampled_outcomes,options.draws
  if not outcomes or not outcomes.after_play or not draws or not scorer.after_discard or not scorer.after_play then
    return no('Exact continuation dependencies are unavailable.')
  end
  local max_evaluations=math.min(8000,options.max_evaluations or 8000)
  local start=diagnostics.evaluations
  local aborted
  local function charge()
    if diagnostics.evaluations>=max_evaluations then aborted='The complete continuation exceeds the existing 8,000-score allowance.';return false end
    diagnostics.evaluations=diagnostics.evaluations+1;d.evaluations=d.evaluations+1
    if options.progress and diagnostics.evaluations%32==0 then options.progress() end
    return true
  end
  local function valid(p)
    return p and not p.uncertain and type(p.score)=='number' and p.score==p.score and p.score>=0 and p.score<math.huge
  end
  local function future_policy(state)
    if #state.hand<1 or #state.hand>9 or #state.deck>120 then aborted='A future observation has no held cards or exceeds the bounded hand/deck size.';return nil end
    local worlds,public={},state
    if M.has_hidden(state) then
      local o,why=M.observe(state);if not o then aborted=why;return nil end
      public=o.state
      for i=1,4 do local w,reason=M.world(o,i);if not w then aborted=reason;return nil end;worlds[i]=w end
    else worlds[1]=exposed(state) end
    local candidates=M.public_candidates(public,false)
    if #candidates==0 or #candidates>8 then aborted='The complete public future-action family is unavailable.';return nil end
    d.observations=d.observations+1
    local target=math.max(0,(state.blind or {}).chips-(state.chips or 0));local best
    for _,indices in ipairs(candidates) do
      local c={indices=indices,clear=0,utility=0,loss=0,score=0}
      for _,w in ipairs(worlds) do
        if not charge() then return nil end
        local p=(scorer.lower_bound or scorer.score)(w,indices)
        if not valid(p) then aborted='A future belief comparison has unsupported scoring.';return nil end
        local score=p.legal==false and 0 or p.score
        c.clear=c.clear+(score>=target and 1 or 0)/#worlds
        c.utility=c.utility+math.min(target,score)/#worlds;c.score=c.score+score/#worlds
        local loss=p.glass_loss or 0
        if (state.modifiers or {}).debuff_played_cards then
          for _,i in ipairs(p.scoring_indices or {}) do if not (w.hand[i].ability or {}).perma_debuff then loss=loss+1 end end
        end
        c.loss=c.loss+loss/#worlds
      end
      if not best or c.clear>best.clear or c.clear==best.clear and
        (c.utility>best.utility or c.utility==best.utility and
        (c.loss<best.loss or c.loss==best.loss and (#indices<#best.indices or #indices==#best.indices and c.score>best.score))) then best=c end
    end
    return best and best.indices
  end
  local branches={{kind='play',indices=copy(immediate.indices),clear=0,utility=0,hands=0,loss=0,ending_dollars=0,discards_spent=0}}
  if discards>0 and #(s.deck or {})>0 then
    for _,indices in ipairs(M.public_candidates(observation.state,true)) do
      branches[#branches+1]={kind='discard',indices=indices,clear=0,utility=0,hands=0,loss=0,ending_dollars=0,discards_spent=0}
    end
  end
  d.discard_candidates=#branches-1;d.first_actions=#branches
  local target=math.max(1,((s.blind or {}).chips or 0)-(s.chips or 0))
  for _,branch in ipairs(branches) do
    for world_index=1,4 do
      local state,why=M.world(observation,world_index)
      if not state then return no(why) end
      for _,slot in ipairs(observation.slots) do if slot.area~='outside' then state.hand[slot.index].face_down=true end end
      local seed=observation.seed+world_index*104729
      if branch.kind=='discard' then
        local before=state
        state,why=scorer.after_discard(exposed(state),branch.indices)
        if not state then return no('A considered first discard is unsupported: '..tostring(why)) end
        local private={};for _,c in ipairs(before.hand) do if hidden(c) then private[c.id]=true end end
        for _,c in ipairs((why or {}).destroyed_cards or {}) do if private[c.id] then
          return no('A concealed discard destroys an identity without an observed reveal.')
        end end
        restore_visibility(state,before)
        state,why=M.future_fill(state,scorer,draws,outcomes,seed,0)
        if not state then return no(why) end
      end
      local total_loss,used=0,0
      for turn=1,hands do
        local indices=branch.kind=='play' and turn==1 and branch.indices or future_policy(state)
        if not indices then return no(aborted or 'No complete future play is available.') end
        if not charge() then return no(aborted) end
        local before=state;local actual,effects
        state,effects,actual=outcomes.after_play(exposed(before),indices,scorer,seed,turn)
        if not state or not valid(actual) or actual.legal==false then
          return no('A future play transition is unsupported: '..tostring(state and 'uncertain score or growth' or effects))
        end
        used=used+1
        local removed=effects and effects.destroyed_cards or {};total_loss=total_loss+#removed
        if (before.modifiers or {}).debuff_played_cards then
          for _,i in ipairs(actual.scoring_indices or {}) do if not (before.hand[i].ability or {}).perma_debuff then total_loss=total_loss+1 end end
        end
        restore_visibility(state,before)
        local played={};for _,i in ipairs(indices) do played[before.hand[i].id]=true end
        for _,c in ipairs(state.playing_cards or {}) do if played[c.id] then c.face_down=false end end
        if (state.chips or 0)>=(state.blind or {}).chips or (state.hands_left or 0)<=0 or #state.hand+#state.deck==0 then break end
        state,why=M.future_fill(state,scorer,draws,outcomes,seed,turn)
        if not state then return no(why) end
      end
      local progress=math.max(0,(state.chips or 0)-(s.chips or 0))
      branch.clear=branch.clear+(progress>=target and 1 or 0)/4
      branch.utility=branch.utility+math.min(1,progress/target)/4
      branch.hands=branch.hands+used/4;branch.loss=branch.loss+total_loss/4
      branch.ending_dollars=branch.ending_dollars+(state.dollars or 0)/4
      branch.discards_spent=branch.discards_spent+(discards-(state.discards_left or 0))/4
    end
    d.comparisons[#d.comparisons+1]=branch
  end
  local best=branches[1]
  for i=2,#branches do
    local candidate=branches[i]
    if candidate.clear>best.clear or candidate.clear==best.clear and
      (candidate.utility>best.utility+0.02 or candidate.utility==best.utility and
      (candidate.loss<best.loss or candidate.loss==best.loss and candidate.hands+1<best.hands)) then best=candidate end
  end
  d.complete=true;d.sampled_finish=best.clear;d.selected_kind=best.kind;d.selected_indices=copy(best.indices)
  d.evaluations=diagnostics.evaluations-start
  return {kind=best.kind,area='hand',indices=copy(best.indices)},d
end
return M

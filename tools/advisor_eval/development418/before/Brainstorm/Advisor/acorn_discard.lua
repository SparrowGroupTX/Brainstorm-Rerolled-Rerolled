-- Last-hand Amber Acorn redraw comparison over a qualified public Joker row.
-- Only the first discard is recommended; the next observed hand is replanned.
-- Hidden Joker payloads and physical deck order are never read.
local M={}
local function finite(x) return type(x)=='number' and x==x and math.abs(x)<math.huge end
local function visible(c)
  return type(c)=='table' and not (c.face_down or c.unknown or c.concealed or c.identity_redacted or c.facing=='back')
end
local omitted={id=true,face_down=true,facing=true,sprite_facing=true,sort_id=true,T=true,VT=true,
  wheel_flipped=true,discarded=true}
local function encode(v)
  if type(v)~='table' then return type(v)..':'..tostring(v) end
  local keys,out={},{}
  for k in pairs(v) do if not omitted[k] then keys[#keys+1]=k end end
  table.sort(keys,function(a,b)return tostring(a)<tostring(b) end)
  for _,k in ipairs(keys) do out[#out+1]=encode(k)..'='..encode(v[k]) end
  return '{'..table.concat(out,';')..'}'
end
local function count_plays(n,limit)
  local term,total=1,0
  for k=1,math.min(n,limit) do term=term*(n-k+1)/k;total=total+term end
  return total
end
local function subsets(n,limit,visit)
  local row={}
  local function walk(start)
    if #row>0 then visit(row) end
    if #row>=limit then return end
    for i=start,n do row[#row+1]=i;walk(i+1);row[#row]=nil end
  end
  walk(1)
end
local function public_family(s)
  local rows,groups={},{}
  local forced={};for i,c in ipairs(s.hand) do if (c.ability or {}).forced_selection then forced[i]=true end end
  local purple_unavailable=#(s.consumeables or {})+(s.consumeable_buffer or 0)<(s.consumable_limit or 2)
  subsets(#s.hand,math.min(5,s.hand_limit or 5),function(indices)
    local chosen={};for _,i in ipairs(indices) do chosen[i]=true end
    for i in pairs(forced) do if not chosen[i] then return end end
    if purple_unavailable then for _,i in ipairs(indices) do if s.hand[i].seal=='Purple' then return end end end
    local held,ranks,merit={}, {}, #indices*4
    for i,c in ipairs(s.hand) do if not chosen[i] then
      held[#held+1]=c
      local rank=c.rank or (c.base or {}).id
      ranks[rank]=(ranks[rank] or 0)+1
      if c.enhancement=='m_glass' or c.enhancement=='m_steel' then merit=merit+12 end
      if c.seal=='Red' or c.seal=='Blue' then merit=merit+4 end
    end end
    for _,v in pairs(ranks) do merit=merit+v*v*7 end
    local row={indices={},merit=merit,key=table.concat(indices,',')}
    for i,x in ipairs(indices) do row.indices[i]=x end
    groups[#indices]=groups[#indices] or {};groups[#indices][#groups[#indices]+1]=row
  end)
  for _,group in pairs(groups) do table.sort(group,function(a,b)
    return a.merit==b.merit and a.key<b.key or a.merit>b.merit
  end) end
  local out,seen={},{}
  local function add(row)
    if row and not seen[row.key] and #out<4 then seen[row.key]=true;out[#out+1]=row.indices end
  end
  local maximum=math.min(5,s.hand_limit or 5,#s.hand)
  add(groups[maximum] and groups[maximum][1]);add(groups[maximum] and groups[maximum][2])
  add(groups[maximum-1] and groups[maximum-1][1])
  for size=maximum-2,1,-1 do add(groups[size] and groups[size][1]) end
  return out
end
local function complete_population(s)
  if #s.hand>12 or #s.deck>120 or #(s.playing_cards or {})==0 then return false end
  local present,population={},{}
  for _,c in ipairs(s.playing_cards) do
    if not c.id or population[c.id] or not c.rank or not c.suit then return false end
    population[c.id]=true
  end
  for _,area in ipairs({s.hand,s.deck}) do for _,c in ipairs(area) do
    if not c.id or present[c.id] or not population[c.id] or not c.rank or not c.suit then return false end
    present[c.id]=true
  end end
  for _,c in ipairs(s.hand) do if not visible(c) then return false end end
  for _,c in ipairs(s.playing_cards) do if not present[c.id] and not visible(c) then return false end end
  return true
end
local function shuffle(n,sample)
  local order={};for i=1,n do order[i]=i end
  local x=(19491001+sample*104729)%2147483647
  for i=n,2,-1 do x=(x*16807)%2147483647;local j=x%i+1;order[i],order[j]=order[j],order[i] end
  return order
end
local function legal_plays(s,full,public_candidates)
  if not full then return public_candidates(s,false) end
  local out={}
  subsets(#s.hand,math.min(5,s.hand_limit or 5),function(indices)
    local selected={};for _,i in ipairs(indices) do selected[i]=true end
    for i,c in ipairs(s.hand) do if (c.ability or {}).forced_selection and not selected[i] then return end end
    local row={};for i,v in ipairs(indices) do row[i]=v end;out[#out+1]=row
  end)
  return out
end
function M.suggest(s,b,immediate,prior,scorer,raw,belief,draws,public_candidates,options)
  options=options or {}
  local early=type(s.hands_left)=='number' and s.hands_left>1
  local d={complete=false,evaluations=0,scope=early and
    'First-discard immediate progress comparison over every public Joker world and common sampled draws; later plays unmodeled.' or
    'Final-hand first-discard comparison over every public Joker world and common sampled draws.'}
  local function no(why) d.reason=why;return nil,d.evaluations,d end
  local blind=s.blind or {}
  if s.phase~='hand' or (blind.key~='bl_final_acorn' and blind.name~='Amber Acorn') or blind.disabled or
    not finite(s.hands_left) or s.hands_left<1 or not finite(s.discards_left) or s.discards_left<1 or #(s.deck or {})<1 or
    not immediate or immediate.kind~='play' or immediate.immediate_clear_all_worlds or
    not prior or not prior.complete or not prior.profiles or not prior.profiles[1] or
    not belief or not belief.validate(b) or b.state_valid~=true or #b.worlds>120 or
    not scorer or not scorer.lower_bound or not raw or not raw.after_discard or
    not draws or not draws.fill or not public_candidates or not complete_population(s) then
    return no('The final-hand public redraw scope is unavailable.')
  end
  if belief.qualified_values and not belief.qualified_values(b) then return no('Modified public Joker abilities are outside the qualified redraw comparison.') end
  local target=blind.chips-s.chips
  if not finite(target) or target<=0 then return no('A finite remaining target is required.') end
  local baseline=0;local incumbent
  for _,profile in ipairs(prior.profiles[1]) do if profile.legal and profile.clear_count then
    baseline=math.max(baseline,profile.clear_count/#b.worlds)
    if table.concat(profile.indices or {},',')==table.concat((immediate.action or {}).indices or {},',') then incumbent=profile end
  end end
  if early and (not incumbent or #(incumbent.scores or {})~=#b.worlds) then return no('The fixed current play has no complete per-world profile.') end
  if baseline>=1 then return no('An existing fixed play clears every public order.') end
  if not finite(options.max_evaluations) then return no('A finite remaining ordinary score allowance is required.') end
  local allowance=math.max(0,math.min(140000,math.floor(options.max_evaluations)))
  local samples=24
  local candidates=public_family(s)
  if #candidates==0 then return no('No legal public first discard was admitted.') end
  local root={}
  for k,v in pairs(s) do if k~='jokers' and k~='public_joker_belief' and k~='public_joker_observations' then
    root[k]=belief.copy(v)
  end end
  table.sort(root.deck,function(a,c)return encode(a)<encode(c) end)
  local prepared={}
  for _,indices in ipairs(candidates) do
    local advanced=belief.advance_public(b,{epoch=b.epoch,kind='discard',observed_complete=true,discarded_count=#indices})
    if not advanced or advanced.state_valid~=true then return no('A completed discard would invalidate the public Joker ability belief.') end
    local rows={};local witness
    for wi,world in ipairs(b.worlds) do
      local state=belief.copy(root);state.jokers={}
      for slot,ordinal in ipairs(world) do
        state.jokers[slot]=belief.copy(b.inventory[ordinal]);state.jokers[slot].face_down=false
        if belief.public_edition then local ok,e=belief.public_edition(state.jokers[slot].edition);state.jokers[slot].edition=e end
      end
      local after,effects=raw.after_discard(state,indices)
      if not after then return no('A considered exact discard is unsupported: '..tostring(effects)) end
      if effects and effects.population_delta~=0 then return no('A considered discard changes the unseen population.') end
      if #(after.jokers or {})~=#b.inventory then return no('A discard changes the retained Joker inventory.') end
      for slot,ordinal in ipairs(world) do
        local actual,expected=after.jokers[slot],advanced.inventory[ordinal]
        if actual.key~=expected.key or encode(actual.ability)~=encode(expected.ability) then
          return no('The exact discard state disagrees with the public Joker ability transition.')
        end
      end
      local common=encode({hand=after.hand,deck=after.deck,dollars=after.dollars,hand_size=after.hand_size,
        discards_left=after.discards_left,consumeables=after.consumeables,playing_cards=after.playing_cards})
      if witness and witness~=common then return no('A discard has different public redraw resources across Joker orders.') end
      witness=common;rows[wi]=after
    end
    prepared[#prepared+1]={indices=indices,rows=rows}
  end
  local max_size=0
  for _,candidate in ipairs(prepared) do
    local state=candidate.rows[1]
    local size=state.hand_size
    if not finite(size) or size<1 or size%1~=0 then
      return no('A finite integral prospective hand size is required.')
    end
    max_size=math.max(max_size,math.min(size,#state.hand+#state.deck))
  end
  if max_size<1 or max_size>12 then return no('A prospective hand exceeds the bounded play size.') end
  local full=samples*#b.worlds*#prepared*count_plays(max_size,math.min(5,s.hand_limit or 5))<=allowance
  if not full then
    while #prepared>0 and samples*#b.worlds*#prepared*8>allowance do prepared[#prepared]=nil end
  end
  if #prepared==0 then return no('The complete common-world redraw family exceeds the remaining ordinary score allowance.') end
  d.baseline_clear_fraction=baseline;d.worlds=#b.worlds;d.samples=samples
  d.discard_candidates=#prepared;d.play_family=full and 'all_legal_subsets' or 'bounded_public_rank_suit_subsets'
  local best
  for _,candidate in ipairs(prepared) do
    local clear,clipped=0,0;local world_progress={}
    for wi=1,#b.worlds do world_progress[wi]=0 end
    for sample=1,samples do
      local order=shuffle(#root.deck,sample)
      local states,signature={}
      for wi,after in ipairs(candidate.rows) do
        local cards={};for i,index in ipairs(order) do cards[i]=after.deck[index] end
        local next_state,why=draws.fill(after,cards)
        if not next_state then return no('A sampled redraw is unsupported: '..tostring(why)) end
        for _,card in ipairs(next_state.hand) do if not visible(card) then return no('A sampled redraw remains concealed.') end end
        local key=encode({hand=next_state.hand,dollars=next_state.dollars,hand_size=next_state.hand_size})
        if signature and signature~=key then return no('The next public hand depends on the concealed Joker order.') end
        signature=key;states[wi]=next_state
      end
      local plays=legal_plays(states[1],full,public_candidates)
      if #plays==0 or not full and #plays>8 or
        d.evaluations+#plays*#b.worlds>allowance then
        return no('The complete next-hand play family exceeds the remaining ordinary allowance.')
      end
      local next_best
      for _,indices in ipairs(plays) do
        local wins,utility,legal=0,0,true;local minimum=math.huge;local progress={}
        for wi,state in ipairs(states) do
          local score=scorer.lower_bound(state,indices);d.evaluations=d.evaluations+1
          if options.yield_fn and d.evaluations%32==0 then options.yield_fn(d.evaluations) end
          if not score or score.uncertain or score.reliable_bound~=true or
            type(score.warnings)=='table' and #score.warnings>0 or not finite(score.score) or score.score<0 then
            return no('A redraw world has no supported scoring floor.')
          end
          if score.legal==false then legal=false
          else
            if score.score>=target then wins=wins+1 end
            progress[wi]=math.min(target,score.score)/target
            utility=utility+progress[wi];minimum=math.min(minimum,progress[wi])
          end
        end
        local better=not next_best or early and (minimum>next_best.minimum or minimum==next_best.minimum and utility>next_best.utility) or
          not early and (wins>next_best.wins or wins==next_best.wins and utility>next_best.utility)
        if legal and better then
          next_best={wins=wins,utility=utility,minimum=minimum,progress=progress}
        end
      end
      if not next_best then return no('No fixed legal next-hand play remains in every public Joker order.') end
      clear=clear+next_best.wins;clipped=clipped+next_best.utility
      for wi=1,#b.worlds do world_progress[wi]=world_progress[wi]+next_best.progress[wi]/samples end
    end
    local rate=clear/(samples*#b.worlds)
    local candidate_result={indices=candidate.indices,clear_fraction=rate,
      clipped_fraction=clipped/(samples*#b.worlds),world_progress=world_progress}
    if early then
      candidate_result.early_supported=true;local gain=0
      for wi,value in ipairs(world_progress) do
        local base=math.min(target,incumbent.scores[wi])/target
        if value+1e-9<base then candidate_result.early_supported=false end
        gain=gain+value-base
      end
      candidate_result.early_gain=gain/#b.worlds
      candidate_result.early_supported=candidate_result.early_supported and candidate_result.early_gain>0.04
    end
    d.comparisons=d.comparisons or {};d.comparisons[#d.comparisons+1]=candidate_result
    if (not early or candidate_result.early_supported) and (not best or rate>best.clear_fraction or rate==best.clear_fraction and
      candidate_result.clipped_fraction>best.clipped_fraction) then best=candidate_result end
  end
  d.complete=true;d.selected=best;d.supported_improvement=best and
    (early and best.early_supported or not early and best.clear_fraction>=baseline+0.125) or false
  if not d.supported_improvement then return nil,d.evaluations,d end
  return {kind='discard',action={kind='discard',area='hand',indices=best.indices},
    sampled_clear_fraction=best.clear_fraction,baseline_clear_fraction=baseline,
    lines={early and 'A first discard improves sampled immediate progress without lowering its mean in any retained public Joker order; later hands are not forecast.' or
      'A first discard improved supported sampled clearing across '..samples..' common redraws and every retained public Joker order.',
      'This is a bounded current-blind estimate, not a calibrated win probability or a guaranteed clear.',
      'Discard once, observe the new hand and Joker evidence, then request fresh advice.'}},d.evaluations,d
end
function M.retained(s,b,immediate,scorer,raw,belief,modules,options)
  options=options or {}
  local cap=math.min(12,math.max(0,math.floor(options.max_evaluations or 12)))
  local d={complete=false,evaluations=0,scope='same physical discard and retained clear in every public Joker order'}
  local function no(why)d.reason=why;return nil,d.evaluations,d end
  if s.teacher_profile~='perkeo_yorick_win_v1' or not immediate or not immediate.immediate_clear_all_worlds or
      not modules.growth or not modules.strategy or not scorer.lower_bound or not raw.after_discard or
      not belief.validate(b) or b.state_valid~=true or not complete_population(s) or
      belief.qualified_values and not belief.qualified_values(b) then return no('No complete qualified public retained-clear scope.') end
  if #b.worlds+1>cap then return no('The complete public retained-clear family exceeds the twelve-score allowance.') end
  local root={};for k,v in pairs(s) do
    if k~='jokers' and k~='public_joker_belief' and k~='public_joker_observations' then root[k]=belief.copy(v) end
  end
  local function state(world)
    local value=belief.copy(root);value.jokers={}
    for slot,ordinal in ipairs(world) do
      value.jokers[slot]=belief.copy(b.inventory[ordinal]);value.jokers[slot].face_down=false
      if belief.public_edition then local ok,e=belief.public_edition(value.jokers[slot].edition);value.jokers[slot].edition=e end
    end
    return value
  end
  local first=state(b.worlds[1]);local indices=immediate.action.indices
  local clear=scorer.lower_bound(first,indices);d.evaluations=d.evaluations+1
  if not clear or not clear.reliable_bound or clear.uncertain or clear.legal==false then return no('The fixed public play lacks a supported floor.') end
  clear.indices=indices
  local scoped={};for k,v in pairs(modules) do scoped[k]=v end
  scoped.scoring=setmetatable({lower_bound=scorer.lower_bound},{__index=raw})
  local choice,work,why=modules.growth.suggest(first,scoped,clear,{exhaust_discards=true,
    max_evaluations=cap-#b.worlds})
  d.evaluations=d.evaluations+work;d.first_world=why
  if not choice then return no('No first-world retained discard qualified.') end
  local advanced=belief.advance_public(b,{epoch=b.epoch,kind='discard',observed_complete=true,discarded_count=#choice.action.indices})
  if not advanced or advanced.state_valid~=true then return no('Public growth cannot advance after this discard.') end
  local removed={};for _,i in ipairs(choice.action.indices) do removed[i]=true end
  local remap={};local count=0;for i=1,#s.hand do if not removed[i] then count=count+1;remap[i]=count end end
  local finish={};for _,i in ipairs(choice.growth.retained_original_indices) do
    if not remap[i] then return no('The proposed discard removes its retained anchor.') end;finish[#finish+1]=remap[i]
  end
  for wi,world in ipairs(b.worlds) do
    local after,effects=raw.after_discard(state(world),choice.action.indices)
    if not after or effects.population_delta~=0 or after.dollars<s.dollars then return no('A public discard endpoint is unsupported or spends cash.') end
    for slot,ordinal in ipairs(world) do
      if encode(after.jokers[slot].ability)~=encode(advanced.inventory[ordinal].ability) then return no('Public growth and the exact discard disagree.') end
    end
    if wi>1 then
      local blue=(choice.growth or {}).blue_joker_draw_cost
      if blue then
        local deck={};for i=1,blue.remaining_deck do deck[i]=after.deck[i] end;after.deck=deck
      end
      local p=scorer.lower_bound(after,finish);d.evaluations=d.evaluations+1
      if not p or not p.reliable_bound or p.uncertain or p.legal==false or
          p.score<(s.blind.chips-s.chips) then return no('A later public order loses the retained clear.') end
    end
  end
  d.complete=true;d.worlds=#b.worlds;d.retained_indices=choice.growth.retained_original_indices
  choice.lines={'The same visible cards still clear after this discard in every retained public Joker order.',
    'Keep the current physical slots. Observe the real discard and draw before requesting the next action.'}
  return choice,d.evaluations,d
end
return M

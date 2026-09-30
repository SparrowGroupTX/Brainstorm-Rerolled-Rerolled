-- Detached429 model evaluation. No original game, actions, profiles or saves.
local m=A
local original=m.snapshot.fingerprint(INPUT.snapshot)
local function summary(r)
 return {action=r.action,evaluations=r.evaluations,title=r.title,
  discard_before_clear=r.discard_before_clear,yorick_review=m.player_journal.compact_yorick_review(r),
  play=r.play and {score=r.play.score,hand=r.play.hand,uncertain=r.play.uncertain,legal=r.play.legal},
  warnings=r.warnings}
end
local function decide(s)
 local before=m.snapshot.fingerprint(s)
 local r=m.decision.run(s,m,nil,nil) -- product budgets; clean/disabled retry
 assert(m.snapshot.fingerprint(s)==before,'Policy mutated public input')
 assert(not r.evaluations or r.evaluations<=140000,'Ordinary decision cap exceeded')
 return r
end
local function dense_order(order,n)
 if type(order)~='table' or #order~=n then return false end
 local seen={};for _,i in ipairs(order) do
  if type(i)~='number' or i%1~=0 or i<1 or i>n or seen[i] then return false end;seen[i]=true
 end
 return true
end
local function selection(s,a)
 local seen={};local indices=a.indices
 if type(indices)~='table' or #indices<1 or #indices>math.min(5,s.hand_limit or 5) then return false end
 for _,i in ipairs(indices) do if type(i)~='number' or i%1~=0 or not s.hand[i] or seen[i] then return false end;seen[i]=true end
 for i,c in ipairs(s.hand) do if (c.ability or {}).forced_selection and not seen[i] then return false end end
 return (a.kind=='discard' and (s.discards_left or 0) or (s.hands_left or 0))>0
end
local function finish(row)
 assert(m.snapshot.fingerprint(INPUT.snapshot)==original,'Original captured input mutated')
 row.input_unchanged=true;row.mode=INPUT.mode;row.case=INPUT.case;row.policy=INPUT.policy
 return assert(m.player_journal.encode(row))
end
if INPUT.mode=='decision' then
 local r=decide(INPUT.snapshot);local a=r.action or {}
 local audit={status='not_a_card_action'}
 if a.kind=='play' or a.kind=='discard' then
  audit.status=selection(INPUT.snapshot,a) and 'modeled_legal' or 'invalid'
 end
 return finish({status='complete',decision=summary(r),legality=audit})
end
assert(INPUT.mode=='continuation','Unknown evaluation mode')
local s=m.snapshot.copy(INPUT.snapshot)
local initial_left=s.discards_left or 0
local row={status='action_cap',steps={},discards=0,cards_discarded=0,five_card_discards=0,plays=0,
 initial_discards_left=initial_left,world=INPUT.world,sorting=INPUT.sorting,full_run=false}
local seen={};local remaining=INPUT.world_order
local function stop(status,reason)
 row.status=status;row.reason=reason;row.remaining_discards=s.discards_left
 row.chips=s.chips;row.target=(s.blind or {}).chips
 return finish(row)
end
local function refill(next_state,turn)
 local available={};for _,c in ipairs(next_state.deck or {}) do
  if not c.id or available[c.id] then return nil,'Duplicate/missing deck identity' end
  available[c.id]=c
 end
 local ordered={};for _,id in ipairs(remaining) do if available[id] then
  ordered[#ordered+1]=available[id];available[id]=nil
 end end
 if next(available) then return nil,'New unregistered draw-pile identity' end
 local filled,why=m.sampled_outcomes.fill(next_state,ordered,m.scoring,m.draws,INPUT.world_seed,turn)
 if not filled then return nil,why end
 remaining={};for _,c in ipairs(filled.deck) do remaining[#remaining+1]=c.id end
 -- The private hypothetical draw order must NEVER become a policy feature.
 table.sort(filled.deck,function(a,b)return tostring(a.id)<tostring(b.id)end)
 local suits={Spades=4,Hearts=3,Clubs=2,Diamonds=1}
 table.sort(filled.hand,function(a,b)
  local ar,br=a.rank or (a.base or {}).id or 0,b.rank or (b.base or {}).id or 0
  local as,bs=suits[a.suit or (a.base or {}).suit] or 0,suits[b.suit or (b.base or {}).suit] or 0
  if INPUT.sorting=='suit' then if as~=bs then return as>bs end;if ar~=br then return ar>br end
  else if ar~=br then return ar>br end;if as~=bs then return as>bs end end
  return tostring(a.id)<tostring(b.id)
 end)
 return filled
end
for step=1,INPUT.action_cap do
 local key=m.snapshot.fingerprint(s)
 if seen[key] then return stop('loop','Repeated complete public state')end;seen[key]=true
 if (s.hands_left or 0)<=0 then return stop('modeled_failure','Hands exhausted before clear')end
 local r=decide(s);local a=r.action
 row.steps[#row.steps+1]={before_discards=s.discards_left,before_chips=s.chips,decision=summary(r)}
 if not a then return stop('unsupported','No selected action')end
 if a.kind=='reorder_hand' or a.kind=='reorder_jokers' then
  local area=a.kind=='reorder_hand' and 'hand' or 'jokers';local old=s[area]
  if not dense_order(a.order,#old)then return stop('invalid','Malformed reorder')end
  local ordered={};for i,j in ipairs(a.order)do
   if old[j].pinned and i~=j then return stop('unsupported','Pinned reorder')end;ordered[i]=old[j]
  end;s[area]=ordered
 elseif a.kind=='use' and a.area=='consumeables' then
  local next_state,why=m.consumables.apply(s,a.index,a.targets or {})
  if not next_state then return stop('unsupported',tostring(why))end
  s=next_state
 elseif a.kind=='discard' then
  if not selection(s,a)then return stop('invalid','Invalid discard')end
  local next_state,why=m.scoring.after_discard(s,a.indices)
  if not next_state then return stop('unsupported',tostring(why))end
  if next_state.discards_left~=s.discards_left-1 then return stop('invalid','Discard counter conservation')end
  row.discards=row.discards+1;row.cards_discarded=row.cards_discarded+#a.indices
  row.five_card_discards=row.five_card_discards+(#a.indices==5 and 1 or 0)
  s=next_state
  local filled,reason=refill(s,step);if not filled then return stop('unsupported',tostring(reason))end;s=filled
 elseif a.kind=='play' then
  if not selection(s,a)then return stop('invalid','Invalid play')end
  local needed=math.max(1,(s.blind or {}).chips-(s.chips or 0))
  local floor=m.scoring.lower_bound(s,a.indices)
  if floor.legal and not floor.uncertain and floor.reliable_bound and floor.score>=needed then
   row.plays=row.plays+1;row.clear_floor=floor.score
   return stop('supported_clear','Supported immediate floor reaches target; round-end rewards not simulated')
  end
  -- A mean or an owned-Lucky all-failed floor is not a stochastic transition.
  local next_state,effects,actual=m.sampled_outcomes.after_play(s,a.indices,m.scoring,INPUT.world_seed,step)
  if not next_state then return stop('unsupported',tostring(effects))end
  if not actual or not actual.legal or actual.uncertain then return stop('unsupported','Unresolved random scoring transition')end
  row.plays=row.plays+1;s=next_state
  if s.chips>=(s.blind or {}).chips then return stop('supported_clear','Supported sampled transition reaches target')end
  if s.hands_left<=0 then return stop('modeled_failure','Hands exhausted before clear')end
  local filled,reason=refill(s,step);if not filled then return stop('unsupported',tostring(reason))end;s=filled
 else return stop('unsupported','Unsupported action: '..tostring(a.kind))end
end
return stop('action_cap','Eight-action continuation cap')

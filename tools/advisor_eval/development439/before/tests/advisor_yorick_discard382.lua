-- Independently manufactured public states; no saved or captured game state.
local D=dofile('Brainstorm/Advisor/decision.lua')
local G=dofile('Brainstorm/Advisor/growth.lua')
local Search=dofile('Brainstorm/Advisor/search.lua')
local Journal=dofile('Brainstorm/Advisor/player_journal.lua')
local checks=0
local function check(v,m) checks=checks+1;assert(v,m) end
local function eq(a,b,m) check(a==b,m..': '..tostring(a)..' ~= '..tostring(b)) end
local function clone(value)
 if type(value)~='table' then return value end
 local out={};for k,v in pairs(value) do out[k]=clone(v) end;return out
end
local function state()
 local s={phase='hand',teacher_profile='perkeo_yorick_win_v1',ante=1,win_ante=8,
  blind={chips=80},chips=0,dollars=20,hand_size=8,hand_limit=5,hands_left=3,
  hands_played=0,discards_left=3,discards_used=0,current_round={},modifiers={},
  hands={},consumeables={},playing_cards={},hand={},deck={},jokers={{key='j_yorick',
   ability={name='Yorick',x_mult=1,yorick_discards=5,extra={discards=5,xmult=1}}}}}
 local base_ability={bonus=0,d_size=0,effect='Base',extra_value=0,h_dollars=0,h_mult=0,
  h_size=0,h_x_mult=0,hands_played_at_create=0,mult=0,name='Default Base',p_dollars=0,
  perma_bonus=0,set='Default',t_chips=0,t_mult=0,type='',x_mult=1}
 for i=1,8 do s.hand[i]={id='h'..i,key='c_base',rank=i+1,suit='Spades',
  ability=clone(base_ability)} end
 for i=1,12 do s.deck[i]={id='d'..i,key='c_base',rank=13,suit='Hearts',
  ability=clone(base_ability)} end
 return s
end
local score_calls=0
local seen_states,world_signatures={},{}
local scorer={score=function(s,indices)
 score_calls=score_calls+1
 local value=80*((s.jokers[1].ability or {}).x_mult or 1)
 if s.ignore_x then value=80 end
 if s.bad_five and s.last_discard_size==5 then value=0 end
 if s.loss_short and s.last_discard_size and s.last_discard_size<5 then value=60 end
 if s.last_discard_size==5 then
  local drawn={}
  for _,c in ipairs(s.hand) do if c.id:sub(1,1)=='d' then drawn[#drawn+1]=c.id end end
  local signature=table.concat(drawn,',')
  if not seen_states[s] then seen_states[s]=true;world_signatures[signature]=(world_signatures[signature] or 0)+1 end
  if s.bad_signature==signature then value=79 end
 end
 return {score=value,legal=true,uncertain=s.uncertain_redraw and s.last_discard_size~=nil or false,
  hand='High Card',indices=indices,warnings={}}
end,after_discard=function(s,indices)
 local out=clone(s);local removed={}
 for _,i in ipairs(indices) do removed[i]=true end
 out.hand={};for i,c in ipairs(s.hand) do if not removed[i] then out.hand[#out.hand+1]=clone(c) end end
 out.discards_left=s.discards_left-1;out.discards_used=s.discards_used+1
 out.last_discard_size=#indices
 local a=out.jokers[1].ability;a.yorick_discards=a.yorick_discards-#indices
 if a.yorick_discards<=0 then a.yorick_discards=a.yorick_discards+a.extra.discards;a.x_mult=a.x_mult+a.extra.xmult end
 return out,{population_delta=0}
end,lower_bound=function(s,indices)
 score_calls=score_calls+1
 return {score=s.synthetic_floor or 0,legal=true,uncertain=false,reliable_bound=true,
  hand='High Card',indices=indices,warnings={}}
end}
local strategy={build_profile=function()return {horizon=6,final=false}end}
local function run(s,options)
 score_calls=0;seen_states={};world_signatures={}
 local r=D.run(s,{search=Search,scoring=scorer,strategy=strategy},nil,
  {search=options or {samples=24,candidates=5,draw_targets=false,resource_samples=0}})
 eq(r.evaluations,score_calls,'all ordinary and clear work is charged')
 check(r.evaluations<=140000,'ordinary score cap retained')
 return r
end
do
 local s=state();local r=run(s)
 eq(r.action.kind,'discard','early complete paired all-clear comparison may invest')
 eq(#r.action.indices,5,'all-clear benign physical Yorick candidate uses five cards')
 check(r.risky_yorick_clear.selected,'risk receipt names the selected sampled comparison')
 eq(r.risky_yorick_clear.samples,24,'all required common worlds are complete')
 eq(r.risky_yorick_clear.sampled_clears,24,'every sampled next play clears')
 eq(r.discard.prepared.jokers[1].ability.x_mult,2,'actual post-discard Yorick X-Mult enters each forecast')
 check(not r.fast_clear,'opt-in uses the ordinary allowance, not the 70-score path')
 local public=Journal.compact_yorick_review(r)
 eq(public.risk.samples,24,'public scalar review retains paired sample count')
 check(public.risk.selected and public.risk.final_action_matches_search,'public review names settled advice choice')
 local encoded=assert(Journal.encode(public))
 check(not encoded:find('prepared',1,true) and not encoded:find('deck',1,true),
  'public review omits prepared world and hidden draws')
 s.teacher_profile=nil;r=run(s)
 eq(r.action.kind,'play','non-teacher certain clear retains the fast-clear behavior')
 check(r.fast_clear and r.evaluations<=70,'non-teacher fast-clear cap stays at seventy')
end
do
 local s=state();s.bad_five=true
 local r=run(s)
 eq(r.action.kind,'discard','a smaller all-clear growth batch remains possible')
 check(#r.action.indices<5,'a five-card candidate that fails every matched world is rejected')
 check(r.discard.probability==1,'selected shorter batch keeps sampled survival')
 local sizes=Journal.compact_yorick_review(r).risk.by_size
 eq(#sizes,5,'five bounded public size receipts')
 check(sizes[5].compared>0 and sizes[5].qualified==0 and sizes[5].survival==sizes[5].compared,
  'rejected full-five candidates report their actual survival veto, not the shorter winner')
 local compared,qualified=0,0
 for _,row in ipairs(sizes)do compared=compared+row.compared;qualified=qualified+row.qualified end
 eq(compared,r.risky_yorick_clear.candidate_count,'per-size counts cover actual compared family')
 eq(qualified,r.risky_yorick_clear.qualified_count,'qualified counts match actual admission')
end
do
 local s=state();s.blind.chips=100;s.ignore_x=true
 local r=run(s)
 eq(r.action.kind,'discard','below-target win-first can invest when matched survival ties')
 eq(#r.action.indices,5,'below-target ordinary comparison values all five Yorick cards')
 s.teacher_profile=nil;r=run(s)
 eq(r.action.kind,'play','non-teacher below-target objective does not gain the Yorick premium')
end
do
 local s=state();s.ante=5;s.jokers[1].ability.x_mult=10
 local r=run(s)
 eq(r.action.kind,'play','mature late Yorick no longer pays for sampled clear risk')
 check(not r.risky_yorick_clear or not r.risky_yorick_clear.selected,'late decline is explicit')
 check(r.fast_clear and r.evaluations<=70,'mature Yorick keeps the seventy-score fast clear')
end
do
 local s=state()
 for _,c in ipairs(s.hand) do c.enhancement='m_gold' end
 local r=run(s)
 eq(r.action.kind,'play','held Gold resources cannot gain the benign Yorick risk premium')
 s=state();for _,c in ipairs(s.hand) do c.ability.h_x_mult=1.5 end
 r=run(s);eq(r.action.kind,'play','plain-looking held Steel-like effects are not benign')
 s=state();for _,c in ipairs(s.hand) do c.ability.h_dollars=1 end
 r=run(s);eq(r.action.kind,'play','plain-looking held cash effects are not benign')
 s=state();s.modifiers.discard_cost=1;r=run(s)
 eq(r.action.kind,'play','paid discards cannot gain the benign risk premium')
end
do
 local s=state();s.loss_short=true
 local first=run(s)
 eq(#first.action.indices,5,'full physical batch is uniquely useful in manufactured rank test')
 local one
 for signature,count in pairs(world_signatures) do if count==1 then one=signature;break end end
 check(one~=nil,'a unique matched draw world is available to manufacture one miss')
 s.bad_signature=one
 local r=run(s)
 eq(r.action.kind,'discard','Ante-one near-target single miss may justify Yorick growth')
 eq(#r.action.indices,5,'physical threshold still favors full batch')
 eq(r.risky_yorick_clear.samples,24,'one-miss comparison covers twenty-four complete worlds')
 eq(r.risky_yorick_clear.sampled_clears,23,'one world fails after exact Yorick growth')
 s.ante=3;r=run(s)
 eq(r.action.kind,'play','later ante requires every sampled redraw to clear')
 check(r.risky_yorick_clear and not r.risky_yorick_clear.selected,'later risk rejection is recorded')
end
do
 local s=state();s.jokers[2]={key='j_joker',ability={name='Joker',mult=0}}
 score_calls=0
 local result=D.run(s,{search=Search,scoring=scorer,strategy=strategy,
  ordering={suggest=function()return {action={kind='reorder_jokers',area='jokers',order={2,1}}},0,{} end}},nil,
  {search={samples=24,candidates=5,draw_targets=false,resource_samples=0}})
 eq(result.action.kind,'reorder_jokers','ordinary specialist can replace sampled discard')
 check(result.risky_yorick_clear.search_selected and not result.risky_yorick_clear.selected,
  'receipt distinguishes search proposal from final specialist action')
 eq(result.risky_yorick_clear.final_action_kind,'reorder_jokers','receipt names actual advice kind')
 local public=Journal.compact_yorick_review(result)
 check(public.risk.search_selected and not public.risk.selected,
  'public review records specialist displacement without a false executed risk choice')
end
do
 local s=state();s.ante=7;s.jokers[1].ability.x_mult=6;s.blind.chips=70
 local r=run(s)
 eq(r.action.kind,'discard','late 24-world 105% clear may invest a neutral full Yorick batch')
 eq(#r.action.indices,5,'late safe investment still prefers a physical five-card batch')
 check(r.risky_yorick_clear and r.risky_yorick_clear.late_margin and
  r.risky_yorick_clear.samples==24 and r.risky_yorick_clear.sampled_clears==24,
  'late selected risk has complete paired all-clear and margin evidence')
 s.blind.chips=80;s.ignore_x=true;r=run(s)
 eq(r.action.kind,'play','late all-clear forecast without 105% margin keeps current certain clear')
 s.blind.chips=70;s.ignore_x=nil;s.modifiers.discard_cost=1;r=run(s)
 eq(r.action.kind,'play','late paid discards cannot borrow the neutral growth exception')
 s.modifiers.discard_cost=nil;s.uncertain_redraw=true;s.synthetic_floor=72;r=run(s)
 eq(r.action.kind,'play','a random mean over target cannot substitute for a sub-105% certified score floor')
 check(r.risky_yorick_clear and not r.risky_yorick_clear.late_margin,
  'bounded late risk receipt records the rejected supported floor')
 s.synthetic_floor=75;r=run(s)
 eq(r.action.kind,'discard','a supported 105% floor may qualify the same complete redraw family')
end
do
 local s=state();local r=run(s,{samples=24,candidates=5,draw_targets=false,
  resource_samples=0,max_evaluations=500})
 eq(r.action.kind,'play','insufficient complete paired work preserves certain clear')
 check(not r.risky_yorick_clear or not r.risky_yorick_clear.selected,'partial samples cannot qualify')
end
do
 -- Nine-card hands with the ordinary sixteen-candidate shortlist used to
 -- exhaust the allowance after roughly fourteen matched redraw worlds.
 -- This state and its scorer are independently manufactured, not a captured
 -- game observation.
 local s=state();s.hand[9]=clone(s.hand[8]);s.hand[9].id='h9';s.hand[9].rank=10
 s.hand_size=9
 local r=run(s,{samples=24,draw_targets=false,resource_samples=0})
 eq(r.action.kind,'discard','nine-card ordinary shortlist can invest a proven clear')
 eq(#r.action.indices,5,'budget reduction retains a five-card opportunity')
 check(r.search_diagnostics.discard_shortlist_reduced,'only the candidate family is narrowed')
 eq(r.search_diagnostics.yorick_required_samples,24,'required complete-world count is public')
 check(r.search_diagnostics.discard_candidates<16 and r.search_diagnostics.discard_candidates>=2,
  'large and small redraw families remain in the bounded comparison')
 eq(r.risky_yorick_clear.samples,24,'every retained candidate receives twenty-four common worlds')
 eq(r.risky_yorick_clear.candidate_count,r.search_diagnostics.discard_candidates,
  'receipt names exactly the compared candidate family')
 check(r.risky_yorick_clear.qualified_five_count>0 and r.risky_yorick_clear.selected_cards==5,
  'qualified full batch is selected after the complete family')
 check(r.evaluations<=140000,'ordinary score ceiling remains unchanged')
 local public=Journal.compact_yorick_review(r)
 eq(public.risk.candidate_count,r.risky_yorick_clear.candidate_count,
  'public review carries comparison coverage without sampled identities')
 eq(public.risk.selected_cards,5,'public review names the selected physical batch size')
 s.uncertain_redraw=true;s.synthetic_floor=84
 r=run(s,{samples=24,draw_targets=false,resource_samples=0})
 eq(r.action.kind,'discard','floor-probed nine-card family retains a supported clear')
 eq(r.risky_yorick_clear.samples,24,'one extra floor score per trial was budgeted')
 check(r.evaluations<=140000,'floor probes remain inside the same ordinary ceiling')
 r=run(s,{samples=48,draw_targets=false,resource_samples=0})
 eq(r.action.kind,'discard','oversized caller sampling still completes an affordable paired family')
 check(r.search_diagnostics.discard_samples_limited,
  'risky sampling is bounded even when no continuation was reserved')
 check(r.risky_yorick_clear.samples>=24 and r.risky_yorick_clear.samples<48,
  'qualified family uses complete affordable worlds, not a truncated forty-eight')
 check(r.evaluations<=140000,'caller sample request cannot exceed the ordinary score ceiling')
end
do
 -- A Burnt development estimate can make a shorter discard the ordinary
 -- utility leader. It does not mask a separately qualified five-card Yorick
 -- investment with the same complete sampled survival.
 local s=state();s.jokers[2]={key='j_burnt',ability={name='Burnt Joker'}}
 s.hands.Pair={chips=10,mult=1,l_chips=100,l_mult=10,played=10,level=1}
 local burnt_scorer={score=scorer.score,after_discard=scorer.after_discard,
  lower_bound=scorer.lower_bound,
  classify=function(_,indices) return #indices<5 and 'Pair' or 'High Card' end}
 score_calls=0
 local r=Search.run(s,burnt_scorer,{samples=24,candidates=5,draw_targets=false,
  resource_samples=0,fast_clear=false,win_first_yorick_clear_discard=true,
  strategy=strategy})
 eq(r.kind,'discard','individually qualified candidate wins the clear trade')
 check(r.discard_alternatives and #r.discard_alternatives>=5,
  'all compared ordinary and win-first candidates remain auditable')
 local ordinary_best=r.discard_alternatives[1]
 for _,candidate in ipairs(r.discard_alternatives) do
  if candidate.value>ordinary_best.value then ordinary_best=candidate end
 end
 check(#ordinary_best.indices<5,'a shorter batch really is the ordinary utility leader')
 eq(#r.discard.indices,5,'qualified physical Yorick batch is not masked by that leader')
 check(r.risky_yorick_clear.qualified_five_count>0 and
  r.risky_yorick_clear.qualified_count>1,'candidate-wise admission is recorded')
 eq(r.evaluations,score_calls,'candidate-wise admission adds no uncharged scoring')
end
do
 -- A larger ordinary utility is not a certificate for a late clear. The
 -- individually supported 105% floor belongs to the five-card row alone.
 local s=state();s.ante=7;s.blind.chips=70
 s.jokers[2]={key='j_burnt',ability={name='Burnt Joker'}}
 s.hands.Pair={chips=10,mult=1,l_chips=100,l_mult=10,played=10,level=1}
 local late_scorer={after_discard=scorer.after_discard,lower_bound=scorer.lower_bound,
  classify=function(_,indices) return #indices<5 and 'Pair' or 'High Card' end,
  score=function(t,indices)
   local p=scorer.score(t,indices)
   p.score=t.last_discard_size and (t.last_discard_size==5 and 75 or 72) or 80
   return p
  end}
 local r=Search.run(s,late_scorer,{samples=24,candidates=5,draw_targets=false,
  resource_samples=0,fast_clear=false,win_first_yorick_clear_discard=true,
  strategy=strategy})
 eq(r.kind,'discard','late supported five-card floor passes its own admission')
 eq(#r.discard.indices,5,'a higher-value short row below the late margin cannot mask five')
 eq(r.risky_yorick_clear.minimum_score,75,'reported floor is from the selected row')
 eq(r.risky_yorick_clear.qualified_five_count,1,'only the supported-margin five qualifies')
 for _,candidate in ipairs(r.discard_alternatives) do
  eq(candidate.count,24,'each late alternative shares the complete world count')
 end
 s.five_floor=72
 local no_margin={after_discard=late_scorer.after_discard,lower_bound=late_scorer.lower_bound,
  classify=late_scorer.classify,score=function(t,indices)
   local p=late_scorer.score(t,indices)
   if t.last_discard_size==5 then p.score=72 end
   return p
  end}
 r=Search.run(s,no_margin,{samples=24,candidates=5,draw_targets=false,
  resource_samples=0,fast_clear=false,win_first_yorick_clear_discard=true,
  strategy=strategy})
 eq(r.kind,'play','when every late floor misses 105%, preserve the certain clear')
 eq(r.risky_yorick_clear.qualified_count,0,'receipt records no certified alternative')
end
do
 -- The remaining-blind continuation must compare against the actual qualified
 -- candidate, not an ordinary utility leader carried in another field.
 local s=state();s.jokers[2]={key='j_burnt',ability={name='Burnt Joker'}}
 s.hands.Pair={chips=10,mult=1,l_chips=100,l_mult=10,played=10,level=1}
 local continuation_scorer={after_discard=scorer.after_discard,
  classify=function(_,indices) return #indices<5 and 'Pair' or 'High Card' end,
  score=function(t,indices)
   local p=scorer.score(t,indices);p.scoring_indices=clone(indices);return p
  end,
  after_play=function(t)
   local out=clone(t);out.hands_left=out.hands_left-1;out.chips=out.blind.chips
   return out
  end}
 local r=Search.run(s,continuation_scorer,{samples=24,candidates=5,draw_targets=false,
  resource_samples=4,fast_clear=false,win_first_yorick_clear_discard=true,
  strategy=strategy})
 check(r.search_diagnostics.continuation_reserve>0,
  'bounded paired continuation is reserved before discard sampling')
 eq(r.risky_yorick_clear.samples,24,'reservation does not dilute the required redraw worlds')
 check(r.resource_comparison and r.resource_comparison.prior_discard,
  'remaining-blind comparison completed on manufactured supported outcomes')
 eq(table.concat(r.resource_comparison.prior_discard.indices,','),
  table.concat(r.discard.indices,','),'continuation prior is the selected qualified row')
 check(r.risky_yorick_clear.selected,'final risk receipt agrees with continuation result')
end
do
 local s=state();local veto={after_discard=scorer.after_discard,
  score=function(t,indices)
   local p=scorer.score(t,indices);p.scoring_indices=clone(indices);return p
  end,
  after_play=function(t)
   local out=clone(t);out.hands_left=0
   out.chips=t.last_discard_size and 0 or out.blind.chips
   return out
  end}
 local options={samples=24,candidates=5,draw_targets=false,resource_samples=4}
 local r=D.run(s,{search=Search,scoring=veto,strategy=strategy},nil,{search=options})
 eq(r.action.kind,'play','matched remaining-blind loss can veto qualified first-discard risk')
 check(r.resource_comparison and r.resource_comparison.prior.kind=='discard' and
  r.resource_comparison.best.kind=='play',
  'the veto comes from a completed play-versus-discard continuation')
 check(r.risky_yorick_clear.compared and not r.risky_yorick_clear.selected,
  'veto does not masquerade as an accepted Yorick risk')
 eq(r.risky_yorick_clear.final_action_kind,'play',
  'clear-shortcut return stamps the final action after continuation veto')
 check(r.risky_yorick_clear.final_action_matches_search==false and
  r.risky_yorick_clear.search_selected==false,
  'search and settled action flags remain explicit on early return')
 local public=Journal.compact_yorick_review(r)
 eq(public.risk.final_action_kind,'play','public scalar receipt records the veto')
end
do
 -- Hook post-play resolution and a supported uncertain-score floor each cost
 -- one additional evaluation per trial. Their combination must still leave
 -- twenty-four complete paired worlds under the same cap.
 local s=state();s.blind.key='bl_hook';s.uncertain_redraw=true
 local hook_calls=0;score_calls=0
 local hook_scorer={after_discard=scorer.after_discard,score=scorer.score,
  prepare_play=function(t,indices) return t,indices end,
  lower_bound=function(_,indices)
   score_calls=score_calls+1
   return {score=80,legal=true,uncertain=false,reliable_bound=true,
    hand='High Card',indices=indices,warnings={}}
  end}
 local outcomes={context=function()return {hook_indices={}} end,
  after_play=function(t,indices)
   hook_calls=hook_calls+1
   return clone(t),nil,{score=80,legal=true,uncertain=true,
    hand='High Card',indices=clone(indices),warnings={}}
  end}
 local r=Search.run(s,hook_scorer,{samples=24,candidates=5,draw_targets=false,
  resource_samples=0,fast_clear=false,win_first_yorick_clear_discard=true,
  sampled_outcomes=outcomes,strategy=strategy})
 check(hook_calls>0,'Hook resolution was actually exercised')
 eq(r.evaluations,score_calls+hook_calls,'Hook and floor work is charged exactly')
 eq(r.risky_yorick_clear.samples,24,'Hook plus floor completes the minimum common worlds')
 for _,candidate in ipairs(r.discard_alternatives or {}) do
  eq(candidate.count,24,'Hook candidates have identical committed world counts')
 end
 check(r.evaluations<=140000,'combined Hook/floor work stays below ordinary cap')
end
do
 local s=state();s.blind.chips=200
 local selected={score=201,legal=true,uncertain=false,indices={1,2,3,4,5},hand='High Card'}
 local safe={score=220,legal=true,uncertain=false,indices={1,2,3},hand='High Card'}
 local anchor,diag=G.select_clear(s,selected,{safe})
 eq(anchor,safe,'already scored and resource-neutral 105% alternate can anchor growth')
 check(diag.changed and diag.qualified==1,'alternate admission is diagnosed')
 local bad=clone(safe);bad.uncertain=true
 eq(G.select_clear(s,selected,{bad}),selected,'uncertain score cannot anchor growth')
 bad=clone(safe);bad.population_cost=1
 eq(G.select_clear(s,selected,{bad}),selected,'population regression cannot anchor growth')
 bad=clone(safe);bad.warnings={'Unmodeled scoring effect'}
 eq(G.select_clear(s,selected,{bad}),selected,'unsupported scorer warning cannot anchor growth')
 bad=clone(safe);s.hand[1].enhancement='m_mult'
 s.jokers[2]={key='j_greedy_joker',ability={name='Greedy Joker'}}
 eq(G.select_clear(s,selected,{bad}),selected,'order-sensitive alternate cannot anchor growth')
 selected.score=211
 eq(G.select_clear(s,selected,{safe}),selected,'qualified selected clear remains incumbent')
end
print('advisor_yorick_discard382: '..checks..' manufactured checks passed')

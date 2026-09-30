local Runtime=dofile('Brainstorm/Core/jokerless_search_runtime.lua')
local checks=0;local function check(v,label)assert(v,label);checks=checks+1 end
local function fixture(options)
 options=options or {};local calls={search=0,delete=0,start=0,legacy=0,alert=0,exit=0};local now=0;local b
 function calls.advance_time(delta)now=now+delta end
 local g={GAME={challenge='c_jokerless_1',challenge_tab={id='c_jokerless_1',retained='definition'},stake=1},valid=true,signature='catalog1'}
 function g:delete_run()calls.delete=calls.delete+1 end
 function g:start_run(args)calls.start=calls.start+1;calls.args=args;self.GAME={challenge=args.challenge.id,stake=args.stake} end
 local opening={mode='test_detached',catalog=function(x)now=now+(options.catalog_delay or 0);if x.valid then return {signature=x.signature} end;return nil,'invalid fresh state' end,
  catalog_signature=function(c)return c.signature end,seed_at=function(i)return 'SEED'..i end,
  validate_result=function(r)return r.valid end,match=function(r,p)calls.match_predicate=p;return r.matched and r.blue>=p.min_blue and r.steel>=p.min_steel and (p.require_saturn or p.require_planet==r.target_planet) and p.require_telescope end}
 function opening.search(c,o)
  calls.search=calls.search+1;calls.options=o
  now=now+(options.search_delay or 0)
  local count=o.limit;local target=options.target
  local found=target and target>=o.start and target<o.start+count
  if found then count=target-o.start+1 end
  local result={status=found and 'found' or 'not_found',tested=count,next_index=o.start+count,matches={}}
  if found then result.matches[1]={seed='SEED'..target,catalog_signature=c.signature,valid=true,matched=true,blue=options.recipe_blue or 3,steel=options.recipe_steel or 3,
    target_planet=options.wrong_planet or o.require_planet,target_hand=options.wrong_hand or o.target_hand} end
  if options.bad_cursor then result.next_index=result.next_index+1 end
  if options.bad_recipe and found then result.matches[1].valid=false end
  if options.change_during_search then g.signature='changed' end
  if options.replace_during_search then g.GAME={challenge='c_jokerless_1'} end
  if options.cancel_after==calls.search then b.ar_active=false end
  return result
 end
 b={config=options.config,validateChallengeOpening=function()calls.legacy=calls.legacy+1;return 'legacy_validate' end,
  startChallengeOpeningSearch=function()calls.legacy=calls.legacy+1;return 'legacy_start' end,
  stopChallengeOpeningSearch=function()calls.legacy=calls.legacy+1;return 'legacy_stop' end,
  challengeOpeningSearch=function()calls.legacy=calls.legacy+1;return 'legacy_search' end}
 local state=Runtime.attach(b,{opening=opening,get_game=function()return g end,alert=function()calls.alert=calls.alert+1 end,
  now=options.clock or (options.unknown_clock and function()return 0/0 end or function()if not options.manual_clock then now=now+.01 end;return now end),
  batch_size=options.batch_size or 4,max_seeds=options.max_seeds or 10})
 return b,g,state,calls
end
local b,g,state,calls=fixture({target=6})
check(not state.searching and calls.search==0 and calls.delete==0,'attach never starts a search or run')
check(state.preset=='four_kind' and #state.presets==5 and b.config==nil,'default Four of a Kind preset without configuration mutation')
check(state.presets[2].id=='flush' and state.presets[3].id=='two_blue' and state.presets[4].id=='blue_steel' and state.presets[5].id=='three_blue_steel','new targets followed by stable legacy preset order')
b.challengeOpeningSearch('IGNORED');check(calls.search==0,'update without explicit start is inert')
check(b.validateChallengeOpening(),'fresh Jokerless validates')
check(b.startChallengeOpeningSearch(),'user callback starts bounded job')
check(state.searching and state.status=='searching' and b.ar_active,'UI search state exposed')
check(b.challengeOpeningSearch()==nil and state.last.tested==4,'first bounded batch complete')
local definition=g.GAME.challenge_tab
check(b.challengeOpeningSearch()=='SEED6','matching batch applies selected seed')
check(calls.delete==1 and calls.start==1 and calls.args.challenge==definition and calls.args.stake==1,'preserve exact challenge definition and stake')
check(g.GAME.used_filter and not g.GAME.seeded and g.GAME.filter_info.jokerless_opening.seed=='SEED6','existing filtered-run semantics')
check(g.GAME.filter_info.jokerless_catalog_signature=='catalog1','catalog provenance attached')
check(state.status=='found' and not state.searching and state.last.tested==7 and state.next_index==7,'complete bounded accounting retained')
check(state.last.compute_seconds>0,'computation time captured separately')
check(state.last.session_limit==10 and state.last.elapsed_wall_seconds>state.last.compute_seconds and state.last.seeds_per_second>0,
 'ledger separates full wall duration and throughput from detached computation')
check(state.progress_count=='Jokerless: 7 / 10' and state.progress_text=='7 / 10 seeds tested.',
 'completed match retains tested count and job limit for existing UI references')
check(calls.options.require_planet=='c_mars' and calls.options.target_hand=='Four of a Kind' and calls.options.min_blue==2 and calls.options.min_steel==1 and not calls.options.require_saturn,'default binds Mars and exact Blue Steel predicate')
check(g.GAME.filter_info.jokerless_opening.target_planet=='c_mars' and g.GAME.filter_info.jokerless_opening.target_hand=='Four of a Kind','applied recipe retains matching target metadata')
b.challengeOpeningSearch();check(calls.start==1,'match cannot restart run again without a click')
b.startChallengeOpeningSearch();check(state.last.start_index==7,'next user job resumes deterministic cursor')
b.stopChallengeOpeningSearch('user_stopped');check(not state.searching and state.status=='user_stopped','user cancellation explicit')
b.challengeOpeningSearch();check(calls.search==2,'cancelled update inert')
b,g,state,calls=fixture();b.startChallengeOpeningSearch()
for _=1,3 do b.challengeOpeningSearch() end
check(state.status=='not_found' and state.last.tested==10 and calls.search==3,'hard per-job seed cap')
check(calls.options.limit==2 and calls.start==0,'last batch truncates without invented match')
check(state.last.session_limit==10 and state.progress_count=='Jokerless: 10 / 10','completed cap retains exact count and limit')
b,g,state,calls=fixture();g.valid=false
check(not b.startChallengeOpeningSearch() and calls.alert==1 and calls.search==0,'non-fresh run cannot start')
check(state.status=='unavailable' and state.reason=='invalid fresh state' and state.last.reason==state.reason,'failed start exposes actionable reason')
b,g,state,calls=fixture();state.next_index=35^8
check(not b.startChallengeOpeningSearch() and state.status=='exhausted' and state.next_index==35^8,'exhausted range never silently resets')
check(calls.search==0 and calls.start==0 and state.reason:find('exhausted'),'exhaustion explanation and no computation')
b,g,state,calls=fixture();state.next_index=35^8-2;b.startChallengeOpeningSearch();b.challengeOpeningSearch()
check(state.next_index==35^8 and state.last.tested==2 and calls.options.limit==2,'last seed range is bounded exactly')
check(state.last.session_limit==2 and state.progress_count=='Jokerless: 2 / 2','remaining domain becomes the displayed session limit')
check(not b.startChallengeOpeningSearch() and state.status=='exhausted' and calls.search==1,'subsequent click cannot repeat exhausted range')
b,g,state,calls=fixture();state.next_index=0/0
check(not b.startChallengeOpeningSearch() and state.status=='error' and calls.search==0,'invalid cursor fails explicitly')
b,g,state,calls=fixture();b.startChallengeOpeningSearch();g.signature='changed';b.challengeOpeningSearch()
check(state.status=='error' and calls.search==0 and calls.start==0,'catalog drift cancels before computation')
b,g,state,calls=fixture();b.startChallengeOpeningSearch();g.GAME={challenge='c_jokerless_1'};b.challengeOpeningSearch()
check(state.status=='error' and calls.start==0,'new game identity cancels old job')
b,g,state,calls=fixture({target=1,change_during_search=true});b.startChallengeOpeningSearch();b.challengeOpeningSearch()
check(state.status=='error' and calls.start==0,'catalog rechecked before only mutation')
b,g,state,calls=fixture({target=1,bad_cursor=true});b.startChallengeOpeningSearch();b.challengeOpeningSearch()
check(state.status=='error' and calls.start==0,'partial cursor evidence fails closed')
b,g,state,calls=fixture({target=1,bad_recipe=true});b.startChallengeOpeningSearch();b.challengeOpeningSearch()
check(state.status=='error' and calls.start==0,'invalid recipe cannot restart run')
b,g,state,calls=fixture({unknown_clock=true});b.startChallengeOpeningSearch();b.challengeOpeningSearch()
check(state.last.compute_seconds==nil,'unknown timing is not zero')
check(state.last.elapsed_wall_seconds==nil and state.last.seeds_per_second==nil and state.timing_text=='Elapsed time unavailable; rate unavailable.',
 'unknown clock is explicit in wall ledger and display')
do
 local timed_b,_,timed_state,timed_calls=fixture({manual_clock=true,catalog_delay=2,search_delay=0.5})
 timed_b.startChallengeOpeningSearch()
 check(timed_state.last.elapsed_wall_seconds==0 and timed_state.last.seeds_per_second==nil,'zero initial elapsed time has no invented rate')
 timed_calls.advance_time(5);timed_b.challengeOpeningSearch()
 check(timed_state.last.elapsed_wall_seconds==9.5 and timed_state.last.compute_seconds==0.5,
  'wall time includes initial catalog, frame wait, batch catalog and search while compute includes only search')
 check(math.abs(timed_state.last.seeds_per_second-4/9.5)<1e-12 and timed_state.progress_text=='4 / 10 seeds tested.',
  'wall throughput uses actual completed count and elapsed duration')
 timed_calls.advance_time(3);timed_b.challengeOpeningSearch()
 check(timed_state.last.elapsed_wall_seconds==15 and timed_state.last.compute_seconds==1 and timed_state.last.tested==8,
  'multiple frame and catalog waits remain in cumulative wall accounting')
 check(timed_state.timing_text=='15.00s elapsed; 0.5 seeds/s (wall).' and timed_state.compute_text=='1.00s detached search computation.',
  'menu strings distinguish wall throughput and compute cost without time-to-match estimates')
 timed_calls.advance_time(20);timed_b.stopChallengeOpeningSearch('user_stopped')
 check(timed_state.last.elapsed_wall_seconds==15 and timed_state.last.tested==8 and timed_state.progress_count=='Jokerless: 8 / 10',
  'cancellation retains latest batch accounting without counting an unobserved interval or renewing the limit')
 timed_b.startChallengeOpeningSearch()
 check(timed_state.last.start_index==8 and timed_state.last.tested==0 and timed_state.last.elapsed_wall_seconds==0,
  'next explicit job resets elapsed accounting and tested count while preserving cursor')
end
do
 local timed_b,_,timed_state,timed_calls=fixture({manual_clock=true})
 timed_b.startChallengeOpeningSearch();timed_b.challengeOpeningSearch()
 check(timed_state.last.elapsed_wall_seconds==0 and timed_state.last.compute_seconds==0 and timed_state.last.seeds_per_second==nil,
  'zero-duration completed batches preserve zero time and unavailable rate')
 timed_b,_,timed_state,timed_calls=fixture({manual_clock=true,search_delay=0.01})
 timed_b.startChallengeOpeningSearch();timed_calls.advance_time(10);timed_b.challengeOpeningSearch()
 check(timed_state.last.elapsed_wall_seconds==10.01,'valid later clock yields cumulative elapsed time')
 timed_calls.advance_time(-5);timed_b.challengeOpeningSearch()
 check(timed_state.last.elapsed_wall_seconds==nil and timed_state.last.seeds_per_second==nil and timed_state.last.compute_seconds>0,
  'clock regression between batches invalidates wall timing even if each compute interval is locally valid')
end
for _,bad in ipairs({false,0/0,math.huge,-1}) do
 local ticks=0
 local timed_b,_,timed_state=fixture({clock=function()ticks=ticks+1;if ticks==1 then return bad or nil end;return ticks end})
 timed_b.startChallengeOpeningSearch();timed_b.challengeOpeningSearch()
 check(timed_state.last.elapsed_wall_seconds==nil and timed_state.last.seeds_per_second==nil and timed_state.last.compute_seconds==1,
  'missing or invalid start clock never becomes a known wall interval later')
end
do
 local values={10,9,10,11,12,13,14,15,16};local ticks=0
 local timed_b,_,timed_state=fixture({clock=function()ticks=ticks+1;return values[ticks] end})
 timed_b.startChallengeOpeningSearch();timed_b.challengeOpeningSearch();timed_b.challengeOpeningSearch()
 check(timed_state.last.elapsed_wall_seconds==nil and timed_state.last.seeds_per_second==nil and timed_state.last.compute_seconds==2,
  'a backward pre-search timestamp invalidates wall duration permanently despite subsequent recovery')
end
do
 local burst_b,_,burst_state,burst_calls=fixture({manual_clock=true,max_seeds=100})
 burst_b.startChallengeOpeningSearch();burst_b.challengeOpeningSearch()
 check(burst_calls.search==8 and burst_state.last.tested==32 and burst_state.searching,
  'one callback performs at most eight existing batches even if the clock does not advance')
 check(burst_calls.options.limit==4 and burst_state.last.session_limit==100,
  'burst scheduling changes neither the batch size nor the total job cap')
 burst_b,_,burst_state,burst_calls=fixture({manual_clock=true,max_seeds=100,catalog_delay=0.0001,search_delay=0.0021})
 burst_b.startChallengeOpeningSearch();burst_b.challengeOpeningSearch()
 check(burst_calls.search==3 and burst_state.last.tested==12 and burst_state.searching,
  'time slicing yields between complete batches after the six millisecond budget including catalog validation')
 check(burst_state.last.compute_seconds<burst_state.last.elapsed_wall_seconds,
  'short burst still reports detached computation separately from full wall time')
 burst_b,_,burst_state,burst_calls=fixture({manual_clock=true,max_seeds=10})
 burst_b.startChallengeOpeningSearch();burst_b.challengeOpeningSearch()
 check(burst_calls.search==3 and burst_calls.options.limit==2 and burst_state.last.tested==10 and burst_state.status=='not_found',
  'a burst truncates its final batch at the unchanged session cap and stops immediately')
 burst_b,_,burst_state,burst_calls=fixture({manual_clock=true,target=6,max_seeds=100})
 burst_b.startChallengeOpeningSearch()
 check(burst_b.challengeOpeningSearch()=='SEED6' and burst_calls.search==2 and burst_calls.start==1 and burst_calls.delete==1,
  'a burst applies the first deterministic match exactly once and performs no subsequent batch')
 check(burst_state.last.tested==7 and burst_state.next_index==7,'first-match cursor is independent of callback boundaries')
 burst_b,_,burst_state,burst_calls=fixture({manual_clock=true,cancel_after=1,max_seeds=100})
 burst_b.startChallengeOpeningSearch();burst_b.challengeOpeningSearch()
 check(burst_calls.search==1 and burst_state.status=='stopped' and burst_state.next_index==4 and not burst_state.searching,
  'cancellation after a completed batch stops before the next batch without losing completed work')
 for _,options in ipairs({{unknown_clock=true},{manual_clock=true,change_during_search=true},{manual_clock=true,replace_during_search=true}}) do
  options.max_seeds=100;burst_b,_,burst_state,burst_calls=fixture(options)
  burst_b.startChallengeOpeningSearch();burst_b.challengeOpeningSearch()
  check(burst_calls.search==1 and burst_calls.start==0 and burst_state.last.tested==4,
   'unknown clock, catalog drift or replacement cannot cause another search batch in the callback')
  if options.unknown_clock then check(burst_state.searching,'unknown clock falls back to one batch without stopping a valid job')
  else check(burst_state.status=='error' and not burst_state.searching,'every burst batch revalidates catalog and game identity') end
 end
 local ticks=0
 burst_b,_,burst_state,burst_calls=fixture({max_seeds=100,clock=function()ticks=ticks+1;return ticks<=3 and 10 or 9 end})
 burst_b.startChallengeOpeningSearch();burst_b.challengeOpeningSearch()
 check(burst_calls.search==1 and burst_state.searching and burst_state.last.compute_seconds==nil and burst_state.last.elapsed_wall_seconds==nil,
  'regressing batch clock falls back to one batch and preserves explicit unknown timing')
 ticks=0
 burst_b,_,burst_state,burst_calls=fixture({max_seeds=100,clock=function()ticks=ticks+1;return ticks<5 and 10 or 9 end})
 burst_b.startChallengeOpeningSearch();burst_b.challengeOpeningSearch()
 check(burst_calls.search==1 and burst_state.searching and burst_state.last.compute_seconds==0 and burst_state.last.elapsed_wall_seconds==nil and
  burst_state.last.seeds_per_second==nil and burst_state.timing_text=='Elapsed time unavailable; rate unavailable.',
  'a clock regression at the between-batch check immediately invalidates the displayed record as well as future burst scheduling')
end
b,g,state,calls=fixture();g.GAME.challenge='c_omelette_1'
check(b.validateChallengeOpening()=='legacy_validate','other challenge validation delegated')
check(b.startChallengeOpeningSearch()=='legacy_start','other challenge start delegated')
check(b.challengeOpeningSearch('seed')=='legacy_search','other challenge search delegated')
check(b.stopChallengeOpeningSearch()=='legacy_stop','other challenge stop delegated')
check(calls.search==0 and calls.delete==0,'no Jokerless action in other challenges')
b,g,state,calls=fixture({config={jokerless_opening_search={preset='unknown'}}})
check(state.preset=='four_kind' and b.config.jokerless_opening_search.preset=='unknown','invalid persisted preset defaults only in memory')
b,g,state,calls=fixture({config={jokerless_opening_search={preset='blue_steel'}},target=1})
check(state.preset=='blue_steel','valid configured preset loaded')
b.startChallengeOpeningSearch();b.challengeOpeningSearch()
check(calls.options.min_blue==2 and calls.options.min_steel==1 and calls.options.limit==4,'Blue Steel predicate uses original bounded batch')
check(calls.options.require_saturn and not calls.options.require_planet and not g.GAME.filter_info.jokerless_opening.target_planet,'persisted legacy preset retains Saturn predicate and unbound recipe format')
check(state.last.preset=='blue_steel' and state.last.predicate.min_steel==1,'completed result records selected predicate')
b,g,state,calls=fixture({config={jokerless_opening_search={preset='three_blue_steel'}},target=6})
b.startChallengeOpeningSearch();b.challengeOpeningSearch()
check(calls.options.min_blue==3 and calls.options.min_steel==3,'three Blue Steel predicate selected')
state.preset='two_blue';b.config.jokerless_opening_search.preset='two_blue';state.presets[5].min_blue=0
state.last.predicate.min_blue=0;calls.options.min_steel=0
b.challengeOpeningSearch()
check(calls.options.min_blue==3 and calls.options.min_steel==3 and calls.match_predicate.min_blue==3 and calls.match_predicate.min_steel==3,'in-flight predicate cannot change through config UI results or prior search options')
check(state.last.preset=='three_blue_steel' and state.last.predicate.min_blue==3 and state.last.tested==7,'immutable preset and complete shared cursor recorded')
b.startChallengeOpeningSearch()
check(state.last.preset=='two_blue' and state.last.start_index==7,'next user job may select another preset without resetting cursor')
b,g,state,calls=fixture({config={jokerless_opening_search={preset='three_blue_steel'}},target=1,recipe_blue=2,recipe_steel=1})
b.startChallengeOpeningSearch();b.challengeOpeningSearch()
check(state.status=='error' and calls.start==0,'candidate must meet the exact selected stronger predicate')
b,g,state,calls=fixture({config={jokerless_opening_search={preset='flush'}},target=6})
b.startChallengeOpeningSearch();b.challengeOpeningSearch()
state.preset='four_kind';b.config.jokerless_opening_search.preset='four_kind';state.presets[2].require_planet='c_mars'
state.last.predicate.require_planet='c_mars';calls.options.target_hand='Four of a Kind'
b.challengeOpeningSearch()
check(state.status=='found' and calls.options.require_planet=='c_jupiter' and calls.options.target_hand=='Flush' and not calls.options.require_saturn,'selected Flush target remains frozen across batches')
check(state.last.preset=='flush' and state.last.predicate.require_planet=='c_jupiter' and g.GAME.filter_info.jokerless_opening.target_hand=='Flush','completed Flush recipe and provenance remain bound')
for _,options in ipairs({{wrong_planet='c_jupiter'},{wrong_hand='Flush'},{recipe_steel=0}}) do
 options.target=1;b,g,state,calls=fixture(options);b.startChallengeOpeningSearch();b.challengeOpeningSearch()
 check(state.status=='error' and calls.start==0,'wrong target or missing required Steel fails before run mutation')
end
print('advisor_jokerless_search_runtime: '..checks..' checks passed')

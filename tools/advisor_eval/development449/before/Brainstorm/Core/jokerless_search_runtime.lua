-- Product UI adapter. Merely loading/attaching never starts a search or a run.
local M={}
local function whole(n,lo,hi) return type(n)=='number' and n==n and n%1==0 and n>=lo and n<=hi end
local presets={
  {id='four_kind',label='Four of a Kind + Blue Steel',min_blue=2,min_steel=1,require_planet='c_mars',target_hand='Four of a Kind',
    description='Coupon, two Blue seals including a Steel, Mars and Telescope. Develop Four of a Kind; survival is unknown.'},
  {id='flush',label='Flush + Blue Steel',min_blue=2,min_steel=1,require_planet='c_jupiter',target_hand='Flush',
    description='Coupon, two Blue seals including a Steel, Jupiter and Telescope. Develop Flush; survival is unknown.'},
  {id='two_blue',label='Straight: two Blue seals',min_blue=2,min_steel=0,
    description='Coupon, two Blue seals, Saturn and Telescope. Survival is unknown.'},
  {id='blue_steel',label='Straight: Blue + Steel (rare)',min_blue=2,min_steel=1,
    description='Two Blue seals, at least one Steel, plus Saturn and Telescope. Rarer; survival is unknown.'},
  {id='three_blue_steel',label='Straight: three Blue Steel (very rare)',min_blue=3,min_steel=3,
    description='Three selectable Blue Steel cards, Saturn and Telescope. Very rare; survival is unknown.'},
}
local function shallow(t)local out={};for key,value in pairs(t or {})do out[key]=value end;return out end
local function count_text(n)
  return string.format('%.0f',n):reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')
end
local function preset_for(id)for _,p in ipairs(presets)do if p.id==id then return p end end;return presets[1] end
local function predicate_for(p)
  local predicate={min_blue=p.min_blue,min_steel=p.min_steel,require_coupon=true,require_telescope=true}
  if p.require_planet then predicate.require_planet=p.require_planet;predicate.target_hand=p.target_hand
  else predicate.require_saturn=true end
  return predicate
end
function M.attach(brainstorm,deps)
  deps=deps or {};local opening=assert(deps.opening,'Jokerless opening module required')
  local surface=deps.get_game or function()return G end
  local old={validate=brainstorm.validateChallengeOpening,start=brainstorm.startChallengeOpeningSearch,
    stop=brainstorm.stopChallengeOpeningSearch,search=brainstorm.challengeOpeningSearch}
  local config=type(brainstorm.config)=='table' and brainstorm.config.jokerless_opening_search
  local configured=type(config)=='table' and config.preset
  local state={status='idle',searching=false,next_index=0,last=nil,preset=preset_for(configured).id,presets={},
    progress_count='Jokerless: ready',progress_text='No opening search started.',
    timing_text='Elapsed time unavailable; rate unavailable.',compute_text='Search computation unavailable.'}
  for i,p in ipairs(presets)do state.presets[i]=shallow(p) end
  brainstorm.JokerlessOpeningSearch=state
  local session
  local batch=whole(deps.batch_size,1,1024) and deps.batch_size or 512
  local maximum=whole(deps.max_seeds,1,1000000) and deps.max_seeds or 1000000
  -- Check this time budget between complete batches. One batch may exceed it.
  local callback_limit,callback_seconds=8,0.006
  local function is_jokerless(g) return g and g.GAME and g.GAME.challenge=='c_jokerless_1' end
  local function clock()
    if type(deps.now)~='function' then return nil end
    local ok,n=pcall(deps.now);if ok and type(n)=='number' and n==n and n>=0 and n<math.huge then return n end
  end
  local function alert(reason) if type(deps.alert)=='function' then deps.alert(reason) end end
  local function observe_wall(now)
    if session and session.wall_known then
      if not now or now<session.wall_latest then session.wall_known=false
      else session.wall_latest=now end
    end
  end
  local function progress(record)
    local count=count_text(record.tested)
    if record.session_limit then count=count..' / '..count_text(record.session_limit) end
    state.progress_count='Jokerless: '..count
    state.progress_text=count..' seeds tested.'
    state.timing_text=record.elapsed_wall_seconds and string.format('%.2fs elapsed; ',record.elapsed_wall_seconds) or 'Elapsed time unavailable; '
    state.timing_text=state.timing_text..(record.seeds_per_second and string.format('%.1f seeds/s (wall).',record.seeds_per_second) or 'rate unavailable.')
    state.compute_text=record.compute_seconds and string.format('%.2fs detached search computation.',record.compute_seconds) or 'Search computation unavailable.'
  end
  local function record(status,reason,result)
    local selected=preset_for(state.preset)
    local elapsed=session and session.wall_known and session.wall_latest-session.wall_started or nil
    local rate=elapsed and elapsed>0 and session.tested/elapsed or nil
    if rate and rate==math.huge then rate=nil end
    local out={status=status,reason=reason,result=result,mode=opening.mode,challenge_id='c_jokerless_1',qualification=false,
      preset=session and session.preset or selected.id,predicate=shallow(session and session.predicate or predicate_for(selected)),
      tested=session and session.tested or 0,batches=session and session.batches or 0,
      session_limit=session and session.limit or nil,elapsed_wall_seconds=elapsed,seeds_per_second=rate,
      start_index=session and session.start or state.next_index,next_index=session and session.cursor or state.next_index,
      compute_seconds=session and session.seconds_known and session.seconds or nil,
      elapsed_scope='Wall time from user start through the latest batch timestamp; includes catalog checks and waits between batches, excludes later gameplay.',
      scope='Detached opening-search computation only; excludes gameplay, setup, user actions and later outcomes.'}
    progress(out);return out
  end
  local function stop(status,reason,result)
    state.last=record(status or 'stopped',reason,result);state.status=state.last.status;state.reason=reason
    if session then state.next_index=session.cursor end
    state.searching=false;session=nil;brainstorm.ar_active=false;brainstorm.ar_frames=0;brainstorm.ar_timer=0
    if brainstorm.ar_text and type(brainstorm.removeAttentionText)=='function' then brainstorm.removeAttentionText(brainstorm.ar_text);brainstorm.ar_text=nil end
  end
  function brainstorm.validateChallengeOpening(...)
    local g=surface();if not is_jokerless(g) then if old.validate then return old.validate(...) end;return false,'Start a challenge first.' end
    local catalog,reason=opening.catalog(g)
    if not catalog then return false,reason end
    return true,preset_for(session and session.preset or state.preset).description,catalog
  end
  function brainstorm.stopChallengeOpeningSearch(status,reason,...)
    if session or state.searching then return stop(status,reason) end
    if old.stop then return old.stop(status,reason,...) end
  end
  function brainstorm.startChallengeOpeningSearch(...)
    local g=surface();if not is_jokerless(g) then if old.start then return old.start(...) end;return false end
    local started=clock()
    local catalog,reason=opening.catalog(g);if not catalog then stop('unavailable',reason);alert(reason);return false end
    if session then stop('replaced') elseif old.stop then old.stop('replaced') end
    if not whole(state.next_index,0,35^8) then
      local detail='The deterministic search cursor is invalid.';stop('error',detail);alert(detail);return false
    end
    if state.next_index==35^8 then
      local detail='The deterministic seed range is exhausted; no seeds were repeated.';stop('exhausted',detail);alert(detail);return false
    end
    local cap=math.min(maximum,35^8-state.next_index)
    local selected=preset_for(state.preset);state.preset=selected.id
    session={game=g.GAME,catalog=catalog,signature=opening.catalog_signature(catalog),start=state.next_index,cursor=state.next_index,
      tested=0,batches=0,limit=cap,seconds=0,seconds_known=true,preset=selected.id,predicate=predicate_for(selected),
      wall_started=started,wall_latest=started,wall_known=started~=nil}
    state.status='searching';state.reason=nil;state.searching=true;state.last=record('searching')
    brainstorm.ar_active=true;brainstorm.ar_frames=0;brainstorm.ar_timer=0
    if g.OVERLAY_MENU and g.FUNCS and type(g.FUNCS.exit_overlay_menu)=='function' then g.FUNCS.exit_overlay_menu() end
    return true
  end
  local function search_batch()
    local function fail(reason) stop('error',reason);alert(reason);return nil end
    if not brainstorm.ar_active then stop('stopped');return nil end
    local g=surface();local catalog,reason=opening.catalog(g)
    if not catalog or not g or g.GAME~=session.game or opening.catalog_signature(catalog)~=session.signature then
      return fail(reason or 'The fresh run or opening catalog changed during search.') end
    local remaining=session.limit-session.tested
    if remaining<=0 then stop('not_found','No matching opening in this bounded search.');return nil end
    local before=clock();observe_wall(before)
    local options=shallow(session.predicate);options.start=session.cursor;options.limit=math.min(batch,remaining);options.max_matches=1
    local ok,result,why=pcall(opening.search,session.catalog,options)
    local after=clock();observe_wall(after)
    if before and after and after>=before then session.seconds=session.seconds+after-before else session.seconds_known=false end
    if not ok or not result then return fail('Detached opening search failed: '..tostring(ok and why or result)) end
    if not whole(result.tested,0,math.min(batch,remaining)) or result.next_index~=session.cursor+result.tested then
      return fail('The search returned incomplete or inconsistent cursor evidence.') end
    session.batches=session.batches+1;session.tested=session.tested+result.tested;session.cursor=result.next_index
    if result.status=='not_found' then
      state.last=record('searching');if session.tested>=session.limit then stop('not_found','No matching opening in this bounded search.') end
      return nil
    end
    if result.status~='found' or type(result.matches)~='table' or #result.matches~=1 then return fail(result.reason or 'Unsupported opening search result.') end
    local recipe=result.matches[1]
    if (session.predicate.require_planet and (recipe.target_planet~=session.predicate.require_planet or recipe.target_hand~=session.predicate.target_hand)) or
      not opening.validate_result(recipe) or not opening.match(recipe,shallow(session.predicate)) or
      recipe.catalog_signature~=session.signature or recipe.seed~=opening.seed_at(session.cursor-1) then
      return fail('The matching opening did not validate against this search.') end
    local fresh,detail=opening.catalog(g)
    if surface()~=g or g.GAME~=session.game or not fresh or opening.catalog_signature(fresh)~=session.signature then
      return fail(detail or 'The run changed before the opening could be applied.') end
    local definition,stake=g.GAME.challenge_tab,g.GAME.stake or 1
    stop('found',nil,recipe)
    -- This is the existing user-clicked filtered-run product operation. Tools
    -- never invoke it; the current challenge definition and stake are retained.
    g:delete_run();g:start_run({stake=stake,seed=recipe.seed,challenge=definition})
    g.GAME.used_filter=true;g.GAME.seeded=false
    g.GAME.filter_info={jokerless_opening=recipe,jokerless_catalog_signature=recipe.catalog_signature,
      challenge_id='c_jokerless_1',search=state.last}
    return recipe.seed
  end
  function brainstorm.challengeOpeningSearch(...)
    if not session then if not is_jokerless(surface()) and old.search then return old.search(...) end;return nil end
    local began=clock();observe_wall(began)
    for index=1,callback_limit do
      local result=search_batch()
      if result~=nil or not session then return result end
      if not brainstorm.ar_active then stop('stopped');return nil end
      if index==callback_limit then return nil end
      local now=clock();observe_wall(now)
      state.last=record('searching')
      if not began or not now or not session.wall_known or now-began>=callback_seconds then return nil end
    end
  end
  return state
end
return M

-- Source callback receipts for normal-deck progress. Synthetic profile only;
-- GAME.won is an observation, never sufficient evidence of terminal success.
local M={}
local function count(g,kind,key)
  local profile=(g.PROFILES or {})[(g.SETTINGS or {}).profile] or {}
  local usage=(profile[kind] or {})[key] or {};local wins=usage.wins or {}
  return tonumber(wins[(g.GAME or {}).stake]) or 0
end
function M.classify(e)
  if e.game_over then return 'loss' end
  if not e.final_boss or not e.source_won or not e.deck_progress or not e.joker_progress then return nil end
  if not e.threshold_met and not e.source_saved then return nil end
  return 'win'
end
function M.attach(g,trace,copy)
  local S={callbacks={},deck_progress=false,joker_progress=false,source_saved=false}
  local function info()
    local game=g.GAME;local key=game.selected_back and game.selected_back.effect and game.selected_back.effect.center.key
    local held={};for _,card in ipairs(g.jokers and g.jokers.cards or {}) do
      local center=card.config and card.config.center; if center and center.key then held[center.key]=count(g,'joker_usage',center.key) end
    end
    return {deck=key,stake=game.stake,deck_wins=count(g,'deck_usage',key),jokers=held,
      ante=(game.round_resets or {}).ante,round=game.round,win_ante=game.win_ante,boss=not not (game.blind or {}).boss,
      chips=game.chips,target=(game.blind or {}).chips,source_won=not not game.won,state=g.STATE,
      seeded=not not game.seeded,challenge=game.challenge}
  end
  local finish_round=assert(_G.end_round,'HEADLESS_BOUNDARY original end_round missing')
  _G.end_round=function(...)
    local before=info()
    if before.boss and before.ante==before.win_ante then
      S.final_context=copy(before)
      trace({type='engine_normal_final_round_entered',context=before})
    end
    return finish_round(...)
  end
  for _,name in ipairs({'set_deck_win','set_joker_win'}) do
    local original=assert(_G[name],'HEADLESS_BOUNDARY original progress callback missing: '..name)
    _G[name]=function(...)
      local before=info()
      local function packed(...)return {n=select('#',...),...} end
      local result=packed(original(...));local after=info()
      local changed=false
      if name=='set_deck_win' then
        changed=after.deck==before.deck and after.deck_wins>before.deck_wins
        if changed then S.deck_progress=true end
      else
        changed=true
        for key,n in pairs(before.jokers) do if (after.jokers[key] or 0)<=n then changed=false end end
        if changed then S.joker_progress=true end
      end
      S.callbacks[#S.callbacks+1]={name=name,before=copy(before),after=copy(after),progress_verified=changed}
      trace({type='engine_normal_progress_callback',callback=name,before=before,after=after,progress_verified=changed})
      return unpack(result,1,result.n)
    end
  end
  -- The original context is passed to every Joker, including copy effects. Only
  -- the original calculation's explicit saved result can qualify an under-target
  -- terminal exception; possession of Mr Bones or GAME.won alone cannot.
  local calculate=assert(Card.calculate_joker)
  function Card:calculate_joker(context,...)
    local result=calculate(self,context,...)
    if context and context.end_of_round and type(result)=='table' and result.saved==true then
      S.source_saved=true;S.saved_context=info()
      trace({type='engine_normal_source_saved',key=self.config and self.config.center and self.config.center.key,
        chips=g.GAME.chips,target=(g.GAME.blind or {}).chips,ante=(g.GAME.round_resets or {}).ante})
    end
    return result
  end
  function S:evidence()
    local current=info();local final=self.final_context or current
    return {game_over=g.STATE==g.STATES.GAME_OVER,source_won=current.source_won,
      final_boss=final.boss and final.ante==final.win_ante,threshold_met=type(final.chips)=='number' and
        type(final.target)=='number' and final.target>0 and final.chips>=final.target,
      source_saved=self.source_saved and self.saved_context.ante==final.ante and self.saved_context.round==final.round,
      deck_progress=self.deck_progress,joker_progress=self.joker_progress,
      final_context=copy(final),callbacks=copy(self.callbacks)}
  end
  function S:completed()return M.classify(self:evidence())=='win' end
  return S
end
return M

local base='Brainstorm/Advisor/'
local journal=dofile(base..'player_journal.lua');local hooks=dofile(base..'acorn_public_hooks.lua')
local registry=dofile('tools/advisor_eval/development333/observer_component/callback_hooks.lua')
local callbacks={'play_cards_from_highlighted','discard_cards_from_highlighted','buy_from_shop','use_card','sell_card','select_blind','cash_out','toggle_shop'}
local function run(label,J,H,R)
  local g={GAME={},CONTROLLER={locks={}},jokers={cards={}},hand={cards={},highlighted={}},FUNCS={}}
  for _,name in ipairs(callbacks)do g.FUNCS[name]=function()end end
  local t={reset=function()end,invalidate=function()end,begin_action=function()end,sync=function()end,drag_active=function()return false end,drag_finish=function()end}
  local a={callback_hooks=R};G=g
  local j=J.attach(a,{config={advisor={player_logging=false}}},{game=function()return g end,append=function()error('logging off')end})
  local h=H.attach(t,{env={G=g},game=function()return g end,callback_hooks=R})
  collectgarbage('collect');local before=collectgarbage('count');local changes=0
  for i=1,1000 do
    local old={};for _,name in ipairs(callbacks)do old[name]=g.FUNCS[name]end
    j:install_hooks(g)
    for _,name in ipairs(callbacks)do if old[name]~=g.FUNCS[name]then changes=changes+1 end;old[name]=g.FUNCS[name]end
    h:update()
    for _,name in ipairs(callbacks)do if old[name]~=g.FUNCS[name]then changes=changes+1 end end
  end
  collectgarbage('collect');local after=collectgarbage('count')
  print(label..': idle_ticks=1000 retained_entrypoint_replacements='..changes..' collected_memory_delta_KiB='..(after-before))
end
run('baseline332',journal,hooks)
run('candidate333',dofile('tools/advisor_eval/development333/logger_component/player_journal.lua'),dofile('tools/advisor_eval/development333/observer_component/acorn_public_hooks.lua'),registry.new())

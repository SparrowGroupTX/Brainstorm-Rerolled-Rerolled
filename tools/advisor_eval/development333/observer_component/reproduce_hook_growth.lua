local base='Brainstorm/Advisor/'
local journal=dofile(base..'player_journal.lua')
local hooks=dofile(base..'acorn_public_hooks.lua')
for _,ticks in ipairs({0,10,50,100})do
  local calls,begins,events=0,0,0
  local g={GAME={},CONTROLLER={locks={}},jokers={cards={}},hand={cards={},highlighted={}},FUNCS={}}
  g.FUNCS.play_cards_from_highlighted=function()calls=calls+1;return 'played'end
  G=g
  local a={};local b={config={advisor={player_logging=true}}}
  local j=journal.attach(a,b,{game=function()return g end,observe=function()return {}end,
    now=function()return 'fixture'end,clock=function()return 1 end,
    append=function()events=events+1;return true end,notice=function()end})
  local t={reset=function()end,invalidate=function()end,begin_action=function()begins=begins+1 end,
    sync=function()end,drag_active=function()return false end,drag_finish=function()end}
  local h=hooks.attach(t,{env={G=g},game=function()return g end})
  for i=1,ticks do j:install_hooks(g);h:update()end
  local ok,why=pcall(g.FUNCS.play_cards_from_highlighted)
  print('ticks='..ticks..' callback='..calls..' begin_action='..begins..' journal_events='..events..' accepted='..tostring(ok)..' reason='..tostring(why))
end

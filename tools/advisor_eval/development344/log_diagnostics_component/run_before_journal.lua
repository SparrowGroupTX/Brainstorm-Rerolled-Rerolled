local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/player_journal.lua' then return original('tools/advisor_eval/development344/log_diagnostics_component/before/Brainstorm/Advisor/player_journal.lua') end
  return original(path)
end
original('tests/advisor_player_journal.lua')

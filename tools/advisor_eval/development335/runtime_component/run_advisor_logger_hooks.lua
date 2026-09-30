local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/player_journal.lua' then
    return original('tools/advisor_eval/development335/runtime_component/player_journal.lua')
  end
  return original(path)
end
original('tests/advisor_logger_hooks.lua')

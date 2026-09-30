local original=dofile
dofile=function(path)
  if path=='Brainstorm/Advisor/player_journal.lua'then
    return original('tools/advisor_eval/development324/journal_timing/player_journal.lua')
  end
  return original(path)
end
dofile('tools/advisor_eval/development324/journal_timing/test_player_journal_timing.lua')
dofile('tests/advisor_player_journal.lua')

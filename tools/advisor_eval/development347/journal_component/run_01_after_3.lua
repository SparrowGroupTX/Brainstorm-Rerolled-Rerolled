local original=dofile
dofile=function(path)
 if path=='Brainstorm/Advisor/player_journal.lua' then return original('tools/advisor_eval/development347/journal_component/Brainstorm/Advisor/player_journal.lua') end
 return original(path)
end
dofile('tests/advisor_player_journal_timing.lua')

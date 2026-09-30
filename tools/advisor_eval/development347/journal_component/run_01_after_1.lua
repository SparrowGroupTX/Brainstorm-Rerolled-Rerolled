local original=dofile
dofile=function(path)
 if path=='Brainstorm/Advisor/player_journal.lua' then return original('tools/advisor_eval/development347/journal_component/Brainstorm/Advisor/player_journal.lua') end
 return original(path)
end
dofile('tools/advisor_eval/development347/journal_component/tests/advisor_gold_journal.lua')

local old=dofile;dofile=function(p)if p=='Brainstorm/Advisor/auto_run.lua'then p='tools/advisor_eval/development348/log_projection_component/before/Brainstorm/Advisor/auto_run.lua'end;return old(p)end
dofile('tools/advisor_eval/development348/log_projection_component/tests/advisor_auto_log_projection.lua')

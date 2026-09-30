local root='tools/advisor_eval/development325/input_ui/'
local paths={['Brainstorm/Core/Brainstorm.lua']='Brainstorm.lua',['Brainstorm/UI/advisor.lua']='advisor.lua',
  ['Brainstorm/UI/collection_run.lua']='collection_run.lua',['Brainstorm/Advisor/runtime.lua']='runtime.lua',
  ['Brainstorm/Core/checkpoint_runtime.lua']='checkpoint_runtime.lua'}
local old_open,old_dofile=io.open,dofile
io.open=function(path,...)return old_open(paths[path]and root..paths[path]or path,...)end
dofile=function(path)return old_dofile(paths[path]and root..paths[path]or path)end
dofile('tests/advisor_gold_layout.lua')

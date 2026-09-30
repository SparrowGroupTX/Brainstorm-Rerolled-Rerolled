local original=dofile
dofile=function(path)
  if path=='Brainstorm/Core/auto_run_product.lua' then
    return original('tools/advisor_eval/development323/auto_observation/auto_run_product.lua')
  end
  return original(path)
end
original('tests/advisor_auto_run_product.lua')
original('tests/advisor_auto_run.lua')

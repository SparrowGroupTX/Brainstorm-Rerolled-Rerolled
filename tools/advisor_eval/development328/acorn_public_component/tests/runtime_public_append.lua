do
  local A=setup();local s=A.snapshot.capture(G)
  A.joker_names=function()error('Hidden Joker name formatter must not be called')end
  A.present(s,{strategy={title='Public order',lines={},warnings={}},
    public_joker_belief={supported=true,worlds=2},action={kind='reorder_jokers',order={3,1,2}},
    play={score=500},evaluations=20},true)
  equal(A.display.status,'Public Joker score floor','Concealed row receives explicit conservative UI status')
  local lines=table.concat(A.lines,'\n')
  check(lines:find('#3, #1, #2',1,true),'Display references current physical slots without guessed names')
  check(lines:find('Lowest supported score across 2 possible rows: 500 chips.',1,true),'UI presents minimum over public worlds')
  A.present(s,{strategy={title='Unavailable',lines={'Unsupported public state'},warnings={}},
    public_joker_belief={supported=false},action=nil},true)
  equal(A.display.status,'Public Joker advice unavailable','No unsupported fallback masquerades as exact advice')
end
print('advisor_public_runtime_total: '..checks..' checks passed')

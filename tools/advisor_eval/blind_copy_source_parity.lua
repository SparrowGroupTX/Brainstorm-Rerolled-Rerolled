-- Appended to the frozen blind-start parity harness; its run(row) executes the
-- original callbacks and compares complete resource/population/Joker outcomes.
local Prep=dofile(PREP_MODULE);Prep.blind_start=Start
local proposals=0
local function prepare(row)
  local s={phase='blind',jokers=copy(row),playing_cards={},hand_size=8,joker_limit=5,
    hands_left=3,discards_left=4,current_round={hands_left=3,discards_left=4},
    consumeables={},modifiers={},hands={},blind={key='bl_small',boss=false}}
  for i=1,52 do s.playing_cards[i]={id=i,rank=2+(i-1)%13,suit='Spades',ability={}} end
  local proposal,diagnostics=Prep.suggest(s)
  assert(proposal,'expected executable source fixture preparation')
  assert(diagnostics.complete and diagnostics.orders<=64,'complete bounded preparation')
  proposals=proposals+1
  local ordered={};for i,index in ipairs(proposal.action.order) do ordered[i]=copy(row[index]) end
  run(copy(row));run(ordered)
end
prepare({b(),joker('j_blueprint')})
prepare({joker('j_brainstorm'),b()})
prepare({joker('j_brainstorm'),b(),joker('j_blueprint')})
prepare({b(),joker('j_blueprint'),joker('j_blueprint')})
prepare({m(),joker('j_hologram',{x_mult=1,extra=.25}),joker('j_blueprint')})
prepare({joker('j_brainstorm'),m(),joker('j_hologram',{x_mult=1,extra=.25})})
print('blind-copy source parity: '..proposals..' proposals, '..cases..' cases, '..checks..' comparisons')

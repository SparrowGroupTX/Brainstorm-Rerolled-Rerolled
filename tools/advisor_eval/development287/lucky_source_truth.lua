-- Bounded conditional source-method comparison. The source eval_card/Card
-- methods are supplied by the registered builder; event scheduling and final
-- chips/mult/cash arithmetic below are explicit test doubles, not source phase
-- qualification. This file does not start a game, draw seeds, or read saves.
local M={}
function M.run(mode,emit)
  assert(mode=='ordinary' or mode=='red','Unknown Lucky truth-table mode')
  local S=assert(POLICY_SCORING,'Missing frozen scoring module')
  local Snapshot=assert(POLICY_SNAPSHOT,'Missing frozen snapshot module')
  assert(type(Card)=='table' and type(eval_card)=='function','Missing registered source methods')
  local repeats=mode=='red' and 2 or 1
  local cases=mode=='red' and 16 or 4
  local rows={}
  emit=emit or function() end
  for pattern=0,cases-1 do
    local events,queue,timeline={},{},{}
    for evaluation=1,repeats do
      events[evaluation]={mult=math.floor(pattern/2^((evaluation-1)*2))%2==1,
        dollars=math.floor(pattern/2^((evaluation-1)*2+1))%2==1}
    end
    local held={id='lucky:king',rank=13,suit='Spades',enhancement='m_lucky',ability={},
      seal=mode=='red' and 'Red' or nil}
    local state={phase='hand',ante=2,hand={held},deck={},playing_cards={held},jokers={},
      consumeables={},consumable_limit=2,hands_left=3,hands_played=1,discards_left=2,
      discards_used=0,hand_size=8,hand_limit=5,chips=0,dollars=10,
      blind={key='bl_small',chips=10000},current_round={},probabilities={normal=1},modifiers={}}
    local before=Snapshot.fingerprint(state)
    local projected,effects,actual=S.after_play(state,{1},{lucky_outcomes={[1]=events}})
    assert(projected and effects and actual and not actual.uncertain,'Unsupported advisor Lucky transition')
    assert(Snapshot.fingerprint(state)==before,'Advisor mutated truth-table input')
    assert(projected.hands_left==2 and projected.discards_left==2,'Advisor changed wrong resources')
    assert(#projected.playing_cards==1 and #projected.consumeables==0,'Advisor changed population/inventory')
    G={GAME={probabilities={normal=1},dollars=10,dollar_buffer=0},play={cards={}},hand={cards={}},
      jokers={cards={}},consumeables={cards={}},C={}}
    G.E_MANAGER={add_event=function(_,e)
      assert(type(e)=='table' and type(e.func)=='function','Unexpected source event')
      queue[#queue+1]=e
      timeline[#timeline+1]={kind='queue_buffer_reset',dollars=G.GAME.dollars,buffer=G.GAME.dollar_buffer}
    end}
    Event=function(e) return e end
    localize=function(key) assert(key=='k_again_ex','Unexpected localization');return key end
    local calls=0
    pseudorandom=function(key,...)
      assert(select('#',...)==0,'Unexpected random range or arguments')
      calls=calls+1
      assert(calls<=repeats*2,'Unexpected extra random trigger')
      local evaluation=math.floor((calls-1)/2)+1
      local field=calls%2==1 and 'mult' or 'dollars'
      assert(key==(field=='mult' and 'lucky_mult' or 'lucky_money'),'Lucky trigger order changed')
      local hit=events[evaluation][field]
      timeline[#timeline+1]={kind='random_trigger',evaluation=evaluation,key=key,hit=hit}
      return hit and 0 or 0.999999
    end
    local card=setmetatable({base={id=13,suit='Spades',nominal=10},seal=held.seal,
      ability={set='Enhanced',effect='Lucky Card',name='Lucky Card',bonus=0,perma_bonus=0,
        mult=20,p_dollars=20,x_mult=1,h_mult=0,h_x_mult=0}}, {__index=Card})
    G.play.cards={card}
    local repeat_result=eval_card(card,{cardarea=G.play,repetition_only=true,repetition=true})
    assert(calls==0 and #queue==0,'Repetition discovery consumed a scoring effect')
    local discovered=repeat_result.seals and repeat_result.seals.repetitions or 0
    assert(discovered==repeats-1,'Source Red seal repetition count differs')
    local chips,mult,cash_applied=5,1,0
    for evaluation=1,1+discovered do
      card.lucky_trigger=false
      local result=eval_card(card,{cardarea=G.play,scoring_hand={card},full_hand={card},
        scoring_name='High Card',poker_hands={}})
      assert(not result.jokers and not result.edition and not result.x_mult,'Unexpected source effect')
      chips=chips+(result.chips or 0)
      mult=mult+(result.mult or 0)
      local dollars=result.p_dollars or 0
      assert(dollars==(events[evaluation].dollars and 20 or 0),'Source conditional cash mismatch')
      assert(card.lucky_trigger==(events[evaluation].mult or events[evaluation].dollars),
        'Source Lucky trigger flag differs')
      assert(G.GAME.dollars==10+cash_applied,'Source getter paid cash directly')
      assert(G.GAME.dollar_buffer==dollars,'Source cash buffer is not the current effect')
      -- Production consumes returned p_dollars once. This arithmetic is a test
      -- double and is explicitly reported; it is not an original event loop.
      G.GAME.dollars=G.GAME.dollars+dollars
      cash_applied=cash_applied+dollars
      timeline[#timeline+1]={kind='apply_returned_cash_test_double',evaluation=evaluation,
        dollars=dollars,cash=G.GAME.dollars,buffer=G.GAME.dollar_buffer}
      local pending=queue;queue={}
      assert(#pending==(dollars>0 and 1 or 0),'Unexpected source event count')
      for _,e in ipairs(pending) do
        assert(e.func()==true,'Source reset event did not complete')
        timeline[#timeline+1]={kind='source_buffer_reset',evaluation=evaluation,
          cash=G.GAME.dollars,buffer=G.GAME.dollar_buffer}
      end
      assert(G.GAME.dollar_buffer==0 and G.GAME.dollars==10+cash_applied,
        'Source reset changed cash or left a stale buffer')
    end
    assert(calls==repeats*2 and #queue==0,'Incomplete conditional trigger table')
    local source_score=math.max(0,math.floor(chips*mult))
    assert(source_score==actual.score,'Advisor/source-method conditional score mismatch')
    assert(G.GAME.dollars==projected.dollars,'Advisor/source-method conditional cash mismatch')
    local row={type='lucky_truth_case',mode=mode,pattern=pattern,events=events,repetitions=discovered,
      evaluations=repeats,random_calls=calls,source_score=source_score,advisor_score=actual.score,
      source_cash_delta=G.GAME.dollars-10,advisor_cash_delta=projected.dollars-10,
      final_cash_buffer=G.GAME.dollar_buffer,input_unchanged=true,timeline=timeline,
      arithmetic_and_scheduling='explicit_test_doubles',source_phase_qualified=false}
    rows[#rows+1]=row;emit(row)
  end
  local summary={type='lucky_truth_summary',mode=mode,cases=#rows,expected_cases=cases,passed=true,
    qualification=false,scope='conditional_original_card_methods_and_eval_card_only',
    trigger_frequency_measured=false,full_source_scoring_phase_qualified=false}
  emit(summary)
  return rows,summary
end
return M

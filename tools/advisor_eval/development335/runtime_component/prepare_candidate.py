from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent
source = (ROOT / 'Brainstorm/Advisor/player_journal.lua').read_text(encoding='utf-8')
before = "    local current=s and A.snapshot.fingerprint(s)==A.published_key and A.published_game==g.GAME"
after = """    -- A missing publication or different game already proves advice is not
    -- current. The full observation remains fresh in every case.
    local current=s and A.published_key~=nil and A.published_game==g.GAME and
      A.snapshot.fingerprint(s)==A.published_key"""
assert source.count(before) == 1
candidate = source.replace(before, after)
before = """          local args={...};local selected={};local e=args[1]
          for _,card in ipairs(g.hand and g.hand.highlighted or {}) do
            for i,c in ipairs(g.hand.cards or {}) do if c==card then selected[#selected+1]=i end end
          end
          local ref=type(e)=='table' and e.config and e.config.ref_table
          local center=type(ref)=='table' and ref.config and ref.config.center
          local sequence=J:before(name,{selected=selected,key=center and center.key,button=type(e)=='table' and e.config and e.config.id})"""
after = """          local sequence
          -- These request details have no consumer when observation is off,
          -- suppressed by its owning action, or already stopped by an error.
          -- Keep the callback's protected call and exact return/error handling.
          if J:enabled() and J.suppressed<=0 and not J.error then
            local selected={};local e=select(1,...)
            for _,card in ipairs(g.hand and g.hand.highlighted or {}) do
              for i,c in ipairs(g.hand.cards or {}) do if c==card then selected[#selected+1]=i end end
            end
            local ref=type(e)=='table' and e.config and e.config.ref_table
            local center=type(ref)=='table' and ref.config and ref.config.center
            sequence=J:before(name,{selected=selected,key=center and center.key,button=type(e)=='table' and e.config and e.config.id})
          end"""
assert candidate.count(before) == 1
candidate = candidate.replace(before, after)
for name, value in [('player_journal.base.lua', source), ('player_journal.lua', candidate)]:
    path = OUT / name
    assert not path.exists(), f'Refusing to overwrite {path}'
    path.write_text(value, encoding='utf-8', newline='\n')

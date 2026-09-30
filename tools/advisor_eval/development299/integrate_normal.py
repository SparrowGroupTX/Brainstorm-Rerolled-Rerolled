from pathlib import Path
root=Path(__file__).resolve().parents[3];draft=Path(__file__).parent/'drafts/normal_route'
for name,target in [('normal_opening.lua',root/'Brainstorm/Advisor/normal_opening.lua'),
 ('advisor_normal_opening.lua',root/'tests/advisor_normal_opening.lua')]:
    assert not target.exists(),'Preserve existing work'
    data=(draft/name).read_text().replace('tools/advisor_eval/development299/drafts/normal_route/normal_opening.lua','Brainstorm/Advisor/normal_opening.lua')
    if name.startswith('advisor_'):
        old="local function capture(g)\n  local s=Snapshot.capture(g)\n  -- Root's three-line snapshot integration supplies exactly these two fields.\n  s.stake=g.GAME.stake;s.normal_opening=Opening.capture(g)\n  return s\nend"
        assert old in data
        data=data.replace(old,'Snapshot.normal_opening=Opening\nlocal function capture(g) return Snapshot.capture(g) end')
    with target.open('x') as stream:stream.write(data)
def replace(path,old,new):
    p=root/path;data=p.read_text();assert data.count(old)==1,path;p.write_text(data.replace(old,new))
replace('Brainstorm/Advisor/runtime.lua',"A.gold_search = module('gold_search')", "A.gold_search = module('gold_search')\nA.normal_opening=module('normal_opening')\nA.normal_opening.gold_stickers=A.gold_stickers\nA.normal_opening.gold_search=A.gold_search\nA.snapshot.normal_opening=A.normal_opening")
replace('Brainstorm/Advisor/snapshot.lua','    deck_key = back.key, blind_choices = M.copy(resets.blind_choices or {}),',
 '    stake = game.stake,\n    normal_opening = M.normal_opening and M.normal_opening.capture(g) or nil,\n    deck_key = back.key, blind_choices = M.copy(resets.blind_choices or {}),')
replace('Brainstorm/Advisor/decision.lua',"  if snapshot.phase ~= 'hand' then", "  if snapshot.phase ~= 'hand' then\n    local normal=modules.normal_opening and modules.normal_opening.advice(snapshot)\n    if normal then return {kind='strategy',strategy=normal,action=normal.action,evaluations=0} end")
replace('Brainstorm/Core/Brainstorm.lua','    if filter_info.challenge_opening and area then area.brainstorm_challenge_opening = true end',
 '    if filter_info.challenge_opening and area then area.brainstorm_challenge_opening = true end\n    if not G.GAME.challenge and area and G.GAME.round==0 and\n        (G.GAME.round_resets or {}).ante==1 and G.GAME.blind_on_deck==\'Big\' and\n        ((G.GAME.round_resets or {}).blind_states or {}).Small==\'Skipped\' and\n        (G.GAME.skips or 0)==1 then\n      area.brainstorm_normal_opening=true\n    end')
print('Integrated normal opening draft, current capture and marker; no freeze or installation.')

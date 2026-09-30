from pathlib import Path
H=Path(__file__).resolve().parent
s=(H.parent/'development447/freeze.py').read_text()
s=s.replace('visible retained-discard repair','expired Riff-raff repair')
s=s.replace("{'Brainstorm/Advisor/growth.lua','Brainstorm/Core/Brainstorm.lua'", "{'Brainstorm/Advisor/shop_scoring.lua','Brainstorm/Advisor/growth.lua','Brainstorm/Core/Brainstorm.lua'")
s=s.replace('len(tests)==379','len(tests)==380').replace('tests/advisor_visible_jokers447.lua','tests/advisor_expired_riff448.lua')
s=s.replace('repair447_candidate1','repair448_candidate1').replace('2.222.0-alpha','2.223.0-alpha')
with(H/'freeze.py').open('x')as f:f.write(s)

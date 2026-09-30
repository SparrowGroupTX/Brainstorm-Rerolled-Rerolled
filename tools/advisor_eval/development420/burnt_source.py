"""Inspect archived original-game text; never execute original code."""
from pathlib import Path
import zipfile,json,hashlib
p=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe')
with zipfile.ZipFile(p) as z:t=z.read('card.lua').decode()
needle="self.ability.name == 'Burnt Joker'";starts=[];at=0
while True:
 at=t.find(needle,at)
 if at<0:break
 starts.append(t[max(0,at-240):at+1400]);at+=len(needle)
out={'source':str(p),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'scope':__doc__,'excerpts':starts}
with (Path(__file__).parent/'burnt_source_text.json').open('x') as f:json.dump(out,f,indent=2)
print(json.dumps({'matches':len(starts),'source_sha256':out['source_sha256']}))

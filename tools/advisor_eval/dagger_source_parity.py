"""Check Dagger slicing against its untouched installed-source setting_blind block.

DLL only. Event/display doubles; this is narrow callback parity, not whole blind entry.
"""
from pathlib import Path
import hashlib
import importlib.util
import tempfile
import zipfile
from discard_source_parity import ROOT

def main():
    install=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro')
    with zipfile.ZipFile(install/'Balatro.exe') as archive: raw=archive.read('card.lua')
    source=raw.decode();start=source.index("if self.ability.name == 'Ceremonial Dagger' and not context.blueprint")
    end=source.index("            if self.ability.name == 'Marble Joker'",start)
    chunk='function source_dagger(self,context)\n'+source[start:end]+'\nend\n'
    chunk+=Path(__file__).with_suffix('.lua').read_text(encoding='utf-8')
    spec=importlib.util.spec_from_file_location('lua_tests',ROOT/'tests/run_lua_tests.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    print('card.lua sha256='+hashlib.sha256(raw).hexdigest())
    with tempfile.TemporaryDirectory(prefix='advisor-dagger-parity-') as temp:
        file=Path(temp)/'parity.lua';file.write_text(chunk,encoding='utf-8')
        return 0 if module.LuaLibrary(install/'lua51.dll').run(file) else 1
if __name__=='__main__':raise SystemExit(main())

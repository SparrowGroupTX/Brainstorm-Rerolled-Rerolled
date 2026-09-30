"""Manufactured ZIP fixtures only; no source archive/game/policy access."""
from pathlib import Path
import ast,importlib.util,json,sys,tempfile,zipfile
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
spec=importlib.util.spec_from_file_location('source_lexer',ROOT/'tools/advisor_eval/development300/mechanics11/inspect_source.py')
lexer=importlib.util.module_from_spec(spec);sys.modules['source_lexer']=lexer;spec.loader.exec_module(lexer)
from inspect_source import inspect,MEMBERS,CAP,sha

def main():
    checks=0
    def check(value):
        nonlocal checks
        checks+=1;assert value
    for name in ('inspect_source.py','register.py','test_inspector.py'):
        ast.parse((HERE/name).read_text());checks+=1
    body=b'''-- function Card:set_seal() fake end\r
function Card:set_seal(seal)\r
  local ignored="function end"\r
  if seal then self.seal=seal end\r
end\r
function Card:calculate_joker(context)\r
  if context.first_hand_drawn then\r
    if self.ability.name == 'Certificate' then\r
      local chosen = pseudorandom('certsl')\r
      return chosen\r
    end\r
  end\r
end\r
'''
    with tempfile.TemporaryDirectory(prefix='synthetic_certificate_inspect_') as temporary:
        root=Path(temporary);archive=root/'source.zip'
        with zipfile.ZipFile(archive,'x') as z:
            z.writestr('card.lua',body)
            z.writestr('functions/state_events.lua',b'G.FUNCS.draw_from_deck_to_hand = function(e)\n return e\nend\n')
            z.writestr('functions/common_events.lua',b'function draw_card(a,b)\n return a,b\nend\n')
            z.writestr('forbidden.lua',b'ERROR: must not inspect this member')
        output=root/'inspection';result=inspect(archive,output)
        check(set(result['members'])==set(MEMBERS))
        check(result['members']['card.lua']['sha256']==sha(body))
        method=next(x for x in result['methods'] if x['name']=='set_seal')
        check(method['status']=='found' and method['truncated'] is False)
        check((output/method['excerpt_file']).read_bytes().startswith(b'function Card:set_seal'))
        cert=next(x for x in result['neighborhoods'] if x['name']=='certificate')
        check(cert['matches']==cert['shown_matches']==1 and not cert['truncated'])
        check(sum(p.stat().st_size for p in output.glob('*.lua'))==result['combined_output_bytes']<=CAP)
        check(any(x['status']=='not_found' for x in result['methods']))
        # Many repetitive hits preserve total-match counts and bounded omissions.
        large=root/'large.zip'
        with zipfile.ZipFile(large,'x') as z:
            z.writestr('card.lua',b'-- Certificate first_hand_drawn certsl\n'*1500)
        limited=inspect(large,root/'limited')
        check(limited['members']['functions/common_events.lua']['status']=='missing')
        cert=next(x for x in limited['neighborhoods'] if x['name']=='certificate')
        check(cert['matches']==1500 and cert['shown_matches']<=8 and cert['truncated'])
        check(limited['combined_output_bytes']<=CAP)
        duplicate=root/'duplicate.zip'
        with zipfile.ZipFile(duplicate,'x') as z:
            z.writestr('card.lua',body);z.writestr('CARD.LUA',body)
        ambiguous=inspect(duplicate,root/'ambiguous')
        check(ambiguous['members']['card.lua']['status']=='ambiguous')
        check(not ambiguous['source_execution'] and not ambiguous['player_file_access'])
    with (HERE/'synthetic_fixture_report.json').open('x',encoding='utf-8') as f:
        json.dump({'schema':1,'checks':checks,'passed':True,'original_source_access':False,
            'source_execution':False,'registration':False,'source':'Temporary manufactured ZIP files only'},f,indent=2)
    print('M15 inspector synthetic checks:',checks,'passed')

if __name__=='__main__':main()

"""Root-only prospective M15 registration. Never run this from a subagent."""
from pathlib import Path
import sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[4]
sys.path.insert(0,str(ROOT/'tools/advisor_eval/development299'))
from cycle import register

def main():
    archive=Path('C:/Program Files (x86)/Steam/steamapps/common/Balatro/Balatro.exe').resolve()
    files={'inspect_source.py':HERE/'inspect_source.py',
        'source_lexer.py':ROOT/'tools/advisor_eval/development300/mechanics11/inspect_source.py',
        'spec.md':HERE/'spec.md','synthetic_fixture_report.json':HERE/'synthetic_fixture_report.json'}
    folder=register('M15',files,[sys.executable,'-B','-u','{job}/inspect_source.py'],{
        'hypothesis':'Exact Certificate generation timing and insertion/seal callbacks determine whether a complete first-hand projection can share a known public population with Gold cargo comparisons.',
        'source_archive':str(archive),'outer_cap_seconds':30,'one_use':True,
        'source_scope':'Only card.lua, functions/state_events.lua, functions/common_events.lua ZIP members; each<=4MiB, <=20000 archive entries.',
        'combined_output_cap_bytes':120000,
        'methods':'Six named first-draw/generation/seal functions; individual line bounds and12000-byte caps, original full-method and excerpt hashes; missing/truncated explicit.',
        'neighborhoods':'Bounded Certificate/first_hand_drawn/generation/seal-pool sites; at most8/4/6/6/6 matches,6000bytes per excerpt, total120000bytes; every omitted/truncated site labeled.',
        'profile':'none','policy':'none','runtime':'Frozen Python standard-library ZIP reader plus byte lexer; no Lua',
        'qualification':False,'source_execution':False,'native_search':False,
        'player_file_access':False,'game_process_access':False,
        'limitations':'Read-only mechanics inspection. No action, run, source callback, gameplay outcome or adapter qualification.'
    },external=[archive,Path(sys.executable)])
    print(folder/'registration.json')

if __name__=='__main__':main()

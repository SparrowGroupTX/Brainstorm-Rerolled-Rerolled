"""Source-free construction of a dedicated nonempty terminal fixture adapter."""
from pathlib import Path
import hashlib
import json
here=Path(__file__).resolve().parent;base=here/'normal_adapter/engine_run.lua'
data=base.read_bytes();newline=b'\r\n' if b'\r\n' in data else b'\n'
marker=b"        if PROBE_TEST_SCENARIO=='terminal_saved_final' or PROBE_TEST_SCENARIO=='terminal_unsaved_final' then"
assert data.count(marker)==1
addition="""        if PROBE_DECK and PROBE_TEST_SCENARIO=='terminal_win_final' then
            -- Explicit M08 synthetic terminal row, not a run acquisition.
            for _,key in ipairs({'j_yorick','j_perkeo','j_brainstorm','j_burnt'}) do
                local card=create_card('Joker',G.jokers,nil,nil,nil,nil,key)
                card:add_to_deck();G.jokers:emplace(card)
            end
            trace({type='engine_held_terminal_fixture',keys={'j_yorick','j_perkeo','j_brainstorm','j_burnt'},
                qualification=false,actual_acquisition=false,policy_decisions=0})
        end
""".replace('\n',newline.decode()).encode()
derived=data.replace(marker,addition+marker)
dest=here/'drafts/held_terminal';dest.mkdir(exist_ok=False)
with (dest/'engine_run.lua').open('xb') as stream:stream.write(derived)
with (dest/'derivation.json').open('x') as stream:json.dump({'schema':1,'base_adapter_sha256':hashlib.sha256(data).hexdigest(),
    'derived_adapter_sha256':hashlib.sha256(derived).hexdigest(),'insertion_sha256':hashlib.sha256(addition).hexdigest(),
    'scope':'Only synthetic normal terminal_win_final branch receives four held original-source Joker instances; all other source dispatch unchanged.'},stream,indent=2)
print(dest)

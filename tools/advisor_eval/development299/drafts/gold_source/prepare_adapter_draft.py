"""Create only changed adapter copies; never run or inspect original game source."""
from pathlib import Path

HERE = Path(__file__).resolve().parent
BASE = HERE.parents[1] / 'normal_adapter'


def replace_once(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)


def main():
    probe = (BASE / 'engine_probe.py').read_text(encoding='utf-8')
    probe = replace_once(probe, 'from normal_recipe import load as normal_recipe_record',
                         'from normal_recipe import load as normal_recipe_record\nfrom gold_objective_spec import MODES as GOLD_OBJECTIVE_MODES, build as gold_objective_spec')
    probe = replace_once(probe, '    parser.add_argument("--episode", action="store_true", help="Continue into the experimental real-engine episode adapter")',
                         '    parser.add_argument("--gold-objective", choices=GOLD_OBJECTIVE_MODES, default="off",\n'
                         '                        help="Explicit fresh synthetic all-missing Gold objective; default off; never player history")\n'
                         '    parser.add_argument("--episode", action="store_true", help="Continue into the experimental real-engine episode adapter")')
    probe = replace_once(probe, '    executable = args.install / "Balatro.exe"',
                         '    try:\n        objective_spec = gold_objective_spec(args)\n'
                         '    except ValueError as error:\n        parser.error(str(error))\n'
                         '    executable = args.install / "Balatro.exe"')
    probe = replace_once(probe, '"normal_recipe.py", "normal_terminal.lua")}',
                         '"normal_recipe.py", "normal_terminal.lua", "gold_objective_spec.py", "gold_objective_context.lua")}')
    probe = replace_once(probe, "    provenance['retry_context_spec'] = retry_context_spec()",
                         "    provenance['gold_objective_spec'] = objective_spec\n"
                         "    provenance['gold_objective_spec_digest'] = digest(objective_spec)\n"
                         "    provenance['retry_context_spec'] = retry_context_spec()")
    probe = replace_once(probe, '    chunks.append(b"PROBE_TEST_SCENARIO=" + lua_value(args.test_scenario))',
                         '    chunks.append(b"PROBE_TEST_SCENARIO=" + lua_value(args.test_scenario))\n'
                         '    chunks.append(b"PROBE_GOLD_OBJECTIVE=" + lua_value(objective_spec))\n'
                         '    chunks.append(b"package.preload.probe_gold_objective_context=assert(loadstring(" + literal(\n'
                         "        Path(__file__).with_name('gold_objective_context.lua').read_bytes()) + b\",'@gold_objective_context.lua'))\")")
    run = (BASE / 'engine_run.lua').read_text(encoding='utf-8')
    run = replace_once(run, "if package.preload.probe_policy_gold_stickers then modules.gold_stickers=require('probe_policy_gold_stickers') end",
                       "if package.preload.probe_policy_gold_stickers then modules.gold_stickers=require('probe_policy_gold_stickers') end\n"
                       "if PROBE_GOLD_OBJECTIVE and PROBE_GOLD_OBJECTIVE.enabled then modules.gold_goal=require('probe_policy_gold_goal') end")
    run = replace_once(run, 'local function check_opening_complete(step)',
                       "if PROBE_GOLD_OBJECTIVE and PROBE_GOLD_OBJECTIVE.enabled then\n"
                       "    require('probe_gold_objective_context').attach(PROBE_GOLD_OBJECTIVE,modules,G,trace)\n"
                       "else\n"
                       "    trace({type='engine_gold_objective_context',enabled=false,mode='off',\n"
                       "      initialized_before_decision=true,qualification=false,actual_player_profile=false})\n"
                       "end\n"
                       'local function check_opening_complete(step)')
    for name, text in [('engine_probe.py', probe), ('engine_run.lua', run)]:
        with (HERE / name).open('x', encoding='utf-8', newline='\n') as out:
            out.write(text)


if __name__ == '__main__':
    main()

"""Fresh M14 source-startup comparison adapter; preparation only."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
OLD = ROOT/'tools/advisor_eval/runs/gold299_20260914/M12'


def change(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)


def main():
    adapter = HERE/'adapter'; adapter.mkdir(exist_ok=False)
    names = ('engine_probe.py', 'engine_probe.lua', 'engine_run.lua', 'engine_contract.lua',
        'opening_support.py', 'benchmark.py', 'normal_recipe.py', 'normal_terminal.lua',
        'startup_fixture.lua', 'startup_receipt.py', 'worker.py')
    original = {}
    for name in names:
        raw = (OLD/name).read_bytes(); original[name] = hashlib.sha256(raw).hexdigest()
        text = raw.decode('utf-8')
        if name == 'engine_probe.py':
            text = change(text, '"startup_fixture.lua", "startup_receipt.py")}',
                '"startup_fixture.lua", "startup_receipt.py", "baseline_collection_search_product.lua")}')
            needle = "            fixture = Path(__file__).with_name('startup_fixture.lua').read_bytes()"
            insertion = '''            baseline = Path(__file__).with_name('baseline_collection_search_product.lua').read_bytes()
            chunks.append(b'package.preload.probe_baseline_collection_search_product=assert(loadstring(' + literal(baseline) + b",'@frozen302/Core/collection_search_product.lua'))")
            chunks.append(b'PROBE_BASELINE_PRODUCT_SHA256=' + lua_value(hashlib.sha256(baseline).hexdigest()))
'''
            text = change(text, needle, insertion+needle)
            text = change(text, "'bootstrap_seed': args.seed, 'requested_seed': observed['result']['seed'],",
                "'bootstrap_seed': args.seed, 'requested_seed': observed['result']['seed'],\n                'mechanical_context': 'M14 injects only the M13-proven font-only boot-cache shape and compares frozen302 preflight with candidate304 startup. No profile/terminal/gameplay injection.',\n                'baseline_product_sha256': hashlib.sha256(baseline).hexdigest(),")
        elif name == 'startup_fixture.lua':
            text = text.replace('M12', 'M14')
            text = change(text, '  local old_game=g.GAME', '''  -- M13 proves boot_timer creates this persistent display-cache shape.
  -- Font rendering is represented by an inert table. boot_timer itself is
  -- not executed; no game/profile/terminal fields are changed by this setup.
  assert(g.LOADING==nil or g.LOADING==false,'M14 expected isolated probe without original boot display cache')
  local boot_cache={font={synthetic_display_font=true}}
  g.LOADING=boot_cache
  local old_game=g.GAME''')
            text = change(text, '  local api=product.attach(B,{game=function()return g end,', '''  local baseline=require('probe_baseline_collection_search_product').attach(B,{game=function()return g end})
  local old_ready,old_reason=baseline.can_begin()
  assert(not old_ready and old_reason=='A save or checkpoint operation is pending.',
      'M14 must reproduce frozen302 wrongly treating boot display cache as active loading')
  trace({type='engine_collection_startup_baseline',baseline_product_sha256=PROBE_BASELINE_PRODUCT_SHA256,
      ready=false,reason=old_reason,searches=0,launches=0,
      injected_scope='Only M13-proven G.LOADING font-only cache; inert font stand-in, no original boot_timer execution'})
  local api=product.attach(B,{game=function()return g end,''')
            text = change(text, "      after.blind_on_deck=='Small' and after.skips==0 and #g.playing_cards==52,",
                "      after.blind_on_deck=='Small' and after.skips==0 and #g.playing_cards==52 and\n      after.skip_tags.Small=='tag_charm' and g.LOADING==boot_cache,")
            text = change(text, "      used_filter=g.GAME.used_filter,seeded=g.GAME.seeded,profile_unchanged=true,profile_counts=goal_after.counts,",
                "      used_filter=g.GAME.used_filter,seeded=g.GAME.seeded,profile_unchanged=true,profile_counts=goal_after.counts,\n      actual_small_tag=after.skip_tags.Small,boot_cache_preserved=g.LOADING==boot_cache,baseline_preflight_rejected=true,")
            text = change(text, "reason='development_collection_product_startup'", "reason='development_collection_product_startup_boot_cache'")
        elif name == 'worker.py':
            text = text.replace('M12', 'M14')
        (adapter/name).write_text(text, encoding='utf-8', newline='\n')
    baseline = OLD/'policy/Brainstorm/Core/collection_search_product.lua'
    record = json.loads((OLD/'frozen_product_record.json').read_text(encoding='utf-8'))
    assert hashlib.sha256(baseline.read_bytes()).hexdigest() == record['policy']['policy_files']['Brainstorm/Core/collection_search_product.lua']
    (adapter/'baseline_collection_search_product.lua').write_bytes(baseline.read_bytes())
    original['baseline_collection_search_product.lua'] = hashlib.sha256(baseline.read_bytes()).hexdigest()
    with (HERE/'parent_evidence_hashes.json').open('x', encoding='utf-8') as stream:
        json.dump(original, stream, indent=2); stream.write('\n')
    print('Prepared M14; no registration, source execution or native call.')


if __name__ == '__main__':
    main()

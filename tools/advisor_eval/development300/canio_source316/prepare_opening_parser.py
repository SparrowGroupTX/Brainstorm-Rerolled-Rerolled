"""Optional M23 parser overlay, prepared from a root-chosen fresh adapter.

Importing is inert. Only rewrites copied Python text; no source/game execution.
"""
from pathlib import Path
import sys
def patched(text):
    old="if args.opening_only_actions and (not normal_recipe or not args.stop_on_opening_complete or args.stop_after_step!=10):\n        parser.error('Opening-only qualification requires normal recipe, opening stop and exact ten-step cap')"
    new="if args.opening_only_actions and (not normal_recipe or not args.stop_on_opening_complete or not (args.stop_after_step==10 or args.stop_after_step==3 and args.gold_objective=='synthetic_only_canio_missing_v1')):\n        parser.error('Opening-only qualification requires normal recipe, opening stop and exact ten-step cap, or three steps for the declared alternate Canio objective')"
    if text.count(old)!=1:raise ValueError('Root-chosen adapter does not have the reviewed opening-only cap guard')
    return text.replace(old,new)
def main():
    if len(sys.argv)!=3:raise SystemExit('Usage: prepare_opening_parser.py SOURCE_ENGINE_PROBE.py FRESH_OUTPUT.py')
    result=patched(Path(sys.argv[1]).read_text())
    compile(result,'@prospective_m23_engine_probe.py','exec')
    with Path(sys.argv[2]).open('x',encoding='utf-8',newline='\n')as out:out.write(result)
if __name__=='__main__':main()

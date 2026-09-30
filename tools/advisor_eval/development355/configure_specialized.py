"""Freeze the latest observed public goal; no saves, profiles or simulation."""
from pathlib import Path
import datetime as dt
import hashlib
import json

directory=Path(__file__).parent
source=directory/'SPECIALIZED_PUBLIC_DATA.json'
data=json.loads(source.read_text())
goal=data['latest_goal']
if goal['metadata_status']!='complete' or goal['catalog_status']!='complete':
    raise ValueError('Verified public collection metadata required')
spec={'schema':'completionist_distinct_v1','verified_collection':True,
      'joker_keys':sorted(goal['status_by_key']),'status_by_key':goal['status_by_key'],
      'public_source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
      'public_goal_event_sha256':goal['event_sha256'],'observed_at':goal['at'],
      'observed_counts':goal['counts'],'actual_player_awards':False,
      'training_cohort':'public_conditioned_post_soul_training',
      'opening':{'deck':'b_red','stake':8,'jokers':['j_perkeo','j_yorick'],
                 'dollars':4,'ante':1,'round':0,'next_blind':'Big','small_skipped':True,
                 'consumables':[],'source_exemplar':'YAEARC31 public seq2201',
                 'seed_equivalent':False,'hidden_future':'fresh simulator draws; not source-conditioned RNG'}}
with (directory/'specialized_goal.json').open('x') as stream:json.dump(spec,stream,indent=2);stream.write('\n')
amendment={'registered_utc':dt.datetime.now(dt.timezone.utc).isoformat(),
    'authority':'Latest user steering: specialize Red Deck Gold Stake Perkeo/Yorick openings and maximize average distinct new Gold stickers per game.',
    'changes':'Remaining T02/T03/V02/V03 specialize the objective and public-conditioned opening. Planned White Stake curriculum is cancelled. No budget or job count increase. P01/S01/V01/T01 remain consumed historical generic evidence, not comparable target results.',
    'reserved_seconds_unchanged':3030,'remaining_job_ids':['T02','T03','V02','V03'],
    'goal_file_sha256':hashlib.sha256((directory/'specialized_goal.json').read_bytes()).hexdigest(),
    'terminal_reward':'Distinct verified-missing held Joker identities at an eligible simulated normal Red Gold final win. Unknown/already-Gold/duplicates do not add reward. No reward for purchase, holding, or zero-new-sticker wins. Actual awards always0 in this simulator.',
    'discount':1.0,'time_penalty':0,'shaping':'0.05*blinds-cleared potential difference, zero at true terminals; telescopes over full episodes.',
    'cohort_limit':'Constructed post-Soul public scaffold is not exact native search, source opening validation, full source attempt, or unseen named-seed evaluation. Known named seeds remain development data.',
    'evaluation':'V02 development and V03 final can pair learned/weak heuristic on32 identical synthetic-world seeds each,64 total episodes per job. Select policy before final namespace; censor unsupported/errors/caps. No source workers, seed search or live gameplay.'}
with (directory/'AMENDMENT_SPECIALIZED.json').open('x') as stream:json.dump(amendment,stream,indent=2);stream.write('\n')
print(json.dumps({'goal_counts':goal['counts'],'amendment':amendment['registered_utc']}))

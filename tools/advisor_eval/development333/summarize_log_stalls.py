"""Read compact timing only; no snapshot evaluation or live control."""
from pathlib import Path
import sys,json,hashlib
HERE=Path(__file__).resolve().parent; sys.path.insert(0,str(HERE.parent))
from read_player_log import records,parsed
source=HERE/'captured_log/session-20260915T202738Z-1-000001.brj'
rows=[];kinds={}
with source.open('rb') as stream:
    for raw,meta in records(stream):
        event=parsed(raw); kind=event.get('kind');kinds[kind]=kinds.get(kind,0)+1
        if kind!='performance_window': continue
        w=event['details'];metrics={}
        for name in ['frame_interval','game_update','journal_update','advisor_update','journal.total','performance_emit','draw_total']:
            m=w.get('metrics',{}).get(name)
            if m:metrics[name]={'count':m['count'],'total_seconds':m['total_seconds'],'maximum_seconds':m['max_seconds'],
                'mean_seconds':m['total_seconds']/m['count']}
        rows.append({'sequence':event['sequence'],'at':event['at'],'window_id':w['window_id'],
            'start_seconds':w['start_seconds'],'end_seconds':w['end_seconds'],'flags':w.get('flags'),
            'metrics':metrics})
slow=sorted(rows,key=lambda w:w['metrics'].get('frame_interval',{}).get('mean_seconds',0),reverse=True)[:8]
value={'schema':1,'kind':'read_only_logged_stall_index','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
 'event_kinds':kinds,'windows':rows,'largest_mean_frame_intervals':slow,
 'interpretation':['Only this captured prefix; loaded version is absent because these are compact timing records.',
 'Existing direct journal event costs and game_update costs are measured separately. Nested timings must not be summed.',
 'Hook-chain growth is separately reproduced with manufactured callbacks; timing cannot identify GC or prove the sole live cause.',
 'No live FPS recovery or new-source/policy evaluation is measured.']}
with (HERE/'captured_log/stall_index.json').open('x',encoding='utf-8') as f:json.dump(value,f,indent=2);f.write('\n')
print(json.dumps({'event_kinds':kinds,'largest_mean_frame_intervals':slow[:3]},indent=2))

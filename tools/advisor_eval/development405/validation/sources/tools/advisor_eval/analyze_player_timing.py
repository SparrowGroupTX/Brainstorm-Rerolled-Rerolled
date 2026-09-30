"""Bounded offline summaries of explicitly supplied public journal timing files.

No directory discovery, game access, writes to inputs, or inferred CPU usage.
JSONL and BRJ2 archives use the existing validating public-journal decoder.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import sys
try:
    from read_player_log import ArchiveError, parsed, records
except ModuleNotFoundError:
    from tools.advisor_eval.read_player_log import ArchiveError, parsed, records

BUCKETS=[.001,.004,.008,.016,.033,.05,.1,.25,1,5]
LABELS=set('update_argument_dt frame_interval update_total game_update checkpoint_update search_update journal_update advisor_update auto_update legacy_reroll original_draw advisor_hud_draw draw_total performance_emit snapshot.capture snapshot.fingerprint advisor.refresh advisor.present decision.resume journal.observe journal.encode journal.append journal.total'.split())
GROUPS={
 'update_components':['game_update','checkpoint_update','search_update','journal_update','advisor_update','auto_update','legacy_reroll'],
 'totals_and_gaps':['update_total','draw_total','frame_interval','update_argument_dt','performance_emit'],
 'draw_components':['original_draw','advisor_hud_draw'],
 'nested_measurements':['snapshot.capture','snapshot.fingerprint','advisor.refresh','advisor.present','decision.resume','journal.observe','journal.encode','journal.append','journal.total'],
}
HARD={'max_files':32,'max_file_bytes':134217728,'max_total_bytes':268435456,
      'max_decoded_bytes':268435456,'max_events':100000,'max_decisions':100000,'max_examples':64}
DEFAULT={**HARD,'max_files':16,'max_file_bytes':33554432,'max_total_bytes':67108864,
         'max_decoded_bytes':134217728,'max_events':50000,'max_examples':20}

class TimingError(ValueError):pass
def require(value,message):
    if not value:raise TimingError(message)
def number(v):return type(v) in (int,float) and math.isfinite(v) and 0<=v<=1e12
def integer(v):return type(v) is int and 0<=v<=2**53
def identity(v):return integer(v) and v>0 or isinstance(v,str) and 0<len(v)<=64
def empty_array(v,name,limit):
    if v=={}:return [] # Lua encodes its empty arrays as empty objects.
    require(isinstance(v,list) and len(v)<=limit,'Invalid '+name)
    return v
def flags(v):
    require(isinstance(v,dict) and len(v)<=32,'Invalid flags')
    require(all(isinstance(k,str) and len(k)<=64 and (type(x) is bool or number(x) or isinstance(x,str) and len(x)<=128) for k,x in v.items()),'Invalid flag value')
    return dict(v)
def limits(options):
    out={**DEFAULT,**(options or {})}
    require(set(out)==set(HARD),'Unknown input limit')
    for key,value in out.items():require(type(value)is int and 0<value<=HARD[key],'Invalid '+key)
    return out

def validate_window(event):
    require(event.get('schema')==1 and event.get('context')=={},'Timing window requires schema1 and empty context')
    w=event.get('details')
    require(isinstance(w,dict) and w.get('schema')==1 and identity(w.get('window_id')),'Invalid performance window identity')
    require(w.get('clock_scope','process_monotonic')=='process_monotonic' and w.get('units','seconds')=='seconds','Unknown timing clock/units')
    require(number(w.get('start_seconds')) and number(w.get('end_seconds')) and w['end_seconds']>=w['start_seconds'],'Invalid window interval')
    require(w.get('bucket_upper_seconds')==BUCKETS and all(number(x) for x in w['bucket_upper_seconds']),'Unknown histogram buckets')
    require(isinstance(w.get('metrics'),dict) and set(w['metrics'])<=LABELS,'Unknown timing metric')
    for name,m in w['metrics'].items():
        require(isinstance(m,dict) and integer(m.get('count')) and m['count']>0,'Invalid metric count: '+name)
        require(number(m.get('total_seconds')) and number(m.get('max_seconds')),'Invalid metric seconds: '+name)
        h=m.get('histogram')
        require(isinstance(h,list) and len(h)==11 and all(integer(x) for x in h) and sum(h)==m['count'],'Incomplete metric histogram: '+name)
        eps=max(1e-9,m['total_seconds']*1e-12)
        require(m['max_seconds']<=m['total_seconds']+eps and m['total_seconds']<=m['count']*m['max_seconds']+eps,'Inconsistent metric totals: '+name)
        maximum_bucket=next((i for i,upper in enumerate(BUCKETS) if m['max_seconds']<=upper),10)
        require(max(i for i,n in enumerate(h) if n)==maximum_bucket,'Histogram maximum is inconsistent: '+name)
        lower=sum(n*(0 if i==0 else BUCKETS[i-1]) for i,n in enumerate(h))
        upper=sum(n*BUCKETS[i] for i,n in enumerate(h[:-1])) if h[-1]==0 else math.inf
        require(lower<=m['total_seconds']+eps and m['total_seconds']<=upper+eps,'Histogram total is inconsistent: '+name)
    slow=empty_array(w.get('slow_frames'), 'slow frames',64)
    for row in slow:
        require(isinstance(row,dict) and number(row.get('at_seconds')),'Invalid slow frame anchor')
        require(any(k in row for k in ('frame_interval_seconds','update_seconds')),'Missing slow frame measurement')
        for key in ('frame_interval_seconds','update_seconds'):
            require(key not in row or number(row[key]),'Invalid slow frame duration')
        flags(row.get('flags',{}))
    decisions=empty_array(w.get('decisions'),'decision receipts',128)
    for d in decisions:
        require(isinstance(d,dict) and identity(d.get('decision_id')),'Invalid decision identity')
        require(d.get('status') in ('completed','cancelled','error'),'Unknown decision status')
        require(isinstance(d.get('phase'),str) and len(d['phase'])<=32,'Invalid decision phase')
        for key in ('started_seconds','finished_seconds','elapsed_seconds','active_seconds','max_resume_seconds'):
            require(number(d.get(key)),'Invalid decision '+key)
        require(integer(d.get('resume_calls')),'Invalid resume count')
        eps=max(1e-8,d['elapsed_seconds']*1e-10)
        require(abs(d['finished_seconds']-d['started_seconds']-d['elapsed_seconds'])<=eps and d['active_seconds']<=d['elapsed_seconds']+eps and d['max_resume_seconds']<=d['active_seconds']+eps,'Inconsistent decision timing')
        if 'evaluations' in d:require(d['status']=='completed' and integer(d['evaluations']),'Only completed decisions can report score calls')
        for key in ('state','ante','round'):
            require(key not in d or number(d[key]),'Invalid optional decision metadata')
        require('action_kind' not in d or isinstance(d['action_kind'],str) and len(d['action_kind'])<=32,'Invalid decision action kind')
    for key in ('slow_frames_dropped','decisions_dropped'):
        require(integer(w.get(key)),'Missing dropped-record count')
    require(integer(w.get('clock_failures',0)),'Invalid clock failure count')
    flags(w.get('flags',{}))
    return w,slow,decisions

def quantile_bounds(hist,count,percent):
    rank=max(1,(count*percent+99)//100);cumulative=0
    for index,n in enumerate(hist):
        cumulative+=n
        if cumulative>=rank:
            return {'rank':rank,'lower_seconds':0 if index==0 else BUCKETS[index-1],
                    'lower_inclusive':index==0,'upper_seconds':BUCKETS[index] if index<len(BUCKETS) else None,
                    'upper_inclusive':index<len(BUCKETS),'exact_percentile':False}
    raise TimingError('Histogram rank missing')

class Summary:
    def __init__(self,options=None):
        self.limits=limits(options);self.events=0;self.decoded_bytes=0;self.windows=0
        self.metrics={};self.scopes={};self.seen_windows=set();self.seen_decisions=set()
        self.archive_tails={};self.archive_links=0
        self.slow=[];self.decisions=[];self.slow_seen=0;self.decisions_seen=0
        self.dropped_slow=0;self.dropped_decisions=0;self.clock_failures=0
        self.statuses={k:0 for k in ('completed','cancelled','error')}
        self.decision_totals={'elapsed_seconds':0,'active_seconds':0,'resume_calls':0,'max_resume_seconds':0,
                              'completed_with_evaluations':0,'completed_without_evaluations':0,'known_completed_score_calls':0}
        self.legacy_anchors=0;self.unavailable_anchors=0;self.valid_anchors=0;self.errors=[];self.inputs=[]
    def consume(self,raw,metadata,source):
        require(self.events<self.limits['max_events'],'Event cap reached; suffix not analyzed')
        require(self.decoded_bytes+len(raw)<=self.limits['max_decoded_bytes'],'Decoded-byte cap reached; suffix not analyzed')
        event=parsed(raw)
        scope=('archive:'+metadata['session']) if metadata.get('format')==2 else ('jsonl:'+source)
        s=self.scopes.setdefault(scope,{'events':0,'windows':0,'last_sequence':None,'last_window_end_seconds':None,
                                        'events_after_last_window':0,'last_monotonic_seconds':None})
        seq=event['sequence']
        require(s['last_sequence'] is None or seq==s['last_sequence']+1,'Sequence gap, duplicate or out-of-order input in '+scope)
        archive=metadata.get('format')==2
        previous=self.archive_tails.get(scope) if archive else None
        if previous:
            # The decoder accepts standalone fragments. Once both endpoints
            # are supplied, adjacent sequence numbers alone cannot join them.
            require(metadata['previous_frame_sha256']==previous['frame_sha256'],
                    'Archive predecessor mismatch between supplied frames in '+scope)
            if source!=previous['source']:
                # Empty rotations can consume segment numbers without events.
                require(metadata['segment']>previous['segment'],
                        'Archive segment reused or regressed across supplied files in '+scope)
        stamp=event.get('monotonic_seconds')
        if stamp is not None:
            require(number(stamp),'Invalid precise event timestamp')
            require(s['last_monotonic_seconds'] is None or stamp>=s['last_monotonic_seconds'],'Precise event clock regressed')
        prepared=None
        if event.get('kind')=='performance_window':
            prepared=validate_window(event);w,slow,decisions=prepared
            require((scope,w['window_id']) not in self.seen_windows,'Duplicate performance window; not counted twice')
            require(s['last_window_end_seconds'] is None or w['start_seconds']>=s['last_window_end_seconds'],'Overlapping or out-of-order timing windows')
            require(self.decisions_seen+len(decisions)<=self.limits['max_decisions'],'Decision receipt cap reached')
            ids=[(scope,d['decision_id']) for d in decisions]
            require(len(set(ids))==len(ids) and not any(key in self.seen_decisions for key in ids),'Duplicate decision receipt; not counted twice')
        # Commit only after the entire next record validates.
        self.events+=1;self.decoded_bytes+=len(raw);s['events']+=1;s['last_sequence']=seq;s['events_after_last_window']+=1
        if archive:
            self.archive_links+=int(previous is not None)
            self.archive_tails[scope]={'source':source,'segment':metadata['segment'],
                                       'frame_sha256':metadata['frame_sha256']}
        if stamp is not None:self.valid_anchors+=1;s['last_monotonic_seconds']=stamp
        elif event.get('monotonic_status')=='unavailable':self.unavailable_anchors+=1
        else:self.legacy_anchors+=1
        if not prepared:return
        w,slow,decisions=prepared;self.windows+=1;s['windows']+=1;s['last_window_end_seconds']=w['end_seconds'];s['events_after_last_window']=0
        self.seen_windows.add((scope,w['window_id']));self.clock_failures+=w.get('clock_failures',0)
        self.dropped_slow+=w['slow_frames_dropped'];self.dropped_decisions+=w['decisions_dropped']
        for name,m in w['metrics'].items():
            a=self.metrics.setdefault(name,{'count':0,'total_seconds':0,'max_seconds':0,'histogram':[0]*11})
            a['count']+=m['count'];a['total_seconds']+=m['total_seconds'];a['max_seconds']=max(a['max_seconds'],m['max_seconds'])
            for i,n in enumerate(m['histogram']):a['histogram'][i]+=n
        self.slow_seen+=len(slow);self.decisions_seen+=len(decisions)
        self.slow.extend({**row,'scope':scope,'window_id':w['window_id']} for row in slow)
        self.slow.sort(key=lambda row:max(row.get('frame_interval_seconds',0),row.get('update_seconds',0)),reverse=True)
        self.slow=self.slow[:self.limits['max_examples']]
        for d in decisions:
            self.seen_decisions.add((scope,d['decision_id']));self.statuses[d['status']]+=1
            for key in ('elapsed_seconds','active_seconds','resume_calls'):self.decision_totals[key]+=d[key]
            self.decision_totals['max_resume_seconds']=max(self.decision_totals['max_resume_seconds'],d['max_resume_seconds'])
            if d['status']=='completed':
                self.decision_totals['completed_with_evaluations' if 'evaluations'in d else 'completed_without_evaluations']+=1
                if 'evaluations'in d:self.decision_totals['known_completed_score_calls']+=d['evaluations']
            self.decisions.append({**d,'scope':scope,'window_id':w['window_id']})
        self.decisions.sort(key=lambda d:d['elapsed_seconds'],reverse=True)
        self.decisions=self.decisions[:self.limits['max_examples']]
    def report(self):
        metrics={}
        for name,m in sorted(self.metrics.items()):
            metrics[name]={**m,'mean_seconds':m['total_seconds']/m['count'],
                           'histogram_quantile_bounds':{label:quantile_bounds(m['histogram'],m['count'],q) for label,q in [('p50',50),('p95',95),('p99',99)]}}
        scopes={}
        for key,s in self.scopes.items():
            scopes[key]={**s,'tail_status':'unflushed_or_missing_compact_tail_cannot_be_excluded'}
            if s['last_window_end_seconds'] is not None and s['last_monotonic_seconds'] is not None:
                scopes[key]['last_event_minus_last_window_end_seconds']=s['last_monotonic_seconds']-s['last_window_end_seconds']
        return {'schema':1,'status':'incomplete' if self.errors else 'parsed_supplied_records',
                'complete_session_claimed':False,'limits':self.limits,'inputs':self.inputs,'errors':self.errors,
                'archive_integrity':{'supplied_frame_links_validated':self.archive_links,
                    'outside_predecessors_verified':False,'cross_file_segment_order':'strictly_increasing_not_necessarily_consecutive'},
                'events':self.events,'decoded_bytes':self.decoded_bytes,'performance_windows':self.windows,
                'event_anchors':{'precise':self.valid_anchors,'explicitly_unavailable':self.unavailable_anchors,'legacy_missing_precision':self.legacy_anchors},
                'metrics':metrics,'metric_groups':GROUPS,'bucket_upper_seconds':BUCKETS,
                'decisions':{'recorded':self.decisions_seen,'status_counts':self.statuses,**self.decision_totals,
                             'source_dropped':self.dropped_decisions,'examples_omitted':max(0,self.decisions_seen-len(self.decisions)),
                             'largest_elapsed_examples':self.decisions},
                'slow_frames':{'recorded':self.slow_seen,'source_dropped':self.dropped_slow,
                               'examples_omitted':max(0,self.slow_seen-len(self.slow)),'largest_reported_gap_or_update_examples':self.slow},
                'clock_failures_in_windows':self.clock_failures,'scopes':scopes,
                'interpretation':[
                  'Elapsed wall measurements are not CPU utilization. No CPU percentage is inferred.',
                  'Nested metrics overlap parents; do not sum journal, snapshot, refresh or decision measurements into update/draw totals.',
                  'update_total excludes performance_emit. Frame interval and update_argument_dt are broad inter-frame timing, not animation or outside-update CPU attribution.',
                  'Histogram percentiles are bucket bounds only, never exact percentiles. Means are weighted by counts, not means of window means.',
                  'Decision elapsed wall time includes waits/yields; active time sums measured resumes and maximum chunk is separate. Missing completed evaluations are unknown, never zero.',
                  'Only supplied complete compact windows are summarized. The last summary write and later work may await a missing/unflushed next window; an orderly final tail is not proven.',
                  'Legacy second-resolution UTC records do not recover precise elapsed timings. JSONL files are independent clock scopes; archive segments share their validated session identity.',
                  'Each supplied BRJ2 file is one original segment. Supplied same-session frames require matching predecessor hashes and increasing segment IDs across files; an earlier fragment or later tail may still be missing.'
                ]}

class LimitedReader:
    def __init__(self,stream,size):self.stream=stream;self.remaining=size;self.bytes=0;self.hash=hashlib.sha256()
    def read(self,n):
        raw=self.stream.read(min(n,self.remaining));self.remaining-=len(raw);self.bytes+=len(raw);self.hash.update(raw);return raw
    def readline(self,n):
        raw=self.stream.readline(min(n,self.remaining));self.remaining-=len(raw);self.bytes+=len(raw);self.hash.update(raw);return raw

def analyze(inputs,options=None):
    summary=Summary(options);paths=[Path(p) for p in inputs];total=0;actual_total=0;seen=set()
    try:
        require(0<len(paths)<=summary.limits['max_files'],'Explicit file count exceeds its cap')
        for path in paths:
            resolved=path.resolve();require(resolved not in seen,'Duplicate input path');seen.add(resolved)
            require(path.is_file(),'Input is not an explicit regular file: '+str(path))
            size=path.stat().st_size;require(size<=summary.limits['max_file_bytes'],'Input file byte cap exceeded')
            total+=size;require(total<=summary.limits['max_total_bytes'],'Total input byte cap exceeded')
        for path in paths:
            entry={'path':str(path),'status':'reading'};summary.inputs.append(entry)
            reader=None
            try:
                with path.open('rb') as stream:
                    before=os.fstat(stream.fileno());size=before.st_size
                    require(size<=summary.limits['max_file_bytes'],'Input grew beyond file cap')
                    actual_total+=size;require(actual_total<=summary.limits['max_total_bytes'],'Inputs grew beyond total byte cap')
                    reader=LimitedReader(stream,size)
                    iterator=records(reader)
                    while reader.remaining:
                        require(summary.events<summary.limits['max_events'],'Event cap reached; suffix not decoded')
                        try:raw,meta=next(iterator)
                        except StopIteration:raise TimingError('Input truncated while reading') from None
                        summary.consume(raw,meta,str(path.resolve()))
                    after=os.fstat(stream.fileno())
                    require(before.st_size==after.st_size and before.st_mtime_ns==after.st_mtime_ns,'Input changed while reading; retry only on a stable explicit copy')
                    entry.update(status='parsed',stored_bytes=reader.bytes,sha256=reader.hash.hexdigest())
            except (OSError,ArchiveError,TimingError,RecursionError,OverflowError) as error:
                entry['status']='incomplete'
                if reader:entry.update(stored_bytes_read=reader.bytes,prefix_sha256=reader.hash.hexdigest())
                raise
    except (OSError,ArchiveError,TimingError,RecursionError,OverflowError) as error:
        summary.errors.append({'reason':str(error)[:512],'complete_prefix_events':summary.events,'remaining_inputs_not_read':True})
    return summary.report()

def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('inputs',nargs='+',type=Path,help='Explicit stable JSONL or BRJ2 files; no discovery')
    parser.add_argument('--output',type=Path,help='Create a new JSON report; never overwrite an existing file')
    for key,value in DEFAULT.items():parser.add_argument('--'+key.replace('_','-'),type=int,default=value)
    args=parser.parse_args(argv)
    try:report=analyze(args.inputs,{key:getattr(args,key) for key in DEFAULT})
    except TimingError as error:parser.error(str(error))
    output=json.dumps(report,indent=2,allow_nan=False)+'\n'
    if args.output:
        with args.output.open('x',encoding='utf-8',newline='\n')as f:f.write(output)
    else:sys.stdout.write(output)
    return 1 if report['status']=='incomplete' else 0
if __name__=='__main__':raise SystemExit(main())

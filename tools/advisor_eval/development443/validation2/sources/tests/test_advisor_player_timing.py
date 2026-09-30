"""Manufactured bounded JSONL/BRJ2 files only; never inspect real player logs."""
import copy
import hashlib
import io
import json
from pathlib import Path
import tempfile
import unittest
import zlib
from unittest.mock import patch
from tools.advisor_eval import analyze_player_timing as A

def raw(event):return (json.dumps(event,separators=(',',':'),allow_nan=False)+'\n').encode()
def metric(values):
    h=[0]*11
    for value in values:
        index=next((i for i,upper in enumerate(A.BUCKETS) if value<=upper),10);h[index]+=1
    return {'count':len(values),'total_seconds':sum(values),'max_seconds':max(values),'histogram':h}
def event(seq=1,kind='performance_window',start=0,end=5):
    return {'schema':1,'sequence':seq,'kind':kind,'at':'2026-09-15T08:00:00Z',
            'monotonic_seconds':end,'monotonic_status':'available','context':{},
            'details':{'schema':1,'window_id':seq,'clock_scope':'process_monotonic','units':'seconds',
                       'start_seconds':start,'end_seconds':end,'bucket_upper_seconds':A.BUCKETS,
                       'metrics':{},'slow_frames':{},'decisions':{},'slow_frames_dropped':0,'decisions_dropped':0,'flags':{}}}
def decision(ident=1,status='completed',evaluations=100):
    d={'decision_id':ident,'phase':'shop','status':status,'started_seconds':1,'finished_seconds':3,
       'elapsed_seconds':2,'active_seconds':.5,'resume_calls':3,'max_resume_seconds':.25}
    if evaluations is not None:d['evaluations']=evaluations
    return d
def frame(e,session='synthetic',segment=1,previous='-',compressed=False):
    original=raw(e)
    body=raw({'schema':2,'session':session,'segment':segment,'previous_frame_sha256':previous,'event_json':original.decode()})
    digest=lambda x:hashlib.sha256(x).hexdigest()
    payload=zlib.compress(body) if compressed else body
    header='\t'.join(['BRJ2','zlib' if compressed else 'raw',str(len(payload)),str(len(body)),str(e['sequence']),digest(body),digest(original)])+'\n'
    result=header.encode()+payload+b'\n'
    return result,digest(result)

class Timing(unittest.TestCase):
    def setUp(self):self.temp=tempfile.TemporaryDirectory();self.folder=Path(self.temp.name)
    def tearDown(self):self.temp.cleanup()
    def file(self,name,events):
        path=self.folder/name;path.write_bytes(events if isinstance(events,bytes) else b''.join(raw(e) for e in events));return path
    def analyze(self,events,options=None):return A.analyze([self.file('test.jsonl',events)],options)
    def test_weighted_histogram_counts_and_means(self):
        one,two=event(),event(2,start=5,end=10)
        one['details']['metrics']={'advisor_update':metric([.001])}
        two['details']['metrics']={'advisor_update':metric([.1]*9)}
        report=self.analyze([one,two]);m=report['metrics']['advisor_update']
        self.assertEqual(report['status'],'parsed_supplied_records');self.assertEqual(m['count'],10)
        self.assertAlmostEqual(m['mean_seconds'],.0901)
        self.assertEqual(m['histogram_quantile_bounds']['p95']['rank'],10)
        self.assertEqual(m['histogram_quantile_bounds']['p50']['lower_seconds'],.05)
        self.assertEqual(m['histogram_quantile_bounds']['p50']['upper_seconds'],.1)
        self.assertFalse(m['histogram_quantile_bounds']['p50']['exact_percentile'])
    def test_nested_totals_remain_separate_and_gap_overflow_is_a_bound(self):
        e=event();e['details']['metrics']={name:metric([v]) for name,v in
            [('update_total',.2),('snapshot.capture',.15),('journal.total',.2),('frame_interval',6),('performance_emit',.1)]}
        report=self.analyze([e])
        self.assertEqual(report['metrics']['update_total']['total_seconds'],.2)
        self.assertNotIn('combined_total_seconds',report);self.assertNotIn('cpu_percent',report)
        bounds=report['metrics']['frame_interval']['histogram_quantile_bounds']['p99']
        self.assertEqual(bounds['lower_seconds'],5);self.assertIsNone(bounds['upper_seconds'])
        self.assertTrue(any('not animation' in x for x in report['interpretation']))
    def test_decision_active_wall_and_missing_evaluations_are_distinct(self):
        e=event();e['details']['decisions']=[decision(),decision(2,evaluations=None),decision(3,'cancelled',None),decision(4,'error',None)]
        d=self.analyze([e])['decisions']
        self.assertEqual(d['recorded'],4);self.assertEqual(d['elapsed_seconds'],8);self.assertEqual(d['active_seconds'],2)
        self.assertEqual(d['max_resume_seconds'],.25);self.assertEqual(d['known_completed_score_calls'],100)
        self.assertEqual(d['completed_with_evaluations'],1);self.assertEqual(d['completed_without_evaluations'],1)
        self.assertEqual(d['status_counts'],{'completed':2,'cancelled':1,'error':1})
    def test_cancelled_evaluations_reject_entire_window(self):
        e=event();e['details']['decisions']=[decision(status='cancelled')]
        report=self.analyze([e]);self.assertEqual(report['status'],'incomplete');self.assertEqual(report['performance_windows'],0)
    def test_legacy_and_explicit_unavailable_precision(self):
        old=event(kind='action_requested');old.pop('monotonic_seconds');old.pop('monotonic_status')
        unavailable=event(2,kind='action_callback_result');unavailable.pop('monotonic_seconds');unavailable['monotonic_status']='unavailable'
        report=self.analyze([old,unavailable])
        self.assertEqual(report['event_anchors'],{'precise':0,'explicitly_unavailable':1,'legacy_missing_precision':1})
        self.assertEqual(report['performance_windows'],0);self.assertFalse(report['complete_session_claimed'])
    def test_dropped_examples_and_bounded_largest_selection(self):
        e=event();w=e['details'];w['slow_frames_dropped']=7;w['decisions_dropped']=3
        w['slow_frames']=[{'at_seconds':i,'frame_interval_seconds':i/2,'flags':{'dragging':False}}for i in range(1,5)]
        w['decisions']=[decision(i)for i in range(1,5)]
        r=self.analyze([e],{'max_examples':2})
        self.assertEqual(r['slow_frames']['source_dropped'],7);self.assertEqual(r['slow_frames']['examples_omitted'],2)
        self.assertEqual(r['slow_frames']['largest_reported_gap_or_update_examples'][0]['frame_interval_seconds'],2)
        self.assertEqual(r['decisions']['source_dropped'],3);self.assertEqual(r['decisions']['examples_omitted'],2)
    def test_duplicate_window_never_counted_twice(self):
        e,f=event(),event(2,start=5,end=10);f['details']['window_id']=1
        r=self.analyze([e,f]);self.assertEqual(r['status'],'incomplete');self.assertEqual(r['performance_windows'],1)
        self.assertIn('Duplicate performance window',r['errors'][0]['reason'])
    def test_separate_jsonl_files_do_not_share_clock_or_ids(self):
        p=self.file('one.jsonl',[event(start=100,end=105)]);q=self.file('two.jsonl',[event(start=0,end=5)])
        r=A.analyze([p,q]);self.assertEqual(r['status'],'parsed_supplied_records');self.assertEqual(r['performance_windows'],2)
        self.assertEqual(len(r['scopes']),2)
    def test_archive_segments_share_validated_session_scope(self):
        first,h=frame(event());second,_=frame(event(2,start=5,end=10),segment=2,previous=h)
        r=A.analyze([self.file('one.brj',first),self.file('two.brj',second)])
        self.assertEqual(r['performance_windows'],2);self.assertEqual(len(r['scopes']),1)
        self.assertTrue(all(len(x['sha256'])==64 for x in r['inputs']))
    def test_compressed_archive_window_roundtrip(self):
        e=event();e['details']['metrics']={'update_total':metric([.01,.02])}
        encoded,_=frame(e,compressed=True)
        r=A.analyze([self.file('compressed.brj',encoded)])
        self.assertEqual(r['status'],'parsed_supplied_records')
        self.assertEqual(r['metrics']['update_total']['count'],2)
        self.assertEqual(r['metrics']['update_total']['total_seconds'],.03)
    def test_different_archive_processes_may_restart_ids_and_clocks(self):
        first,_=frame(event(start=100,end=105),session='process1');second,_=frame(event(),session='process2')
        r=A.analyze([self.file('one.brj',first),self.file('two.brj',second)])
        self.assertEqual(r['status'],'parsed_supplied_records');self.assertEqual(len(r['scopes']),2)
    def test_archive_corrupt_suffix_preserves_complete_prefix(self):
        first,h=frame(event());second,_=frame(event(2,start=5,end=10),previous=h)
        r=self.analyze(first+second[:-3]+b'bad')
        self.assertEqual(r['status'],'incomplete');self.assertEqual(r['performance_windows'],1)
        self.assertIn('prefix_sha256',r['inputs'][0]);self.assertNotIn('sha256',r['inputs'][0])
    def test_truncated_jsonl_tail_is_not_silently_ignored(self):
        r=self.analyze(raw(event())+b'{"schema":1')
        self.assertEqual(r['events'],1);self.assertEqual(r['status'],'incomplete')
    def test_event_cap_does_not_decode_extra_bad_event(self):
        r=self.analyze(raw(event())+b'not JSON\n',{'max_events':1})
        self.assertEqual(r['events'],1);self.assertIn('Event cap',r['errors'][0]['reason'])
        r=self.analyze([event()],{'max_events':1});self.assertEqual(r['status'],'parsed_supplied_records')
    def test_stored_and_decoded_byte_caps(self):
        e=event();size=len(raw(e))
        r=self.analyze([e],{'max_file_bytes':size-1});self.assertEqual(r['events'],0)
        r=self.analyze([e],{'max_total_bytes':size-1});self.assertEqual(r['events'],0)
        r=self.analyze([e],{'max_decoded_bytes':size-1});self.assertEqual(r['events'],0);self.assertIn('Decoded-byte',r['errors'][0]['reason'])
    def test_explicit_inputs_only_and_duplicate_paths(self):
        p=self.file('one.jsonl',[event()]);q=self.file('two.jsonl',[event()])
        self.assertEqual(A.analyze([p,q],{'max_files':1})['events'],0)
        self.assertEqual(A.analyze([p,p])['events'],0)
        self.assertEqual(A.analyze([self.folder])['events'],0)
        with self.assertRaises(A.TimingError):A.analyze([p],{'max_events':A.HARD['max_events']+1})
    def test_malformed_histograms_and_unknown_labels_decline(self):
        for mutation in ('count','max','buckets','label'):
            e=event();w=e['details'];w['metrics']={'update_total':metric([.001])}
            if mutation=='count':w['metrics']['update_total']['histogram'][0]=2
            if mutation=='max':w['metrics']['update_total']['max_seconds']=.02
            if mutation=='buckets':w['bucket_upper_seconds']=[1]*10
            if mutation=='label':w['metrics']={'unknown.cpu':metric([.001])}
            r=self.analyze([e]);self.assertEqual(r['status'],'incomplete');self.assertEqual(r['performance_windows'],0)
    def test_partial_tail_is_explicit_after_a_last_regular_event(self):
        r=self.analyze([event(),event(2,'action_requested',end=5.5)])
        scope=next(iter(r['scopes'].values()));self.assertEqual(scope['events_after_last_window'],1)
        self.assertEqual(scope['last_event_minus_last_window_end_seconds'],.5)
        self.assertIn('cannot_be_excluded',scope['tail_status'])
    def test_duplicate_decision_rejects_whole_new_window(self):
        e,f=event(),event(2,start=5,end=10)
        e['details']['decisions']=[decision()];f['details']['decisions']=[decision()]
        r=self.analyze([e,f]);self.assertEqual(r['performance_windows'],1);self.assertEqual(r['decisions']['recorded'],1)
    def test_clock_regression_and_overlap_fail_closed(self):
        e,f=event(),event(2,start=4,end=10)
        self.assertEqual(self.analyze([e,f])['status'],'incomplete')
        f=event(2,kind='action_requested',end=4)
        self.assertEqual(self.analyze([e,f])['status'],'incomplete')
    def test_output_is_exclusive_and_inputs_remain_unchanged(self):
        p=self.file('one.jsonl',[event()]);before=p.read_bytes();out=self.folder/'report.json'
        self.assertEqual(A.main([str(p),'--output',str(out)]),0)
        self.assertEqual(p.read_bytes(),before);saved=out.read_bytes()
        with self.assertRaises(FileExistsError):A.main([str(p),'--output',str(out)])
        self.assertEqual(out.read_bytes(),saved)
    def test_nan_json_and_invalid_duration_fail_without_partial_credit(self):
        e=event();e['details']['metrics']={'update_total':metric([.001])}
        data=raw(e).replace(b'"total_seconds":0.001',b'"total_seconds":NaN')
        r=self.analyze(data);self.assertEqual(r['status'],'incomplete');self.assertEqual(r['performance_windows'],0)
        e['details']['decisions']=[decision()];e['details']['decisions'][0]['active_seconds']=5
        self.assertEqual(self.analyze([e])['status'],'incomplete')
    def test_bad_clock_failure_and_dropped_field_types_do_not_escape(self):
        for field in ('clock_failures','slow_frames_dropped','decisions_dropped'):
            e=event();e['details'][field]={'invalid':'type'}
            r=self.analyze([e]);self.assertEqual(r['status'],'incomplete');self.assertEqual(r['performance_windows'],0)

if __name__=='__main__':unittest.main()

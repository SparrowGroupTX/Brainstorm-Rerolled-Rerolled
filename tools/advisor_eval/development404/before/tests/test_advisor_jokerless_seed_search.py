import importlib.util
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('jokerless_seed_search',ROOT/'tools/advisor_eval/jokerless_seed_search.py')
search=importlib.util.module_from_spec(spec);spec.loader.exec_module(search)


class JokerlessSeedAuthorizationTests(unittest.TestCase):
    def authority(self):
        return {'worker_deadline_utc':'2026-09-13T19:18:00+00:00','allowances':{'seed_search_agent':{
            'source_mechanical_workers':12,'per_mechanical_seconds':15,
            'mechanical_seconds_total':180,'seed_search_seconds_total':300}}}

    def test_complete_lease_must_fit_deadline(self):
        authority=self.authority();deadline=datetime(2026,9,13,19,18,tzinfo=timezone.utc)
        search.require_worker_time(authority,15,deadline-timedelta(seconds=15))
        with self.assertRaisesRegex(ValueError,'does not fit'):
            search.require_worker_time(authority,15,deadline-timedelta(seconds=14))
        with self.assertRaisesRegex(ValueError,'does not fit'):
            search.require_worker_time(authority,1,deadline)

    def test_resume_binds_original_and_existing_requests(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);original=root/'authorization.json';request=root/'request.json'
            original.write_text(json.dumps(self.authority()),encoding='utf-8')
            request.write_text('{"note":"Blue seal — source evidence"}',encoding='utf-8')
            resumed=self.authority();resumed.update(resumes_authorization='original/path/authorization.json',
                resumes_authorization_sha256=search.sha(original),existing_registrations_at_resume={'request.json':search.sha(request)})
            path=root/'resume.json';path.write_text(json.dumps(resumed),encoding='utf-8')
            self.assertEqual(search.read_authority(path)['allowances'],self.authority()['allowances'])
            request.write_text('{}',encoding='utf-8')
            with self.assertRaisesRegex(ValueError,'Previously registered request changed'):search.read_authority(path)

    def test_resume_never_renews_seed_allowance(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);path=root/'authorization.json';authority=self.authority()
            authority['allowances']['seed_search_agent']['seed_search_seconds_total']=600
            path.write_text(json.dumps(authority),encoding='utf-8')
            with self.assertRaisesRegex(ValueError,'Unexpected authorization'):search.read_authority(path)


if __name__=='__main__':unittest.main()

"""Synthetic temporary files only; never runs preparation on real cycle files."""
from pathlib import Path
import tempfile
import unittest
from publish_status import publish, outcomes, NAVIGATION
from close_cycle import sha, read, encoded


class Publication(unittest.TestCase):
    def test_all_navigation_archived_and_immutable_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); archive = root/'archive'
            for n in NAVIGATION: (root/n).write_text('old:'+n)
            immutable=root/'SESSION_RESET_321.json';immutable.write_text('immutable')
            old={n:sha(root/n) for n in NAVIGATION};immutable_hash=sha(immutable)
            context=root/'context/context.json'
            plan={'root':root,'archive':archive,'context_path':context,'context':{'status':'CLOSED'},
                  'new':{'SESSION_STATUS_321_CLOSED.md':b'closed'},
                  'navigation':{n:('new:'+n).encode() for n in NAVIGATION},'expected_navigation':old,'refs':{}}
            receipt=publish(plan)
            self.assertFalse(receipt['runtime_changed'])
            self.assertEqual(sha(immutable),immutable_hash)
            for n in NAVIGATION:
                self.assertEqual(sha(archive/'previous_navigation'/n),old[n])
                self.assertEqual((root/n).read_text(),'new:'+n)
            self.assertEqual(read(context),{'status':'CLOSED'})
            with self.assertRaises(AssertionError): publish(plan)

    def test_changed_navigation_declines_before_any_archive(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for n in NAVIGATION:(root/n).write_text('old')
            expected={n:sha(root/n) for n in NAVIGATION};(root/NAVIGATION[1]).write_text('new user work')
            with self.assertRaises(AssertionError): publish({'root':root,'archive':root/'archive','expected_navigation':expected})
            self.assertFalse((root/'archive').exists())
            self.assertEqual((root/NAVIGATION[1]).read_text(),'new user work')

    def test_selected_corrected_audit_not_initial_error(self):
        jobs=[{'job':'C01','selected_audit':'audit_verified.json','audits':{
            'audit.json':{'summary':{'disposition':'win','audit_issues':['wrong helper']}},
            'audit_verified.json':{'summary':{'disposition':'loss','audit_issues':[]}}}}]
        self.assertEqual(outcomes(jobs)['loss'],1);self.assertEqual(outcomes(jobs)['win'],0)
        self.assertEqual(jobs[0]['audits']['audit.json']['summary']['audit_issues'],['wrong helper'])

    def test_missing_terminal_outcome_not_imputed(self):
        with self.assertRaises(AssertionError):outcomes([{'job':'C01','selected_audit':'audit.json','audits':{'audit.json':{'summary':{}}}}])


if __name__=='__main__':unittest.main()

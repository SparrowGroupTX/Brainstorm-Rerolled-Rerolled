"""Pure manufactured registration checks; no worker or policy execution."""
import copy
import unittest

from followup_source_audit import SAME_ADAPTER, SAME_METADATA, verify_followup


class FollowupDesignTests(unittest.TestCase):
    def setUp(self):
        self.hashes = {'registration': 'reg', 'record': 'record', 'audit': 'audit'}
        self.reference = {'job': 'C02', 'authority_sha256': 'authority', 'timeout_seconds': 180,
                          'external_files': {'python': 'py', 'source': 'exe', 'lua': 'dll'},
                          'metadata': {key: 'same' for key in SAME_METADATA},
                          'files': {key: 'unchanged' for key in SAME_ADAPTER}}
        self.reference['metadata']['policy_digest'] = 'prior'
        self.reference['files']['policy/concealed.lua'] = 'eight'
        self.candidate = copy.deepcopy(self.reference)
        self.candidate['job'] = 'C05'
        self.candidate['files']['policy/concealed.lua'] = 'nine'
        self.candidate['metadata'].update({
            'policy_digest': 'new', 'comparison_design': 'prospective_followup_using_already_spent_dependent_reference',
            'comparison_role': 'followup_candidate', 'prior_comparison_job': 'C02',
            'fresh_reciprocal_pair': False, 'prior_comparison_policy_digest': 'prior',
            'changed_policy_files': {'concealed.lua': {'prior_sha256': 'eight', 'candidate_sha256': 'nine'}},
            **{'prior_comparison_' + name + '_sha256': value for name, value in self.hashes.items()}})

    def check(self):
        return verify_followup('C02', 'C05', self.reference, self.candidate, self.hashes)

    def test_declared_dependent_followup(self):
        original = copy.deepcopy((self.reference, self.candidate))
        self.assertTrue(self.check()['same_adapter_and_recipe_hashes'])
        self.assertEqual(original, (self.reference, self.candidate))

    def test_old_record_hash_cannot_change(self):
        self.candidate['metadata']['prior_comparison_record_sha256'] = 'changed'
        with self.assertRaises(AssertionError):
            self.check()

    def test_no_reciprocal_pair(self):
        self.candidate['metadata']['paired_job'] = 'C02'
        with self.assertRaises(AssertionError):
            self.check()

    def test_same_caps(self):
        self.candidate['timeout_seconds'] = 181
        with self.assertRaises(AssertionError):
            self.check()

    def test_same_profile(self):
        self.candidate['metadata']['profile'] = 'different'
        with self.assertRaises(AssertionError):
            self.check()

    def test_same_adapter(self):
        self.candidate['files']['engine_run.lua'] = 'changed'
        with self.assertRaises(AssertionError):
            self.check()

    def test_same_runtime(self):
        self.candidate['external_files']['lua'] = 'changed'
        with self.assertRaises(AssertionError):
            self.check()

    def test_no_undeclared_policy_change(self):
        self.candidate['files']['policy/concealed.lua'] = 'different'
        with self.assertRaises(AssertionError):
            self.check()


if __name__ == '__main__':
    unittest.main()

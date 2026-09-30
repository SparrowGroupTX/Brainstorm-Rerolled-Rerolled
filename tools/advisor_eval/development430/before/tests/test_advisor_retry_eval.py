"""Retry-context provenance protocol tests; no game/source workers execute."""
import copy
import json
import re
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

TOOLS=Path(__file__).resolve().parents[1]/'tools/advisor_eval'
sys.path.insert(0,str(TOOLS))
import engine_probe as E
import paired_policy_audit as P


class RetryEvalTests(unittest.TestCase):
    def fixture(self):
        spec=E.retry_context_spec()
        provenance={'retry_context_spec':spec,'retry_context_spec_digest':P.digest(spec)}
        return spec,provenance,[E.retry_context_record(),{'type':'engine_episode_action'}]

    def test_clean_declaration_requires_actual_matching_receipt(self):
        spec,origin,rows=self.fixture()
        context=E.applied_retry_context(rows,origin,spec)
        self.assertEqual(context['mode'],'disabled_clean_attempt_v1')
        self.assertIs(context['retry_advice_evaluated'],False)
        self.assertEqual(context['checkpoint_reloads_observed'],0)
        for invalid in ([],rows[1:],rows[:1]+rows[:1]+rows[1:]):
            with self.subTest(rows=invalid), self.assertRaises(ValueError):
                E.applied_retry_context(invalid,origin,spec)

    def test_actual_lua_receipt_matches_host_schema_and_precedes_dispatch(self):
        source=(TOOLS/'engine_run.lua').read_text(encoding='utf-8')
        body=re.search(r'local clean_retry_context=\{([^}]+)\}',source).group(1)
        actual={}
        for key,token in re.findall(r"([a-z_]+)=('[^']*'|true|false|\d+)",body):
            actual[key]=token[1:-1] if token.startswith("'") else token=='true' if token in ('true','false') else int(token)
        self.assertEqual(actual,E.retry_context_spec())
        self.assertLess(source.index("type='engine_probe_retry_context'"),source.index('decision.run(s,modules)'))
        self.assertNotRegex(source,r"require\(['\"]probe_policy_retry_")
        self.assertNotIn('journal_path',source)

    def test_receipt_must_precede_decisions_or_terminal_outcomes(self):
        spec,origin,rows=self.fixture()
        for kind in ('engine_episode_decision_started','engine_episode_terminal','engine_episode_action'):
            with self.subTest(kind=kind),self.assertRaisesRegex(ValueError,'before episode'):
                E.applied_retry_context([{'type':kind},rows[0]],origin,spec)

    def test_retry_claims_and_implicit_checkpoint_events_cannot_be_admitted(self):
        for key,value in [('mode','manual_checkpoint_v1'),('max_checkpoint_reloads',5),
                          ('journal_access','user'),('initial_memory','existing'),
                          ('retry_advice_evaluated',True),('checkpoint_restore','supported')]:
            spec,origin,rows=self.fixture();origin['retry_context_spec']=copy.deepcopy(spec)
            origin['retry_context_spec'][key]=value
            origin['retry_context_spec_digest']=P.digest(origin['retry_context_spec'])
            with self.subTest(key=key),self.assertRaisesRegex(ValueError,'Unsupported'):
                E.applied_retry_context(rows,origin,spec)
        spec,origin,rows=self.fixture()
        for kind in ('engine_retry_restored','engine_checkpoint_reload_requested'):
            with self.subTest(kind=kind),self.assertRaisesRegex(ValueError,'unsupported'):
                E.applied_retry_context(rows+[{'type':kind}],origin,spec)

    def test_bool_zero_coercion_and_forged_actual_counts_are_rejected(self):
        spec,origin,rows=self.fixture();origin['retry_context_spec']['max_checkpoint_reloads']=False
        origin['retry_context_spec_digest']=P.digest(origin['retry_context_spec'])
        with self.assertRaises(ValueError):E.applied_retry_context(rows,origin,E.retry_context_spec())
        for key,value in [('checkpoint_reloads_observed',1),('checkpoint_reloads_observed',False),
                          ('initialized_before_decision',False),('qualification_compatible',True)]:
            spec,origin,rows=self.fixture();rows[0][key]=value
            with self.subTest(key=key,value=value),self.assertRaises(ValueError):
                E.applied_retry_context(rows,origin,spec)

    def test_historical_absence_is_unreported_never_retroactive_retry_support(self):
        context=E.applied_retry_context([{'type':'engine_episode_terminal'}],{})
        self.assertEqual(context['mode'],'historical_unreported')
        self.assertFalse(context['retry_advice_evaluated'])
        spec,origin,rows=self.fixture()
        with self.assertRaisesRegex(ValueError,'historical registration'):
            E.applied_retry_context(rows,origin)
        with self.assertRaises(ValueError):
            E.applied_retry_context([{'type':'engine_retry_restored'}],{})

    def test_new_registration_binds_spec_without_reading_external_memory_or_executing(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);product=root/'product';install=root/'install';install.mkdir()
            for relative in ('Advisor/decision.lua','Core/Brainstorm.lua','Core/challenge_opening.lua',
                             'UI/advisor.lua','UI/ui.lua','UI/challenge_opening.lua','lovely.toml'):
                path=product/'Brainstorm'/relative;path.parent.mkdir(parents=True,exist_ok=True);path.write_text('return {}')
            (install/'Balatro.exe').write_bytes(b'not executable');(install/'lua51.dll').write_bytes(b'not a runtime')
            with patch.object(P,'collect') as collect:
                manifest=P.initialize(root/'run',{role:product for role in P.ROLES},install,
                    [{'challenge':'c_jokerless_1','seed':'PROTOCOL'}],1,None)
                collect.assert_not_called()
            self.assertEqual(manifest['retry_context_spec'],E.retry_context_spec())
            self.assertEqual(manifest['retry_context_spec_digest'],P.digest(E.retry_context_spec()))
            missing=copy.deepcopy(manifest)
            missing.pop('retry_context_spec');missing.pop('retry_context_spec_digest');missing.pop('manifest_digest')
            missing['manifest_digest']=P.digest(missing);P.write_json(root/'run/manifest.json',missing)
            with self.assertRaisesRegex(ValueError,'Unsupported'):P.verify_manifest(root/'run')
            manifest['retry_context_spec']['max_checkpoint_reloads']=5
            manifest['retry_context_spec_digest']=P.digest(manifest['retry_context_spec'])
            manifest.pop('manifest_digest');manifest['manifest_digest']=P.digest(manifest)
            P.write_json(root/'run/manifest.json',manifest)
            with self.assertRaisesRegex(ValueError,'Unsupported'):P.verify_manifest(root/'run')


if __name__=='__main__':unittest.main()

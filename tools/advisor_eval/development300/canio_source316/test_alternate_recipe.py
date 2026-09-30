"""Pure JSON recipe/profile qualification; no native, source or player I/O."""
from pathlib import Path
from types import SimpleNamespace
import copy,json,unittest
from normal_recipe import validate
from gold_objective_spec import build
HERE=Path(__file__).resolve().parent
class Alternate(unittest.TestCase):
    def setUp(self):
        self.recipe=json.loads((HERE/'normal_opening_recipe.json').read_text())
    def test_exact_observed_recipe(self):
        self.assertEqual(validate(self.recipe,'ITKSGS21','b_red',8),self.recipe)
        self.assertEqual(self.recipe['expected_opening_jokers'],['j_caino','j_perkeo'])
    def test_old_api9_route_unchanged(self):
        old=json.loads((HERE.parents[1]/'runs/gold299_20260914/C05/normal_opening_recipe.json').read_text())
        self.assertEqual(validate(old,'S7PXV521','b_red',8),old)
    def test_all_identity_and_resource_tampering_rejected(self):
        changes=[(['expected_opening_jokers'],['j_yorick','j_perkeo']),
          (['filter_info','joker_targets'],'Yorick\x1fBrainstorm\x1fBurnt Joker\x1fPerkeo\x1f'),
          (['filter_info','collection_search','primary_legendary_key'],'j_chicot'),
          (['filter_info','collection_search','minimum_distinct'],0),
          (['filter_info','collection_search','missing_names'],'Yorick'),
          (['filter_info','collection_search','quota_mode'],'strict'),
          (['filter_info','collection_search','burnt_required'],False),
          (['filter_info','collection_search','observed_copy_key'],'j_brainstorm'),
          (['filter_info','collection_search','future_acquisition_verified'],True),
          (['filter_info','collection_search','native_result','seed'],'OTHER'),
          (['filter_info','collection_search','native_result','budget_ms'],18000),
          (['filter_info','collection_search','native_result','exact_candidates'],0),
          (['filter_info','normal_opening','targets',0,'key'],'j_yorick'),
          (['filter_info','no_perishable_jokers'],False),
          (['filter_info','filter_params',27],27000),
          (['filter_info','filter_params',22],False),
          (['filter_info','filter_params',23],''),
          (['filter_info','filter_params',24],0),
          (['filter_info','collection_search'],[]),(['filter_info'],[])]
        for path,value in changes:
            with self.subTest(path=path):
                recipe=copy.deepcopy(self.recipe);node=recipe
                for key in path[:-1]:node=node[key]
                node[path[-1]]=value
                with self.assertRaises(ValueError):validate(recipe,'ITKSGS21','b_red',8)
    def test_alternate_profile_is_explicit_and_old_mode_retained(self):
        args=SimpleNamespace(gold_objective='synthetic_only_canio_missing_v1',episode=True,
          deck='b_red',stake=8,unlock_profile='all_unlocked_discovered_v1',
          normal_filter_recipe='recipe.json',seed_selection_evidence='selection.json')
        spec=build(args);self.assertEqual(spec['initial_counts'],dict(total=150,complete=149,missing=1,unknown=0))
        self.assertEqual(spec['missing_keys'],['j_caino']);self.assertFalse(spec['player_achievement_credit'])
        args.gold_objective='synthetic_fresh_all_missing_v1'
        self.assertEqual(build(args)['initial_counts']['missing'],150)
        args.gold_objective='off';self.assertFalse(build(args)['enabled'])
    def test_profile_refuses_existing_replay_scenario_or_player_scope(self):
        for field,value in [('episode',False),('deck','b_blue'),('stake',7),('unlock_profile','player'),
          ('normal_filter_recipe',None),('seed_selection_evidence',None),('replay_trace','trace'),('test_scenario','anything')]:
            with self.subTest(field=field):
                args=SimpleNamespace(gold_objective='synthetic_only_canio_missing_v1',episode=True,deck='b_red',stake=8,
                  unlock_profile='all_unlocked_discovered_v1',normal_filter_recipe='recipe',seed_selection_evidence='selection')
                setattr(args,field,value)
                with self.assertRaises(ValueError):build(args)
if __name__=='__main__':unittest.main(verbosity=2)

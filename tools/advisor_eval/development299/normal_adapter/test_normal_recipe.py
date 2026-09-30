"""Routine pure parser fixture. Synthetic JSON only, no original source or search."""
import copy
import json
from pathlib import Path
import tempfile
from normal_recipe import load

targets='Yorick\x1fBrainstorm\x1fBurnt Joker\x1fPerkeo'
locations='soul_pack\x1fby_ante_5\x1fby_ante_5\x1fsoul_pack'
params=['TEST','','','Charm Tag',2,False,0,False,False,False,False,False,'No Filter','Kings','Any Suit',0,0,targets,'Red Deck',locations,8,True]
record={'schema':1,'kind':'normal_filtered_product_v1','qualification':False,'seed':'TEST','deck':'b_red','stake':8,
        'expected_opening_jokers':['j_yorick','j_perkeo'],
        'filter_info':{'native_api_version':8,'stake_level':8,'required_soul_count':2,'soul_count':2,
                       'multi_soul_pack_consumed':False,'no_perishable_jokers':True,'deck_name':'Red Deck',
                       'joker_targets':targets,'joker_target_locations':locations,'filter_params':params}}
with tempfile.TemporaryDirectory(prefix='brainstorm-normal-recipe-fixture-') as directory:
    path=Path(directory)/'synthetic.json'
    path.write_text(json.dumps(record))
    result=load(path,'TEST','b_red',8)
    assert result['spec']==record and not result['native_search_executed_by_adapter']
    for changes in [('seed','OTHER'),('qualification',True),('stake',1)]:
        bad=copy.deepcopy(record);bad[changes[0]]=changes[1];path.write_text(json.dumps(bad))
        try:load(path,'TEST','b_red',8)
        except ValueError:pass
        else:raise AssertionError('Accepted mismatch '+changes[0])
    for field,value in [('required_soul_count',1),('multi_soul_pack_consumed',True),
                        ('no_perishable_jokers',False),('joker_target_locations','by_ante_8'),('deck_name','Zodiac Deck')]:
        bad=copy.deepcopy(record);bad['filter_info'][field]=value;path.write_text(json.dumps(bad))
        try:load(path,'TEST','b_red',8)
        except ValueError:pass
        else:raise AssertionError('Accepted mismatch '+field)
    bad=copy.deepcopy(record);bad['filter_info']['filter_params'][21]=False;path.write_text(json.dumps(bad))
    try:load(path,'TEST','b_red',8)
    except ValueError:pass
    else:raise AssertionError('Accepted contradictory query')
print('normal_recipe: 10 checks passed')

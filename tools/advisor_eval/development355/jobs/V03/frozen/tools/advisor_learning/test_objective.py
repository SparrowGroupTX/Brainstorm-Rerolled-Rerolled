import unittest
import numpy as np
from .objective import CompletionGoal,sticker_training_reward


class GoalTests(unittest.TestCase):
    def setUp(self):
        self.keys=[f'j_{i:03}' for i in range(150)]
        self.status={k:'complete' for k in self.keys}
        self.status[self.keys[0]]='missing';self.status[self.keys[1]]='unknown'
        self.goal=CompletionGoal(self.status,self.keys)

    def test_unique_missing_identity_only_after_eligible_win(self):
        held=[self.keys[0],self.keys[0],self.keys[1],self.keys[2]]
        self.assertEqual(self.goal.missing_held(held,True,True),[self.keys[0]])
        for eligible,won in [(False,True),(True,False),(None,True)]:
            self.assertEqual(self.goal.missing_held(held,eligible,won),[])

    def test_unverified_status_has_no_reward(self):
        goal=CompletionGoal(self.status,self.keys,verified=False)
        self.assertEqual(goal.missing_held(self.keys,True,True),[])
        self.assertTrue(np.all(goal.features[:,2]==1))

    def test_goal_exposes_missing_complete_unknown_and_redacts_hidden(self):
        ids={k:(i+1)/151 for i,k in enumerate(self.keys)}
        entities=np.zeros((4,64),np.float32);entities[:,1]=1
        entities[:3,7]=1;entities[:,9]=[ids[self.keys[i]] for i in [0,2,1,0]]
        candidates=np.zeros((1,160),np.float32);candidates[0,21:85]=entities[0]
        result=self.goal.augment({'global':np.zeros(80,np.float32),'entities':entities,'candidates':candidates},ids)
        self.assertEqual(result['global'].shape,(530,))
        np.testing.assert_array_equal(result['entities'][:,64:],[[1,0,0],[0,1,0],[0,0,1],[0,0,1]])
        np.testing.assert_array_equal(result['candidates'][0,160:],[1,0,0])

    def test_acquisition_is_not_success_and_shaping_telescopes(self):
        start={'blinds_cleared':0}
        middle={'blinds_cleared':4,'new_gold_count':3,'outcome':'ongoing'}
        end={'blinds_cleared':5,'new_gold_count':0,'outcome':'loss'}
        self.assertAlmostEqual(sticker_training_reward(middle,start,False)+sticker_training_reward(end,middle,True),0)
        end.update(outcome='win',new_gold_count=2)
        self.assertAlmostEqual(sticker_training_reward(middle,start,False)+sticker_training_reward(end,middle,True),2)

    def test_zero_new_sticker_win_earns_zero(self):
        self.assertEqual(sticker_training_reward({'outcome':'win','new_gold_count':0},{},True),0)


if __name__=='__main__':unittest.main()

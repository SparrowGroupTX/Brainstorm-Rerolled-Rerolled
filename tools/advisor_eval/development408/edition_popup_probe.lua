-- Reviewer witness, invented single remembered Joker, no engine or captured state.
local B=dofile('Brainstorm/Advisor/acorn_belief.lua')
local b=assert(B.start({{key='j_joker',ability={name='Joker',mult=4},edition={type='holo'}}},'popup408',{public_before_shuffle=true}))
local seen=B.observe(b,{epoch=b.epoch,type='rendered_status',phase='play',qualified_render=true,
 slot=1,channel='mult',amount=10,text='+10 Mult'})
assert(seen.supported and #seen.worlds==1,'Canonical type-only Holo popup must retain the true public world')
print('edition_popup_probe408 passed')

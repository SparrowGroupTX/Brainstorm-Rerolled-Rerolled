"""Deterministic public-tensor baseline, not an engine oracle or search policy.

Uses the wrapper's ordinary poker base estimate plus visible generic Joker
modifiers. It does not execute or query the simulator, enumerate futures, inspect
raw state, or know seeds. It avoids free rearrangement/reroll loops. This weak
heuristic is for comparison and optional explicitly disclosed imitation warmup.
"""
import numpy as np


def heuristic_index(observation: dict) -> int:
    g=np.asarray(observation["global"])
    e=np.asarray(observation["entities"])
    c=np.asarray(observation["candidates"])
    if not len(c): raise ValueError("At least one candidate required")
    kinds=np.argmax(c[:,:21],axis=1)
    target=c[:,21:85]
    visible_jokers=e[(e[:,1]>0)&(e[:,7]>0)]
    # Generic visible modifiers only; many conditional Joker abilities are not
    # represented here, so this is explicitly a baseline estimate, not parity.
    generic_mult=float(np.expm1(visible_jokers[:,42]).clip(0,1e6).sum()) if len(visible_jokers) else 0
    generic_chips=float(np.expm1(visible_jokers[:,44]).clip(0,1e6).sum()) if len(visible_jokers) else 0
    score=np.full(len(c),-1e6,dtype=np.float64)
    score[kinds==2]=100  # Accept current blind.
    score[kinds==4]=100  # Cash out.
    score[kinds==6]=0   # Leave shop if no beneficial affordable item.
    score[kinds==7]=-10 # Skip pack when no useful eligible pick.

    # Visible purchased modifiers; 12 is Joker set and 14 Planet set.
    item_value=(4 + np.expm1(target[:,42]).clip(0,1000)
                + np.expm1(target[:,44]).clip(0,10000)/15
                + np.expm1(target[:,43]).clip(0,100)*8
                + np.expm1(target[:,54]).clip(0,1000)/30)
    for i,kind in enumerate(kinds):
        item=target[i]
        is_joker=item[12]>0
        is_planet=item[14]>0
        if kind==8:
            # Buy a useful Joker into a free slot; rentals need a modest reserve.
            cash=float(np.expm1(g[11])); cost=float(np.expm1(item[35]))
            if is_joker and (not item[40] or cash-cost>=6):
                score[i]=item_value[i] - float(item[39])*2 - float(item[40])*3
            elif is_planet and cash-cost>=3: score[i]=2
        elif kind==12:
            # Vouchers are expensive; this baseline has no long-horizon values.
            if np.expm1(g[11])-np.expm1(item[35])>=20: score[i]=1
        elif kind==13:
            if np.expm1(g[11])-np.expm1(item[35])>=8: score[i]=1.5
        elif kind==14:
            score[i]=item_value[i] if is_joker else 8 if is_planet else 1
        elif kind==11:
            # Planet uses are always beneficial and remove inventory loops.
            if is_planet: score[i]=1e5

    plays=np.flatnonzero(kinds==0)
    if len(plays):
        # Estimate Joker additions against the public base hand's own mult.
        estimates=np.expm1(c[plays,159]).astype(np.float64)
        hand_type=np.rint(c[plays,158]*11).astype(int).clip(0,11)
        base_mult=np.expm1(g[32+4*hand_type+2]).clip(1,None)
        estimates=(estimates/base_mult+generic_chips)*(base_mult+generic_mult)
        # More score first, then fewer selected cards; stable index tie-break.
        local=np.argmax(estimates-c[plays,154]*0.01)
        best=int(plays[local]); score[plays]=estimates
        target_remaining=max(0,float(np.expm1(g[13])-np.expm1(g[12])))
        hands=max(1,float(g[14])*10)
        discards=np.flatnonzero(kinds==1)
        if len(discards) and estimates[local]<target_remaining/hands:
            kept={int(round(x*128))-1 for x in c[best,149:154] if x>0}
            options=[]
            for i in discards:
                discarded={int(round(x*128))-1 for x in c[i,149:154] if x>0}
                if not kept.intersection(discarded):
                    options.append((len(discarded),-float(c[i,159]),-int(i),int(i)))
            if options:
                score[max(options)[-1]]=max(float(score[best])+1,1e4)
    return int(np.argmax(score))

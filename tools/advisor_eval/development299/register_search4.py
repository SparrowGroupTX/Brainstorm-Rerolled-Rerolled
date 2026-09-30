from cycle import ROOT,BASE,register,read,create
import sys

prior=BASE/'S03';r=read(prior/'registration.json');request=read(prior/'request.json')
index=1299000001;remaining=index;parts=[]
digits='123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';coeff=[66231629136,1892332261,54066636,1544761,44136,1261,36,1]
for c in coeff:
    if remaining>0:
        digit=(remaining-1)//c;remaining-=1+digit*c;parts.append(digits[digit])
request.update(seed=''.join(reversed(parts)),start_index=index,max_indices=1000000000000)
path=ROOT/'tools/advisor_eval/development299/search4_request.json';create(path,request)
files={rel:prior/rel for rel in r['files']};files['request.json']=path
meta=dict(r['metadata']);meta.update(hypothesis='The exact requested RedGold opening has a match in the next fixed native interval before27s or1trillion indices,whichever ends first.',request=request)
create(prior/'audit.json',{'status':'not_found','screened':1000000000,'exact_candidates':6121,
 'scope':'Reported v9 traversal counters for static conditional route only; no purchase/survival/acquisition evidence.',
 'complete_attempt':False,'qualification':False})
register('S04',files,[sys.executable,'-B','-u','{job}/search_v9_worker.py'],meta)
print(BASE/'S04/registration.json')

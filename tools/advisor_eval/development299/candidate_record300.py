from cycle import ROOT,read,create
p=ROOT/'tools/advisor_eval/runs/phaseopening300_candidate'
create(p/'candidate_record.json',{'kind':'frozen_candidate_not_installed','version':'2.100.0-alpha','policy':read(p/'freeze.json')})
print(p/'candidate_record.json')

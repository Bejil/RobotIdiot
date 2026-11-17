#!/usr/bin/env python3
"""Contrôle reproductible hors Xcode des 100 Défis + 100 Bugs + 150 niveaux campagne.
Usage: python3 verifier_quotidiens_et_campagne.py
Dépendances Python standard seulement, outils fournis dans le dossier tools/.
ATTENTION : ne remplace pas une compilation/exécution du véritable moteur Swift.
"""
from pathlib import Path
import json,sys,collections
P=Path(__file__).resolve().parent
sys.path.insert(0,str(P/'tools'))
from robot_v7_builder import Sim
from portal_replay import replay,get_bonus
A={'SI','REPETE'}
levels=json.loads((P/'robot_idiot_daily_challenges_100.json').read_text())['levels']
bugs=json.loads((P/'robot_idiot_daily_bugs_100.json').read_text())['bugs']
camp=json.loads((P/'Robot_Idiot_150_Niveaux_V14_1_Aventure_REFERENCE_NON_MODIFIE.json').read_text())['levels']
assert len(levels)==len(bugs)==100 and len(camp)==150

def exec_daily(sim,commands):
 s=sim.initial()
 for i,c in enumerate(commands):
  ns=sim.step(s,c)
  if ns is None:return False,i,'invalid_command'
  s=ns
  if sim.win(s):return True,i+1,'win'
 return False,len(commands),'not_won'

ids=set();checks=0
for l,b in zip(levels,bugs):
 assert l['id'] not in ids;ids.add(l['id'])
 assert l['id']==b['sourceDailyChallengeId']==b['boardRef']
 unlocked=set(l['unlockedCommands']); assert not unlocked&A
 assert set(b['availableCommands'])==unlocked
 seq=[v['command'] for v in l['solution']['program']]
 assert len(seq)==l['solution']['actionCount']==l['starTargets']['withoutBonus']['threeStarsMax']
 assert seq==l['solution']['expandedCommands']==l['solution']['expandedOptimalCommands']
 assert set(seq)<=unlocked and not(set(seq)&A)
 sim=Sim(l); assert exec_daily(sim,seq)==(True,len(seq),'win'),l['id']
 broken=[v['command'] for v in b['bugProgram']]
 ref=[v['command'] for v in b['referenceProgram']]
 assert ref==seq and len(ref)==len(broken),b['id']
 assert set(broken)<=unlocked and not(set(broken)&A)
 indices=[i for i,(x,y) in enumerate(zip(broken,ref)) if x!=y]
 assert indices==[b['intendedBugLineForQA']],b['id']
 won,_,_=exec_daily(sim,broken)
 assert not won,b['id']
 replacements=[]
 for cmd in unlocked:
  patched=broken[:];patched[indices[0]]=cmd
  if exec_daily(sim,patched)[0]:replacements.append(cmd)
 assert replacements==[ref[indices[0]]],(b['id'],replacements)
 checks+=1

campwin=boltwin=0
for l in camp:
 cmds=[x['command'] for x in l['solution']['program']]
 assert set(cmds)<=set(l['unlockedCommands']) and not(set(cmds)&A)
 assert cmds==l['solution']['expandedOptimalCommands']==l['solution']['expandedCommands']
 r=replay(l,l['solution']['program'])
 assert r['victory'] and r['actions']==l['starTargets']['withoutBonus']['threeStarsMax'] and not r['bolt'],l['id']
 campwin+=1
 if l['rewards']['collectibles']:
  bonus_program=get_bonus(l) or l.get('v14',{}).get('bonusReferenceProgram')
  assert bonus_program is not None,l['id']
  br=replay(l,bonus_program)
  assert br['victory'] and br['bolt'] and br['actions']==l['starTargets']['withBonus']['threeStarsMax'],l['id']
  boltwin+=1
assert boltwin==45
print(f'OK: {checks}/100 défis gagnants et {checks}/100 bugs réparables en 1 primitive avec correction unique sur la ligne QA.')
print(f'OK: {campwin}/150 niveaux Aventure V14.1 et {boltwin}/45 parcours avec écrou rejoués.')
print('OK: SI et REPETE absents de tous les programmes quotidiens et de campagne. Portails simulés dans les niveaux concernés.')
print('LIMITATION: Replay en simulateurs Python. Compiler et tester avec le moteur Swift UIKit dans Cursor.')

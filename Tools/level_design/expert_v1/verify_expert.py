#!/usr/bin/env python3
"""Offline integrity and behavioral verification for Robot Idiot Expert fixed simulations.
Run from any directory. Requires only Python standard library.
THIS DOES NOT COMPILE OR RUN THE SWIFT iOS APP.
"""
from pathlib import Path
import json,hashlib,collections
from expert_engine import replay,count_nodes,PRIMITIVES,CONDITIONS
from primitive_bfs import optimal_primitive
TOOL_DIR=Path(__file__).resolve().parent
REPO=TOOL_DIR.parents[2]
CANDIDATES=[
 TOOL_DIR,
 REPO/'Packages'/'RobotIdiotCore'/'Sources'/'RobotIdiotCore'/'Resources',
 REPO/'RobotIdiot'/'Resources',
 Path('/Users/michaelblin/Desktop/Robot_Idiot_Mode_Expert_V1'),
]
def resolve(name):
 for base in CANDIDATES:
  path=base/name
  if path.is_file():
   return path
 raise FileNotFoundError(name)
D=json.loads(resolve('robot_idiot_expert_simulations_40.json').read_text())
UI=json.loads(resolve('robot_idiot_expert_config.json').read_text())
TUT=json.loads(resolve('robot_idiot_expert_tutorial_fr.json').read_text())
assert D['schemaVersion']=='expert-lab/1.0'
assert len(D['simulations'])==40
assert len(TUT['pages'])==5
assert UI['stars']['metric']=='writtenBlocks'
assert UI['persistence']['neverOverwriteAdventureKeys']
assert UI['persistence']['neverOverwriteDailyKeys']
assert len({tuple(x['grid']) for x in D['simulations']})==40
metrics=collections.Counter()
for i,L in enumerate(D['simulations'],1):
 title=L['id']
 assert title==f'EX-{i:03d}'
 assert L['sequence']==i and L['mode']=='expert' and not L['showLevelNumber']
 assert len(L['grid'])==L['height'] and all(len(r)==L['width'] for r in L['grid'])
 assert 7<=L['width']<=8 and L['width']==L['height']
 grid=L['grid']
 assert sum(c in '^>v<' for row in grid for c in row)==1
 assert sum(c=='F' for row in grid for c in row)==1
 s=L['start'];f=L['finish'];assert grid[s['y']][s['x']] in '^>v<' and grid[f['y']][f['x']]=='F'
 objs=collections.Counter(m['type'] for m in L['mechanics'])
 expected={'BoardKey':'K','BoardLock':'U','BoardPlate':'A','BoardDoor':'D','BoardCrate':'C','BoardPortal':'Q'}
 links=collections.defaultdict(collections.Counter)
 for m in L['mechanics']:
  assert grid[m['y']][m['x']]==expected[m['type']], (title,m)
  if m['type'] in ('BoardPlate','BoardDoor','BoardPortal'):links[m['linkId']][m['type']]+=1
 assert objs['BoardPortal']<=6
 assert all((v['BoardPortal']==2 and v['BoardPlate']==v['BoardDoor']==0) or (v['BoardPortal']==0 and v['BoardPlate']==v['BoardDoor']==1) for v in links.values()),title
 for typ,ch in expected.items():
  assert sum(row.count(ch) for row in grid)==objs[typ],(title,typ)
 def walk(nodes):
  for n in nodes:
   typ=n['command']
   assert typ in PRIMITIVES|{'SI','REPETE'},(title,typ)
   if typ=='SI':
    assert i>=9 and n['condition'] in CONDITIONS and n['condition'] in L['unlockedConditions']
    assert n['body']
   if typ=='REPETE':assert n['body']
   if typ in PRIMITIVES:assert 'body' not in n and 'condition' not in n
   walk(n.get('body',[]))
 walk(L['reference']['program'])
 if i<=8:assert L['unlockedControlCommands']==['REPETE']
 else:assert L['unlockedControlCommands']==['REPETE','SI']
 assert L['reference']['writtenBlocks']==count_nodes(L['reference']['program'])==L['starTargets']['threeStarsMax']
 assert L['starTargets']['metric']=='writtenBlocks'
 assert L['starTargets']['oneStar']=='anySuccess'
 assert L['starTargets']['twoStarsMax']>L['starTargets']['threeStarsMax']
 r=replay(L,L['reference']['program'])
 assert r['victory'] and not r['error'],(title,r['error'])
 assert r['writtenBlocks']==L['reference']['writtenBlocks']
 assert r['executedActions']==L['reference']['executedActions']
 assert r['expandedCommands']==L['reference']['expandedCommands']
 assert r['loopIterations']==L['reference']['loopIterations']
 assert r['conditions']==L['reference']['conditionObservations']
 assert r['events']==L['reference']['events']
 assert r['portalTraversals']==L['reference']['portalTraversals']
 assert r['loopIterations']>=3
 p=optimal_primitive(L)
 assert p['solved'] and p['proven']
 assert p['actions']==L['reference']['shortestPrimitiveOnlyActions'],title
 assert r['writtenBlocks']<p['actions'],title
 # A single iteration must not be sufficient: loop actually matters.
 assert not replay(L,L['reference']['program'][0]['body'])['victory'], title
 # Every SI branch has a necessary contribution in the provided program.
 nodes=[]
 def getSI(ns):
  for node in ns:
   if node['command']=='SI':nodes.append(node)
   getSI(node.get('body',[]))
 getSI(L['reference']['program'])
 for j in range(len(nodes)):
  import copy
  pr=copy.deepcopy(L['reference']['program']);nn=[]
  def gather(ns):
   for x in ns:
    if x['command']=='SI':nn.append(x)
    gather(x.get('body',[]))
  gather(pr);nn[j]['body']=[]
  assert not replay(L,pr)['victory'],(title,'decorative conditional',j)
 if i>=9:
  for cond,obs in r['conditions'].items():
   assert obs['true']>=1 and obs['false']>=1,(title,'sensor ineffective',cond)
  assert r['conditions']['OBSTACLE_DEVANT']['true']>=2
  metrics['conditionLevels']+=1
 for restricted,typ in [('UTILISE','BoardLock'),('ACTIVE','BoardDoor'),('POUSSE','BoardCrate')]:
  if objs[typ]:
   assert not optimal_primitive(L,disable_commands={restricted})['solved'],(title,'nonessential',typ)
 if objs['BoardPortal']:
  assert sum(r['portalTraversals'].values())>=1
  assert not optimal_primitive(L,disable_portals=True)['solved']
  metrics['portalLevels']+=1
 if objs['BoardCrate']:metrics['crateLevels']+=1
 metrics['wins']+=1;metrics['primitiveBFS']+=1;metrics['usefulLoops']+=1
print('PASS',dict(metrics))
print('Tutorial 5 pages; first-entry and replay policies present; expert scoring separate from adventure.')
print('NOTE: Swift/UIKit engine replay, simulator build, and true global minimum written program remain to be verified in Cursor.')

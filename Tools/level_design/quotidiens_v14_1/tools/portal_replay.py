#!/usr/bin/env python3
"""Robot Idiot V12 fixed portal-enabled levels. Offline deterministic rewrites.
Preserves first 80 levels of V11 unchanged and augments levels 81-150 with
mandatory, bidirectional portals. Solutions are replayed (not optimality-proven).
"""
import json, copy, random, csv, statistics, collections
from pathlib import Path
ROOT=Path(__file__).resolve().parent
OUT=ROOT
BASE=None
ORI='NESW'; vec=((0,-1),(1,0),(0,1),(-1,0)); startchars='^>v<'; blocking=set('BRLTPOW')

def add(p,q):return(p[0]+q[0],p[1]+q[1])
def nei(p,n):
 return [add(p,v) for v in vec if 0<=p[0]+v[0]<n and 0<=p[1]+v[1]<n]
def dist(a,b):return abs(a[0]-b[0])+abs(a[1]-b[1])
def turns(ori,to):
 diff=(to-ori)%4
 return [] if diff==0 else ['TOURNE_DROITE'] if diff==1 else ['TOURNE_GAUCHE'] if diff==3 else ['TOURNE_DROITE']*2

def program_list(commands):return [{'command':k} for k in commands]

def replay(L,program,max_actions=600,trace=False,abort_at_finish=True):
 """Execute nested SI and REPETE against a mutable grid; portaling on entry to Q.
 Tracing tracks all positions visited by any command, old or new.
 """
 n=L['width'];grid=L['grid'];start=L['start'];pos=(start['x'],start['y']);ori=ORI.index(start['orientation'])
 goal=(L['finish']['x'],L['finish']['y']); keys={(m['x'],m['y']) for m in L['mechanics'] if m['type']=='BoardKey'}
 locks={(m['x'],m['y']) for m in L['mechanics'] if m['type']=='BoardLock'}
 crates={(m['x'],m['y']) for m in L['mechanics'] if m['type']=='BoardCrate'}
 plates={(m['x'],m['y']):m['linkId'] for m in L['mechanics'] if m['type']=='BoardPlate'}
 doors={(m['x'],m['y']):m['linkId'] for m in L['mechanics'] if m['type']=='BoardDoor'}
 portal_by_pos={(m['x'],m['y']):m['linkId'] for m in L['mechanics'] if m['type']=='BoardPortal'}
 portal_by_link=collections.defaultdict(list)
 for p,lid in portal_by_pos.items():portal_by_link[lid].append(p)
 active=set();opened=set();inventory=0;actions=0;failure=None;loop=0;true_count=0;false_count=0;portals=collections.Counter();events=collections.Counter();visited=[pos];crateVisited=set(crates);sensorRead=set();collected=False;finish_heading=None;finish_pos=None;finish_reached=False;primitive=[]
 bolts={(b['x'],b['y']) for b in L.get('rewards',{}).get('collectibles',[])}
 if pos in bolts:collected=True
 def blocked(q):
  if not (0<=q[0]<n and 0<=q[1]<n):return True
  return grid[q[1]][q[0]] in blocking or q in crates or (q in locks and q not in opened) or (q in doors and doors[q] not in active)
 def step(c):
  nonlocal pos,ori,actions,failure,inventory,collected,finish_heading,finish_pos,finish_reached
  actions+=1;primitive.append(c)
  if actions>max_actions:failure='action guard';return
  front=add(pos,vec[ori]);enter=False
  if c=='TOURNE_GAUCHE':ori=(ori-1)%4
  elif c=='TOURNE_DROITE':ori=(ori+1)%4
  elif c=='AVANCE':
   if blocked(front):failure='blocked AVANCE at '+str(front);return
   pos=front;enter=True
  elif c=='RECULE':
   back=add(pos,vec[(ori+2)%4]);
   if blocked(back):failure='blocked RECULE at '+str(back);return
   pos=back;enter=True
  elif c=='RAMASSE':
   if pos not in keys:failure='no key';return
   keys.remove(pos);inventory+=1;events['key']+=1
  elif c=='UTILISE':
   if front not in locks or front in opened or inventory<1:failure='lock invalid';return
   opened.add(front);inventory-=1;events['lock']+=1
  elif c=='ACTIVE':
   if pos not in plates:failure='not on plate';return
   active.add(plates[pos]);events['plate']+=1
  elif c=='POUSSE':
   if front not in crates:failure='no crate';return
   destination=add(front,vec[ori]);
   if blocked(destination) or destination in portal_by_pos:failure='crate cannot enter destination (portal forbidden)';return
   crates.remove(front);crates.add(destination);crateVisited.add(destination);pos=front;enter=True;events['crate']+=1
  else:failure='unsupported '+c;return
  if enter:
   if pos in portal_by_pos:
    lid=portal_by_pos[pos];pair=portal_by_link[lid]
    if len(pair)!=2:failure='bad portal '+lid;return
    pos=pair[0] if pair[1]==pos else pair[1]
    portals[lid]+=1
   visited.append(pos)
  if pos in bolts:collected=True
  if pos==goal and not finish_reached:
   finish_heading=ori;finish_pos=pos;finish_reached=True
 def run(blocks,depth=0):
  nonlocal failure,loop,true_count,false_count
  if depth>9:failure='nested too deeply';return
  for node in blocks:
   if failure or (abort_at_finish and pos==goal):return
   typ=node['command']
   if typ=='SI':
    if node['condition']!='OBSTACLE_DEVANT':failure='unsupported condition '+str(node.get('condition'));return
    target=add(pos,vec[ori]);sensorRead.add(target);z=blocked(target);true_count+=int(z);false_count+=int(not z)
    if z:run(node.get('body',node.get('children',[])),depth+1)
   elif typ=='REPETE':
    for _ in range(max_actions):
     if failure or (abort_at_finish and pos==goal):return
     loop+=1;run(node.get('body',node.get('children',[])),depth+1)
    if not failure and pos!=goal:failure='loop guard';return
   else:step(typ)
 run(program)
 return {'victory':failure is None and pos==goal,'error':failure,'position':pos,'orientation':ori,'finishOrientation':finish_heading,'actions':actions,'loops':loop,'condTrue':true_count,'condFalse':false_count,'portals':dict(portals),'events':dict(events),'visited':visited,'crateVisited':list(crateVisited),'sensorRead':list(sensorRead),'bolt':collected,'primitive':primitive}

def get_bonus(L):
 if not L['rewards']['collectibles']:return None
 if 'v11' in L and L['v11'].get('bonusReferenceProgram'):
  return L['v11']['bonusReferenceProgram']
 rv=L.get('rewardValidation',{})
 if rv.get('optimalWithBonusProgram'):
  return program_list(rv['optimalWithBonusProgram'])
 return None


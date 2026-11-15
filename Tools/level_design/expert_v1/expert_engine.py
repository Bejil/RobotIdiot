"""Robot Idiot Expert reference interpreter. Python *model*, not the UIKit engine.
JSON contracts are documented separately. No external packages.
"""
from collections import Counter,defaultdict
ORI='NESW'
VEC=((0,-1),(1,0),(0,1),(-1,0))
START='^>v<'
BLOCK=set('BRLTPOW')
PRIMITIVES={'AVANCE','RECULE','TOURNE_GAUCHE','TOURNE_DROITE','RAMASSE','UTILISE','POUSSE','ACTIVE'}
CONDITIONS={'OBSTACLE_DEVANT','CLE_ICI','CADENAS_DEVANT','SUR_BOUTON','CAISSE_DEVANT'}

def node(c,body=None,condition=None):
 d={'command':c}
 if condition is not None:d['condition']=condition
 if body is not None:d['body']=body
 return d

def count_nodes(program):
 return sum(1+count_nodes(n.get('body',[])) for n in program)

def unpack_flat(xs):return [node(x) for x in xs]

class State:
 def __init__(self,L):
  self.L=L;self.w=L['width'];self.h=L['height'];self.grid=L['grid']
  self.p=(L['start']['x'],L['start']['y']);self.o=ORI.index(L['start']['orientation']);self.finish=(L['finish']['x'],L['finish']['y']);
  ms=L.get('mechanics',[])
  self.keys={(m['x'],m['y']) for m in ms if m['type']=='BoardKey'}
  self.locks={(m['x'],m['y']) for m in ms if m['type']=='BoardLock'}
  self.crates={(m['x'],m['y']) for m in ms if m['type']=='BoardCrate'}
  self.plates={(m['x'],m['y']):m['linkId'] for m in ms if m['type']=='BoardPlate'}
  self.doors={(m['x'],m['y']):m['linkId'] for m in ms if m['type']=='BoardDoor'}
  self.portalpos={(m['x'],m['y']):m['linkId'] for m in ms if m['type']=='BoardPortal'}
  self.portalpairs=defaultdict(list)
  for p,lid in self.portalpos.items():self.portalpairs[lid].append(p)
  self.opened=set();self.active=set();self.inventory=0;self.actionCount=0;self.trace=[];self.visited=[self.p];self.loops=0
  self.sensors=defaultdict(lambda:Counter());self.sensorLocations=defaultdict(set);self.events=Counter();self.portals=Counter();self.error=None;self.done=(self.p==self.finish)
  self.picks=[]
 def fwd(self):return(self.p[0]+VEC[self.o][0],self.p[1]+VEC[self.o][1])
 def add(self,p,v):return(p[0]+v[0],p[1]+v[1])
 def blocked(self,p):
  x,y=p
  return not(0<=x<self.w and 0<=y<self.h) or self.grid[y][x] in BLOCK or p in self.crates or (p in self.locks and p not in self.opened) or (p in self.doors and self.doors[p] not in self.active)
 def sensor(self,name):
  f=self.fwd()
  v={'OBSTACLE_DEVANT': lambda:self.blocked(f),'CLE_ICI':lambda:self.p in self.keys,'CADENAS_DEVANT':lambda:f in self.locks and f not in self.opened,'SUR_BOUTON':lambda:self.p in self.plates and self.plates[self.p] not in self.active,'CAISSE_DEVANT':lambda:f in self.crates}[name]()
  self.sensors[name]['true' if v else 'false']+=1;self.sensorLocations[name].add((self.p,self.o));return v
 def step(self,c):
  if self.done or self.error:return
  self.actionCount+=1
  if self.actionCount>400:self.error='ACTION_GUARD';return
  f=self.fwd();entered=False
  if c=='TOURNE_GAUCHE':self.o=(self.o-1)%4
  elif c=='TOURNE_DROITE':self.o=(self.o+1)%4
  elif c=='AVANCE':
   if self.blocked(f):self.error='BLOCKED_AVANCE '+str(f);return
   self.p=f;entered=True
  elif c=='RECULE':
   to=self.add(self.p,VEC[(self.o+2)%4])
   if self.blocked(to):self.error='BLOCKED_RECULE '+str(to);return
   self.p=to;entered=True
  elif c=='RAMASSE':
   if self.p not in self.keys:self.error='NO_KEY';return
   self.keys.remove(self.p);self.inventory+=1;self.events['key']+=1
  elif c=='UTILISE':
   if f not in self.locks or f in self.opened or self.inventory<1:self.error='NO_USABLE_LOCK';return
   self.opened.add(f);self.inventory-=1;self.events['lock']+=1
  elif c=='ACTIVE':
   if self.p not in self.plates or self.plates[self.p] in self.active:self.error='PLATE_INVALID_OR_ALREADY_ACTIVE';return
   self.active.add(self.plates[self.p]);self.events['plate']+=1
  elif c=='POUSSE':
   if f not in self.crates:self.error='NO_CRATE';return
   to=self.add(f,VEC[self.o]);
   if self.blocked(to) or to in self.portalpos:self.error='CRATE_BLOCKED';return
   self.crates.remove(f);self.crates.add(to);self.p=f;entered=True;self.events['crate']+=1
  else:self.error='UNKNOWN_COMMAND_'+str(c);return
  if entered:
   if self.p in self.portalpos:
    lid=self.portalpos[self.p];pair=self.portalpairs[lid]
    if len(pair)!=2:self.error='BAD_PORTAL_PAIR';return
    self.p=pair[1] if pair[0]==self.p else pair[0]
    self.portals[lid]+=1
   self.visited.append(self.p)
  self.trace.append(c)
  self.done=(self.p==self.finish)
 def result(self,program):
  return {'victory':bool(self.done and not self.error),'error':self.error,'writtenBlocks':count_nodes(program),'executedActions':self.actionCount,'expandedCommands':self.trace,'loopIterations':self.loops,'conditions':dict(self.sensors),'distinctSensorStates':{c:len(s) for c,s in self.sensorLocations.items()},'events':dict(self.events),'portalTraversals':dict(self.portals),'visited':self.visited}

def replay(L,program,max_evals=8000):
 S=State(L);evals=[0]
 def run(blocks,depth=0):
  if depth>10:S.error='TOO_DEEP';return
  for n in blocks:
   if S.done or S.error:return
   evals[0]+=1
   if evals[0]>max_evals:S.error='EVALUATION_GUARD';return
   typ=n['command']
   if typ=='SI':
    if n.get('condition') not in CONDITIONS:S.error='UNKNOWN_CONDITION';return
    if S.sensor(n['condition']):run(n.get('body',[]),depth+1)
   elif typ=='REPETE':
    if not n.get('body'):S.error='EMPTY_REPEAT';return
    while not S.done and not S.error:
     S.loops+=1
     run(n['body'],depth+1)
   else:S.step(typ)
 run(program)
 return S.result(program)

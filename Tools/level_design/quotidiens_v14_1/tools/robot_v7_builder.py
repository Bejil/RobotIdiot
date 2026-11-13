import json,collections,itertools,random,heapq,time,math,copy,os,zipfile
from dataclasses import dataclass
SRC=os.path.join(os.path.dirname(os.path.abspath(__file__)),'robot_idiot_100_levels_v6.json')
D=json.load(open(SRC,encoding='utf-8'))
DIR=((0,-1),(1,0),(0,1),(-1,0))
OR={'N':0,'E':1,'S':2,'W':3}
M={'^':0,'>':1,'v':2,'<':3}
BLOCK=set('BRLTPOW')

class Sim:
 def __init__(self,lev):
  self.l=lev; self.grid=lev['grid']; self.w=lev['width']; self.h=lev['height']
  self.start=(lev['start']['x'],lev['start']['y'],OR[lev['start']['orientation']]); self.finish=(lev['finish']['x'],lev['finish']['y'])
  self.keys=sorted([(m['x'],m['y']) for m in lev['mechanics'] if m['type']=='BoardKey'])
  self.locks=sorted([(m['x'],m['y']) for m in lev['mechanics'] if m['type']=='BoardLock'])
  self.crates=sorted([(m['x'],m['y']) for m in lev['mechanics'] if m['type']=='BoardCrate'])
  self.plates=sorted([(m['x'],m['y'],m['linkId']) for m in lev['mechanics'] if m['type']=='BoardPlate'])
  self.doors=sorted([(m['x'],m['y'],m['linkId']) for m in lev['mechanics'] if m['type']=='BoardDoor'])
  self.keyindex={p:i for i,p in enumerate(self.keys)}
  self.lockindex={p:i for i,p in enumerate(self.locks)}
  self.plateindex={p[:2]:i for i,p in enumerate(self.plates)}
  self.doorsbycoord={p[:2]:p[2] for p in self.doors}
  self.pbylink={p[2]:i for i,p in enumerate(self.plates)}
  self.goalkey=bool(lev['objective'].get('requiresItemHeld'))
  self.actions=[k for k in ['AVANCE','RECULE','TOURNE_GAUCHE','TOURNE_DROITE','RAMASSE','UTILISE','POUSSE','ACTIVE'] if k in lev['unlockedCommands']]
 def initial(self):
  return (self.start[0],self.start[1],self.start[2],0,0,0,tuple(self.crates))
 def inv(self,s):return bin(s[3]).count('1')-bin(s[4]).count('1')
 def block(self,s,p):
  x,y=p
  if not 0<=x<self.w or not 0<=y<self.h:return True
  c=self.grid[y][x]
  if c in BLOCK:return True
  if p in s[6]:return True
  li=self.lockindex.get(p)
  if li is not None and not (s[4]>>li)&1:return True
  link=self.doorsbycoord.get(p)
  if link is not None and not (s[5]>>self.pbylink[link])&1:return True
  return False
 def step(self,s,cmd):
  x,y,d,keys,locks,plates,crates=s
  dx,dy=DIR[d];ahead=(x+dx,y+dy)
  if cmd=='TOURNE_GAUCHE':return (x,y,(d-1)%4,keys,locks,plates,crates)
  if cmd=='TOURNE_DROITE':return (x,y,(d+1)%4,keys,locks,plates,crates)
  if cmd in ('AVANCE','RECULE'):
   to=(x+dx,y+dy) if cmd=='AVANCE' else (x-dx,y-dy)
   if self.block(s,to):return None
   return (to[0],to[1],d,keys,locks,plates,crates)
  if cmd=='RAMASSE':
   idx=self.keyindex.get((x,y))
   if idx is None or (keys>>idx)&1:return None
   return (x,y,d,keys|(1<<idx),locks,plates,crates)
  if cmd=='UTILISE':
   idx=self.lockindex.get(ahead)
   if idx is None or ((locks>>idx)&1) or self.inv(s)<=0:return None
   return (x,y,d,keys,locks|(1<<idx),plates,crates)
  if cmd=='ACTIVE':
   idx=self.plateindex.get((x,y))
   if idx is None or (plates>>idx)&1:return None
   return (x,y,d,keys,locks,plates|(1<<idx),crates)
  if cmd=='POUSSE':
   if ahead not in crates:return None
   to=(ahead[0]+dx,ahead[1]+dy)
   if self.block(s,to):return None
   newcrates=tuple(sorted((set(crates)-{ahead})|{to}))
   return (ahead[0],ahead[1],d,keys,locks,plates,newcrates)
  raise ValueError(cmd)
 def win(self,s):return (s[0],s[1])==self.finish and (not self.goalkey or self.inv(s)>0)
 def run(self,cmds,bonus=None,record=True):
  s=self.initial(); states=[s]; got=False
  for j,cmd in enumerate(cmds):
   s=self.step(s,cmd)
   if s is None:return False,states,got,'invalid_command '+str((j,cmd))
   states.append(s)
   if bonus and (s[0],s[1])==bonus:got=True
   if self.win(s):return (j==len(cmds)-1),states,got,('win' if j==len(cmds)-1 else 'early_win')
  return False,states,got,'not_won'
 def relevant(self,s): return (s[0],s[1])

if __name__=='__main__':
 ok=0
 for l in D['levels']:
  sim=Sim(l); sol=l['solution']['expandedCommands'];res,st,got,why=sim.run(sol)
  if not res: print('FAILED',l['id'],why,sim.win(st[-1]),'final',st[-1][:3]);
  else:ok+=1
 print('solutions',ok,'/100')

def astar(sim,bonus,require_bonus,upperbound,witness,max_states=240000,max_seconds=2.5):
 """Exact minimum number of primitive actions if search completes; upperbound is a valid witness length."""
 start=sim.initial()
 if require_bonus:
  def he(s):
   if s[7]:return abs(s[0]-sim.finish[0])+abs(s[1]-sim.finish[1])
   return abs(s[0]-bonus[0])+abs(s[1]-bonus[1])+abs(bonus[0]-sim.finish[0])+abs(bonus[1]-sim.finish[1])
 else:
  def he(s):return abs(s[0]-sim.finish[0])+abs(s[1]-sim.finish[1])
 s0=start+(0,);h0=he(s0)
 dist={s0:0};parents={};q=[(h0,0,s0)];serial=0; count=0;initial_time=time.monotonic()
 while q:
  if len(dist)>max_states or time.monotonic()-initial_time>max_seconds:
   return upperbound,witness,False,len(dist),'budget'
  f,neg_g,s=heapq.heappop(q);g=-neg_g
  if g!=dist[s] or f>=upperbound:continue
  count+=1
  for act in sim.actions:
   ns=sim.step(s[:7],act)
   if ns is None:continue
   if not require_bonus and (ns[0],ns[1])==bonus:continue
   got=s[7] or int((ns[0],ns[1])==bonus)
   ns=ns+(got,)
   ng=g+1
   if ng>=upperbound: continue
   if sim.win(ns[:7]) and require_bonus and not got:
    continue  # game ends on flag; cannot go back for collectible afterwards
   if sim.win(ns[:7]) and (not require_bonus or got):
    seq=[act];cur=s
    while cur in parents:
     old,act0=parents[cur];seq.append(act0);cur=old
    seq.reverse()
    assert len(seq)==ng
    upperbound=ng;witness=seq
    continue
   hn=he(ns)
   if ng+hn>=upperbound:continue
   if ng>=dist.get(ns,10**8):continue
   dist[ns]=ng;parents[ns]=(s,act)
   heapq.heappush(q,(ng+hn,-ng,ns))
 return upperbound,witness,True,len(dist),'proven'

def find_spurs(sim,states):
 visited={(s[0],s[1]) for s in states};cand=[]
 for t,s in enumerate(states[:-1]):
  for rel,d in [('L',(s[2]-1)%4),('R',(s[2]+1)%4)]:
   p=(s[0]+DIR[d][0],s[1]+DIR[d][1]);x,y=p
   if not (0<=x<sim.w and 0<=y<sim.h):continue
   if sim.grid[y][x]!='g' or p in visited or sim.block(s,p):continue
   turn='TOURNE_GAUCHE' if rel=='L' else 'TOURNE_DROITE'
   revert='TOURNE_DROITE' if rel=='L' else 'TOURNE_GAUCHE'
   if 'RECULE' in sim.actions:delta=[turn,'AVANCE','RECULE',revert]
   else:delta=[turn,'AVANCE',turn,turn,'AVANCE',turn]
   if not (sim.step(s,turn) and sim.step(sim.step(s,turn),'AVANCE')):continue
   witness=sim.l['solution']['expandedCommands'][:t]+delta+sim.l['solution']['expandedCommands'][t:]
   ok,tr,got,why=sim.run(witness,p)
   if not(ok and got):continue
   degree=sum(0<=x+dx<sim.w and 0<=y+dy<sim.h and sim.grid[y+dy][x+dx] not in BLOCK and sim.grid[y+dy][x+dx] not in 'UDC' for dx,dy in DIR)
   cand.append({'t':t,'coord':p,'degree':degree,'witness':witness,'delta':delta})
 return cand

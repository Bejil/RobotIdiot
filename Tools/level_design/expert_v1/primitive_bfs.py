"""Exact shortest action-sequence solver for a fixed Expert level (no REPETE/SI).
State includes keys, locks, plates/doors, movable crates, portals.
This does NOT prove the shortest written program with control structures.
"""
from collections import deque,defaultdict
from expert_engine import VEC,ORI,BLOCK
ACTIONS=('AVANCE','RECULE','TOURNE_GAUCHE','TOURNE_DROITE','RAMASSE','UTILISE','POUSSE','ACTIVE')
def optimal_primitive(L,cap=400000,disable_commands=None,disable_portals=False):
 w=L['width'];h=L['height'];g=L['grid']
 start=(L['start']['x'],L['start']['y']);o=ORI.index(L['start']['orientation']);finish=(L['finish']['x'],L['finish']['y'])
 ms=L['mechanics'];keys=[(m['x'],m['y']) for m in ms if m['type']=='BoardKey'];locks=[(m['x'],m['y']) for m in ms if m['type']=='BoardLock'];crates=tuple(sorted((m['x'],m['y']) for m in ms if m['type']=='BoardCrate'))
 plates={(m['x'],m['y']):m['linkId'] for m in ms if m['type']=='BoardPlate'};doors={(m['x'],m['y']):m['linkId'] for m in ms if m['type']=='BoardDoor'}
 links={l:i for i,l in enumerate(sorted(set(plates.values())|set(doors.values())))}
 portals=defaultdict(list)
 for m in ms:
  if m['type']=='BoardPortal':portals[m['linkId']].append((m['x'],m['y']))
 portalmap={} if disable_portals else {a:b for ps in portals.values() if len(ps)==2 for a,b in (ps,ps[::-1])}
 kdict={p:i for i,p in enumerate(keys)};ldict={p:i for i,p in enumerate(locks)}
 def inside(p):return 0<=p[0]<w and 0<=p[1]<h
 def inc(p,v):return(p[0]+v[0],p[1]+v[1])
 def blocked(p,ls,active,cr):
  return not inside(p) or g[p[1]][p[0]] in BLOCK or p in cr or (p in ldict and not (ls&(1<<ldict[p]))) or (p in doors and not(active&(1<<links[doors[p]])))
 init=(start,o,0,0,0,0,crates) # pos,ori,inv,removedKeysBits,openLocksBits,activeDoorsBits,crates
 q=deque([init]);parents={init:(None,None)}
 while q:
  s=q.popleft();p,d,inv,kb,lb,ab,cr=s
  if p==finish:
   ans=[]
   while parents[s][0] is not None:
    parent,act=parents[s];ans.append(act);s=parent
   return {'solved':True,'actions':len(ans),'program':ans[::-1],'visitedStates':len(parents),'proven':True}
  if len(parents)>cap:return {'solved':False,'reason':'STATE_CAP','visitedStates':len(parents)}
  for cmd in ACTIONS:
   if disable_commands and cmd in disable_commands:continue
   pp=p;dd=d;iv=inv;kk=kb;ll=lb;aa=ab;cc=cr
   front=inc(p,VEC[d]);step=False
   if cmd=='TOURNE_GAUCHE':dd=(d-1)%4
   elif cmd=='TOURNE_DROITE':dd=(d+1)%4
   elif cmd=='AVANCE':
    if blocked(front,ll,aa,cc):continue
    pp=front;step=True
   elif cmd=='RECULE':
    back=inc(p,VEC[(d+2)%4]);
    if blocked(back,ll,aa,cc):continue
    pp=back;step=True
   elif cmd=='RAMASSE':
    if p not in kdict or (kk&(1<<kdict[p])):continue
    kk|=(1<<kdict[p]);iv+=1
   elif cmd=='UTILISE':
    if front not in ldict or ll&(1<<ldict[front]) or iv<1:continue
    ll|=(1<<ldict[front]);iv-=1
   elif cmd=='ACTIVE':
    if p not in plates or aa&(1<<links[plates[p]]):continue
    aa|=(1<<links[plates[p]])
   elif cmd=='POUSSE':
    if front not in cc:continue
    to=inc(front,VEC[d]);
    if blocked(to,ll,aa,cc) or to in portalmap:continue
    cc=tuple(sorted((set(cc)-{front})|{to}));pp=front;step=True
   if step and pp in portalmap:pp=portalmap[pp]
   ns=(pp,dd,iv,kk,ll,aa,cc)
   if ns not in parents:
    parents[ns]=(s,cmd);q.append(ns)
 return {'solved':False,'reason':'NO_PATH','visitedStates':len(parents)}

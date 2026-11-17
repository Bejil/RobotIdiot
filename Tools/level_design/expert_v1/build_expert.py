#!/usr/bin/env python3
"""Author and validate a fixed Expert Laboratory pack for Robot Idiot.
No runtime procedural generation. Each candidate is deterministically authored here and exported.
"""
import json, random, hashlib, csv, copy, math
from pathlib import Path
from collections import deque,Counter,defaultdict
from expert_engine import replay,node,count_nodes,ORI,VEC,START,BLOCK
OUT=Path(__file__).resolve().parent.parent
R=random.Random(420111)
F='AVANCE';L='TOURNE_GAUCHE';T='TOURNE_DROITE';B='RECULE'
BLOCK_CHARS=['B','O','R','W','P','T']

def posadd(p,v):return(p[0]+v[0],p[1]+v[1])
def within(p,n):return 0<=p[0]<n and 0<=p[1]<n

def naive_path(start,o,motif,cycles,n):
 p=start;seen={p};trace=[p];heading=o
 for _ in range(cycles):
  for cmd in motif:
   if cmd==T:heading=(heading+1)%4
   elif cmd==L:heading=(heading-1)%4
   else:
    delta=VEC[heading if cmd==F else (heading+2)%4];q=posadd(p,delta)
    if not within(q,n) or q in seen:return None
    p=q;seen.add(q);trace.append(q)
 return p,heading,trace


def grid_from_walked(n,road,start,finish,blocked=None,rng=None,extra_free=0.06):
 rng=rng or R;blocked=set(blocked or set())
 A=[['g' for _ in range(n)] for _ in range(n)]
 for y in range(n):
  for x in range(n):
   p=(x,y)
   if p in blocked or (p not in road and rng.random()>extra_free):A[y][x]=rng.choice(BLOCK_CHARS)
 x,y=start[0];A[y][x]=START[start[1]]
 fx,fy=finish;A[fy][fx]='F'
 return [''.join(row) for row in A]


def level(name,n,grid,start,o,finish,program,mechanics=None,theme=1,intro=None,skill='REPETE',mode='loop',explain=None):
 mechanics=mechanics or []
 return {'id':'', 'name':name, 'mode':'expert', 'width':n,'height':n,'grid':grid,'start':{'x':start[0],'y':start[1],'orientation':ORI[o]},'finish':{'x':finish[0],'y':finish[1]},'objective':{'type':'reach_flag','requiresItemHeld':False},'mechanics':mechanics,'visualThemeWorld':theme,'reference':{'program':program,'writtenBlocks':count_nodes(program),'scoringMetric':'writtenBlocks','optimality':'VERIFIED_REFERENCE_NOT_PROVEN_MINIMUM'},'skill':skill,'designPattern':mode,'teachingHint':explain or '', 'firstUseTutorialStep':intro}

def make_repeats(index,motif,cycles,n=7,theme=1):
 for attempt in range(2000):
  o=R.randrange(4);st=(R.randrange(n),R.randrange(n));result=naive_path(st,o,motif,cycles,n)
  if not result:continue
  end,heading,path=result
  if len(path)<9:continue
  g=grid_from_walked(n,set(path), (st,o),end, rng=R, extra_free=R.uniform(0.0,.13))
  prog=[node('REPETE', [node(c) for c in motif])]
  lvl=level('Lancement de boucle',n,g,st,o,end,prog,theme=theme,skill='REPETE',mode='periodic-motif')
  rr=replay(lvl,prog)
  if rr['victory'] and rr['loopIterations']>=cycles:return lvl,rr
 raise ValueError(('could not create repeat',index,motif,cycles,n))

def path_follow(n,steps,side,seed, min_turns=3, max_turns=15):
 """Create self-avoiding path where each turn is forced by wall directly ahead.
 Sensor program repeat(if obstacle ahead turn side; advance)."""
 rr=random.Random(seed)
 for attempt in range(850):
  st=(rr.randrange(n),rr.randrange(n));o=rr.randrange(4);visited={st};forbidden=set();path=[st];turnpoints=[];heading=o
  # stochastic DFS; backtracking at every step
  def dfs(p,ori,route,seen,banned,turns,turnposes,tries=0):
   if len(route)==steps+1:
    return (p,ori,route,seen,banned,turns,turnposes) if turns>=min_turns and turns<=max_turns else None
   front=posadd(p,VEC[ori]);turn= (ori+1)%4 if side=='R' else (ori-1)%4
   to_turn=posadd(p,VEC[turn]);choices=['go','turn'];rr.shuffle(choices)
   for choice in choices:
    if choice=='go':
     if not within(front,n) or front in seen or front in banned:continue
     res=dfs(front,ori,route+[front],seen|{front},banned,turns,turnposes)
    else:
     if not within(to_turn,n) or to_turn in seen or to_turn in banned:continue
     if within(front,n) and front in seen:continue
     b2=banned|({front} if within(front,n) else set())
     res=dfs(to_turn,turn,route+[to_turn],seen|{to_turn},b2,turns+1,turnposes+[p])
    if res:return res
   return None
  got=dfs(st,o,path,visited,forbidden,0,[])
  if got:return st,o,got
 raise ValueError(('no forced path',n,steps,side,min_turns))

def build_follow(index,n,steps,side,theme=4,lesson='SI',extra=None):
 for attempt in range(50):
  st,o,(end,_,path,seen,banned,turns,turnposes)=path_follow(n,steps,side,seed=index*9737+attempt*883+199,min_turns=max(2,int(steps/7)))
  g=grid_from_walked(n,set(path),(st,o),end,banned,rng=R,extra_free=R.uniform(0.0,.20))
  turncmd=T if side=='R' else L
  inside=[node('SI',[node(turncmd)],'OBSTACLE_DEVANT'),node(F)]
  prog=[node('REPETE',inside)]
  lvl=level('Réflexe automatique',n,g,st,o,end,prog,theme=theme,skill=lesson,mode='reactive-turn')
  rr=replay(lvl,prog)
  cond=rr['conditions'].get('OBSTACLE_DEVANT',{})
  if rr['victory'] and rr['loopIterations']>=12 and cond.get('true',0)>=2 and cond.get('false',0)>=3:
   return lvl,rr,path,turnposes,banned
 raise ValueError(('no valid follower',index,n,steps,side))


def augment_interaction(index,n,steps,side,kind,theme):
 for attempt in range(80):
  lvl,_,path,turnpoints,banned=build_follow(index+attempt*100,n,steps,side,theme,lesson='SENSORS')
  grid=[list(s) for s in lvl['grid']]
  mechanics=[]
  # guarantee no revisit to earlier interactive tiles (self-avoiding route).
  # sensor at beginning iteration before action -> put key/plate in visited path
  if kind in ('key-lock','key-plate-lock','double-keys','plate-door','double-plates'):
   needed=[]
   if kind=='key-lock':needed=['key','lock']
   elif kind=='key-plate-lock':needed=['key','plate','lock','door']
   elif kind=='double-keys':needed=['key','lock','key','lock']
   elif kind=='plate-door':needed=['plate','door']
   elif kind=='double-plates':needed=['plate','door','plate','door']
   elif kind=='double-mix':needed=['key','plate','lock','door','key','lock']
   # Place sensors on a path step; locks/doors on a straight step (not at turn),
   # including gap between turnpoints and avoid conflict.
   lastj=0
   for tp,k in enumerate(needed):
    lo=max(lastj+2,int((tp+1)*len(path)/(len(needed)+1))-2);hi=min(len(path)-2,int((tp+1)*len(path)/(len(needed)+1))+4)
    possibilities=[]
    for i in range(max(2,lo),max(3,hi)):
     if any(m['x']==path[i][0] and m['y']==path[i][1] for m in mechanics):continue
     if (k in ('lock','door')):
      if i>=len(path)-1:continue
      # The step into path[i] must have no turn, and can be approached as forward.
      # Check preceding straight (on the natural path).
      if i<2 or path[i][0]-path[i-1][0]!=path[i-1][0]-path[i-2][0] or path[i][1]-path[i-1][1]!=path[i-1][1]-path[i-2][1]:continue
      # clear blocker in forward cell; no need extra since link condition opens first
     possibilities.append(i)
    if not possibilities:break
    j=R.choice(possibilities);lastj=j;p=path[j]
    if k=='key':
     grid[p[1]][p[0]]='K';mechanics.append({'type':'BoardKey','x':p[0],'y':p[1]})
    elif k=='plate':
     grid[p[1]][p[0]]='A';mechanics.append({'type':'BoardPlate','x':p[0],'y':p[1],'linkId':'EXPERT-'+str(index)+'-'+str(len([m for m in mechanics if m['type']=='BoardPlate'])+1)})
    elif k=='lock':
     grid[p[1]][p[0]]='U';mechanics.append({'type':'BoardLock','x':p[0],'y':p[1]})
    elif k=='door':
     grid[p[1]][p[0]]='D'
     lid=[m['linkId'] for m in mechanics if m['type']=='BoardPlate' and not any(d['type']=='BoardDoor' and d['linkId']==m['linkId'] for d in mechanics)][0]
     mechanics.append({'type':'BoardDoor','x':p[0],'y':p[1],'linkId':lid})
   else:
    grid[lvl['start']['y']][lvl['start']['x']]=START[ORI.index(lvl['start']['orientation'])]
    grid[lvl['finish']['y']][lvl['finish']['x']]='F'
    lvl['grid']=[''.join(row) for row in grid]
    lvl['mechanics']=mechanics
    inside=[]
    if kind in ('key-lock','key-plate-lock','double-keys','double-mix'):
     inside.append(node('SI',[node('RAMASSE')],'CLE_ICI'))
    if kind in ('plate-door','double-plates','key-plate-lock','double-mix'):
     inside.append(node('SI',[node('ACTIVE')],'SUR_BOUTON'))
    if kind in ('key-lock','key-plate-lock','double-keys','double-mix'):
     inside.append(node('SI',[node('UTILISE')],'CADENAS_DEVANT'))
    inside += [node('SI',[node(T if side=='R' else L)],'OBSTACLE_DEVANT'),node(F)]
    prog=[node('REPETE',inside)]
    lvl['reference']['program']=prog;lvl['reference']['writtenBlocks']=count_nodes(prog)
    lvl['designPattern']=kind;lvl['skill']='INTERACTIONS'
    r=replay(lvl,prog)
    expected={'key-lock':['key','lock'],'key-plate-lock':['key','lock','plate'],'double-keys':['key','lock'],'plate-door':['plate'],'double-plates':['plate'],'double-mix':['key','lock','plate']}
    if r['victory'] and all(r['events'].get(e,0)>=1 for e in expected[kind]) and r['loopIterations']>=10:
     return lvl,r,path
 raise ValueError(('could not augment',index,kind,n,steps))

def build_portal(index,n,steps,side,theme=9,add_interaction='key-lock'):
 """Two physically separated walking regions connected by one mandatory portal pair.
 Preserve the robot's heading and move suffix after teleport by a translation.
 """
 for attempt in range(750):
  try:
   st,o,(end,heading,path,seen,banned,turns,turnposes)=path_follow(n,steps,side,seed=191717+index*2001+attempt*7,min_turns=max(2,steps//6))
  except ValueError:continue
  # gate teleport at an ordinary moved-to tile, not at the start/finish
  ks=list(range(max(3,steps//3),min(steps-3,steps*2//3+1)))
  R.shuffle(ks)
  for k in ks:
   pref=set(path[:k+1]);suf=path[k:]
   vectors=[(dx,dy) for dx in range(-n+1,n) for dy in range(-n+1,n) if dx or dy]
   R.shuffle(vectors)
   for dx,dy in vectors:
    target=[(p[0]+dx,p[1]+dy) for p in suf]
    if not all(within(p,n) for p in target):continue
    exitp=target[0]
    # don't allow any contact between prefix and teleported region
    if any(abs(a[0]-b[0])+abs(a[1]-b[1])<2 for a in pref for b in target):continue
    # shift forced blockers from after entrance; keep the ones from before
    tpos=set(turnposes)
    preban=set();postban=set()
    for i,p in enumerate(path[:-1]):
     if p not in tpos:continue
     # turn at this position => next step did not go forward, determine front from path's headings
     # simply classify ban cells by closeness to route segment, and shift if ban adjacent to turnpoint
    # Keep prefix/suffix road disconnected, all other squares walls, so existing ban positions redundant
    combined=list(path[:k+1])+target[1:]
    road=set(combined)|{exitp}
    A=[['O' for x in range(n)] for y in range(n)]
    for x,y in road:A[y][x]='g'
    srcp=path[k];A[srcp[1]][srcp[0]]='Q';A[exitp[1]][exitp[0]]='Q'
    A[st[1]][st[0]]=START[o]
    dest=target[-1];A[dest[1]][dest[0]]='F'
    g=[''.join(row) for row in A]
    p_id='expert-portal-'+str(index)
    mechanics=[{'type':'BoardPortal','x':srcp[0],'y':srcp[1],'linkId':p_id,'visualVariant':'A'}, {'type':'BoardPortal','x':exitp[0],'y':exitp[1],'linkId':p_id,'visualVariant':'A'}]
    base_inside=[node('SI',[node(T if side=='R' else L)],'OBSTACLE_DEVANT'),node(F)]
    base_prog=[node('REPETE',base_inside)]
    lvl=level('Passage dimensionnel',n,g,st,o,dest,base_prog,mechanics,theme=theme,skill='PORTALS',mode='two-region-portal')
    v=replay(lvl,base_prog)
    c=v['conditions'].get('OBSTACLE_DEVANT',{})
    if not (v['victory'] and v['portalTraversals'].get(p_id,0)==1 and c.get('true',0)>=2 and c.get('false',0)>=3):continue
    if add_interaction:
     # Place interaction AFTER confirming portal route. Ensure first use is on first region,
     # matching the loop's start-of-cycle. Lock/door must be approached head-on.
     # Calculate path as actually visited including portal jump and detect an index before/after jump.
     walked=v['visited']
     # presence of portal arrival counts as one position (source not in visited, exit is)
     # Sensors run before each walk step. Place key/plate at safe visited point.
     def place_at(p,char,m):
      nonlocal lvl
      if p in (st,dest,srcp,exitp):return False
      if lvl['grid'][p[1]][p[0]]!='g':return False
      ls=[list(row) for row in lvl['grid']];ls[p[1]][p[0]]=char;lvl['grid']=[''.join(row) for row in ls];lvl['mechanics'].append(m);return True
     if add_interaction=='key-lock':
      # Use key on pre-portal region and lock after teleport; loop must adapt.
      pre=[p for p in walked[2: max(3,k-1)] if p not in (srcp, exitp)]
      post=[p for p in walked[max(3,k+2): -2] if p not in (srcp,exitp)]
      if len(pre)<1 or len(post)<1:continue
      kp=pre[len(pre)//2]
      lp=post[len(post)//2]
      # lock must be on straight-forward entry, not a turn.
      ii=walked.index(lp)
      if ii<2 or (lp[0]-walked[ii-1][0],lp[1]-walked[ii-1][1])!=(walked[ii-1][0]-walked[ii-2][0],walked[ii-1][1]-walked[ii-2][1]):continue
      if not place_at(kp,'K',{'type':'BoardKey','x':kp[0],'y':kp[1]}):continue
      if not place_at(lp,'U',{'type':'BoardLock','x':lp[0],'y':lp[1]}):continue
      prog=[node('REPETE',[node('SI',[node('RAMASSE')],'CLE_ICI'),node('SI',[node('UTILISE')],'CADENAS_DEVANT'),node('SI',[node(T if side=='R' else L)],'OBSTACLE_DEVANT'),node(F)])]
      lvl['reference']['program']=prog;lvl['reference']['writtenBlocks']=count_nodes(prog)
      lvl['designPattern']='portal-key-lock'
     elif add_interaction=='plate-door':
      pre=[p for p in walked[2:max(3,k-1)] if p not in (srcp,exitp)]
      post=[p for p in walked[max(3,k+2):-2] if p not in (srcp,exitp)]
      if not pre or not post:continue
      ap=pre[len(pre)//2];dp=post[len(post)//2];ii=walked.index(dp)
      if ii<2 or (dp[0]-walked[ii-1][0],dp[1]-walked[ii-1][1])!=(walked[ii-1][0]-walked[ii-2][0],walked[ii-1][1]-walked[ii-2][1]):continue
      lid='expert-door-'+str(index)
      if not place_at(ap,'A',{'type':'BoardPlate','x':ap[0],'y':ap[1],'linkId':lid}):continue
      if not place_at(dp,'D',{'type':'BoardDoor','x':dp[0],'y':dp[1],'linkId':lid}):continue
      prog=[node('REPETE',[node('SI',[node('ACTIVE')],'SUR_BOUTON'),node('SI',[node(T if side=='R' else L)],'OBSTACLE_DEVANT'),node(F)])]
      lvl['reference']['program']=prog;lvl['reference']['writtenBlocks']=count_nodes(prog);lvl['designPattern']='portal-plate-door'
    result=replay(lvl,lvl['reference']['program'])
    if result['victory'] and result['portalTraversals'].get(p_id,0)==1 and (add_interaction is None or (add_interaction=='key-lock' and result['events'].get('key',0)>=1 and result['events'].get('lock',0)>=1) or (add_interaction=='plate-door' and result['events'].get('plate',0)>=1)):
     return lvl,result
 raise ValueError(('portal puzzle unavailable',index,steps,side,add_interaction))


def collect_program_conditions(program):
 out=[]
 for q in program:
  if q['command']=='SI':out.append(q['condition'])
  out+=collect_program_conditions(q.get('body',[]))
 return out


def check_cond_essential(L,prog):
 """Every conditional block must be necessary in the reference *as written*."""
 n=[]
 def count(ns):
  for x in ns:
   if x['command']=='SI':n.append(x)
   count(x.get('body',[]))
 count(prog)
 results=[]
 for i in range(len(n)):
  p=copy.deepcopy(prog)
  targets=[]
  def gather(ns):
   for x in ns:
    if x['command']=='SI':targets.append(x)
    gather(x.get('body',[]))
  gather(p);targets[i]['body']=[]
  r=replay(L,p)
  results.append(not r['victory'])
 return results


def create_levels():
 from primitive_bfs import optimal_primitive
 alllevels=[];audit=[]
 def test_candidate(lvl,phase,requiredMargin=3):
  prog=lvl['reference']['program'];result=replay(lvl,prog)
  if not result['victory'] or result['loopIterations']<3:return None
  if result['writtenBlocks']>=result['executedActions']-2:return None
  if phase>=2:
   c=result['conditions'].get('OBSTACLE_DEVANT',{})
   if c.get('true',0)<2 or c.get('false',0)<3:return None
   if not all(check_cond_essential(lvl,prog)):return None
  base=optimal_primitive(lvl)
  if not base['solved'] or base['actions'] < result['writtenBlocks']+requiredMargin:return None
  # Prove control constructs are useful via comparison to optimized primitive-only sequence.
  if phase>=3:
   types=set(x['type'] for x in lvl['mechanics'])
   if 'BoardLock' in types:
    r=optimal_primitive(lvl,disable_commands={'UTILISE'})
    if r['solved']:return None
   if 'BoardDoor' in types:
    r=optimal_primitive(lvl,disable_commands={'ACTIVE'})
    if r['solved']:return None
   if 'BoardCrate' in types:
    r=optimal_primitive(lvl,disable_commands={'POUSSE'})
    if r['solved']:return None
  if phase==5:
   r=optimal_primitive(lvl,disable_portals=True)
   if r['solved']:return None
   if sum(result['portalTraversals'].values())<1:return None
  noRepeat=copy.deepcopy(prog)
  if noRepeat[0]['command']!='REPETE':raise AssertionError('expected loop')
  singleRun=replay(lvl,noRepeat[0]['body'])
  if singleRun['victory']:return None
  return result,base
 def accept(lvl,phase,title,intro,theme,minimumMargin=3):
  z=test_candidate(lvl,phase,minimumMargin)
  if z is None:return False
  r,b=z
  idx=len(alllevels)+1
  lvl['id']='EX-'+str(idx).zfill(3)
  lvl['name']=title
  lvl['visualThemeWorld']=theme
  lvl['sequence']=idx # internal only; no visible level numbering
  lvl['showLevelNumber']=False
  lvl['firstUseTutorialStep']=intro
  lvl['reference']['expandedCommands']=r['expandedCommands']
  lvl['reference']['executedActions']=r['executedActions']
  lvl['reference']['loopIterations']=r['loopIterations']
  lvl['reference']['conditionObservations']=r['conditions']
  lvl['reference']['events']=r['events']
  lvl['reference']['portalTraversals']=r['portalTraversals']
  lvl['reference']['shortestPrimitiveOnlyActions']=b['actions']
  lvl['reference']['primitiveOnlyOptimality']='EXACT_BFS_OFFLINE_MODEL'
  lvl['reference']['writtenBlockOptimality']='BEST_KNOWN_VALIDATED_NOT_PROVEN'
  wc=r['writtenBlocks']
  lvl['starTargets']={'metric':'writtenBlocks','threeStarsMax':wc,'twoStarsMax':wc+max(2,int(math.ceil(wc*.3))),'oneStar':'anySuccess','optimality':'REFERENCE_NOT_PROVEN_WRITTEN_MINIMUM'}
  lvl['initiallyAvailableCommands']=['AVANCE','RECULE','TOURNE_GAUCHE','TOURNE_DROITE','RAMASSE','UTILISE','POUSSE','ACTIVE']
  lvl['unlockedControlCommands']=['REPETE']+(['SI'] if idx>=9 else [])
  lvl['unlockedConditions']=([] if idx<=8 else ['OBSTACLE_DEVANT'] if idx<=16 else ['OBSTACLE_DEVANT','CLE_ICI','CADENAS_DEVANT'] if idx<=20 else ['OBSTACLE_DEVANT','CLE_ICI','CADENAS_DEVANT','SUR_BOUTON'] if idx<30 else ['OBSTACLE_DEVANT','CLE_ICI','CADENAS_DEVANT','SUR_BOUTON','CAISSE_DEVANT'])
  lvl['expertScoringIndependence']='No change to adventure stars, which are executedPrimitiveActions'
  alllevels.append(lvl)
  audit.append({'id':lvl['id'],'name':title,'phase':phase,'size':str(lvl['width'])+'x'+str(lvl['height']),'referenceBlocks':wc,'primitiveOptimalActions':b['actions'],'programActions':r['executedActions'],'loopIterations':r['loopIterations'],'sensorTrue':sum(c.get('true',0) for c in r['conditions'].values()),'sensorFalse':sum(c.get('false',0) for c in r['conditions'].values()),'interactions':json.dumps(r['events'],ensure_ascii=False),'portals':len(r['portalTraversals']),'star3':wc,'star2':lvl['starTargets']['twoStarsMax']})
  return True

 # Phase 1: loops. Fixed per-step motifs; repeated 3-4x (no SI yet).
 patterns=[
  [F,T,F,L], [F,L,F,T], [F,F,T,F,L], [F,F,L,F,T],
  [F,T,F,F,L],[F,L,F,F,T],[F,T,F,L,F],[F,L,F,T,F]
 ]
 names=['Le premier automatisme','Un pas de côté','Avancer, tourner, recommencer','Le rythme inversé','Un détour régulier','Le mouvement miroir','La séquence cachée','Pilote automatique']
 for i,pattern in enumerate(patterns):
  for cyc in [4,3,5,2]:
   try:
    lvl,_=make_repeats(i,pattern,cyc,7 if i<6 else 8,theme=1+i%5)
    if accept(lvl,1,names[i],1 if i==0 else None,1+i%5,minimumMargin=4):break
   except ValueError:continue
  else:raise ValueError('stage loop not found '+str(i))

 # Phase 2: sensor inside a loop, right/left first obstacle turns.
 names=['Le mur décide','Réagir sans réfléchir','Le virage automatique','Contourner les obstacles','Chercher une ouverture','La trajectoire imprévue','Le passage en spirale','Le robot s’adapte']
 for i in range(8):
  for j in range(100):
   n=7 if i<5 else 8;steps=14+i+(j%3)
   try:lvl,*_=build_follow(200+i*500+j,n,steps,('R' if i%2==0 else 'L'),theme=4+i%6)
   except ValueError:continue
   if accept(lvl,2,names[i],2 if i==0 else None,4+i%6,minimumMargin=5):break
  else:raise ValueError('stage condition not found '+str(i))

 # Phase 3: keys and plates, one interaction per level, progressively harder.
 names=['La clé répétée','Une serrure sur la route','La clé au bon moment','Le passage verrouillé','Détecter le bouton','Activer sans s’arrêter','L’interrupteur caché','La porte automatique']
 for i in range(8):
  kind='key-lock' if i<4 else 'plate-door'
  for j in range(170):
   try:lvl,_,_=augment_interaction(500+i*1000+j,8,19+i+(j%4),('R' if (i+j)%2==0 else 'L'),kind,theme=6+i%7)
   except ValueError:continue
   if accept(lvl,3,names[i],3 if i==0 else 4 if i==4 else None,6+i%7,minimumMargin=5):break
  else:raise ValueError('stage interaction not found '+str(i))

 # Phase 4: advanced combinations without teleport, multi keys and multi switches.
 names=['Deux clés, une logique','Les deux serrures','Deux boutons à retrouver','Les portes jumelles','Clé et commande','Passages successifs','Réflexes croisés','La routine complète']
 kinds=['double-keys','double-keys','double-plates','double-plates','key-plate-lock','key-plate-lock','key-plate-lock','key-plate-lock']
 for i,kind in enumerate(kinds):
  for j in range(220):
   try:
    side=('L' if (i+j)%2 else 'R')
    lvl,_,_=augment_interaction(850+i*1200+j,8,25+i+(j%3),side,kind,theme=8+i%8)
    if i in (5,7):
     candidate=augment_crate(lvl,side)
     if candidate is None:continue
     lvl,_=candidate
   except ValueError:continue
   if accept(lvl,4,names[i],6 if i==5 else None,8+i%8,minimumMargin=6):break
  else:raise ValueError('stage advanced not found '+str(i))

 # Phase 5: mandatory portals plus autonomous sensors and interactions.
 names=['Saut dimensionnel','Une clé de l’autre côté','La porte après le saut','Le détour impossible','Deux salles, un programme','Le passage télécommandé','L’itinéraire autonome','Examen du laboratoire']
 for i in range(8):
  typ=['key-lock','plate-door'][i%2]
  for j in range(240):
   try:lvl,_=build_portal(1600+i*1200+j,8,13+i%5+(j%3),('R' if (i+j)%2 else 'L'),theme=9+i%7,add_interaction=typ)
   except ValueError:continue
   if accept(lvl,5,names[i],5 if i==0 else None,9+i%7,minimumMargin=5):break
  else:raise ValueError('stage portals not found '+str(i))

 assert len(alllevels)==40
 assert len({tuple(L['grid']) for L in alllevels})==40
 for entry in alllevels:
  assert entry['reference']['writtenBlocks'] < entry['reference']['shortestPrimitiveOnlyActions']
  assert all(cmd!='SI' for cmd in [x['command'] for x in entry['reference']['program']] if entry['sequence']<=8)
  assert entry['sequence']==int(entry['id'][3:])
 return alllevels,audit


def augment_crate(lvl,side):
 """Insert a useful conditional push at a forced turn: pushing moves robot one tile,
 then the moved crate remains ahead, making OBSTACLE_DEVANT true and turning correctly.
 """
 source=copy.deepcopy(lvl)
 v=replay(source,source['reference']['program'])
 if not v['victory']:return None
 path=v['visited'];n=lvl['width'];turncmd=T if side=='R' else L
 mechanicpos={(m['x'],m['y']) for m in lvl['mechanics']};orient_right=lambda vin:(vin[1],-vin[0]) if side=='L' else (-vin[1],vin[0])
 idxs=list(range(4,len(path)-3));R.shuffle(idxs)
 for j in idxs:
  pprev,p,post=path[j-1:j+2]
  # Need p to turn right/left relative to incoming direction and pprev->p to be forward.
  vdir=(p[0]-pprev[0],p[1]-pprev[1]);wdir=(post[0]-p[0],post[1]-p[1])
  if abs(vdir[0])+abs(vdir[1])!=1 or wdir!=orient_right(vdir):continue
  q=(p[0]+vdir[0],p[1]+vdir[1])
  if not within(q,n) or p in mechanicpos or q in mechanicpos or p in (lvl['finish']['x'],lvl['finish']['y']):continue
  if lvl['grid'][p[1]][p[0]]!='g' or lvl['grid'][q[1]][q[0]] not in BLOCK:continue
  ll=copy.deepcopy(lvl);cells=[list(r) for r in ll['grid']]
  cells[p[1]][p[0]]='C';cells[q[1]][q[0]]='g'
  ll['grid']=[''.join(row) for row in cells]
  ll['mechanics'].append({'type':'BoardCrate','x':p[0],'y':p[1]})
  prog=copy.deepcopy(ll['reference']['program'])
  prog[0]['body'].insert(0,node('SI',[node('POUSSE')],'CAISSE_DEVANT'))
  ll['reference']['program']=prog;ll['reference']['writtenBlocks']=count_nodes(prog)
  ll['designPattern']=ll['designPattern']+'-with-crate'
  z=replay(ll,prog)
  if z['victory'] and z['events'].get('crate',0)==1 and z['conditions'].get('CAISSE_DEVANT',{}).get('false',0)>=3:
   return ll,z
 return None

if __name__=='__main__':
 levels,audit=create_levels()
 P=OUT/'robot_idiot_expert_simulations_40.json'
 package={'schemaVersion':'expert-lab/1.0','packId':'robot-idiot-expert-laboratory-v1','mode':'expert','locale':'fr-FR',
 'displayPolicy':{'noWorldMap':True,'hideInternalLevelNumbers':True,'entryPoint':'Continuer l’entraînement','progress':'completedUnique/40','archive':'Historique des simulations','fixedLevelsOnly':True,'generateRuntime':False},
 'scoring':{'metric':'writtenBlocks','count':'Count each AST command node once, including SI, REPETE and their nested children, ignoring execution multiplicity','threeStars':'writtenBlocks <= starTargets.threeStarsMax','twoStars':'writtenBlocks <= starTargets.twoStarsMax','oneStar':'successfulProgram','neverBlockOnStarRating':True,'noBlockLimit':True,'referenceOptimalityCaution':'Reference scores are validated but not mathematically proven global minimum written program.'},
 'progression':{'simulations':40,'unlockRule':'Complete current simulation with any star rating to unlock next','firstUnlocked':'EX-001','beginUnlockedCommands':['REPETE'],'unlockSIAt':'EX-009','beginPrimitiveCommands':['AVANCE','RECULE','TOURNE_GAUCHE','TOURNE_DROITE','RAMASSE','UTILISE','POUSSE','ACTIVE'],'noAdventureSaveChanges':True,'noSharedStars':True,'unlockCrateSensorAt':'EX-030'},
 'controlRules':{'REPETE':'Infinite; stop immediately on reaching flag, explicit failure, user stop, or safety watchdog','SI':'Executes body only when condition true; reevaluates each time execution visits the SI','availableConditions':['OBSTACLE_DEVANT','CLE_ICI','CADENAS_DEVANT','SUR_BOUTON','CAISSE_DEVANT'],'conditionsAreFreeSensors':True,'movementAndObjectRules':'Follow V14.1 interactionRules, including keys/locks, plates/doors, portal orientation, crate-portal exclusion.'},
 'simulations':levels}
 P.write_text(json.dumps(package,ensure_ascii=False,indent=2)+'\n')
 csvp=OUT/'audit_expert_40_simulations.csv'
 with csvp.open('w',newline='') as fp:
  w=csv.DictWriter(fp,audit[0].keys());w.writeheader();w.writerows(audit)
 print('EXPORTED',P,len(levels),'AUDIT',csvp)
 for a in audit:print(a['id'],a['phase'],a['referenceBlocks'],a['primitiveOptimalActions'],a['programActions'],a['loopIterations'])

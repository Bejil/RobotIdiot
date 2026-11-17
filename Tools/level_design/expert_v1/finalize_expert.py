#!/usr/bin/env python3
"""Polish pedagogical order, add first-run tutorial strings and manifests."""
import json,copy,hashlib,math,csv
from pathlib import Path
from expert_engine import replay,count_nodes
from primitive_bfs import optimal_primitive
OUT=Path(__file__).resolve().parent.parent
P=OUT/'robot_idiot_expert_simulations_40.json'
d=json.loads(P.read_text());ls=d['simulations']
assert len(ls)==40
# Keep didactic unlock order, sort the graduated subgroups by best primitive route.
for a,b in [(8,16),(16,20),(20,24),(24,29),(32,40)]:
 ls[a:b]=sorted(ls[a:b],key=lambda L:(L['reference']['shortestPrimitiveOnlyActions'],L['reference']['executedActions']))
# First stage's first lesson remains EX-001; first SI after first 8; first key at 17; first plate at 21.
firstStep={1:1,9:2,17:3,21:4,30:6,33:5}
for i,L in enumerate(ls,1):
 L['sequence']=i;L['id']=f'EX-{i:03d}';L.pop('firstUseTutorialStep',None)
 L['microTutorialKey']={1:'repeat',9:'if',17:'key',21:'plate',30:'crate',33:'portal'}.get(i)
 L['unlockedControlCommands']=['REPETE']+(['SI'] if i>=9 else [])
 L['unlockedConditions']=([] if i<=8 else ['OBSTACLE_DEVANT'] if i<=16 else ['OBSTACLE_DEVANT','CLE_ICI','CADENAS_DEVANT'] if i<=20 else ['OBSTACLE_DEVANT','CLE_ICI','CADENAS_DEVANT','SUR_BOUTON'] if i<30 else ['OBSTACLE_DEVANT','CLE_ICI','CADENAS_DEVANT','SUR_BOUTON','CAISSE_DEVANT'])
 L['progressDisplay']={'showLevelNumber':False,'label':'Simulation en cours','singleNextButton':True}
 # Collapsing tutorial: just one line at the specified skill introduction, not blocking every replay.
 intro={1:'Une boucle répète tes instructions jusqu’à l’arrivée.',9:'Une condition se vérifie à chaque passage. Si elle est vraie, le robot réagit.',17:'Le robot peut reconnaître une clé et un cadenas.',21:'Un bouton peut être activé automatiquement.',30:'Ton robot peut détecter et pousser une caisse.',33:'Un portail conserve l’orientation du robot.'}
 L['teachingHint']=intro.get(i, L.get('teachingHint',''))
 L['reference']['replayedAfterOrdering']=True
d['simulations']=ls
# Use full UI copy separate from game data for easy localization.
tutorial={
 'schemaVersion':'expert-tutorial/1.0','id':'expert-first-entry-v1','locale':'fr-FR',
 'completionStorageKey':'robotIdiot.expert.tutorial.v1.completed',
 'showRule':'On first entry into Expert, before the game board; show again if tutorial closed before final validation; explicit skip marks completed',
 'replayEntry':'Help (?) > Revoir le tutoriel du Laboratoire',
 'skipAllowed':True,'pages':[
  {'id':'intro','title':'Bienvenue au Laboratoire','body':'Dans l’Aventure, tu aides le robot à atteindre le drapeau en utilisant le moins d’actions possible. Ici, tu apprends à le rendre autonome.','visualHint':'showSameRobotDifferentModes','primaryCTA':'Suivant','secondaryCTA':'Passer'},
  {'id':'repeat','title':'Fais travailler ton robot','body':'REPETE recommence les commandes à l’intérieur de la boucle. Pas besoin d’indiquer combien de fois : le robot s’arrête dès qu’il atteint le drapeau.','visualHint':'animatedExampleRepeat','exampleProgram':[{'command':'REPETE','body':[{'command':'AVANCE'},{'command':'TOURNE_DROITE'}]}], 'primaryCTA':'Suivant'},
  {'id':'if','title':'Il pourra bientôt décider','body':'Plus tard, tu débloqueras SI. Le robot vérifiera une situation, comme « obstacle devant ». Si c’est vrai, il exécutera la commande placée dans le SI. Sinon, il la sautera.','visualHint':'conditionTrueFalsePreview','conditionPreviewLocked':True,'primaryCTA':'Suivant'},
  {'id':'stars','title':'Ici, le plus court gagne','body':'Dans le Laboratoire, les étoiles dépendent du nombre de blocs écrits, pas du nombre de déplacements du robot. REPETE et SI ne comptent chacun qu’une fois. Une étoile suffit pour continuer ; les trois étoiles sont un défi facultatif.','example':{'expandedActions':12,'writtenBlocks':4},'visualHint':'compareBlocksVsActions','primaryCTA':'Suivant'},
  {'id':'start','title':'Prêt pour une simulation ?','body':'Chaque réussite fait monter ta jauge de maîtrise. Une nouvelle simulation arrive automatiquement, sans mondes ni carte de niveaux. Tu pourras revoir les anciennes simulations quand tu voudras.','visualHint':'progressGauge','primaryCTA':'Commencer l’entraînement'}
 ],
 'microTutorials':[
  {'onFirstStartSimulation':'EX-001','title':'Nouvelle commande : REPETE','body':'Dépose des commandes dans REPETE puis lance le robot. La boucle recommencera jusqu’au drapeau.','shownOnceKey':'expert.tip.repeat'},
  {'onFirstStartSimulation':'EX-009','title':'Nouvelle commande : SI','body':'Place une action dans SI OBSTACLE_DEVANT. Le robot vérifie cette condition à chaque passage dans la boucle.','shownOnceKey':'expert.tip.if'},
  {'onFirstStartSimulation':'EX-017','title':'De nouveaux capteurs','body':'SI CLE_ICI et SI CADENAS_DEVANT détectent les objets au bon endroit, au bon moment.','shownOnceKey':'expert.tip.key'},
  {'onFirstStartSimulation':'EX-021','title':'Le capteur de bouton','body':'SI SUR_BOUTON peut déclencher ACTIVE quand le robot se trouve sur un bouton encore inactif.','shownOnceKey':'expert.tip.plate'},
  {'onFirstStartSimulation':'EX-030','title':'La caisse détectée','body':'SI CAISSE_DEVANT permet de pousser au moment opportun.','shownOnceKey':'expert.tip.crate'},
  {'onFirstStartSimulation':'EX-033','title':'Les portails','body':'Un portail transporte le robot à sa paire sans modifier son orientation.','shownOnceKey':'expert.tip.portal'}
 ],
 'accessibility':{'voiceOver':True,'dynamicType':True,'reduceMotion':True,'skipAnimatedDemo':True},
 'exitBehavior':{'closeBeforeCompletion':'do not mark completed; show on next entry','pressSkip':'mark as completed explicitly','pressStart':'mark completed then open next available simulation','replayTutorial':'do not reset completion or progress'}
 }
(OUT/'robot_idiot_expert_tutorial_fr.json').write_text(json.dumps(tutorial,ensure_ascii=False,indent=2)+'\n')

# A compact independent UI progression file; separate saved runtime state.
config={'schemaVersion':'expert-config/1.0','mode':'expert','pack':'robot-idiot-expert-laboratory-v1',
 'availability':{'entryPoint':'home.ExpertLaboratory','requiresAdventureCompletion':False,'separateProgressFromAdventure':True},
 'navigation':{'initialRoute':'expert.tutorial.ifNeeded -> expert.currentSimulation','showWorldMap':False,'showLevelSelection':False,'showInternalSequenceNumbers':False,'resumeCTA':'Continuer l’entraînement','replayRoute':'expert.history','helpRoute':'expert.tutorial.replay'},
 'progression':{'totalSimulations':40,'completionPercent':'floor(100 * uniqueCompleted / 40)','unlockNextWith':'victory and starRating >= 1','allowReplay':True,'allowSkipSimulation':False,'finalAchievement':'Laboratoire maîtrisé','postCompletion':'Replay and improve; no infinite generated puzzles'},
 'controls':{'primitiveCommandsAvailableFromStart':d['progression']['beginPrimitiveCommands'],'REPETE':{'unlockAt':'EX-001','repeatCount':'infinite'},'SI':{'unlockAt':'EX-009','conditionsUnlockBySimulation':{'OBSTACLE_DEVANT':'EX-009','CLE_ICI':'EX-017','CADENAS_DEVANT':'EX-017','SUR_BOUTON':'EX-021','CAISSE_DEVANT':'EX-030'}},'unavailableBeforeUnlock':'visible, locked, disabled; never runnable'},
 'stars':{'metric':'writtenBlocks','countASTNodesOnce':True,'countSIOncePlusBodyNodes':True,'countREPETEOncePlusBodyNodes':True,'countVisualEndMarkers':False,'compareOnVictoryOnly':True,'oneStarAnyWin':True,'twoStarReferenceThreshold':'starTargets.twoStarsMax','threeStarReferenceThreshold':'starTargets.threeStarsMax','noArbitraryBlocksLimit':True,'noImpactToAdventureScoring':'executedPrimitiveActions'},
 'persistence':{'namespace':'robotIdiot.expert.v1','bestStarsBySimulation':'starRating by EX-id','bestWrittenBlocks':'minimum winning block count by EX-id','savedProgramBySimulation':'AST encoded per EX-id','nextAvailableId':'first not yet completed','tutorialCompletedKey':'robotIdiot.expert.tutorial.v1.completed','neverOverwriteAdventureKeys':True,'neverOverwriteDailyKeys':True,'atomicSaveRecommended':True},
 'runtimeSafety':{'maxExecutedPrimitiveActions':1000,'maxASTNodes':None,'maxInterpretationSteps':20000,'maxWallTimeSeconds':20,'controlFeedback':'Show why stopped without deleting editor program'},
 'assets':{'reuseExistingRobotAndTiles':True,'reuseVisualThemesFromAdventure':True,'newGraphicsRequired':False,'worldVisualThemeIsOnlyStyling':True},
 'dataValidation':{'allProgramsReplayedOffline':True,'minimumWrittenBlocksProven':False,'minimumPrimitiveCommandsOfflineBFSProven':True,'swiftReplayRequired':True},
 'sourceFiles':['robot_idiot_expert_simulations_40.json','robot_idiot_expert_tutorial_fr.json']}
(OUT/'robot_idiot_expert_config.json').write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n')

rows=[]
for L in ls:
 r=replay(L,L['reference']['program']);b=optimal_primitive(L)
 assert r['victory'],L['id'];assert b['solved']
 rows.append({'id':L['id'],'name':L['name'],'phase':(L['sequence']-1)//8+1,'size':str(L['width'])+'×'+str(L['height']),'referenceBlocks':r['writtenBlocks'],'bestPrimitiveActions':b['actions'],'referenceExecutedActions':r['executedActions'],'loops':r['loopIterations'],'conditionTrue':sum(s.get('true',0) for s in r['conditions'].values()),'conditionFalse':sum(s.get('false',0) for s in r['conditions'].values()),'interactionEvents':json.dumps(r['events'],ensure_ascii=False),'portalJumps':sum(r['portalTraversals'].values()),'star3Threshold':L['starTargets']['threeStarsMax'],'star2Threshold':L['starTargets']['twoStarsMax']})
with (OUT/'audit_expert_40_simulations.csv').open('w',newline='') as fp:
 wr=csv.DictWriter(fp,rows[0].keys());wr.writeheader();wr.writerows(rows)
P.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
(OUT/'validation_summary.json').write_text(json.dumps({'simulations':len(ls),'referenceWins':sum(replay(x,x['reference']['program'])['victory'] for x in ls),'uniqueGrids':len({tuple(x['grid']) for x in ls}),'minimumPrimitiveOnlyBFSVerified':len(ls),'writtenBlockGlobalOptimalityProven':False,'gamesPreserved':'Adventure and Dailies not modified','conditionsStart':'EX-009','keysStart':'EX-017','plateSensorStart':'EX-021','crateSensorStart':'EX-030','portalsStart':'EX-033','oneStarForWin':True,'allLevelsIndependentOfAdventureStars':True,'artifactSHA256':hashlib.sha256(P.read_bytes()).hexdigest()},ensure_ascii=False,indent=2)+'\n')
print('FINALIZED',len(ls),'ids',ls[0]['id'],ls[-1]['id'])
